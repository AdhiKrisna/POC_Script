import Foundation

public struct ScriptRequest: Equatable, Sendable {
    public let phase: Phase
    public let airportID: String
    public let profile: FlightProfile
    public let callsign: String?
    public let seed: Int
    public let includeAbnormal: Bool
    public let includeEmergency: Bool
    public let forcedEventID: String?

    public init(
        phase: Phase,
        airportID: String,
        profile: FlightProfile,
        callsign: String? = nil,
        seed: Int = 4207,
        includeAbnormal: Bool = false,
        includeEmergency: Bool = false,
        forcedEventID: String? = nil
    ) {
        self.phase = phase
        self.airportID = airportID
        self.profile = profile
        self.callsign = callsign
        self.seed = seed
        self.includeAbnormal = includeAbnormal
        self.includeEmergency = includeEmergency
        self.forcedEventID = forcedEventID
    }
}

public struct CriticalSlot: Equatable, Codable, Sendable {
    public let slot: String
    public let expectedValue: String
    public let type: String
    public let position: String?

    public init(slot: String, expectedValue: String, type: String, position: String? = nil) {
        self.slot = slot
        self.expectedValue = expectedValue
        self.type = type
        self.position = position
    }
}

public enum EventSeverity: String, Codable, Sendable {
    case normal = "NORMAL"
    case abnormal = "ABNORMAL"
    case urgency = "URGENCY"    // PAN PAN
    case distress = "DISTRESS"  // MAYDAY
}

public struct InjectedContingency: Equatable, Codable, Sendable {
    public let title: String
    public let severity: EventSeverity
    public let triggerPhase: Phase
    public let summary: String
    public let downstreamEffect: String

    public init(
        title: String,
        severity: EventSeverity,
        triggerPhase: Phase,
        summary: String,
        downstreamEffect: String
    ) {
        self.title = title
        self.severity = severity
        self.triggerPhase = triggerPhase
        self.summary = summary
        self.downstreamEffect = downstreamEffect
    }
}

public enum ContingencySelection: String, CaseIterable, Identifiable, Sendable {
    case auto = "Auto (Random by Difficulty)"
    case routineOnly = "Routine Only (Normal Flight)"

    // MARK: - LEVEL 2: Regional Commuter (15% Probability)
    case pushbackDelay = "Pushback Delay (Traffic Behind - Doc 9432 §4.3.1)"
    case stopPushback = "Stop Pushback Immediately (Doc 9432 §4.3.3)"
    case unableAltitude = "Unable Altitude Profile (Aircraft Performance - Doc 9432 §2.6)"
    case holdShortExact = "Hold Short Mandatory Readback (Doc 4444 §4.5.7.5b)"

    // MARK: - LEVEL 3: Tactical Commercial Operator (35% Probability)
    case runwayBacktrack = "Runway Backtrack (Doc 9432 §4.4.2)"
    case wakeTurbulenceLineUp = "Wake Turbulence Line-Up (2 Min Delay - Doc 4444 §5.8)"
    case conditionalLineUp = "Conditional Line-Up (Doc 9432 §4.5.7)"
    case immediateTakeoffOrVacate = "Immediate Take-off or Vacate Runway (Doc 9432 §4.5.5)"
    case holdingPatternEAT = "Holding Pattern & EAT (Doc 4444 §5.5)"
    case delayingVectorOrbit = "Delaying Vector / Orbit (Doc 9432 §4.6.5)"
    case continueApproachShortFinal = "Continue Approach on Short Final (Doc 9432 §4.7.1)"
    case lowPassInspection = "Low Pass Inspection (Gear Check - Doc 9432 §4.7.2)"
    case flapFailure = "Flap Asymmetry High-Speed Approach (Doc 9432 Ch 9)"
    case lightGunSignals = "Light Gun Signals (Ground Comms Failure - Doc 4444 §7.16)"

    // MARK: - LEVEL 4: Metropolitan Captain (60% Probability)
    case ctotSlotManagement = "CTOT Slot Management (ATFM Delay - Doc 4444 Ch 3)"
    case holdShortCrossing = "Dual Runway Crossing (Cross 25L, Hold Short 25R - Doc 4444 §7.6.3.2)"
    case callsignConfusion = "Callsign Confusion Vigilance (Doc 9432 §2.7.2)"
    case abortTakeoff = "Rejected Take-Off (RTO High Speed - Doc 9432 §4.5.11)"
    case tcasRA = "TCAS Resolution Advisory (Doc 4444 §15.7.3)"
    case slopOceanic = "Strategic Lateral Offset (SLOP - Doc 4444 §16.5)"
    case fuelDumping = "Fuel Dumping Procedure (Doc 9432 §11.2)"
    case passengerMedicalEmergency = "In-Flight Medical Diversion (Doc 4444 §15.1)"
    case communicableDiseases = "Communicable Disease Report (Doc 4444 §16.6)"
    case blownTireLanding = "Blown Tire Blocking Runway (Doc 4444 §15.1)"
    case hotBrakesInspection = "Hot Brakes Inspection on Taxiway (Doc 9432 §4.10)"
    case airborneCommsFailure = "Airborne Comms Failure / Squawk 7600 (Doc 4444 §15.3)"

    // MARK: - LEVEL 5: High-Risk Commander (100% Injected Challenges)
    case pilotInitiatedGoAround = "Pilot-Initiated Go-Around (Runway Obstruction - Doc 9432 §4.8.3)"
    case gpwsTerrainAvoidance = "GPWS Terrain Avoidance (UNABLE Heading - Doc 4444 §15.7.4)"
    case windShearMicroburst = "Severe Wind Shear Microburst (Doc 9432 §11.4)"
    case emergencyDescentDecompression = "Emergency Descent to FL100 (Cabin Decompression - Doc 4444 §15.1.4)"
    case efato = "EFATO / Engine Failure Drift-Down (Doc 4444 §15.1, §15.2)"
    case fuelEmergencyMayday = "MINIMUM FUEL vs MAYDAY FUEL (Doc 4444 §15.5.4)"
    case volcanicAshAvoidance = "Volcanic Ash Avoidance (Doc 4444 §15.8)"
    case impositionOfSilence = "Imposition of Silence (STOP TRANSMITTING - Doc 9432 §9.2.2)"
    case runwayExcursionARFF = "Runway Excursion / ARFF Alerting (Doc 4444 §9.2, §15.1)"
    case hijack7500 = "Unlawful Interference / Squawk 7500 (Doc 4444 §15.1.3)"
    case militaryInterception = "Military Interception (WILCO - Doc 4444 §15.4)"

    // Legacy Aliases for backward compatibility
    case runwayChange = "Runway Wind Shift (180° Change)"
    case forgottenLandingClearancePrompt = "Late Landing Clearance (Short Final Prompt)"
    case birdHazardHold = "Bird Hazard on Runway (Dispersal Hold)"
    case birdStrikeAbort = "Bird Strike on Take-off Roll (Abort)"
    case cancelLineUp = "Cancel Line-Up (Traffic Delay)"
    case emergencyLandingHold = "Inbound Emergency Priority (Hold Short / Cancel TO)"
    case weatherDeviation = "Weather Deviation En-Route (CB Avoidance)"
    case unsafeGear = "Unsafe Gear (VOR Holding & Check)"
    case unclearedGoAround = "No Clearance Received (Uncleared Go-Around)"
    case midAirEngineOut = "Mid-Air Engine Out (Diversion ASSIST)"
    case engineFailureFinal = "Engine Failure on Final (MAYDAY 4 DME)"
    case rnavFailure = "RNAV / GPS Failure (Vectoring)"
    case parallelBreakout = "Parallel Breakout (Simultaneous ILS Hazard)"
    case visualOrbitSpacing = "Visual Orbit for Spacing (360° Turn)"
    case extendDownwind = "Extend Downwind (Traffic Spacing)"
    case nordoBlindTransmission = "Transmitting Blind (NORDO Receiver Fail)"
    case radarAvoidingAction = "Radar Avoiding Action (Near-Miss Turn)"
    case lowVisibilityRVR = "Low Visibility RVR Breakdown (Cat II ILS)"
    case contaminatedRunwayBraking = "Contaminated Runway & Braking Action Poor"

    public var id: String { rawValue }

    /// True if this contingency triggers a transition from standard phraseology to
    /// constrained plain English (ICAO Doc 9835 §4.3.1 & Appendix B).
    public var requiresPlainEnglish: Bool {
        switch self {
        case .lowPassInspection, .unsafeGear:
            return true
        case .weatherDeviation, .volcanicAshAvoidance:
            return true
        case .birdStrikeAbort, .blownTireLanding, .hotBrakesInspection:
            return true
        case .passengerMedicalEmergency, .communicableDiseases:
            return true
        case .efato, .midAirEngineOut, .engineFailureFinal, .runwayExcursionARFF:
            return true
        case .emergencyDescentDecompression:
            return true
        case .fuelDumping, .fuelEmergencyMayday:
            return true
        case .windShearMicroburst:
            return true
        case .unableAltitude:
            return true
        default:
            return false
        }
    }

    public var defaultSeverity: EventSeverity {
        switch self {
        case .efato, .midAirEngineOut, .engineFailureFinal, .tcasRA, .parallelBreakout, .birdStrikeAbort, .emergencyDescentDecompression, .fuelEmergencyMayday, .runwayExcursionARFF, .hijack7500, .abortTakeoff:
            return .distress
        case .flapFailure, .lowPassInspection, .passengerMedicalEmergency, .fuelDumping, .communicableDiseases, .blownTireLanding, .hotBrakesInspection, .airborneCommsFailure, .nordoBlindTransmission, .gpwsTerrainAvoidance, .windShearMicroburst, .volcanicAshAvoidance, .impositionOfSilence, .militaryInterception, .unsafeGear, .unclearedGoAround, .radarAvoidingAction:
            return .urgency
        default:
            return .abnormal
        }
    }

