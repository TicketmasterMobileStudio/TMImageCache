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
    public let dataProvider: AnyImageDataProvider<Key>
    
    public init<U: TMImageDataProvider>(cache: TMImageCache<Key>, dataProvider: U) where U.Key == Key {
        self.cache = cache
        self.dataProvider = AnyImageDataProvider<Key>(dataProvider: dataProvider)
    }
    
    public func image(for key: Key, completion: (UIImage?) -> Void) {
        
    }
    
}
