import Darwin
import Foundation

let dualViewVersion = "0.6.0"

enum QuarterTurn: Equatable {
    case none
    case clockwise
    case counterclockwise
}

enum RotationMode: Equatable {
    case none
    case always(QuarterTurn)
    case toFill(QuarterTurn)
}

struct Options {
    var fill = false
    var sources: [String] = []
    var showHelp = false
    var showPath = false
    var pathFontSize = 20.0
    var pathFontName: String?
    var clickNavigation = false
    var loop = false
    var showVersion = false
    var rotation = RotationMode.none
    var showProgress = false
    var showProgressBar = false
    var autoAdvance = false
    var delay = 5.0

    static func parse(_ arguments: [String]) throws -> Options {
        var result = Options()
        var positional: [String] = []

        var index = 0
        var optionsEnded = false
        while index < arguments.count {
            let argument = arguments[index]
            if optionsEnded {
                positional.append(argument)
                index += 1
                continue
            }

            switch argument {
            case "--fill":
                result.fill = true
            case "--list":
                break  // Compatibility no-op: non-image regular files are lists.
            case "-h", "--help":
                result.showHelp = true
            case "-V", "--version":
                result.showVersion = true
            case "--show-path":
                result.showPath = true
            case "--progress":
                result.showProgress = true
                result.showPath = true
            case "--progress-bar":
                result.showProgressBar = true
            case "--rotate":
                index += 1
                result.rotation = .always(
                    try parseQuarterTurn(arguments, at: index, option: "--rotate")
                )
            case "--rotate-to-fill":
                index += 1
                result.rotation = .toFill(
                    try parseQuarterTurn(arguments, at: index, option: "--rotate-to-fill")
                )
            case "-a", "--auto-advance":
                result.autoAdvance = true
            case "-t", "--delay":
                index += 1
                guard index < arguments.count,
                    let delay = Double(arguments[index]),
                    delay.isFinite,
                    delay > 0
                else {
                    throw CommandLineError("--delay requires a positive number of seconds.")
                }
                result.delay = delay
                result.autoAdvance = true
            case "--path-font-size":
                index += 1
                guard index < arguments.count,
                    let size = Double(arguments[index]),
                    size >= 8,
                    size <= 200
                else {
                    throw CommandLineError("--path-font-size requires a number from 8 through 200.")
                }
                result.pathFontSize = size
                result.showPath = true
            case "--path-font":
                index += 1
                guard index < arguments.count, !arguments[index].isEmpty else {
                    throw CommandLineError("--path-font requires a font name.")
                }
                result.pathFontName = arguments[index]
                result.showPath = true
            case "--click-nav":
                result.clickNavigation = true
            case "-r", "-R", "--recursive":
                break  // Compatibility no-op: directories are always recursive.
            case "--loop", "--circular":
                result.loop = true
            case "--":
                optionsEnded = true
            case "-":
                positional.append(argument)
            default:
                if argument.hasPrefix("-") {
                    throw CommandLineError("Unknown option: \(argument)")
                }
                positional.append(argument)
            }
            index += 1
        }

        result.sources = positional
        return result
    }

    private static func parseQuarterTurn(
        _ arguments: [String],
        at index: Int,
        option: String
    ) throws -> QuarterTurn {
        guard index < arguments.count else {
            throw CommandLineError("\(option) requires cw or ccw.")
        }
        switch arguments[index].lowercased() {
        case "cw":
            return .clockwise
        case "ccw":
            return .counterclockwise
        default:
            throw CommandLineError("\(option) requires cw or ccw.")
        }
    }
}

struct CommandLineError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}

let usage = """
    Usage: dualview [OPTIONS] [INPUT ...]

    OPTIONS:
      --fill                 Initially fill both displays when possible.
      --show-path            Show an input-relative path at bottom-left.
      --progress             Prefix the path with its source ordinal, such as [1/383].
      --progress-bar         Show traversal progress as a thin bar on the first display.
      --path-font-size N     Set path size in points; implies --show-path.
      --path-font NAME       Set path font face; implies --show-path.
      --rotate cw|ccw        Rotate displayed images by one quarter turn.
      --rotate-to-fill cw|ccw
                             Rotate only when image and screen orientations differ.
      --click-nav            Left-click advances; right/Shift-click goes back.
      --loop, --circular     Wrap navigation at the first and last states.
      -a, --auto-advance     Advance automatically (default delay: 5 seconds).
      -t, --delay SECONDS    Set the delay and enable automatic advance.
      -V, --version          Show the program version.
      -h, --help             Show this help.

    Each INPUT may be:
      DIRECTORY   Recursively scan images in natural full-relative-path order.
      IMAGE       Display one image.
      LIST        Read one image or directory path per line.
      -           Read one image or directory path per line from standard input.

    Inputs are concatenated in command-line order; duplicates are preserved. With no
    INPUT, redirected standard input is used. Directory lines in a list are expanded
    recursively in place. For compatibility, --list and -r/-R/--recursive are accepted
    as no-ops. Supported formats are JPEG, PNG, HEIC, and the first frame of GIF.
    Navigation keys: arrows, Page Up/Down, Space/Shift-Space,
    Return, and keypad Enter. R toggles random permutation;
    S toggles auto-advance; 1-9 set its delay in seconds and 0 sets 10 seconds.
    Escape or Command-Q quits.
    """

func readStandardInputIfNeeded(sources: [String]) -> String? {
    guard sources.contains("-") || (sources.isEmpty && isatty(STDIN_FILENO) == 0) else {
        return nil
    }
    return String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8)
}

func writeStandardError(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}
