//
//  Copyright © 2017 Ticketmaster. All rights reserved.
//

import Foundation
import MobileCoreServices

public final class TMImageCache<Key: TMImageKeyType> {
    
    public let name: String
    
    private lazy var queue: DispatchQueue = DispatchQueue(label: "\(type(of: self))-\(self.name)", qos: .background, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
    private let persistenceURL: URL

    public init(name: String) {

        guard let persistenceURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("TMImageCaches/\(name)", isDirectory: true) else {
            fatalError("Failed to construct persistence URL")
        }

        try? FileManager.default.createDirectory(atPath: persistenceURL.path, withIntermediateDirectories: true, attributes: nil)

        self.persistenceURL = persistenceURL
        self.name = name
    }

    public func setImage(atURL url: URL, forKey key: Key) {

        if url.isFileURL == false {
            assertionFailure("URL must be a local file URL")
            return
        }
        guard let typeIdentifier = (try? url.resourceValues(forKeys: [.typeIdentifierKey]))?.typeIdentifier else {
            return
        }

        if UTTypeConformsTo(typeIdentifier as CFString, kUTTypeImage) == false {
            return
        }
        let destinationURL = self.urlForImage(withKey: key)
        try? FileManager.default.copyItem(at: url, to: destinationURL)
    }

    public func setImage(image: UIImage, forKey key: Key, completion:@escaping ()->Void = {}) {

        let url = self.urlForImage(withKey: key)
        self.queue.async {
            guard let pngData = UIImagePNGRepresentation(image) else {
                return
            }
            try? pngData.write(to: url, options: .atomicWrite)
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    public func containsObject(forKey key: Key) -> Bool {
        return FileManager.default.fileExists(atPath: self.urlForImage(withKey: key).path)
    }
    
    internal func image(forKey key: Key) -> UIImage? {
        return UIImage(contentsOfFile: self.urlForImage(withKey: key).path)
    }

    private func urlForImage(withKey key: Key) -> URL {
        return self.persistenceURL.appendingPathComponent("\(key)", isDirectory: false)
    }
}
