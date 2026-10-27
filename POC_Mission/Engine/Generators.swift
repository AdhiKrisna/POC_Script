import Foundation

public enum CallsignGenerator {
    private static let gaSuffixes = ["WIC", "ABC", "KRS", "LNX", "ROZ", "VAL", "PLT", "DEF", "XYZ", "BWA"]

    // Level-specific callsign pools per Variabel_Dinamis.pdf
    public static func generate(level: CurriculumLevel, seed: Int) -> String {
        let absSeed = abs(seed)
        switch level {
        case .level1:
            // Skyfox [10-99], Indo Air [01-20], PK-[A-Z]{3}
            let choice = absSeed % 3
            if choice == 0 {
                let num = 10 + (absSeed % 90)
                return "Skyfox \(SpokenFormFormatter.digitWords(String(num)))"
            } else if choice == 1 {
                let num = 1 + (absSeed % 20)
                let numStr = String(format: "%02d", num)
                return "Indo Air \(SpokenFormFormatter.digitWords(numStr))"
            } else {
                let reg = gaSuffixes[absSeed % gaSuffixes.count]
                return "PK-\(reg)"
            }

        case .level2:
            // Wings Air [1800-1899], Susi Air [100-299], Supergreen [400-499]
            let choice = absSeed % 3
            if choice == 0 {
                let num = 1800 + (absSeed % 100)
                return "Wings Air \(SpokenFormFormatter.digitWords(String(num)))"
            } else if choice == 1 {
                let num = 100 + (absSeed % 200)
                return "Susi Air \(SpokenFormFormatter.digitWords(String(num)))"
            } else {
                let num = 400 + (absSeed % 100)
                return "Supergreen \(SpokenFormFormatter.digitWords(String(num)))"
            }

        case .level3:
            // Indonesia [300-399], Batik [6300-6399], Lion Air [700-799], Supergreen [500-599]
            let choice = absSeed % 4
            if choice == 0 {
                let num = 300 + (absSeed % 100)
                return "Indonesia \(SpokenFormFormatter.digitWords(String(num)))"
            } else if choice == 1 {
                let num = 6300 + (absSeed % 100)
                return "Batik \(SpokenFormFormatter.digitWords(String(num)))"
            } else if choice == 2 {
                let num = 700 + (absSeed % 100)
                return "Lion Air \(SpokenFormFormatter.digitWords(String(num)))"
            } else {
                let num = 500 + (absSeed % 100)
                return "Supergreen \(SpokenFormFormatter.digitWords(String(num)))"
            }

        case .level4:
            // Indonesia [100-299] Heavy, Batik [7000-7199], Lion Air [800-899], Prosper [100-299]
            let choice = absSeed % 4
            if choice == 0 {
                let num = 100 + (absSeed % 200)
                return "Indonesia \(SpokenFormFormatter.digitWords(String(num))) Heavy"
            } else if choice == 1 {
                let num = 7000 + (absSeed % 200)
                return "Batik \(SpokenFormFormatter.digitWords(String(num)))"
            } else if choice == 2 {
                let num = 800 + (absSeed % 100)
                return "Lion Air \(SpokenFormFormatter.digitWords(String(num)))"
            } else {
                let num = 100 + (absSeed % 200)
                return "Prosper \(SpokenFormFormatter.digitWords(String(num)))"
            }

        case .level5:
            // Trigana [200-299], Smart [100-199], Wings Air [1850-1899], Batik [400-499], Asian One [300-399]
            let choice = absSeed % 5
            if choice == 0 {
                let num = 200 + (absSeed % 100)
                return "Trigana \(SpokenFormFormatter.digitWords(String(num)))"
            } else if choice == 1 {
                let num = 100 + (absSeed % 100)
                return "Smart \(SpokenFormFormatter.digitWords(String(num)))"
            } else if choice == 2 {
                let num = 1850 + (absSeed % 50)
                return "Wings Air \(SpokenFormFormatter.digitWords(String(num)))"
            } else if choice == 3 {
                let num = 400 + (absSeed % 100)
                return "Batik \(SpokenFormFormatter.digitWords(String(num)))"
            } else {
                let num = 300 + (absSeed % 100)
                return "Asian One \(SpokenFormFormatter.digitWords(String(num)))"
            }
        }
    }

