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
    public let dataProvider: TMImageDataProvider<Key>
    
    public init(cache: TMImageCache<Key>, dataProvider: TMImageDataProvider<Key>) {
        self.cache = cache
        self.dataProvider = dataProvider
    }
    
    public func image(for key: Key, completion: (UIImage?) -> Void) {
        
    }
    
}