    public var triggerPhase: Phase {
        switch self {
        case .auto, .routineOnly, .runwayChange, .holdShortCrossing, .pushbackDelay, .stopPushback, .holdShortExact, .ctotSlotManagement:
            return .preDeparture
        case .abortTakeoff, .efato, .cancelLineUp, .birdHazardHold, .birdStrikeAbort, .emergencyLandingHold, .wakeTurbulenceLineUp, .immediateTakeoffOrVacate, .runwayBacktrack, .conditionalLineUp, .callsignConfusion:
            return .departure
        case .weatherDeviation, .midAirEngineOut, .tcasRA, .nordoBlindTransmission, .radarAvoidingAction, .emergencyDescentDecompression, .unableAltitude, .holdingPatternEAT, .slopOceanic, .fuelDumping, .volcanicAshAvoidance, .militaryInterception, .hijack7500:
            return .enRoute
        case .rnavFailure, .passengerMedicalEmergency, .communicableDiseases, .fuelEmergencyMayday:
            return .arrival
        case .lowPassInspection, .forgottenLandingClearancePrompt, .flapFailure, .unsafeGear, .unclearedGoAround, .engineFailureFinal, .parallelBreakout, .visualOrbitSpacing, .extendDownwind, .impositionOfSilence, .lowVisibilityRVR, .contaminatedRunwayBraking, .delayingVectorOrbit, .airborneCommsFailure, .gpwsTerrainAvoidance, .windShearMicroburst:
            return .approach
        case .continueApproachShortFinal, .lightGunSignals, .blownTireLanding, .hotBrakesInspection, .pilotInitiatedGoAround, .runwayExcursionARFF:
            return .landing
        }
    }

    public var shortDisplayName: String {
        switch self {
        case .auto: "Auto"
        case .routineOnly: "Routine Only"
        case .pushbackDelay: "Pushback Delay"
        case .stopPushback: "Stop Pushback"
        case .unableAltitude: "Unable Climb Rate"
        case .holdShortExact: "Hold Short Exact"
        case .runwayBacktrack: "Runway Backtrack"
        case .conditionalLineUp: "Conditional Line-Up"
        case .holdingPatternEAT: "Holding Pattern & EAT"
        case .delayingVectorOrbit: "Delaying Orbit"
        case .continueApproachShortFinal: "Continue Approach"
        case .lightGunSignals: "Light Gun Signal"
        case .ctotSlotManagement: "CTOT Slot Delay"
        case .callsignConfusion: "Callsign Confusion"
        case .slopOceanic: "SLOP Offset"
        case .fuelDumping: "Fuel Dumping"
        case .communicableDiseases: "Communicable Disease"
        case .blownTireLanding: "Blown Tire on Roll"
        case .hotBrakesInspection: "Hot Brakes Check"
        case .airborneCommsFailure: "Airborne NORDO 7600"
        case .pilotInitiatedGoAround: "Pilot Go-Around"
        case .gpwsTerrainAvoidance: "GPWS Escape"
        case .windShearMicroburst: "Wind Shear Alert"
        case .fuelEmergencyMayday: "MAYDAY Fuel"
        case .volcanicAshAvoidance: "Volcanic Ash Escape"
        case .runwayExcursionARFF: "Runway Excursion"
        case .hijack7500: "Squawk 7500 Hijack"
        case .militaryInterception: "Military Intercept"
        case .runwayChange: "Runway Change"
        case .forgottenLandingClearancePrompt: "Late Landing Prompt"
        case .abortTakeoff: "Abort Take-Off"
        case .efato: "EFATO (Engine Out)"
        case .birdHazardHold: "Bird Hazard Hold"
        case .birdStrikeAbort: "Bird Strike Abort"
        case .cancelLineUp: "Cancel Line-Up"
        case .emergencyLandingHold: "Inbound Emergency Priority"
        case .lowPassInspection: "Low Pass Inspection"
        case .weatherDeviation: "Weather Deviation"
        case .flapFailure: "Flap Failure"
        case .unsafeGear: "Unsafe Gear"
        case .unclearedGoAround: "Uncleared Go-Around"
        case .midAirEngineOut: "Mid-Air Engine Out"
        case .holdShortCrossing: "Hold Short Crossing"
        case .engineFailureFinal: "Engine Failure Final"
        case .tcasRA: "TCAS RA"
        case .rnavFailure: "RNAV GPS Failure"
        case .parallelBreakout: "Parallel Breakout"
        case .visualOrbitSpacing: "Visual Orbit 360°"
        case .extendDownwind: "Extend Downwind"
        case .nordoBlindTransmission: "Blind Transmission (NORDO)"
        case .wakeTurbulenceLineUp: "Wake Turbulence Wait"
        case .immediateTakeoffOrVacate: "Takeoff or Vacate"
        case .radarAvoidingAction: "Avoiding Action (Near-Miss)"
        case .emergencyDescentDecompression: "Emergency Descent (Cabin Alt)"
        case .impositionOfSilence: "Silence Imposed (MAYDAY)"
        case .passengerMedicalEmergency: "Medical Priority (PAN PAN)"
        case .lowVisibilityRVR: "Low Visibility RVR"
        case .contaminatedRunwayBraking: "Runway Water / Braking Poor"
        }
    }
}

// MARK: - Language Layer (ICAO Doc 9835 §4.3.1 Hierarchy)
/// Distinguishes standard phraseology from plain-English exchanges in a script.
/// Per Doc 9835: Layer 1 = mandatory standard; Layer 2 = plain English only when
/// no standard phrase covers the intended transmission.
public enum LanguageLayer: String, Codable, Sendable {
    /// Layer 1 — ICAO Doc 9432 standard phraseology (mandatory, deterministic readback required)
    case standardPhraseology = "STANDARD"
    /// Layer 2 — Constrained Plain English (Doc 9835 §4.3.1): used ONLY when no standard phrase covers the situation
    case constrainedPlainEnglish = "PLAIN_EN"
    /// Anchor word embedded in a plain-English transition (e.g. ROGER, WILCO, AFFIRM)
    case anchorWord = "ANCHOR"
}

public struct FilledExchange: Equatable, Codable, Sendable, Identifiable {
    public var id: String { exchangeID }
    public let exchangeID: String
    public let templateID: String
    public let turn: Int
    public let speaker: String
    public let isUserTurn: Bool
    public let text: String
    public let criticalSlots: [CriticalSlot]
    public let severity: EventSeverity
    public let eventTag: String?
    /// Language layer for this transmission (Doc 9835 §4.3.1)
    public let languageLayer: LanguageLayer
    /// Human-readable explanation of WHY plain English is used (nil for standard phraseology)
    /// e.g. "No standard phrase for gear-unsafe low pass request (Doc 9835 §3.3.19)"
    public let plainEnglishTrigger: String?
    /// Educational goal / operational context for this speaking turn (especially for user turns)
    public let objective: String?

    public init(
        exchangeID: String,
        templateID: String,
        turn: Int,
        speaker: String,
        isUserTurn: Bool,
        text: String,
        criticalSlots: [CriticalSlot],
        severity: EventSeverity = .normal,
        eventTag: String? = nil,
        languageLayer: LanguageLayer = .standardPhraseology,
        plainEnglishTrigger: String? = nil,
        objective: String? = nil
    ) {
        self.exchangeID = exchangeID
        self.templateID = templateID
        self.turn = turn
        self.speaker = speaker
        self.isUserTurn = isUserTurn
        self.text = text
        self.criticalSlots = criticalSlots
        self.severity = severity
        self.eventTag = eventTag
        self.languageLayer = languageLayer
        self.plainEnglishTrigger = plainEnglishTrigger
        if let obj = objective {
            self.objective = obj
        } else if isUserTurn {
            self.objective = Self.resolveDefaultObjective(tag: eventTag, text: text, templateID: templateID)
        } else {
            self.objective = nil
        }
    }

