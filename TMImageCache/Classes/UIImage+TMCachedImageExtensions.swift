//
//  Copyright © 2017 Ticketmaster. All rights reserved.
//

import UIKit

internal extension UIImage {

    static func fromMappedFile(pointer: UnsafeMutableRawPointer) -> UIImage? {
        let header = pointer.bindMemory(to: TMCachedImageHeader.self, capacity: 1).pointee

        let imageBytes = pointer.advanced(by: MemoryLayout<TMCachedImageHeader>.size)
        guard let dataProvider = CGDataProvider(dataInfo: nil, data: imageBytes, size: header.imageBytesLength, releaseData: {_,_,_ in }) else {
            return nil
        }

        let colorspace = CGColorSpaceCreateDeviceRGB()

        guard let cgImage = CGImage(width: Int(header.pixelSize.width),
                                    height: Int(header.pixelSize.height),
                                    bitsPerComponent: header.bitsPerComponent,
                                    bitsPerPixel: header.bitsPerComponent * header.numberOfComponents,
                                    bytesPerRow: header.bytesPerRow,
                                    space: colorspace,
                                    bitmapInfo: header.bitmapInfo,
                                    provider: dataProvider,
                                    decode: nil,
                                    shouldInterpolate: false,
                                    intent: .defaultIntent) else {
                                        return nil
        }

        return UIImage(cgImage: cgImage, scale: header.scale, orientation: .up)
    }
}
