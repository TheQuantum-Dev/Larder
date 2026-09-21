//
//  ScanImage.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import CoreGraphics
import Foundation
import ImageIO

extension CGImage {
    /// A copy whose longest side is at most `maxEdge` pixels. Smaller images
    /// come back unchanged. Big photos cost the model time for no extra
    /// accuracy, so we shrink them before sending.
    func downscaled(maxEdge: Int) -> CGImage {
        let longest = max(width, height)
        guard longest > maxEdge else { return self }
        let scale = Double(maxEdge) / Double(longest)
        let newWidth = max(1, Int(Double(width) * scale))
        let newHeight = max(1, Int(Double(height) * scale))

        guard let context = CGContext(data: nil, width: newWidth, height: newHeight,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return self }
        context.interpolationQuality = .high
        context.draw(self, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage() ?? self
    }

    /// Splits the image into an `n` by `n` grid of tiles.
    func tiles(grid n: Int) -> [CGImage] {
        let tileWidth = width / n
        let tileHeight = height / n
        var result: [CGImage] = []
        for row in 0..<n {
            for column in 0..<n {
                let rect = CGRect(x: column * tileWidth, y: row * tileHeight, width: tileWidth, height: tileHeight)
                if let tile = cropping(to: rect) { result.append(tile) }
            }
        }
        return result
    }

    /// Loads an image from a file, applying its EXIF orientation so photos
    /// taken sideways come out upright.
    static func load(from url: URL, maxEdge: Int = 2400) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return upright(from: source, maxEdge: maxEdge)
    }

    /// The same, for photo data such as what the photo picker hands back.
    static func load(from data: Data, maxEdge: Int = 2400) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return upright(from: source, maxEdge: maxEdge)
    }

    private static func upright(from source: CGImageSource, maxEdge: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxEdge,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
