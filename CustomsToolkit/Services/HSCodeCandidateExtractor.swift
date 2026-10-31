import Foundation

public enum HSCodeCandidateExtractor {
    /// Extracts plausible HS-code digit sequences from OCR text without deciding which candidate is correct.
    /// The user always confirms the candidate before it is sent to tariff search.
    public static func candidates(from text: String) -> [String] {
        let pattern = #"(?<![0-9٠-٩])(?:[0-9٠-٩][\s\.\-\/]*){4,16}(?![0-9٠-٩])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, range: range)

        var seen = Set<String>()
        var output: [String] = []

        for match in matches {
            let raw = nsText.substring(with: match.range)
            let normalized = HSNormalizer.normalize(raw)
            guard normalized.count >= 4,
                  normalized.count <= AppConfig.maxHSCodeLength,
                  seen.insert(normalized).inserted else { continue }
            output.append(normalized)
        }

        return output.sorted { lhs, rhs in
            // Longer local tariff codes are usually more specific; keep them first for confirmation.
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs < rhs
        }
    }
}
