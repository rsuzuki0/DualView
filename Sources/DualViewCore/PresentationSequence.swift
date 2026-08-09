import Foundation

public enum RoutingMode: Equatable, Sendable {
    case single
    case byOrientation
    case alternating
}

public struct FrameState: Equatable, Sendable {
    public let entryIndices: [Int?]

    public init(_ entryIndices: [Int?]) {
        precondition(entryIndices.count == 2)
        self.entryIndices = entryIndices
    }
}

public struct PresentationSequence: Sendable {
    public let frames: [FrameState]

    public init(entries: [ImageEntry], mode: RoutingMode, fill: Bool) {
        guard !entries.isEmpty else {
            frames = []
            return
        }

        switch (mode, fill) {
        case (.single, _):
            frames = entries.indices.map { FrameState([$0, nil]) }
        case (.alternating, true):
            frames = Self.makeFilledAlternating(entries: entries)
        case (.byOrientation, true):
            frames = Self.makeFilledByOrientation(entries: entries)
        default:
            frames = Self.makeSequential(entries: entries, mode: mode)
        }
    }

    private static func makeSequential(
        entries: [ImageEntry],
        mode: RoutingMode
    ) -> [FrameState] {
        var slots: [Int?] = [nil, nil]
        return entries.indices.map { index in
            slots[slot(for: index, entry: entries[index], mode: mode)] = index
            return FrameState(slots)
        }
    }

    private static func makeFilledAlternating(entries: [ImageEntry]) -> [FrameState] {
        var slots: [Int?] = [0, nil]
        var nextIndex = 1
        if entries.count > 1 {
            slots[1] = 1
            nextIndex = 2
        }

        var result = [FrameState(slots)]
        for index in nextIndex..<entries.count {
            slots[index % 2] = index
            result.append(FrameState(slots))
        }
        return result
    }

    private static func makeFilledByOrientation(entries: [ImageEntry]) -> [FrameState] {
        var slots: [Int?] = [nil, nil]
        let firstSlot = slot(for: 0, entry: entries[0], mode: .byOrientation)
        slots[firstSlot] = 0

        let missingSlot = 1 - firstSlot
        if let fillIndex = entries.indices.dropFirst().first(where: {
            slot(for: $0, entry: entries[$0], mode: .byOrientation) == missingSlot
        }) {
            slots[missingSlot] = fillIndex
        }

        var result = [FrameState(slots)]
        for index in entries.indices.dropFirst() {
            let target = slot(for: index, entry: entries[index], mode: .byOrientation)
            slots[target] = index
            result.append(FrameState(slots))
        }
        return result
    }

    private static func slot(
        for index: Int,
        entry: ImageEntry,
        mode: RoutingMode
    ) -> Int {
        switch mode {
        case .single:
            return 0
        case .alternating:
            return index % 2
        case .byOrientation:
            return entry.orientation == .landscape ? 0 : 1
        }
    }
}

public final class FrameNavigator {
    public let frames: [FrameState]
    public private(set) var position: Int
    public let wraps: Bool

    public init(frames: [FrameState], wraps: Bool = false, startPosition: Int = 0) {
        self.frames = frames
        if frames.isEmpty {
            self.position = 0
        } else {
            self.position = min(max(0, startPosition), frames.count - 1)
        }
        self.wraps = wraps
    }

    public var current: FrameState? {
        frames.indices.contains(position) ? frames[position] : nil
    }

    @discardableResult
    public func moveForward() -> FrameState? {
        guard !frames.isEmpty else { return nil }
        if position + 1 < frames.count {
            position += 1
        } else if wraps {
            position = 0
        }
        return current
    }

    @discardableResult
    public func moveBackward() -> FrameState? {
        guard !frames.isEmpty else { return nil }
        if position > 0 {
            position -= 1
        } else if wraps {
            position = frames.count - 1
        }
        return current
    }
}

public func randomizedFrameOrder(frameCount: Int, keeping current: Int) -> [Int] {
    guard frameCount > 0, (0..<frameCount).contains(current) else { return [] }
    var remaining = Array(0..<frameCount).filter { $0 != current }
    remaining.shuffle()
    return [current] + remaining
}
