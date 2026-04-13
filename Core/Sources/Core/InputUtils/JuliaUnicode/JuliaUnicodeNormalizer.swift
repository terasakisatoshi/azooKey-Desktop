enum JuliaUnicodeNormalizer {
    static func normalize(_ input: String) -> String {
        var result = String()
        result.reserveCapacity(input.count)

        for scalar in input.unicodeScalars {
            switch scalar.value {
            case 0xFF3C:
                result.append("\\")
            default:
                result.unicodeScalars.append(scalar)
            }
        }

        return result
    }
}
