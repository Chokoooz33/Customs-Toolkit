import Foundation

/// Normalizer for HS Code input and search queries.
/// Supports both international prefixes and long Oman local tariff codes (e.g. 12 digits).
public enum HSNormalizer {
    
    /// Normalizes raw user input into a continuous digit string.
    /// Examples:
    /// - "01 01 21 10 00 01" -> "010121100001"
    /// - "01.01.21.10.00.01" -> "010121100001"
    /// - "01-01-21-10-00-01" -> "010121100001"
    /// - "٣٣٠٣٠٠١٠" -> "33030010"
    public static func normalize(_ input: String) -> String {
        let arabicToWesternMap: [Character: Character] = [
            "٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4",
            "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9"
        ]
        
        var normalized = ""
        for char in input {
            if let westernChar = arabicToWesternMap[char] {
                normalized.append(westernChar)
            } else if char.isNumber {
                normalized.append(char)
            }
        }
        
        return normalized
    }
    
    /// Formats a continuous digit HS code with standard customs 2-digit hierarchy spacing.
    /// Examples:
    /// - "010121100001" -> "0101 21 10 00 01"
    /// - "33030010" -> "3303 00 10"
    /// - "330300" -> "3303 00"
    /// - "3303" -> "3303"
    /// - "01" -> "01"
    public static func formatForDisplay(_ normalizedCode: String) -> String {
        let digits = normalize(normalizedCode)
        let count = digits.count
        
        guard count > 4 else {
            return digits
        }
        
        var result = ""
        let chars = Array(digits)
        
        // First 4 digits (Heading)
        result.append(contentsOf: chars[0..<4])
        
        // Pairs for subsequent subdivisions
        var index = 4
        while index < count {
            result.append(" ")
            let nextIndex = min(index + 2, count)
            result.append(contentsOf: chars[index..<nextIndex])
            index += 2
        }
        
        return result
    }
    
    /// Validates if an input string contains a valid partial or complete HS search query.
    public static func isValidQuery(_ input: String) -> Bool {
        let normalized = normalize(input)
        return !normalized.isEmpty && normalized.count <= AppConfig.maxHSCodeLength
    }
    
    /// Normalizes Arabic text specifically for search matching (e.g. stripping diacritics and unifying Alef/Yeh variants)
    /// Note: Does NOT modify original official source descriptions.
    public static func normalizeArabicForSearch(_ text: String) -> String {
        let result = text
            // Remove Arabic Tashkeel / Diacritics
            .replacingOccurrences(of: "[\u{064B}-\u{0652}\u{0670}]", with: "", options: .regularExpression)
            // Unify Alef forms: أ, إ, آ, ٱ -> ا
            .replacingOccurrences(of: "[أإآٱ]", with: "ا", options: .regularExpression)
            // Unify Taa Marbuta: ة -> ه
            .replacingOccurrences(of: "ة", with: "ه")
            // Unify Alef Maqsura: ى -> ي
            .replacingOccurrences(of: "ى", with: "ي")
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
