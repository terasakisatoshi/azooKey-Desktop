#!/usr/bin/env swift

import Foundation

let scriptURL = URL(fileURLWithPath: #filePath)
let repoRootURL = scriptURL.deletingLastPathComponent().deletingLastPathComponent()

let inputFiles: [(source: URL, destination: URL, symbolName: String)] = [
    (
        source: repoRootURL.appendingPathComponent("extern/julia/stdlib/REPL/src/latex_symbols.jl"),
        destination: repoRootURL.appendingPathComponent("Core/Sources/Core/InputUtils/JuliaUnicode/Generated/JuliaLatexSymbolMap.swift"),
        symbolName: "juliaLatexSymbolMap"
    ),
    (
        source: repoRootURL.appendingPathComponent("extern/julia/stdlib/REPL/src/emoji_symbols.jl"),
        destination: repoRootURL.appendingPathComponent("Core/Sources/Core/InputUtils/JuliaUnicode/Generated/JuliaEmojiSymbolMap.swift"),
        symbolName: "juliaEmojiSymbolMap"
    )
]

let pairPattern = #"^\s*"((?:\\.|[^"])*)"\s*=>\s*"((?:\\.|[^"])*)""#
let pairRegex = try NSRegularExpression(pattern: pairPattern)

func decodeJuliaString(_ raw: Substring) -> String {
    var result = String()
    let characters = Array(raw)
    var index = 0

    while index < characters.count {
        let character = characters[index]
        guard character == "\\" else {
            result.append(character)
            index += 1
            continue
        }

        guard index + 1 < characters.count else {
            result.append(character)
            break
        }

        let next = characters[index + 1]
        switch next {
        case "\\":
            result.append("\\")
            index += 2
        case "\"":
            result.append("\"")
            index += 2
        case "n":
            result.append("\n")
            index += 2
        case "r":
            result.append("\r")
            index += 2
        case "t":
            result.append("\t")
            index += 2
        case "u":
            let start = index + 2
            let end = min(start + 4, characters.count)
            guard end - start == 4 else {
                result.append(next)
                index += 2
                continue
            }
            let hex = String(characters[start..<end])
            guard let scalarValue = UInt32(hex, radix: 16), let scalar = UnicodeScalar(scalarValue) else {
                result.append(next)
                index += 2
                continue
            }
            result.unicodeScalars.append(scalar)
            index = end
        case "U":
            let start = index + 2
            let end = min(start + 8, characters.count)
            guard end - start == 8 else {
                result.append(next)
                index += 2
                continue
            }
            let hex = String(characters[start..<end])
            guard let scalarValue = UInt32(hex, radix: 16), let scalar = UnicodeScalar(scalarValue) else {
                result.append(next)
                index += 2
                continue
            }
            result.unicodeScalars.append(scalar)
            index = end
        default:
            result.append(next)
            index += 2
        }
    }

    return result
}

func parsePairs(from source: String) -> [(trigger: String, text: String)] {
    var pairs: [(trigger: String, text: String)] = []

    source.enumerateLines { line, _ in
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = pairRegex.firstMatch(in: line, options: [], range: range) else {
            return
        }

        guard
            let triggerRange = Range(match.range(at: 1), in: line),
            let textRange = Range(match.range(at: 2), in: line)
        else {
            return
        }

        let trigger = decodeJuliaString(line[triggerRange])
        let text = decodeJuliaString(line[textRange])
        pairs.append((trigger: trigger, text: text))
    }

    return pairs
}

func writeSymbolMap(symbolName: String, pairs: [(trigger: String, text: String)], destination: URL) throws {
    try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)

    var output = """
    internal let \(symbolName): [(trigger: String, text: String)] = [
    """

    for pair in pairs {
        output += "\n    (trigger: \(String(reflecting: pair.trigger)), text: \(String(reflecting: pair.text))),"
    }

    output += "\n]\n"
    try output.write(to: destination, atomically: true, encoding: .utf8)
}

for file in inputFiles {
    let source = try String(contentsOf: file.source, encoding: .utf8)
    let pairs = parsePairs(from: source)
    try writeSymbolMap(symbolName: file.symbolName, pairs: pairs, destination: file.destination)
}
