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