    /// Generates a confusable bait callsign for Level 4 Selective Auditory Attention training
    public static func generateBait(playerCallsign: String, seed: Int) -> String {
        if playerCallsign.contains("Batik") {
            return playerCallsign.replacingOccurrences(of: "Batik", with: "Lion")
        } else if playerCallsign.contains("Indonesia") {
            return playerCallsign.replacingOccurrences(of: "Indonesia", with: "Supergreen")
        } else if playerCallsign.contains("Garuda") {
            return playerCallsign.replacingOccurrences(of: "Garuda", with: "Indonesia")
        } else if playerCallsign.contains("Lion") {
            return playerCallsign.replacingOccurrences(of: "Lion", with: "Batik")
        } else if playerCallsign.contains("Supergreen") {
            return playerCallsign.replacingOccurrences(of: "Supergreen", with: "Prosper")
        } else if playerCallsign.contains("Prosper") {
            return playerCallsign.replacingOccurrences(of: "Prosper", with: "Supergreen")
        }
        return "Batik \(100 + abs(seed) % 800)"
    }

    public static func generate(profile: FlightProfile, seed: Int) -> String {
        switch profile {
        case .vfrLocal:
            return generate(level: .level1, seed: seed)
        case .ifrCommercial:
            return generate(level: .level3, seed: seed)
        }
    }
}

public enum AircraftGenerator {
    // Doc 9432 2.7.2.1 Type a) Note: hanya SATU prefix radiotelephony (nama manufaktur ATAU model),
    // bukan keduanya sekaligus. "Piper Archer PA-two eight" diperbaiki menjadi "Piper Archer".
    // Digit mengikuti bentuk ucapan ICAO Doc 9432 2.4.1 (tree/fower/fife/ait/niner).
    private static let level1Aircraft = [
        "Cessna one seven two",
        "Piper Archer",
        "Diamond fower zero"
    ]

    private static let level2Aircraft = [
        "ATR seven two",
        "Cessna Grand Caravan"
    ]

    private static let level3Aircraft = [
        "Airbus A tree two zero",
        "Boeing seven tree seven"
    ]

    private static let level4Aircraft = [
        "Boeing seven seven seven Heavy",
        "Airbus A tree tree zero Heavy",
        "Airbus A tree two zero",
        "Boeing seven tree seven"
    ]

    // Level 5: Extreme Terrain & STOL Jet / Commuter
    private static let level5Aircraft = [
        "Boeing seven tree seven",
        "ATR seven two",
        "Twin Otter"
    ]

    // Toraja Buntu Kunik (WAFB): Cliff runway, STOL turboprop only
    private static let torajaAircraft = [
        "ATR seven two",
        "Twin Otter"
    ]

    public static func generate(profile: FlightProfile, level: CurriculumLevel? = nil, airportICAO: String? = nil, seed: Int) -> String {
        let absSeed = abs(seed)
        if airportICAO == "WAFB" {
            return torajaAircraft[absSeed % torajaAircraft.count]
        }

        if let lvl = level {
            switch lvl {
            case .level1:
                return level1Aircraft[absSeed % level1Aircraft.count]
            case .level2:
                return level2Aircraft[absSeed % level2Aircraft.count]
            case .level3:
                return level3Aircraft[absSeed % level3Aircraft.count]
            case .level4:
                return level4Aircraft[absSeed % level4Aircraft.count]
            case .level5:
                return level5Aircraft[absSeed % level5Aircraft.count]
            }
        }

        switch profile {
        case .vfrLocal:
            return level1Aircraft[absSeed % level1Aircraft.count]
        case .ifrCommercial:
            return level3Aircraft[absSeed % level3Aircraft.count]
        }
    }

    public static func generate(profile: FlightProfile, level: CurriculumLevel? = nil, seed: Int) -> String {
        generate(profile: profile, level: level, airportICAO: nil, seed: seed)
    }

    public static func generate(profile: FlightProfile, seed: Int) -> String {
        generate(profile: profile, level: nil, airportICAO: nil, seed: seed)
    }
}

public enum SquawkGenerator {
    /// Generates standard transponder codes:
    /// - Level 1 (VFR): standard 1200 ("one two zero zero")
    /// - Level 2-5 (IFR): strictly 4 octal digits (0..7 only, no 8 or 9)
    public static func generate(level: CurriculumLevel, seed: Int) -> String {
        if level == .level1 {
            return "one two zero zero"
        }
        let absSeed = abs(seed)
        let d1 = (absSeed % 4) + 4     // 4..7
        let d2 = (absSeed / 7) % 8     // 0..7
        let d3 = (absSeed / 49) % 8    // 0..7
        let d4 = (absSeed / 343) % 8   // 0..7
        let codeStr = "\(d1)\(d2)\(d3)\(d4)"
        return SpokenFormFormatter.digitWords(codeStr)
    }
}

public enum FlightLevelGenerator {
    private static let eastboundFLs = [
        "flight level tree one zero",
        "flight level tree tree zero",
        "flight level tree fife zero",
        "flight level tree seven zero"
    ]

    private static let westboundFLs = [
        "flight level tree two zero",
        "flight level tree fower zero",
        "flight level tree six zero",
        "flight level tree ait zero"
    ]