    private static func resolveDefaultObjective(tag: String?, text: String, templateID: String) -> String? {
        let lower = text.lowercased()
        let t = (tag ?? "").uppercased()

        if t.contains("ATC HEARBACK CORRECTION") {
            return "Koreksi kesalahan readback (slip of the tongue) pilot: tegaskan NEGATIVE I SAY AGAIN dan sebutkan variabel yang benar (Doc 9432 §2.8.3.9)."
        }
        if t.contains("CALLSIGN CONFUSION CORRECTION") {
            return "Intersepsi kerancuan callsign (similar callsign confusion): tegur pesawat yang salah ambil izin dengan NEGATIVE dan instruksikan hold position (Doc 9432 §4.3.2)."
        }
        if t.contains("DEPARTURE CHECK-IN") {
            return "Hubungi Departure Control setelah mengudara, laporkan ketinggian saat ini dan ketinggian tuju."
        }
        if t.contains("TRANSFER CONTROL") {
            return "Readback alih kendali frekuensi ke Area Control Center (ACC)."
        }
        if t.contains("AREA CONTROL CHECK-IN") {
            return "Check-in awal ke Area Control, laporkan flight level saat ini dan estimasi waypoint."
        }
        if t.contains("APPROACH CHECK-IN") {
            return "Check-in awal ke Approach Control, laporkan ketinggian penurunan dan kode ATIS yang diterima."
        }
        if t.contains("LOCALIZER ESTABLISHED FINAL") {
            return "Laporkan pesawat telah mengunci garis pemancar localizer ILS pada short final ke Tower."
        }
        if t.contains("GROUND CHECK-IN") {
            return "Hubungi Ground Control setelah keluar landasan pacu dan minta rute taxi ke stand/gate."
        }
        if t.contains("ROLL OUT") {
            return "Readback instruksi rollout hingga ujung landasan pacu dengan kawalan armada pemadam PKP-PK."
        }
        if t.contains("CHECK-IN SINGLE ENGINE") {
            return "Check-in ke Approach Control, laporkan status single-engine MAYDAY dan minta vektor ILS lurus."
        }
        if t.contains("REPORT FINAL MAYDAY") {
            return "Laporkan posisi final darurat (short final single engine) dan kesiapan konfigurasi roda."
        }
        if t.contains("EXPEDITE VACATE") {
            return "Readback percepatan pengosongan landasan pacu (expedite vacate) dan kontak Ground."
        }
        if t.contains("CANCEL MAYDAY") {
            return "Batalkan status marabahaya MAYDAY setelah pesawat berhenti aman dan pemeriksaan darat selesai."
        }
        if t.contains("RESUME") || t.contains("NAVIGATION") {
            return "Readback instruksi resume own navigation kembali ke rute atau waypoint yang ditentukan."
        }
        if t.contains("INTERCEPT") {
            return "Readback penyesuaian kecepatan, heading intersep localizer, dan izin pendekatan ILS."
        }
        if t.contains("TOWER FREQ") {
            return "Readback pembatalan restriksi kecepatan dan alih kendali frekuensi ke Menara Pengawas (Tower)."
        }
        if t.contains("BACKTRACK") {
            return "Readback instruksi backtrack di landasan pacu aktif dan lapor siap lepas landas."
        }
        if t.contains("CONDITIONAL") {
            return "Readback instruksi conditional line up and wait di belakang pesawat yang mendarat/lepas landas."
        }
        if t.contains("CONSTRAINT") {
            return "Readback restriksi batas ketinggian dan kecepatan jelajah di waypoint."
        }
        if t.contains("SECOND ILS") {
            return "Readback izin pendekatan ILS kedua setelah pelaksanaan prosedur missed approach/holding."
        }
        if t.contains("TAXI TO GATE") {
            return "Readback instruksi taxi menuju apron atau gate kedatangan."
        }
        if t.contains("STRAIGHT-IN") {
            return "Readback izin pendekatan lurus (straight-in approach) dan frekuensi Tower."
        }
        if t.contains("STOPPING") || t.contains("ABORTING") {
            return "Laporkan pembatalan lepas landas (aborting take-off) di darat dan status pesawat berhenti."
        }
        if t.contains("TAKING OFF IMMEDIATELY") {
            return "Readback izin lepas landas segera (immediate take-off) tanpa berhenti di landasan."
        }
        if t.contains("FLAP") {
            return "Deklarasikan urgensi PAN PAN akibat kegagalan ekstensi flap, laporkan kecepatan pendekatan lebih tinggi (160 kts), dan minta pendaratan prioritas straight-in."
        }
        if t.contains("LOW PASS") || t.contains("INSPECTION") {
            return "Minta izin terbang rendah (low pass) di atas menara pengawas untuk inspeksi visual roda pendaratan oleh tower cab."
        }
        if t.contains("GEAR") || t.contains("UNSAFE") {
            return "Laporkan indikasi roda pendaratan tidak mengunci (unsafe gear) dan minta holding untuk menjalankan checklist darurat."
        }
        if t.contains("MEDICAL") {
            return "Deklarasikan urgensi PAN PAN medis penumpang sakit dan minta ambulans siaga di stand/gate kedatangan."
        }
        if t.contains("ENGINE OUT") || t.contains("ENGINE FAILURE") || t.contains("EFATO") {
            return "Deklarasikan marabahaya MAYDAY akibat mati mesin, laporkan jumlah jiwa di pesawat (POB) dan sisa bahan bakar (endurance)."
        }
        if t.contains("DECOMPRESSION") || t.contains("EMERGENCY DESCENT") {
            return "Deklarasikan MAYDAY dekompresi kabin mendadak dan lakukan penurunan darurat (emergency descent) ke ketinggian aman."
        }
        if t.contains("AVOIDING ACTION") {
            return "Laksanakan dan readback manuver menghindar segera dari trafik berlawanan."
        }
        if t.contains("IMMEDIATE") || t.contains("EXPEDITE") {
            return "Readback instruksi lepas landas segera (immediate departure) atau bersiap keluar landasan untuk menjaga separasi trafik final."
        }
        if t.contains("CROSSING") || t.contains("INCURSION") {
            return "Readback wajib instruksi hold short taxiway crossing sebelum melintasi landasan pacu paralel aktif."
        }
        if t.contains("BRAKING") || t.contains("CONTAMINATED") {
            return "Readback izin mendarat dan konfirmasi penerimaan informasi landasan basah/pengereman buruk (braking action poor)."
        }
        if t.contains("NORDO") || t.contains("TRANSMITTING BLIND") {
            return "Lakukan transmisi radio satu arah (transmitting blind) sesuai prosedur kegagalan penerimaan ICAO."
        }
        if t.contains("ABORT") {
            return "Laporkan pembatalan lepas landas (abort take-off) pada ground roll dan minta bantuan inspeksi di landasan pacu."
        }
        if t.contains("BIRD") {
            return "Readback peringatan aktivitas kawanan burung (bird hazard) di area operasi landasan pacu."
        }
        if t.contains("RUNWAY CHANGE") {
            return "Readback perubahan landasan pacu aktif dan sesuaikan konfigurasi rute/prosedur lepas landas."
        }
        if t.contains("CANCEL LINE UP") {
            return "Readback pembatalan instruksi line-up dan tetap hold short sebelum landasan pacu."
        }
        if t.contains("TOUCH AND GO") {
            return "Readback izin touch-and-go di sirkuit visual."
        }
        if t.contains("ORBIT") {
            return "Readback instruksi orbit visual 360° untuk separasi trafik."
        }
        if t.contains("DOWNWIND") {
            return "Laporkan posisi downwind leg di pola sirkuit visual."
        }
        if t.contains("IFR CLEARANCE") {
            return "Minta izin rute IFR (CRAFT clearance) ke bandara tujuan."
        }
        if t.contains("READBACK CLEARANCE") {
            return "Lakukan readback lengkap seluruh variabel izin rute IFR."
        }
        if t.contains("READBACK STANDBY") || t.contains("STANDBY") {
            return "Konfirmasi status standby menunggu instruksi ATC."
        }
        if t.contains("READBACK PUSHBACK") || t.contains("PUSHBACK") {
            return "Readback izin start-up dan pushback dengan arah hadap pesawat."
        }
        if t.contains("READBACK TAXI") || t.contains("TAXI") {
            return "Readback rute taxi dan kepatuhan wajib hold short runway aktif."
        }
        if t.contains("READY FOR DEPARTURE") {
            return "Laporkan pesawat siap lepas landas di holding point runway aktif."
        }
        if t.contains("WAKE LINE UP") {
            return "Readback line up and wait dan waspadai turbulensi vorteks (wake turbulence)."
        }
        if t.contains("READBACK LINE UP") || t.contains("LINE UP") {
            return "Readback instruksi line up and wait di runway aktif."
        }
        if t.contains("READBACK CLEARED TAKEOFF") || t.contains("TAKEOFF") || t.contains("TAKE-OFF") {
            return "Readback izin lepas landas (take-off clearance) dan nomor runway."
        }
        if t.contains("AIRBORNE") || t.contains("DEPARTURE FREQ") {
            return "Readback kontak frekuensi Departure Control setelah mengudara."
        }
        if t.contains("CLIMB") {
            return "Readback instruksi climb ke ketinggian jelajah dan direct waypoint."
        }
        if t.contains("REACHING") {
            return "Laporkan pesawat telah mencapai flight level jelajah."
        }
        if t.contains("WEATHER") || t.contains("DEVIATION") {
            if lower.contains("request") {
                return "Minta izin deviasi arah terbang untuk menghindari awan badai CB."
            } else if lower.contains("clear") {
                return "Lapor telah bebas dari awan badai dan minta kembali ke rute penerbangan."
            }
            return "Readback persetujuan deviasi cuaca dan pembatasan jarak/arah."
        }
        if t.contains("TCAS") {
            return "Laporkan respons manuver menghindar TCAS Resolution Advisory (TCAS RA)."
        }
        if t.contains("STAR") || t.contains("DESCENT") {
            return "Readback izin penurunan bertahap dan rute kedatangan STAR."
        }
        if t.contains("LEVEL RESTRICTION") || t.contains("SPEED") {
            return "Readback restriksi batas ketinggian dan kecepatan di waypoint."
        }
        if t.contains("LOCALIZER") || t.contains("ESTABLISHED") {
            return "Laporkan pesawat telah mengunci garis pemancar localizer ILS."
        }
        if t.contains("ILS") || t.contains("APPROACH") {
            return "Readback vektor radar intersep heading dan izin pendekatan ILS."
        }
        if t.contains("CLEARED TO LAND") || t.contains("LANDING") {
            return "Readback izin mendarat (cleared to land) dan nomor runway."
        }
        if t.contains("VACATE") {
            return "Readback instruksi keluar landasan (vacate) via taxiway dan kontak Ground."
        }
        if t.contains("CLOSE") || t.contains("SHUTDOWN") {
            return "Lapor mesin telah dimatikan di stand/gate dan minta penutupan flight plan."
        }
        if t.contains("GOOD DAY") {
            return "Tutup komunikasi radio dengan ucapan baku 'good day'."
        }
        if t.contains("GO-AROUND") || t.contains("GOING AROUND") {
            return "Laksanakan manuver pembatalan pendaratan (Go-Around) demi keselamatan."
        }
        if t.contains("HOLDING") {
            return "Readback instruksi holding pattern di atas fix dan level tunggu."
        }

        // Text heuristics fallback
        if lower.contains("cleared to land") {
            return "Readback izin mendarat (cleared to land) dan nomor runway."
        }
        if lower.contains("cleared for take-off") {
            return "Readback izin lepas landas dan verifikasi nomor runway."
        }
        if lower.contains("hold short") {
            return "Readback wajib instruksi hold short sebelum memasuki runway aktif."
        }
        if lower.contains("line up and wait") {
            return "Readback instruksi line up and wait di runway aktif."
        }
        if lower.contains("going around") {
            return "Laporkan pembatalan pendaratan mandiri (Go-Around) ke Tower."
        }
        if lower.contains("standby") || lower.contains("standing by") {
            return "Konfirmasi status standby menunggu giliran komunikasi."
        }
        if lower.contains("contact") {
            return "Readback alih kendali frekuensi ke unit ATC berikutnya."
        }
        if lower.contains("climb") || lower.contains("descend") {
            return "Readback instruksi perubahan ketinggian atau flight level."
        }
        if lower.contains("qnh") {
            return "Konfirmasi pengaturan altimeter QNH dan informasi kedatangan/keberangkatan."
        }
        if lower.contains("good day") {
            return "Tutup komunikasi radio dengan ucapan baku."
        }

        return "Sampaikan transmisi komunikasi radio standar ICAO sesuai giliran."
    }
}

public struct SlotContext: Equatable, Sendable {
    public let airport: Airport
    public let selectedRunway: Runway
    public let holdingPoint: String
    public let taxiRoute: String
    public let callsign: String
    public let weather: AlignedWeather
    public let atisId: String
    public let unitGround: ATCUnit?
    public let unitTower: ATCUnit?
    public let unitApproach: ATCUnit?
    public let unitDeparture: ATCUnit?
    public let unitDelivery: ATCUnit?
    public let unitControl: ATCUnit?
    public let stand: String
    public let aircraftType: String
    public let pob: Int

