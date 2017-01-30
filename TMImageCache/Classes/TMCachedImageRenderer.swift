//
//  Copyright © 2017 Ticketmaster. All rights reserved.
//

import UIKit

fileprivate struct CachedFileDescriptor {
    let header: TMCachedImageHeader
    let fileDescriptor: Int32
    let mappedPointer: UnsafeMutableRawPointer
}

open class TMCachedImageRenderer<ImageKey: Hashable> {


    public final let name: String
    public final let originalCache: TMImageCache<ImageKey>
    public final let persistenceURL: URL
    fileprivate let queue: DispatchQueue
    fileprivate var fileDescriptorCache: [URL: CachedFileDescriptor] = [:]

    public init(name: String, originalCache: TMImageCache<ImageKey>, purgeExisting shouldPurge: Bool = false) {

        guard let persistenceURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("TMVolatileImageCaches/\(originalCache.name)-\(name)", isDirectory: true) else {
            fatalError("Failed to construct persistence URL")
        }

        if shouldPurge {
            try? FileManager.default.removeItem(at: persistenceURL)
        }

        try? FileManager.default.createDirectory(atPath: persistenceURL.path, withIntermediateDirectories: true, attributes: nil)

        self.name = name
        self.persistenceURL = persistenceURL
        self.originalCache = originalCache
        self.queue = DispatchQueue(label: "\(type(of: self))-\(self.name)", qos: .background, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
    }

    deinit {
        for item in fileDescriptorCache.values {
            munmap(item.mappedPointer, item.header.totalBytesLength)
            close(item.fileDescriptor)
        }
    }

    public final func image(forKey key: ImageKey, targetSize size: CGSize, scale: CGFloat? = nil, completion: @escaping (_ key: ImageKey, _ image: UIImage?)->Void) -> UIImage? {

        let scale = scale ?? UIScreen.main.scale
        if let basePointer = self.mappedPointer(forKey: key, targetSize: size, scale: scale) {
            if let image = UIImage.fromMappedFile(pointer: basePointer) {
                return image
            }
        }
        self.queue.async { [weak self] in
            guard let original = self?.originalCache.image(forKey: key) else {
                return
            }
            let result = self?.render(image: original, forKey: key, targetSize: size)
            DispatchQueue.main.async {
                completion(key, result)
            }
        }
        return nil
    }

    open func render(image: UIImage, inContext context: CGContext, contextBounds bounds: CGRect) {
        image.draw(in: bounds)
    }
}

fileprivate extension TMCachedImageRenderer {

    final func url(forImageWithKey key: ImageKey, targetSize size: CGSize, scale: CGFloat? = nil) -> URL {
        let scale = scale ?? UIScreen.main.scale
        return self.persistenceURL.appendingPathComponent("\(key)_@\(scale)x_\(Int(size.width))_\(Int(size.height))", isDirectory: false)
    }

    final func mappedPointer(forKey key: ImageKey, targetSize size: CGSize, scale: CGFloat? = nil) -> UnsafeMutableRawPointer? {

        let scale = scale ?? UIScreen.main.scale
        let url = self.url(forImageWithKey: key, targetSize: size, scale: scale)
        if let cached = self.fileDescriptorCache[url] {
            return cached.mappedPointer
        }

        let fd = url.withUnsafeFileSystemRepresentation { (fsPath) -> Int32? in

            guard let fsPath = fsPath else {
                assertionFailure("Failed to obtain filesystem representation \(url.standardizedFileURL.path)")
                return nil
            }
            let fd = open(fsPath, O_RDONLY, 0666)
            if fd == -1 {
                return nil
            }
            return fd
        }

        guard let fileDescriptor = fd else {
            return nil
        }

        let header = TMCachedImageHeader(targetSize: size, scale: scale)
        guard let bytes = mmap(nil, header.totalBytesLength, PROT_READ, (MAP_FILE | MAP_SHARED), fileDescriptor, 0) else {
            close(fileDescriptor)
            assertionFailure("mmap failure")
            return nil
        }

        self.fileDescriptorCache[url] = CachedFileDescriptor(header: header, fileDescriptor: fileDescriptor, mappedPointer: bytes)
        return bytes
    }

    final func render(image: UIImage, forKey key: ImageKey, targetSize: CGSize, scale: CGFloat? = nil) -> UIImage? {

        let scale = scale ?? UIScreen.main.scale
        let url = self.url(forImageWithKey: key, targetSize: targetSize)
        let header = TMCachedImageHeader(targetSize: targetSize, scale: scale)
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            if let error = try? fileManager.removeItem(atPath: url.path) {
                assertionFailure("Failed to remove existing file at path: \(url.path) error: \(error)")
                return nil
            }
        }

        guard fileManager.createFile(atPath: url.path, contents: nil, attributes: [URLResourceKey.isExcludedFromBackupKey.rawValue:true]) else {
            assertionFailure("Failed to create new file \(url.path)")
            return nil
        }

        return url.withUnsafeFileSystemRepresentation { (filesystemRepresentation) -> UIImage? in

            guard let filesystemRepresentation = filesystemRepresentation else {
                assertionFailure("Failed to obtain filesystem representation \(url.standardizedFileURL.path)")
                return nil
            }

            let fileDescriptor = open(filesystemRepresentation, (O_RDWR | O_CREAT), 0666)
            defer {
                close(fileDescriptor)
            }
            guard truncate(filesystemRepresentation, off_t(header.totalBytesLength)) == 0 else {
                perror("Failed to resize binary blob \(url.standardizedFileURL.path): ")
                close(fileDescriptor)
                return nil
            }

            guard let bytes = mmap(nil, header.totalBytesLength, PROT_WRITE | PROT_READ, MAP_FILE | MAP_SHARED, fileDescriptor, 0) else {
                assertionFailure("mmap failure")
                close(fileDescriptor)
                return nil
            }

            let headerPointer = bytes.bindMemory(to: TMCachedImageHeader.self, capacity: 1)
            headerPointer.pointee = header

            let imagePointer = bytes.advanced(by: MemoryLayout<TMCachedImageHeader>.size)

            let colorspace = CGColorSpaceCreateDeviceRGB()
            guard let context = CGContext(data: imagePointer, width: Int(header.pixelSize.width), height: Int(header.pixelSize.height), bitsPerComponent: header.bitsPerComponent, bytesPerRow: header.bytesPerRow, space: colorspace, bitmapInfo: header.bitmapInfo.rawValue) else {
                assertionFailure("Context creation failure")
                close(fileDescriptor)
                return nil
            }

            let imageRect = CGRect(x: 0.0, y: 0.0, width: header.size.width, height: header.size.height)
            context.translateBy(x: 0.0, y: header.pixelSize.height)
            context.scaleBy(x: header.scale, y: -header.scale)
            context.clip(to: imageRect)
            context.interpolationQuality = .high
            context.setFillColor(UIColor.black.cgColor)
            context.fill(imageRect)

            UIGraphicsPushContext(context)
            self.render(image: image, inContext: context, contextBounds: imageRect)
            UIGraphicsPopContext()

            msync(bytes, header.totalBytesLength, MS_SYNC)
            munmap(bytes, header.totalBytesLength)

            guard let basePointer = self.mappedPointer(forKey: key, targetSize: targetSize, scale: scale) else {
                return nil
            }
            
            return UIImage.fromMappedFile(pointer: basePointer)
        }
    }
}

