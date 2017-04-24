//
//  Copyright © 2017 Ticketmaster. All rights reserved.
//

import UIKit

fileprivate struct CachedFileDescriptor {
    let header: TMCachedImageHeader
    let fileDescriptor: Int32
    let mappedPointer: UnsafeMutableRawPointer
}

open class TMCachedImageRenderer<ImageKey: TMImageKeyType> {


    public final let name: String
    public final let dataSource: TMImageDataSource<ImageKey>
    public final let persistenceURL: URL
    fileprivate var fileDescriptorCache: [URL: CachedFileDescriptor] = [:]
    fileprivate var queuesByKey: [ImageKey: DispatchQueue] = [:]

    fileprivate let rendersOpaqueImages: Bool

    public init(name: String, dataSource: TMImageDataSource<ImageKey>, rendersOpaqueImages: Bool = true) {

        guard let persistenceURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("TMVolatileImageCaches/\(dataSource.cache.name)-\(name)", isDirectory: true) else {
            fatalError("Failed to construct persistence URL")
        }

        try? FileManager.default.createDirectory(atPath: persistenceURL.path, withIntermediateDirectories: true, attributes: nil)

        self.rendersOpaqueImages = rendersOpaqueImages
        self.name = name
        self.persistenceURL = persistenceURL
        self.dataSource = dataSource
    }

    deinit {
        for item in fileDescriptorCache.values {
            munmap(item.mappedPointer, item.header.totalBytesLength)
            close(item.fileDescriptor)
        }
    }