    // Extended flight parameters
    public let airportName: String
    public let destinationName: String
    public let sidProcedure: String
    public let starProcedure: String
    public let squawk: String
    public let depFreq: String
    public let approachFreq: String
    public let controlFreq: String
    public let arrRunway: String
    public let arrAtisId: String
    public let visibility: String
    public let cloudCondition: String
    public let temperature: String
    public let dewPoint: String

    public let turnDirection: String
    public let heading: Int
    public let initialAlt: String
    public let levelStatus: String
    public let currentLevel: String
    public let routeContext: String
    public let currentPosition: String
    public let timeUTC: String
    public let nextPosition: String
    public let nextETA: String
    public let requestedLevel: String
    public let requestedDeviationDistance: String
    public let requestedDeviationDirection: String
    public let approvedDeviationDistance: String
    public let approvedDeviationDirection: String
    public let descentLevel: String
    public let holdingFix: String
    public let holdingLevel: String
    public let inboundTrack: String
    public let eat: String
    public let goAroundReason: String
    public let missedAlt: String
    public let missedInstruction: String
    public let exitDirection: String
    public let exitTaxiway: String
    public let destinationStand: String
    public let taxiInRoute: String
}

public struct GeneratedScript: Equatable, Sendable {
    public let id: UUID
    public let seed: Int
    public let phase: Phase
    public let airport: String
    public let callsign: String
    public let context: SlotContext
    public let exchanges: [FilledExchange]
    public let criticalSlots: [CriticalSlot]
}

// MARK: - Full Flight Mission Models

public enum UserRole: String, CaseIterable, Identifiable, Sendable {
    case pilot = "Student Pilot"
    case atc = "ATC Trainee"
    public var id: String { rawValue }
}

public enum SimulationMode: String, CaseIterable, Identifiable, Sendable {
    case practice = "Practice Mode"
    case learning = "Learning Mode"
    public var id: String { rawValue }
}

public enum CurriculumLevel: Int, CaseIterable, Identifiable, Comparable, Sendable {
    case level1 = 1
    case level2 = 2
    case level3 = 3
    case level4 = 4
    case level5 = 5

    public var id: Int { rawValue }

    public static func < (lhs: CurriculumLevel, rhs: CurriculumLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var nextLevel: CurriculumLevel? {
        CurriculumLevel(rawValue: rawValue + 1)
    }

    public var title: String {
        switch self {
        case .level1: "Level 1: Flight School & Local Training"
        case .level2: "Level 2: Regional Controlled & Basic Instrument"
        case .level3: "Level 3: Busy Single-Runway & Backtrack"
        case .level4: "Level 4: Major Hub & Multi-Runway"
        case .level5: "Level 5: Extreme Terrain & High-Risk Valley"
        }
    }

    public var levelCategory: String {
        switch self {
        case .level1: "Flight School & Local Training"
        case .level2: "Regional Controlled & Basic Instrument"
        case .level3: "Busy Single-Runway & Backtrack"
        case .level4: "Major Hub & Multi-Runway"
        case .level5: "Extreme Terrain & High-Risk Valley"
        }
    }

    public var icaoDocReference: String {
        switch self {
        case .level1: "ICAO Doc 9432 Sec 4.4, Doc 9835 Structure & Fluency"
        case .level2: "ICAO Doc 9432 Sec 4.5, Doc 4444 Ch 4 & 6"
        case .level3: "ICAO Doc 4444 Sec 12.2.7 (Conditional) & Sec 8.6 (Vectors)"
        case .level4: "ICAO Doc 4444 Ch 7 (Surface Safety) & Doc 9432 Sec 4.7"
        case .level5: "ICAO Doc 9835 App B (Plain English) & Doc 4444 Ch 15 (Emergency)"
        }
    }

    public var sidProcedure: String {
        switch self {
        case .level1: "Circuit Departure"
        case .level2: "Area Alpha Departure via Selat Bali"
        case .level3: "BLI Two Charlie (BLI 2C)"
        case .level4: "SURABAYA One Bravo (SBY 1B)"
        case .level5: "JOG One Charlie (JOG 1C)"
        }
    }

    public var starProcedure: String {
        switch self {
        case .level1: "Overhead Join Pattern"
        case .level2: "Right Base Runway 09"
        case .level3: "POSOP One Alfa (POSOP 1A)"
        case .level4: "GANDI One Alfa (GANDI 1A)"
        case .level5: "DOLTA One Alfa (DOLTA 1A)"
        }
    }

    public var act1Focus: String {
        switch self {
        case .level1: "Radio check, taxi holding point visual, take-off standard, pelafalan angka baku."
        case .level2: "IFR clearance delivery via SID, readback 2 variabel (FL & heading), pushback tanpa hambatan."
        case .level3: "Conditional line-up ('Behind landing B737, line up and wait'), departure heading restriction."
        case .level4: "Taxi clearance panjang melewati beberapa persimpangan aktif, kepatuhan hold short ketat."
        case .level5: "A-CDM TSAT timing, keberangkatan parallel runway, koordinasi slot padat."
        }
    }

    public var act2Focus: String {
        switch self {
        case .level1: "Laporan posisi downwind leg, visual traffic spacing, orbit 360° bila padat."
        case .level2: "Handover ke Departure Radar, instruksi climb ke cruising level, transfer sektor ACC."
        case .level3: "Radar vectoring taktis menghindari trafik berlawanan, speed restriction (deselerasi)."
        case .level4: "Step-climb bertahap di ruang udara TMA padat, pergantian frekuensi cepat tanpa blocking."
        case .level5: "Deviasi cuaca buruk (CB cloud 20 NM), Plain English negotiation, TCAS RA response."
        }
    }

    public var act3Focus: String {
        switch self {
        case .level1: "Clearance touch-and-go / full stop, vacating runway, taxi kembali ke apron latih."
        case .level2: "Clearance STAR standar, capture ILS localizer, landing clearance, taxi ke gate."
        case .level3: "Holding pattern 1 putaran di atas VOR (antrean), pembatalan instrumen/visual mendadak."
        case .level4: "Instruksi Go-Around mendadak di ketinggian 500 kaki (runway belum steril), reposisi radar."
        case .level5: "Skenario darurat (PAN-PAN / MAYDAY: gear unsafe / engine out), prioritas pendaratan & PKP-PK."
        }
    }

    public var defaultProfile: FlightProfile {
        switch self {
        case .level1: .vfrLocal
        case .level2, .level3, .level4, .level5: .ifrCommercial
        }
    }

    public var curriculumObjective: String {
        switch self {
        case .level1: "Pembentukan fondasi frasa ICAO, disiplin sirkuit visual, dan operasi prosedural tanpa radar."
        case .level2: "Transisi ruang udara, transfer frekuensi (handoff), dan integrasi lalu lintas campuran VFR-IFR."
        case .level3: "Kepatuhan penuh aturan terbang instrumen (IFR), vektor radar taktis, dan prosedur instrumen kompleks."
        case .level4: "Navigasi koridor padat, operasi darat multi-landasan, fragmentasi frekuensi, dan disiplin anti-blocking."
        case .level5: "Kepatuhan slot waktu A-CDM, RNAV 1 kompleks, holding stack EFC time, dan simultaneous parallel approach."
        }
    }

    // MARK: - Pilot Ranks (APP_FLOW_CIA.pdf & Hariri et al. 2026)
    public var pilotRankCode: String {
        switch self {
        case .level1: "Rank 01"
        case .level2: "Rank 02"
        case .level3: "Rank 03"
        case .level4: "Rank 04"
        case .level5: "Rank 05"
        }
    }

    public var pilotRankTitle: String {
        switch self {
        case .level1: "Flight Cadet"
        case .level2: "Radio Trainee"
        case .level3: "Flight Navigator"
        case .level4: "Advanced Aviator"
        case .level5: "Skybound Elite"
        }
    }

    public var pilotRankSubtitle: String {
        switch self {
        case .level1: "Fondasi komunikasi rutin dan prosedur dasar"
        case .level2: "Melatih ketelitian terhadap angka dan instruksi dinamis"
        case .level3: "Menghadapi traffic, antrean, dan kontinjensi taktis"
        case .level4: "Berlatih dalam lingkungan hub yang padat dan kompleks"
        case .level5: "Menghadapi skenario yang menuntut pengambilan keputusan dan mitigasi risiko ekstrem"
        }
    }

    public var targetWpmRange: String {
        switch self {
        case .level1: "80 – 90 WPM (Tempo Pembelajaran)"
        case .level2, .level3, .level4, .level5: "100 – 120 WPM (Standar Baku ICAO)"
        }
    }

    public var emergencyFocus: String {
        switch self {
        case .level1: "EFATO (Engine Failure After Takeoff) / NORDO (No Radio)"
        case .level2: "Awan CB Selat Bali (Weather Deviation) / Flap System Failure"
        case .level3: "Unsafe Gear Indication / Missed Approach & Holding Pattern"
        case .level4: "Engine Failure on Final Approach / Runway Crossing Blocked / Fuel Emergency"
        case .level5: "TCAS Resolution Advisory (TCAS RA) / RNAV GPS Failure / Parallel Breakout"
        }
    }

    public var sidName: String {
        switch self {
        case .level1: "Circuit Departure"
        case .level2: "Area Alpha Departure via Selat Bali"
        case .level3: "BLI Two Charlie (BLI 2C)"
        case .level4: "SURABAYA One Bravo (SBY 1B)"
        case .level5: "JOG One Charlie (JOG 1C)"
        }
    }

    public var starName: String {
        switch self {
        case .level1: "Overhead Join Pattern"
        case .level2: "Right Base Runway 09"
        case .level3: "POSOP One Alfa (POSOP 1A)"
        case .level4: "GANDI One Alfa (GANDI 1A)"
        case .level5: "DOLTA One Alfa (DOLTA 1A)"
        }
    }

    public var criticalPhrases: [String] {
        switch self {
        case .level1:
            return ["Backtrack runway 08 approved", "Report downwind", "Touch and go approved", "Orbit right present position"]
        case .level2:
            return ["Contact Bali Approach 124.0", "Caution wake turbulence behind B737", "Join right base runway 09"]
        case .level3:
            return ["Cleared to Surabaya via W17", "Vector for ILS runway 10", "Reduce speed 160 knots", "Execute missed approach"]
        case .level4:
            return ["Pushback facing north", "Cross runway 25L hold short 25R", "Direct BUNTA", "Contact Jakarta Director 124.35"]
        case .level5:
            return ["Cancel speed restriction above 10,000", "Cross BUNTA at FL140, 220 knots", "Expect further clearance at 45", "TCAS RA, returning FL180"]
        }
    }

    public var allowedContingencies: [ContingencySelection] {
        switch self {
        case .level1:
            // LEVEL 1: Ab-Initio Cadet (100% Prosedur Rutin Murni, zero anomalies)
            return [
                .routineOnly
            ]
        case .level2:
            // LEVEL 2: Regional Commuter (Peluang 15%)
            return [
                .auto,
                .routineOnly,
                .pushbackDelay,
                .stopPushback,
                .unableAltitude,
                .holdShortExact
            ]
        case .level3:
            // LEVEL 3: Tactical Commercial Operator (Peluang 35%)
            return [
                .auto,
                .routineOnly,
                .runwayBacktrack,
                .wakeTurbulenceLineUp,
                .conditionalLineUp,
                .immediateTakeoffOrVacate,
                .holdingPatternEAT,
                .delayingVectorOrbit,
                .continueApproachShortFinal,
                .lowPassInspection,
                .flapFailure,
                .lightGunSignals
            ]
        case .level4:
            // LEVEL 4: Metropolitan Captain (Peluang 60%)
            return [
                .auto,
                .routineOnly,
                .ctotSlotManagement,
                .holdShortCrossing,
                .callsignConfusion,
                .abortTakeoff,
                .tcasRA,
                .slopOceanic,
                .fuelDumping,
                .passengerMedicalEmergency,
                .communicableDiseases,
                .blownTireLanding,
                .hotBrakesInspection,
                .airborneCommsFailure
            ]
        case .level5:
            // LEVEL 5: High-Risk Commander (100% Injected Challenges)
            return [
                .auto,
                .routineOnly,
                .pilotInitiatedGoAround,
                .gpwsTerrainAvoidance,
                .windShearMicroburst,
                .emergencyDescentDecompression,
                .efato,
                .fuelEmergencyMayday,
                .volcanicAshAvoidance,
                .impositionOfSilence,
                .runwayExcursionARFF,
                .hijack7500,
                .militaryInterception
            ]
        }
    }

    public var allowedScenarios: [ContingencySelection] {
        allowedContingencies.filter { $0 != .auto && $0 != .routineOnly }
    }
}

// MARK: - Dynamic Airport Registry & 3-Act Mission Models

public struct AirportCurriculumItem: Identifiable, Hashable, Sendable {
    public var id: String { icao }
    public let icao: String
    public let iata: String
    public let name: String
    public let city: String
    public let assignedLevel: CurriculumLevel
    public let defaultProfile: FlightProfile
    public let runwaySummary: String
    public let primaryFreq: String

