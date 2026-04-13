import Core

struct JuliaUnicodeSession {
    private var resolver: JuliaUnicodeResolver

    var buffer: String = ""
    var selectedIndex: Int = 0
    var matches: [JuliaUnicodeEntry] = []

    struct ActionResult: Sendable, Equatable {
        var updatedBuffer: String
        var commitText: String?
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
            return .init(updatedBuffer: "", commitText: exact.text)
        }

        let prefix = Self.commonPrefix(of: matches.map(\.trigger))
        if prefix.count > buffer.count {
            return .init(updatedBuffer: prefix, commitText: nil)
        }

        return .init(updatedBuffer: buffer, commitText: nil)
    }

    static func enterAction(
        buffer: String,
        selectedIndex: Int?,
        resolver: JuliaUnicodeResolver
    ) -> ActionResult {
        let matches = resolver.resolveMatches(buffer)
        if let selectedIndex, matches.indices.contains(selectedIndex) {
            return .init(updatedBuffer: "", commitText: matches[selectedIndex].text)
        }

        if let exact = resolver.resolveExact(buffer) {
            return .init(updatedBuffer: "", commitText: exact.text)
        }

        return .init(updatedBuffer: "", commitText: buffer)
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
