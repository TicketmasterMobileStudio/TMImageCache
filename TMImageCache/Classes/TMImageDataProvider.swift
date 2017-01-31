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
    
    func image(for key: Key, completion: @escaping ImageRequestCompletion) -> Void
}


public enum ImageRequestResult {
    case success(UIImage)
    case failure(Error?)
}

public typealias ImageRequestCompletion = (ImageRequestResult) -> Void

// type-erasure for TMImageDataProvider
public class AnyImageDataProvider<Key>: TMImageDataProvider {
    
    private let _imageForKey: (Key, @escaping ImageRequestCompletion) -> Void
    
    init<DataProvider: TMImageDataProvider>(dataProvider: DataProvider) where DataProvider.Key == Key {
        _imageForKey = dataProvider.image(for:completion:)
    }
    
    public func image(for key: Key, completion: @escaping ImageRequestCompletion) {
        return _imageForKey(key, { result in
            completion(result)
        })
    }
    
}