    public init(
        icao: String,
        iata: String,
        name: String,
        city: String,
        assignedLevel: CurriculumLevel,
        defaultProfile: FlightProfile,
        runwaySummary: String,
        primaryFreq: String
    ) {
        self.icao = icao
        self.iata = iata
        self.name = name
        self.city = city
        self.assignedLevel = assignedLevel
        self.defaultProfile = defaultProfile
        self.runwaySummary = runwaySummary
        self.primaryFreq = primaryFreq
    }
}

public struct AirportCurriculumRegistry: Sendable {
    public static let allAirports: [AirportCurriculumItem] = [
        // Level 1: Flight School & Local Training
        AirportCurriculumItem(
            icao: "WADY", iata: "BWX", name: "Banyuwangi", city: "Rogojampi, Banyuwangi",
            assignedLevel: .level1, defaultProfile: .vfrLocal,
            runwaySummary: "RWY 08/26 (7382 ft)", primaryFreq: "TWR 118.100"
        ),
        AirportCurriculumItem(
            icao: "WICB", iata: "CURUG", name: "Budiarto Curug", city: "Curug, Tangerang",
            assignedLevel: .level1, defaultProfile: .vfrLocal,
            runwaySummary: "RWY 12/30, 04/22 (6562 ft)", primaryFreq: "TWR 118.300"
        ),
        AirportCurriculumItem(
            icao: "WADE", iata: "TTR", name: "Wisnu Buleleng", city: "Buleleng, Bali",
            assignedLevel: .level1, defaultProfile: .vfrLocal,
            runwaySummary: "RWY 14/32 (2233 ft)", primaryFreq: "TWR 118.300"
        ),

        // Level 2: Regional Controlled & Basic Instrument
        AirportCurriculumItem(
            icao: "WAHI", iata: "YIA", name: "Yogyakarta International", city: "Kulon Progo, Yogyakarta",
            assignedLevel: .level2, defaultProfile: .ifrCommercial,
            runwaySummary: "RWY 11/29 (10663 ft)", primaryFreq: "TWR 118.400"
        ),
        AirportCurriculumItem(
            icao: "WADL", iata: "LOP", name: "Lombok Praya", city: "Praya, Lombok",
            assignedLevel: .level2, defaultProfile: .ifrCommercial,
            runwaySummary: "RWY 13/31 (10826 ft)", primaryFreq: "TWR 118.100"
        ),
        AirportCurriculumItem(
            icao: "WIPP", iata: "PLM", name: "Sultan Mahmud Badaruddin II", city: "Palembang",
            assignedLevel: .level2, defaultProfile: .ifrCommercial,
            runwaySummary: "RWY 11/29 (8202 ft)", primaryFreq: "TWR 118.100"
        ),
        AirportCurriculumItem(
            icao: "WAOO", iata: "BDJ", name: "Syamsudin Noor Banjarmasin", city: "Banjarmasin",
            assignedLevel: .level2, defaultProfile: .ifrCommercial,
            runwaySummary: "RWY 10/28 (8202 ft)", primaryFreq: "TWR 118.100"
        ),

        // Level 3: Busy Single-Runway & Backtrack
        AirportCurriculumItem(
            icao: "WADD", iata: "DPS", name: "Ngurah Rai Bali", city: "Denpasar, Bali",
            assignedLevel: .level3, defaultProfile: .ifrCommercial,
            runwaySummary: "RWY 09/27 (9842 ft)", primaryFreq: "TWR 118.100"
        ),
        AirportCurriculumItem(
            icao: "WARS", iata: "SRG", name: "Ahmad Yani Semarang", city: "Semarang",
            assignedLevel: .level3, defaultProfile: .ifrCommercial,
            runwaySummary: "RWY 13/31 (8399 ft)", primaryFreq: "TWR 118.300"
        ),
        AirportCurriculumItem(
            icao: "WIDD", iata: "BTH", name: "Hang Nadim Batam", city: "Batam",
            assignedLevel: .level3, defaultProfile: .ifrCommercial,
            runwaySummary: "RWY 04/22 (13218 ft)", primaryFreq: "TWR 118.700"
        ),
        AirportCurriculumItem(
            icao: "WIPT", iata: "PDG", name: "Minangkabau Padang", city: "Padang",
            assignedLevel: .level3, defaultProfile: .ifrCommercial,
            runwaySummary: "RWY 15/33 (9843 ft)", primaryFreq: "TWR 118.100"
        ),
        AirportCurriculumItem(
            icao: "WARQ", iata: "SOC", name: "Adisoemarmo Solo", city: "Solo",
            assignedLevel: .level3, defaultProfile: .ifrCommercial,
            runwaySummary: "RWY 08/26 (8530 ft)", primaryFreq: "TWR 118.300"
        ),
        AirportCurriculumItem(
            icao: "WALL", iata: "BPN", name: "Sepinggan Balikpapan", city: "Balikpapan",
            assignedLevel: .level3, defaultProfile: .ifrCommercial,
            runwaySummary: "RWY 07/25 (8202 ft)", primaryFreq: "TWR 118.100"
        ),

        // Level 4: Major Hub & Multi-Runway
        AirportCurriculumItem(
            icao: "WIII", iata: "CGK", name: "Soekarno-Hatta Jakarta", city: "Jakarta",
            assignedLevel: .level4, defaultProfile: .ifrCommercial,
            runwaySummary: "3 Runways (12008 ft)", primaryFreq: "TWR 118.200"
        ),
        AirportCurriculumItem(
            icao: "WARR", iata: "SUB", name: "Juanda Surabaya", city: "Surabaya",
            assignedLevel: .level4, defaultProfile: .ifrCommercial,
            runwaySummary: "RWY 10/28 (9843 ft)", primaryFreq: "TWR 118.300"
        ),
        AirportCurriculumItem(
            icao: "WAAA", iata: "UPG", name: "Sultan Hasanuddin Makassar", city: "Makassar",
            assignedLevel: .level4, defaultProfile: .ifrCommercial,
            runwaySummary: "RWY 03/21, 13/31 (10171 ft)", primaryFreq: "TWR 118.100"
        ),
        AirportCurriculumItem(
            icao: "WIMM", iata: "KNO", name: "Kualanamu Medan", city: "Medan",
            assignedLevel: .level4, defaultProfile: .ifrCommercial,
            runwaySummary: "RWY 05/23 (12303 ft)", primaryFreq: "TWR 118.300"
        ),
        AirportCurriculumItem(
            icao: "WIHH", iata: "HLP", name: "Halim Perdanakusuma Jakarta", city: "Jakarta",
            assignedLevel: .level4, defaultProfile: .ifrCommercial,
            runwaySummary: "RWY 06/24 (9843 ft)", primaryFreq: "TWR 118.600"
        ),

        // Level 5: Extreme Terrain & High-Risk Valley
        AirportCurriculumItem(
            icao: "WAVV", iata: "WMX", name: "Wamena", city: "Wamena, Papua Pegunungan",
            assignedLevel: .level5, defaultProfile: .ifrCommercial,
            runwaySummary: "RWY 15/33 (7135 ft, El 5435 ft)", primaryFreq: "TWR 122.200"
        ),
        AirportCurriculumItem(
            icao: "WICC", iata: "BDO", name: "Husein Sastranegara Bandung", city: "Bandung",
            assignedLevel: .level5, defaultProfile: .ifrCommercial,
            runwaySummary: "RWY 11/29 (7381 ft, El 2436 ft)", primaryFreq: "TWR 118.100"
        ),
        AirportCurriculumItem(
            icao: "WAFB", iata: "TRT", name: "Toraja", city: "Tana Toraja, Sulawesi",
            assignedLevel: .level5, defaultProfile: .ifrCommercial,
            runwaySummary: "RWY 04/22 (6562 ft, El 2884 ft)", primaryFreq: "TWR 122.400"
        ),
        AirportCurriculumItem(
            icao: "WABP", iata: "TIM", name: "Mozes Kilangin Timika", city: "Timika, Papua Tengah",
            assignedLevel: .level5, defaultProfile: .ifrCommercial,
            runwaySummary: "RWY 12/30 (7841 ft, El 103 ft)", primaryFreq: "TWR 118.100"
        ),
        AirportCurriculumItem(
            icao: "WALR", iata: "TRK", name: "Juwata Tarakan", city: "Tarakan",
            assignedLevel: .level5, defaultProfile: .ifrCommercial,
            runwaySummary: "RWY 06/24 (7382 ft)", primaryFreq: "TWR 118.100"
        )
    ]

