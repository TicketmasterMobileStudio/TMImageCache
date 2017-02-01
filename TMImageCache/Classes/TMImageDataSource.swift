//
//  TMImageDatasource.swift
//  Pods
//
//  Created by Duncan Lewis on 1/31/17.
//
//

import Foundation

public class TMImageDataSource<Key: Hashable> {
    
    public let cache: TMImageCache<Key>
    
    internal let dataProvider: AnyImageDataProvider<Key>
    internal var imageRequestsByKey = [Key: CancellableImageRequest]()
    internal var completionHandlersByKey = [Key: [(UIImage?) -> Void]]()
    
    public init<DataProvider: TMImageDataProvider>(cache: TMImageCache<Key>, dataProvider: DataProvider) where DataProvider.Key == Key {
        self.cache = cache
        self.dataProvider = AnyImageDataProvider<Key>(dataProvider: dataProvider)
    }
    
    public func image(for key: Key, completion: @escaping (UIImage?) -> Void) {
        
        if self.cache.containsObject(forKey: key), let cachedImage = self.cache.image(forKey: key) {
            completion(cachedImage)
        } else {
            self.addCompletionHandler(completion, for: key)
            self.sendRequest(for: key)
        }

    }
    
    
    // MARK: Request/Completion Handlers
    
    fileprivate func addCompletionHandler(_ completionHandler: @escaping (UIImage?) -> Void, for key: Key) {
        var handlers = self.completionHandlersByKey[key] ?? [(UIImage?) -> Void]()
        handlers.append(completionHandler)
        self.completionHandlersByKey[key] = handlers
    }
    
    fileprivate func sendRequest(for key: Key) {
        guard self.imageRequestsByKey[key] == nil else {
            return
        }
        
        let imageRequest = self.dataProvider.image(for: key, completion: { (result) in
            
            self.imageRequestsByKey[key] = nil
            
            switch result {
            case .success(let image):
                self.invokeCompletions(for: key, with: image)
            case .failure(let error):
                if let error = error {
                    // print the error if logging is on?
                    print(error)
                }
                self.invokeCompletions(for: key, with: nil)
            }
        })
        
        self.imageRequestsByKey[key] = imageRequest
    }
    
    func invokeCompletions(for key: Key, with image: UIImage?) {
        self.completionHandlersByKey[key]?.forEach { $0(image) }
        self.completionHandlersByKey[key] = nil
    }
    
}
