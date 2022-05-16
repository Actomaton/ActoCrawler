import Foundation

func isRegexMatched(_ string: String, pattern: String) -> Bool
{
    let matches = try? NSRegularExpression(pattern: pattern)
        .matches(in: string, range: .init(location: 0, length: string.utf16.count))

    return !(matches ?? []).isEmpty
}
