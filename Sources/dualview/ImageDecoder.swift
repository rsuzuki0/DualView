import AppKit
import ImageIO
import DualViewCore

final class ImageDecoder {
    private let cache = NSCache<NSString, NSImage>()

    init() {
        cache.countLimit = 16
        cache.totalCostLimit = 512 * 1024 * 1024
    }

    func cachedImage(for entry: ImageEntry, maxPixelSize: Int) -> NSImage? {
        cache.object(forKey: cacheKey(for: entry, maxPixelSize: maxPixelSize))
    }

    func image(for entry: ImageEntry, maxPixelSize: Int) -> NSImage? {
        let key = cacheKey(for: entry, maxPixelSize: maxPixelSize)
        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard let source = CGImageSourceCreateWithURL(entry.url as CFURL, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixelSize),
            kCGImageSourceShouldCacheImmediately: true,
        ]

        guard
            let cgImage = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                options as CFDictionary
            )
        else {
            return nil
        }

        let image = NSImage(cgImage: cgImage, size: .zero)
        let cost = cgImage.bytesPerRow * cgImage.height
        cache.setObject(image, forKey: key, cost: cost)
        return image
    }

    private func cacheKey(for entry: ImageEntry, maxPixelSize: Int) -> NSString {
        "\(entry.url.path)#\(maxPixelSize)" as NSString
    }
}
