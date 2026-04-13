# azooKey Julia Unicode Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Julia REPL-style backslash Unicode completion to azooKey without disturbing normal Japanese conversion, triggered only by direct `\` input.

**Architecture:** Keep kana-kanji conversion in `SegmentsManager` unchanged and add a controller-managed Julia completion session backed by pure Core resolver code. Use the existing candidate window and marked-text refresh paths, but branch them when the active mode is Julia composing/selecting.

**Tech Stack:** Swift 6.1, SwiftPM (`Core`), InputMethodKit, azooKey candidate window UI, generated Julia symbol tables from `extern/julia`.

---

### Task 1: Add generated Julia symbol sources and pure resolver types

**Files:**
- Create: `Core/Sources/Core/InputUtils/JuliaUnicode/JuliaUnicodeEntry.swift`
- Create: `Core/Sources/Core/InputUtils/JuliaUnicode/JuliaUnicodeResolver.swift`
- Create: `Core/Sources/Core/InputUtils/JuliaUnicode/JuliaUnicodeNormalizer.swift`
- Create: `Core/Sources/Core/InputUtils/JuliaUnicode/Generated/JuliaLatexSymbolMap.swift`
- Create: `Core/Sources/Core/InputUtils/JuliaUnicode/Generated/JuliaEmojiSymbolMap.swift`
- Create: `tools/generate_julia_unicode_symbols.swift`
- Test: `Core/Tests/CoreTests/InputUtilsTests/JuliaUnicodeResolverTests.swift`

**Step 1: Write the failing resolver tests**

```swift
@testable import Core
import Testing

@Test func juliaResolverExactMatchAlpha() async throws {
    let resolver = JuliaUnicodeResolver.standard
    #expect(resolver.resolveExact("\\alpha")?.text == "α")
}

@Test func juliaResolverPrefixEmoji() async throws {
    let resolver = JuliaUnicodeResolver.standard
    #expect(resolver.resolveMatches("\\:ko").contains { $0.trigger == "\\:koala:" })
}

@Test func juliaResolverSuperscriptRun() async throws {
    let resolver = JuliaUnicodeResolver.standard
    #expect(resolver.resolveExact("\\^(123)n")?.text == "⁽¹²³⁾ⁿ")
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --package-path ./Core --filter JuliaUnicodeResolverTests`
Expected: FAIL because the resolver types and generated symbol maps do not exist yet.

**Step 3: Write minimal implementation**

```swift
public struct JuliaUnicodeEntry: Sendable, Equatable {
    public var trigger: String
    public var text: String
}

public struct JuliaUnicodeResolver: Sendable {
    public static let standard = JuliaUnicodeResolver()

    public func resolveExact(_ input: String) -> JuliaUnicodeEntry? { /* exact + super/sub */ }
    public func resolveMatches(_ input: String) -> [JuliaUnicodeEntry] { /* prefix matches */ }
}
```

Use `JuliaUnicodeNormalizer` to map `＼` to `\` and lowercase ASCII trigger text. Generate `JuliaLatexSymbolMap.swift` and `JuliaEmojiSymbolMap.swift` from `extern/julia/stdlib/REPL/src/latex_symbols.jl` and `extern/julia/stdlib/REPL/src/emoji_symbols.jl`, and implement Julia-style `\^...` / `\_...` expansion with dedicated lookup tables instead of enumerating every run.

**Step 4: Run test to verify it passes**

Run: `swift test --package-path ./Core --filter JuliaUnicodeResolverTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Core/Sources/Core/InputUtils/JuliaUnicode Core/Tests/CoreTests/InputUtilsTests/JuliaUnicodeResolverTests.swift tools/generate_julia_unicode_symbols.swift
git commit -m "feat: add Julia Unicode resolver"
```

### Task 2: Add Julia completion mode to the input state machine

**Files:**
- Modify: `Core/Sources/Core/InputUtils/InputState.swift`
- Modify: `Core/Sources/Core/InputUtils/Actions/ClientAction.swift`
- Modify: `Core/Sources/Core/InputUtils/Actions/UserAction.swift`
- Test: `Core/Tests/CoreTests/InputUtilsTests/JuliaUnicodeInputStateTests.swift`

**Step 1: Write the failing state tests**

```swift
@testable import Core
import Testing

