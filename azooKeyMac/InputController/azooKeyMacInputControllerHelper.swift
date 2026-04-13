import Cocoa
import Core
import InputMethodKit
import KanaKanjiConverterModuleWithDefaultDictionary

extension azooKeyMacInputController {
    // MARK: - Settings and Menu Items

    func setupMenu() {
        self.appMenu.autoenablesItems = true
        self.liveConversionToggleMenuItem = NSMenuItem(title: "ライブ変換", action: #selector(self.toggleLiveConversion(_:)), keyEquivalent: "")
        self.appMenu.addItem(self.liveConversionToggleMenuItem)
        self.transformSelectedTextMenuItem = NSMenuItem(title: TransformMenuTitle.normal, action: #selector(self.performTransformSelectedText(_:)), keyEquivalent: "s")
        self.transformSelectedTextMenuItem.keyEquivalentModifierMask = [.control]
        self.transformSelectedTextMenuItem.target = self
        self.appMenu.addItem(self.transformSelectedTextMenuItem)
        self.appMenu.addItem(NSMenuItem.separator())
        self.appMenu.addItem(NSMenuItem(title: "設定…", action: #selector(self.openConfigWindow(_:)), keyEquivalent: ""))
        self.appMenu.addItem(NSMenuItem(title: "View on GitHub…", action: #selector(self.openGitHubRepository(_:)), keyEquivalent: ""))
        self.updateTransformSelectedTextMenuItemEnabledState()
    }

    @objc func toggleLiveConversion(_ sender: Any) {
        self.segmentsManager.appendDebugMessage("\(#line): toggleLiveConversion")
        let config = Config.LiveConversion()
        config.value = !self.liveConversionEnabled
        self.updateLiveConversionToggleMenuItem(newValue: config.value)
    }

    func updateLiveConversionToggleMenuItem(newValue: Bool) {
        self.liveConversionToggleMenuItem.state = newValue ? .on : .off
        self.liveConversionToggleMenuItem.title = "ライブ変換"
    }

    private enum TransformMenuTitle {
        static let normal = "いい感じ変換"
        static let noBackend = "いい感じ変換（無効/バックエンドなし）"
    }

    @MainActor @objc func performTransformSelectedText(_ sender: Any) {
        let aiBackendEnabled = Config.AIBackendPreference().value != .off
        self.updateTransformSelectedTextMenuItemTitle(aiBackendEnabled: aiBackendEnabled)
        guard aiBackendEnabled else {
            return
        }
        guard !self.isPromptWindowVisible else {
            return
        }
        guard let client = self.client() else {
            return
        }
        let hasSelection = client.selectedRange().length > 0
        if hasSelection {
            _ = self.handleClientAction(.showPromptInputWindow, clientActionCallback: .fallthrough, client: client)
            return
        }
        switch self.inputState {
        case .composing, .replaceSuggestion:
            _ = self.handleClientAction(.requestReplaceSuggestion, clientActionCallback: .transition(.replaceSuggestion), client: client)
        case .none:
            _ = self.handleClientAction(.requestPredictiveSuggestion, clientActionCallback: .transition(.replaceSuggestion), client: client)
        default:
            break
        }
    }

    @MainActor @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard menuItem == self.transformSelectedTextMenuItem else {
            return true
        }
        let aiBackendEnabled = Config.AIBackendPreference().value != .off
        self.updateTransformSelectedTextMenuItemTitle(aiBackendEnabled: aiBackendEnabled)
        return self.canPerformTransformSelectedText(client: self.client())
    }

    func updateTransformSelectedTextMenuItemEnabledState() {
        let aiBackendEnabled = Config.AIBackendPreference().value != .off
        self.updateTransformSelectedTextMenuItemTitle(aiBackendEnabled: aiBackendEnabled)
        self.transformSelectedTextMenuItem.isEnabled = self.canPerformTransformSelectedText(client: self.client())
    }

    private func canPerformTransformSelectedText(client: IMKTextInput?) -> Bool {
        guard !self.isPromptWindowVisible else {
            return false
        }
        guard let client else {
            return false
        }
        let hasSelection = client.selectedRange().length > 0
        return hasSelection || self.inputState == .composing || self.inputState == .replaceSuggestion || self.inputState == .none
    }

    private func updateTransformSelectedTextMenuItemTitle(aiBackendEnabled: Bool) {
        self.transformSelectedTextMenuItem.title = aiBackendEnabled ? TransformMenuTitle.normal : TransformMenuTitle.noBackend
    }

    @objc func openGitHubRepository(_ sender: Any) {
        guard let url = URL(string: "https://github.com/azooKey/azooKey-Desktop") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc func openConfigWindow(_ sender: Any) {
        (NSApplication.shared.delegate as? AppDelegate)!.openConfigWindow()
    }

    // MARK: - Application Support Directory
    func prepareApplicationSupportDirectory() {
        do {
            self.segmentsManager.appendDebugMessage("\(#line): Applicatiion Support Directory Path: \(self.segmentsManager.azooKeyMemoryDir)")
            try FileManager.default.createDirectory(at: self.segmentsManager.azooKeyMemoryDir, withIntermediateDirectories: true)
            self.segmentsManager.appendDebugMessage("\(#line): Debug TypoCorrection Download Directory Path: \(self.segmentsManager.downloadedInputN5LMDir)")
            try FileManager.default.createDirectory(at: self.segmentsManager.downloadedInputN5LMDir, withIntermediateDirectories: true)
        } catch {
            self.segmentsManager.appendDebugMessage("\(#line): \(error.localizedDescription)")
        }
    }

    @MainActor func makeJuliaCandidatePresentations() -> [CandidatePresentation] {
        self.juliaSession.matches.map { entry in
            let candidate = Candidate(
                text: entry.text,
                value: 0,
                composingCount: .surfaceCount(entry.text.count),
                lastMid: 0,
                data: []
            )
            return CandidatePresentation(
                candidate: candidate,
                displayContext: .init(annotationText: entry.trigger)
            )
        }
    }

    @MainActor func commitJuliaSelection(on client: IMKTextInput, inputState: InputState) {
        let text = self.juliaSession.commitText(
            for: self.juliaSession.buffer,
            preferSelectedEntry: inputState == .juliaSelecting
        ) ?? self.juliaSession.buffer
        client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
        self.juliaSession.reset()
    }

    @MainActor func finalizeJuliaSession(on client: IMKTextInput?) {
        if let client {
            self.commitJuliaSelection(on: client, inputState: self.inputState)
        } else {
            self.resetJuliaSession()
        }
        self.inputState = .none
    }

    @MainActor func resetJuliaSession() {
        self.juliaSession.reset()
    }

    @MainActor func startJuliaSession(initialBuffer: String) {
        self.juliaSession.reset()
        self.juliaSession.replaceBuffer(initialBuffer)
    }

    @MainActor func appendToJuliaSession(_ string: String) {
        self.juliaSession.append(string)
    }

    @MainActor func deleteBackwardFromJuliaSession() {
        self.juliaSession.deleteBackward()
    }

    @MainActor func moveJuliaSessionSelection(by offset: Int) {
        self.juliaSession.moveSelection(by: offset)
    }
}