    public static func cruisingLevel(level: CurriculumLevel, headingTrack: Int, seed: Int) -> String {
        let absSeed = abs(seed)
        let isEastbound = (headingTrack >= 0 && headingTrack < 180)

        switch level {
        case .level1:
            // 1.000 s/d 1.500 ft AGL local circuit
            return (absSeed % 2 == 0) ? "one thousand feet" : "one thousand fife hundred feet"

        case .level2:
            // FL140 s/d FL180 (Regional turboprop)
            let fls = isEastbound ? ["flight level one fife zero", "flight level one seven zero"]
                                  : ["flight level one fower zero", "flight level one six zero", "flight level one ait zero"]
            return fls[absSeed % fls.count]

        case .level3:
            // FL240 s/d FL280 (Domestic jet)
            let fls = isEastbound ? ["flight level two fife zero", "flight level two seven zero"]
                                  : ["flight level two fower zero", "flight level two six zero", "flight level two ait zero"]
            return fls[absSeed % fls.count]

        case .level4:
            // FL300 s/d FL380 (Heavy & metro jet)
            let fls = isEastbound ? ["flight level tree one zero", "flight level tree tree zero", "flight level tree fife zero", "flight level tree seven zero"]
                                  : ["flight level tree zero zero", "flight level tree two zero", "flight level tree fower zero", "flight level tree six zero", "flight level tree ait zero"]
            return fls[absSeed % fls.count]

        case .level5:
            // FL160 s/d FL240 (Extreme terrain / mountain crossing)
            let fls = isEastbound ? ["flight level one seven zero", "flight level one niner zero", "flight level two one zero", "flight level two tree zero"]
                                  : ["flight level one six zero", "flight level one ait zero", "flight level two zero zero", "flight level two two zero", "flight level two fower zero"]
            return fls[absSeed % fls.count]
        }
    }

    public static func cruisingLevel(headingTrack: Int, seed: Int) -> String {
        // Semicircular rule: 000-179 Eastbound (Odd FL), 180-359 Westbound (Even FL)
        let isEastbound = (headingTrack >= 0 && headingTrack < 180)
        let list = isEastbound ? eastboundFLs : westboundFLs
        return list[abs(seed) % list.count]
    }

    public static func initialAltitude(level: CurriculumLevel, seed: Int) -> String {
        let absSeed = abs(seed)
        switch level {
        case .level1:
            return (absSeed % 2 == 0) ? "one thousand feet" : "one thousand fife hundred feet"
        case .level2:
            return (absSeed % 2 == 0) ? "altitude fower thousand feet" : "altitude fife thousand feet"
        case .level3:
            return "flight level one zero zero"
        case .level4:
            return (absSeed % 2 == 0) ? "flight level one zero zero" : "flight level one one zero"
        case .level5:
            return (absSeed % 2 == 0) ? "altitude ait thousand feet" : "flight level one zero zero"
        }
    }

    public static func initialAltitude(seed: Int) -> String {
        let altitudes = [
            "altitude fower thousand feet",
            "altitude fife thousand feet",
            "flight level zero ait zero",
            "flight level one zero zero"
        ]
        return altitudes[abs(seed) % altitudes.count]
    }
}

public enum StandGenerator {
    private static let jakartaStands = [
        "Alpha Twelve", "Alpha Seven", "Bravo Six", "Bravo Nine",
        "Echo Four", "Delta Two", "Delta Five", "Fox One", "Gate G Four Two"
    ]

    private static let baliStands = [
        "Alfa One", "Bravo Six", "Charlie Four", "Delta Two", "Echo Three"
    ]

    private static let gaStands = [
        "One", "Two", "Three", "General Aviation Four"
    ]

    public static func originStand(icao: String, seed: Int) -> String {
        switch icao {
        case "WIII":
            return jakartaStands[abs(seed) % jakartaStands.count]
        case "WADD":
            return baliStands[abs(seed) % baliStands.count]
        default:
            return gaStands[abs(seed) % gaStands.count]
        }
    }

    public static func destinationStand(icao: String, seed: Int) -> String {
        switch icao {
        case "WADD":
            return baliStands[abs(seed + 13) % baliStands.count]
        case "WIII":
            return jakartaStands[abs(seed + 13) % jakartaStands.count]
        default:
            return gaStands[abs(seed + 13) % gaStands.count]
        }
    }
}

public enum ATISGenerator {
    private static let letters = [
        "Alfa", "Bravo", "Charlie", "Delta", "Echo",
        "Foxtrot", "Golf", "Hotel", "India", "Kilo",
        "Lima", "Mike", "November", "Oscar", "Papa",
        "Quebec", "Romeo", "Sierra", "Tango", "Uniform",
        "Victor", "Whiskey", "X-ray", "Yankee", "Zulu"
    ]

    public static func letter(seed: Int) -> String {
        let index = abs(seed) % letters.count
        return letters[index]
    }
}