@Test func backslashStartsJuliaModeFromNone() async throws {
    let (action, callback) = InputState.none.event(
        eventCore: .init(modifierFlags: [], characters: "\\\\", charactersIgnoringModifiers: "\\\\", keyCode: 42),
        userAction: .input([.character("\\\\")]),
        inputLanguage: .japanese,
        liveConversionEnabled: false,
        enableDebugWindow: false,
        enableSuggestion: false
    )
    #expect(action == .enterJuliaUnicodeMode(initialBuffer: "\\\\"))
    #expect(callback == .transition(.juliaComposing))
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --package-path ./Core --filter JuliaUnicodeInputStateTests`
Expected: FAIL because Julia mode actions and states do not exist.

**Step 3: Write minimal implementation**

```swift
public enum InputState: Sendable, Hashable {
    case none
    case attachDiacritic(String)
    case composing
    case previewing
    case selecting
    case replaceSuggestion
    case unicodeInput(String)
    case juliaComposing
    case juliaSelecting
}

public enum ClientAction {
    case enterJuliaUnicodeMode(initialBuffer: String)
    case appendToJuliaUnicodeBuffer(String)
    case deleteBackwardFromJuliaUnicodeBuffer
    case moveJuliaUnicodeCandidate(Int)
    case submitJuliaUnicodeSelection
    case cancelJuliaUnicodeMode
    // existing cases...
}
```

Update `UserAction.getUserAction` only if needed to preserve direct backslash identity; keep `\` as a regular `.input`, not a new shortcut. In `InputState.event`, make `\` the only entry point into Julia mode and map `Tab` / `Space` / arrow / `Enter` / `Escape` / `Backspace` to Julia-specific actions while the mode is active.

**Step 4: Run test to verify it passes**

Run: `swift test --package-path ./Core --filter JuliaUnicodeInputStateTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Core/Sources/Core/InputUtils/InputState.swift Core/Sources/Core/InputUtils/Actions/ClientAction.swift Core/Sources/Core/InputUtils/Actions/UserAction.swift Core/Tests/CoreTests/InputUtilsTests/JuliaUnicodeInputStateTests.swift
git commit -m "feat: add Julia Unicode input states"
```

### Task 3: Integrate Julia session handling into the macOS input controller

**Files:**
- Create: `azooKeyMac/InputController/JuliaUnicodeSession.swift`
- Modify: `azooKeyMac/InputController/azooKeyMacInputController.swift`
- Modify: `azooKeyMac/InputController/CandidateWindow/CandidateView.swift`
- Modify: `azooKeyMac/InputController/azooKeyMacInputControllerHelper.swift`

**Step 1: Write the failing integration-focused app tests or compile-target assertions**

```swift
// azooKeyMacTests/JuliaUnicodeSessionTests.swift
@testable import azooKeyMac
import XCTest

final class JuliaUnicodeSessionTests: XCTestCase {
    func testTabCommitsExactJuliaMatch() {
        let session = JuliaUnicodeSession(resolver: .standard)
        XCTAssertEqual(session.commitText(for: "\\alpha"), "α")
    }
}
```

If direct app-level unit coverage is impractical, write the test first and allow it to be a build-only smoke target while integration code is added.

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project ./azooKeyMac.xcodeproj -scheme azooKeyMac -destination 'platform=macOS' -only-testing:azooKeyMacTests/JuliaUnicodeSessionTests`
Expected: FAIL because `JuliaUnicodeSession` and controller hooks do not exist yet.

**Step 3: Write minimal implementation**

```swift
struct JuliaUnicodeSession {
    var buffer: String = ""
    var selectedIndex: Int = 0
    var matches: [JuliaUnicodeEntry] = []

    mutating func replaceBuffer(_ newValue: String, resolver: JuliaUnicodeResolver) {
        buffer = newValue
        matches = resolver.resolveMatches(newValue)
        selectedIndex = min(selectedIndex, max(matches.count - 1, 0))
    }
}
```

In `azooKeyMacInputController`:

- store `private var juliaSession = JuliaUnicodeSession()`
- special-case Julia actions in `handleClientAction`
- special-case Julia mode in `refreshMarkedText`
- special-case Julia mode in `refreshCandidateWindow`
- update `candidateSubmitted()` and `candidateSelectionChanged(_:)` to route to Julia selection when `inputState` is `.juliaSelecting`

Do not push Julia candidates through `SegmentsManager`; instead build `CandidatePresentation` values directly in the controller:

```swift
let candidate = Candidate(
    text: entry.text,
    value: 0,
    composingCount: .surfaceCount(entry.text.count),
    lastMid: 0,
    data: []
)
let presentation = CandidatePresentation(
    candidate: candidate,
    displayContext: .init(annotationText: entry.trigger)
)
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project ./azooKeyMac.xcodeproj -scheme azooKeyMac -destination 'platform=macOS' -only-testing:azooKeyMacTests/JuliaUnicodeSessionTests`
Expected: PASS

**Step 5: Commit**

```bash
git add azooKeyMac/InputController/JuliaUnicodeSession.swift azooKeyMac/InputController/azooKeyMacInputController.swift azooKeyMac/InputController/CandidateWindow/CandidateView.swift azooKeyMac/InputController/azooKeyMacInputControllerHelper.swift azooKeyMacTests/JuliaUnicodeSessionTests.swift
git commit -m "feat: integrate Julia Unicode session into IME"
```

### Task 4: Wire `Tab` / `Space` / `Enter` behavior to match Julia REPL semantics

**Files:**
- Modify: `Core/Sources/Core/InputUtils/InputState.swift`
- Modify: `azooKeyMac/InputController/JuliaUnicodeSession.swift`
- Test: `Core/Tests/CoreTests/InputUtilsTests/JuliaUnicodeInputStateTests.swift`
- Test: `azooKeyMacTests/JuliaUnicodeSessionTests.swift`

**Step 1: Write the failing behavior tests**

```swift
@Test func tabExpandsUniquePrefixBeforeSelection() async throws {
    let resolver = JuliaUnicodeResolver.standard
    let result = JuliaUnicodeSession.tabAction(buffer: "\\alp", resolver: resolver)
    #expect(result.updatedBuffer == "\\alpha")
    #expect(result.commitText == nil)
}

@Test func enterFallsBackToLiteralWhenNoJuliaMatchExists() async throws {
    let resolver = JuliaUnicodeResolver.standard
    let result = JuliaUnicodeSession.enterAction(buffer: "\\notasymbol", selectedIndex: nil, resolver: resolver)
    #expect(result.commitText == "\\notasymbol")
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --package-path ./Core --filter JuliaUnicodeInputStateTests`
Run: `xcodebuild test -project ./azooKeyMac.xcodeproj -scheme azooKeyMac -destination 'platform=macOS' -only-testing:azooKeyMacTests/JuliaUnicodeSessionTests`
Expected: FAIL because `Tab` expansion and literal fallback logic are incomplete.

**Step 3: Write minimal implementation**

Implement Julia REPL-like behavior:

- `Tab`: exact match -> commit, single prefix/common prefix -> extend buffer, otherwise enter selecting
- `Space`: if matches exist, enter/select next candidate
- `Shift+Space` / `Up`: previous candidate
- `Enter`: selected candidate > exact match > literal buffer
- `Escape`: discard Julia session and close candidate window

Keep this logic in `JuliaUnicodeSession` so it remains testable without IMK.

**Step 4: Run test to verify it passes**

Run: `swift test --package-path ./Core --filter JuliaUnicodeInputStateTests`
Run: `xcodebuild test -project ./azooKeyMac.xcodeproj -scheme azooKeyMac -destination 'platform=macOS' -only-testing:azooKeyMacTests/JuliaUnicodeSessionTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Core/Sources/Core/InputUtils/InputState.swift azooKeyMac/InputController/JuliaUnicodeSession.swift Core/Tests/CoreTests/InputUtilsTests/JuliaUnicodeInputStateTests.swift azooKeyMacTests/JuliaUnicodeSessionTests.swift
git commit -m "feat: match Julia REPL completion behavior"
```

### Task 5: Verify end-to-end behavior and document regeneration workflow

**Files:**
- Modify: `README.md`
- Modify: `docs/plans/2026-04-13-azookey-julia-unicode-design.md`
- Modify: `tools/generate_julia_unicode_symbols.swift`

**Step 1: Write the failing documentation expectation**

```text
README should mention:
- direct `\` starts Julia Unicode completion
- `Tab` / `Space` / `Enter` controls
- `tools/generate_julia_unicode_symbols.swift` refreshes symbol tables from extern/julia
```

**Step 2: Run verification commands before doc changes**

Run: `swift test --package-path ./Core`
Run: `xcodebuild build -project ./azooKeyMac.xcodeproj -scheme azooKeyMac -configuration Debug`
Expected: PASS before updating docs, or stop and fix failures before editing documentation.

**Step 3: Write minimal documentation**

Add a short README section describing:

```markdown
### Julia Unicode Completion

Type `\` directly to start Julia-style Unicode completion.

- `Tab`: complete / commit
- `Space`: open or advance candidates
- `Shift+Space` / `Up`: previous candidate
- `Enter`: commit selected candidate, or literal input if there is no match
```

Also document the symbol regeneration command:

```bash
swift ./tools/generate_julia_unicode_symbols.swift
```

**Step 4: Run final verification**

Run: `swift test --package-path ./Core`
Run: `xcodebuild test -project ./azooKeyMac.xcodeproj -scheme azooKeyMac -destination 'platform=macOS'`
Expected: PASS

**Step 5: Commit**

```bash
git add README.md docs/plans/2026-04-13-azookey-julia-unicode-design.md tools/generate_julia_unicode_symbols.swift
git commit -m "docs: document Julia Unicode completion"
```