    public static func airport(for icao: String) -> AirportCurriculumItem? {
        let target = (icao == "WAWP") ? "WADY" : icao
        return allAirports.first(where: { $0.icao == target })
    }

    public static func level(for icao: String) -> CurriculumLevel {
        airport(for: icao)?.assignedLevel ?? .level1
    }

    public static func effectiveLevel(origin: String, destination: String?) -> CurriculumLevel {
        let lOrigin = level(for: origin)
        guard let destination = destination, !destination.isEmpty else {
            return lOrigin
        }
        let lDest = level(for: destination)
        return max(lOrigin, lDest)
    }

    public static func airports(for level: CurriculumLevel) -> [AirportCurriculumItem] {
        allAirports.filter { $0.assignedLevel == level }
    }
}

public enum MissionAct: Int, CaseIterable, Identifiable, Codable, Sendable {
    case act1Departure = 1
    case act2EnRoute = 2
    case act3Arrival = 3

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .act1Departure: "Act 1: Departure"
        case .act2EnRoute: "Act 2: En-Route / Circuit"
        case .act3Arrival: "Act 3: Arrival & Landing"
        }
    }

    public var subtitle: String {
        switch self {
        case .act1Departure: "Pre-Flight, Taxi, Line-Up, Take-Off"
        case .act2EnRoute: "Climb, Cruise, Spacing & Radar Vectors"
        case .act3Arrival: "Descent, Approach, Holding & Landing"
        }
    }

    public var phases: [Phase] {
        switch self {
        case .act1Departure: [.preDeparture, .departure]
        case .act2EnRoute: [.enRoute]
        case .act3Arrival: [.arrival, .approach, .landing]
        }
    }

    public static func act(for phase: Phase) -> MissionAct {
        switch phase {
        case .preDeparture, .departure: return .act1Departure
        case .enRoute: return .act2EnRoute
        case .arrival, .approach, .landing: return .act3Arrival
        }
    }
}

public enum CriticalViolationType: String, CaseIterable, Identifiable, Codable, Sendable {
    case wrongRunway = "Salah Nomor Runway"
    case missedHoldShort = "Gagal Baca Hold Short"
    case altitudeBust = "Salah Ketinggian / FL (Altitude Bust)"
    case wrongSquawk = "Salah Kode Transponder Squawk"

    public var id: String { rawValue }

    public var icaoDoc: String {
        switch self {
        case .wrongRunway: "ICAO Doc 4444 Sec 12.2.3 & Doc 9432 Sec 4.4"
        case .missedHoldShort: "ICAO Doc 4444 Sec 12.2.3 (Mandatory Readback: Hold Short)"
        case .altitudeBust: "ICAO Doc 9432 Sec 4.6 (Flight Level / Altitude Compliance)"
        case .wrongSquawk: "ICAO Doc 4444 Sec 12.2.3 (SSR Code Verification)"
        }
    }

    public var severityImpact: String {
        "INSTANT FAIL PADA BABAK BERJALAN"
    }
}

public enum NonCriticalPenalty: String, CaseIterable, Identifiable, Codable, Sendable {
    case phoneticHesitation = "Pelafalan Fonetik Kurang Baku (-10)"
    case longSilence = "Jeda Transmisi > 4 Detik (-10)"
    case wordOrderTransposition = "Struktur Pesan Terbalik (-5)"

    public var id: String { rawValue }

    public var penaltyPoints: Int {
        switch self {
        case .phoneticHesitation, .longSilence: 10
        case .wordOrderTransposition: 5
        }
    }

    public var icaoRef: String {
        "ICAO Doc 9835 Holistic Descriptors (Fluency & Structure)"
    }
}

public struct ActEvaluation: Identifiable, Equatable, Sendable {
    public var id: Int { act.rawValue }
    public let act: MissionAct
    public let score: Int
    public let isPassed: Bool
    public let criticalViolations: [CriticalViolationType]
    public let penalties: [NonCriticalPenalty]
    public let feedback: String

    public init(
        act: MissionAct,
        score: Int,
        isPassed: Bool,
        criticalViolations: [CriticalViolationType] = [],
        penalties: [NonCriticalPenalty] = [],
        feedback: String
    ) {
        self.act = act
        self.score = score
        self.isPassed = isPassed
        self.criticalViolations = criticalViolations
        self.penalties = penalties
        self.feedback = feedback
    }
}

public struct DiagnosticReport: Sendable, Equatable {
    public let overallScore: Int
    public let readbackAccuracyPercent: Int
    public let phraseologyScorePercent: Int
    public let disciplineScorePercent: Int
    public let isPassed: Bool
    public let summaryFeedback: String
    public let improvementAreas: [String]
    public let actEvaluations: [ActEvaluation]
    public let criticalViolations: [CriticalViolationType]
    public let nonCriticalPenalties: [NonCriticalPenalty]

    // MARK: - 4-Pillar Aviation Safety Risk Hierarchy (APP_FLOW_CIA.pdf & Hariri et al. 2026)
    public let numbersScore: Int            // Bobot 40% — Kejelasan & Ketepatan Angka (Risiko Fatal)
    public let phraseologyScore: Int        // Bobot 25% — Standar Frase Baku (Pencegah Ambiguitas)
    public let pttDisciplineScore: Int      // Bobot 20% — Disiplin Refleks Tombol PTT (Integritas Medium)
    public let fluencyScore: Int            // Bobot 15% — Kelancaran Bicara & Kecepatan WPM (Beban Mental)

    // Detailed Metrics (Rapor Ketertiban Radio)
    public let actualWpm: Int               // e.g. 110 WPM (Ideal: 100-120 WPM)
    public let fillerWordsCount: Int        // e.g. 0 kali
    public let hesitationCount: Int         // e.g. 0 kali
    public let pttLatencyMs: Int            // e.g. 315 ms (<800ms)
    public let numbersAccuracyPercentVal: Int // e.g. 98%

    public init(
        overallScore: Int,
        readbackAccuracyPercent: Int,
        phraseologyScorePercent: Int,
        disciplineScorePercent: Int,
        isPassed: Bool,
        summaryFeedback: String,
        improvementAreas: [String],
        actEvaluations: [ActEvaluation] = [],
        criticalViolations: [CriticalViolationType] = [],
        nonCriticalPenalties: [NonCriticalPenalty] = [],
        numbersScore: Int? = nil,
        phraseologyScore: Int? = nil,
        pttDisciplineScore: Int? = nil,
        fluencyScore: Int? = nil,
        actualWpm: Int = 110,
        fillerWordsCount: Int = 0,
        hesitationCount: Int = 0,
        pttLatencyMs: Int = 315,
        numbersAccuracyPercentVal: Int = 98
    ) {
        let nScore = numbersScore ?? readbackAccuracyPercent
        let pScore = phraseologyScore ?? phraseologyScorePercent
        let pttScore = pttDisciplineScore ?? disciplineScorePercent
        let fScore = fluencyScore ?? 92

        self.numbersScore = nScore
        self.phraseologyScore = pScore
        self.pttDisciplineScore = pttScore
        self.fluencyScore = fScore

        // Weighted Total: (Angka x 40%) + (Frase x 25%) + (PTT x 20%) + (Kelancaran x 15%)
        let weighted = Int(Double(nScore) * 0.40 + Double(pScore) * 0.25 + Double(pttScore) * 0.20 + Double(fScore) * 0.15)
        self.overallScore = (numbersScore != nil) ? weighted : overallScore

        self.readbackAccuracyPercent = readbackAccuracyPercent
        self.phraseologyScorePercent = phraseologyScorePercent
        self.disciplineScorePercent = disciplineScorePercent
        self.isPassed = isPassed
        self.summaryFeedback = summaryFeedback
        self.improvementAreas = improvementAreas
        self.actEvaluations = actEvaluations
        self.criticalViolations = criticalViolations
        self.nonCriticalPenalties = nonCriticalPenalties

        self.actualWpm = actualWpm
        self.fillerWordsCount = fillerWordsCount
        self.hesitationCount = hesitationCount
        self.pttLatencyMs = pttLatencyMs
        self.numbersAccuracyPercentVal = numbersAccuracyPercentVal
    }
}

public enum MissionArchetype: String, CaseIterable, Sendable, Identifiable {
    // IFR Archetypes
    case ifrRoutineDirect = "Routine Flight (Step Climb & Straight-in ILS)"
    case ifrWeatherAvoidance = "Severe Weather Diversion (CB Avoidance)"
    case ifrAirspaceCongestion = "Airspace Congestion & Radar Vectoring"
    case ifrHoldingPattern = "Holding Delay over VOR (Traffic Queue)"
    case ifrGoAroundReApproach = "Unstabilized Approach & Go-Around Loop"

    // VFR Archetypes
    case vfrTrainingAreaAirwork = "Training Area Alpha Airwork & Maneuvers"
    case vfrCircuitTouchAndGo = "Circuit Traffic Pattern (Touch & Go)"
    case vfrSimulatedEngineOut = "Simulated Engine Failure in Circuit"

    public var id: String { rawValue }
}

