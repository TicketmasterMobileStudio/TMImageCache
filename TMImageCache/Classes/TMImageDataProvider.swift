//
//  TMImageDataProvider.swift
//  Pods
//
//  Created by Duncan Lewis on 1/30/17.
//
//

import Foundation

public enum ImageRequestResult {
    case success(UIImage)
    case failure(Error?)
}

open class TMImageDataProvider<Key: Hashable> {
    
    open func image(for key: Key, completion: (ImageRequestResult) -> Void) {
        completion(.failure(nil))
    }
    
}
