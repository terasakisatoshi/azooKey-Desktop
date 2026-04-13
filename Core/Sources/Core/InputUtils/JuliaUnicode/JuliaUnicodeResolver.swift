public struct JuliaUnicodeResolver: Sendable {
    public static let standard = JuliaUnicodeResolver()

    public func resolveExact(_ input: String) -> JuliaUnicodeEntry? {
        let normalizedInput = JuliaUnicodeNormalizer.normalize(input)
        if let entry = Self.exactTriggerLookup[normalizedInput] {
            return entry
        }
        if let entry = Self.normalizedLookup[normalizedInput] {
            return entry
        }
        return Self.resolveRunExpansion(normalizedInput)
    }

    public func resolveMatches(_ input: String) -> [JuliaUnicodeEntry] {
        let normalizedInput = JuliaUnicodeNormalizer.normalize(input)
        guard !normalizedInput.isEmpty else {
            return []
        }

        return Self.allEntries.filter { entry in
            JuliaUnicodeNormalizer.normalize(entry.trigger).hasPrefix(normalizedInput)
        }
    }
}

private extension JuliaUnicodeResolver {
    static let allEntries: [JuliaUnicodeEntry] = {
        let latexEntries = juliaLatexSymbolMap.map { JuliaUnicodeEntry(trigger: $0.trigger, text: $0.text) }
        let emojiEntries = juliaEmojiSymbolMap.map { JuliaUnicodeEntry(trigger: $0.trigger, text: $0.text) }
        return latexEntries + emojiEntries
    }()

    static let exactTriggerLookup: [String: JuliaUnicodeEntry] = {
        var lookup: [String: JuliaUnicodeEntry] = [:]
        lookup.reserveCapacity(allEntries.count)

        for entry in allEntries {
            if lookup[entry.trigger] == nil {
                lookup[entry.trigger] = entry
            }
        }

        return lookup
    }()

    static let normalizedLookup: [String: JuliaUnicodeEntry] = {
        var lookup: [String: JuliaUnicodeEntry] = [:]
        lookup.reserveCapacity(allEntries.count)

        for entry in allEntries {
            let normalizedTrigger = JuliaUnicodeNormalizer.normalize(entry.trigger)
            if lookup[normalizedTrigger] == nil {
                lookup[normalizedTrigger] = entry
            }
        }

        return lookup
    }()

    static let superscriptRunMap: [String: String] = [
        "0": "⁰",
        "1": "¹",
        "2": "²",
        "3": "³",
        "4": "⁴",
        "5": "⁵",
        "6": "⁶",
        "7": "⁷",
        "8": "⁸",
        "9": "⁹",
        "+": "⁺",
        "-": "⁻",
        "=": "⁼",
        "(": "⁽",
        ")": "⁾",
        "a": "ᵃ",
        "b": "ᵇ",
        "c": "ᶜ",
        "d": "ᵈ",
        "e": "ᵉ",
        "f": "ᶠ",
        "g": "ᵍ",
        "h": "ʰ",
        "i": "ⁱ",
        "j": "ʲ",
        "k": "ᵏ",
        "l": "ˡ",
        "m": "ᵐ",
        "n": "ⁿ",
        "o": "ᵒ",
        "p": "ᵖ",
        "q": "𐞥",
        "r": "ʳ",
        "s": "ˢ",
        "t": "ᵗ",
        "u": "ᵘ",
        "v": "ᵛ",
        "w": "ʷ",
        "x": "ˣ",
        "y": "ʸ",
        "z": "ᶻ",
        "A": "ᴬ",
        "B": "ᴮ",
        "C": "ꟲ",
        "D": "ᴰ",
        "E": "ᴱ",
        "F": "ꟳ",
        "G": "ᴳ",
        "H": "ᴴ",
        "I": "ᴵ",
        "J": "ᴶ",
        "K": "ᴷ",
        "L": "ᴸ",
        "M": "ᴹ",
        "N": "ᴺ",
        "O": "ᴼ",
        "P": "ᴾ",
        "Q": "ꟴ",
        "R": "ᴿ",
        "T": "ᵀ",
        "U": "ᵁ",
        "V": "ⱽ",
        "W": "ᵂ",
        "alpha": "ᵅ",
        "beta": "ᵝ",
        "gamma": "ᵞ",
        "delta": "ᵟ",
        "epsilon": "ᵋ",
        "theta": "ᶿ",
        "iota": "ᶥ",
        "phi": "ᵠ",
        "chi": "ᵡ",
        "ltphi": "ᶲ",
        "uparrow": "ꜛ",
        "downarrow": "ꜜ",
        "!": "ꜝ"
    ]

    static let subscriptRunMap: [String: String] = [
        "0": "₀",
        "1": "₁",
        "2": "₂",
        "3": "₃",
        "4": "₄",
        "5": "₅",
        "6": "₆",
        "7": "₇",
        "8": "₈",
        "9": "₉",
        "+": "₊",
        "-": "₋",
        "=": "₌",
        "<": "˱",
        ">": "˲",
        "(": "₍",
        ")": "₎",
        "a": "ₐ",
        "e": "ₑ",
        "h": "ₕ",
        "i": "ᵢ",
        "j": "ⱼ",
        "k": "ₖ",
        "l": "ₗ",
        "m": "ₘ",
        "n": "ₙ",
        "o": "ₒ",
        "p": "ₚ",
        "r": "ᵣ",
        "s": "ₛ",
        "t": "ₜ",
        "u": "ᵤ",
        "v": "ᵥ",
        "x": "ₓ",
        "schwa": "ₔ",
        "beta": "ᵦ",
        "gamma": "ᵧ",
        "rho": "ᵨ",
        "phi": "ᵩ",
        "chi": "ᵪ"
    ]

    static func resolveRunExpansion(_ input: String) -> JuliaUnicodeEntry? {
        let prefix: String
        let mapping: [String: String]
        let orderedKeys: [String]

        if input.hasPrefix("\\^") {
            prefix = "\\^"
            mapping = superscriptRunMap
            orderedKeys = superscriptRunKeys
        } else if input.hasPrefix("\\_") {
            prefix = "\\_"
            mapping = subscriptRunMap
            orderedKeys = subscriptRunKeys
        } else {
            return nil
        }

        let remainder = input.dropFirst(prefix.count)
        guard !remainder.isEmpty else {
            return nil
        }

        var expanded = String()
        expanded.reserveCapacity(remainder.count)

        var remaining = remainder[...]
        while !remaining.isEmpty {
            var didMatch = false

            for key in orderedKeys {
                guard remaining.hasPrefix(key), let mapped = mapping[key] else {
                    continue
                }

                expanded.append(mapped)
                remaining.removeFirst(key.count)
                didMatch = true
                break
            }

            if !didMatch {
                return nil
            }
        }

        return JuliaUnicodeEntry(trigger: input, text: expanded)
    }

    static let superscriptRunKeys: [String] = superscriptRunMap.keys.sorted {
        $0.count > $1.count
    }

    static let subscriptRunKeys: [String] = subscriptRunMap.keys.sorted {
        $0.count > $1.count
    }
}