public struct FlightMissionContext: Equatable, Sendable {
    public let missionID: UUID
    public let profile: FlightProfile
    public let archetype: MissionArchetype
    public let aircraftType: String
    public let callsign: String
    public let originAirport: Airport
    public let destinationAirport: Airport
    public let depRunway: Runway
    public let arrRunway: Runway
    public let depWeather: AlignedWeather
    public let arrWeather: AlignedWeather
    public let depAtisId: String
    public let arrAtisId: String
    public let cruisingLevel: String
    public let squawkCode: String
    public let initialAlt: String
    public let sidProcedure: String
    public let starProcedure: String
    public let departureHeading: Int
    public let standOrigin: String
    public let standDestination: String
    public let taxiOutRoute: String
    public let taxiInRoute: String
    public let weatherDeviationDistance: String?
    public let weatherDeviationDirection: String?

    public var depAtisBroadcastText: String {
        let infoName = originAirport.name.components(separatedBy: " ").first ?? originAirport.name
        let windSpoken = SpokenFormFormatter.wind(direction: depWeather.windDirection, knots: depWeather.windSpeed)
        let rwySpoken = SpokenFormFormatter.runway(depRunway.designator)
        let qnhSpoken = SpokenFormFormatter.qnh(depWeather.qnh)
        return "\(infoName) Information \(depAtisId). Time zero one two zero UTC. Wind \(windSpoken). Runway \(rwySpoken) in use. QNH \(qnhSpoken) hPa. Advise information \(depAtisId) received on initial contact."
    }

    public var arrAtisBroadcastText: String {
        let infoName = destinationAirport.name.components(separatedBy: " ").first ?? destinationAirport.name
        let windSpoken = SpokenFormFormatter.wind(direction: arrWeather.windDirection, knots: arrWeather.windSpeed)
        let rwySpoken = SpokenFormFormatter.runway(arrRunway.designator)
        let qnhSpoken = SpokenFormFormatter.qnh(arrWeather.qnh)
        return "\(infoName) Information \(arrAtisId). Time zero one five zero UTC. Wind \(windSpoken). Runway \(rwySpoken) in use. Expect ILS approach runway \(rwySpoken). QNH \(qnhSpoken) hPa. Advise information \(arrAtisId) received on initial contact with Approach."
    }

    public var depDATISText: String {
        let icao = originAirport.icao
        let windDir = String(format: "%03d", depWeather.windDirection)
        let windSpd = String(format: "%02d", depWeather.windSpeed)
        return """
        \(icao) DEP ATIS \(depAtisId) 0120Z
        \(windDir)\(windSpd)KT CAVOK 30/25 Q\(depWeather.qnh)
        DEP RWY \(depRunway.designator) IN USE
        INITIAL CLIMB \(initialAlt.uppercased())
        SQUAWK \(squawkCode.uppercased())
        """
    }

    public var arrDATISText: String {
        let icao = destinationAirport.icao
        let windDir = String(format: "%03d", arrWeather.windDirection)
        let windSpd = String(format: "%02d", arrWeather.windSpeed)
        return """
        \(icao) ARR ATIS \(arrAtisId) 0150Z
        \(windDir)\(windSpd)KT CAVOK 29/24 Q\(arrWeather.qnh)
        ARR RWY \(arrRunway.designator) IN USE
        EXPECT ILS DME APCH RWY \(arrRunway.designator)
        """
    }
}

public struct PhaseScript: Identifiable, Equatable, Sendable {
    public var id: Phase { phase }
    public let phase: Phase
    public let title: String
    public let educationalGoal: String
    public let exchanges: [FilledExchange]

    public var turnCount: Int { exchanges.count }
    public var estimatedDurationMinutes: Double { Double(exchanges.count) * 0.45 }
}

public struct FlightMissionScript: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let seed: Int
    public let level: CurriculumLevel?
    public let role: UserRole
    public let mode: SimulationMode
    public let profile: FlightProfile
    public let archetype: MissionArchetype
    public let originAirport: Airport
    public let destinationAirport: Airport
    public let callsign: String
    public let missionContext: FlightMissionContext
    public let phaseScripts: [PhaseScript]
    public let diagnosticReport: DiagnosticReport?
    public let contingencies: [InjectedContingency]

    public var contingency: InjectedContingency? {
        contingencies.first
    }

    public init(
        id: UUID = UUID(),
        seed: Int,
        level: CurriculumLevel? = nil,
        role: UserRole = .pilot,
        mode: SimulationMode = .practice,
        profile: FlightProfile,
        archetype: MissionArchetype,
        originAirport: Airport,
        destinationAirport: Airport,
        callsign: String,
        missionContext: FlightMissionContext,
        phaseScripts: [PhaseScript],
        diagnosticReport: DiagnosticReport? = nil,
        contingency: InjectedContingency? = nil,
        contingencies: [InjectedContingency] = []
    ) {
        self.id = id
        self.seed = seed
        self.level = level
        self.role = role
        self.mode = mode
        self.profile = profile
        self.archetype = archetype
        self.originAirport = originAirport
        self.destinationAirport = destinationAirport
        self.callsign = callsign
        self.missionContext = missionContext
        self.phaseScripts = phaseScripts
        self.diagnosticReport = diagnosticReport
        if !contingencies.isEmpty {
            self.contingencies = contingencies
        } else if let c = contingency {
            self.contingencies = [c]
        } else {
            self.contingencies = []
        }
    }

    public var allExchanges: [FilledExchange] {
        phaseScripts.flatMap { $0.exchanges }
    }

    public var totalExchanges: Int {
        allExchanges.count
    }

    public var totalEstimatedDurationMinutes: Double {
        phaseScripts.reduce(0.0) { $0 + $1.estimatedDurationMinutes }
    }

    public var allCriticalSlots: [CriticalSlot] {
        allExchanges.filter { $0.isUserTurn }.flatMap { $0.criticalSlots }
    }

    public func act(for phase: Phase) -> MissionAct {
        MissionAct.act(for: phase)
    }

    public func phaseScripts(for act: MissionAct) -> [PhaseScript] {
        let actPhases = Set(act.phases)
        return phaseScripts.filter { actPhases.contains($0.phase) }
    }

    public func exchanges(for act: MissionAct) -> [FilledExchange] {
        phaseScripts(for: act).flatMap { $0.exchanges }
    }

    /// Exchanges that use constrained plain English (Doc 9835 §4.3.1 Layer 2)
    public var plainEnglishExchanges: [FilledExchange] {
        allExchanges.filter { $0.languageLayer == .constrainedPlainEnglish }
    }

    public func exportAsPlainText() -> String {
        var output = """
        ================================================================================
        HERMES RADIOTELEPHONY SIMULATION FLIGHT SCRIPT
        Level: \(level?.title ?? "Custom Route")
        Mode: \(mode.rawValue) | Role: \(role.rawValue) | Seed: \(seed)
        Total Turns: \(totalExchanges) | Estimated Duration: \(String(format: "%.1f", totalEstimatedDurationMinutes)) mins
        ================================================================================

        --------------------------------------------------------------------------------
        📋 1. OPERATIONAL FLIGHT PLAN (OFP / ICAO FLIGHT PLAN)
        --------------------------------------------------------------------------------
        Callsign           : \(callsign)
        Aircraft Type      : \(missionContext.aircraftType)
        Departure (Origin) : \(missionContext.originAirport.icao) (\(missionContext.originAirport.name))
        Parking Stand      : \(missionContext.standOrigin)
        Destination        : \(missionContext.destinationAirport.icao) (\(missionContext.destinationAirport.name))
        Planned Cruising   : \(missionContext.cruisingLevel)
        Initial Altitude   : \(missionContext.initialAlt)
        Assigned Routing   : SID \(missionContext.sidProcedure) | STAR \(missionContext.starProcedure)
        Assigned Squawk    : \(missionContext.squawkCode)
        Planned Dep Runway : Runway \(missionContext.depRunway.designator) (Assigned by Departure ATIS)
        Expected Arr Runway: Runway \(missionContext.arrRunway.designator) (Assigned by Arrival ATIS)
        Destination Stand  : \(missionContext.standDestination)

        --------------------------------------------------------------------------------
        📻 2. DEPARTURE ATIS (AUTOMATIC TERMINAL INFORMATION SERVICE)
        --------------------------------------------------------------------------------
        Station            : \(missionContext.originAirport.name) (\(missionContext.originAirport.icao))
        ATIS Identification: Information \(missionContext.depAtisId) (Issued 0120 UTC)
        Runway in Use      : Runway \(missionContext.depRunway.designator)
        Surface Wind       : \(String(format: "%03d", missionContext.depWeather.windDirection))° / \(String(format: "%02d", missionContext.depWeather.windSpeed)) knots
        Visibility         : Greater than 10 km (CAVOK)
        Altimeter (QNH)    : \(missionContext.depWeather.qnh) hPa
        Temperature / Dew  : 30°C / 25°C

        [VOICE ATIS BROADCAST TRANSCRIPT (VHF COMM-2)]:
        "\(missionContext.depAtisBroadcastText)"
        (Prosedur Resmi: Pilot memantau ATIS secara pasif di radio COMM-2 sebelum transmisi awal; pilot menyatakan kode pengenal '\(missionContext.depAtisId)' pada initial call ke ATC).

        [DIGITAL D-ATIS (ACARS / COCKPIT MCDU READOUT)]:
        \(missionContext.depDATISText)

        --------------------------------------------------------------------------------
        📻 3. ARRIVAL ATIS (DESTINATION ADVISORY - EN-ROUTE / DESCENT PREPARATION)
        --------------------------------------------------------------------------------
        Station            : \(missionContext.destinationAirport.name) (\(missionContext.destinationAirport.icao))
        ATIS Identification: Information \(missionContext.arrAtisId) (Issued 0150 UTC)
        Expected Runway    : Runway \(missionContext.arrRunway.designator) in use
        Approach Procedure : ILS DME Runway \(missionContext.arrRunway.designator)
        Surface Wind       : \(String(format: "%03d", missionContext.arrWeather.windDirection))° / \(String(format: "%02d", missionContext.arrWeather.windSpeed)) knots
        Visibility         : Greater than 10 km (CAVOK)
        Altimeter (QNH)    : \(missionContext.arrWeather.qnh) hPa

        [VOICE ATIS BROADCAST TRANSCRIPT (VHF COMM-2)]:
        "\(missionContext.arrAtisBroadcastText)"
        (Prosedur Resmi: Pilot menyatakan kode pengenal '\(missionContext.arrAtisId)' pada initial contact ke Approach saat descent).

        [DIGITAL D-ATIS (ACARS / COCKPIT MCDU READOUT)]:
        \(missionContext.arrDATISText)
        ================================================================================
        """

        if !contingencies.isEmpty {
            for (idx, cont) in contingencies.enumerated() {
                let numStr = contingencies.count > 1 ? " #\(idx + 1)" : ""
                output += """

                ⚠️ INJECTED CONTINGENCY EVENT\(numStr): [\(cont.severity.rawValue)] \(cont.title)
                Phase Trigger: \(cont.triggerPhase.rawValue)
                Situation: \(cont.summary)
                Downstream Impact: \(cont.downstreamEffect)
                ================================================================================
                """
            }
        }

        output += "\n"

        for phaseScript in phaseScripts {
            output += """

            ================================================================================
            \(phaseScript.title.uppercased())
            Goal: \(phaseScript.educationalGoal)
            Turns: \(phaseScript.turnCount) (~ \(String(format: "%.1f", phaseScript.estimatedDurationMinutes)) minutes)
            --------------------------------------------------------------------------------

            """

            for ex in phaseScript.exchanges {
                var speakerLabel = ex.isUserTurn ? "\(ex.speaker) [USER TURN]" : ex.speaker
                if ex.severity != .normal, let tag = ex.eventTag {
                    speakerLabel += " [\(ex.severity.rawValue): \(tag)]"
                }
                output += "Turn \(ex.turn) | \(speakerLabel):\n"
                if let obj = ex.objective, ex.isUserTurn {
                    output += "  Objective: \(obj)\n"
                }
                output += "\"\(ex.text)\"\n"
                if !ex.criticalSlots.isEmpty {
                    let items = ex.criticalSlots.map { "\($0.slot): '\($0.expectedValue)'" }.joined(separator: ", ")
                    output += "  >> Mandatory Readback: [\(items)]\n"
                }
                output += "\n"
            }
        }

        if let diag = diagnosticReport {
            output += """

            ================================================================================
            DIAGNOSTIC & PERFORMANCE EVALUATION (POST-SESSION REPORT)
            Status: \(diag.isPassed ? "PASSED (SCORE >= 80%)" : "NEEDS IMPROVEMENT (SCORE < 80%)")
            Overall Score: \(diag.overallScore)%
            - Safety-Critical Readback Accuracy: \(diag.readbackAccuracyPercent)%
            - Standard ICAO Phraseology Compliance: \(diag.phraseologyScorePercent)%
            - Transmission Discipline & Latency: \(diag.disciplineScorePercent)%

            Summary:
            \(diag.summaryFeedback)

            Key Improvement Areas:
            """
            for area in diag.improvementAreas {
                output += "\n• \(area)"
            }
            output += "\n"
        }

        output += """

        ================================================================================
        END OF SIMULATION SCRIPT — HERMES TECHNICAL SECOND BRAIN
        ================================================================================
        """
        return output
    }
}

