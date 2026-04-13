@testable import Core
import Testing

@Test func juliaResolverExactMatchAlpha() async throws {
    let resolver = JuliaUnicodeResolver.standard
    #expect(resolver.resolveExact("\\alpha")?.text == "α")
}

@Test func juliaResolverExactMatchPreservesCase() async throws {
    let resolver = JuliaUnicodeResolver.standard
    #expect(resolver.resolveExact("\\Alpha")?.text == "Α")
    #expect(resolver.resolveExact("\\^A")?.text == "ᴬ")
}

@Test func juliaResolverManualAliasEntriesResolve() async throws {
    let resolver = JuliaUnicodeResolver.standard
    #expect(resolver.resolveExact("\\scrB")?.text == "ℬ")
    #expect(resolver.resolveExact("\\bbpi")?.text == "ℼ")
}

@Test func juliaResolverShortUnicodeEscapeAliasesResolve() async throws {
    let resolver = JuliaUnicodeResolver.standard
    #expect(resolver.resolveExact("\\scrl")?.text == "𝓁")
}

@Test func juliaResolverPrefixEmoji() async throws {
    let resolver = JuliaUnicodeResolver.standard
    #expect(resolver.resolveMatches("\\:ko").contains { $0.trigger == "\\:koala:" })
}

@Test func juliaResolverPrefixPreservesCase() async throws {
    let resolver = JuliaUnicodeResolver.standard
    let matches = resolver.resolveMatches("\\Al")
    #expect(matches.contains { $0.trigger == "\\Alpha" })
    #expect(!matches.contains { $0.trigger == "\\alpha" })
}

@Test func juliaResolverSuperscriptRun() async throws {
    let resolver = JuliaUnicodeResolver.standard
    #expect(resolver.resolveExact("\\^(123)n")?.text == "⁽¹²³⁾ⁿ")
}

@Test func juliaResolverFullWidthBackslashNormalizes() async throws {
    let resolver = JuliaUnicodeResolver.standard
    #expect(resolver.resolveExact("＼alpha")?.text == "α")
}
