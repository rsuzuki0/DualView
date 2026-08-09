import Foundation

public enum DisplayPath {
    public static func relative(from baseURL: URL, to targetURL: URL) -> String {
        let baseComponents = baseURL.standardizedFileURL.pathComponents
        let targetComponents = targetURL.standardizedFileURL.pathComponents
        var sharedCount = 0

        while sharedCount < baseComponents.count,
            sharedCount < targetComponents.count,
            baseComponents[sharedCount] == targetComponents[sharedCount]
        {
            sharedCount += 1
        }

        let upward = Array(repeating: "..", count: baseComponents.count - sharedCount)
        let downward = Array(targetComponents.dropFirst(sharedCount))
        let components = upward + downward
        return components.isEmpty ? targetURL.lastPathComponent : components.joined(separator: "/")
    }
}
