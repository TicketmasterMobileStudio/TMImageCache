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
    
    public init<DataProvider: TMImageDataProvider>(cache: TMImageCache<Key>, dataProvider: DataProvider) where DataProvider.Key == Key {
        self.cache = cache
        self.dataProvider = AnyImageDataProvider<Key>(dataProvider: dataProvider)
    }
    
    public func image(for key: Key, completion: @escaping (UIImage?) -> Void) {
        
        var result: UIImage? = nil
        defer {
            completion(result)
        }
        
        if self.cache.containsObject(forKey: key), let cachedImage = self.cache.image(forKey: key) {
            result = cachedImage
            
        } else {
            self.dataProvider.image(for: key, completion: { (result) in
                switch result {
                case .success(let image):
                    completion(image)
                case .failure(let error):
                    if let error = error {
                        // print the error if logging is on?
                        print(error)
                    }
                    completion(nil)
                }
            })
        }
        
    }
    
}