    public final func image(forKey key: ImageKey, targetSize size: CGSize, scale: CGFloat? = nil, completion: @escaping (_ key: ImageKey, _ image: UIImage?)->Void) -> UIImage? {

        // temp: synchronous path disabled
        //        let scale = scale ?? UIScreen.main.scale
        //        if let basePointer = self.mappedPointer(forKey: key, targetSize: size, scale: scale) {
        //            if let image = UIImage.fromMappedFile(pointer: basePointer) {
        //                return image
        //            }
        //        }

        if self.queuesByKey[key] == nil {
            self.queuesByKey[key] = DispatchQueue(label: "imageCachingQueue-\(key.hashedIdentifier)")
        }
        self.queuesByKey[key]?.async {

            let scale = scale ?? UIScreen.main.scale
            if let basePointer = self.mappedPointer(forKey: key, targetSize: size, scale: scale),
                let image = UIImage.fromMappedFile(pointer: basePointer){
                DispatchQueue.main.async {
                    completion(key, image)
                }
            } else {
                self.dataSource.image(for: key, completion: { (image: UIImage?) -> Void in
                    var result: UIImage? = nil

                    // temp until we figure out threading issues
                    self.queuesByKey[key]?.async {
                        if let image = image {
                            result = self.render(image: image, forKey: key, targetSize: size)
                        }
                        DispatchQueue.main.async {
                            completion(key, result)
                        }
                    }

                })
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
        return self.persistenceURL.appendingPathComponent("\(key.hashedIdentifier)_@\(scale)x_\(Int(size.width))_\(Int(size.height))", isDirectory: false)
    }

    final func mappedPointer(forKey key: ImageKey, targetSize size: CGSize, scale: CGFloat? = nil) -> UnsafeMutableRawPointer? {

        let scale = scale ?? UIScreen.main.scale
        let url = self.url(forImageWithKey: key, targetSize: size, scale: scale)
        if let cached = self.fileDescriptorCache[url] {
            return cached.mappedPointer
        }

        let fileCoordinator = NSFileCoordinator()

        var bytes: UnsafeMutableRawPointer? = nil
        var errorPointer: NSErrorPointer = nil
        fileCoordinator.coordinate(readingItemAt: url, options: [], error: errorPointer) { (url) in
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
                return
            }

            let header = TMCachedImageHeader(targetSize: size, scale: scale, opaque: self.rendersOpaqueImages)
            guard let theBytes = mmap(nil, header.totalBytesLength, PROT_READ, (MAP_FILE | MAP_SHARED), fileDescriptor, 0) else {
                close(fileDescriptor)
                assertionFailure("mmap failure")
                return
            }

            self.fileDescriptorCache[url] = CachedFileDescriptor(header: header, fileDescriptor: fileDescriptor, mappedPointer: theBytes)
            bytes = theBytes
        }

        return bytes
    }

    final func render(image: UIImage, forKey key: ImageKey, targetSize: CGSize, scale: CGFloat? = nil) -> UIImage? {

        let scale = scale ?? UIScreen.main.scale
        let url = self.url(forImageWithKey: key, targetSize: targetSize)
        let header = TMCachedImageHeader(targetSize: targetSize, scale: scale, opaque: self.rendersOpaqueImages)
        let fileManager = FileManager.default
        let fileCoordinator = NSFileCoordinator()

        var success: Bool = false
        var errorPointer: NSErrorPointer = nil
        fileCoordinator.coordinate(writingItemAt: url, options: .forReplacing, error: errorPointer) { (url) in
            if fileManager.fileExists(atPath: url.path) {
                do {
                    try fileManager.removeItem(atPath: url.path)
                } catch let error {
                    assertionFailure("Failed to remove existing file at path: \(url.path) error: \(error)")
                    return
                }
            }
            guard fileManager.createFile(atPath: url.path, contents: nil, attributes: [URLResourceKey.isExcludedFromBackupKey.rawValue:true]) else {
                assertionFailure("Failed to create new file \(url.path)")
                return
            }
            success = true
        }
        guard success == true else {
            if let error = errorPointer?.pointee {
                assertionFailure("Couldn't coordinate writing item at url: \(url), error: \(error)")
            }
            return nil
        }

        var imageToReturn: UIImage? = nil
        var error: NSErrorPointer = nil

        fileCoordinator.coordinate(writingItemAt: url, options: [], error: errorPointer) { (url) in
            url.withUnsafeFileSystemRepresentation { (filesystemRepresentation) in
                guard let filesystemRepresentation = filesystemRepresentation else {
                    assertionFailure("Failed to obtain filesystem representation \(url.standardizedFileURL.path)")
                    return
                }
                self.renderImageTo(filesystemRepresentation: filesystemRepresentation, header: header, image: image)
            }
        }
        if let error = errorPointer?.pointee {
            print("Error rendering image into file: \(url), error: \(error)")
        }

        guard let basePointer = self.mappedPointer(forKey: key, targetSize: targetSize, scale: scale) else {
            return nil
        }

        imageToReturn = UIImage.fromMappedFile(pointer: basePointer)

        return imageToReturn
    }

    // todo: name this better
    func renderImageTo(filesystemRepresentation: UnsafePointer<Int8>,
                       header: TMCachedImageHeader,
                       image: UIImage) {

        let fileDescriptor = open(filesystemRepresentation, (O_RDWR | O_CREAT), 0666)
        defer {
            close(fileDescriptor)
        }
        guard truncate(filesystemRepresentation, off_t(header.totalBytesLength)) == 0 else {
            perror("Failed to resize binary blob \(filesystemRepresentation): ")
            close(fileDescriptor)
            return
        }

        guard let bytes = mmap(nil, header.totalBytesLength, PROT_WRITE | PROT_READ, MAP_FILE | MAP_SHARED, fileDescriptor, 0) else {
            assertionFailure("mmap failure")
            close(fileDescriptor)
            return
        }

        let headerPointer = bytes.bindMemory(to: TMCachedImageHeader.self, capacity: 1)
        headerPointer.pointee = header

        let imagePointer = bytes.advanced(by: MemoryLayout<TMCachedImageHeader>.size)

        let colorspace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: imagePointer, width: Int(header.pixelSize.width), height: Int(header.pixelSize.height), bitsPerComponent: header.bitsPerComponent, bytesPerRow: header.bytesPerRow, space: colorspace, bitmapInfo: header.bitmapInfo.rawValue) else {
            assertionFailure("Context creation failure")
            close(fileDescriptor)
            return
        }

        let imageRect = CGRect(x: 0.0, y: 0.0, width: header.size.width, height: header.size.height)
        context.translateBy(x: 0.0, y: header.pixelSize.height)
        context.scaleBy(x: header.scale, y: -header.scale)
        context.clip(to: imageRect)
        context.interpolationQuality = .high
        context.clear(imageRect)

        if self.rendersOpaqueImages {
            context.setFillColor(UIColor.black.cgColor)
            context.fill(imageRect)
        }
        
        UIGraphicsPushContext(context)
        self.render(image: image, inContext: context, contextBounds: imageRect)
        UIGraphicsPopContext()
        
        msync(bytes, header.totalBytesLength, MS_SYNC)
        munmap(bytes, header.totalBytesLength)
    }
}

