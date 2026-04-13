@testable import Core
import KanaKanjiConverterModule
import Testing

@Test func backslashStartsJuliaModeFromNone() async throws {
    let (action, callback) = InputState.none.event(
        eventCore: .init(
            modifierFlags: [],
            characters: "\\",
            charactersIgnoringModifiers: "\\",
            keyCode: 42
        ),
        userAction: .input([.character("\\")]),
        inputLanguage: .japanese,
        liveConversionEnabled: false,
        enableDebugWindow: false,
        enableSuggestion: false
    )
    #expect(action == .enterJuliaUnicodeMode(initialBuffer: "\\"))
    #expect(callback == .transition(.juliaComposing))
}

@Test func spaceMovesJuliaCandidateFromComposing() async throws {
    let (action, callback) = InputState.juliaComposing.event(
        eventCore: .init(modifierFlags: [], characters: " ", charactersIgnoringModifiers: " ", keyCode: 49),
        userAction: .space(prefersFullWidthWhenInput: false),
        inputLanguage: .japanese,
        liveConversionEnabled: false,
        enableDebugWindow: false,
        enableSuggestion: false
    )
    #expect(action == .moveJuliaUnicodeCandidate(1))
    #expect(callback == .transition(.juliaSelecting))
}

@Test func backspaceDeletesJuliaBufferFromSelecting() async throws {
    let (action, callback) = InputState.juliaSelecting.event(
        eventCore: .init(modifierFlags: [], characters: nil, charactersIgnoringModifiers: nil, keyCode: 51),
        userAction: .backspace,
        inputLanguage: .japanese,
        liveConversionEnabled: false,
        enableDebugWindow: false,
        enableSuggestion: false
    )
    #expect(action == .deleteBackwardFromJuliaUnicodeBuffer)
    #expect(callback == .transition(.juliaComposing))
}
