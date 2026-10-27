import Foundation

public enum SpokenFormFormatter {
    /// Bentuk ucapan digit per ICAO Doc 9432 Tabel 2.4.1 (ZE-RO, WUN, TOO, TREE, FOW-er, FIFE, SIX, SEV-en, EIGHT, NIN-er).
    /// Ejaan disederhanakan tanpa tanda hubung/kapital agar natural dibaca TTS, tetapi tetap mempertahankan
    /// fonem khas ICAO yang membedakannya dari bahasa Inggris biasa (tree/fower/fife/eight/niner).
    private static let digits: [Character: String] = [
        "0": "zero", "1": "one", "2": "two", "3": "tree", "4": "fower",
        "5": "fife", "6": "six", "7": "seven", "8": "eight", "9": "niner"
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

    /// Kamus pelafalan fonetik ICAO untuk kode fasilitas navigasi radio (VOR/NDB) 2-3 huruf di Indonesia.
    /// Kode fasilitas radio navigasi wajib dieja alfabet fonetik ICAO per huruf (Doc 9432 Bab 2.4.1),
    /// sedangkan waypoint 5LNC (seperti DOLTA, BUNTA) diucapkan sebagai satu kata utuh.
    public static let navaidPhoneticNames: [String: String] = [
        "KNO": "Kilo November Oscar",
        "UPG": "Uniform Papa Golf",
        "BLI": "Bravo Lima India",
        "JOG": "Juliett Oscar Golf",
        "BPN": "Bravo Papa November",
        "BDJ": "Bravo Delta Juliett",
        "SLO": "Sierra Lima Oscar",
        "BDO": "Bravo Delta Oscar",
        "BTH": "Bravo Tango Hotel",
        "HLP": "Hotel Lima Papa",
        "PLM": "Papa Lima Mike",
        "PDG": "Papa Delta Golf",
        "SUP": "Sierra Uniform Papa",
        "CKG": "Charlie Kilo Golf",
        "TRK": "Tango Romeo Kilo",
        "SRG": "Sierra Romeo Golf",
        "SOC": "Sierra Oscar Charlie",
        "SUR": "Sierra Uniform Romeo",
        "TIM": "Tango India Mike",
        "BTO": "Bravo Tango Oscar",
        "PLP": "Papa Lima Papa",
        "MLVOR": "Mike Lima VOR"
    ]

    /// Mengonversi nama waypoint atau navaid menjadi bentuk lisan ICAO literal.
    /// Kode navaid 2-3 huruf dieja alfabet fonetik ICAO; waypoint 5LNC kata utuh dipertahankan.
    public static func waypointSpoken(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix(" VOR") {
            let code = String(trimmed.dropLast(4)).trimmingCharacters(in: .whitespaces)
            return "\(waypointSpoken(code)) VOR"
        }
        if let mapped = navaidPhoneticNames[trimmed.uppercased()] {
            return mapped
        }
        if trimmed.uppercased() == "ANY" {
            return "Alpha November Yankee"
        }
        // Kode navaid 2-3 huruf kapital murni dieja per huruf
        if trimmed.count >= 2 && trimmed.count <= 3 && trimmed.allSatisfy({ $0.isLetter && $0.isUppercase }) {
            return trimmed.compactMap { phoneticAlphabet[$0] }.joined(separator: " ")
        }
        return trimmed
    }

    /// Kata-kata digit bahasa Inggris biasa dan kode navaid yang harus diganti bentuk ucapan ICAO.
    private static let icaoDigitSubstitutions: [(pattern: NSRegularExpression, replacement: String)] = {
        var result: [(pattern: NSRegularExpression, replacement: String)] = []

        let digitPairs: [(String, String)] = [
            ("three", "tree"), ("four", "fower"), ("five", "fife"),
            ("nine", "niner"), ("decimal", "day see mal")
        ]
        for (word, replacement) in digitPairs {
            if let regex = try? NSRegularExpression(pattern: "\\b\(word)\\b", options: [.caseInsensitive]) {
                result.append((regex, replacement))
            }
        }

        // Navaid codes: ANY VOR khusus agar kata bahasa Inggris 'any' tidak terganggu
        if let regex = try? NSRegularExpression(pattern: "\\bANY VOR\\b", options: [.caseInsensitive]) {
            result.append((regex, "Alpha November Yankee VOR"))
        }

        for (code, spoken) in navaidPhoneticNames {
            if let regex = try? NSRegularExpression(pattern: "\\b\(code)\\b", options: []) {
                result.append((regex, spoken))
            }
        }

        return result
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
