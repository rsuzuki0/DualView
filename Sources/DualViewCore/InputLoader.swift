import Foundation

public enum InputError: LocalizedError, Equatable {
    case missingSource
    case sourceDoesNotExist(String)
    case cannotReadList(String)
    case multipleStandardInputs
    case noUsableImages

    public var errorDescription: String? {
        switch self {
        case .missingSource:
            return
                "No input source was provided. Pass directories, lists, images, or '-' for stdin."
        case .sourceDoesNotExist(let path):
            return "Input source does not exist: \(path)"
        case .cannotReadList(let path):
            return "Could not read list file as UTF-8: \(path)"
        case .multipleStandardInputs:
            return "Standard input ('-') may be specified only once."
        case .noUsableImages:
            return "No supported images were found."
        }
    }
}

public struct ImageInputLoader {
    public static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "gif",
    ]

    public init() {}

    public func load(
        sources: [String],
        standardInput: String?,
        currentDirectory: URL,
        warning: @escaping (String) -> Void
    ) throws -> [ImageInput] {
        let effectiveSources = sources.isEmpty && standardInput != nil ? ["-"] : sources
        guard !effectiveSources.isEmpty else {
            throw InputError.missingSource
        }
        guard effectiveSources.filter({ $0 == "-" }).count <= 1 else {
            throw InputError.multipleStandardInputs
        }

        var result: [ImageInput] = []
        for source in effectiveSources {
            if source == "-" {
                guard let standardInput else {
                    throw InputError.missingSource
                }
                result.append(
                    contentsOf: try parseList(
                        standardInput,
                        relativeTo: currentDirectory,
                        warning: warning
                    )
                )
                continue
            }

            let sourceURL = resolve(source, relativeTo: currentDirectory)
            var isDirectory: ObjCBool = false
            guard
                FileManager.default.fileExists(
                    atPath: sourceURL.path,
                    isDirectory: &isDirectory
                )
            else {
                throw InputError.sourceDoesNotExist(sourceURL.path)
            }

            if isDirectory.boolValue {
                result.append(
                    contentsOf: try loadDirectory(
                        sourceURL,
                        displayBaseURL: sourceURL,
                        warning: warning
                    )
                )
            } else if isSupportedImage(sourceURL) {
                result.append(
                    ImageInput(
                        url: sourceURL,
                        displayBaseURL: sourceURL.deletingLastPathComponent()
                    )
                )
            } else {
                guard let text = try? String(contentsOf: sourceURL, encoding: .utf8) else {
                    throw InputError.cannotReadList(sourceURL.path)
                }
                result.append(
                    contentsOf: try parseList(
                        text,
                        relativeTo: sourceURL.deletingLastPathComponent(),
                        warning: warning
                    )
                )
            }
        }

        guard !result.isEmpty else {
            throw InputError.noUsableImages
        }
        return result
    }

    private func loadDirectory(
        _ directory: URL,
        displayBaseURL: URL,
        warning: @escaping (String) -> Void
    ) throws -> [ImageInput] {
        guard
            let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { url, _ in
                    warning("Skipping inaccessible path: \(url.path)")
                    return true
                }
            )
        else {
            return []
        }

        return enumerator.compactMap { $0 as? URL }
            .filter { url in
                guard isSupportedImage(url) else { return false }
                do {
                    return try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile
                        == true
                } catch {
                    warning("Skipping inaccessible file: \(url.path)")
                    return false
                }
            }
            .sorted { lhs, rhs in
                let leftPath = DisplayPath.relative(from: directory, to: lhs)
                let rightPath = DisplayPath.relative(from: directory, to: rhs)
                let result = leftPath.localizedStandardCompare(rightPath)
                if result == .orderedSame {
                    return lhs.path < rhs.path
                }
                return result == .orderedAscending
            }
            .map { ImageInput(url: $0, displayBaseURL: displayBaseURL) }
    }

    private func parseList(
        _ text: String,
        relativeTo baseURL: URL,
        warning: @escaping (String) -> Void
    ) throws -> [ImageInput] {
        var result: [ImageInput] = []
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            let url = resolve(line, relativeTo: baseURL)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            else {
                warning("Skipping missing path: \(url.path)")
                continue
            }
            if isDirectory.boolValue {
                result.append(
                    contentsOf: try loadDirectory(
                        url,
                        displayBaseURL: baseURL,
                        warning: warning
                    )
                )
                continue
            }
            guard isSupportedImage(url) else {
                warning("Skipping unsupported file: \(url.path)")
                continue
            }
            result.append(ImageInput(url: url, displayBaseURL: baseURL))
        }
        return result
    }

    private func resolve(_ path: String, relativeTo baseURL: URL) -> URL {
        let expanded = NSString(string: path).expandingTildeInPath
        return URL(fileURLWithPath: expanded, relativeTo: baseURL).standardizedFileURL
    }

    private func isSupportedImage(_ url: URL) -> Bool {
        Self.supportedExtensions.contains(url.pathExtension.lowercased())
    }
}
