import Core

struct JuliaUnicodeSession {
    private var resolver: JuliaUnicodeResolver

    var buffer: String = ""
    var selectedIndex: Int = 0
    var matches: [JuliaUnicodeEntry] = []

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

    func commitText(for input: String) -> String? {
        self.resolver.resolveExact(input)?.text
    }
}
