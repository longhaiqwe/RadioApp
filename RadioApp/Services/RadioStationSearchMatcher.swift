import Foundation
import CoreFoundation

enum RadioStationSearchMatcher {
    private static let knownAnchors = [
        "fm",
        "am",
        "radio",
        "station",
        "电台",
        "广播",
        "音乐"
    ]
    private static let optionalCJKQualifiers = [
        "华语广播",
        "中文广播",
        "汉语广播",
        "普通话广播",
        "国语广播",
        "华语",
        "中文",
        "汉语",
        "普通话",
        "国语"
    ]

    static func fallbackTerms(for query: String) -> [String] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        let queryTokens = tokens(in: trimmedQuery)
        let compactQuery = queryTokens.joined()
        var terms: [String] = []

        let traditionalQuery = convertedChinese(trimmedQuery, transform: "Hans-Hant")
        if traditionalQuery != trimmedQuery {
            appendUnique(traditionalQuery, to: &terms)
        }

        for anchor in knownAnchors where queryTokens.contains(anchor) || compactQuery.contains(anchor) {
            appendUnique(anchor, to: &terms)
        }

        for token in queryTokens where token.count >= 2 {
            appendUnique(token, to: &terms)
        }

        for token in queryTokens where token.count >= 4 {
            appendUnique(String(token.prefix(min(4, token.count - 1))), to: &terms)
        }

        return terms.filter {
            $0.compare(trimmedQuery, options: [.caseInsensitive, .diacriticInsensitive]) != .orderedSame
        }
    }

    static func matches(
        name: String,
        tags: String,
        country: String,
        language: String,
        query: String
    ) -> Bool {
        let searchableText = [name, tags, country, language].joined(separator: " ")
        return score(candidate: searchableText, query: query) != nil
    }

    private static func score(candidate: String, query: String) -> Int? {
        let candidateTokens = tokens(in: candidate)
        let queryTokens = queryTokens(in: query)
        let candidateCompact = candidateTokens.joined()
        let queryCompact = queryTokens.joined()

        guard !candidateCompact.isEmpty, !queryCompact.isEmpty else { return nil }

        if candidateCompact == queryCompact {
            return 0
        }
        if candidateCompact.contains(queryCompact) {
            return 1
        }

        var totalScore = 0
        for queryToken in queryTokens {
            let bestTokenScore = candidateTokens
                .compactMap { tokenScore(candidateToken: $0, queryToken: queryToken) }
                .min()

            guard let bestTokenScore else { return nil }
            totalScore += bestTokenScore
        }
        return 10 + totalScore
    }

    private static func tokenScore(candidateToken: String, queryToken: String) -> Int? {
        if candidateToken == queryToken {
            return 0
        }
        if candidateToken.contains(queryToken) {
            return 1
        }
        if containsCJK(candidateToken) || containsCJK(queryToken) {
            return nil
        }

        let distance = levenshteinDistance(candidateToken, queryToken)
        guard distance <= allowedEditDistance(candidateToken, queryToken) else { return nil }
        return 4 + distance
    }

    private static func allowedEditDistance(_ lhs: String, _ rhs: String) -> Int {
        let shorter = min(lhs.count, rhs.count)
        let longer = max(lhs.count, rhs.count)
        if shorter <= 2 { return 0 }
        if shorter <= 4 { return 1 }
        return min(3, max(2, longer / 4))
    }

    private static func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let lhsCharacters = Array(lhs)
        let rhsCharacters = Array(rhs)
        guard !lhsCharacters.isEmpty else { return rhsCharacters.count }
        guard !rhsCharacters.isEmpty else { return lhsCharacters.count }

        var previousRow = Array(0...rhsCharacters.count)
        for lhsIndex in 1...lhsCharacters.count {
            var currentRow = [lhsIndex] + Array(repeating: 0, count: rhsCharacters.count)
            for rhsIndex in 1...rhsCharacters.count {
                let substitutionCost = lhsCharacters[lhsIndex - 1] == rhsCharacters[rhsIndex - 1] ? 0 : 1
                currentRow[rhsIndex] = min(
                    previousRow[rhsIndex] + 1,
                    currentRow[rhsIndex - 1] + 1,
                    previousRow[rhsIndex - 1] + substitutionCost
                )
            }
            previousRow = currentRow
        }
        return previousRow[rhsCharacters.count]
    }

    private static func queryTokens(in query: String) -> [String] {
        let queryTokens = tokens(in: query)
        guard queryTokens.contains(where: { containsASCIILetter($0) && $0.count >= 2 }) else {
            return queryTokens
        }

        let filteredTokens = queryTokens.filter { !optionalCJKQualifiers.contains($0) }
        return filteredTokens.isEmpty ? queryTokens : filteredTokens
    }

    private static func tokens(in value: String) -> [String] {
        normalizedSearchText(value)
            .split(separator: " ")
            .map(String.init)
    }

    private static func normalizedSearchText(_ value: String) -> String {
        let folded = convertedChinese(value, transform: "Hant-Hans")
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .lowercased()

        var output = ""
        var isLastCharacterSeparator = true
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                output.unicodeScalars.append(scalar)
                isLastCharacterSeparator = false
            } else if !isLastCharacterSeparator {
                output.append(" ")
                isLastCharacterSeparator = true
            }
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func convertedChinese(_ value: String, transform: String) -> String {
        let mutableValue = NSMutableString(string: value)
        CFStringTransform(mutableValue, nil, transform as CFString, false)
        return mutableValue as String
    }

    private static func containsASCIILetter(_ value: String) -> Bool {
        value.unicodeScalars.contains {
            ($0.value >= 65 && $0.value <= 90) || ($0.value >= 97 && $0.value <= 122)
        }
    }

    private static func containsCJK(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            let codePoint = scalar.value
            return (codePoint >= 0x3400 && codePoint <= 0x4DBF)
                || (codePoint >= 0x4E00 && codePoint <= 0x9FFF)
                || (codePoint >= 0xF900 && codePoint <= 0xFAFF)
                || (codePoint >= 0x20000 && codePoint <= 0x2FA1F)
        }
    }

    private static func appendUnique(_ term: String, to terms: inout [String]) {
        guard !terms.contains(term) else { return }
        terms.append(term)
    }
}
