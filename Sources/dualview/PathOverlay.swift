import AppKit
import DualViewCore
import Foundation

struct PathOverlaySettings {
    let fontName: String?
    let fontSize: CGFloat
    let showsProgress: Bool

    func text(for entry: ImageEntry, entryNumber: Int, total: Int) -> String {
        let path = DisplayPath.relative(from: entry.displayBaseURL, to: entry.url)
        return showsProgress ? "[\(entryNumber)/\(total)] \(path)" : path
    }

    func makeFont(warning: (String) -> Void) -> NSFont {
        guard let fontName else {
            return .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }
        if let font = NSFont(name: fontName, size: fontSize) {
            return font
        }
        if let font = NSFontManager.shared.font(
            withFamily: fontName,
            traits: [],
            weight: 5,
            size: fontSize
        ) {
            return font
        }

        warning("Font '\(fontName)' was not found; using the system monospaced font.")
        return .monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }
}
