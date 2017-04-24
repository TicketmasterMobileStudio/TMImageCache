//
//  TMImageKey.swift
//  Pods
//
//  Created by Duncan Lewis on 4/24/17.
//
//

import CryptoSwift

public protocol TMImageKeyType: Hashable {

    var imageIdentifier: String { get }

}

extension TMImageKeyType {

    var hashedIdentifier: String {
        return self.imageIdentifier.md5()
    }

}
