//
//  Copyright © 2017 Ticketmaster. All rights reserved.
//

import Foundation

private extension CGBitmapInfo {
    static var byteOrder32Host: CGBitmapInfo {
        #if __BIG_ENDIAN__
            return CGBitmapInfo.byteOrder32Big
        #else    /* Little endian. */
            return CGBitmapInfo.byteOrder32Little
        #endif
    }
}

private func ByteAlign(width: UInt, alignment: UInt = 64) -> UInt {
    return ((width + (alignment - 1)) / alignment) * alignment;
}

internal struct TMCachedImageHeader {

    let size: CGSize
    let scale: CGFloat
    let pixelSize: CGSize
    let bytesPerRow: Int
    let bitsPerComponent: Int = 8
    let numberOfComponents: Int = 4
    let imageBytesLength: Int
    let totalBytesLength: Int
    let isOpaque: Bool

    var bitmapInfo: CGBitmapInfo {
        let alphaInfo: CGImageAlphaInfo = self.isOpaque ? .noneSkipFirst : .premultipliedFirst
        let info = CGBitmapInfo(rawValue: alphaInfo.rawValue | CGBitmapInfo.byteOrder32Host.rawValue)
        return info
    }

    init(targetSize: CGSize, scale: CGFloat?=nil, opaque: Bool = true) {

        let scale = scale ?? UIScreen.main.scale

        self.isOpaque = opaque

        self.scale = scale
        self.size = targetSize
        self.pixelSize = CGSize(width: targetSize.width * scale, height: targetSize.height * scale)

        self.bytesPerRow = Int(ByteAlign(width: UInt(self.pixelSize.width) * UInt(self.numberOfComponents)))

        self.imageBytesLength = Int(ByteAlign(width: UInt(self.bytesPerRow * Int(self.pixelSize.height))))
        self.totalBytesLength = self.imageBytesLength + MemoryLayout<TMCachedImageHeader>.size
    }
}
