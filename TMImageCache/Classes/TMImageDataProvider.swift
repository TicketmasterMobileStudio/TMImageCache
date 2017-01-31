//
//  TMImageDataProvider.swift
//  Pods
//
//  Created by Duncan Lewis on 1/30/17.
//
//

import Foundation


public protocol TMImageDataProvider {
    associatedtype Key
    
    func image(for key: Key, completion: @escaping (ImageRequestResult) -> Void) -> CancellableImageRequest
}

public protocol CancellableImageRequest {
    func cancel()
}

public enum ImageRequestResult {
    case success(UIImage)
    case failure(Error?)
}

// type-erasure for TMImageDataProvider
class AnyImageDataProvider<Key>: TMImageDataProvider {
    
    private let _imageForKey: (Key, @escaping (ImageRequestResult) -> Void) -> Void
    
    init<DataProvider: TMImageDataProvider>(dataProvider: DataProvider) where DataProvider.Key == Key {
        _imageForKey = dataProvider.image(for:completion:)
    }
    
    func image(for key: Key, completion: @escaping (ImageRequestResult) -> Void) {
        return _imageForKey(key, { result in
            completion(result)
        })
    }
    
}
