//
//  TMDataProvider.swift
//  Pods
//
//  Created by Duncan Lewis on 1/30/17.
//
//

import Foundation

open class TMDataProvider<Key: Hashable> {
    
    open func image(for key: Key, completion: (UIImage?) -> Void) {
        completion(nil)
    }
    
}
