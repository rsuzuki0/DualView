import Foundation
import ImageIO

public enum ImageOrientation: Equatable, Sendable {
    case landscape
    case portrait
}

public struct ImageInput: Equatable, Sendable {
    public let url: URL
    public let displayBaseURL: URL

    public init(url: URL, displayBaseURL: URL) {
        self.url = url
        self.displayBaseURL = displayBaseURL
    }
}

public struct ImageEntry: Equatable, Sendable {
    public let url: URL
    public let displayBaseURL: URL
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let exifOrientation: UInt32

    public init(
        url: URL,
        displayBaseURL: URL? = nil,
        pixelWidth: Int,
        pixelHeight: Int,
        exifOrientation: UInt32 = 1
    ) {
        self.url = url
        self.displayBaseURL = displayBaseURL ?? url.deletingLastPathComponent()
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.exifOrientation = exifOrientation
    }

    public var displayedPixelWidth: Int {
        exifOrientation >= 5 && exifOrientation <= 8 ? pixelHeight : pixelWidth
    }

    public var displayedPixelHeight: Int {
        exifOrientation >= 5 && exifOrientation <= 8 ? pixelWidth : pixelHeight
    }

    public var orientation: ImageOrientation {
        displayedPixelWidth >= displayedPixelHeight ? .landscape : .portrait
    }

    public func shouldRotate(toMatch screenOrientation: ImageOrientation) -> Bool {
        orientation != screenOrientation
    }

    public static func placeholder(for input: ImageInput) -> ImageEntry {
        ImageEntry(
            url: input.url,
            displayBaseURL: input.displayBaseURL,
            pixelWidth: 1,
            pixelHeight: 1
        )
    }
}

public enum ImageMetadataScanner {
    public static func scan(
        inputs: [ImageInput],
        maxConcurrentTasks: Int = 4,
        warning: @escaping (String) -> Void
    ) -> [ImageEntry] {
        guard !inputs.isEmpty else { return [] }

        let store = MetadataScanStore(count: inputs.count)
        let queue = OperationQueue()
        queue.name = "DualView metadata scanner"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = max(1, min(maxConcurrentTasks, inputs.count))

        for (index, input) in inputs.enumerated() {
            queue.addOperation {
                autoreleasepool {
                    store.set(scan(input: input), at: index)
                }
            }
        }
        queue.waitUntilAllOperationsAreFinished()

        let results = store.values()
        for (index, result) in results.enumerated() where result == nil {
            warning("Skipping unreadable image: \(inputs[index].url.path)")
        }
        return results.compactMap { $0 }
    }

    public static func scan(urls: [URL], warning: @escaping (String) -> Void) -> [ImageEntry] {
        scan(
            inputs: urls.map {
                ImageInput(url: $0, displayBaseURL: $0.deletingLastPathComponent())
            },
            warning: warning
        )
    }

    public static func scan(input: ImageInput) -> ImageEntry? {
        guard let source = CGImageSourceCreateWithURL(input.url as CFURL, nil),
            CGImageSourceGetCount(source) > 0,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
            let width = number(properties[kCGImagePropertyPixelWidth]),
            let height = number(properties[kCGImagePropertyPixelHeight]),
            width > 0,
            height > 0
        else {
            return nil
        }

        let orientation = number(properties[kCGImagePropertyOrientation]) ?? 1
        return ImageEntry(
            url: input.url,
            displayBaseURL: input.displayBaseURL,
            pixelWidth: width,
            pixelHeight: height,
            exifOrientation: UInt32(orientation)
        )
    }

    private static func number(_ value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }
        return value as? Int
    }
}

private final class MetadataScanStore: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [ImageEntry?]

    init(count: Int) {
        storage = Array(repeating: nil, count: count)
    }

    func set(_ entry: ImageEntry?, at index: Int) {
        lock.lock()
        storage[index] = entry
        lock.unlock()
    }

    func values() -> [ImageEntry?] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
