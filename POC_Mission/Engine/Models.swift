import Foundation

public enum Phase: String, CaseIterable, Codable, Sendable {
    case preDeparture = "PRE_DEPARTURE"
    case departure = "DEPARTURE"
    case enRoute = "EN_ROUTE"
    case arrival = "ARRIVAL"
    case approach = "APPROACH"
    case landing = "LANDING"

    var resourceName: String {
        switch self {
        case .preDeparture: "pre_departure"
        case .departure: "departure"
        case .enRoute: "en_route"
        case .arrival: "arrival"
        case .approach: "approach"
        case .landing: "landing"
        }
    }

    public var frequencyRole: String {
        switch self {
        case .preDeparture: "Delivery / Ground"
        case .departure: "Tower / Departure"
        case .enRoute: "Area Control / Radar"
        case .arrival: "Arrival / Radar"
        case .approach: "Approach / Tower"
        case .landing: "Tower / Ground"
        }
    }
}

public enum FlightProfile: String, Codable, Sendable {
    case vfrLocal = "VFR_LOCAL"
    case ifrCommercial = "IFR_COMMERCIAL"
}

public struct Airport: Codable, Equatable, Sendable {
    public let level: Int?
    public let icao: String
    public let iata: String?
    public let name: String

    /// Nama ringkas bandara untuk tampilan antarmuka (maksimal ~32 karakter).
    ///
    /// Menghindari pemotongan teks di kartu rute dan ATIS dengan meringkas gelar
    /// militer (Lt. Col.), status internasional (Intl. Airport), dan akronim AIP.
    /// Nama lisan (`name`) tetap utuh untuk sintesis suara radio dan naskah dialog.
    public var shortName: String {
        switch icao.uppercased() {
        case "WAAA": return "Sultan Hasanuddin Intl. Airport"
        case "WABP": return "Mozes Kilangin Airport"
        case "WADD": return "I Gusti Ngurah Rai Intl. Airport"
        case "WADE": return "Lt. Col. Wisnu Airfield"
        case "WADL": return "Lombok Intl. Airport"
        case "WADY": return "Banyuwangi Airport"
        case "WAFB": return "Toraja Airport"
        case "WAHI": return "Yogyakarta Intl. Airport"
        case "WALL": return "SAMS Sepinggan Intl. Airport"
        case "WALR": return "Juwata Intl. Airport"
        case "WAOO": return "Syamsudin Noor Intl. Airport"
        case "WARQ": return "Adisoemarmo Intl. Airport"
        case "WARR": return "Juanda Intl. Airport"
        case "WARS": return "Jend. Ahmad Yani Airport"
        case "WAVV": return "Wamena Airport"
        case "WICB": return "Budiarto Airport"
        case "WICC": return "Husein Sastranegara Intl. Airport"
        case "WIDD": return "Hang Nadim Intl. Airport"
        case "WIHH": return "Halim Perdanakusuma Intl. Airport"
        case "WIII": return "Soekarno-Hatta Intl. Airport"
        case "WIMM": return "Kualanamu Intl. Airport"
        case "WIPP": return "SMB II Airport"
        case "WIPT": return "Minangkabau Intl. Airport"
        default: return name
        }
    }

    public let city: String?
    public let profile: FlightProfile
    public let elevationFt: Int
    public let runways: [Runway]
    public let units: AirportUnits
    public let taxiways: [Taxiway]
    public let stands: [Stand]
    public let procedures: Procedures
    public let waypoints: [String]?
    public let reference: AirportReference?

    enum CodingKeys: String, CodingKey {
        case level, icao, iata, name, city, profile, runways, units, taxiways, stands, procedures, waypoints, reference
        case elevationFt = "elevation_ft"
    }
}

public struct AirportReference: Codable, Equatable, Sendable {
    public let source: String?
    public let tripKitPage: Int?
    public let hasTerminalCharts: Bool?
    public let chartCount: Int?
    public let waypoints: [String]?

    public init(source: String? = nil, tripKitPage: Int? = nil, hasTerminalCharts: Bool? = nil, chartCount: Int? = nil, waypoints: [String]? = nil) {
        self.source = source
        self.tripKitPage = tripKitPage
        self.hasTerminalCharts = hasTerminalCharts
        self.chartCount = chartCount
        self.waypoints = waypoints
    }
}

public struct Runway: Codable, Equatable, Sendable {
    public let pair: [String]
    public let designator: String
    public let reciprocal: String
    public let headingDegT: Double
    public let holdingPoints: [String]

    enum CodingKeys: String, CodingKey {
        case pair, designator, reciprocal, holdingPoints
        case headingDegT = "heading_degT"
    }
}

public struct AirportUnits: Codable, Equatable, Sendable {
    public let delivery: ATCUnit?
    public let apron: ATCUnit?
    public let ground: ATCUnit?
    public let tower: ATCUnit?
    public let approach: ATCUnit?
    public let departure: ATCUnit?
    public let center: ATCUnit?
    public let atis: ATCUnit?
}

public struct ATCUnit: Codable, Equatable, Sendable {
    public let callsign: String
    public let frequency: String
}

public struct Taxiway: Codable, Equatable, Sendable {
    public let id: String
    public let spoken: String
}

public struct Stand: Codable, Equatable, Sendable {
    public let id: String
    public let spoken: String
}

public struct Procedures: Codable, Equatable, Sendable {
    public let sids: [SID]
    public let stars: [STAR]
    public let approaches: [ApproachProcedure]
    public let holdings: [Holding]
    public let waypoints: [String]?

    public init(sids: [SID], stars: [STAR], approaches: [ApproachProcedure], holdings: [Holding], waypoints: [String]? = nil) {
        self.sids = sids
        self.stars = stars
        self.approaches = approaches
        self.holdings = holdings
        self.waypoints = waypoints
    }
}

public struct SID: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let runway: String
    public let initialAltFt: Int
    enum CodingKeys: String, CodingKey { case id, name, runway; case initialAltFt = "initialAltFt" }
}

public struct STAR: Codable, Equatable, Sendable { public let id: String; public let name: String; public let runway: String }

public struct ApproachProcedure: Codable, Equatable, Sendable {
    public let id: String
    public let type: String
    public let runway: String
    public let missedApproachAltFt: Int?
    enum CodingKeys: String, CodingKey { case id, type, runway; case missedApproachAltFt = "missedApproachAltFt" }
}

public struct Holding: Codable, Equatable, Sendable {
    public let fix: String
    public let inboundTrack: Int
    public let turns: String
    public let altFt: Int
    enum CodingKeys: String, CodingKey { case fix, turns; case inboundTrack = "inboundTrack"; case altFt = "altFt" }
}

public struct ScenarioTemplate: Codable, Sendable {
    public let id: String
    public let name: String
    public let phase: Phase
    public let profile: [FlightProfile]
    public let isAbnormal: Bool?
    public let exchanges: [ExchangeTemplate]
}

public struct ExchangeTemplate: Codable, Sendable {
    public let turn: Int
    public let speaker: String
    public let isUserTurn: Bool
    public let template: String
    public let slots: [String]
    public let criticalReadback: [CriticalReadbackRule]
    public let branch: String?
}

public struct CriticalReadbackRule: Codable, Sendable {
    public let slot: String
    public let keyword: String?
    public let position: String?
    public let type: String
}

public struct AbnormalEvent: Codable, Sendable { public let id: String; public let name: String; public let eligiblePhases: [Phase] }
public struct EmergencyRule: Codable, Sendable { public let id: String; public let eventClass: String; public let eventType: String; public let severity: String; public let eligiblePhases: [Phase] }
