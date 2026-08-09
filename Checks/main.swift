import DualViewCore
import Foundation

enum CheckFailure: Error, CustomStringConvertible {
    case mismatch(String)

    var description: String {
        switch self {
        case .mismatch(let message): return message
        }
    }
}

func expect<T: Equatable>(_ actual: T, _ expected: T, _ name: String) throws {
    guard actual == expected else {
        throw CheckFailure.mismatch("\(name): expected \(expected), got \(actual)")
    }
    print("PASS \(name)")
}

func entry(_ index: Int, orientation: ImageOrientation) -> ImageEntry {
    let size = orientation == .landscape ? (1200, 800) : (800, 1200)
    return ImageEntry(
        url: URL(fileURLWithPath: "/image-\(index).jpg"),
        pixelWidth: size.0,
        pixelHeight: size.1
    )
}

func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

do {
    let singleEntries = (0..<3).map { entry($0, orientation: .landscape) }
    let single = PresentationSequence(entries: singleEntries, mode: .single, fill: true)
    try expect(
        single.frames.map(\.entryIndices),
        [[0, nil], [1, nil], [2, nil]],
        "single-display sequence"
    )

    let alternatingEntries = (0..<5).map { entry($0, orientation: .landscape) }
    let alternatingFill = PresentationSequence(
        entries: alternatingEntries,
        mode: .alternating,
        fill: true
    )
    try expect(
        alternatingFill.frames.map(\.entryIndices),
        [
            [0, 1], [2, 1], [2, 3], [4, 3],
        ], "alternating fill")

    let alternatingPlain = PresentationSequence(
        entries: Array(alternatingEntries.prefix(4)),
        mode: .alternating,
        fill: false
    )
    try expect(
        alternatingPlain.frames.map(\.entryIndices),
        [
            [0, nil], [0, 1], [2, 1], [2, 3],
        ], "alternating without fill")

    let mixedEntries = [
        entry(0, orientation: .landscape),
        entry(1, orientation: .landscape),
        entry(2, orientation: .portrait),
        entry(3, orientation: .portrait),
        entry(4, orientation: .landscape),
    ]
    let mixedFill = PresentationSequence(
        entries: mixedEntries,
        mode: .byOrientation,
        fill: true
    )
    try expect(
        mixedFill.frames.map(\.entryIndices),
        [
            [0, 2], [1, 2], [1, 2], [1, 3], [4, 3],
        ], "orientation fill")

    let rotated = ImageEntry(
        url: URL(fileURLWithPath: "/rotated.jpg"),
        pixelWidth: 1200,
        pixelHeight: 800,
        exifOrientation: 6
    )
    try expect(rotated.orientation, .portrait, "EXIF rotation")
    try expect(
        rotated.shouldRotate(toMatch: .landscape),
        true,
        "portrait rotates for landscape screen"
    )
    try expect(
        rotated.shouldRotate(toMatch: .portrait),
        false,
        "portrait stays upright for portrait screen"
    )

    let wrappingNavigator = FrameNavigator(
        frames: [FrameState([0, nil]), FrameState([0, 1]), FrameState([2, 1])],
        wraps: true
    )
    _ = wrappingNavigator.moveBackward()
    try expect(wrappingNavigator.position, 2, "circular backward wrap")
    _ = wrappingNavigator.moveForward()
    try expect(wrappingNavigator.position, 0, "circular forward wrap")

    let positionedNavigator = FrameNavigator(
        frames: single.frames,
        startPosition: 2
    )
    try expect(positionedNavigator.position, 2, "navigator starting position")

    let randomOrder = randomizedFrameOrder(frameCount: 20, keeping: 7)
    try expect(randomOrder.first, 7, "random permutation keeps current first")
    try expect(randomOrder.sorted(), Array(0..<20), "random permutation coverage")

    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    for name in ["slide10.jpg", "slide2.JPG", "slide1.png", "notes.txt"] {
        _ = FileManager.default.createFile(
            atPath: directory.appendingPathComponent(name).path,
            contents: Data()
        )
    }
    let directoryResult = try ImageInputLoader().load(
        sources: [directory.path],
        standardInput: nil,
        currentDirectory: directory,
        warning: { _ in }
    )
    try expect(
        directoryResult.map(\.url.lastPathComponent),
        [
            "slide1.png", "slide2.JPG", "slide10.jpg",
        ], "directory natural sort")

    let section10 = directory.appendingPathComponent("section10", isDirectory: true)
    let section2 = directory.appendingPathComponent("section2", isDirectory: true)
    try FileManager.default.createDirectory(at: section10, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: section2, withIntermediateDirectories: true)
    for url in [
        section10.appendingPathComponent("slide1.jpg"),
        section2.appendingPathComponent("slide10.jpg"),
        section2.appendingPathComponent("slide2.jpg"),
    ] {
        _ = FileManager.default.createFile(atPath: url.path, contents: Data())
    }
    let recursiveResult = try ImageInputLoader().load(
        sources: [directory.path],
        standardInput: nil,
        currentDirectory: directory,
        warning: { _ in }
    )
    try expect(
        recursiveResult.map {
            DisplayPath.relative(from: directory, to: $0.url)
        },
        [
            "section2/slide2.jpg",
            "section2/slide10.jpg",
            "section10/slide1.jpg",
            "slide1.png",
            "slide2.JPG",
            "slide10.jpg",
        ], "recursive full-path natural sort")

    let image = directory.appendingPathComponent("photo 1.heic")
    _ = FileManager.default.createFile(atPath: image.path, contents: Data())
    let list = directory.appendingPathComponent("show.txt")
    try "photo 1.heic\n\nphoto 1.heic\n".write(
        to: list,
        atomically: true,
        encoding: .utf8
    )
    let listResult = try ImageInputLoader().load(
        sources: [list.path],
        standardInput: nil,
        currentDirectory: URL(fileURLWithPath: "/"),
        warning: { _ in }
    )
    try expect(listResult.map(\.url), [image, image], "relative list paths and duplicates")
    try expect(
        listResult.map(\.displayBaseURL),
        [directory, directory],
        "list display paths use list directory"
    )

    let listedDirectory = directory.appendingPathComponent("listed", isDirectory: true)
    let listedSection = listedDirectory.appendingPathComponent("section2", isDirectory: true)
    try FileManager.default.createDirectory(at: listedSection, withIntermediateDirectories: true)
    let listedSlide10 = listedDirectory.appendingPathComponent("slide10.jpg")
    let listedSlide2 = listedSection.appendingPathComponent("slide2.png")
    _ = FileManager.default.createFile(atPath: listedSlide10.path, contents: Data())
    _ = FileManager.default.createFile(atPath: listedSlide2.path, contents: Data())
    let directoryList = directory.appendingPathComponent("directories.txt")
    try "photo 1.heic\nlisted\nphoto 1.heic\n".write(
        to: directoryList,
        atomically: true,
        encoding: .utf8
    )
    let expandedListResult = try ImageInputLoader().load(
        sources: [directoryList.path],
        standardInput: nil,
        currentDirectory: URL(fileURLWithPath: "/"),
        warning: { _ in }
    )
    try expect(
        expandedListResult.map { $0.url.resolvingSymlinksInPath() },
        [image, listedSlide2, listedSlide10, image].map { $0.resolvingSymlinksInPath() },
        "list directory recursive expansion in place"
    )
    try expect(
        expandedListResult.map(\.displayBaseURL),
        Array(repeating: directory, count: 4),
        "listed directories retain list-relative display base"
    )

    let concatenated = try ImageInputLoader().load(
        sources: [image.path, directoryList.path, image.path],
        standardInput: nil,
        currentDirectory: directory,
        warning: { _ in }
    )
    try expect(
.map { $0.url.resolvingSymlinksInPath() },
        [image, image, listedSlide2, listedSlide10, image, image].map {
            $0.resolvingSymlinksInPath()
        },
        "multiple inputs concatenate in argument order"
    )

    let stdinResult = try ImageInputLoader().load(
        sources: [image.path, "-"],
        standardInput: "photo 1.heic\n",
        currentDirectory: directory,
        warning: { _ in }
    )
    try expect(stdinResult.map(\.url), [image, image], "stdin concatenates in place")

    var metadataWarnings: [String] = []
    let unreadableInputs = [
        directory.appendingPathComponent("slide10.jpg"),
        directory.appendingPathComponent("slide1.png"),
        directory.appendingPathComponent("slide2.JPG"),
    ].map { ImageInput(url: $0, displayBaseURL: directory) }
    let unreadableEntries = ImageMetadataScanner.scan(
        inputs: unreadableInputs,
        maxConcurrentTasks: 2
    ) { metadataWarnings.append($0) }
    try expect(unreadableEntries, [], "parallel metadata scan skips unreadable files")
    try expect(
        metadataWarnings,
        unreadableInputs.map { "Skipping unreadable image: \($0.url.path)" },
        "parallel metadata warnings preserve input order"
    )

    let suppliedImageURLs = CommandLine.arguments.dropFirst().map {
        URL(fileURLWithPath: NSString(string: $0).expandingTildeInPath)
    }
    if !suppliedImageURLs.isEmpty {
        var warnings: [String] = []
        let scanned = ImageMetadataScanner.scan(urls: suppliedImageURLs) {
            warnings.append($0)
        }
        try expect(scanned.count, suppliedImageURLs.count, "supplied image metadata scan")
        try expect(warnings, [], "supplied image metadata warnings")
    }

    print("All DualView checks passed.")
} catch {
    FileHandle.standardError.write(Data(("FAIL \(error)\n").utf8))
    exit(EXIT_FAILURE)
}
