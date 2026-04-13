public struct JuliaUnicodeEntry: Sendable, Equatable {
    public var trigger: String
    public var text: String

    public init(trigger: String, text: String) {
        self.trigger = trigger
        self.text = text
    }
}
