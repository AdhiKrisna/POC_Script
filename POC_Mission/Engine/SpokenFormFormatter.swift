import Foundation

public enum SpokenFormFormatter {
    /// Bentuk ucapan digit per ICAO Doc 9432 Tabel 2.4.1 (ZE-RO, WUN, TOO, TREE, FOW-er, FIFE, SIX, SEV-en, AIT, NIN-er).
    /// Ejaan disederhanakan tanpa tanda hubung/kapital agar natural dibaca TTS, tetapi tetap mempertahankan
    /// fonem khas ICAO yang membedakannya dari bahasa Inggris biasa (tree/fower/fife/ait/niner).
    private static let digits: [Character: String] = [
        "0": "zero", "1": "one", "2": "two", "3": "tree", "4": "fower",
        "5": "fife", "6": "six", "7": "seven", "8": "ait", "9": "niner"
    ]

    private static let phoneticAlphabet: [Character: String] = [
        "A": "Alpha", "B": "Bravo", "C": "Charlie", "D": "Delta",
        "E": "Echo", "F": "Foxtrot", "G": "Golf", "H": "Hotel",
        "I": "India", "J": "Juliett", "K": "Kilo", "L": "Lima",
        "M": "Mike", "N": "November", "O": "Oscar", "P": "Papa",
        "Q": "Quebec", "R": "Romeo", "S": "Sierra", "T": "Tango",
        "U": "Uniform", "V": "Victor", "W": "Whiskey", "X": "X-ray",
        "Y": "Yankee", "Z": "Zulu"
    ]

    /// Converts alphanumeric codes like "A2", "NP1", "B3", "A" into standard ICAO spoken words (e.g. "Alpha two", "November Papa one", "Bravo three", "Alpha").
    public static func holdingPoint(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Alpha one" }

        let lower = trimmed.lowercased()
        if lower.contains("alpha") || lower.contains("alfa") || lower.contains("bravo") || lower.contains("charlie") || lower.contains("delta") || lower.contains("echo") {
            return trimmed
        }

        var words: [String] = []
        for char in trimmed.uppercased() {
            if let phonetic = phoneticAlphabet[char] {
                words.append(phonetic)
            } else if let digit = digits[char] {
                words.append(digit)
            }
        }
        return words.isEmpty ? trimmed : words.joined(separator: " ")
    }

    public static func phoneticAlphanumeric(_ value: String) -> String {
        holdingPoint(value)
    }

    public static func runway(_ value: String) -> String {
        let uppercase = value.uppercased()
        let numeric = uppercase.prefix { $0.isNumber }
        let suffix = uppercase.dropFirst(numeric.count)
        let spokenDigits = digitWords(String(numeric))
        let spokenSuffix: String
        switch suffix {
        case "L": spokenSuffix = "left"
        case "R": spokenSuffix = "right"
        case "C": spokenSuffix = "centre"
        default: spokenSuffix = ""
        }
        return [spokenDigits, spokenSuffix].filter { !$0.isEmpty }.joined(separator: " ")
    }

    public static func frequency(_ value: String) -> String {
        let parts = value.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return digitWords(value) }
        var fractional = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "0"))
        if fractional.isEmpty {
            fractional = "0"
        }
        return [digitWords(parts[0]), "day see mal", digitWords(fractional)].filter { !$0.isEmpty }.joined(separator: " ")
    }

    public static func qnh(_ value: Int) -> String { digitWords(String(value)) }

    public static func heading(_ value: Int) -> String {
        digitWords(String(format: "%03d", ((value % 360) + 360) % 360))
    }

    public static func altitude(_ feet: Int) -> String {
        let thousands = feet / 1000
        let hundreds = (feet % 1000) / 100
        var words: [String] = []
        if thousands > 0 { words += [cardinal(thousands), "thousand"] }
        if hundreds > 0 { words += [cardinal(hundreds), "hundred"] }
        if words.isEmpty { words.append("zero") }
        words.append("feet")
        return words.joined(separator: " ")
    }

    public static func flightLevel(_ value: Int) -> String { "flight level \(digitWords(String(format: "%03d", value)))" }
    public static func speed(_ value: Int) -> String { "\(digitWords(String(value))) knots" }
    public static func degrees(_ value: Int) -> String { "\(heading(value)) degrees" }
    public static func knots(_ value: Int) -> String { speed(value) }

    public static func wind(direction: Int, knots: Int) -> String {
        "\(degrees(direction)) \(self.knots(knots))"
    }

    // ICAO Doc 9432 Section 2.5: Transmission of Time
    public static func timeMinutes(_ minutes: Int) -> String {
        digitWords(String(format: "%02d", minutes % 60))
    }

    public static func timeFull(hour: Int, minute: Int) -> String {
        "\(digitWords(String(format: "%02d", hour % 24))) \(digitWords(String(format: "%02d", minute % 60)))"
    }

    public static func digitWords(_ value: String) -> String {
        value.compactMap { digits[$0] }.joined(separator: " ")
    }

    /// Kata-kata digit bahasa Inggris biasa yang harus diganti bentuk ucapan ICAO Doc 9432 2.4.1.
    /// Hanya 5 digit yang berbeda; zero/one/two/six/seven sudah identik.
    private static let icaoDigitSubstitutions: [(pattern: NSRegularExpression, replacement: String)] = {
        let pairs = [
            ("three", "tree"), ("four", "fower"), ("five", "fife"),
            ("eight", "ait"), ("nine", "niner"), ("decimal", "day see mal")
        ]
        return pairs.compactMap { word, replacement in
            // \b mencegah kecocokan di dalam kata (threshold, fourth, eighty, ninety, nineteen).
            guard let regex = try? NSRegularExpression(pattern: "\\b\(word)\\b", options: [.caseInsensitive]) else {
                return nil
            }
            return (regex, replacement)
        }
    }()

    /// Mengubah kata digit bahasa Inggris biasa di dalam teks transmisi menjadi bentuk ucapan ICAO.
    /// Dipakai sebagai jaring pengaman terpusat agar seluruh teks yang diucapkan konsisten,
    /// tanpa harus menyentuh ratusan string literal satu per satu.
    /// Catatan: "nine" -> "niner" dilewati bila sudah berbentuk "niner".
    public static func normalizeToICAOSpokenForm(_ text: String) -> String {
        var result = text
        for (regex, replacement) in icaoDigitSubstitutions {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: replacement
            )
        }
        return result
    }

    private static func cardinal(_ value: Int) -> String {
        digitWords(String(value))
    }
}
