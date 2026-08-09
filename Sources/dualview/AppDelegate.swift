import AppKit
import DualViewCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let inputs: [ImageInput]
    private var entries: [ImageEntry] = []
    private let fill: Bool
    private let loop: Bool
    private let pathOverlay: PathOverlaySettings?
    private let clickNavigation: Bool
    private let rotation: RotationMode
    private let showProgressBar: Bool
    private var autoAdvanceEnabled: Bool
    private var delay: TimeInterval
    private let decoder = ImageDecoder()
    private var windows: [DisplayWindow] = []
    private var navigator: FrameNavigator?
    private var normalFrames: [FrameState] = []
    private var frameOrder: [Int] = []
    private var randomMode = false
    private var indexing = false
    private var pendingRandomMode = false
    private var previewEntryNumber = 1
    private var metadataEntries: [URL: ImageEntry] = [:]
    private var keyMonitor: Any?
    private var autoAdvanceTimer: Timer?
    private let currentDecodeQueue = DispatchQueue(
        label: "DualView current image decoder",
        qos: .userInitiated,
        attributes: .concurrent
    )
    private let prefetchQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "DualView image prefetch"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .utility
        return queue
    }()
    private var prefetchRequest: DispatchWorkItem?
    private var requestedEntryIndices: [Int?] = [nil, nil]
    private var decodeGenerations: [UInt64] = [0, 0]

    init(
        inputs: [ImageInput],
        fill: Bool,
        loop: Bool,
        pathOverlay: PathOverlaySettings?,
        clickNavigation: Bool,
        rotation: RotationMode,
        showProgressBar: Bool,
        autoAdvance: Bool,
        delay: TimeInterval
    ) {
        self.inputs = inputs
        self.fill = fill
        self.loop = loop
        self.pathOverlay = pathOverlay
        self.clickNavigation = clickNavigation
        self.rotation = rotation
        self.showProgressBar = showProgressBar
        self.autoAdvanceEnabled = autoAdvance
        self.delay = delay
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installApplicationIcon()
        let screens = Self.orderedScreens(Array(NSScreen.screens))
        guard !screens.isEmpty else {
            writeStandardError("dualview could not find an active display.")
            NSApp.terminate(nil)
            return
        }

        if screens.count > 2 {
            writeStandardError(
                "Warning: more than two displays found; using the first two by position.")
        }

        let selected = Array(screens.prefix(2))
        let mode: RoutingMode
        let displayOrder: [NSScreen]

        if selected.count == 1 {
            mode = .single
            displayOrder = selected
        } else if Self.orientation(of: selected[0]) != Self.orientation(of: selected[1]) {
            mode = .byOrientation
            let landscape = selected.first { Self.orientation(of: $0) == .landscape }!
            let portrait = selected.first { Self.orientation(of: $0) == .portrait }!
            displayOrder = [landscape, portrait]
        } else {
            mode = .alternating
            displayOrder = selected
        }

        installMainMenu()
        installKeyMonitor()

        windows = displayOrder.map { DisplayWindow(screen: $0) }
        let overlayFont = pathOverlay?.makeFont {
            writeStandardError("Warning: \($0)")
        }
        for window in windows {
            window.imageView.overlayFont = overlayFont ?? window.imageView.overlayFont
            window.imageView.keyHandler = { [weak self] event in
                _ = self?.handleKey(event)
            }
            if clickNavigation {
                window.imageView.clickHandler = { [weak self] forward in
                    if forward {
                        self?.moveForward()
                    } else {
                        self?.moveBackward()
                    }
                }
            }
        }

        for window in windows {
            window.orderFront(nil)
        }

        NSApp.presentationOptions = [.autoHideDock, .autoHideMenuBar]
        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKeyAndOrderFront(nil)
        windows.first?.makeFirstResponder(windows.first?.imageView)

        if mode == .byOrientation {
            beginMixedDisplayIndexing()
        } else {
            entries = inputs.map(ImageEntry.placeholder(for:))
            installSequence(mode: mode)
            renderCurrentFrame()
            scheduleAutoAdvance()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        prefetchRequest?.cancel()
        prefetchQueue.cancelAllOperations()
        autoAdvanceTimer?.invalidate()
        decodeGenerations = decodeGenerations.map { $0 &+ 1 }
        NSApp.presentationOptions = []
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func installSequence(mode: RoutingMode) {
        let sequence = PresentationSequence(entries: entries, mode: mode, fill: fill)
        normalFrames = sequence.frames
        frameOrder = Array(normalFrames.indices)
        navigator = FrameNavigator(frames: normalFrames, wraps: loop)
        requestedEntryIndices = [nil, nil]
        decodeGenerations = decodeGenerations.map { $0 &+ 1 }
    }

    private func beginMixedDisplayIndexing() {
        indexing = true
        writeStandardError("Indexing \(inputs.count) images in the background…")

        if let preview = inputs.enumerated().lazy.compactMap({ index, input in
            ImageMetadataScanner.scan(input: input).map { (index, $0) }
        }).first {
            previewEntryNumber = preview.0 + 1
            entries = [preview.1]
            metadataEntries[preview.1.url] = preview.1
            let slot = preview.1.orientation == .landscape ? 0 : 1
            normalFrames = [FrameState(slot == 0 ? [0, nil] : [nil, 0])]
            frameOrder = [0]
            navigator = FrameNavigator(frames: normalFrames, wraps: loop)
            renderCurrentFrame()
        }

        let inputs = self.inputs
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let scanned = ImageMetadataScanner.scan(
                inputs: inputs,
                warning: { writeStandardError("Warning: \($0)") }
            )
            DispatchQueue.main.async { [weak self] in
                self?.finishMixedDisplayIndexing(scanned)
            }
        }
    }

    private func finishMixedDisplayIndexing(_ scanned: [ImageEntry]) {
        guard !scanned.isEmpty else {
            writeStandardError("Error: \(InputError.noUsableImages.localizedDescription)")
            NSApp.terminate(nil)
            return
        }

        entries = scanned
        metadataEntries = Dictionary(
            scanned.map { ($0.url, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        indexing = false
        randomMode = false
        installSequence(mode: .byOrientation)
        writeStandardError("Indexing complete: \(scanned.count) images")

        if pendingRandomMode {
            pendingRandomMode = false
            toggleRandomMode()
        } else {
            renderCurrentFrame()
            scheduleAutoAdvance()
        }
    }

    @discardableResult
    private func handleKey(_ event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command),
            event.charactersIgnoringModifiers?.lowercased() == "q"
        {
            NSApp.terminate(nil)
            return true
        }

        let disallowedRandomModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        if event.charactersIgnoringModifiers?.lowercased() == "r",
            event.modifierFlags.intersection(disallowedRandomModifiers).isEmpty,
            !event.isARepeat
        {
            toggleRandomMode()
            return true
        }

        if event.charactersIgnoringModifiers?.lowercased() == "s",
            event.modifierFlags.intersection(disallowedRandomModifiers).isEmpty,
            !event.isARepeat
        {
            toggleAutoAdvance()
            return true
        }

        if event.modifierFlags.intersection(disallowedRandomModifiers).isEmpty,
            let character = event.charactersIgnoringModifiers,
            character.count == 1,
            let digit = character.first?.wholeNumberValue,
            (0...9).contains(digit)
        {
            setDelay(digit == 0 ? 10 : TimeInterval(digit))
            return true
        }

        switch event.keyCode {
        case 53:
            NSApp.terminate(nil)
            return true
        case 51, 116, 123, 126:
            moveBackward()
            return true
        case 36, 76, 121, 124, 125:
            moveForward()
            return true
        case 49:
            if event.modifierFlags.contains(.shift) {
                moveBackward()
            } else {
                moveForward()
            }
            return true
        default:
            return false
        }
    }

    @discardableResult
    private func moveForward(resetAutoAdvance: Bool = true) -> Bool {
        guard !indexing else { return false }
        let previousPosition = navigator?.position
        navigator?.moveForward()
        let changed = previousPosition != navigator?.position
        if changed {
            renderCurrentFrame()
        }
        if resetAutoAdvance {
            scheduleAutoAdvance()
        }
        return changed
    }

    private func moveBackward() {
        guard !indexing else { return }
        navigator?.moveBackward()
        renderCurrentFrame()
        scheduleAutoAdvance()
    }

    private func toggleRandomMode() {
        if indexing {
            pendingRandomMode.toggle()
            writeStandardError(
                "Random permutation after indexing: \(pendingRandomMode ? "on" : "off")"
            )
            return
        }
        guard let navigator, !normalFrames.isEmpty else { return }
        let currentOriginalPosition = frameOrder[navigator.position]

        if randomMode {
            frameOrder = Array(normalFrames.indices)
            self.navigator = FrameNavigator(
                frames: normalFrames,
                wraps: loop,
                startPosition: currentOriginalPosition
            )
            randomMode = false
            writeStandardError("Random permutation: off")
        } else {
            frameOrder = randomizedFrameOrder(
                frameCount: normalFrames.count,
                keeping: currentOriginalPosition
            )
            self.navigator = FrameNavigator(
                frames: frameOrder.map { normalFrames[$0] },
                wraps: loop
            )
            randomMode = true
            writeStandardError("Random permutation: on")
        }

        renderCurrentFrame()
        scheduleAutoAdvance()
    }

    private func scheduleAutoAdvance() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = nil
        guard autoAdvanceEnabled, !indexing else { return }

        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            if self.moveForward(resetAutoAdvance: false) {
                self.scheduleAutoAdvance()
            }
        }
        autoAdvanceTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func toggleAutoAdvance() {
        autoAdvanceEnabled.toggle()
        scheduleAutoAdvance()
        writeStandardError(
            "Auto-advance: \(autoAdvanceEnabled ? "on" : "off") (delay: \(delay) seconds)"
        )
    }

    private func setDelay(_ newDelay: TimeInterval) {
        delay = newDelay
        if autoAdvanceEnabled {
            scheduleAutoAdvance()
        }
        writeStandardError("Auto-advance delay: \(delay) seconds")
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            return self?.handleKey(event) == true ? nil : event
        }
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()
        let applicationItem = NSMenuItem(title: "DualView", action: nil, keyEquivalent: "")
        let applicationMenu = NSMenu()
        applicationMenu.addItem(
            withTitle: "Quit DualView",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)
        NSApp.mainMenu = mainMenu
    }

    private func installApplicationIcon() {
        guard let iconURL = Bundle.main.url(forResource: "DualView", withExtension: "icns"),
            let icon = NSImage(contentsOf: iconURL)
        else {
            return
        }
        NSApp.applicationIconImage = icon
    }

    private func renderCurrentFrame() {
        guard let state = navigator?.current else { return }
        updateProgressBar()

        for (slot, window) in windows.enumerated() {
            guard let entryIndex = state.entryIndices[slot] else {
                decodeGenerations[slot] &+= 1
                requestedEntryIndices[slot] = nil
                window.imageView.rotation = emptySlotRotation
                window.imageView.image = nil
                window.imageView.overlayText = nil
                continue
            }

            guard requestedEntryIndices[slot] != entryIndex else {
                continue
            }

            requestedEntryIndices[slot] = entryIndex
            decodeGenerations[slot] &+= 1
            let generation = decodeGenerations[slot]

            let pixelSize = targetPixelSize(for: window)
            let entry = entries[entryIndex]
            let knownMetadata = metadataEntries[entry.url]
            let needsMetadata: Bool
            if case .toFill = rotation {
                needsMetadata = knownMetadata == nil
            } else {
                needsMetadata = false
            }

            if let cached = decoder.cachedImage(for: entry, maxPixelSize: pixelSize) {
                if needsMetadata {
                    currentDecodeQueue.async { [weak self] in
                        let metadata = ImageMetadataScanner.scan(
                            input: ImageInput(
                                url: entry.url,
                                displayBaseURL: entry.displayBaseURL
                            )
                        )
                        DispatchQueue.main.async { [weak self] in
                            guard let self,
                                self.decodeGenerations[slot] == generation,
                                self.requestedEntryIndices[slot] == entryIndex
                            else {
                                return
                            }
                            if let metadata {
                                self.metadataEntries[entry.url] = metadata
                            }
                            self.display(
                                cached,
                                entryIndex: entryIndex,
                                in: slot,
                                rotationEntry: metadata ?? entry
                            )
                        }
                    }
                } else {
                    display(
                        cached,
                        entryIndex: entryIndex,
                        in: slot,
                        rotationEntry: knownMetadata ?? entry
                    )
                }
                continue
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) { [weak self] in
                guard let self,
                    self.decodeGenerations[slot] == generation,
                    self.requestedEntryIndices[slot] == entryIndex
                else {
                    return
                }
                self.currentDecodeQueue.async { [weak self] in
                    guard let self else { return }
                    let metadata =
                        needsMetadata
                        ? ImageMetadataScanner.scan(
                            input: ImageInput(
                                url: entry.url,
                                displayBaseURL: entry.displayBaseURL
                            )
                        ) : knownMetadata
                    let image = self.decoder.image(for: entry, maxPixelSize: pixelSize)

                    DispatchQueue.main.async { [weak self] in
                        guard let self,
                            self.decodeGenerations[slot] == generation,
                            self.requestedEntryIndices[slot] == entryIndex
                        else {
                            return
                        }
                        if let metadata {
                            self.metadataEntries[entry.url] = metadata
                        }
                        self.display(
                            image,
                            entryIndex: entryIndex,
                            in: slot,
                            rotationEntry: metadata ?? entry
                        )
                        if image == nil {
                            writeStandardError("Could not decode image: \(entry.url.path)")
                        }
                    }
                }
            }
        }

        schedulePrefetch()
    }

    private func display(
        _ image: NSImage?,
        entryIndex: Int,
        in slot: Int,
        rotationEntry: ImageEntry
    ) {
        windows[slot].imageView.rotation = appliedRotation(
            for: rotationEntry,
            in: windows[slot]
        )
        windows[slot].imageView.image = image
        windows[slot].imageView.overlayText =
            image == nil
            ? nil
            : pathOverlay?.text(
                for: entries[entryIndex],
                entryNumber: indexing ? previewEntryNumber : entryIndex + 1,
                total: indexing ? inputs.count : entries.count
            )
    }

    private func appliedRotation(for entry: ImageEntry, in window: DisplayWindow) -> QuarterTurn {
        switch rotation {
        case .none:
            return .none
        case .always(let turn):
            return turn
        case .toFill(let turn):
            let screenOrientation: ImageOrientation =
                window.frame.width >= window.frame.height ? .landscape : .portrait
            return entry.shouldRotate(toMatch: screenOrientation) ? turn : .none
        }
    }

    private var emptySlotRotation: QuarterTurn {
        if case .always(let turn) = rotation {
            return turn
        }
        return .none
    }

    private func updateProgressBar() {
        guard !indexing, showProgressBar, let navigator, !navigator.frames.isEmpty else {
            windows.first?.imageView.progressFraction = nil
            return
        }
        windows.first?.imageView.progressFraction =
            CGFloat(navigator.position + 1) / CGFloat(navigator.frames.count)
    }

    private func schedulePrefetch() {
        prefetchRequest?.cancel()
        guard let navigator else { return }

        let position = navigator.position
        let neighboringPositions = [
            position + 1,
            position + 2,
            position + 3,
            position - 1,
            position - 2,
        ].filter {
            navigator.frames.indices.contains($0)
        }
        guard !neighboringPositions.isEmpty else { return }

        let request = DispatchWorkItem { [weak self] in
            self?.prefetch(neighboringPositions: neighboringPositions)
        }
        prefetchRequest = request
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: request)
    }

    private func prefetch(neighboringPositions: [Int]) {
        guard let navigator else { return }
        prefetchQueue.cancelAllOperations()

        let currentKeys = Set(
            requestedEntryIndices.enumerated().compactMap {
                slot, possibleEntryIndex -> String? in
                guard let entryIndex = possibleEntryIndex else { return nil }
                let entry = entries[entryIndex]
                let pixelSize = targetPixelSize(for: windows[slot])
                return "\(entry.url.path)#\(pixelSize)"
            })
        var scheduledKeys = Set<String>()
        for position in neighboringPositions {
            let state = navigator.frames[position]
            for (slot, possibleEntryIndex) in state.entryIndices.enumerated() {
                guard windows.indices.contains(slot), let entryIndex = possibleEntryIndex else {
                    continue
                }
                let entry = entries[entryIndex]
                let pixelSize = targetPixelSize(for: windows[slot])
                let key = "\(entry.url.path)#\(pixelSize)"
                guard !currentKeys.contains(key),
                    scheduledKeys.insert(key).inserted,
                    decoder.cachedImage(for: entry, maxPixelSize: pixelSize) == nil
                else {
                    continue
                }

                prefetchQueue.addOperation { [weak self] in
                    _ = self?.decoder.image(for: entry, maxPixelSize: pixelSize)
                }
            }
        }
    }

    private func targetPixelSize(for window: NSWindow) -> Int {
        let scale = window.screen?.backingScaleFactor ?? 1
        return Int(max(window.frame.width, window.frame.height) * scale)
    }

    private static func orderedScreens(_ screens: [NSScreen]) -> [NSScreen] {
        screens.sorted { lhs, rhs in
            if lhs.frame.minX != rhs.frame.minX {
                return lhs.frame.minX < rhs.frame.minX
            }
            return lhs.frame.maxY > rhs.frame.maxY
        }
    }

    private static func orientation(of screen: NSScreen) -> ImageOrientation {
        screen.frame.width >= screen.frame.height ? .landscape : .portrait
    }
}
