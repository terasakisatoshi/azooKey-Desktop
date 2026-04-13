import Core

struct JuliaUnicodeSession {
    private var resolver: JuliaUnicodeResolver

    var buffer: String = ""
    var selectedIndex: Int = 0
    var matches: [JuliaUnicodeEntry] = []

    enum Mode: Sendable, Equatable {
        case composing
        case selecting
        case none
    }

    enum Command: Sendable, Equatable {
        case tab
        case nextCandidate
        case previousCandidate
        case enter
        case cancel
    }

    struct ActionResult: Sendable, Equatable {
        var updatedBuffer: String
        var commitText: String?
        var mode: Mode
    }

    init(resolver: JuliaUnicodeResolver = .standard) {
        self.resolver = resolver
    }

    var selectedEntry: JuliaUnicodeEntry? {
        guard self.matches.indices.contains(self.selectedIndex) else {
            return nil
        }
        return self.matches[self.selectedIndex]
    }

    mutating func replaceBuffer(_ newValue: String) {
        self.buffer = newValue
        self.matches = self.resolver.resolveMatches(newValue)
        self.selectedIndex = min(self.selectedIndex, max(self.matches.count - 1, 0))
    }

    mutating func replaceBuffer(_ newValue: String, resolver: JuliaUnicodeResolver) {
        self.resolver = resolver
        self.replaceBuffer(newValue)
    }

    mutating func append(_ value: String) {
        self.replaceBuffer(self.buffer + value)
    }

    mutating func deleteBackward() {
        guard !self.buffer.isEmpty else {
            return
        }
        self.replaceBuffer(String(self.buffer.dropLast()))
    }

    mutating func moveSelection(by offset: Int) {
        guard !self.matches.isEmpty else {
            return
        }
        let nextIndex = self.selectedIndex + offset
        self.selectedIndex = min(max(nextIndex, 0), self.matches.count - 1)
    }

    mutating func reset() {
        self.buffer = ""
        self.selectedIndex = 0
        self.matches = []
    }

    mutating func perform(_ command: Command) -> ActionResult {
        switch command {
        case .tab:
            let result = Self.tabAction(buffer: self.buffer, resolver: self.resolver)
            if let commitText = result.commitText {
                self.reset()
                return .init(updatedBuffer: "", commitText: commitText, mode: .none)
            }

            if result.updatedBuffer != self.buffer {
                self.replaceBuffer(result.updatedBuffer)
                self.selectedIndex = 0
                return .init(updatedBuffer: result.updatedBuffer, commitText: nil, mode: .composing)
            }

            if self.matches.isEmpty {
                return .init(updatedBuffer: self.buffer, commitText: nil, mode: .composing)
            }

            self.selectedIndex = min(self.selectedIndex, max(self.matches.count - 1, 0))
            return .init(updatedBuffer: self.buffer, commitText: nil, mode: .selecting)
        case .nextCandidate:
            guard !self.matches.isEmpty else {
                return .init(updatedBuffer: self.buffer, commitText: nil, mode: .composing)
            }
            self.moveSelection(by: 1)
            return .init(updatedBuffer: self.buffer, commitText: nil, mode: .selecting)
        case .previousCandidate:
            guard !self.matches.isEmpty else {
                return .init(updatedBuffer: self.buffer, commitText: nil, mode: .composing)
            }
            self.moveSelection(by: -1)
            return .init(updatedBuffer: self.buffer, commitText: nil, mode: .selecting)
        case .enter:
            let result = Self.enterAction(
                buffer: self.buffer,
                selectedIndex: self.matches.indices.contains(self.selectedIndex) ? self.selectedIndex : nil,
                resolver: self.resolver
            )
            self.reset()
            return .init(updatedBuffer: "", commitText: result.commitText, mode: .none)
        case .cancel:
            self.reset()
            return .init(updatedBuffer: "", commitText: nil, mode: .none)
        }
    }

    mutating func tabAction() -> ActionResult {
        let result = Self.tabAction(buffer: self.buffer, resolver: self.resolver)
        if result.commitText != nil {
            self.reset()
            return result
        }

        self.replaceBuffer(result.updatedBuffer)
        self.selectedIndex = 0
        return result
    }

    static func tabAction(buffer: String, resolver: JuliaUnicodeResolver) -> ActionResult {
        let matches = resolver.resolveMatches(buffer)
        if let exact = resolver.resolveExact(buffer) {
            return .init(updatedBuffer: "", commitText: exact.text, mode: .none)
        }

        let prefix = Self.commonPrefix(of: matches.map(\.trigger))
        if prefix.count > buffer.count {
            return .init(updatedBuffer: prefix, commitText: nil, mode: .composing)
        }

        if matches.isEmpty {
            return .init(updatedBuffer: buffer, commitText: nil, mode: .composing)
        }

        return .init(updatedBuffer: buffer, commitText: nil, mode: .selecting)
    }

    static func enterAction(
        buffer: String,
        selectedIndex: Int?,
        resolver: JuliaUnicodeResolver
    ) -> ActionResult {
        let matches = resolver.resolveMatches(buffer)
        if let selectedIndex, matches.indices.contains(selectedIndex) {
            return .init(updatedBuffer: "", commitText: matches[selectedIndex].text, mode: .none)
        }

        if let exact = resolver.resolveExact(buffer) {
            return .init(updatedBuffer: "", commitText: exact.text, mode: .none)
        }

        return .init(updatedBuffer: "", commitText: buffer, mode: .none)
    }

    func commitText(for input: String, preferSelectedEntry: Bool = false) -> String? {
        if preferSelectedEntry, let selectedEntry {
            return selectedEntry.text
        }

        return self.resolver.resolveExact(input)?.text ?? self.selectedEntry?.text ?? input
    }

    mutating func commitTextAndReset(for input: String, preferSelectedEntry: Bool = false) -> String? {
        defer {
            self.reset()
        }
        return self.commitText(for: input, preferSelectedEntry: preferSelectedEntry)
    }

    private static func commonPrefix(of strings: [String]) -> String {
        guard var prefix = strings.first else {
            return ""
        }

        for string in strings.dropFirst() {
            prefix = String(prefix.commonPrefix(with: string))
            if prefix.isEmpty {
                break
            }
        }

        return prefix
    }
}