// MARK: - ATC Session Models (Multi-Traffic, Single Aerodrome)

/// Type of aircraft traffic in an ATC session.
/// ATC controls one aerodrome but handles multiple simultaneous aircraft.
public enum ATCTrafficType: String, Codable, Sendable, CaseIterable, Identifiable {
    case fullDeparture = "Departure"                       // Startup → Taxi → Line-Up → Take-Off → Handoff
    case touchAndGo = "Touch & Go"                         // VFR circuit student: multiple passes & spacing
    case enRouteTransit = "En-Route Transit"               // Overflying aircraft, position report only
    case fullArrival = "Full Arrival"                      // Descent → Approach → Landing → Taxi-in
    case emergencyInbound = "Emergency MAYDAY"             // MAYDAY engine failure, priority landing, ARFF escort
    case diversionArrival = "Diversion"                    // Weather/fuel diversion alternate arrival

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .fullDeparture: "airplane.departure"
        case .touchAndGo: "arrow.2.circlepath"
        case .enRouteTransit: "arrow.right.circle"
        case .fullArrival: "airplane.arrival"
        case .emergencyInbound: "exclamationmark.triangle.fill"
        case .diversionArrival: "arrow.triangle.turn.up.right.circle"
        }
    }

    public var color: String {
        switch self {
        case .fullDeparture: "blue"
        case .touchAndGo: "teal"
        case .enRouteTransit: "gray"
        case .fullArrival: "green"
        case .emergencyInbound: "red"
        case .diversionArrival: "orange"
        }
    }
}

/// A single aircraft handled by the ATC trainee within a session.
public struct ATCTrafficEntry: Identifiable, Equatable, Sendable {
    public var id: String { trafficID }
    public let trafficID: String       // "T1", "T2", "T3", …
    public let callsign: String
    public let aircraftType: String
    public let trafficType: ATCTrafficType
    /// All exchanges for this traffic (ATC speaks, aircraft responds)
    public let exchanges: [FilledExchange]
    /// Subset: transmissions where plain English is used (Doc 9835 §4.3.1)
    public var plainEnglishExchanges: [FilledExchange] {
        exchanges.filter { $0.languageLayer == .constrainedPlainEnglish }
    }
    /// The MissionAct this traffic primarily belongs to (for 3-Act grouping)
    public let act: MissionAct
    /// True if this traffic injects an abnormal/emergency scenario
    public let hasContingency: Bool
    public let contingencySummary: String?

    public init(
        trafficID: String,
        callsign: String,
        aircraftType: String,
        trafficType: ATCTrafficType,
        exchanges: [FilledExchange],
        act: MissionAct,
        hasContingency: Bool = false,
        contingencySummary: String? = nil
    ) {
        self.trafficID = trafficID
        self.callsign = callsign
        self.aircraftType = aircraftType
        self.trafficType = trafficType
        self.exchanges = exchanges
        self.act = act
        self.hasContingency = hasContingency
        self.contingencySummary = contingencySummary
    }
}

/// An ATC training session at one aerodrome, handling multiple simultaneous aircraft.
/// Replaces the pilot-centric FlightMissionScript for mode ATC.
public struct ATCSessionScript: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let seed: Int
    public let aerodrome: AirportCurriculumItem
    public let level: CurriculumLevel
    public let trafficEntries: [ATCTrafficEntry]
    public let diagnosticReport: DiagnosticReport?

    public init(
        id: UUID = UUID(),
        seed: Int,
        aerodrome: AirportCurriculumItem,
        level: CurriculumLevel,
        trafficEntries: [ATCTrafficEntry],
        diagnosticReport: DiagnosticReport? = nil
    ) {
        self.id = id
        self.seed = seed
        self.aerodrome = aerodrome
        self.level = level
        self.trafficEntries = trafficEntries
        self.diagnosticReport = diagnosticReport
    }

    // MARK: - Derived Properties

    public var allExchanges: [FilledExchange] {
        trafficEntries.flatMap { $0.exchanges }
    }

    public var totalExchanges: Int { allExchanges.count }

    public var plainEnglishExchanges: [FilledExchange] {
        allExchanges.filter { $0.languageLayer == .constrainedPlainEnglish }
    }

    /// Traffic entries grouped by 3-Act checkpoint
    public func trafficEntries(for act: MissionAct) -> [ATCTrafficEntry] {
        trafficEntries.filter { $0.act == act }
    }

    /// All exchanges for a specific act (across all traffic in that act)
    public func exchanges(for act: MissionAct) -> [FilledExchange] {
        trafficEntries(for: act).flatMap { $0.exchanges }
    }

    /// Estimated session duration in minutes (0.45 min per exchange, like pilot model)
    public var estimatedDurationMinutes: Double {
        Double(totalExchanges) * 0.45
    }

    // MARK: - ATC Act Labels (different from Pilot 3-Act)
    public static func atcActTitle(for act: MissionAct) -> String {
        switch act {
        case .act1Departure: "Act 1: Departures & Circuits"
        case .act2EnRoute: "Act 2: Transit & Sequencing"
        case .act3Arrival: "Act 3: Arrivals & Emergencies"
        }
    }

    public static func atcActSubtitle(for act: MissionAct) -> String {
        switch act {
        case .act1Departure: "Handle departing & circuit aircraft from startup to handoff"
        case .act2EnRoute: "Coordinate overflying traffic, sequencing & conditional separation"
        case .act3Arrival: "Guide arriving aircraft, manage emergency priority & diversion"
        }
    }

    public func exportAsPlainText() -> String {
        var output = """
        ================================================================================
        HERMES ATC RADIOTELEPHONY SESSION SCRIPT
        Aerodrome: \(aerodrome.icao) (\(aerodrome.name))
        Level: Level \(level.rawValue) — \(level.levelCategory)
        Runways: \(aerodrome.runwaySummary) | Frequency: \(aerodrome.primaryFreq)
        Seed: \(seed) | Total Traffic: \(trafficEntries.count) aircraft
        Total Exchanges: \(totalExchanges) | Estimated Duration: \(String(format: "%.0f", estimatedDurationMinutes)) mins
        ================================================================================
        """
        for traffic in trafficEntries {
            output += """

            --------------------------------------------------------------------------------
            TRAFFIC [\(traffic.trafficID)]: \(traffic.callsign) (\(traffic.aircraftType)) — \(traffic.trafficType.rawValue)
            Babak: \(traffic.act.title)
            --------------------------------------------------------------------------------
            """
            for ex in traffic.exchanges {
                let speakerLabel = ex.isUserTurn ? "\(ex.speaker) [USER TURN]" : ex.speaker
                output += "\nTurn \(ex.turn) | \(speakerLabel):\n"
                if let obj = ex.objective {
                    output += "  🎯 Objective: \(obj)\n"
                }
                output += "\"\(ex.text)\"\n"
            }
        }
        if let diag = diagnosticReport {
            output += """

            ================================================================================
            POST-SESSION DIAGNOSTIC EVALUATION (ICAO DOC 4444)
            Overall Score: \(diag.overallScore)% (Passed: \(diag.isPassed))
            - Readback Accuracy: \(diag.readbackAccuracyPercent)%
            - Phraseology Compliance: \(diag.phraseologyScorePercent)%
            - Transmission Discipline: \(diag.disciplineScorePercent)%
            ================================================================================
            """
        }
        return output
    }
}
