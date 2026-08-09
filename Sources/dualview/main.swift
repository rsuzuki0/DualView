import AppKit
import DualViewCore
import Foundation

do {
    let options = try Options.parse(Array(CommandLine.arguments.dropFirst()))
    if options.showHelp {
        print(usage)
        exit(EXIT_SUCCESS)
    }
    if options.showVersion {
        print("DualView \(dualViewVersion)")
        exit(EXIT_SUCCESS)
    }

    let stdin = readStandardInputIfNeeded(sources: options.sources)
    let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let inputs = try ImageInputLoader().load(
        sources: options.sources,
        standardInput: stdin,
        currentDirectory: currentDirectory,
        warning: { writeStandardError("Warning: \($0)") }
    )

    let pathOverlay =
        options.showPath
        ? PathOverlaySettings(
            fontName: options.pathFontName,
            fontSize: CGFloat(options.pathFontSize),
            showsProgress: options.showProgress
        ) : nil

    let application = NSApplication.shared
    application.setActivationPolicy(.regular)
    let delegate = AppDelegate(
        inputs: inputs,
        fill: options.fill,
        loop: options.loop,
        pathOverlay: pathOverlay,
        clickNavigation: options.clickNavigation,
        rotation: options.rotation,
        showProgressBar: options.showProgressBar,
        autoAdvance: options.autoAdvance,
        delay: options.delay
    )
    application.delegate = delegate
    application.run()
} catch {
    writeStandardError("Error: \(error.localizedDescription)")
    writeStandardError(usage)
    exit(EXIT_FAILURE)
}
