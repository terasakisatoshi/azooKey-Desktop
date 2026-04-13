@testable import Core
import Foundation
import KanaKanjiConverterModule
import Testing

private func rawInputString(from action: UserAction) -> String? {
    guard case .input(let pieces) = action else {
        return nil
    }
    return pieces.inputString(preferIntention: false)
}

@Test func backslashKeyStartsJuliaModeFromNone() async throws {
    let defaults = UserDefaults.standard
    let key = Config.TypeBackSlash.key
    let originalData = defaults.data(forKey: key)
    defer {
        if let data = originalData {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    Config.TypeBackSlash().value = true

    let userAction = UserAction.getUserAction(
        eventCore: .init(
            modifierFlags: [],
            characters: "\\",
            charactersIgnoringModifiers: "\\",
            keyCode: 42
        ),
        inputLanguage: .japanese
    )
    #expect(rawInputString(from: userAction) == "\\")

    let (action, callback) = InputState.none.event(
        eventCore: .init(
            modifierFlags: [],
            characters: "\\",
            charactersIgnoringModifiers: "\\",
            keyCode: 42
        ),
        userAction: userAction,
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

@Test func backslashStartsJuliaModeFromComposing() async throws {
    let (action, callback) = InputState.composing.event(
        eventCore: .init(
            modifierFlags: [],
            characters: "\\",
            charactersIgnoringModifiers: "\\",
            keyCode: 42
        ),
        userAction: UserAction.getUserAction(
            eventCore: .init(
                modifierFlags: [],
                characters: "\\",
                charactersIgnoringModifiers: "\\",
                keyCode: 42
            ),
            inputLanguage: .japanese
        ),
        inputLanguage: .japanese,
        liveConversionEnabled: false,
        enableDebugWindow: false,
        enableSuggestion: false
    )
    #expect(action == .commitMarkedTextAndEnterJuliaUnicodeMode(initialBuffer: "\\"))
    #expect(callback == .transition(.juliaComposing))
}

@Test func backslashStartsJuliaModeFromPreviewing() async throws {
    let (action, callback) = InputState.previewing.event(
        eventCore: .init(
            modifierFlags: [],
            characters: "\\",
            charactersIgnoringModifiers: "\\",
            keyCode: 42
        ),
        userAction: UserAction.getUserAction(
            eventCore: .init(
                modifierFlags: [],
                characters: "\\",
                charactersIgnoringModifiers: "\\",
                keyCode: 42
            ),
            inputLanguage: .japanese
        ),
        inputLanguage: .japanese,
        liveConversionEnabled: false,
        enableDebugWindow: false,
        enableSuggestion: false
    )
    #expect(action == .commitMarkedTextAndEnterJuliaUnicodeMode(initialBuffer: "\\"))
    #expect(callback == .transition(.juliaComposing))
}

@Test func backslashStartsJuliaModeFromSelecting() async throws {
    let (action, callback) = InputState.selecting.event(
        eventCore: .init(
            modifierFlags: [],
            characters: "\\",
            charactersIgnoringModifiers: "\\",
            keyCode: 42
        ),
        userAction: UserAction.getUserAction(
            eventCore: .init(
                modifierFlags: [],
                characters: "\\",
                charactersIgnoringModifiers: "\\",
                keyCode: 42
            ),
            inputLanguage: .japanese
        ),
        inputLanguage: .japanese,
        liveConversionEnabled: false,
        enableDebugWindow: false,
        enableSuggestion: false
    )
    #expect(action == .submitSelectedCandidateAndEnterJuliaUnicodeMode(initialBuffer: "\\"))
    #expect(callback == .transition(.juliaComposing))
}

@Test func backslashStartsJuliaModeFromReplaceSuggestion() async throws {
    let (action, callback) = InputState.replaceSuggestion.event(
        eventCore: .init(
            modifierFlags: [],
            characters: "\\",
            charactersIgnoringModifiers: "\\",
            keyCode: 42
        ),
        userAction: UserAction.getUserAction(
            eventCore: .init(
                modifierFlags: [],
                characters: "\\",
                charactersIgnoringModifiers: "\\",
                keyCode: 42
            ),
            inputLanguage: .japanese
        ),
        inputLanguage: .japanese,
        liveConversionEnabled: false,
        enableDebugWindow: false,
        enableSuggestion: false
    )
    #expect(action == .commitMarkedTextAndEnterJuliaUnicodeMode(initialBuffer: "\\"))
    #expect(callback == .transition(.juliaComposing))
}
