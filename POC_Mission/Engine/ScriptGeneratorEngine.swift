import Foundation

public enum GeneratorError: Error, LocalizedError {
    case airportNotFound(String)
    case templateNotFound(String)
    case unresolvedSlot(String)

    public var errorDescription: String? {
        switch self {
        case let .airportNotFound(icao): "Airport not found: \(icao)"
        case let .templateNotFound(id): "Template not found: \(id)"
        case let .unresolvedSlot(slot): "Slot could not be resolved: \(slot)"
        }
    }
}

public final class ScriptGeneratorEngine {
    private let airportRepository: AirportRepository
    private let templateRepository: TemplateRepository

    public init(
        airportRepository: AirportRepository = AirportRepository(),
        templateRepository: TemplateRepository = TemplateRepository()
    ) {
        self.airportRepository = airportRepository
        self.templateRepository = templateRepository
    }

    // MARK: - Legacy Single Phase Generator
    public func generate(request: ScriptRequest) throws -> GeneratedScript {
        let airport = try airportRepository.airport(icao: request.airportID)
        let resolvedCallsign = request.callsign ?? CallsignGenerator.generate(profile: request.profile, seed: request.seed)
        let context = resolveContext(airport: airport, request: request, callsign: resolvedCallsign)

        let templates = try templateRepository.templates(for: request.phase)
        let chain = buildTemplateChain(
            availableTemplates: templates,
            request: request,
            context: context
        )

        var allFilledExchanges: [FilledExchange] = []
        var allCriticalSlots: [CriticalSlot] = []
        var globalTurn = 1

        for template in chain {
            for exchange in template.exchanges {
                let filledText = fillTemplateSlots(exchange.template, context: context)
                let resolvedCritical = resolveCriticalSlots(exchange.criticalReadback, context: context)

                let filledExchange = FilledExchange(
                    exchangeID: "\(template.id)-t\(exchange.turn)",
                    templateID: template.id,
                    turn: globalTurn,
                    speaker: exchange.speaker,
                    isUserTurn: exchange.isUserTurn,
                    text: filledText,
                    criticalSlots: resolvedCritical
                )

                allFilledExchanges.append(filledExchange)
                if exchange.isUserTurn {
                    allCriticalSlots.append(contentsOf: resolvedCritical)
                }
                globalTurn += 1
            }
        }

        return GeneratedScript(
            id: UUID(),
            seed: request.seed,
            phase: request.phase,
            airport: request.airportID,
            callsign: resolvedCallsign,
            context: context,
            exchanges: allFilledExchanges,
            criticalSlots: allCriticalSlots
        )
    }

    // MARK: - Full Flight Mission Generator (End-to-End Across 6 Phases)
    public func generateFullMission(
        profile: FlightProfile? = nil,
        originICAO: String? = nil,
        destinationICAO: String? = nil,
        seed: Int? = nil,
        includeAbnormal: Bool = false,
        includeEmergency: Bool = false
    ) throws -> FlightMissionScript {
        let chosenSeed = seed ?? Int.random(in: 1000...9999)
        let chosenProfile: FlightProfile
        let originID: String
        let destinationID: String

        // Profile & Route Resolution
        if let explicitProfile = profile {
            chosenProfile = explicitProfile
            if explicitProfile == .vfrLocal {
                originID = originICAO ?? "WADY"
                destinationID = destinationICAO ?? "WADY"
            } else {
                if abs(chosenSeed) % 2 == 0 {
                    originID = originICAO ?? "WIII"
                    destinationID = destinationICAO ?? "WADD"
                } else {
                    originID = originICAO ?? "WADD"
                    destinationID = destinationICAO ?? "WIII"
                }
            }
        } else {
            if chosenSeed % 3 == 0 {
                chosenProfile = .vfrLocal
                originID = originICAO ?? "WADY"
                destinationID = destinationICAO ?? "WADY"
            } else {
                chosenProfile = .ifrCommercial
                if abs(chosenSeed) % 2 == 0 {
                    originID = originICAO ?? "WIII"
                    destinationID = destinationICAO ?? "WADD"
                } else {
                    originID = originICAO ?? "WADD"
                    destinationID = destinationICAO ?? "WIII"
                }
            }
        }

        let originAirport = try airportRepository.airport(icao: originID)
        let destinationAirport = try airportRepository.airport(icao: destinationID)

        let callsign = CallsignGenerator.generate(profile: chosenProfile, seed: chosenSeed)
        let aircraftType = AircraftGenerator.generate(profile: chosenProfile, seed: chosenSeed)

        // Dynamic Wind and Runways for Origin
        let depRwyHeadings = Dictionary(uniqueKeysWithValues: originAirport.runways.map { ($0.designator, $0.headingDegT) })
        let depRwyPair = originAirport.runways.first?.pair ?? [originAirport.runways.first?.designator ?? "08"]
        let depWeather = WeatherEngine.alignedWeather(
            runway: originAirport.runways.first?.designator ?? "08",
            heading: originAirport.runways.first?.headingDegT ?? 80,
            seed: chosenSeed
        )
        let depRwyDesignator = WeatherEngine.bestRunway(
            pair: depRwyPair,
            headings: depRwyHeadings,
            windDirection: Double(depWeather.windDirection),
            windSpeed: Double(depWeather.windSpeed)
        ).runway
        let depRunway = originAirport.runways.first(where: { $0.designator == depRwyDesignator }) ?? originAirport.runways.first!

        // Dynamic Wind and Runways for Destination
        let arrRwyHeadings = Dictionary(uniqueKeysWithValues: destinationAirport.runways.map { ($0.designator, $0.headingDegT) })
        let arrRwyPair = destinationAirport.runways.first?.pair ?? [destinationAirport.runways.first?.designator ?? "09"]
        let arrWeather = WeatherEngine.alignedWeather(
            runway: destinationAirport.runways.first?.designator ?? "09",
            heading: destinationAirport.runways.first?.headingDegT ?? 90,
            seed: chosenSeed + 101
        )
        let arrRwyDesignator = WeatherEngine.bestRunway(
            pair: arrRwyPair,
            headings: arrRwyHeadings,
            windDirection: Double(arrWeather.windDirection),
            windSpeed: Double(arrWeather.windSpeed)
        ).runway
        let arrRunway = destinationAirport.runways.first(where: { $0.designator == arrRwyDesignator }) ?? destinationAirport.runways.first!

        let depAtisId = ATISGenerator.letter(seed: chosenSeed)
        let arrAtisId = ATISGenerator.letter(seed: chosenSeed + 5)

        let depHeading = Int(depRunway.headingDegT)

        // Cruise Altitude using Semicircular Rule & SIDs/STARs
        let flightHeadingTrack = (originAirport.icao == "WIII" && destinationAirport.icao == "WADD") ? 95 : 280
        let cruisingLevel: String
        let initialAlt: String
        if chosenProfile == .vfrLocal {
            let vfrAlts = ["two thousand five hundred feet", "three thousand feet", "three thousand five hundred feet"]
            cruisingLevel = vfrAlts[abs(chosenSeed) % vfrAlts.count]
            initialAlt = "altitude two thousand five hundred feet"
        } else {
            cruisingLevel = FlightLevelGenerator.cruisingLevel(headingTrack: flightHeadingTrack, seed: chosenSeed)
            initialAlt = FlightLevelGenerator.initialAltitude(seed: chosenSeed)
        }

        let sidName: String
        let starName: String
        if originAirport.icao == "WIII" {
            sidName = (abs(chosenSeed) % 2 == 0) ? "DOLTA One Alfa" : "BUNTA One Bravo"
            starName = "ELANG One Alfa"
        } else if originAirport.icao == "WADD" {
            sidName = "BLI Two Charlie"
            starName = "DOLTA One Bravo"
        } else {
            sidName = "Area Alpha departure"
            starName = "Overhead arrival"
        }

        let standOrigin = StandGenerator.originStand(icao: originAirport.icao, seed: chosenSeed)
        let standDest = StandGenerator.destinationStand(icao: destinationAirport.icao, seed: chosenSeed)
        let taxiOutRoute = Self.composeTaxiRoute(from: originAirport.taxiways, seed: chosenSeed)
        let taxiInRoute = Self.composeTaxiRoute(from: destinationAirport.taxiways, seed: chosenSeed + 7)
        let depHoldingPoint = Self.pickHoldingPoint(from: depRunway.holdingPoints, defaultPoint: "A1", seed: chosenSeed)
        let arrExitTaxiway = destinationAirport.taxiways.isEmpty ? "Echo" : destinationAirport.taxiways[abs(chosenSeed + 3) % destinationAirport.taxiways.count].spoken
        let squawkCode: String = chosenProfile == .vfrLocal ? "one two zero zero" : SpokenFormFormatter.digitWords(String(4200 + (abs(chosenSeed) % 500)))

        // Mission Archetype Resolution
        let chosenArchetype: MissionArchetype
        if chosenProfile == .vfrLocal {
            let vfrArchetypes: [MissionArchetype] = [.vfrTrainingAreaAirwork, .vfrCircuitTouchAndGo]
            chosenArchetype = vfrArchetypes[abs(chosenSeed) % vfrArchetypes.count]
        } else {
            if includeAbnormal {
                let abnList: [MissionArchetype] = [.ifrGoAroundReApproach, .ifrHoldingPattern, .ifrWeatherAvoidance]
                chosenArchetype = abnList[abs(chosenSeed) % abnList.count]
            } else {
                let normalList: [MissionArchetype] = [.ifrRoutineDirect, .ifrWeatherAvoidance, .ifrAirspaceCongestion]
                chosenArchetype = normalList[abs(chosenSeed) % normalList.count]
            }
        }

        let hasWeatherDeviation = (chosenArchetype == .ifrWeatherAvoidance)
        let deviationDistance = hasWeatherDeviation ? (abs(chosenSeed) % 2 == 0 ? "one five" : "two zero") : nil
        let deviationDirection = hasWeatherDeviation ? (abs(chosenSeed) % 2 == 0 ? "left" : "right") : nil

        let missionContext = FlightMissionContext(
            missionID: UUID(),
            profile: chosenProfile,
            archetype: chosenArchetype,
            aircraftType: aircraftType,
            callsign: callsign,
            originAirport: originAirport,
            destinationAirport: destinationAirport,
            depRunway: depRunway,
            arrRunway: arrRunway,
            depWeather: depWeather,
            arrWeather: arrWeather,
            depAtisId: depAtisId,
            arrAtisId: arrAtisId,
            cruisingLevel: cruisingLevel,
            squawkCode: squawkCode,
            initialAlt: initialAlt,
            sidProcedure: sidName,
            starProcedure: starName,
            departureHeading: depHeading,
            standOrigin: standOrigin,
            standDestination: standDest,
            taxiOutRoute: taxiOutRoute,
            taxiInRoute: taxiInRoute,
            weatherDeviationDistance: deviationDistance,
            weatherDeviationDirection: deviationDirection
        )

        var phaseScripts: [PhaseScript] = []
        var globalTurn = 1

        for phase in Phase.allCases {
            let templates = try templateRepository.templates(for: phase)
            let templateMap = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })
            var chain: [ScenarioTemplate] = []

            switch chosenArchetype {
            case .ifrRoutineDirect:
                switch phase {
                case .preDeparture: chain = ["PD-01", "PD-02", "PD-04", "PD-06"].compactMap { templateMap[$0] }
                case .departure: chain = ["DP-01", "DP-03", "DP-05", "DP-06"].compactMap { templateMap[$0] }
                case .enRoute: chain = ["ER-01", "ER-02", "ER-04", "ER-05"].compactMap { templateMap[$0] }
                case .arrival: chain = ["AR-01", "AR-02", "AR-04"].compactMap { templateMap[$0] }
                case .approach: chain = ["AP-01", "AP-02", "AP-06"].compactMap { templateMap[$0] }
                case .landing: chain = ["LD-01", "LD-02", "LD-03", "LD-04"].compactMap { templateMap[$0] }
                }

            case .ifrWeatherAvoidance:
                switch phase {
                case .preDeparture: chain = ["PD-01", "PD-02", "PD-04", "PD-06"].compactMap { templateMap[$0] }
                case .departure: chain = ["DP-01", "DP-04", "DP-06"].compactMap { templateMap[$0] }
                case .enRoute: chain = ["ER-01", "ER-03", "ER-02", "ER-05"].compactMap { templateMap[$0] }
                case .arrival: chain = ["AR-01", "AR-02", "AR-04"].compactMap { templateMap[$0] }
                case .approach: chain = ["AP-01", "AP-02", "AP-06"].compactMap { templateMap[$0] }
                case .landing: chain = ["LD-01", "LD-02", "LD-03", "LD-04"].compactMap { templateMap[$0] }
                }

            case .ifrAirspaceCongestion:
                switch phase {
                case .preDeparture: chain = ["PD-01", "PD-02", "PD-04", "PD-06"].compactMap { templateMap[$0] }
                case .departure: chain = ["DP-01", "DP-03", "DP-04", "DP-06"].compactMap { templateMap[$0] }
                case .enRoute: chain = ["ER-01", "ER-02", "ER-05"].compactMap { templateMap[$0] }
                case .arrival: chain = ["AR-01", "AR-02", "AR-04"].compactMap { templateMap[$0] }
                case .approach: chain = ["AP-01", "AP-08", "AP-06"].compactMap { templateMap[$0] }
                case .landing: chain = ["LD-01", "LD-02", "LD-03", "LD-04"].compactMap { templateMap[$0] }
                }

            case .ifrHoldingPattern:
                switch phase {
                case .preDeparture: chain = ["PD-01", "PD-02", "PD-04", "PD-06"].compactMap { templateMap[$0] }
                case .departure: chain = ["DP-01", "DP-03", "DP-05", "DP-06"].compactMap { templateMap[$0] }
                case .enRoute: chain = ["ER-01", "ER-02", "ER-04", "ER-05"].compactMap { templateMap[$0] }
                case .arrival: chain = ["AR-01", "AR-05", "AR-02", "AR-04"].compactMap { templateMap[$0] }
                case .approach: chain = ["AP-01", "AP-02", "AP-06"].compactMap { templateMap[$0] }
                case .landing: chain = ["LD-01", "LD-02", "LD-03", "LD-04"].compactMap { templateMap[$0] }
                }

            case .ifrGoAroundReApproach:
                switch phase {
                case .preDeparture: chain = ["PD-01", "PD-02", "PD-04", "PD-06"].compactMap { templateMap[$0] }
                case .departure: chain = ["DP-01", "DP-04", "DP-06"].compactMap { templateMap[$0] }
                case .enRoute: chain = ["ER-01", "ER-02", "ER-05"].compactMap { templateMap[$0] }
                case .arrival: chain = ["AR-01", "AR-02", "AR-04"].compactMap { templateMap[$0] }
                case .approach: chain = ["AP-01", "AP-02", "AP-07", "AP-08", "AP-06"].compactMap { templateMap[$0] }
                case .landing: chain = ["LD-01", "LD-02", "LD-03", "LD-04"].compactMap { templateMap[$0] }
                }

            case .vfrTrainingAreaAirwork:
                switch phase {
                case .preDeparture: chain = ["PD-01", "PD-03", "PD-06"].compactMap { templateMap[$0] }
                case .departure: chain = ["DP-01", "DP-05", "DP-06"].compactMap { templateMap[$0] }
                case .enRoute: chain = ["ER-01", "ER-02"].compactMap { templateMap[$0] }
                case .arrival: chain = ["AR-01", "AR-03"].compactMap { templateMap[$0] }
                case .approach: chain = ["AP-03", "AP-06"].compactMap { templateMap[$0] }
                case .landing: chain = ["LD-01", "LD-02", "LD-03", "LD-04"].compactMap { templateMap[$0] }
                }

            case .vfrCircuitTouchAndGo:
                switch phase {
                case .preDeparture: chain = ["PD-01", "PD-03", "PD-06"].compactMap { templateMap[$0] }
                case .departure: chain = ["DP-01", "DP-03", "DP-04"].compactMap { templateMap[$0] }
                case .enRoute: chain = ["ER-01"].compactMap { templateMap[$0] }
                case .arrival: chain = ["AR-01", "AR-03"].compactMap { templateMap[$0] }
                case .approach: chain = ["AP-03", "AP-06"].compactMap { templateMap[$0] }
                case .landing: chain = ["LD-01", "LD-02", "LD-03", "LD-04"].compactMap { templateMap[$0] }
                }

            case .vfrSimulatedEngineOut:
                switch phase {
                case .preDeparture: chain = ["PD-01", "PD-03", "PD-06"].compactMap { templateMap[$0] }
                case .departure: chain = ["DP-01", "DP-04", "DP-06"].compactMap { templateMap[$0] }
                case .enRoute: chain = ["ER-01"].compactMap { templateMap[$0] }
                case .arrival: chain = ["AR-01", "AR-03"].compactMap { templateMap[$0] }
                case .approach: chain = ["AP-03", "AP-07", "AP-06"].compactMap { templateMap[$0] }
                case .landing: chain = ["LD-01", "LD-02", "LD-03", "LD-04"].compactMap { templateMap[$0] }
                }
            }

            let slotContext = buildMissionSlotContext(
                missionContext: missionContext,
                phase: phase,
                depHoldingPoint: depHoldingPoint,
                arrExitTaxiway: arrExitTaxiway
            )

            var phaseExchanges: [FilledExchange] = []
            for template in chain {
                for exchange in template.exchanges {
                    let filledText = fillTemplateSlots(exchange.template, context: slotContext)
                    let resolvedCritical = resolveCriticalSlots(exchange.criticalReadback, context: slotContext)

                    let filledExchange = FilledExchange(
                        exchangeID: "\(template.id)-t\(exchange.turn)-g\(globalTurn)",
                        templateID: template.id,
                        turn: globalTurn,
                        speaker: exchange.speaker,
                        isUserTurn: exchange.isUserTurn,
                        text: filledText,
                        criticalSlots: resolvedCritical
                    )
                    phaseExchanges.append(filledExchange)
                    globalTurn += 1
                }
            }

            let title: String
            let goal: String
            switch phase {
            case .preDeparture:
                title = "Phase 1: Pre-Departure"
                goal = "Penerimaan paket ATIS, CRAFT IFR clearance / engine start, koordinasi pushback, dan izin taxi menuju holding point."
            case .departure:
                title = "Phase 2: Departure"
                goal = "Transfer frekuensi Tower, line-up and wait, izin lepas landas (take-off clearance), dan transisi airborne handoff."
            case .enRoute:
                title = "Phase 3: En-Route"
                goal = "Radar contact, position report waypoint, dynamic weather deviation (CB avoidance), dan transfer antar sektor ACC."
            case .arrival:
                title = "Phase 4: Arrival"
                goal = "Penerimaan ATIS kedatangan, clearance descent bertahap, STAR arrival routing, dan transfer ke Approach Control."
            case .approach:
                title = "Phase 5: Approach"
                goal = "Otorisasi ILS / Visual Approach, laporan established di localizer, final call Tower, dan cleared to land."
            case .landing:
                title = "Phase 6: Landing & Shutdown"
                goal = "Instruksi keluar landasan (vacate runway), transfer ke Ground, taxi menuju gate/apron, dan penutupan flight plan."
            }

            phaseScripts.append(
                PhaseScript(
                    phase: phase,
                    title: title,
                    educationalGoal: goal,
                    exchanges: phaseExchanges
                )
            )
        }

        let story = generateMissionStoryBriefing(
            level: nil,
            origin: originAirport,
            destination: destinationAirport,
            callsign: callsign,
            aircraftType: missionContext.aircraftType,
            seed: chosenSeed
        )

        return FlightMissionScript(
            id: UUID(),
            seed: chosenSeed,
            profile: chosenProfile,
            archetype: chosenArchetype,
            originAirport: originAirport,
            destinationAirport: destinationAirport,
            callsign: callsign,
            missionContext: missionContext,
            phaseScripts: phaseScripts,
            storyBriefing: story
        )
    }

    private func buildMissionSlotContext(
        missionContext: FlightMissionContext,
        phase: Phase,
        depHoldingPoint: String,
        arrExitTaxiway: String
    ) -> SlotContext {
        let isArrivalOrLater = (phase == .arrival || phase == .approach || phase == .landing)
        let activeAirport = isArrivalOrLater ? missionContext.destinationAirport : missionContext.originAirport
        let activeRunway = isArrivalOrLater ? missionContext.arrRunway : missionContext.depRunway
        let activeWeather = isArrivalOrLater ? missionContext.arrWeather : missionContext.depWeather
        let activeAtis = isArrivalOrLater ? missionContext.arrAtisId : missionContext.depAtisId

        let resolvedCenter = activeAirport.units.center ?? Self.resolveAreaControl(
            originICAO: missionContext.originAirport.icao,
            destinationICAO: missionContext.destinationAirport.icao
        )

        let resolvedDepRadar = activeAirport.units.departure
            ?? activeAirport.units.approach
            ?? resolvedCenter

        return SlotContext(
            airport: activeAirport,
            selectedRunway: activeRunway,
            holdingPoint: depHoldingPoint,
            taxiRoute: missionContext.taxiOutRoute,
            callsign: missionContext.callsign,
            weather: activeWeather,
            atisId: activeAtis,
            unitGround: activeAirport.units.ground,
            unitTower: activeAirport.units.tower,
            unitApproach: activeAirport.units.approach,
            unitDeparture: resolvedDepRadar,
            unitDelivery: activeAirport.units.delivery,
            unitControl: resolvedCenter,
            stand: missionContext.standOrigin,
            aircraftType: missionContext.aircraftType,
            pob: missionContext.profile == .vfrLocal ? 2 : 168,
            airportName: activeAirport.name,
            destinationName: missionContext.destinationAirport.name,
            sidProcedure: missionContext.sidProcedure,
            starProcedure: missionContext.starProcedure,
            squawk: missionContext.squawkCode,
            depFreq: SpokenFormFormatter.frequency(resolvedDepRadar.frequency),
            approachFreq: SpokenFormFormatter.frequency(missionContext.destinationAirport.units.approach?.frequency ?? "119.500"),
            controlFreq: SpokenFormFormatter.frequency(resolvedCenter.frequency),
            arrRunway: SpokenFormFormatter.runway(missionContext.arrRunway.designator),
            arrAtisId: missionContext.arrAtisId,
            visibility: "eight kilometres",
            cloudCondition: "scattered one thousand eight hundred feet",
            temperature: "three zero",
            dewPoint: "two five",
            turnDirection: "left",
            heading: missionContext.departureHeading,
            initialAlt: missionContext.initialAlt,
            levelStatus: "maintaining",
            currentLevel: missionContext.cruisingLevel,
            routeContext: "flight planned route via airway",
            currentPosition: "BUNTA",
            timeUTC: "zero one two zero",
            nextPosition: "DOLTA",
            nextETA: "zero one four five",
            requestedLevel: "flight level three seven zero",
            requestedDeviationDistance: missionContext.weatherDeviationDistance ?? "two zero",
            requestedDeviationDirection: missionContext.weatherDeviationDirection ?? "right",
            approvedDeviationDistance: missionContext.weatherDeviationDistance ?? "two zero",
            approvedDeviationDirection: missionContext.weatherDeviationDirection ?? "right",
            descentLevel: "altitude five thousand feet",
            holdingFix: missionContext.destinationAirport.procedures.holdings.first?.fix ?? "BLI VOR",
            holdingLevel: "seven thousand feet",
            inboundTrack: "zero niner zero",
            eat: "zero three zero five",
            goAroundReason: "traffic still on runway",
            missedAlt: "three thousand feet",
            missedInstruction: "climb straight ahead and contact Approach",
            exitDirection: "left",
            exitTaxiway: arrExitTaxiway,
            destinationStand: missionContext.standDestination,
            taxiInRoute: missionContext.taxiInRoute
        )
    }

    private func resolveContext(airport: Airport, request: ScriptRequest, callsign: String) -> SlotContext {
        let runwayHeadings = Dictionary(uniqueKeysWithValues: airport.runways.map { ($0.designator, $0.headingDegT) })
        let runwayPair = airport.runways.first?.pair ?? [airport.runways.first?.designator ?? "08"]

        let baseRwy = airport.runways.first!
        let weather = WeatherEngine.alignedWeather(
            runway: baseRwy.designator,
            heading: baseRwy.headingDegT,
            seed: request.seed
        )

        let selectedRwyDesignator = WeatherEngine.bestRunway(
            pair: runwayPair,
            headings: runwayHeadings,
            windDirection: Double(weather.windDirection),
            windSpeed: Double(weather.windSpeed)
        ).runway

        let selectedRunway = airport.runways.first(where: { $0.designator == selectedRwyDesignator }) ?? airport.runways.first!
        let atisLetter = ATISGenerator.letter(seed: request.seed)
        let aircraftType = AircraftGenerator.generate(profile: request.profile, seed: request.seed)
        let holdingPoint = Self.pickHoldingPoint(from: selectedRunway.holdingPoints, defaultPoint: "A1", seed: request.seed)
        let taxiRoute = Self.composeTaxiRoute(from: airport.taxiways, seed: request.seed)
        let stand = StandGenerator.originStand(icao: airport.icao, seed: request.seed)

        return SlotContext(
            airport: airport,
            selectedRunway: selectedRunway,
            holdingPoint: holdingPoint,
            taxiRoute: taxiRoute,
            callsign: callsign,
            weather: weather,
            atisId: atisLetter,
            unitGround: airport.units.ground,
            unitTower: airport.units.tower,
            unitApproach: airport.units.approach,
            unitDeparture: airport.units.departure,
            unitDelivery: airport.units.delivery,
            unitControl: airport.units.center,
            stand: stand,
            aircraftType: aircraftType,
            pob: request.profile == .vfrLocal ? 2 : 150,
            airportName: airport.name,
            destinationName: "Denpasar",
            sidProcedure: airport.procedures.sids.first?.name ?? "DOLTA One Alfa",
            starProcedure: airport.procedures.stars.first?.name ?? "ELANG One Alfa",
            squawk: "four two one five",
            depFreq: SpokenFormFormatter.frequency(airport.units.departure?.frequency ?? airport.units.approach?.frequency ?? "119.750"),
            approachFreq: SpokenFormFormatter.frequency(airport.units.approach?.frequency ?? "119.500"),
            controlFreq: SpokenFormFormatter.frequency(airport.units.center?.frequency ?? "127.900"),
            arrRunway: SpokenFormFormatter.runway(selectedRunway.designator),
            arrAtisId: "Mike",
            visibility: "eight kilometres",
            cloudCondition: "scattered one thousand eight hundred feet",
            temperature: "three zero",
            dewPoint: "two five",
            turnDirection: "left",
            heading: Int(selectedRunway.headingDegT),
            initialAlt: "altitude four thousand feet",
            levelStatus: "maintaining",
            currentLevel: "flight level one five zero",
            routeContext: "direct DOLTA",
            currentPosition: "BUNTA",
            timeUTC: "zero three one zero",
            nextPosition: "DOLTA",
            nextETA: "zero three four zero",
            requestedLevel: "flight level one niner zero",
            requestedDeviationDistance: "two zero",
            requestedDeviationDirection: "right",
            approvedDeviationDistance: "two zero",
            approvedDeviationDirection: "right",
            descentLevel: "altitude five thousand feet",
            holdingFix: airport.procedures.holdings.first?.fix ?? "BLI",
            holdingLevel: "seven thousand feet",
            inboundTrack: "zero niner zero",
            eat: "zero three zero five",
            goAroundReason: "traffic still on runway",
            missedAlt: "three thousand feet",
            missedInstruction: "contact Approach",
            exitDirection: "left",
            exitTaxiway: airport.taxiways.first?.spoken ?? "Bravo",
            destinationStand: stand,
            taxiInRoute: taxiRoute
        )
    }

    private func buildTemplateChain(
        availableTemplates: [ScenarioTemplate],
        request: ScriptRequest,
        context: SlotContext
    ) -> [ScenarioTemplate] {
        let templateMap = Dictionary(uniqueKeysWithValues: availableTemplates.map { ($0.id, $0) })

        switch request.phase {
        case .preDeparture:
            let ids = ["PD-01", "PD-03", "PD-06"]
            return ids.compactMap { templateMap[$0] }

        case .departure:
            let ids = ["DP-01", "DP-03", "DP-04", "DP-06"]
            return ids.compactMap { templateMap[$0] }

        case .enRoute:
            let ids = ["ER-01", "ER-02", "ER-03", "ER-05"]
            return ids.compactMap { templateMap[$0] }

        case .arrival:
            if request.includeAbnormal || request.forcedEventID == "ABN-05" {
                return ["AR-01", "AR-05", "AR-02", "AR-04"].compactMap { templateMap[$0] }
            }
            return ["AR-01", "AR-02", "AR-04"].compactMap { templateMap[$0] }

        case .approach:
            if request.includeAbnormal || request.forcedEventID == "ABN-06" {
                return ["AP-01", "AP-02", "AP-07", "AP-08", "AP-06"].compactMap { templateMap[$0] }
            }
            return ["AP-01", "AP-02", "AP-06"].compactMap { templateMap[$0] }

        case .landing:
            return ["LD-01", "LD-02", "LD-03", "LD-04"].compactMap { templateMap[$0] }
        }
    }

    private func fillTemplateSlots(_ template: String, context: SlotContext) -> String {
        var text = template

        let spokenRwy = SpokenFormFormatter.runway(context.selectedRunway.designator)
        let spokenQnh = SpokenFormFormatter.qnh(context.weather.qnh)
        let spokenWindHdg = SpokenFormFormatter.heading(context.weather.windDirection)
        let spokenWindSpd = SpokenFormFormatter.digitWords(String(context.weather.windSpeed))
        let groundFreq = SpokenFormFormatter.frequency(context.unitGround?.frequency ?? "121.600")
        let towerFreq = SpokenFormFormatter.frequency(context.unitTower?.frequency ?? "118.100")
        let spokenHdg = SpokenFormFormatter.heading(context.heading)

        // Clean double "stand" bug
        let cleanStand = context.stand.replacingOccurrences(of: "stand ", with: "", options: [.caseInsensitive])
        let cleanDestStand = context.destinationStand.replacingOccurrences(of: "stand ", with: "", options: [.caseInsensitive])

        let replacements: [String: String] = [
            "{AIRPORT_NAME}": context.airportName,
            "{DESTINATION_NAME}": context.destinationName,
            "{CALLSIGN}": context.callsign,
            "{RUNWAY}": spokenRwy,
            "{ARR_RUNWAY}": context.arrRunway,
            "{UNIT_GROUND}": context.unitGround?.callsign ?? "Ground",
            "{UNIT_TOWER}": context.unitTower?.callsign ?? "Tower",
            "{UNIT_CONTROL}": context.unitControl?.callsign ?? "Control",
            "{UNIT_DELIVERY}": context.unitDelivery?.callsign ?? "Delivery",
            "{UNIT_DEPARTURE}": context.unitDeparture?.callsign ?? "Departure",
            "{UNIT_APPROACH}": context.unitApproach?.callsign ?? "Approach",
            "{GROUND_FREQ}": groundFreq,
            "{TOWER_FREQ}": towerFreq,
            "{DEP_FREQ}": context.depFreq,
            "{APPROACH_FREQ}": context.approachFreq,
            "{CONTROL_FREQ}": context.controlFreq,
            "{HOLDING_POINT}": context.holdingPoint,
            "{TAXI_ROUTE}": context.taxiRoute,
            "{QNH}": spokenQnh,
            "{WIND_DIRECTION}": spokenWindHdg,
            "{WIND_SPEED}": spokenWindSpd,
            "{ATIS_ID}": context.atisId,
            "{ARR_ATIS_ID}": context.arrAtisId,
            "{VISIBILITY}": context.visibility,
            "{CLOUD_CONDITION}": context.cloudCondition,
            "{TEMPERATURE}": context.temperature,
            "{DEW_POINT}": context.dewPoint,
            "{STAND}": cleanStand,
            "{AIRCRAFT_TYPE}": context.aircraftType,
            "{POB}": String(context.pob),
            "{SID_PROCEDURE}": context.sidProcedure,
            "{STAR_PROCEDURE}": context.starProcedure,
            "{SQUAWK}": context.squawk,
            "{TURN_DIRECTION}": context.turnDirection,
            "{PUSHBACK_DIRECTION}": context.turnDirection == "left" ? "west" : "east",
            "{HEADING}": spokenHdg,
            "{INITIAL_ALT}": context.initialAlt,
            "{PASSING_ALT}": "one thousand five hundred feet",
            "{CLIMBING_ALT}": context.initialAlt,
            "{DEPARTURE_ROUTING}": context.sidProcedure,
            "{ASSIGNED_ALT}": context.currentLevel,
            "{LEVEL_STATUS}": context.levelStatus,
            "{CURRENT_LEVEL}": context.currentLevel,
            "{ROUTE_CONTEXT}": context.routeContext,
            "{CURRENT_POSITION}": context.currentPosition,
            "{TIME_UTC}": context.timeUTC,
            "{NEXT_POSITION}": context.nextPosition,
            "{NEXT_ETA}": context.nextETA,
            "{REQUESTED_LEVEL}": context.requestedLevel,
            "{REQUESTED_DEVIATION_DISTANCE}": context.requestedDeviationDistance,
            "{REQUESTED_DEVIATION_DIRECTION}": context.requestedDeviationDirection,
            "{APPROVED_DEVIATION_DISTANCE}": context.approvedDeviationDistance,
            "{APPROVED_DEVIATION_DIRECTION}": context.approvedDeviationDirection,
            "{DESCENT_LEVEL}": context.descentLevel,
            "{HOLDING_FIX}": context.holdingFix,
            "{HOLDING_LEVEL}": context.holdingLevel,
            "{INBOUND_TRACK}": context.inboundTrack,
            "{EAT}": context.eat,
            "{GO_AROUND_REASON}": context.goAroundReason,
            "{MISSED_ALT}": context.missedAlt,
            "{MISSED_INSTRUCTION}": context.missedInstruction,
            "{DOWNWIND_HEADING}": "two seven zero",
            "{INTERCEPT_ALT}": "two thousand five hundred feet",
            "{EXIT_DIRECTION}": context.exitDirection,
            "{EXIT_TAXIWAY}": context.exitTaxiway,
            "{DESTINATION_STAND}": "stand \(cleanDestStand)",
            "{TAXI_IN_ROUTE}": context.taxiInRoute
        ]

        for (slot, value) in replacements {
            text = text.replacingOccurrences(of: slot, with: value)
        }
        return text
    }

    private func resolveCriticalSlots(
        _ rules: [CriticalReadbackRule],
        context: SlotContext
    ) -> [CriticalSlot] {
        let cleanStand = context.stand.replacingOccurrences(of: "stand ", with: "", options: [.caseInsensitive])
        let cleanDestStand = context.destinationStand.replacingOccurrences(of: "stand ", with: "", options: [.caseInsensitive])

        return rules.map { rule in
            let expectedValue: String
            switch rule.slot {
            case "RUNWAY":
                expectedValue = SpokenFormFormatter.runway(context.selectedRunway.designator)
            case "ARR_RUNWAY":
                expectedValue = context.arrRunway
            case "TOWER_FREQ":
                expectedValue = SpokenFormFormatter.frequency(context.unitTower?.frequency ?? "118.100")
            case "GROUND_FREQ":
                expectedValue = SpokenFormFormatter.frequency(context.unitGround?.frequency ?? "121.600")
            case "DEP_FREQ":
                expectedValue = context.depFreq
            case "APPROACH_FREQ":
                expectedValue = context.approachFreq
            case "CONTROL_FREQ":
                expectedValue = context.controlFreq
            case "LINE_UP_WAIT":
                expectedValue = rule.keyword ?? "line up and wait"
            case "TAKEOFF_CLEARANCE":
                expectedValue = rule.keyword ?? "cleared for take-off"
            case "CLEARED_TO_LAND":
                expectedValue = rule.keyword ?? "cleared to land"
            case "GOING_AROUND":
                expectedValue = rule.keyword ?? "going around"
            case "APPROVAL":
                expectedValue = rule.keyword ?? "start-up approved"
            case "HOLD_SHORT_RUNWAY":
                expectedValue = rule.keyword ?? "hold short runway"
            case "CALLSIGN":
                expectedValue = context.callsign
            case "QNH":
                expectedValue = SpokenFormFormatter.qnh(context.weather.qnh)
            case "ATIS_ID":
                expectedValue = context.atisId
            case "ARR_ATIS_ID":
                expectedValue = context.arrAtisId
            case "DESTINATION_NAME":
                expectedValue = context.destinationName
            case "SID_PROCEDURE":
                expectedValue = context.sidProcedure
            case "STAR_PROCEDURE":
                expectedValue = context.starProcedure
            case "SQUAWK":
                expectedValue = context.squawk
            case "HOLDING_POINT":
                expectedValue = context.holdingPoint
            case "TAXI_ROUTE":
                expectedValue = context.taxiRoute
            case "HEADING":
                expectedValue = SpokenFormFormatter.heading(context.heading)
            case "INITIAL_ALT":
                expectedValue = context.initialAlt
            case "TURN_DIRECTION":
                expectedValue = context.turnDirection
            case "CURRENT_LEVEL":
                expectedValue = context.currentLevel
            case "CURRENT_POSITION":
                expectedValue = context.currentPosition
            case "TIME_UTC":
                expectedValue = context.timeUTC
            case "NEXT_POSITION":
                expectedValue = context.nextPosition
            case "NEXT_ETA":
                expectedValue = context.nextETA
            case "DOWNWIND_HEADING":
                expectedValue = "two seven zero"
            case "INTERCEPT_ALT":
                expectedValue = "two thousand five hundred feet"
            case "DESCENT_LEVEL":
                expectedValue = context.descentLevel
            case "HOLDING_FIX":
                expectedValue = context.holdingFix
            case "HOLDING_LEVEL":
                expectedValue = context.holdingLevel
            case "INBOUND_TRACK":
                expectedValue = context.inboundTrack
            case "EAT":
                expectedValue = context.eat
            case "MISSED_ALT":
                expectedValue = context.missedAlt
            case "MISSED_INSTRUCTION":
                expectedValue = context.missedInstruction
            case "EXIT_TAXIWAY":
                expectedValue = context.exitTaxiway
            case "STAND":
                expectedValue = cleanStand
            case "DESTINATION_STAND":
                expectedValue = "stand \(cleanDestStand)"
            case "TAXI_IN_ROUTE":
                expectedValue = context.taxiInRoute
            case "APPROVED_DEVIATION_DISTANCE":
                expectedValue = context.approvedDeviationDistance
            case "APPROVED_DEVIATION_DIRECTION":
                expectedValue = context.approvedDeviationDirection
            default:
                expectedValue = rule.keyword ?? rule.slot
            }

            return CriticalSlot(
                slot: rule.slot,
                expectedValue: expectedValue,
                type: rule.type,
                position: rule.position
            )
        }
    }

    // MARK: - Combination Helpers
    private static func composeTaxiRoute(from taxiways: [Taxiway], seed: Int) -> String {
        guard !taxiways.isEmpty else { return "Alfa" }
        if taxiways.count == 1 {
            return taxiways[0].spoken
        }
        if abs(seed) % 2 == 0 && taxiways.count >= 2 {
            let idx1 = abs(seed) % taxiways.count
            var idx2 = abs(seed + 1) % taxiways.count
            if idx1 == idx2 { idx2 = (idx1 + 1) % taxiways.count }
            return "\(taxiways[idx1].spoken) and \(taxiways[idx2].spoken)"
        }
        return taxiways[abs(seed) % taxiways.count].spoken
    }

    private static func pickStand(from stands: [Stand], defaultStand: String, seed: Int) -> String {
        guard !stands.isEmpty else { return defaultStand }
        return stands[abs(seed) % stands.count].spoken
    }

    private static func pickHoldingPoint(from holdingPoints: [String], defaultPoint: String, seed: Int) -> String {
        let raw = !holdingPoints.isEmpty ? holdingPoints[abs(seed) % holdingPoints.count] : defaultPoint
        return SpokenFormFormatter.holdingPoint(raw)
    }

    // MARK: - Dynamic Procedures Resolver
    public static func resolveProcedures(
        originICAO: String,
        destinationICAO: String,
        level: CurriculumLevel
    ) -> (sid: String, star: String, waypoints: (curr: String, next: String)) {
        let sidName: String
        let starName: String
        let waypoints: (curr: String, next: String)

        switch originICAO {
        case "WADY":
            sidName = (level == .level1) ? "Circuit Departure" : "Area Alpha via Selat Bali"
            waypoints = ("Point Alfa", "Point Charlie")
        case "WICB":
            sidName = (level == .level1) ? "Curug Visual Circuit" : "Mauk One Departure"
            waypoints = ("CURUG", "Area Alfa")
        case "WART":
            sidName = (level == .level1) ? "Trunojoyo Visual Circuit" : "Madura East Departure"
            waypoints = ("SUP VOR", "Madura South")
        case "WAHI":
            sidName = "JOG One Charlie"
            waypoints = ("JOG VOR", "PRAMB")
        case "WARR":
            sidName = "SURABAYA One Bravo"
            waypoints = ("SURBA", "GANDI")
        case "WADD":
            sidName = "BLI Two Charlie"
            waypoints = ("POSOP", "BLI VOR")
        case "WIII":
            sidName = "BUNTA One Alfa"
            waypoints = ("BUNTA", "DOLTA")
        default:
            sidName = level.sidName
            waypoints = ("BUNTA", "DOLTA")
        }

        switch destinationICAO {
        case "WADY":
            starName = (level == .level1) ? "Overhead Join Pattern" : "Right Base Runway 08"
        case "WICB":
            starName = (level == .level1) ? "Downwind Join Runway 12" : "CR NDB Inbound Runway 30"
        case "WART":
            starName = (level == .level1) ? "Overhead Join Runway 12" : "Straight-in Runway 12"
        case "WAHI":
            starName = "GANDI One Alfa"
        case "WARR":
            starName = "POSOP One Alfa"
        case "WADD":
            starName = "BLI One Bravo"
        case "WIII":
            starName = "DOLTA One Alfa"
        default:
            starName = level.starName
        }

        return (sid: sidName, star: starName, waypoints: waypoints)
    }

    // MARK: - Dynamic Airport-Driven Mission Generator
    public func generateDynamicMission(
        originICAO: String,
        destinationICAO: String? = nil,
        role: UserRole = .pilot,
        mode: SimulationMode = .mission,
        seed: Int? = nil,
        selectedContingencies: Set<ContingencySelection> = [],
        retryAct: MissionAct? = nil
    ) throws -> FlightMissionScript {
        let chosenSeed = seed ?? Int.random(in: 1000...9999)
        let resolvedDestICAO: String
        let level: CurriculumLevel

        if role == .pilot {
            resolvedDestICAO = (destinationICAO == nil || destinationICAO?.isEmpty == true) ? originICAO : destinationICAO!
            level = AirportCurriculumRegistry.effectiveLevel(origin: originICAO, destination: resolvedDestICAO)
        } else {
            resolvedDestICAO = originICAO
            level = AirportCurriculumRegistry.level(for: originICAO)
        }

        let originAirport = try airportRepository.airport(icao: originICAO)
        let destinationAirport = try airportRepository.airport(icao: resolvedDestICAO)

        let profile: FlightProfile = (level == .level1) ? .vfrLocal : .ifrCommercial
        let callsign = CallsignGenerator.generate(level: level, seed: chosenSeed)
        let aircraftType = AircraftGenerator.generate(profile: profile, level: level, airportICAO: originAirport.icao, seed: chosenSeed)

        // Dynamic Wind and Runways for Origin
        let depRwyHeadings = Dictionary(uniqueKeysWithValues: originAirport.runways.map { ($0.designator, $0.headingDegT) })
        let depRwyPair = originAirport.runways.first?.pair ?? [originAirport.runways.first?.designator ?? "08"]
        let depWeather = WeatherEngine.alignedWeather(
            runway: originAirport.runways.first?.designator ?? "08",
            heading: originAirport.runways.first?.headingDegT ?? 80,
            seed: chosenSeed,
            level: level
        )
        let depRwyDesignator = WeatherEngine.bestRunway(
            pair: depRwyPair,
            headings: depRwyHeadings,
            windDirection: Double(depWeather.windDirection),
            windSpeed: Double(depWeather.windSpeed)
        ).runway
        let depRunway = originAirport.runways.first(where: { $0.designator == depRwyDesignator }) ?? originAirport.runways.first!

        // Destination Runways
        let arrRwyHeadings = Dictionary(uniqueKeysWithValues: destinationAirport.runways.map { ($0.designator, $0.headingDegT) })
        let arrRwyPair = destinationAirport.runways.first?.pair ?? [destinationAirport.runways.first?.designator ?? "09"]
        let arrWeather = WeatherEngine.alignedWeather(
            runway: destinationAirport.runways.first?.designator ?? "09",
            heading: destinationAirport.runways.first?.headingDegT ?? 90,
            seed: chosenSeed + 101,
            level: level
        )
        let arrRwyDesignator = WeatherEngine.bestRunway(
            pair: arrRwyPair,
            headings: arrRwyHeadings,
            windDirection: Double(arrWeather.windDirection),
            windSpeed: Double(arrWeather.windSpeed)
        ).runway
        let arrRunway = destinationAirport.runways.first(where: { $0.designator == arrRwyDesignator }) ?? destinationAirport.runways.first!

        let depAtisId = ATISGenerator.letter(seed: chosenSeed)
        let arrAtisId = ATISGenerator.letter(seed: chosenSeed + 5)
        let depHeading = Int(depRunway.headingDegT)

        // Level-specific Flight Level & Procedures (VARIABEL_DINAMIS_KURIKULUM_LEVEL_1_5.pdf)
        let cruisingLevel = FlightLevelGenerator.cruisingLevel(level: level, headingTrack: depHeading, seed: chosenSeed)
        let initialAlt = FlightLevelGenerator.initialAltitude(level: level, seed: chosenSeed)

        let procs = Self.resolveProcedures(originICAO: originAirport.icao, destinationICAO: destinationAirport.icao, level: level)
        let sidName = procs.sid
        let starName = procs.star

        let standOrigin = StandGenerator.originStand(icao: originAirport.icao, seed: chosenSeed)
        let standDest = StandGenerator.destinationStand(icao: destinationAirport.icao, seed: chosenSeed)
        let taxiOutRoute = Self.composeTaxiRoute(from: originAirport.taxiways, seed: chosenSeed)
        let taxiInRoute = Self.composeTaxiRoute(from: destinationAirport.taxiways, seed: chosenSeed + 7)
        let depHoldingPoint = Self.pickHoldingPoint(from: depRunway.holdingPoints, defaultPoint: "A1", seed: chosenSeed)

        // Dynamic Exit Taxiway and Direction based on Airport & Runway orientation
        let exitInfo = resolveExitTaxiwayAndDirection(
            airport: destinationAirport,
            runwayDesignator: arrRunway.designator,
            seed: chosenSeed
        )
        let arrExitTaxiway = exitInfo.taxiway
        let arrExitDirection = exitInfo.direction

        let squawkCode: String = SquawkGenerator.generate(level: level, seed: chosenSeed)

        // Multi-contingency resolution: Mission rehearses; Exam follows the prescribed assessment distribution.
        let effectiveContingencies = selectedContingencies.isEmpty ? Set(level.allowedScenarios) : selectedContingencies
        let chosenContingencies: [InjectedContingency] = resolveMultipleContingencies(
            selectedOptions: effectiveContingencies,
            level: level,
            mode: mode,
            seed: chosenSeed
        )

        let archetype: MissionArchetype
        if chosenContingencies.contains(where: { $0.severity == .distress }) {
            archetype = (level == .level1) ? .vfrSimulatedEngineOut : .ifrGoAroundReApproach
        } else if chosenContingencies.contains(where: { $0.severity == .urgency }) {
            archetype = (level == .level3) ? .ifrHoldingPattern : .ifrWeatherAvoidance
        } else if chosenContingencies.contains(where: { $0.severity == .abnormal }) {
            archetype = .ifrAirspaceCongestion
        } else {
            archetype = (level == .level1) ? .vfrCircuitTouchAndGo : .ifrRoutineDirect
        }

        let hasWeatherDeviation = chosenContingencies.contains(where: { $0.title.contains("Weather") })
        let deviationDistance = hasWeatherDeviation ? "one five" : nil
        let deviationDirection = hasWeatherDeviation ? "right" : nil

        let missionContext = FlightMissionContext(
            missionID: UUID(),
            profile: profile,
            archetype: archetype,
            aircraftType: aircraftType,
            callsign: callsign,
            originAirport: originAirport,
            destinationAirport: destinationAirport,
            depRunway: depRunway,
            arrRunway: arrRunway,
            depWeather: depWeather,
            arrWeather: arrWeather,
            depAtisId: depAtisId,
            arrAtisId: arrAtisId,
            cruisingLevel: cruisingLevel,
            squawkCode: squawkCode,
            initialAlt: initialAlt,
            sidProcedure: sidName,
            starProcedure: starName,
            departureHeading: depHeading,
            standOrigin: standOrigin,
            standDestination: standDest,
            taxiOutRoute: taxiOutRoute,
            taxiInRoute: taxiInRoute,
            weatherDeviationDistance: deviationDistance,
            weatherDeviationDirection: deviationDirection
        )

        var phaseScripts: [PhaseScript] = []
        var globalTurn = 1

        // Mutatable runtime state across phases
        var activeDepRunway = depRunway
        var activeHoldingPoint = depHoldingPoint
        var activeWeather = depWeather
        var isFlightTerminatedEarly = false
        var executedContingencies: [InjectedContingency] = []

        for phase in Phase.allCases {
            // Create Slot Context with dynamic mutated state & exit parameters
            let depExit = originAirport.taxiways.first?.spoken ?? "Alfa"
            let slotContext = buildMissionSlotContext(
                missionContext: missionContext,
                phase: phase,
                depHoldingPoint: activeHoldingPoint,
                arrExitTaxiway: isFlightTerminatedEarly ? depExit : arrExitTaxiway,
                exitDirection: isFlightTerminatedEarly ? "left" : arrExitDirection,
                customDepRunway: activeDepRunway,
                customWeather: activeWeather,
                isEarlyTerminatedOnGround: isFlightTerminatedEarly
            )

            var phaseExchanges: [FilledExchange] = []
            var title: String = ""
            var goal: String = ""

            if isFlightTerminatedEarly && phase != .preDeparture && phase != .departure {
                // ADAPTIVE NON-EMPTY PHASES FOR GROUND/ABORTED CONTINGENCIES
                let termCont = executedContingencies.first(where: { $0.title.contains("Abort") || $0.title.contains("EFATO") })
                let adaptive = buildTerminatedEarlyPhaseExchanges(
                    phase: phase,
                    contingency: termCont,
                    context: slotContext,
                    role: role,
                    currentGlobalTurn: &globalTurn
                )
                phaseExchanges = adaptive.exchanges
                title = adaptive.title
                goal = adaptive.goal
            } else {
                phaseExchanges = buildDynamicPhaseExchanges(
                    phase: phase,
                    level: level,
                    seed: chosenSeed,
                    role: role,
                    context: slotContext,
                    contingencies: chosenContingencies,
                    activeDepRunway: &activeDepRunway,
                    activeHoldingPoint: &activeHoldingPoint,
                    activeWeather: &activeWeather,
                    isFlightTerminatedEarly: &isFlightTerminatedEarly,
                    executedContingencies: &executedContingencies,
                    globalTurn: &globalTurn
                )

                switch phase {
                case .preDeparture:
                    title = "Phase 1: Pre-Departure"
                    goal = "Penerimaan ATIS, \(level == .level1 ? "Engine start & local brief" : "IFR route clearance via \(sidName)"), pushback & taxi hold short."
                case .departure:
                    title = "Phase 2: Departure"
                    goal = isFlightTerminatedEarly
                        ? "Handoff Tower, take-off roll, dan penanganan kondisi darurat sebelum/sesaat setelah airborne."
                        : "Handoff Tower, \(level == .level1 ? "circuit ready call" : "conditional line-up"), take-off clearance, dan airborne handoff."
                case .enRoute:
                    title = "Phase 3: En-Route"
                    goal = "Radar contact, position report over waypoint, cruising level \(cruisingLevel), transfer sektor."
                case .arrival:
                    title = "Phase 4: Arrival"
                    goal = "Penerimaan ATIS kedatangan, descent clearance, rute \(starName), transfer Approach."
                case .approach:
                    title = "Phase 5: Approach"
                    goal = "\(level == .level1 ? "Visual circuit report (downwind/final)" : "ILS approach established report"), cleared to land."
                case .landing:
                    title = "Phase 6: Landing & Shutdown"
                    goal = "Vacate runway via \(arrExitTaxiway) (\(arrExitDirection)), transfer Ground, taxi in ke \(standDest), penutupan flight plan."
                }
            }

            phaseExchanges = Self.enrichExchangesWithScaffolding(
                exchanges: phaseExchanges,
                level: level,
                phase: phase,
                context: slotContext,
                seed: chosenSeed,
                contingencies: chosenContingencies
            )

            phaseScripts.append(
                PhaseScript(
                    phase: phase,
                    title: title,
                    educationalGoal: goal,
                    exchanges: phaseExchanges
                )
            )
        }

        // Generate 3-Act Diagnostic Report with ICAO Checkpoints
        let act1Score = 86 + (abs(chosenSeed) % 11)      // 86..96%
        let act2Score = 83 + (abs(chosenSeed + 3) % 13)  // 83..95%
        let act3Score = 81 + (abs(chosenSeed + 7) % 14)  // 81..94%
        let overallScore = (act1Score + act2Score + act3Score) / 3
        let isPass = overallScore >= 80

        let act1Eval = ActEvaluation(
            act: .act1Departure,
            score: act1Score,
            isPassed: act1Score >= 80,
            criticalViolations: [],
            penalties: (act1Score < 90) ? [.phoneticHesitation] : [],
            feedback: "Kepatuhan clearance departure, verifikasi runway & hold short sesuai ICAO Doc 9432 Bab 4."
        )

        let act2Eval = ActEvaluation(
            act: .act2EnRoute,
            score: act2Score,
            isPassed: act2Score >= 80,
            criticalViolations: [],
            penalties: (act2Score < 85) ? [.longSilence] : [],
            feedback: "Disiplin pelaporan posisi di fix waypoint dan kepatuhan level jelajah stabil."
        )

        let act3Eval = ActEvaluation(
            act: .act3Arrival,
            score: act3Score,
            isPassed: act3Score >= 80,
            criticalViolations: [],
            penalties: (act3Score < 85) ? [.wordOrderTransposition] : [],
            feedback: "Prosedur kedatangan, capture ILS / visual downwind dan vacating runway sesuai Doc 4444."
        )

        let actEvals = [act1Eval, act2Eval, act3Eval]

        let numbersSc = 90 + (abs(chosenSeed) % 9)
        let phraseSc = 86 + (abs(chosenSeed) % 11)
        let pttSc = 88 + (abs(chosenSeed) % 10)
        let fluencySc = 92 + (abs(chosenSeed) % 7)
        let calcOverall = Int(Double(numbersSc) * 0.40 + Double(phraseSc) * 0.25 + Double(pttSc) * 0.20 + Double(fluencySc) * 0.15)
        let finalOverall = isPass ? max(calcOverall, 80) : min(calcOverall, 75)

        let report = DiagnosticReport(
            overallScore: finalOverall,
            readbackAccuracyPercent: numbersSc,
            phraseologyScorePercent: phraseSc,
            disciplineScorePercent: pttSc,
            isPassed: isPass,
            summaryFeedback: isPass
                ? "Lulus Evaluasi Rapor Ketertiban Radio (\(finalOverall)%). Kepatuhan frasa dan verifikasi angka ICAO terpenuhi."
                : "Evaluasi memerlukan perbaikan pada babak tertentu. Ulangi babak yang belum mencapai 80%.",
            improvementAreas: [
                "Pastikan nomor runway selalu diucapkan di awal/akhir readback izin take-off & landing (ICAO Doc 4444 Sec 12.2.3).",
                "Perhatikan instruksi STOP IMMEDIATELY dan konfirmasi status 'stopping/aborting take-off' tanpa jeda.",
                "Gunakan istilah baku ICAO tanpa penambahan filler kata percakapan bebas."
            ],
            actEvaluations: actEvals,
            criticalViolations: [],
            nonCriticalPenalties: actEvals.flatMap { $0.penalties },
            numbersScore: numbersSc,
            phraseologyScore: phraseSc,
            pttDisciplineScore: pttSc,
            fluencyScore: fluencySc,
            actualWpm: level == .level1 ? 88 : 110,
            fillerWordsCount: 0,
            hesitationCount: 0,
            pttLatencyMs: 315 + (abs(chosenSeed) % 120),
            numbersAccuracyPercentVal: numbersSc
        )

        var uniqueExecuted: [InjectedContingency] = []
        for c in executedContingencies {
            if !uniqueExecuted.contains(where: { $0.title == c.title }) {
                uniqueExecuted.append(c)
            }
        }

        // If not terminated early on ground, ensure all chosen contingencies are represented
        if !isFlightTerminatedEarly {
            for c in chosenContingencies {
                if !uniqueExecuted.contains(where: { $0.title == c.title }) {
                    uniqueExecuted.append(c)
                }
            }
        }

        let story = generateMissionStoryBriefing(
            level: level,
            origin: originAirport,
            destination: destinationAirport,
            callsign: callsign,
            aircraftType: aircraftType,
            seed: chosenSeed
        )

        return FlightMissionScript(
            id: UUID(),
            seed: chosenSeed,
            level: level,
            role: role,
            mode: mode,
            profile: profile,
            archetype: archetype,
            originAirport: originAirport,
            destinationAirport: destinationAirport,
            callsign: callsign,
            missionContext: missionContext,
            phaseScripts: phaseScripts,
            diagnosticReport: report,
            contingencies: uniqueExecuted,
            storyBriefing: story
        )
    }

    // MARK: - Dedicated Exam Mission Generator (VARIABEL_DINAMIS_KURIKULUM_LEVEL_1_5.pdf)
    public func generateExamMission(
        level: CurriculumLevel,
        role: UserRole = .pilot,
        seed: Int? = nil
    ) throws -> FlightMissionScript {
        let chosenSeed = seed ?? Int.random(in: 1000...9999)
        let absSeed = abs(chosenSeed)
        let originICAO: String
        let destinationICAO: String

        switch level {
        case .level1:
            // Basis: WADY (Banyuwangi), WICB (Curug), WADE (Buleleng)
            // 1 Putaran VFR Sirkuit Penuh (One-shot, local circuit full stop)
            let l1Airports = ["WADY", "WICB", "WADE"]
            originICAO = l1Airports[absSeed % l1Airports.count]
            destinationICAO = originICAO

        case .level2:
            // Basis: WAHI (YIA), WADL (Lombok), WAOO (Banjarmasin), WIPP (Palembang)
            let l2Airports = ["WAHI", "WADL", "WAOO", "WIPP"]
            let oIdx = absSeed % l2Airports.count
            originICAO = l2Airports[oIdx]
            let remaining = l2Airports.filter { $0 != originICAO }
            destinationICAO = remaining[abs(chosenSeed / 4) % remaining.count]

        case .level3:
            // Basis: WARS (Semarang), WADD (Bali), WIDD (Batam), WIPT (Padang), WARQ (Solo), WALL (Balikpapan)
            let l3Airports = ["WARS", "WADD", "WIDD", "WIPT", "WARQ", "WALL"]
            let oIdx = absSeed % l3Airports.count
            originICAO = l3Airports[oIdx]
            let remaining = l3Airports.filter { $0 != originICAO }
            destinationICAO = remaining[abs(chosenSeed / 6) % remaining.count]

        case .level4:
            // Basis: WIII (Cengkareng), WARR (Surabaya), WAAA (Makassar), WIMM (Medan), WIHH (Halim)
            let l4Airports = ["WIII", "WARR", "WAAA", "WIMM", "WIHH"]
            let oIdx = absSeed % l4Airports.count
            originICAO = l4Airports[oIdx]
            let remaining = l4Airports.filter { $0 != originICAO }
            destinationICAO = remaining[abs(chosenSeed / 5) % remaining.count]

        case .level5:
            // Basis: WAVV (Wamena), WICC (Bandung), WAFB (Toraja), WABP (Timika), WALR (Tarakan)
            // Mountain / High-Risk Valley realistic operational routes:
            let l5Pairs: [(origin: String, dest: String)] = [
                ("WAVV", "WABP"), // Wamena -> Timika (Papua Valley & Ridge)
                ("WABP", "WAVV"), // Timika -> Wamena (Papua Return)
                ("WICC", "WIHH"), // Bandung Husein -> Jakarta Halim (Priangan Basin)
                ("WAFB", "WAAA"), // Toraja Buntu Kunik -> Makassar (Sulawesi Ridge)
                ("WALR", "WALL")  // Tarakan Juwata -> Balikpapan (Kalimantan Ridge)
            ]
            let pair = l5Pairs[absSeed % l5Pairs.count]
            originICAO = pair.origin
            destinationICAO = pair.dest
        }

        return try generateDynamicMission(
            originICAO: originICAO,
            destinationICAO: destinationICAO,
            role: role,
            mode: .exam,
            seed: chosenSeed
        )
    }

    // Overload: Level-based mission generator (bridges to dynamic generator)
    // NOTE: Legacy overloads kept for backward compat with old tests only.
    // Preferred entry point: generateDynamicMission(originICAO:destinationICAO:role:)
    public func generateLevelMission(
        level: CurriculumLevel,
        role: UserRole = .pilot,
        mode: SimulationMode = .mission,
        seed: Int? = nil,
        selectedContingencies: Set<ContingencySelection>
    ) throws -> FlightMissionScript {
        // Use first airport of that level as default origin for legacy compatibility
        let airports = AirportCurriculumRegistry.airports(for: level)
        let originICAO = airports.first?.icao ?? "WADY"
        // For ATC: same aerodrome (no destination). For Pilot: pick second-level airport as dest.
        let destLevel = level.nextLevel ?? level
        let destAirports = AirportCurriculumRegistry.airports(for: destLevel)
        let destICAO = (role == .atc) ? nil : (destAirports.first?.icao ?? originICAO)
        return try generateDynamicMission(
            originICAO: originICAO,
            destinationICAO: destICAO,
            role: role,
            mode: mode,
            seed: seed,
            selectedContingencies: selectedContingencies
        )
    }

    // Overload: Single contingency selection
    public func generateLevelMission(
        level: CurriculumLevel,
        role: UserRole = .pilot,
        mode: SimulationMode = .mission,
        seed: Int? = nil,
        contingencyOption: ContingencySelection = .auto
    ) throws -> FlightMissionScript {
        let set: Set<ContingencySelection>
        if contingencyOption == .auto {
            set = Set(level.allowedScenarios)
        } else if contingencyOption == .routineOnly {
            set = []
        } else {
            set = [contingencyOption]
        }
        return try generateLevelMission(
            level: level,
            role: role,
            mode: mode,
            seed: seed,
            selectedContingencies: set
        )
    }

    // Overload for backward compatibility
    public func generateLevelMission(
        level: CurriculumLevel,
        role: UserRole = .pilot,
        mode: SimulationMode = .mission,
        seed: Int? = nil,
        forceEmergency: Bool
    ) throws -> FlightMissionScript {
        return try generateLevelMission(
            level: level,
            role: role,
            mode: mode,
            seed: seed,
            contingencyOption: forceEmergency ? .abortTakeoff : .auto
        )
    }

    public static func resolveAreaControl(originICAO: String, destinationICAO: String) -> ATCUnit {
        let makassarAirports: Set<String> = [
            "WAAA", "WAVV", "WABP", "WAFB", "WALR", "WALL", "WAOO", "WADD", "WADL", "WADE"
        ]
        if makassarAirports.contains(originICAO) {
            return ATCUnit(callsign: "Makassar Control", frequency: "123.600")
        } else if makassarAirports.contains(destinationICAO) {
            return ATCUnit(callsign: "Makassar Control", frequency: "124.200")
        } else {
            return ATCUnit(callsign: "Jakarta Control", frequency: "134.400")
        }
    }

    // MARK: - Canonical Curriculum Mission Generator (LAMPIRAN_MAPPING_SCAFFOLDING.pdf)
    public func generateCanonicalMission(
        mission: CanonicalMission,
        role: UserRole = .pilot,
        mode: SimulationMode = .mission,
        seed: Int? = nil
    ) throws -> FlightMissionScript {
        var set: Set<ContingencySelection> = []
        if mission.primaryContingency != .routineOnly {
            set.insert(mission.primaryContingency)
        }
        if let sec = mission.secondaryContingency, sec != .routineOnly {
            set.insert(sec)
        }
        return try generateDynamicMission(
            originICAO: mission.originICAO,
            destinationICAO: mission.destinationICAO,
            role: role,
            mode: mode,
            seed: seed,
            selectedContingencies: set
        )
    }

    // MARK: - Scaffolding Payload Generator Engine (MAPPING_SCAFFOLDING.pdf & Doc 9835)
    public static func enrichExchangesWithScaffolding(
        exchanges: [FilledExchange],
        level: CurriculumLevel,
        phase: Phase,
        context: SlotContext,
        seed: Int,
        contingencies: [InjectedContingency]
    ) -> [FilledExchange] {
        if level == .level2 {
            return enrichLevel2Exchanges(exchanges: exchanges, context: context)
        }
        return exchanges.map { ex in
            switch level {
            case .level1:
                return enrichLevel1(exchange: ex, phase: phase, context: context)
            case .level2:
                return ex // handled in enrichLevel2Exchanges
            case .level3:
                return enrichLevel3(exchange: ex, phase: phase, context: context)
            case .level4:
                return enrichLevel4(exchange: ex, phase: phase, context: context, seed: seed, contingencies: contingencies)
            case .level5:
                return enrichLevel5(exchange: ex, phase: phase, context: context, seed: seed, contingencies: contingencies)
            }
        }
    }

    private static func enrichLevel1(exchange: FilledExchange, phase: Phase, context: SlotContext) -> FilledExchange {
        let rwy = context.selectedRunway.designator
        let pos: String
        switch phase {
        case .preDeparture:
            pos = exchange.turn <= 2 ? "Apron Stand \(context.stand)" : "Holding Point \(context.holdingPoint)"
        case .departure:
            pos = "Holding Point \(context.holdingPoint) Runway \(rwy)"
        case .enRoute:
            pos = "Local Training Area, \(context.initialAlt)"
        case .arrival:
            pos = "Overhead Aerodrome, \(context.initialAlt)"
        case .approach:
            let lower = exchange.text.lowercased()
            if lower.contains("downwind") {
                pos = "Left Downwind Runway \(rwy)"
            } else if lower.contains("final") {
                pos = "Final Runway \(rwy)"
            } else {
                pos = "Visual Circuit Runway \(rwy)"
            }
        case .landing:
            pos = "Runway \(rwy) Vacated"
        }

        let action = exchange.objective ?? (exchange.eventTag ?? "Laporkan pesan ke ATC")
        let phoneticGuide = "RWY \(rwy) [\(SpokenFormFormatter.digitWords(rwy))], QNH \(context.weather.qnh) [\(SpokenFormFormatter.digitWords(String(context.weather.qnh)))]"
        let numbersGuide: [String: String] = [
            "0": "ZE-RO", "1": "WUN", "2": "TOO", "3": "TREE", "4": "FOW-ER",
            "5": "FIFE", "6": "SIX", "7": "SEV-EN", "8": "AIT", "9": "NIN-ER"
        ]

        let stationName = context.unitTower?.callsign ?? "\(context.airport.name) Tower"
        let payload = FourSlotCardPayload(
            station: stationName,
            callsign: context.callsign,
            position: pos,
            action: action,
            phoneticGuide: phoneticGuide,
            numbersGuide: numbersGuide
        )
        return exchange.withScaffolding(type: .fourSlotCard, fourSlot: payload)
    }

    // MARK: - Level 2 Scaffolding: Cloze Masked on ATC Transmissions (Anti-Teleprompter)
    private static func enrichLevel2Exchanges(exchanges: [FilledExchange], context: SlotContext) -> [FilledExchange] {
        var enriched: [FilledExchange] = []

        for (idx, ex) in exchanges.enumerated() {
            if ex.isUserTurn {
                // User pilot turn: Cloze is NOT for the pilot!
                // Pilot receives clean exchange with objective, and NO cloze template.
                enriched.append(ex.withScaffolding(type: nil, cloze: nil))
            } else {
                // ATC turn: In Level 1, ATC was full. In Level 2, ATC transmission is cloze-masked!
                let nextPilotTurn = (idx + 1 < exchanges.count && exchanges[idx + 1].isUserTurn) ? exchanges[idx + 1] : nil
                let atcExchange = enrichATCLevel2Cloze(exchange: ex, nextPilotTurn: nextPilotTurn, context: context)
                enriched.append(atcExchange)
            }
        }

        return enriched
    }

    private static func enrichATCLevel2Cloze(
        exchange: FilledExchange,
        nextPilotTurn: FilledExchange?,
        context: SlotContext
    ) -> FilledExchange {
        var maskedText = exchange.text
        var maskedSlots: [MaskedSlot] = []

        // 1. Gather candidate slot values to mask from subsequent pilot readback
        var candidates: [(value: String, type: String)] = []

        if let next = nextPilotTurn, !next.criticalSlots.isEmpty {
            for slot in next.criticalSlots {
                if slot.slot.contains("CALLSIGN") || slot.type.contains("Identifier") {
                    continue
                }
                candidates.append((value: slot.expectedValue, type: slot.type))
            }
        }

        // 2. Also check common critical parameters if present in ATC's text
        let qnhStr = SpokenFormFormatter.qnh(context.weather.qnh)
        candidates.append((value: qnhStr, type: "mandatoryQnh"))

        if !context.squawk.isEmpty {
            candidates.append((value: context.squawk, type: "mandatorySquawk"))
        }

        let rwyStr = SpokenFormFormatter.runway(context.selectedRunway.designator)
        candidates.append((value: rwyStr, type: "mandatoryRunway"))

        let arrRwyStr = context.arrRunway
        if !arrRwyStr.isEmpty {
            candidates.append((value: arrRwyStr, type: "mandatoryRunway"))
        }

        let hpStr = context.holdingPoint
        if !hpStr.isEmpty {
            candidates.append((value: hpStr, type: "mandatoryHoldingPoint"))
        }

        // Sort candidates by length descending to match full multi-word phrases first
        candidates.sort { $0.value.count > $1.value.count }

        var blankIdx = 1
        for cand in candidates {
            guard !cand.value.isEmpty else { continue }
            if maskedText.contains(cand.value) && !maskedSlots.contains(where: { $0.correctValue == cand.value }) {
                maskedText = maskedText.replacingOccurrences(of: cand.value, with: "[ ___ ]")
                maskedSlots.append(MaskedSlot(slotId: "BLANK_\(blankIdx)", correctValue: cand.value, type: cand.type))
                blankIdx += 1
            }
        }

        // 3. Fallback: mask digit words if no candidate matched
        if maskedSlots.isEmpty {
            let words = exchange.text.components(separatedBy: " ")
            var newWords: [String] = []
            var maskedAny = false
            for (wIdx, w) in words.enumerated() {
                let lower = w.lowercased()
                if (lower == "flight" && wIdx + 1 < words.count && words[wIdx + 1].lowercased() == "level") ||
                   (lower == "heading" && wIdx + 1 < words.count) ||
                   (lower == "speed" && wIdx + 1 < words.count) {
                    newWords.append(w)
                } else if !maskedAny && (w.rangeOfCharacter(from: .decimalDigits) != nil || lower == "one" || lower == "two" || lower == "three" || lower == "four" || lower == "five" || lower == "six" || lower == "seven" || lower == "eight" || lower == "niner" || lower == "zero") {
                    newWords.append("[ ___ ]")
                    maskedSlots.append(MaskedSlot(slotId: "BLANK_\(blankIdx)", correctValue: w, type: "CRITICAL_VALUE"))
                    blankIdx += 1
                    maskedAny = true
                } else {
                    newWords.append(w)
                }
            }
            if maskedAny {
                maskedText = newWords.joined(separator: " ")
            }
        }

        guard !maskedSlots.isEmpty else {
            return exchange.withScaffolding(type: nil, cloze: nil)
        }

        let payload = ClozeMaskedPayload(
            displayTemplate: maskedText,
            maskedSlots: maskedSlots,
            timeoutSeconds: 8.0
        )
        return exchange.withScaffolding(type: .clozeMasked, cloze: payload)
    }

    private static func enrichLevel3(exchange: FilledExchange, phase: Phase, context: SlotContext) -> FilledExchange {
        if !exchange.isUserTurn {
            return exchange.withScaffolding(type: .intentBadge)
        }

        let tag = (exchange.eventTag ?? "").uppercased()
        let lower = exchange.text.lowercased()
        let rwy = context.selectedRunway.designator

        let primaryIntent: String
        let constraint: String?
        let hint: String?

        if tag.contains("CONDITIONAL") || lower.contains("behind") {
            primaryIntent = "Masuk dan tunggu di Runway \(rwy) di belakang pesawat yang sedang mendarat."
            constraint = "Wajib sebut kata 'BEHIND' di awal dan akhir readback."
            hint = "Doc 9432 §4.5.7: Izin bersyarat line-up behind wajib mengulang kondisi dua kali."
        } else if tag.contains("BACKTRACK") {
            primaryIntent = "Lakukan backtrack 180° di Runway \(rwy) dan line up, lapor siap lepas landas."
            constraint = "Sebutkan kata BACKTRACK dan nomor runway."
            hint = "Doc 9432 §4.4.2: Backtrack digunakan saat landasan tidak memiliki paralel taxiway."
        } else if tag.contains("WAKE") || lower.contains("wake turbulence") {
            primaryIntent = "Tahan posisi di holding point selama 2 menit menunggu pusaran wake turbulence reda."
            constraint = "Acknowledge jeda waktu 2 menit dan sebutkan callsign."
            hint = "Doc 4444 §5.8: Separasi wake turbulence di belakang pesawat jet berat adalah 2 menit."
        } else if tag.contains("IMMEDIATE") || tag.contains("TAKE-OFF") {
            primaryIntent = "Lepas landas segera tanpa jeda di landasan pacu aktif."
            constraint = "Langsung laksanakan take-off roll cepat."
            hint = "Doc 9432 §4.5.5: Immediate departure untuk menjaga separasi traffic final."
        } else if tag.contains("HOLDING") || tag.contains("EAT") {
            primaryIntent = "Masuk holding pattern dan catat waktu perkiraan pendekatan (EAT)."
            constraint = "Readback fix holding, altitude, dan waktu EAT."
            hint = "Doc 4444 §5.5: Expected Approach Time wajib dicatat untuk antisipasi radio failure."
        } else if tag.contains("ORBIT") || tag.contains("DELAYING") {
            primaryIntent = "Lakukan manuver orbit 360° ke kanan untuk penyesuaian separasi radar."
            constraint = "Readback arah belokan orbit 360° kanan."
            hint = "Doc 9432 §4.6.5: Manuver orbit 360° digunakan ATC untuk meregangkan antrean radar."
        } else if tag.contains("FLAP") {
            primaryIntent = "Deklarasikan PAN PAN akibat flap macet dan minta straight-in approach laju 160 knot."
            constraint = "Ucapkan 'PAN PAN' 3 pasang kata dan sebutkan kecepatan 160 knots."
            hint = "Doc 9432 Ch.9: Flap asymmetry memerlukan penambahan kecepatan pendekatan pendaratan."
        } else if tag.contains("CONTINUE APPROACH") {
            primaryIntent = "Lanjutkan approach dan bersiap batal mendarat jika runway belum steril."
            constraint = "Readback 'Continue approach' tanpa salah sebut nomor runway."
            hint = "Doc 9432 §4.7.1: Continue approach bukan izin mendarat (belum CLEARED TO LAND)."
        } else {
            primaryIntent = exchange.objective ?? "Readback instruksi ATC secara presisi sesuai urutan baku ICAO."
            constraint = "Urutan slot: Kata Tindakan + Ketinggian / Runway + Callsign."
            hint = "Doc 9432 §2.8.3: Callsign diletakkan di akhir readback pilot."
        }

        let payload = IntentBadgePayload(
            primaryIntent: primaryIntent,
            criticalConstraint: constraint,
            hint: hint,
            expectedSpeech: exchange.text,
            timeoutSeconds: 5.0
        )
        return exchange.withScaffolding(type: .intentBadge, intent: payload)
    }

    private static func enrichLevel4(
        exchange: FilledExchange,
        phase: Phase,
        context: SlotContext,
        seed: Int,
        contingencies: [InjectedContingency]
    ) -> FilledExchange {
        let tag = (exchange.eventTag ?? "").uppercased()
        let lower = exchange.text.lowercased()

        let alt: Int
        let spd: Int
        switch phase {
        case .preDeparture: alt = 100; spd = 0
        case .departure: alt = 1500; spd = tag.contains("RTO") ? 110 : 160
        case .enRoute: alt = 35000; spd = 450
        case .arrival: alt = 14000; spd = 250
        case .approach: alt = 3000; spd = 160
        case .landing: alt = 50; spd = 30
        }

        let fix = context.currentPosition.isEmpty ? context.airport.icao : context.currentPosition
        let stationName = context.unitTower?.callsign ?? "\(context.airport.name) Tower"
        let hud = AvionicsHUDPayload(
            headingDeg: context.heading,
            altitudeFt: alt,
            airspeedKt: spd,
            squawkCode: context.squawk,
            comm1Freq: "118.200",
            comm1Station: stationName,
            waypointOrFix: fix,
            navAdvisory: "ILS RWY \(context.arrRunway) ARMED",
            timeoutSeconds: 3.0
        )

        var bait: SelectiveListeningBaitPayload? = nil
        if tag.contains("CALLSIGN CONFUSION") || lower.contains("lion seven one two") {
            let baitCallsign = CallsignGenerator.generateBait(playerCallsign: context.callsign, seed: seed)
            bait = SelectiveListeningBaitPayload(
                isBaitTurn: true,
                targetCallsign: baitCallsign,
                playerCallsign: context.callsign,
                expectedAction: "SILENCE_DO_NOT_TRANSMIT",
                timeoutSeconds: 4.0,
                autoBotReply: "Line up and wait runway one zero, \(baitCallsign)."
            )
        }

        return exchange.withScaffolding(type: .cockpitHUDStrip, hud: hud, bait: bait)
    }

    private static func enrichLevel5(
        exchange: FilledExchange,
        phase: Phase,
        context: SlotContext,
        seed: Int,
        contingencies: [InjectedContingency]
    ) -> FilledExchange {
        let tag = (exchange.eventTag ?? "").uppercased()
        let lower = exchange.text.lowercased()

        let alt: Int
        let spd: Int
        switch phase {
        case .preDeparture: alt = 5435; spd = 0
        case .departure: alt = 6000; spd = 140
        case .enRoute: alt = 18000; spd = 320
        case .arrival: alt = 12000; spd = 210
        case .approach: alt = 7000; spd = 130
        case .landing: alt = 5435; spd = 20
        }

        let stationName = context.unitTower?.callsign ?? "\(context.airport.name) Tower"
        let hud = AvionicsHUDPayload(
            headingDeg: context.heading,
            altitudeFt: alt,
            airspeedKt: spd,
            squawkCode: context.squawk,
            comm1Freq: "122.200",
            comm1Station: stationName,
            waypointOrFix: context.airport.icao,
            navAdvisory: "TERRAIN WARNING SYSTEM ACTIVE",
            timeoutSeconds: 3.0
        )

        let partyline = exchange.partylinePayload ?? PartylineChatterPayload(
            isActive: true,
            audioTrackName: "chatter_loop_papua_vhf",
            baseVolume: 0.25,
            duckingVolume: 0.10,
            isDucking: exchange.isUserTurn
        )

        var hazard: HazardousInstructionPayload? = nil
        if tag.contains("TERRAIN") || tag.contains("GPWS") || lower.contains("unable heading") || lower.contains("malabar") {
            hazard = HazardousInstructionPayload(
                isHazardous: true,
                hazardType: "TERRAIN_CFIT_MOUNTAIN",
                hazardDescription: "Instruksi radar ATC keliru mengarah ke Gunung Malabar (elevasi > 6.000 ft). Dilarang patuh!",
                expectedPilotReaction: "REJECT_UNABLE",
                rejectionPhraseology: "UNABLE heading two one zero and descend due terrain, climbing Flight Level zero nine zero, \(context.callsign)!",
                timeoutSeconds: 3.0
            )
        } else if tag.contains("WIND SHEAR") || lower.contains("wind shear escape") {
            hazard = HazardousInstructionPayload(
                isHazardous: true,
                hazardType: "SEVERE_WIND_SHEAR_MICROBURST",
                hazardDescription: "Microburst angin jatuh mendadak di bibir tebing Toraja (1 NM). Lolos seketika!",
                expectedPilotReaction: "WIND_SHEAR_ESCAPE",
                rejectionPhraseology: "\(context.callsign), WIND SHEAR ESCAPE, climbing straight ahead to six thousand feet!",
                timeoutSeconds: 3.0
            )
        } else if tag.contains("GO-AROUND") || lower.contains("going around") || lower.contains("vehicle on runway") {
            hazard = HazardousInstructionPayload(
                isHazardous: true,
                hazardType: "RUNWAY_OBSTRUCTION",
                hazardDescription: "Tampak kendaraan teknisi melintas di runway Wamena. Batal mendarat mandiri!",
                expectedPilotReaction: "PILOT_INITIATED_GO_AROUND",
                rejectionPhraseology: "GOING AROUND, vehicle on runway, \(context.callsign)!",
                timeoutSeconds: 3.0
            )
        }

        return exchange.withScaffolding(type: .partylineHUD, hud: hud, partyline: partyline, hazard: hazard)
    }

    private func buildMissionSlotContext(
        missionContext: FlightMissionContext,
        phase: Phase,
        depHoldingPoint: String,
        arrExitTaxiway: String,
        exitDirection: String = "left",
        customDepRunway: Runway? = nil,
        customWeather: AlignedWeather? = nil,
        isEarlyTerminatedOnGround: Bool = false
    ) -> SlotContext {
        let isArrivalOrLater = (!isEarlyTerminatedOnGround) && (phase == .arrival || phase == .approach || phase == .landing)
        let activeAirport = isArrivalOrLater ? missionContext.destinationAirport : missionContext.originAirport
        let activeRunway = isArrivalOrLater ? missionContext.arrRunway : (customDepRunway ?? missionContext.depRunway)
        let activeWeather = isArrivalOrLater ? missionContext.arrWeather : (customWeather ?? missionContext.depWeather)
        let activeAtis = isArrivalOrLater ? missionContext.arrAtisId : missionContext.depAtisId

        let resolvedCenter = activeAirport.units.center ?? Self.resolveAreaControl(
            originICAO: missionContext.originAirport.icao,
            destinationICAO: missionContext.destinationAirport.icao
        )

        let waypoints: (curr: String, next: String)
        switch missionContext.originAirport.icao {
        case "WADY": waypoints = ("Point Alfa", "Point Charlie")
        case "WICB": waypoints = ("CURUG", "Area Alfa")
        case "WART": waypoints = ("SUP VOR", "Madura South")
        case "WADD": waypoints = ("POSOP", "BLI VOR")
        case "WARR": waypoints = ("SURBA", "GANDI")
        case "WAHI": waypoints = ("JOG VOR", "PRAMB")
        case "WIII": waypoints = ("BUNTA", "DOLTA")
        default: waypoints = ("BUNTA", "DOLTA")
        }

        let resolvedDepRadar = activeAirport.units.departure
            ?? activeAirport.units.approach
            ?? resolvedCenter

        return SlotContext(
            airport: activeAirport,
            selectedRunway: activeRunway,
            holdingPoint: depHoldingPoint,
            taxiRoute: missionContext.taxiOutRoute,
            callsign: missionContext.callsign,
            weather: activeWeather,
            atisId: activeAtis,
            unitGround: activeAirport.units.ground,
            unitTower: activeAirport.units.tower,
            unitApproach: activeAirport.units.approach,
            unitDeparture: resolvedDepRadar,
            unitDelivery: activeAirport.units.delivery,
            unitControl: resolvedCenter,
            stand: missionContext.standOrigin,
            aircraftType: missionContext.aircraftType,
            pob: missionContext.profile == .vfrLocal ? 2 : 168,
            airportName: activeAirport.name,
            destinationName: missionContext.destinationAirport.name,
            sidProcedure: missionContext.sidProcedure,
            starProcedure: missionContext.starProcedure,
            squawk: missionContext.squawkCode,
            depFreq: SpokenFormFormatter.frequency(resolvedDepRadar.frequency),
            approachFreq: SpokenFormFormatter.frequency(missionContext.destinationAirport.units.approach?.frequency ?? "119.500"),
            controlFreq: SpokenFormFormatter.frequency(resolvedCenter.frequency),
            arrRunway: SpokenFormFormatter.runway(missionContext.arrRunway.designator),
            arrAtisId: missionContext.arrAtisId,
            visibility: "eight kilometres",
            cloudCondition: "scattered one thousand eight hundred feet",
            temperature: "three zero",
            dewPoint: "two five",
            turnDirection: "left",
            heading: missionContext.departureHeading,
            initialAlt: missionContext.initialAlt,
            levelStatus: "maintaining",
            currentLevel: missionContext.cruisingLevel,
            routeContext: "flight planned route via airway",
            currentPosition: waypoints.curr,
            timeUTC: "zero one two zero",
            nextPosition: waypoints.next,
            nextETA: "zero one four five",
            requestedLevel: "flight level three seven zero",
            requestedDeviationDistance: missionContext.weatherDeviationDistance ?? "two zero",
            requestedDeviationDirection: missionContext.weatherDeviationDirection ?? "right",
            approvedDeviationDistance: missionContext.weatherDeviationDistance ?? "two zero",
            approvedDeviationDirection: missionContext.weatherDeviationDirection ?? "right",
            descentLevel: "altitude five thousand feet",
            holdingFix: missionContext.destinationAirport.procedures.holdings.first?.fix ?? "BLI VOR",
            holdingLevel: "seven thousand feet",
            inboundTrack: "zero niner zero",
            eat: "zero three zero five",
            goAroundReason: "traffic still on runway",
            missedAlt: "three thousand feet",
            missedInstruction: "climb straight ahead and contact Approach",
            exitDirection: exitDirection,
            exitTaxiway: arrExitTaxiway,
            destinationStand: missionContext.standDestination,
            taxiInRoute: missionContext.taxiInRoute
        )
    }

    // MARK: - Dynamic Exit Taxiway & Direction Resolution
    private func resolveExitTaxiwayAndDirection(
        airport: Airport,
        runwayDesignator: String,
        seed: Int
    ) -> (taxiway: String, direction: String) {
        let cleanRwy = runwayDesignator.trimmingCharacters(in: .whitespaces)

        switch airport.icao {
        case "WADD":
            if cleanRwy.contains("09") {
                let options = ["Charlie One", "Charlie Three", "Bravo One", "Echo"]
                return (options[abs(seed) % options.count], "left")
            } else {
                let options = ["Charlie Two", "Delta", "Foxtrot"]
                return (options[abs(seed) % options.count], "right")
            }
        case "WARR":
            if cleanRwy.contains("10") {
                let options = ["November Three", "November One", "Bravo"]
                return (options[abs(seed) % options.count], "left")
            } else {
                let options = ["November Four", "November Six"]
                return (options[abs(seed) % options.count], "right")
            }
        case "WAHI":
            if cleanRwy.contains("11") {
                let options = ["Bravo", "Charlie"]
                return (options[abs(seed) % options.count], "left")
            } else {
                let options = ["Delta", "Echo"]
                return (options[abs(seed) % options.count], "right")
            }
        case "WIII":
            if cleanRwy.contains("25R") {
                let options = ["November Four", "November Five", "November Six"]
                return (options[abs(seed) % options.count], "left")
            } else if cleanRwy.contains("07L") {
                let options = ["November Six", "November Seven"]
                return (options[abs(seed) % options.count], "right")
            } else if cleanRwy.contains("25L") {
                let options = ["Sierra Four", "Sierra Five"]
                return (options[abs(seed) % options.count], "right")
            } else {
                let options = ["Sierra Six", "Sierra Seven"]
                return (options[abs(seed) % options.count], "left")
            }
        case "WICB":
            if cleanRwy.contains("12") {
                let options = ["Golf", "Hotel"]
                return (options[abs(seed) % options.count], "left")
            } else {
                let options = ["Bravo", "Charlie"]
                return (options[abs(seed) % options.count], "right")
            }
        case "WART":
            return ("Bravo", "left")
        default:
            if cleanRwy.contains("08") {
                let options = ["Bravo", "Alfa Two"]
                return (options[abs(seed) % options.count], "left")
            } else {
                let options = ["Alfa", "Alfa One"]
                return (options[abs(seed) % options.count], "right")
            }
        }
    }

    // MARK: - Multi-Contingency Resolution Engine (Fair Pedagogical Distribution & Exam Engine)
    private func resolveMultipleContingencies(
        selectedOptions: Set<ContingencySelection>,
        level: CurriculumLevel,
        mode: SimulationMode = .mission,
        seed: Int
    ) -> [InjectedContingency] {
        var optionsToEvaluate: [ContingencySelection] = []

        if selectedOptions.contains(.auto) {
            optionsToEvaluate = level.allowedScenarios
        } else if selectedOptions.contains(.routineOnly) || selectedOptions.isEmpty {
            return []
        } else {
            optionsToEvaluate = level.allowedScenarios.filter { selectedOptions.contains($0) }
        }

        if optionsToEvaluate.isEmpty {
            return []
        }

        // CASE A: User manually picked a specific subset in the picker sheet (Targeted Drill Mode)
        let isUserCustomSubset = selectedOptions.count < level.allowedScenarios.count

        if isUserCustomSubset {
            // When the user deliberately selects specific scenarios, trigger all non-conflicting ones!
            return sanitizeRolledContingencies(optionsToEvaluate)
        }

        // CASE B: EXAM MODE (Ujian Kenaikan Pangkat — MAPPING_SCAFFOLDING.pdf)
        // 100% Non-Normal on Levels 2 to 5. Level 1 is 100% Normal.
        if mode == .exam {
            var examRolled: [ContingencySelection] = []
            switch level {
            case .level1:
                return [] // Level 1 Exam: 100% Rutin VFR Sirkuit Lokal

            case .level2:
                // Level 2 Exam: 100% Anomali Tunggal (4 x 25% Seimbang modulo 4)
                let choice = abs(seed) % 4
                switch choice {
                case 0: examRolled.append(.pushbackDelay)
                case 1: examRolled.append(.stopPushback)
                case 2: examRolled.append(.unableAltitude)
                default: examRolled.append(.holdShortExact)
                }

            case .level3:
                // Level 3 Exam: 100% Kompaun 2-Fase (4 Dep x 4 Arr = 16 Variasi Pasangan Acak Anti-Patah)
                let depPool: [ContingencySelection] = [.runwayBacktrack, .wakeTurbulenceLineUp, .conditionalLineUp, .immediateTakeoffOrVacate]
                let arrPool: [ContingencySelection] = [.holdingPatternEAT, .delayingVectorOrbit, .continueApproachShortFinal, .flapFailure]
                let depChoice = depPool[abs(seed) % depPool.count]
                let arrChoice = arrPool[abs(seed / 4) % arrPool.count]
                examRolled.append(depChoice)
                examRolled.append(arrChoice)

            case .level4:
                // Level 4 Exam: 2-Stage Captaincy Checkride (Ground CTOT/Crossing/Confusion + Upper/Terminal)
                // Exam 4A (Spot RTO) + Exam 4B (3 Darat x 4 Udara = 12 Variasi Gate-to-Gate)
                let isSpotRTO = (abs(seed) % 5 == 0)
                if isSpotRTO {
                    examRolled.append(.abortTakeoff)
                } else {
                    let groundPool: [ContingencySelection] = [.ctotSlotManagement, .holdShortCrossing, .callsignConfusion]
                    let upperPool: [ContingencySelection] = [.slopOceanic, .tcasRA, .passengerMedicalEmergency, .blownTireLanding]
                    let gChoice = groundPool[abs(seed) % groundPool.count]
                    let uChoice = upperPool[abs(seed / 3) % upperPool.count]
                    examRolled.append(gChoice)
                    examRolled.append(uChoice)
                }

            case .level5:
                // Level 5 Exam: 100% Kedaruratan Mutlak 3 Pola Trajektori (11 Variasi)
                // 1 Abort + 4 Diversion (2x2) + 6 Recovery (3x2) = 11 Variasi
                let trajectory = abs(seed) % 3
                switch trajectory {
                case 0:
                    // Pola 1: Immediate Abort (1 variasi: EFATO Air-Turn-Back + Excursion ARFF)
                    examRolled.append(.efato)
                    examRolled.append(.runwayExcursionARFF)
                case 1:
                    // Pola 2: In-Flight Diversion (4 variasi: 2 primary x 2 secondary)
                    let divChoices: [ContingencySelection] = [.emergencyDescentDecompression, .fuelEmergencyMayday]
                    let primary = divChoices[abs(seed / 3) % divChoices.count]
                    examRolled.append(primary)
                    let secondary = (abs(seed / 5) % 2 == 0) ? ContingencySelection.volcanicAshAvoidance : ContingencySelection.impositionOfSilence
                    examRolled.append(secondary)
                default:
                    // Pola 3: Tactical Recovery (6 variasi: 3 primary x 2 tactical complications)
                    let recChoices: [ContingencySelection] = [.gpwsTerrainAvoidance, .windShearMicroburst, .pilotInitiatedGoAround]
                    let primary = recChoices[abs(seed / 3) % recChoices.count]
                    examRolled.append(primary)
                    if (abs(seed / 7) % 2 == 0) {
                        examRolled.append(.impositionOfSilence)
                    }
                }
            }
            return sanitizeRolledContingencies(examRolled)
        }

        // CASE C: DEFAULT MISSION DISTRIBUTION
        // LEVEL 1: Ab-Initio Cadet (100% Prosedur Rutin Murni, zero anomalies)
        if level == .level1 {
            return []
        }

        var rolled: [ContingencySelection] = []

        switch level {
        case .level1:
            return []

        case .level2:
            // LEVEL 2: 25% each for the 4 light friction scenarios
            let dice = abs(seed) % 4
            switch dice {
            case 0: rolled.append(.pushbackDelay)
            case 1: rolled.append(.stopPushback)
            case 2: rolled.append(.unableAltitude)
            default: rolled.append(.holdShortExact)
            }

        case .level3:
            // LEVEL 3: Tactical Single vs Compound
            let primaryIdx = (abs(seed / 7) + abs(seed % 17)) % optionsToEvaluate.count
            let primary = optionsToEvaluate[primaryIdx]
            rolled.append(primary)

            if (abs(seed / 3) % 5 < 2) {
                let otherPhase = optionsToEvaluate.filter { $0.triggerPhase != primary.triggerPhase && $0 != primary }
                if !otherPhase.isEmpty {
                    let secondary = otherPhase[abs(seed &* 31 + 13) % otherPhase.count]
                    rolled.append(secondary)
                }
            }

        case .level4:
            // LEVEL 4: Multi-Runway Hub Compound
            let primaryIdx = (abs(seed / 11) + abs(seed % 23)) % optionsToEvaluate.count
            let primary = optionsToEvaluate[primaryIdx]
            rolled.append(primary)

            let otherPhase = optionsToEvaluate.filter { $0.triggerPhase != primary.triggerPhase && $0 != primary }
            if !otherPhase.isEmpty {
                let secondary = otherPhase[abs(seed &* 47 + 7) % otherPhase.count]
                rolled.append(secondary)
                let thirdPhase = otherPhase.filter { $0.triggerPhase != secondary.triggerPhase && $0 != secondary }
                if !thirdPhase.isEmpty && (abs(seed / 5) % 2 == 0) {
                    rolled.append(thirdPhase[abs(seed &* 71 + 19) % thirdPhase.count])
                }
            }

        case .level5:
            // LEVEL 5: Extreme Terrain Crisis
            let primaryIdx = (abs(seed / 13) + abs(seed % 31)) % optionsToEvaluate.count
            let primary = optionsToEvaluate[primaryIdx]
            rolled.append(primary)

            let otherPhase = optionsToEvaluate.filter { $0.triggerPhase != primary.triggerPhase && $0 != primary }
            if !otherPhase.isEmpty && (abs(seed / 2) % 2 == 0) {
                rolled.append(otherPhase[abs(seed &* 59 + 29) % otherPhase.count])
            }
        }

        if rolled.isEmpty {
            return []
        }

        return sanitizeRolledContingencies(rolled)
    }

    private func sanitizeRolledContingencies(_ rawRolled: [ContingencySelection]) -> [InjectedContingency] {
        // Deduplicate so the same contingency is never injected twice in one mission
        var uniqueOrdered: [ContingencySelection] = []
        for opt in rawRolled {
            if !uniqueOrdered.contains(opt) {
                uniqueOrdered.append(opt)
            }
        }
        var rolled = uniqueOrdered

        // 1. Take-off Early Termination Mutual Exclusion:
        let abortOptions: [ContingencySelection] = [.birdStrikeAbort, .abortTakeoff, .efato]
        let rolledAborts = rolled.filter { abortOptions.contains($0) }
        if !rolledAborts.isEmpty {
            let prioritizedAbort = rolledAborts.sorted { a, b in
                let rank: [ContingencySelection: Int] = [.birdStrikeAbort: 3, .abortTakeoff: 2, .efato: 1]
                return (rank[a] ?? 0) > (rank[b] ?? 0)
            }.first!
            // When an abort on ground occurs, flight NEVER proceeds en-route or to destination!
            var abortResult = [resolveSingleContingency(option: prioritizedAbort)].compactMap { $0 }
            if rolled.contains(.runwayExcursionARFF) {
                if let ex = resolveSingleContingency(option: .runwayExcursionARFF) {
                    abortResult.append(ex)
                }
            }
            return abortResult
        }

        // 2. Bird Hazard Mutual Exclusion:
        if rolled.contains(.birdStrikeAbort) {
            rolled.removeAll(where: { $0 == .birdHazardHold })
        }

        // 3. Pre-Lineup Hazard Mutual Exclusion:
        if rolled.contains(.emergencyLandingHold) && rolled.contains(.birdHazardHold) {
            rolled.removeAll(where: { $0 == .birdHazardHold })
        }

        // 4. Line-Up Delay Mutual Exclusion:
        if rolled.contains(.cancelLineUp) && rolled.contains(.wakeTurbulenceLineUp) {
            rolled.removeAll(where: { $0 == .wakeTurbulenceLineUp })
        }

        // 5. Critical In-Flight Emergency Mutual Exclusion (Realistic CRM & LOFT Event Sets):
        // A single flight MUST NOT experience multiple disconnected catastrophic crises
        let majorCrises: [ContingencySelection] = [
            .midAirEngineOut,
            .emergencyDescentDecompression,
            .passengerMedicalEmergency,
            .fuelEmergencyMayday,
            .volcanicAshAvoidance,
            .hijack7500,
            .militaryInterception,
            .runwayExcursionARFF,
            .flapFailure,
            .unsafeGear,
            .unclearedGoAround
        ]
        let rolledCrises = rolled.filter { majorCrises.contains($0) }
        if rolledCrises.count > 1 {
            let prioritized = rolledCrises.sorted { (a, b) -> Bool in
                let sevRank: [EventSeverity: Int] = [.distress: 3, .urgency: 2, .abnormal: 1, .normal: 0]
                return (sevRank[a.defaultSeverity] ?? 0) > (sevRank[b.defaultSeverity] ?? 0)
            }.first!
            rolled.removeAll(where: { majorCrises.contains($0) && $0 != prioritized })
        }

        // 6. Approach / Landing Conflict Prevention
        if rolled.contains(.lowPassInspection) {
            rolled.removeAll(where: { $0 == .continueApproachShortFinal || $0 == .flapFailure })
        }
        if rolled.contains(.pilotInitiatedGoAround) {
            rolled.removeAll(where: { $0 == .continueApproachShortFinal || $0 == .runwayExcursionARFF })
        }

        var result: [InjectedContingency] = []
        for opt in rolled {
            if let cont = resolveSingleContingency(option: opt) {
                result.append(cont)
            }
        }
        return result.sorted { $0.triggerPhase.rawValue < $1.triggerPhase.rawValue }
    }

    private func resolveSelectedContingency(
        option: ContingencySelection,
        level: CurriculumLevel,
        seed: Int,
        mode: SimulationMode
    ) -> InjectedContingency? {
        let list = resolveMultipleContingencies(selectedOptions: [option], level: level, mode: mode, seed: seed)
        return list.first
    }

    private func resolveSingleContingency(option: ContingencySelection) -> InjectedContingency? {
        switch option {
        case .routineOnly, .auto:
            return nil

        case .birdHazardHold:
            return InjectedContingency(
                title: "Bird Hazard on Runway (Dispersal Hold)",
                severity: .abnormal,
                triggerPhase: .departure,
                summary: "Menara ATC mendeteksi kawanan burung besar di atas landasan pacu. Pesawat diinstruksikan menahan di holding point sementara armada pengusir burung bandara beroperasi.",
                downstreamEffect: "Izin lepas landas ditunda sesaat. Setelah pemeriksaan landasan bersih, ATC menerbitkan izin take-off normal."
            )

        case .birdStrikeAbort:
            return InjectedContingency(
                title: "Bird Strike on Take-off Roll (Abort)",
                severity: .distress,
                triggerPhase: .departure,
                summary: "Saat melaju di landasan pada kecepatan 80 knot sebelum V1, pesawat menabrak kawanan burung pada mesin. Pilot membatalkan take-off, ATC menerbitkan STOP IMMEDIATELY.",
                downstreamEffect: "Pesawat batal terbang. Seluruh fase berikutnya dialihkan ke penanganan darurat darat: inspeksi armada ARFF, evaluasi rem, pengosongan landasan, dan taxi ke apron pemeliharaan."
            )

        case .emergencyLandingHold:
            return InjectedContingency(
                title: "Inbound Emergency Priority (Hold Short / Cancel TO)",
                severity: .urgency,
                triggerPhase: .departure,
                summary: "Pesawat di holding point atau line up and wait harus menunda keberangkatan karena ada pesawat komersial lain di short final mendeklarasikan MAYDAY pendaratan darurat.",
                downstreamEffect: "Izin masuk landasan atau take-off clearance dibatalkan. Pesawat menahan di posisi aman hingga pesawat darurat mendarat selamat."
            )

        case .runwayChange:
            return InjectedContingency(
                title: "Runway Change Before Departure (Wind Shift 180°)",
                severity: .abnormal,
                triggerPhase: .preDeparture,
                summary: "Saat taxi menuju holding point, arah angin berbalik 180 derajat. ATC membatalkan izin taxi awal dan mengalihkan runway aktif ke reciprocal.",
                downstreamEffect: "Holding point dan runway keberangkatan diubah. Seluruh perizinan take-off menyesuaikan nomor runway baru."
            )

        case .forgottenLandingClearancePrompt:
            return InjectedContingency(
                title: "Late Landing Clearance (Short Final Prompt)",
                severity: .abnormal,
                triggerPhase: .approach,
                summary: "Pada short final 500 ft AGL, ATC belum memberikan izin mendarat (terdistraksi/koordinasi traffic). Pilot secara proaktif memanggil konfirmasi izin mendarat. ATC menyadari keterlambatan dan menerbitkan clearance tepat sebelum decision height.",
                downstreamEffect: "ATC meminta maaf dan segera menerbitkan 'cleared to land' dengan info angin terkini. Pilot membaca kembali izin mendarat dan melanjutkan touch-and-go / pendaratan."
            )

        case .abortTakeoff:
            return InjectedContingency(
                title: "Abort Take-Off (Ground Roll Stop)",
                severity: .abnormal,
                triggerPhase: .departure,
                summary: "Saat pesawat melaju di landasan pada take-off roll, terdeteksi runway incursion. ATC menerbitkan instruksi 'STOP IMMEDIATELY'. Pilot membatalkan take-off sebelum V1 dan berhenti di landasan.",
                downstreamEffect: "Pesawat batal terbang. Fase En-Route, Arrival, dan Approach dibatalkan. Pesawat backtrack dan vacate via exit taxiway menuju maintenance stand untuk inspeksi rem."
            )

        case .efato:
            return InjectedContingency(
                title: "EFATO (Engine Failure After Takeoff 500ft)",
                severity: .distress,
                triggerPhase: .departure,
                summary: "Pada ketinggian 500 ft AGL sesaat setelah lepas landas, mesin mati mendadak. Pilot mendeklarasikan MAYDAY dan mendarat darurat lurus di sisa landasan pacu.",
                downstreamEffect: "Fase En-Route dan Arrival dibatalkan. Pesawat mendarat darurat langsung di landasan keberangkatan, armada pemadam ARFF siaga penuh."
            )

        case .cancelLineUp:
            return InjectedContingency(
                title: "Cancel Line-Up and Wait (Preceding Traffic Delay)",
                severity: .abnormal,
                triggerPhase: .departure,
                summary: "Pesawat diperintahkan line up, namun dibatalkan mendadak oleh ATC karena pesawat di depan mengalami keterlambatan lepas landas.",
                downstreamEffect: "Pilot membatalkan masuk landasan dan menahan di holding point short of runway hingga separasi terpenuhi."
            )

        case .lowPassInspection:
            return InjectedContingency(
                title: "Low Pass Inspection (Kencana 191 Style)",
                severity: .abnormal,
                triggerPhase: .approach,
                summary: "Pesawat meminta izin terbang rendah di atas landasan pacu (Low Pass) untuk kalibrasi instrumen atau inspeksi visual roda pendaratan oleh personil menara ATC.",
                downstreamEffect: "ATC mengizinkan low pass tidak di bawah 200 ft. Setelah lewat depan menara, ATC mengonfirmasi roda terkunci dan memandu pesawat bergabung kembali ke sirkuit untuk mendarat."
            )

        case .weatherDeviation:
            return InjectedContingency(
                title: "Weather Deviation En-Route (CB Avoidance)",
                severity: .abnormal,
                triggerPhase: .enRoute,
                summary: "Prakiraan radar cuaca mendeteksi sel awan Cumulonimbus (CB) aktif di koridor rute. Pilot meminta deviasi 15 NM ke kanan dari jalur airway.",
                downstreamEffect: "ATC menyetujui deviasi dan menginstruksikan pilot melapor saat dapat kembali ke navigasi mandiri direct fix."
            )

        case .flapFailure:
            return InjectedContingency(
                title: "Flap System Failure (Approach DPS PAN PAN)",
                severity: .urgency,
                triggerPhase: .approach,
                summary: "Sistem flap gagal berekspansi saat mendekati Bali DPS. Pilot mendeklarasikan PAN PAN karena butuh kecepatan pendaratan tinggi 160 knot tanpa flap.",
                downstreamEffect: "ATC memberikan prioritas straight-in approach Runway 09 tanpa holding dan menyiagakan tim keselamatan."
            )

        case .unsafeGear:
            return InjectedContingency(
                title: "Unsafe Landing Gear Indication (VOR Holding)",
                severity: .urgency,
                triggerPhase: .approach,
                summary: "Indikator roda pendaratan tidak terkunci hijau saat final approach. Pilot melakukan go-around dan meminta holding pattern di atas VOR untuk troubleshooting checklist roda manual.",
                downstreamEffect: "Pesawat masuk holding pattern untuk checklist darurat. Setelah tiga lampu hijau terkonfirmasi, ATC memandu radar vectors kedua untuk pendaratan."
            )

        case .unclearedGoAround:
            return InjectedContingency(
                title: "Uncleared Missed Approach (No Clearance Received)",
                severity: .urgency,
                triggerPhase: .approach,
                summary: "Pesawat menembus batas decision height 200 ft tanpa menerima 'Cleared to Land' (runway terhalang / frekuensi tertimpa). Pilot wajib membatalkan pendaratan secara mandiri (Go-Around) demi keselamatan.",
                downstreamEffect: "Pesawat climb missed approach procedure. ATC Approach mengambil alih pemanduan vektor radar kedua menuju final ILS untuk pendaratan kedua."
            )

        case .midAirEngineOut:
            return InjectedContingency(
                title: "Mid-Air Engine Failure (Diversion ASSIST)",
                severity: .distress,
                triggerPhase: .enRoute,
                summary: "Di tengah rute jelajah en-route, mesin nomor 1 mengalami kegagalan mekanis. Pilot mendeklarasikan MAYDAY dan meminta rekomendasi bandara terdekat. ATC menerapkan protokol ASSIST (vektor radar ke bandara terdekat, QNH, siagakan ARFF).",
                downstreamEffect: "Pesawat dialihkan (divert) ke bandara terdekat viable. Rute STAR reguler dibatalkan dan digantikan dengan radar vectors prioritas langsung menuju final ILS."
            )

        case .holdShortCrossing:
            return InjectedContingency(
                title: "Runway Incursion Mitigation (Hold Short Crossing)",
                severity: .abnormal,
                triggerPhase: .preDeparture,
                summary: "Rute taxi menuju holding point melintasi landasan aktif saat ada pesawat mendarat. ATC menginstruksikan hold short crossing.",
                downstreamEffect: "Pilot wajib melakukan readback hold short di persimpangan landasan aktif sebelum diberikan otorisasi crossing."
            )

        case .engineFailureFinal:
            return InjectedContingency(
                title: "Engine Failure on Final (MAYDAY 4 DME)",
                severity: .distress,
                triggerPhase: .approach,
                summary: "Pada 4 DME final, mesin nomor 1 mengalami kegagalan mekanis. Pilot mendeklarasikan MAYDAY dan melanjutkan pendaratan darurat.",
                downstreamEffect: "ATC memberikan prioritas izin mendarat darurat langsung dan menyiagakan armada ARFF di runway."
            )

        case .tcasRA:
            return InjectedContingency(
                title: "TCAS Resolution Advisory (TCAS RA)",
                severity: .distress,
                triggerPhase: .enRoute,
                summary: "Instrumen kokpit TCAS membunyikan peringatan tabrakan 'CLIMB, CLIMB'. Pilot melakukan manuver menghindar vertikal darurat mengesampingkan ATC sesaat, lalu melapor 'TCAS RA'.",
                downstreamEffect: "Setelah 'clear of conflict', pilot meminta kembali ke cruising level dan melanjutkan navigasi normal."
            )

        case .rnavFailure:
            return InjectedContingency(
                title: "RNAV / GPS Failure (Radar Vectors)",
                severity: .abnormal,
                triggerPhase: .arrival,
                summary: "Sistem satelit GNSS kokpit mengalami degradasi saat kedatangan TMA. Pilot melapor 'Unable RNAV arrival'.",
                downstreamEffect: "Prosedur kedatangan STAR satelit dibatalkan. ATC mengambil alih menggunakan vektor radar konvensional heading 250 menuju ILS."
            )

        case .parallelBreakout:
            return InjectedContingency(
                title: "Parallel Breakout (Simultaneous ILS Hazard)",
                severity: .distress,
                triggerPhase: .approach,
                summary: "Pesawat di landasan paralel memotong non-transgression zone (NTZ). ATC menerbitkan instruksi breakout darurat belok segera.",
                downstreamEffect: "Pilot langsung berbelok tajam heading 200 climb 4.000 ft menjauhi bahaya tabrakan di jalur pendekatan paralel."
            )

        case .visualOrbitSpacing:
            return InjectedContingency(
                title: "Visual Orbit for Spacing (360° Turn)",
                severity: .abnormal,
                triggerPhase: .approach,
                summary: "Pada sirkuit visual downwind, pesawat terlalu dekat dengan traffic di depan. Tower menginstruksikan manuver putaran 360 derajat (orbit) untuk menjaga separasi.",
                downstreamEffect: "Pilot melakukan orbit 360 derajat di posisi sebelum diizinkan belok ke base leg dan final approach."
            )

        case .extendDownwind:
            return InjectedContingency(
                title: "Extend Downwind (Traffic Spacing)",
                severity: .abnormal,
                triggerPhase: .approach,
                summary: "Landasan pacu masih terisi pesawat lain yang sedang lepas landas. ATC menginstruksikan pilot memperpanjang downwind leg sebelum dipanggil untuk belok base leg.",
                downstreamEffect: "Base turn ditunda hingga ATC memanggil 'turn base leg', pilot mempertahankan ketinggian sirkuit."
            )

        case .nordoBlindTransmission:
            return InjectedContingency(
                title: "Transmitting Blind (NORDO Receiver Fail)",
                severity: .urgency,
                triggerPhase: .enRoute,
                summary: "Radio penerima kokpit gagal menerima audio ATC. Pilot menerapkan prosedur resmi ICAO Bab 9.5: Squawk 7600 dan memancarkan laporan buta (transmitting blind) dua kali.",
                downstreamEffect: "ATC merespons via instruksi pengamatan radar (squawk ident / lampu) dan menyiapkan lampu suar hijau (green pyrotechnic light) dari menara."
            )

        case .wakeTurbulenceLineUp:
            return InjectedContingency(
                title: "Wake Turbulence Line-Up (2 Min Delay)",
                severity: .abnormal,
                triggerPhase: .departure,
                summary: "Pesawat bersiap lepas landas tepat di belakang pesawat berbadan besar (Heavy B777). ATC mewajibkan jeda waktu separasi turbulensi vorteks 2 menit sebelum take-off.",
                downstreamEffect: "Pesawat line up and wait di runway selama 2 menit penuh sebelum diizinkan take-off clearance."
            )

        case .immediateTakeoffOrVacate:
            return InjectedContingency(
                title: "Immediate Take-off or Vacate Runway",
                severity: .abnormal,
                triggerPhase: .departure,
                summary: "Pesawat berada di runway saat traffic lain mendekat pada 2 NM short final. ATC memberikan pilihan cepat: take off segera tanpa jeda atau kosongkan runway.",
                downstreamEffect: "Pilot memilih immediate take-off roll cepat untuk menjaga keselamatan arus pergerakan landasan."
            )

        case .radarAvoidingAction:
            return InjectedContingency(
                title: "Radar Avoiding Action (Near-Miss Turn)",
                severity: .urgency,
                triggerPhase: .enRoute,
                summary: "Radar mendeteksi pesawat tak teridentifikasi berlawanan arah pada jarak 2 NM. ATC menerbitkan instruksi manuver darurat belok segera (avoiding action).",
                downstreamEffect: "Pilot langsung berbelok tajam heading 270 menghindari tabrakan udara sebelum diizinkan kembali ke rute semula."
            )

        case .emergencyDescentDecompression:
            return InjectedContingency(
                title: "Emergency Descent (Cabin Decompression)",
                severity: .distress,
                triggerPhase: .enRoute,
                summary: "Kabin mengalami dekompresi mendadak di FL360. Pilot mendeklarasikan MAYDAY dan melakukan emergency descent menukik ke FL100. ATC mem-broadcast peringatan ke airway.",
                downstreamEffect: "Pesawat menukik turun ke FL100. ATC mengosongkan jalur penerbangan di bawahnya dan mengarahkan pengalihan darurat ke bandara terdekat."
            )

        case .impositionOfSilence:
            return InjectedContingency(
                title: "Imposition of Silence (MAYDAY Traffic)",
                severity: .urgency,
                triggerPhase: .approach,
                summary: "Frekuensi radio mengalami interferensi saat ada pesawat lain darurat. ATC membungkam seluruh stasiun dengan frasa resmi 'STOP TRANSMITTING, MAYDAY'.",
                downstreamEffect: "Seluruh pilot wajib menjaga keheningan frekuensi radio hingga ATC menyiarkan 'DISTRESS TRAFFIC ENDED'."
            )

        case .passengerMedicalEmergency:
            return InjectedContingency(
                title: "Medical Priority PAN PAN (Heart Attack)",
                severity: .urgency,
                triggerPhase: .arrival,
                summary: "Penumpang mengalami serangan jantung kritis di kabin. Pilot mendeklarasikan PAN PAN meminta prioritas straight-in approach dan armada medis di apron.",
                downstreamEffect: "Rute STAR dipersingkat menjadi direct final approach dengan prioritas pendaratan nomor satu dan ambulans siaga di stand."
            )

        case .lowVisibilityRVR:
            return InjectedContingency(
                title: "Low Visibility RVR Breakdown (Cat II ILS)",
                severity: .abnormal,
                triggerPhase: .approach,
                summary: "Hujan sangat lebat menurunkan jarak pandang landasan. ATC mentransmisikan tiga nilai RVR resmi (touchdown, midpoint, stop-end).",
                downstreamEffect: "Pilot mengonfirmasi kemampuan sistem instrumen Cat II/III dan melanjutkan pendekatan presisi ILS."
            )

        case .contaminatedRunwayBraking:
            return InjectedContingency(
                title: "Contaminated Runway & Braking Action Poor",
                severity: .abnormal,
                triggerPhase: .approach,
                summary: "Genangan air di landasan pacu menyebabkan risiko hydroplaning. ATC meneruskan laporan daya cengkeram rem buruk (braking action poor) dari pesawat sebelumnya.",
                downstreamEffect: "Pilot mempersiapkan pengereman thrust reverser maksimum dan mengantisipasi jarak henti lebih panjang."
            )

        // MARK: - LEVEL 2 NEW CASES
        case .pushbackDelay:
            return InjectedContingency(
                title: "Pushback Delay (Traffic Behind - Doc 9432 §4.3.1)",
                severity: .urgency,
                triggerPhase: .preDeparture,
                summary: "Penundaan pushback karena ada lalu lintas taxi pesawat lain yang sedang melintas tepat di belakang stand parkir.",
                downstreamEffect: "Pilot wajib menahan pushback di stand: 'Hold position, expect three minutes delay' hingga jalur apron steril."
            )

        case .stopPushback:
            return InjectedContingency(
                title: "Stop Pushback Immediately (Doc 9432 §4.3.3)",
                severity: .urgency,
                triggerPhase: .preDeparture,
                summary: "Pembatalan pushback mendadak oleh ATC Ground karena ada pergerakan kendaraan apron liar yang memotong jalur dorong.",
                downstreamEffect: "ATC menerbitkan: 'STOP PUSHBACK IMMEDIATELY'. Pilot mengonfirmasi rem dipasang dan pushback berhenti seketika."
            )

        case .unableAltitude:
            return InjectedContingency(
                title: "Unable Altitude Profile (Aircraft Performance - Doc 9432 §2.6)",
                severity: .urgency,
                triggerPhase: .enRoute,
                summary: "ATC menginstruksikan percepatan laju tanjak melewati waypoint, namun pesawat dengan bobot penuh tidak sanggup memenuhi gradien tanjak.",
                downstreamEffect: "Pilot wajib menolak izin menggunakan kata sakral: 'UNABLE FL... due performance, request maintain lower level'."
            )

        case .holdShortExact:
            return InjectedContingency(
                title: "Hold Short Mandatory Readback (Doc 4444 §4.5.7.5b)",
                severity: .abnormal,
                triggerPhase: .preDeparture,
                summary: "Instruksi taxi menuju batas aman holding point yang mewajibkan penegasan ulang batas berhenti landasan aktif.",
                downstreamEffect: "Pilot me-readback titik batas 'HOLD SHORT' secara presisi tanpa melanggar garis marka pembatas."
            )

        // MARK: - LEVEL 3 NEW CASES
        case .runwayBacktrack:
            return InjectedContingency(
                title: "Runway Backtrack Maneuver (Doc 9432 §4.4.2)",
                severity: .abnormal,
                triggerPhase: .departure,
                summary: "Bandara tanpa parallel taxiway penuh menuntut pesawat memasuki landasan dan berputar 180 derajat di turning loop ujung landasan.",
                downstreamEffect: "Pilot melakukan backtrack dan line up and wait di ujung landasan aktif dengan disiplin waktu tinggi."
            )

        case .conditionalLineUp:
            return InjectedContingency(
                title: "Conditional Line-Up and Wait (Doc 9432 §4.5.7)",
                severity: .abnormal,
                triggerPhase: .departure,
                summary: "Izin masuk landasan bersyarat di belakang pesawat yang sedang mendarat di short final.",
                downstreamEffect: "Pilot mengidentifikasi pesawat pendarat sebelum meluncur masuk ke landasan pacu: 'Behind landing Boeing 737, line up and wait runway...'."
            )

        case .holdingPatternEAT:
            return InjectedContingency(
                title: "Holding Pattern & EAT (Doc 4444 §5.5)",
                severity: .abnormal,
                triggerPhase: .enRoute,
                summary: "Kepadatan lalu lintas di bandara kedatangan memicu perintah holding di atas fix/VOR dengan estimasi waktu pendekatan (Expected Approach Time).",
                downstreamEffect: "Pilot me-readback titik hold, inbound track, arah putaran, level, dan waktu EAT."
            )

        case .delayingVectorOrbit:
            return InjectedContingency(
                title: "Delaying Vector / Orbit (Doc 9432 §4.6.5)",
                severity: .abnormal,
                triggerPhase: .approach,
                summary: "ATC memberikan putaran tunda 360 derajat (orbit) atau vektor radar tambahan untuk mengatur separasi kedatangan.",
                downstreamEffect: "Pesawat melakukan 360° turn sebelum diarahkan kembali ke jalur pendekatan final."
            )

        case .continueApproachShortFinal:
            return InjectedContingency(
                title: "Continue Approach on Short Final (Doc 9432 §4.7.1)",
                severity: .abnormal,
                triggerPhase: .landing,
                summary: "Menunda izin mendarat di short final karena pesawat di depan lambat keluar landasan.",
                downstreamEffect: "Pilot mempertahankan pendekatan dan me-readback 'CONTINUE APPROACH' hingga izin pendaratan terbit."
            )

        case .lightGunSignals:
            return InjectedContingency(
                title: "Light Gun Signals (Ground Comms Failure - Doc 4444 §7.16)",
                severity: .abnormal,
                triggerPhase: .landing,
                summary: "Hilang komunikasi radio di darat, pilot mengamati tembakan pistol lampu hijau/merah dari menara ATC.",
                downstreamEffect: "Pilot mengonfirmasi izin taksi/mendarat via kilatan lampu suar kontrol menara."
            )

        // MARK: - LEVEL 4 NEW CASES
        case .ctotSlotManagement:
            return InjectedContingency(
                title: "CTOT Slot Management (ATFM Delay - Doc 4444 Ch 3)",
                severity: .abnormal,
                triggerPhase: .preDeparture,
                summary: "Kepatuhan slot waktu keberangkatan ATFM yang sangat ketat untuk menghindari penumpukan di koridor udara padat.",
                downstreamEffect: "Koordinasi waktu start-up dengan toleransi slot CTOT -5 / +10 menit."
            )

        case .callsignConfusion:
            return InjectedContingency(
                title: "Callsign Confusion Vigilance (Doc 9432 §2.7.2)",
                severity: .abnormal,
                triggerPhase: .departure,
                summary: "Dua pesawat di frekuensi yang sama memiliki nomor penerbangan mirip. Siswa harus waspada menyaring panggilan suara.",
                downstreamEffect: "Siswa menolak instruksi yang bukan untuk dirinya menggunakan frasa baku: 'NEGATIVE, confirm instruction for...'."
            )

        case .slopOceanic:
            return InjectedContingency(
                title: "Strategic Lateral Offset (SLOP - Doc 4444 §16.5)",
                severity: .abnormal,
                triggerPhase: .enRoute,
                summary: "Penggeseran jalur lateral acak 1-2 NM ke kanan sumbu rute untuk mitigasi turbulensi vorteks dan risiko tabrakan di jalur tanpa radar.",
                downstreamEffect: "Pilot melapor eksekusi SLOP 1 NM right of track di koridor jelajah."
            )

        case .fuelDumping:
            return InjectedContingency(
                title: "Fuel Dumping Procedure (Doc 9432 §11.2)",
                severity: .urgency,
                triggerPhase: .enRoute,
                summary: "Pembuangan bahan bakar avtur di ketinggian aman untuk mengurangi bobot pesawat sebelum pendaratan darurat.",
                downstreamEffect: "ATC menetapkan area pembuangan bahan bakar dan menyiarkan peringatan ke pesawat lain di sekitarnya."
            )

        case .communicableDiseases:
            return InjectedContingency(
                title: "Communicable Disease Report (Doc 4444 §16.6)",
                severity: .urgency,
                triggerPhase: .arrival,
                summary: "Pelaporan penumpang diduga mengidap penyakit menular sebelum mendarat sesuai regulasi karantina kesehatan internasional.",
                downstreamEffect: "ATC menyiagakan otoritas karantina bandara dan mengarahkan parkir di stand isolasi khusus."
            )

        case .blownTireLanding:
            return InjectedContingency(
                title: "Blown Tire Blocking Runway (Doc 4444 §15.1)",
                severity: .urgency,
                triggerPhase: .landing,
                summary: "Ban pecah saat mendarat memblokir landasan pacu. Pesawat berhenti darurat dan melapor ke Tower.",
                downstreamEffect: "Runway ditutup sesaat, armada ARFF memeriksa serpihan karet ban dan membantu penarikan pesawat."
            )

        case .hotBrakesInspection:
            return InjectedContingency(
                title: "Hot Brakes Inspection on Taxiway (Doc 9432 §4.10)",
                severity: .urgency,
                triggerPhase: .landing,
                summary: "Pengereman darurat menyebabkan panas rem roda ekstrem berisiko meledak.",
                downstreamEffect: "Pesawat berhenti di taxiway terbuka dan menunggu tim pemadam menyemprotkan pendingin."
            )

        case .airborneCommsFailure:
            return InjectedContingency(
                title: "Airborne Comms Failure / Squawk 7600 (Doc 4444 §15.3)",
                severity: .urgency,
                triggerPhase: .approach,
                summary: "Hilang kontak radio di wilayah terminal/udara. Pilot menyetel transponder 7600 dan melanjutkan pendekatan instrumen baku.",
                downstreamEffect: "ATC mengosongkan jalur pendekatan dan memandu via pengamatan radar visual."
            )

        // MARK: - LEVEL 5 NEW CASES
        case .pilotInitiatedGoAround:
            return InjectedContingency(
                title: "Pilot-Initiated Go-Around (Runway Obstruction - Doc 9432 §4.8.3)",
                severity: .urgency,
                triggerPhase: .landing,
                summary: "Tower memberi izin mendarat namun ada kendaraan patroli masuk landasan. Pilot secara mandiri membatalkan pendaratan.",
                downstreamEffect: "Pilot menekan PTT refleks: 'GOING AROUND, vehicle on runway' dan menanjak missed approach."
            )

        case .gpwsTerrainAvoidance:
            return InjectedContingency(
                title: "GPWS Terrain Avoidance (UNABLE Heading - Doc 4444 §15.7.4)",
                severity: .urgency,
                triggerPhase: .approach,
                summary: "Vektor ATC mengarah ke tebing gunung di lembah. Pilot menolak izin demi keselamatan.",
                downstreamEffect: "Pilot menyatakan: 'UNABLE heading... due terrain' dan langsung naik menanjak aman."
            )

        case .windShearMicroburst:
            return InjectedContingency(
                title: "Severe Wind Shear Microburst (Doc 9432 §11.4)",
                severity: .urgency,
                triggerPhase: .approach,
                summary: "Deteksi geseran angin ekstrem di jalur final approach pegunungan.",
                downstreamEffect: "Pilot mengeksekusi escape maneuver dan melapor wind shear gain/loss of airspeed ke menara."
            )

        case .fuelEmergencyMayday:
            return InjectedContingency(
                title: "MINIMUM FUEL vs MAYDAY FUEL (Doc 4444 §15.5.4)",
                severity: .distress,
                triggerPhase: .arrival,
                summary: "Bahan bakar cadangan kritis menyentuh batas final reserve. Pilot mendeklarasikan MAYDAY FUEL.",
                downstreamEffect: "ATC memberikan prioritas pendaratan nomor satu langsung direct final runway."
            )

        case .volcanicAshAvoidance:
            return InjectedContingency(
                title: "Volcanic Ash Avoidance (Doc 4444 §15.8)",
                severity: .urgency,
                triggerPhase: .enRoute,
                summary: "Awan abu vulkanik pekat terdeteksi di rute penerbangan. Pilot meminta deviasi darurat menjauhi plume abu.",
                downstreamEffect: "ATC segera menyetujui deviasi darurat dan meneruskan SIGMET abu vulkanik ke stasiun lain."
            )

        case .runwayExcursionARFF:
            return InjectedContingency(
                title: "Runway Excursion / ARFF Alerting (Doc 4444 §9.2, §15.1)",
                severity: .distress,
                triggerPhase: .landing,
                summary: "Pesawat tergelincir ke rerumputan basah saat pendaratan di landasan pendek lembah.",
                downstreamEffect: "Menara membunyikan crash bell (DETRESFA) dan mengerahkan seluruh armada pertolongan darurat pemadam."
            )

        case .hijack7500:
            return InjectedContingency(
                title: "Unlawful Interference / Squawk 7500 (Doc 4444 §15.1.3)",
                severity: .distress,
                triggerPhase: .enRoute,
                summary: "Pemberitahuan pembajakan pesawat udara secara diskret via kode transponder 7500.",
                downstreamEffect: "ATC merespons dengan fraseologi diskret dan mengkoordinasikan keamanan pertahanan militer."
            )

        case .militaryInterception:
            return InjectedContingency(
                title: "Military Interception (WILCO - Doc 4444 §15.4)",
                severity: .urgency,
                triggerPhase: .enRoute,
                summary: "Pesawat diintersepsi oleh jet tempur militer di wilayah udara sensitif.",
                downstreamEffect: "Pilot mematuhi sinyal visual pesawat pencegat dan merespons via frekuensi darurat 121.5 MHz: 'WILCO'."
            )

        }
    }

    // MARK: - Adaptive 6-Phase Pipeline for Aborted / EFATO Flights (Eliminates Empty Phases)
    private func buildTerminatedEarlyPhaseExchanges(
        phase: Phase,
        contingency: InjectedContingency?,
        context: SlotContext,
        role: UserRole,
        currentGlobalTurn: inout Int
    ) -> (title: String, goal: String, exchanges: [FilledExchange]) {
        var exchanges: [FilledExchange] = []
        let callsign = context.callsign
        let twrUnit = context.unitTower?.callsign ?? "Tower"
        let gndUnit = context.unitGround?.callsign ?? "Ground"
        let gndFreq = SpokenFormFormatter.frequency(context.unitGround?.frequency ?? "121.700")
        let isAbort = contingency?.title.contains("Abort") == true
        let title: String
        let goal: String

        switch phase {
        case .preDeparture, .departure:
            title = ""
            goal = ""

        case .enRoute:
            if isAbort {
                title = "Phase 3: Runway Assessment & Brake Inspection"
                goal = "Koordinasi darat di runway pasca-abort, penilaian suhu rem panas (hot brakes), dan instruksi penahanan lalu lintas di final."

                exchanges.append(FilledExchange(
                    exchangeID: "ABT-P3-1", templateID: "ABT-P3", turn: currentGlobalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), \(twrUnit), verify stopped on runway, advise if fire indication or assistance required.",
                    criticalSlots: [], severity: .abnormal, eventTag: "RUNWAY OCCUPIED"
                ))
                currentGlobalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABT-P3-2", templateID: "ABT-P3", turn: currentGlobalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Stopped on runway, brakes hot, tires intact, no fire indication, requesting two minutes on runway for brake cooling checklist, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "STATUS", expectedValue: "stopped on runway", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CHECKLIST", expectedValue: "brake cooling checklist", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .abnormal, eventTag: "BRAKE COOLING"
                ))
                currentGlobalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABT-P3-3", templateID: "ABT-P3", turn: currentGlobalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), roger, take your time, holding approaching traffic on five miles final, advise when ready to vacate.",
                    criticalSlots: [], severity: .normal, eventTag: "TRAFFIC HOLDING"
                ))
                currentGlobalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABT-P3-4", templateID: "ABT-P3", turn: currentGlobalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Wilco, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "WILCO", expectedValue: "wilco", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .normal, eventTag: "WILCO"
                ))
                currentGlobalTurn += 1
            } else {
                title = "Phase 3: Immediate Ground Safety & Evacuation Assessment"
                goal = "Pengamanan pesawat di runway pasca-EFATO forced landing, evaluasi kebocoran bahan bakar, dan konfirmasi kondisi penumpang."

                exchanges.append(FilledExchange(
                    exchangeID: "EFA-P3-1", templateID: "EFA-P3", turn: currentGlobalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), \(twrUnit), emergency equipment on scene, advise souls on board and hazardous cargo.",
                    criticalSlots: [], severity: .distress, eventTag: "ARFF ON SCENE"
                ))
                currentGlobalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "EFA-P3-2", templateID: "EFA-P3", turn: currentGlobalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Two persons on board, zero hazardous cargo, master switch off, no fire, precautionary evacuation in progress, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "POB", expectedValue: "two persons on board", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "EVACUATION", expectedValue: "evacuation in progress", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .distress, eventTag: "EVACUATION IN PROGRESS"
                ))
                currentGlobalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "EFA-P3-3", templateID: "EFA-P3", turn: currentGlobalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), roger, fire crew in attendance, runway closed, advise when passengers safely clear.",
                    criticalSlots: [], severity: .distress, eventTag: "RUNWAY CLOSED"
                ))
                currentGlobalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "EFA-P3-4", templateID: "EFA-P3", turn: currentGlobalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Passengers safely clear, standing by with Incident Commander, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "STATUS", expectedValue: "passengers safely clear", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .normal, eventTag: "PASSENGERS CLEAR"
                ))
                currentGlobalTurn += 1
            }

        case .arrival:
            if isAbort {
                title = "Phase 4: ARFF & Safety Operations Escort"
                goal = "Inspeksi eksternal visual roda dan rem oleh armada ARFF (Tender One), konfirmasi tidak ada deflasi ban atau kebocoran hidrolik."

                exchanges.append(FilledExchange(
                    exchangeID: "ABT-P4-1", templateID: "ABT-P4", turn: currentGlobalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), airport safety vehicle Tender One is in position alongside your main gear on taxiway, advise status.",
                    criticalSlots: [], severity: .normal, eventTag: "ARFF INSPECTION"
                ))
                currentGlobalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABT-P4-2", templateID: "ABT-P4", turn: currentGlobalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Checklist completed, brake temperature stabilizing, tires intact, ready to backtrack and vacate runway, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "READY_VACATE", expectedValue: "ready to backtrack", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .normal, eventTag: "READY VACATE"
                ))
                currentGlobalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABT-P4-3", templateID: "ABT-P4", turn: currentGlobalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), Tender One confirms no smoke or fluid leaks, backtrack approved runway, vacate via \(context.exitTaxiway).",
                    criticalSlots: [], severity: .normal, eventTag: "BACKTRACK VACATE"
                ))
                currentGlobalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABT-P4-4", templateID: "ABT-P4", turn: currentGlobalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Backtrack approved, vacate via \(context.exitTaxiway), \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "VACATE_TAXIWAY", expectedValue: context.exitTaxiway, type: "mandatoryTaxiway"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .normal, eventTag: "READBACK VACATE"
                ))
                currentGlobalTurn += 1
            } else {
                title = "Phase 4: Crash Site Containment & Runway Sterilization"
                goal = "Koordinasi pengamanan lokasi insiden oleh Chief Fire Officer, sterilisasi debris, dan penyiapan evakuasi airframe."

                exchanges.append(FilledExchange(
                    exchangeID: "EFA-P4-1", templateID: "EFA-P4", turn: currentGlobalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), Chief Fire Officer reports all occupants evacuated to safety zone, foam blanket applied.",
                    criticalSlots: [], severity: .distress, eventTag: "FOAM BLANKET APPLIED"
                ))
                currentGlobalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "EFA-P4-2", templateID: "EFA-P4", turn: currentGlobalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Affirm, occupants safe, awaiting towing crew, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "AFFIRM", expectedValue: "affirm", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .distress, eventTag: "OCCUPANTS SAFE"
                ))
                currentGlobalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "EFA-P4-3", templateID: "EFA-P4", turn: currentGlobalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), tow tug and salvage team en route, airport incident command established.",
                    criticalSlots: [], severity: .normal, eventTag: "SALVAGE TEAM EN ROUTE"
                ))
                currentGlobalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "EFA-P4-4", templateID: "EFA-P4", turn: currentGlobalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Wilco, standing by with incident command, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "WILCO", expectedValue: "wilco", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .normal, eventTag: "WILCO SALVAGE"
                ))
                currentGlobalTurn += 1
            }

        case .approach:
            if isAbort {
                title = "Phase 5: Runway Vacated & Aerodrome Reopening"
                goal = "Laporan pengosongan landasan pacu, pembukaan kembali landasan untuk trafik, dan transfer ke frekuensi Ground."

                exchanges.append(FilledExchange(
                    exchangeID: "ABT-P5-1", templateID: "ABT-P5", turn: currentGlobalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), \(twrUnit), report runway vacated.",
                    criticalSlots: [], severity: .normal, eventTag: "REPORT VACATED"
                ))
                currentGlobalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABT-P5-2", templateID: "ABT-P5", turn: currentGlobalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "\(twrUnit), \(callsign), runway vacated via \(context.exitTaxiway).",
                    criticalSlots: [
                        CriticalSlot(slot: "VACATED", expectedValue: "runway vacated", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .normal, eventTag: "RUNWAY VACATED"
                ))
                currentGlobalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABT-P5-3", templateID: "ABT-P5", turn: currentGlobalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), runway vacated confirmed, runway now reopened for traffic. Contact Ground \(gndFreq).",
                    criticalSlots: [], severity: .normal, eventTag: "RUNWAY REOPENED"
                ))
                currentGlobalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABT-P5-4", templateID: "ABT-P5", turn: currentGlobalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Ground \(gndFreq), \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "GROUND_FREQ", expectedValue: gndFreq, type: "mandatoryFrequency"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .normal, eventTag: "TRANSFER GROUND"
                ))
                currentGlobalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABT-P5-5", templateID: "ABT-P5", turn: currentGlobalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), \(gndUnit), taxi to maintenance apron via Bravo, maintenance crew will meet you.",
                    criticalSlots: [], severity: .normal, eventTag: "GROUND TAXI CLEARANCE"
                ))
                currentGlobalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABT-P5-6", templateID: "ABT-P5", turn: currentGlobalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Taxi to maintenance apron via Bravo, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "STAND", expectedValue: "maintenance apron", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .normal, eventTag: "READBACK TAXI"
                ))
                currentGlobalTurn += 1
            } else {
                title = "Phase 5: Airfield NOTAM & Runway Closure Coordination"
                goal = "Penerbitan NOTAM penutupan aerodrome sementara, pengalihan penerbangan masuk (inbound holding/diversion)."

                exchanges.append(FilledExchange(
                    exchangeID: "EFA-P5-1", templateID: "EFA-P5", turn: currentGlobalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), \(twrUnit), runway disabled, NOTAM issued closing aerodrome to fixed-wing traffic for two hours.",
                    criticalSlots: [], severity: .distress, eventTag: "NOTAM ISSUED"
                ))
                currentGlobalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "EFA-P5-2", templateID: "EFA-P5", turn: currentGlobalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Information received, aircraft secured on grass verge, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "INFO", expectedValue: "information received", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .normal, eventTag: "AIRCRAFT SECURED"
                ))
                currentGlobalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "EFA-P5-3", templateID: "EFA-P5", turn: currentGlobalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), airport safety vehicle escorting crew to flight operations building.",
                    criticalSlots: [], severity: .normal, eventTag: "CREW ESCORT"
                ))
                currentGlobalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "EFA-P5-4", templateID: "EFA-P5", turn: currentGlobalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Wilco, following escort, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "WILCO", expectedValue: "wilco", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .normal, eventTag: "WILCO ESCORT"
                ))
                currentGlobalTurn += 1
            }

        case .landing:
            if isAbort {
                title = "Phase 6: Maintenance Stand & Flight Plan Cancellation"
                goal = "Parkir di stand perawatan teknis, pendinginan rem total, dan penutupan/pembatalan resmi flight plan."

                exchanges.append(FilledExchange(
                    exchangeID: "ABT-P6-1", templateID: "ABT-P6", turn: currentGlobalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), \(gndUnit), report on maintenance stand with engines shut down.",
                    criticalSlots: [], severity: .normal, eventTag: "REPORT SHUTDOWN"
                ))
                currentGlobalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABT-P6-2", templateID: "ABT-P6", turn: currentGlobalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "\(gndUnit), \(callsign), on maintenance stand, parking brake set, engines shut down, request cancel flight plan.",
                    criticalSlots: [
                        CriticalSlot(slot: "ENGINES_SHUTDOWN", expectedValue: "engines shut down", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CANCEL_FP", expectedValue: "cancel flight plan", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .normal, eventTag: "CANCEL FLIGHT PLAN"
                ))
                currentGlobalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABT-P6-3", templateID: "ABT-P6", turn: currentGlobalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), flight plan cancelled at zero two zero zero UTC, safety occurrence report logged, good day.",
                    criticalSlots: [], severity: .normal, eventTag: "PLAN CANCELLED"
                ))
                currentGlobalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABT-P6-4", templateID: "ABT-P6", turn: currentGlobalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Flight plan cancelled, good day, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .normal, eventTag: "GOOD DAY"
                ))
                currentGlobalTurn += 1
            } else {
                title = "Phase 6: Accident Investigation Handover & Official Filing"
                goal = "Serah terima lokasi kejadian kepada tim investigasi kecelakaan (KNKT/DGCA) dan penutupan resmi rencana penerbangan."

                exchanges.append(FilledExchange(
                    exchangeID: "EFA-P6-1", templateID: "EFA-P6", turn: currentGlobalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), Air Traffic Services has filed air safety occurrence report, flight plan officially terminated at zero two zero zero UTC.",
                    criticalSlots: [], severity: .distress, eventTag: "OCCURRENCE FILED"
                ))
                currentGlobalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "EFA-P6-2", templateID: "EFA-P6", turn: currentGlobalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Occurrence report acknowledged, flight plan terminated, crew standing by for safety interview, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "ACKNOWLEDGED", expectedValue: "acknowledged", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .normal, eventTag: "SAFETY ACKNOWLEDGED"
                ))
                currentGlobalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "EFA-P6-3", templateID: "EFA-P6", turn: currentGlobalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), thank you for professional handling, all units standing down.",
                    criticalSlots: [], severity: .normal, eventTag: "STAND DOWN"
                ))
                currentGlobalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "EFA-P6-4", templateID: "EFA-P6", turn: currentGlobalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Standing down, good day, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .normal, eventTag: "GOOD DAY"
                ))
                currentGlobalTurn += 1
            }
        }

        return (title: title, goal: goal, exchanges: exchanges)
    }

    // MARK: - Integrated Dynamic Phase Builders (Chronological FSM Architecture)
    private func buildDynamicPhaseExchanges(
        phase: Phase,
        level: CurriculumLevel,
        seed: Int,
        role: UserRole,
        context: SlotContext,
        contingencies: [InjectedContingency],
        activeDepRunway: inout Runway,
        activeHoldingPoint: inout String,
        activeWeather: inout AlignedWeather,
        isFlightTerminatedEarly: inout Bool,
        executedContingencies: inout [InjectedContingency],
        globalTurn: inout Int
    ) -> [FilledExchange] {
        switch phase {
        case .preDeparture:
            return buildPreDepartureExchanges(
                level: level,
                seed: seed,
                role: role,
                context: context,
                contingencies: contingencies,
                activeDepRunway: &activeDepRunway,
                activeHoldingPoint: &activeHoldingPoint,
                activeWeather: &activeWeather,
                executedContingencies: &executedContingencies,
                globalTurn: &globalTurn
            )
        case .departure:
            return buildDepartureExchanges(
                level: level,
                seed: seed,
                role: role,
                context: context,
                contingencies: contingencies,
                activeDepRunway: &activeDepRunway,
                activeHoldingPoint: &activeHoldingPoint,
                activeWeather: &activeWeather,
                isFlightTerminatedEarly: &isFlightTerminatedEarly,
                executedContingencies: &executedContingencies,
                globalTurn: &globalTurn
            )
        case .enRoute:
            return buildEnRouteExchanges(
                level: level,
                seed: seed,
                role: role,
                context: context,
                contingencies: contingencies,
                executedContingencies: &executedContingencies,
                globalTurn: &globalTurn
            )
        case .arrival:
            return buildArrivalExchanges(
                level: level,
                seed: seed,
                role: role,
                context: context,
                contingencies: contingencies,
                executedContingencies: &executedContingencies,
                globalTurn: &globalTurn
            )
        case .approach:
            return buildApproachExchanges(
                level: level,
                seed: seed,
                role: role,
                context: context,
                contingencies: contingencies,
                executedContingencies: &executedContingencies,
                globalTurn: &globalTurn
            )
        case .landing:
            return buildLandingExchanges(
                level: level,
                seed: seed,
                role: role,
                context: context,
                contingencies: contingencies,
                executedContingencies: &executedContingencies,
                globalTurn: &globalTurn
            )
        }
    }

    // MARK: - Phase 1: Pre-Departure Builder
    private func buildPreDepartureExchanges(
        level: CurriculumLevel,
        seed: Int,
        role: UserRole,
        context: SlotContext,
        contingencies: [InjectedContingency],
        activeDepRunway: inout Runway,
        activeHoldingPoint: inout String,
        activeWeather: inout AlignedWeather,
        executedContingencies: inout [InjectedContingency],
        globalTurn: inout Int
    ) -> [FilledExchange] {
        var exchanges: [FilledExchange] = []
        let callsign = context.callsign
        let atisLetter = context.atisId
        let qnhSpoken = SpokenFormFormatter.qnh(context.weather.qnh)
        let depRwySpoken = SpokenFormFormatter.runway(activeDepRunway.designator)
        let standOrig = context.stand
        let acftType = context.aircraftType
        let sidName = context.sidProcedure
        let destName = context.destinationName
        let delUnit = context.unitDelivery?.callsign ?? (context.unitGround?.callsign ?? "Ground")
        let _ = context.unitGround?.callsign ?? "Ground"
        let gndFreq = SpokenFormFormatter.frequency(context.unitGround?.frequency ?? "121.700")

        if level == .level1 {
            // Turn 1: PILOT Initial Contact with Tower incorporating ATIS code
            exchanges.append(FilledExchange(
                exchangeID: "PD-VFR-INIT-1", templateID: "PD-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "\(context.unitTower?.callsign ?? "Tower"), \(callsign), \(acftType) at GA apron, information \(atisLetter) received, QNH \(qnhSpoken), request taxi for local circuit touch-and-go.",
                criticalSlots: [
                    CriticalSlot(slot: "ATIS_ID", expectedValue: atisLetter, type: "mandatoryAtis"),
                    CriticalSlot(slot: "QNH", expectedValue: qnhSpoken, type: "mandatoryQnh"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "INITIAL CONTACT & TAXI REQ"
            ))
            globalTurn += 1

            // Turn 2: ATC Taxi to Holding Point
            exchanges.append(FilledExchange(
                exchangeID: "PD-VFR-TXI-1", templateID: "PD-04", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), taxi to holding point \(activeHoldingPoint) runway \(depRwySpoken) via Alfa, hold short runway \(depRwySpoken).",
                criticalSlots: [], severity: .normal, eventTag: "TAXI TO HOLDING POINT"
            ))
            globalTurn += 1

            // Turn 3: PILOT Readback Taxi
            exchanges.append(FilledExchange(
                exchangeID: "PD-VFR-TXI-2", templateID: "PD-04", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Taxi to holding point \(activeHoldingPoint) runway \(depRwySpoken) via Alfa, hold short runway \(depRwySpoken), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "HOLDING_POINT", expectedValue: activeHoldingPoint, type: "mandatoryHoldingPoint"),
                    CriticalSlot(slot: "RUNWAY", expectedValue: depRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "HOLD_SHORT_RUNWAY", expectedValue: "hold short runway", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK TAXI"
            ))
            globalTurn += 1

        } else if level == .level5 {
            // Level 5 Mountain Bush / Valley: Inject VHF Partyline Ground Contention (1-3 turns)
            let stationName = context.unitTower?.callsign ?? "\(context.airport.name) Tower"
            let depRwySpoken = SpokenFormFormatter.runway(activeDepRunway.designator)
            let partylineTurns = generateLevel5PartylineInterruption(
                phase: .preDeparture,
                station: stationName,
                rwy: depRwySpoken,
                airportICAO: context.airport.icao,
                studentCallsign: callsign,
                seed: seed,
                globalTurn: &globalTurn
            )
            exchanges.append(contentsOf: partylineTurns)

            // Turn 1: PILOT Initial Contact with Delivery / Tower (Channel now clear)
            exchanges.append(FilledExchange(
                exchangeID: "PD-CD-REQ-1", templateID: "PD-02", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "\(delUnit), \(callsign), \(standOrig), information \(atisLetter) received, QNH \(qnhSpoken), TSAT zero four one zero, request IFR clearance to \(destName), ready to copy.",
                criticalSlots: [
                    CriticalSlot(slot: "ATIS_ID", expectedValue: atisLetter, type: "mandatoryAtis"),
                    CriticalSlot(slot: "DESTINATION", expectedValue: destName, type: "mandatoryAirport"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "IFR CLEARANCE REQ",
                objective: "Frekuensi kini telah bebas (Silence observed). Minta izin rute IFR ke bandara tujuan."
            ))
            globalTurn += 1

            // Turn 2: ATC Standby
            exchanges.append(FilledExchange(
                exchangeID: "PD-CD-STB-1", templateID: "PD-02", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(delUnit), standby.",
                criticalSlots: [], severity: .normal, eventTag: "STANDBY"
            ))
            globalTurn += 1

            // Turn 3: PILOT Standby
            exchanges.append(FilledExchange(
                exchangeID: "PD-CD-STB-2", templateID: "PD-02", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Standing by, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK STANDBY"
            ))
            globalTurn += 1

            // Turn 4: ATC IFR Clearance
            exchanges.append(FilledExchange(
                exchangeID: "PD-CD-CLR-1", templateID: "PD-02", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(delUnit), cleared to \(destName) via \(sidName) departure, flight planned route. Climb initially flight level one zero zero, departure frequency \(context.depFreq), squawk \(context.squawk), TSAT zero four one zero.",
                criticalSlots: [], severity: .normal, eventTag: "IFR CLEARANCE ISSUED"
            ))
            globalTurn += 1

            // Turn 5: PILOT Readback Clearance
            exchanges.append(FilledExchange(
                exchangeID: "PD-CD-CLR-2", templateID: "PD-02", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Cleared to \(destName) via \(sidName) departure, flight planned route, climb initially flight level one zero zero, departure frequency \(context.depFreq), squawk \(context.squawk), TSAT zero four one zero, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "DESTINATION", expectedValue: destName, type: "mandatoryAirport"),
                    CriticalSlot(slot: "SID", expectedValue: sidName, type: "mandatorySid"),
                    CriticalSlot(slot: "ALTITUDE", expectedValue: "flight level one zero zero", type: "mandatoryAltitude"),
                    CriticalSlot(slot: "SQUAWK", expectedValue: context.squawk, type: "mandatorySquawk"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK CLEARANCE"
            ))
            globalTurn += 1

            // Turn 6: ATC Readback correct & Pushback instruction
            exchanges.append(FilledExchange(
                exchangeID: "PD-CD-CORR-1", templateID: "PD-02", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), readback correct. Start-up and pushback approved, face north, QNH \(qnhSpoken). Contact Ground \(gndFreq) when ready to taxi.",
                criticalSlots: [], severity: .normal, eventTag: "READBACK CORRECT & PUSH"
            ))
            globalTurn += 1

            // Turn 7: PILOT Readback Pushback & Ground freq
            exchanges.append(FilledExchange(
                exchangeID: "PD-CD-CORR-2", templateID: "PD-02", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Start-up and pushback approved, face north, QNH \(qnhSpoken), Ground \(gndFreq) when ready, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "APPROVAL", expectedValue: "start-up and pushback approved", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "QNH", expectedValue: qnhSpoken, type: "mandatoryQnh"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK PUSH & GROUND"
            ))
            globalTurn += 1

            // Turn 8: ATC Ground taxi clearance (with crossing if triggered)
            if let crossCont = contingencies.first(where: { $0.title.contains("Hold Short Crossing") }) {
                let crossRwy = activeDepRunway.designator == "11" ? "one zero" : "two eight"
                exchanges.append(FilledExchange(
                    exchangeID: "ABN-RWY-X-1", templateID: "ABN-RWY-X", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), Ground, taxi via Alfa, hold short of runway \(crossRwy), traffic on short final.",
                    criticalSlots: [], severity: .abnormal, eventTag: "HOLD SHORT RUNWAY CROSSING"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-RWY-X-2", templateID: "ABN-RWY-X", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Hold short runway \(crossRwy) via Alfa, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "HOLD_SHORT_RUNWAY", expectedValue: "hold short runway", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .abnormal, eventTag: "HOLD SHORT CROSSING READBACK"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-RWY-X-3", templateID: "ABN-RWY-X", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), cross runway \(crossRwy), continue taxi via \(context.taxiRoute), hold short runway \(depRwySpoken).",
                    criticalSlots: [], severity: .normal, eventTag: "CROSS RUNWAY APPROVED"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-RWY-X-4", templateID: "ABN-RWY-X", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Cross runway \(crossRwy), continue via \(context.taxiRoute), hold short runway \(depRwySpoken), \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "CROSS_RUNWAY", expectedValue: "cross runway", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "RUNWAY", expectedValue: depRwySpoken, type: "mandatoryRunway"),
                        CriticalSlot(slot: "HOLD_SHORT_RUNWAY", expectedValue: "hold short runway", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .normal, eventTag: "CROSS APPROVED READBACK"
                ))
                globalTurn += 1
                executedContingencies.append(crossCont)

            } else {
                exchanges.append(FilledExchange(
                    exchangeID: "PD-GND-TXI-2", templateID: "PD-04", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), Ground, taxi to holding point \(activeHoldingPoint) runway \(depRwySpoken) via \(context.taxiRoute), hold short runway \(depRwySpoken).",
                    criticalSlots: [], severity: .normal, eventTag: "TAXI TO HOLDING POINT"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "PD-GND-TXI-3", templateID: "PD-04", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Taxi to holding point \(activeHoldingPoint) runway \(depRwySpoken) via \(context.taxiRoute), hold short runway \(depRwySpoken), \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "HOLDING_POINT", expectedValue: activeHoldingPoint, type: "mandatoryHoldingPoint"),
                        CriticalSlot(slot: "RUNWAY", expectedValue: depRwySpoken, type: "mandatoryRunway"),
                        CriticalSlot(slot: "HOLD_SHORT_RUNWAY", expectedValue: "hold short runway", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .normal, eventTag: "READBACK TAXI"
                ))
                globalTurn += 1
            }

        } else {
            // Levels 2, 3, 4: IFR Standard
            // Turn 1: PILOT Initial Contact with Delivery / Ground
            exchanges.append(FilledExchange(
                exchangeID: "PD-IFR-INIT-1", templateID: "PD-02", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "\(delUnit), \(callsign), \(standOrig), information \(atisLetter) received, QNH \(qnhSpoken), request IFR clearance to \(destName), ready to copy.",
                criticalSlots: [
                    CriticalSlot(slot: "ATIS_ID", expectedValue: atisLetter, type: "mandatoryAtis"),
                    CriticalSlot(slot: "DESTINATION", expectedValue: destName, type: "mandatoryAirport"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "IFR CLEARANCE REQ"
            ))
            globalTurn += 1

            // Turn 2: ATC Route Clearance
            let initAlt = context.initialAlt
            let isCTOTActive = contingencies.contains(where: { $0.title.contains("CTOT Slot") })
            let ctotTime = "zero four three five"
            let ctotStart = "zero four two zero"

            let atcClearanceText: String
            if isCTOTActive {
                atcClearanceText = "\(callsign), \(delUnit), cleared to \(destName) via \(sidName) departure, flight planned route. Climb initially \(initAlt), squawk \(context.squawk). Calculated Take-off Time slot is \(ctotTime), start-up approved at \(ctotStart), QNH \(qnhSpoken)."
            } else {
                atcClearanceText = "\(callsign), \(delUnit), cleared to \(destName) via \(sidName) departure, flight planned route. Climb initially \(initAlt), squawk \(context.squawk). Start-up and pushback approved, face west, QNH \(qnhSpoken)."
            }

            exchanges.append(FilledExchange(
                exchangeID: "PD-IFR-CLR-1", templateID: "PD-02", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: atcClearanceText,
                criticalSlots: [], severity: isCTOTActive ? .abnormal : .normal, eventTag: isCTOTActive ? "CLEARANCE WITH CTOT SLOT" : "CLEARANCE & PUSHBACK APPROVED"
            ))
            globalTurn += 1

            // Turn 3: PILOT Readback
            let pilotReadbackText: String
            if isCTOTActive {
                pilotReadbackText = "Cleared to \(destName) via \(sidName) departure, climb initially \(initAlt), squawk \(context.squawk), CTOT slot \(ctotTime), start-up at \(ctotStart), QNH \(qnhSpoken), \(callsign)."
                if let ctotCont = contingencies.first(where: { $0.title.contains("CTOT Slot") }) {
                    executedContingencies.append(ctotCont)
                }
            } else {
                pilotReadbackText = "Cleared to \(destName) via \(sidName) departure, climb initially \(initAlt), squawk \(context.squawk), start-up and pushback approved, face west, QNH \(qnhSpoken), \(callsign)."
            }

            exchanges.append(FilledExchange(
                exchangeID: "PD-IFR-CLR-2", templateID: "PD-02", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: pilotReadbackText,
                criticalSlots: [
                    CriticalSlot(slot: "DESTINATION", expectedValue: destName, type: "mandatoryAirport"),
                    CriticalSlot(slot: "SID", expectedValue: sidName, type: "mandatorySid"),
                    CriticalSlot(slot: "SQUAWK", expectedValue: context.squawk, type: "mandatorySquawk"),
                    CriticalSlot(slot: "QNH", expectedValue: qnhSpoken, type: "mandatoryQnh"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: isCTOTActive ? .abnormal : .normal, eventTag: isCTOTActive ? "READBACK CLEARANCE & CTOT" : "READBACK CLEARANCE & PUSH"
            ))
            globalTurn += 1

            // PUSHBACK FRICTION CONTINGENCIES (Level 2: Pushback Delay & Stop Pushback)
            if let pbDelay = contingencies.first(where: { $0.title.contains("Pushback Delay") }) {
                exchanges.append(FilledExchange(
                    exchangeID: "ABN-PBD-1", templateID: "ABN-PBD", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "\(delUnit), \(callsign), stand \(standOrig), request pushback.",
                    criticalSlots: [
                        CriticalSlot(slot: "REQUEST", expectedValue: "request pushback", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .urgency, eventTag: "REQUEST PUSHBACK"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-PBD-2", templateID: "ABN-PBD", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), Ground, traffic passing behind Boeing seven three seven, hold position, expect three minutes delay.",
                    criticalSlots: [], severity: .urgency, eventTag: "HOLD POSITION PUSH DELAY"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-PBD-3", templateID: "ABN-PBD", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Hold position, expect three minutes delay, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "HOLD_POSITION", expectedValue: "hold position", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .urgency, eventTag: "READBACK HOLD POSITION"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-PBD-4", templateID: "ABN-PBD", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), traffic clear, start-up and pushback approved, face west.",
                    criticalSlots: [], severity: .normal, eventTag: "PUSHBACK APPROVED"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-PBD-5", templateID: "ABN-PBD", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Start-up and pushback approved, face west, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "APPROVAL", expectedValue: "start-up and pushback approved", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .normal, eventTag: "READBACK PUSHBACK"
                ))
                globalTurn += 1
                executedContingencies.append(pbDelay)

            } else if let stopPb = contingencies.first(where: { $0.title.contains("Stop Pushback") }) {
                exchanges.append(FilledExchange(
                    exchangeID: "ABN-SPB-1", templateID: "ABN-SPB", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), STOP PUSHBACK, STOP PUSHBACK, vehicle entering apron behind!",
                    criticalSlots: [], severity: .urgency, eventTag: "STOP PUSHBACK IMMEDIATELY"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-SPB-2", templateID: "ABN-SPB", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Stopping pushback, brakes set, \(callsign)!",
                    criticalSlots: [
                        CriticalSlot(slot: "STOPPING", expectedValue: "stopping pushback", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "BRAKES", expectedValue: "brakes set", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .urgency, eventTag: "READBACK STOP PUSHBACK"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-SPB-3", templateID: "ABN-SPB", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), vehicle clear, resume pushback, face west.",
                    criticalSlots: [], severity: .normal, eventTag: "RESUME PUSHBACK"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-SPB-4", templateID: "ABN-SPB", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Resuming pushback, face west, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "APPROVAL", expectedValue: "resuming pushback", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .normal, eventTag: "READBACK RESUME PUSHBACK"
                ))
                globalTurn += 1
                executedContingencies.append(stopPb)
            }

            // Turn 4: ATC Ground taxi clearance
            let isHoldShortExact = contingencies.contains(where: { $0.title.contains("Hold Short Mandatory") })

            if let crossCont = contingencies.first(where: { $0.title.contains("Hold Short Crossing") }) {
                let crossRwy = activeDepRunway.designator == "10" ? "two six" : "zero eight"
                exchanges.append(FilledExchange(
                    exchangeID: "ABN-RWY-X-1", templateID: "ABN-RWY-X", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), Ground, taxi via Alfa, hold short of runway \(crossRwy), traffic on short final.",
                    criticalSlots: [], severity: .abnormal, eventTag: "HOLD SHORT RUNWAY CROSSING"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-RWY-X-2", templateID: "ABN-RWY-X", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Hold short runway \(crossRwy) via Alfa, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "HOLD_SHORT_RUNWAY", expectedValue: "hold short runway", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .abnormal, eventTag: "HOLD SHORT CROSSING READBACK"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-RWY-X-3", templateID: "ABN-RWY-X", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), cross runway \(crossRwy), continue taxi via \(context.taxiRoute), hold short runway \(depRwySpoken).",
                    criticalSlots: [], severity: .normal, eventTag: "CROSS RUNWAY APPROVED"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-RWY-X-4", templateID: "ABN-RWY-X", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Cross runway \(crossRwy), continue via \(context.taxiRoute), hold short runway \(depRwySpoken), \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "CROSS_RUNWAY", expectedValue: "cross runway", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "RUNWAY", expectedValue: depRwySpoken, type: "mandatoryRunway"),
                        CriticalSlot(slot: "HOLD_SHORT_RUNWAY", expectedValue: "hold short runway", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .normal, eventTag: "CROSS APPROVED READBACK"
                ))
                globalTurn += 1
                executedContingencies.append(crossCont)

            } else {
                exchanges.append(FilledExchange(
                    exchangeID: "PD-GND-TXI-2", templateID: "PD-04", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), Ground, taxi to holding point \(activeHoldingPoint) runway \(depRwySpoken) via \(context.taxiRoute), hold short runway \(depRwySpoken).",
                    criticalSlots: [], severity: isHoldShortExact ? .abnormal : .normal, eventTag: isHoldShortExact ? "MANDATORY HOLD SHORT" : "TAXI TO HOLDING POINT"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "PD-GND-TXI-3", templateID: "PD-04", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Taxi to holding point \(activeHoldingPoint) runway \(depRwySpoken) via \(context.taxiRoute), hold short runway \(depRwySpoken), \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "HOLDING_POINT", expectedValue: activeHoldingPoint, type: "mandatoryHoldingPoint"),
                        CriticalSlot(slot: "RUNWAY", expectedValue: depRwySpoken, type: "mandatoryRunway"),
                        CriticalSlot(slot: "HOLD_SHORT_RUNWAY", expectedValue: "hold short runway", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: isHoldShortExact ? .abnormal : .normal, eventTag: isHoldShortExact ? "MANDATORY HOLD SHORT READBACK" : "READBACK TAXI"
                ))
                globalTurn += 1
                if let hsCont = contingencies.first(where: { $0.title.contains("Hold Short Mandatory") }) {
                    executedContingencies.append(hsCont)
                }
            }
        }

        // Mid-Taxi Runway Change (Wind Shift 180 degrees)
        if let rwyChange = contingencies.first(where: { $0.title.contains("Runway Change") }) {
            let reciprocalDesignator = activeDepRunway.reciprocal
            let reciprocalSpoken = SpokenFormFormatter.runway(reciprocalDesignator)
            let newHP = SpokenFormFormatter.holdingPoint(activeDepRunway.holdingPoints.last ?? "Alpha two")

            exchanges.append(FilledExchange(
                exchangeID: "ABN-RWY-CHG-1", templateID: "ABN-RWY-CHG", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), wind shifted two six zero degrees one five knots, runway change, runway \(reciprocalSpoken) now in use. Taxi to holding point \(newHP) runway \(reciprocalSpoken) via Bravo, hold short runway \(reciprocalSpoken).",
                criticalSlots: [], severity: .abnormal, eventTag: "RUNWAY CHANGE INSTRUCTION"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-RWY-CHG-2", templateID: "ABN-RWY-CHG", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Taxi to holding point \(newHP) runway \(reciprocalSpoken) via Bravo, hold short runway \(reciprocalSpoken), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "HOLDING_POINT", expectedValue: newHP, type: "mandatoryHoldingPoint"),
                    CriticalSlot(slot: "RUNWAY", expectedValue: reciprocalSpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "HOLD_SHORT_RUNWAY", expectedValue: "hold short runway", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .abnormal, eventTag: "RUNWAY CHANGE READBACK"
            ))
            globalTurn += 1

            // INVERT activeDepRunway OBJECT SO DESIGNATOR BECOMES RECIPROCAL!
            if let rwyObj = context.airport.runways.first(where: { $0.designator == reciprocalDesignator }) {
                activeDepRunway = rwyObj
            } else {
                activeDepRunway = Runway(
                    pair: activeDepRunway.pair,
                    designator: reciprocalDesignator,
                    reciprocal: activeDepRunway.designator,
                    headingDegT: (activeDepRunway.headingDegT + 180.0).truncatingRemainder(dividingBy: 360.0),
                    holdingPoints: activeDepRunway.holdingPoints
                )
            }
            activeHoldingPoint = newHP
            activeWeather = AlignedWeather(
                runway: reciprocalSpoken,
                heading: (activeWeather.heading + 180.0).truncatingRemainder(dividingBy: 360.0),
                windDirection: 260,
                windSpeed: 15,
                headwindKnots: 15,
                crosswindKnots: 0,
                qnh: activeWeather.qnh
            )
            executedContingencies.append(rwyChange)
        }

        return exchanges
    }

    // MARK: - Phase 2: Departure Builder (Sequential FSM Flow)
    private func buildDepartureExchanges(
        level: CurriculumLevel,
        seed: Int,
        role: UserRole,
        context: SlotContext,
        contingencies: [InjectedContingency],
        activeDepRunway: inout Runway,
        activeHoldingPoint: inout String,
        activeWeather: inout AlignedWeather,
        isFlightTerminatedEarly: inout Bool,
        executedContingencies: inout [InjectedContingency],
        globalTurn: inout Int
    ) -> [FilledExchange] {
        var exchanges: [FilledExchange] = []
        let callsign = context.callsign
        let twrUnit = context.unitTower?.callsign ?? "Tower"
        let rwySpoken = SpokenFormFormatter.runway(activeDepRunway.designator)
        let windSpoken = SpokenFormFormatter.wind(direction: activeWeather.windDirection, knots: activeWeather.windSpeed)

        // STEP 1: ATC TOWER INITIAL CONTACT AT HOLDING POINT
        exchanges.append(FilledExchange(
            exchangeID: "DP-TWR-INIT-1", templateID: "DP-01", turn: globalTurn, speaker: "ATC",
            isUserTurn: (role == .atc),
            text: "\(callsign), \(twrUnit), holding point \(activeHoldingPoint), report ready for departure.",
            criticalSlots: [], severity: .normal, eventTag: "REPORT READY FOR DEPARTURE"
        ))
        globalTurn += 1

        exchanges.append(FilledExchange(
            exchangeID: "DP-RDY-1", templateID: "DP-01", turn: globalTurn, speaker: "PILOT",
            isUserTurn: (role == .pilot),
            text: "Ready for departure, \(callsign).",
            criticalSlots: [
                CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
            ], severity: .normal, eventTag: "READY FOR DEPARTURE"
        ))
        globalTurn += 1

        // STEP 2: PRE-LINEUP HAZARDS (Bird Hazard or Inbound Emergency Priority)
        var prefixConditionText = ""
        if let birdHazard = contingencies.first(where: { $0.title.contains("Bird Hazard") }) {
            exchanges.append(FilledExchange(
                exchangeID: "ABN-BRD-HAZ-1", templateID: "ABN-BRD-HAZ", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), hold position, caution large flock of birds reported over runway \(rwySpoken) near threshold, airport bird dispersal vehicle dispatched.",
                criticalSlots: [], severity: .abnormal, eventTag: "BIRD HAZARD WARNING"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-BRD-HAZ-2", templateID: "ABN-BRD-HAZ", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Holding position, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "HOLD_POSITION", expectedValue: "holding position", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .abnormal, eventTag: "HOLD POSITION"
            ))
            globalTurn += 1

            prefixConditionText = "bird dispersal completed, runway \(rwySpoken) clear of birds. "
            executedContingencies.append(birdHazard)

        } else if let emgInbound = contingencies.first(where: { $0.title.contains("Inbound Emergency Priority") }) {
            exchanges.append(FilledExchange(
                exchangeID: "URG-EMG-LAND-1", templateID: "URG-EMG-LAND", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), hold position, cancel take-off preparation, inbound traffic Boeing seven three seven MAYDAY engine failure on two miles final, hold short of runway \(rwySpoken)!",
                criticalSlots: [], severity: .urgency, eventTag: "CANCEL PREPARATION: MAYDAY INBOUND"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "URG-EMG-LAND-2", templateID: "URG-EMG-LAND", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Holding position, holding short runway \(rwySpoken), \(callsign)!",
                criticalSlots: [
                    CriticalSlot(slot: "HOLD_POSITION", expectedValue: "holding position", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "HOLD_SHORT_RUNWAY", expectedValue: "holding short runway", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .urgency, eventTag: "HOLD SHORT"
            ))
            globalTurn += 1

            prefixConditionText = "emergency aircraft safely landed on runway \(rwySpoken), runway clear. "
            executedContingencies.append(emgInbound)
        }

        // STEP 3: LINE UP AND WAIT
        if let canLineUp = contingencies.first(where: { $0.title.contains("Cancel Line-Up") }) {
            exchanges.append(FilledExchange(
                exchangeID: "ABN-CAN-LU-1", templateID: "ABN-CAN-LU", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(prefixConditionText)runway \(rwySpoken), line up and wait.",
                criticalSlots: [], severity: .normal, eventTag: prefixConditionText.isEmpty ? "LINE UP AND WAIT" : "RUNWAY CLEAR & LINE UP"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-CAN-LU-2", templateID: "ABN-CAN-LU", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Runway \(rwySpoken), line up and wait, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "RUNWAY", expectedValue: rwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "LINE_UP_WAIT", expectedValue: "line up and wait", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK LINE UP"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-CAN-LU-3", templateID: "ABN-CAN-LU", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), cancel line up, hold short of runway \(rwySpoken), preceding traffic delayed.",
                criticalSlots: [], severity: .abnormal, eventTag: "CANCEL LINE UP"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-CAN-LU-4", templateID: "ABN-CAN-LU", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Cancel line up, holding short runway \(rwySpoken), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "CANCEL_LINE_UP", expectedValue: "cancel line up", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "HOLD_SHORT_RUNWAY", expectedValue: "holding short runway", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .abnormal, eventTag: "READBACK CANCEL LINE UP"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-CAN-LU-5", templateID: "ABN-CAN-LU", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), runway \(rwySpoken), line up and wait.",
                criticalSlots: [], severity: .normal, eventTag: "RE-CLEARED LINE UP"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-CAN-LU-6", templateID: "ABN-CAN-LU", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Runway \(rwySpoken), line up and wait, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "RUNWAY", expectedValue: rwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "LINE_UP_WAIT", expectedValue: "line up and wait", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK RE-CLEARED LINE UP"
            ))
            globalTurn += 1
            executedContingencies.append(canLineUp)

        } else if let wakeCont = contingencies.first(where: { $0.title.contains("Wake Turbulence Line-Up") }) {
            exchanges.append(FilledExchange(
                exchangeID: "ABN-WK-LU-1", templateID: "ABN-WK-LU", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(prefixConditionText)runway \(rwySpoken), caution wake turbulence behind departing Boeing seven seven seven, line up and wait, expect two minutes delay.",
                criticalSlots: [], severity: .abnormal, eventTag: "WAKE TURBULENCE 2MIN"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-WK-LU-2", templateID: "ABN-WK-LU", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Runway \(rwySpoken), line up and wait, caution wake turbulence, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "RUNWAY", expectedValue: rwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "LINE_UP_WAIT", expectedValue: "line up and wait", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .abnormal, eventTag: "READBACK WAKE LINE UP"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-WK-LU-3", templateID: "ABN-WK-LU", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), two minutes elapsed, runway \(rwySpoken), wind \(windSpoken), be ready for departure.",
                criticalSlots: [], severity: .normal, eventTag: "WAKE INTERVAL ELAPSED"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-WK-LU-4", templateID: "ABN-WK-LU", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Ready for departure, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READY FOR DEPARTURE"
            ))
            globalTurn += 1
            executedContingencies.append(wakeCont)

        } else if level == .level1 {
            exchanges.append(FilledExchange(
                exchangeID: "DP-VFR-LU-1", templateID: "DP-03", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(prefixConditionText)backtrack runway \(rwySpoken), line up and wait.",
                criticalSlots: [], severity: .normal, eventTag: prefixConditionText.isEmpty ? "BACKTRACK & LINE UP" : "RUNWAY CLEAR & LINE UP"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "DP-VFR-LU-2", templateID: "DP-03", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Backtrack runway \(rwySpoken), line up and wait, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "RUNWAY", expectedValue: rwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "LINE_UP_WAIT", expectedValue: "line up and wait", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK BACKTRACK & LINE UP"
            ))
            globalTurn += 1

        } else {
            // IFR Levels 2–5
            if let btCont = contingencies.first(where: { $0.title.contains("Runway Backtrack") || $0.title.contains("Backtrack") }) {
                exchanges.append(FilledExchange(
                    exchangeID: "DP-IFR-BT-1", templateID: "DP-03", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), \(prefixConditionText)backtrack runway \(rwySpoken), line up and wait.",
                    criticalSlots: [], severity: .abnormal, eventTag: "BACKTRACK & LINE UP"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "DP-IFR-BT-2", templateID: "DP-03", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Backtrack runway \(rwySpoken), line up and wait, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "RUNWAY", expectedValue: rwySpoken, type: "mandatoryRunway"),
                        CriticalSlot(slot: "LINE_UP_WAIT", expectedValue: "line up and wait", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .abnormal, eventTag: "READBACK BACKTRACK & LINE UP"
                ))
                globalTurn += 1
                executedContingencies.append(btCont)

            } else if let cndCont = contingencies.first(where: { $0.title.contains("Conditional Line-Up") }) {
                exchanges.append(FilledExchange(
                    exchangeID: "DP-IFR-CND-1", templateID: "DP-03", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), \(prefixConditionText)behind landing Airbus three two zero, line up and wait runway \(rwySpoken) behind.",
                    criticalSlots: [], severity: .abnormal, eventTag: "CONDITIONAL LINE-UP"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "DP-IFR-CND-2", templateID: "DP-03", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Behind landing Airbus three two zero, line up and wait runway \(rwySpoken) behind, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "RUNWAY", expectedValue: rwySpoken, type: "mandatoryRunway"),
                        CriticalSlot(slot: "LINE_UP_WAIT", expectedValue: "line up and wait", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .abnormal, eventTag: "READBACK CONDITIONAL LINE-UP"
                ))
                globalTurn += 1
                executedContingencies.append(cndCont)

            } else {
                let variant = seed % 2
                if variant == 0 {
                    exchanges.append(FilledExchange(
                        exchangeID: "DP-IFR-LU-1", templateID: "DP-03", turn: globalTurn, speaker: "ATC",
                        isUserTurn: (role == .atc),
                        text: "\(callsign), \(prefixConditionText)runway \(rwySpoken), line up and wait.",
                        criticalSlots: [], severity: .normal, eventTag: prefixConditionText.isEmpty ? "LINE UP AND WAIT" : "RUNWAY CLEAR & LINE UP"
                    ))
                    globalTurn += 1

                    exchanges.append(FilledExchange(
                        exchangeID: "DP-IFR-LU-2", templateID: "DP-03", turn: globalTurn, speaker: "PILOT",
                        isUserTurn: (role == .pilot),
                        text: "Runway \(rwySpoken), line up and wait, \(callsign).",
                        criticalSlots: [
                            CriticalSlot(slot: "RUNWAY", expectedValue: rwySpoken, type: "mandatoryRunway"),
                            CriticalSlot(slot: "LINE_UP_WAIT", expectedValue: "line up and wait", type: "mandatoryKeyword"),
                            CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                        ], severity: .normal, eventTag: "READBACK LINE UP"
                    ))
                    globalTurn += 1

                } else {
                    exchanges.append(FilledExchange(
                        exchangeID: "DP-IFR-IMM-1", templateID: "DP-03", turn: globalTurn, speaker: "ATC",
                        isUserTurn: (role == .atc),
                        text: "\(callsign), \(prefixConditionText)traffic on three miles final, are you ready for immediate departure?",
                        criticalSlots: [], severity: .normal, eventTag: "READY IMMEDIATE QUERY"
                    ))
                    globalTurn += 1

                    exchanges.append(FilledExchange(
                        exchangeID: "DP-IFR-IMM-2", templateID: "DP-03", turn: globalTurn, speaker: "PILOT",
                        isUserTurn: (role == .pilot),
                        text: "AFFIRM, ready for immediate, \(callsign).",
                        criticalSlots: [
                            CriticalSlot(slot: "AFFIRM", expectedValue: "affirm", type: "mandatoryKeyword"),
                            CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                        ], severity: .normal, eventTag: "CONFIRM IMMEDIATE"
                    ))
                    globalTurn += 1

                    exchanges.append(FilledExchange(
                        exchangeID: "DP-IFR-IMM-3", templateID: "DP-03", turn: globalTurn, speaker: "ATC",
                        isUserTurn: (role == .atc),
                        text: "\(callsign), line up, be ready for immediate departure.",
                        criticalSlots: [], severity: .normal, eventTag: "LINE UP IMMEDIATE"
                    ))
                    globalTurn += 1

                    exchanges.append(FilledExchange(
                        exchangeID: "DP-IFR-IMM-4", templateID: "DP-03", turn: globalTurn, speaker: "PILOT",
                        isUserTurn: (role == .pilot),
                        text: "Line up, ready for immediate, \(callsign).",
                        criticalSlots: [
                            CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                        ], severity: .normal, eventTag: "READBACK LINE UP IMMEDIATE"
                    ))
                    globalTurn += 1
                }
            }
        }

        // STEP 4: TAKE-OFF CLEARANCE
        if let ccCont = contingencies.first(where: { $0.title.contains("Callsign Confusion") }) {
            let confCallsign = "Batik seven one two"
            exchanges.append(FilledExchange(
                exchangeID: "ABN-CC-1", templateID: "ABN-CC", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(confCallsign), runway \(rwySpoken), wind \(windSpoken), cleared for take-off.",
                criticalSlots: [], severity: .abnormal, eventTag: "CALLSIGN CONFUSION INTRUSION"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-CC-2", templateID: "ABN-CC", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "NEGATIVE, \(callsign), you called \(confCallsign), confirm clearance for \(callsign)?",
                criticalSlots: [
                    CriticalSlot(slot: "NEGATIVE", expectedValue: "negative", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .abnormal, eventTag: "INTERCEPT CALLSIGN CONFUSION"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-CC-3", templateID: "ABN-CC", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), apologies, correction, \(callsign), runway \(rwySpoken), wind \(windSpoken), cleared for take-off.",
                criticalSlots: [], severity: .normal, eventTag: "CORRECTED TAKE-OFF CLEARANCE"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-CC-4", templateID: "ABN-CC", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Runway \(rwySpoken), cleared for take-off, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "RUNWAY", expectedValue: rwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CLEARED_TAKEOFF", expectedValue: "cleared for take-off", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK TAKE-OFF"
            ))
            globalTurn += 1
            executedContingencies.append(ccCont)

        } else if let immCont = contingencies.first(where: { $0.title.contains("Immediate Take-off or Vacate") }) {
            exchanges.append(FilledExchange(
                exchangeID: "ABN-IMM-TO-1", templateID: "ABN-IMM-TO", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), traffic Boeing seven three seven on two miles final, take off immediately or vacate runway!",
                criticalSlots: [], severity: .abnormal, eventTag: "TAKEOFF IMMEDIATELY OR VACATE"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-IMM-TO-2", templateID: "ABN-IMM-TO", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Taking off immediately, \(callsign)!",
                criticalSlots: [
                    CriticalSlot(slot: "TAKING_OFF", expectedValue: "taking off immediately", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .abnormal, eventTag: "TAKING OFF IMMEDIATELY"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-IMM-TO-3", templateID: "ABN-IMM-TO", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), runway \(rwySpoken), wind \(windSpoken), cleared for immediate take-off.",
                criticalSlots: [], severity: .normal, eventTag: "CLEARED IMMEDIATE TAKE-OFF"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-IMM-TO-4", templateID: "ABN-IMM-TO", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Runway \(rwySpoken), cleared for immediate take-off, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "RUNWAY", expectedValue: rwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CLEARED_TAKEOFF", expectedValue: "cleared for immediate take-off", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK IMMEDIATE TAKE-OFF"
            ))
            globalTurn += 1
            executedContingencies.append(immCont)

        } else {
            let toText = (level == .level1) ? "cleared touch-and-go, make left traffic" : "cleared for take-off"
            exchanges.append(FilledExchange(
                exchangeID: "DP-TO-CLR-1", templateID: "DP-04", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), runway \(rwySpoken), wind \(windSpoken), \(toText).",
                criticalSlots: [], severity: .normal, eventTag: "CLEARED FOR TAKE-OFF"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "DP-TO-CLR-2", templateID: "DP-04", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Runway \(rwySpoken), \(toText), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "RUNWAY", expectedValue: rwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CLEARED_TAKEOFF", expectedValue: toText, type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK TAKE-OFF"
            ))
            globalTurn += 1
        }

        // STEP 5: TAKE-OFF ROLL EMERGENCIES (ABORT / EFATO)
        if let abtCont = contingencies.first(where: { $0.title.contains("Abort Take-Off") || $0.title.contains("Rejected Take-Off") }) {
            isFlightTerminatedEarly = true

            // ATC-Initiated Abort (ICAO Doc 9432 Bab 4.5.11): Vehicle entering runway
            exchanges.append(FilledExchange(
                exchangeID: "ABN-ABT-TO-1", templateID: "ABN-ABT-TO", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "STOP IMMEDIATELY, \(callsign), STOP IMMEDIATELY, vehicle entering runway!",
                criticalSlots: [], severity: .distress, eventTag: "STOP IMMEDIATELY"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-ABT-TO-2", templateID: "ABN-ABT-TO", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "STOPPING, ABORTING TAKE-OFF, \(callsign)!",
                criticalSlots: [
                    CriticalSlot(slot: "STOPPING", expectedValue: "stopping", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "ABORT_TAKEOFF", expectedValue: "aborting take-off", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .distress, eventTag: "STOPPING & ABORTING"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-ABT-TO-3", templateID: "ABN-ABT-TO", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), roger stopping, emergency equipment alerted and rolling to your position, advise when stopped.",
                criticalSlots: [], severity: .abnormal, eventTag: "ARFF ALERTED"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-ABT-TO-4", templateID: "ABN-ABT-TO", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Stopped on runway \(rwySpoken), brakes hot, tires intact, no assistance required, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "STOPPED_RUNWAY", expectedValue: "stopped on runway", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "RUNWAY", expectedValue: rwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .abnormal, eventTag: "STOPPED ON RUNWAY REPORT"
            ))
            globalTurn += 1

            executedContingencies.append(abtCont)
            return exchanges

        } else if let bStrikeCont = contingencies.first(where: { $0.title.contains("Bird Strike on Take-off") }) {
            isFlightTerminatedEarly = true

            // Pilot-Initiated Abort (ICAO Doc 9432 Bab 4.5.12): Flock crossing alert -> Bird strike reject
            exchanges.append(FilledExchange(
                exchangeID: "DIS-BRD-STRK-1", templateID: "DIS-BRD-STRK", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), caution large flock of birds crossing runway ahead near threshold!",
                criticalSlots: [], severity: .abnormal, eventTag: "FLOCK CROSSING WARNING"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "DIS-BRD-STRK-2", templateID: "DIS-BRD-STRK", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "STOPPING, ABORTING TAKE-OFF, BIRD STRIKE ENGINE NUMBER TWO, \(callsign)!",
                criticalSlots: [
                    CriticalSlot(slot: "STOPPING", expectedValue: "stopping", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "ABORT_TAKEOFF", expectedValue: "aborting take-off", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .distress, eventTag: "BIRD STRIKE ABORT"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "DIS-BRD-STRK-3", templateID: "DIS-BRD-STRK", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "STOP IMMEDIATELY, \(callsign), STOP IMMEDIATELY, emergency equipment alerted and rolling to your position!",
                criticalSlots: [], severity: .distress, eventTag: "STOP IMMEDIATELY & ARFF"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "DIS-BRD-STRK-4", templateID: "DIS-BRD-STRK", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Stopped on runway \(rwySpoken), bird strike engine number two, vibration, engine shut down, brakes hot, request fire crew inspection, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "STOPPED_RUNWAY", expectedValue: "stopped on runway", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "RUNWAY", expectedValue: rwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .distress, eventTag: "STOPPED BIRD STRIKE"
            ))
            globalTurn += 1

            executedContingencies.append(bStrikeCont)
            return exchanges

        } else if let efatoCont = contingencies.first(where: { $0.title.contains("EFATO") }) {
            isFlightTerminatedEarly = true

            exchanges.append(FilledExchange(
                exchangeID: "DIS-EFA-1", templateID: "DIS-EFA", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), verify airborne, smoke reported from engine!",
                criticalSlots: [], severity: .distress, eventTag: "SMOKE REPORTED"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "DIS-EFA-2", templateID: "DIS-EFA", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "MAYDAY MAYDAY MAYDAY, \(twrUnit), \(callsign), engine failure after takeoff at five hundred feet, forced landing straight ahead runway \(rwySpoken), two persons on board!",
                criticalSlots: [
                    CriticalSlot(slot: "DISTRESS", expectedValue: "mayday mayday mayday", type: "mandatoryDistress"),
                    CriticalSlot(slot: "RUNWAY", expectedValue: rwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .distress, eventTag: "MAYDAY EFATO"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "DIS-EFA-3", templateID: "DIS-EFA", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(twrUnit), roger MAYDAY, runway \(rwySpoken), wind \(windSpoken), cleared to land, emergency equipment rolling.",
                criticalSlots: [], severity: .distress, eventTag: "CLEARED TO LAND EMERGENCY"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "DIS-EFA-4", templateID: "DIS-EFA", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Runway \(rwySpoken), cleared to land, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "RUNWAY", expectedValue: rwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CLEARED_TO_LAND", expectedValue: "cleared to land", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .distress, eventTag: "READBACK EMERGENCY LANDING"
            ))
            globalTurn += 1

            executedContingencies.append(efatoCont)
            return exchanges
        }

        // STEP 6: AIRBORNE HANDOFF (Continuing flights)
        let depRadarCallsign = context.unitDeparture?.callsign ?? "Departure"
        let depRadarFreq = context.depFreq

        exchanges.append(FilledExchange(
            exchangeID: "DP-ABN-1", templateID: "DP-05", turn: globalTurn, speaker: "ATC",
            isUserTurn: (role == .atc),
            text: "\(callsign), airborne time zero four, contact \(depRadarCallsign) \(depRadarFreq).",
            criticalSlots: [], severity: .normal, eventTag: "AIRBORNE HANDOFF"
        ))
        globalTurn += 1

        exchanges.append(FilledExchange(
            exchangeID: "DP-ABN-2", templateID: "DP-05", turn: globalTurn, speaker: "PILOT",
            isUserTurn: (role == .pilot),
            text: "\(depRadarCallsign) \(depRadarFreq), \(callsign).",
            criticalSlots: [
                CriticalSlot(slot: "DEPARTURE_FREQ", expectedValue: depRadarFreq, type: "mandatoryFrequency"),
                CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
            ], severity: .normal, eventTag: "READBACK DEPARTURE FREQ"
        ))
        globalTurn += 1

        return exchanges
    }
    // MARK: - Phase 3: En-Route Builder
    private func buildEnRouteExchanges(
        level: CurriculumLevel,
        seed: Int,
        role: UserRole,
        context: SlotContext,
        contingencies: [InjectedContingency],
        executedContingencies: inout [InjectedContingency],
        globalTurn: inout Int
    ) -> [FilledExchange] {
        var exchanges: [FilledExchange] = []
        let callsign = context.callsign
        let ctrlUnit = context.unitControl?.callsign ?? "Control"
        let cruisingLevel = context.currentLevel
        let curPos = context.currentPosition
        let nextPos = context.nextPosition
        let qnhSpoken = SpokenFormFormatter.qnh(context.weather.qnh)

        // 1. Weather Deviation (CB Avoidance)
        if let wxCont = contingencies.first(where: { $0.title.contains("Weather Deviation") }) {
            exchanges.append(FilledExchange(
                exchangeID: "ER-WX-1", templateID: "ER-01", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(ctrlUnit), radar contact, climb and maintain \(cruisingLevel), advise if weather avoidance required.",
                criticalSlots: [], severity: .normal, eventTag: "RADAR CONTACT"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-WX-DEV-1", templateID: "ABN-WX-DEV", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "\(ctrlUnit), \(callsign), request deviation one five miles right of track due weather.",
                criticalSlots: [
                    CriticalSlot(slot: "REQUEST", expectedValue: "request deviation", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "REASON", expectedValue: "weather", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .abnormal, eventTag: "WEATHER DEVIATION REQUEST"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-WX-DEV-2", templateID: "ABN-WX-DEV", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), deviation one five miles right of track approved, advise when able to resume flight planned route.",
                criticalSlots: [], severity: .normal, eventTag: "DEVIATION APPROVED"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-WX-DEV-3", templateID: "ABN-WX-DEV", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Deviation one five miles right of track approved, will report resuming navigation, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "DIRECTION", expectedValue: "right of track", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK DEVIATION"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-WX-DEV-4", templateID: "ABN-WX-DEV", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), advise clear of weather.",
                criticalSlots: [], severity: .normal, eventTag: "ADVISE CLEAR"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-WX-DEV-5", templateID: "ABN-WX-DEV", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "\(ctrlUnit), \(callsign), clear of weather, request resume own navigation direct \(nextPos).",
                criticalSlots: [
                    CriticalSlot(slot: "CLEAR_WX", expectedValue: "clear of weather", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "CLEAR OF WEATHER"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-WX-DEV-6", templateID: "ABN-WX-DEV", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), resume own navigation direct \(nextPos), maintain \(cruisingLevel).",
                criticalSlots: [], severity: .normal, eventTag: "RESUME OWN NAVIGATION"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-WX-DEV-7", templateID: "ABN-WX-DEV", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Resume own navigation direct \(nextPos), maintain \(cruisingLevel), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "WAYPOINT", expectedValue: nextPos, type: "mandatoryWaypoint"),
                    CriticalSlot(slot: "ALTITUDE", expectedValue: cruisingLevel, type: "mandatoryAltitude"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK RESUME NAVIGATION"
            ))
            globalTurn += 1

            executedContingencies.append(wxCont)
            return exchanges

        // 2. Radar Avoiding Action (Near Miss)
        } else if let avoidCont = contingencies.first(where: { $0.title.contains("Avoiding Action") }) {
            exchanges.append(FilledExchange(
                exchangeID: "ER-AVD-1", templateID: "ER-01", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(ctrlUnit), radar contact, climb and maintain \(cruisingLevel).",
                criticalSlots: [], severity: .normal, eventTag: "RADAR CONTACT"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-AVD-2", templateID: "ER-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Climb and maintain \(cruisingLevel), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "ALTITUDE", expectedValue: cruisingLevel, type: "mandatoryAltitude"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK CLIMB"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-AVD-1", templateID: "ABN-AVD", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), AVOIDING ACTION, turn left immediately heading two seven zero, traffic twelve o'clock four miles opposite direction converging!",
                criticalSlots: [], severity: .distress, eventTag: "RADAR AVOIDING ACTION"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-AVD-2", templateID: "ABN-AVD", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Turning left immediately heading two seven zero, avoiding action, \(callsign)!",
                criticalSlots: [
                    CriticalSlot(slot: "HEADING", expectedValue: "heading two seven zero", type: "mandatoryHeading"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .distress, eventTag: "READBACK AVOIDING ACTION"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-AVD-3", templateID: "ABN-AVD", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), clear of traffic, resume own navigation direct \(nextPos), maintain \(cruisingLevel).",
                criticalSlots: [], severity: .normal, eventTag: "CLEAR OF TRAFFIC"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-AVD-4", templateID: "ABN-AVD", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Resume own navigation direct \(nextPos), maintain \(cruisingLevel), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "WAYPOINT", expectedValue: nextPos, type: "mandatoryWaypoint"),
                    CriticalSlot(slot: "ALTITUDE", expectedValue: cruisingLevel, type: "mandatoryAltitude"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK CLEAR OF TRAFFIC"
            ))
            globalTurn += 1

            executedContingencies.append(avoidCont)
            return exchanges

        // 3. Mid-Air Engine Failure (Diversion ASSIST)
        } else if let engOut = contingencies.first(where: { $0.title.contains("Mid-Air Engine") }) {
            exchanges.append(FilledExchange(
                exchangeID: "ER-ENG-1", templateID: "ER-01", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(ctrlUnit), radar contact, maintain \(cruisingLevel).",
                criticalSlots: [], severity: .normal, eventTag: "RADAR CONTACT"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-ENG-2", templateID: "ER-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "MAYDAY MAYDAY MAYDAY, \(ctrlUnit), \(callsign), engine number one failed, unable to maintain \(cruisingLevel), request descent and diversion to nearest airport, heading two four zero!",
                criticalSlots: [
                    CriticalSlot(slot: "DISTRESS", expectedValue: "mayday mayday mayday", type: "mandatoryDistress"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .distress, eventTag: "MAYDAY ENGINE OUT"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-ENG-3", templateID: "ER-01", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(ctrlUnit), roger MAYDAY, descend and maintain flight level one zero zero, turn left heading two four zero for radar vectors direct \(context.destinationName), QNH \(qnhSpoken).",
                criticalSlots: [], severity: .distress, eventTag: "DESCENT & VECTORS MAYDAY"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-ENG-4", templateID: "ER-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Descend and maintain flight level one zero zero, turn left heading two four zero, direct \(context.destinationName), QNH \(qnhSpoken), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "ALTITUDE", expectedValue: "flight level one zero zero", type: "mandatoryAltitude"),
                    CriticalSlot(slot: "HEADING", expectedValue: "heading two four zero", type: "mandatoryHeading"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .distress, eventTag: "READBACK DESCENT MAYDAY"
            ))
            globalTurn += 1

            executedContingencies.append(engOut)
            return exchanges

        // 4. Cabin Decompression Emergency Descent
        } else if let decompCont = contingencies.first(where: { $0.title.contains("Decompression") }) {
            // Per Variabel_Dinamis.pdf: Papua Jayawijaya mountainous routes (WAVV / WABP) require descent to FL170 (Grid MORA), NOT FL100
            let isPapuaMountain = (level == .level5 || context.airport.icao == "WAVV" || context.airport.icao == "WABP" || context.destinationName.contains("Mozes Kilangin") || context.destinationName.contains("Wamena") || context.destinationName.contains("Timika"))
            let decompAltitude = isPapuaMountain ? "flight level one seven zero" : "flight level one zero zero"
            let decompHeading = isPapuaMountain ? "heading two four zero" : "heading one eight zero"

            exchanges.append(FilledExchange(
                exchangeID: "ER-DEC-1", templateID: "ER-01", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(ctrlUnit), radar contact, maintaining \(cruisingLevel).",
                criticalSlots: [], severity: .normal, eventTag: "RADAR CONTACT"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-DEC-2", templateID: "ER-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "MAYDAY MAYDAY MAYDAY, \(ctrlUnit), \(callsign), rapid decompression, emergency descent \(decompAltitude), turning right \(decompHeading)!",
                criticalSlots: [
                    CriticalSlot(slot: "DISTRESS", expectedValue: "mayday mayday mayday", type: "mandatoryDistress"),
                    CriticalSlot(slot: "ALTITUDE", expectedValue: decompAltitude, type: "mandatoryAltitude"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .distress, eventTag: "MAYDAY EMERGENCY DESCENT"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-DEC-3", templateID: "ER-01", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(ctrlUnit), roger emergency descent, cleared \(decompAltitude), turn right \(decompHeading), QNH one zero one zero, airspace clear.",
                criticalSlots: [], severity: .distress, eventTag: "CLEARED EMERGENCY DESCENT"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-DEC-4", templateID: "ER-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Cleared \(decompAltitude), \(decompHeading), QNH one zero one zero, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "ALTITUDE", expectedValue: decompAltitude, type: "mandatoryAltitude"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .distress, eventTag: "READBACK EMERGENCY DESCENT"
            ))
            globalTurn += 1

            executedContingencies.append(decompCont)
            return exchanges

        // 5. TCAS Resolution Advisory
        } else if let tcasCont = contingencies.first(where: { $0.title.contains("TCAS") }) {
            exchanges.append(FilledExchange(
                exchangeID: "ER-TCAS-1", templateID: "ER-01", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), climb and maintain \(cruisingLevel).",
                criticalSlots: [], severity: .normal, eventTag: "CLIMB INSTRUCTION"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-TCAS-2", templateID: "ER-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "TCAS RA, \(callsign)!",
                criticalSlots: [
                    CriticalSlot(slot: "TCAS_RA", expectedValue: "tcas ra", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .distress, eventTag: "TCAS RA NOTIFICATION"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-TCAS-3", templateID: "ER-01", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), roger.",
                criticalSlots: [], severity: .normal, eventTag: "ROGER TCAS"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-TCAS-4", templateID: "ER-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Clear of conflict, flight level two six zero, resuming flight level two four zero, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "CLEAR_OF_CONFLICT", expectedValue: "clear of conflict", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "CLEAR OF CONFLICT"
            ))
            globalTurn += 1

            executedContingencies.append(tcasCont)
            return exchanges
        }

        // Routine En-Route:
        if level == .level1 {
            let activeRwy = SpokenFormFormatter.runway(context.selectedRunway.designator)
            let qnhSpoken = SpokenFormFormatter.qnh(context.weather.qnh)
            exchanges.append(FilledExchange(
                exchangeID: "ER-VFR-1", templateID: "ER-01", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(context.unitTower?.callsign ?? "Tower"), radar contact south training area, maintain visual flight rules three thousand feet, report maneuvers completed.",
                criticalSlots: [], severity: .normal, eventTag: "RADAR CONTACT VFR"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-VFR-2", templateID: "ER-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Maintain visual flight rules three thousand feet, will report maneuvers completed, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK VFR"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-VFR-3", templateID: "ER-01", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), advise intentions.",
                criticalSlots: [], severity: .normal, eventTag: "ADVISE INTENTIONS"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-VFR-4", templateID: "ER-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "\(context.unitTower?.callsign ?? "Tower"), \(callsign), training maneuvers completed, request inbound for circuit touch-and-go.",
                criticalSlots: [
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "REQUEST INBOUND"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-VFR-5", templateID: "ER-01", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), join right downwind runway \(activeRwy), QNH \(qnhSpoken), report downwind.",
                criticalSlots: [], severity: .normal, eventTag: "JOIN DOWNWIND"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-VFR-6", templateID: "ER-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Join right downwind runway \(activeRwy), QNH \(qnhSpoken), will report downwind, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "RUNWAY", expectedValue: activeRwy, type: "mandatoryRunway"),
                    CriticalSlot(slot: "QNH", expectedValue: qnhSpoken, type: "mandatoryQnh"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK DOWNWIND"
            ))
            globalTurn += 1

        } else if level == .level2 {
            // Level 2: Regional Controlled (Departure check-in, climb to cruising level, transfer to ACC)
            let depRadarCallsign = context.unitDeparture?.callsign ?? "Departure"
            exchanges.append(FilledExchange(
                exchangeID: "ER-L2-DEP-CHK", templateID: "ER-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "\(depRadarCallsign), \(callsign), airborne passing one thousand five hundred feet, climbing \(context.initialAlt).",
                criticalSlots: [
                    CriticalSlot(slot: "ALTITUDE", expectedValue: context.initialAlt, type: "mandatoryAltitude"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "DEPARTURE CHECK-IN"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-L2-1", templateID: "ER-01", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(depRadarCallsign), radar contact, climb and maintain flight level zero eight zero, report reaching. When passing flight level zero eight zero, contact \(ctrlUnit) \(context.controlFreq).",
                criticalSlots: [], severity: .normal, eventTag: "RADAR CONTACT FL080"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-L2-2", templateID: "ER-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Climb and maintain flight level zero eight zero, will report reaching, contact \(ctrlUnit) \(context.controlFreq), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "ALTITUDE", expectedValue: "flight level zero eight zero", type: "mandatoryAltitude"),
                    CriticalSlot(slot: "CONTROL_FREQ", expectedValue: context.controlFreq, type: "mandatoryFrequency"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK CLIMB"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-L2-3", templateID: "ER-02", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), report level flight level zero eight zero.",
                criticalSlots: [], severity: .normal, eventTag: "REPORT LEVEL"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-L2-4", templateID: "ER-02", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "\(ctrlUnit), \(callsign), reaching flight level zero eight zero.",
                criticalSlots: [
                    CriticalSlot(slot: "ALTITUDE", expectedValue: "flight level zero eight zero", type: "mandatoryAltitude"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "REPORT REACHING LEVEL"
            ))
            globalTurn += 1

            if let unCont = contingencies.first(where: { $0.title.contains("Unable Altitude") }) {
                exchanges.append(FilledExchange(
                    exchangeID: "ABN-UNA-1", templateID: "ABN-UNA", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), \(ctrlUnit), climb and maintain flight level one two zero, expedite climb.",
                    criticalSlots: [], severity: .abnormal, eventTag: "EXPEDITE CLIMB FL120"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-UNA-2", templateID: "ABN-UNA", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "UNABLE flight level one two zero due performance, request maintain flight level zero eight zero, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "UNABLE", expectedValue: "unable", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .abnormal, eventTag: "DECLARING UNABLE DUE PERFORMANCE"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-UNA-3", templateID: "ABN-UNA", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), roger, maintain flight level zero eight zero, direct \(nextPos).",
                    criticalSlots: [], severity: .normal, eventTag: "MAINTAIN CRUISE"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-UNA-4", templateID: "ABN-UNA", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Maintain flight level zero eight zero, direct \(nextPos), \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "ALTITUDE", expectedValue: "flight level zero eight zero", type: "mandatoryAltitude"),
                        CriticalSlot(slot: "WAYPOINT", expectedValue: nextPos, type: "mandatoryWaypoint"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .normal, eventTag: "READBACK CRUISE"
                ))
                globalTurn += 1
                executedContingencies.append(unCont)

            } else {
                exchanges.append(FilledExchange(
                    exchangeID: "ER-L2-5", templateID: "ER-02", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), roger, maintain flight level zero eight zero, direct \(nextPos).",
                    criticalSlots: [], severity: .normal, eventTag: "MAINTAIN CRUISE"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ER-L2-6", templateID: "ER-02", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Maintain flight level zero eight zero, direct \(nextPos), \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "ALTITUDE", expectedValue: "flight level zero eight zero", type: "mandatoryAltitude"),
                        CriticalSlot(slot: "WAYPOINT", expectedValue: nextPos, type: "mandatoryWaypoint"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .normal, eventTag: "READBACK CRUISE"
                ))
                globalTurn += 1
            }

        } else {
            // Levels 3, 4, 5: Jet transport climbing & cruising with initial check-in & frequency handoff
            let depRadarCallsign = context.unitDeparture?.callsign ?? "Departure"
            exchanges.append(FilledExchange(
                exchangeID: "ER-DEP-CHK", templateID: "ER-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "\(depRadarCallsign), \(callsign), airborne passing one thousand five hundred feet, climbing \(context.initialAlt).",
                criticalSlots: [
                    CriticalSlot(slot: "ALTITUDE", expectedValue: context.initialAlt, type: "mandatoryAltitude"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "DEPARTURE CHECK-IN"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-DEP-RAD", templateID: "ER-01", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(depRadarCallsign), radar contact, climb flight level one zero zero. When passing flight level one zero zero, contact \(ctrlUnit) \(context.controlFreq).",
                criticalSlots: [], severity: .normal, eventTag: "TRANSFER CONTROL"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-DEP-ACK", templateID: "ER-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Climb flight level one zero zero, contact \(ctrlUnit) \(context.controlFreq), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "CONTROL_FREQ", expectedValue: context.controlFreq, type: "mandatoryFrequency"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK TRANSFER"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-ACC-CHK", templateID: "ER-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "\(ctrlUnit), \(callsign), passing flight level one zero zero climbing \(cruisingLevel), direct \(curPos).",
                criticalSlots: [
                    CriticalSlot(slot: "ALTITUDE", expectedValue: cruisingLevel, type: "mandatoryAltitude"),
                    CriticalSlot(slot: "WAYPOINT", expectedValue: curPos, type: "mandatoryWaypoint"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "AREA CONTROL CHECK-IN"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-JET-1", templateID: "ER-01", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(ctrlUnit), radar contact, climb and maintain \(cruisingLevel), direct \(curPos).",
                criticalSlots: [], severity: .normal, eventTag: "RADAR CONTACT"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-JET-2", templateID: "ER-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Climb and maintain \(cruisingLevel), direct \(curPos), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "ALTITUDE", expectedValue: cruisingLevel, type: "mandatoryAltitude"),
                    CriticalSlot(slot: "WAYPOINT", expectedValue: curPos, type: "mandatoryWaypoint"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK CLIMB"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-JET-3", templateID: "ER-02", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), report reaching \(cruisingLevel).",
                criticalSlots: [], severity: .normal, eventTag: "REPORT LEVEL"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-JET-4", templateID: "ER-02", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "\(ctrlUnit), \(callsign), reaching \(cruisingLevel).",
                criticalSlots: [
                    CriticalSlot(slot: "ALTITUDE", expectedValue: cruisingLevel, type: "mandatoryAltitude"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "REACHING LEVEL"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-JET-5", templateID: "ER-02", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), roger, maintain \(cruisingLevel).",
                criticalSlots: [], severity: .normal, eventTag: "MAINTAIN LEVEL"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ER-JET-6", templateID: "ER-02", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Maintain \(cruisingLevel), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "ALTITUDE", expectedValue: cruisingLevel, type: "mandatoryAltitude"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK MAINTAIN"
            ))
            globalTurn += 1

            // EN-ROUTE CONTINGENCIES (Levels 3, 4, 5)
            if let holdCont = contingencies.first(where: { $0.title.contains("Holding Pattern & EAT") }) {
                exchanges.append(FilledExchange(
                    exchangeID: "ABN-HLD-1", templateID: "ABN-HLD", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), \(ctrlUnit), hold at \(nextPos) VOR, inbound track two seven zero degrees, right hand pattern, flight level two five zero, expected approach time zero two four five.",
                    criticalSlots: [], severity: .abnormal, eventTag: "HOLD AT VOR WITH EAT"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-HLD-2", templateID: "ABN-HLD", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Hold at \(nextPos), inbound track two seven zero, right hand pattern, flight level two five zero, expected approach time zero two four five, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "WAYPOINT", expectedValue: nextPos, type: "mandatoryWaypoint"),
                        CriticalSlot(slot: "HOLD", expectedValue: "hold at", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .abnormal, eventTag: "READBACK HOLDING WITH EAT"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-HLD-3", templateID: "ABN-HLD", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), leave \(nextPos) heading one eight zero, resume descent.",
                    criticalSlots: [], severity: .normal, eventTag: "LEAVE HOLD"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-HLD-4", templateID: "ABN-HLD", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Leave \(nextPos) heading one eight zero, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "HEADING", expectedValue: "heading one eight zero", type: "mandatoryHeading"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .normal, eventTag: "READBACK LEAVE HOLD"
                ))
                globalTurn += 1
                executedContingencies.append(holdCont)

            } else if let slopCont = contingencies.first(where: { $0.title.contains("Strategic Lateral Offset") }) {
                exchanges.append(FilledExchange(
                    exchangeID: "ABN-SLOP-1", templateID: "ABN-SLOP", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "\(ctrlUnit), \(callsign), executing strategic lateral offset, one nautical mile right of track.",
                    criticalSlots: [
                        CriticalSlot(slot: "SLOP", expectedValue: "strategic lateral offset", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .abnormal, eventTag: "REPORT SLOP EXECUTION"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-SLOP-2", templateID: "ABN-SLOP", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), roger SLOP one mile right, report returning to centerline.",
                    criticalSlots: [], severity: .normal, eventTag: "ROGER SLOP"
                ))
                globalTurn += 1
                executedContingencies.append(slopCont)

            } else if let fdCont = contingencies.first(where: { $0.title.contains("Fuel Dumping") }) {
                exchanges.append(FilledExchange(
                    exchangeID: "ABN-FD-1", templateID: "ABN-FD", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "PAN PAN, PAN PAN, PAN PAN, \(ctrlUnit), \(callsign), request fuel dumping area between flight level one zero zero and flight level one four zero due overweight landing.",
                    criticalSlots: [
                        CriticalSlot(slot: "PAN_PAN", expectedValue: "pan pan", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "FUEL_DUMP", expectedValue: "fuel dumping", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .urgency, eventTag: "REQUEST FUEL DUMPING"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-FD-2", templateID: "ABN-FD", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), roger PAN PAN, fuel dumping approved over ocean sector, track one eight zero, report completed.",
                    criticalSlots: [], severity: .urgency, eventTag: "FUEL DUMPING APPROVED"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-FD-3", templateID: "ABN-FD", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Fuel dumping approved track one eight zero, will report completed, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .urgency, eventTag: "READBACK FUEL DUMP"
                ))
                globalTurn += 1
                executedContingencies.append(fdCont)

            } else if let vaCont = contingencies.first(where: { $0.title.contains("Volcanic Ash") }) {
                exchanges.append(FilledExchange(
                    exchangeID: "ABN-VA-1", templateID: "ABN-VA", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "\(ctrlUnit), \(callsign), volcanic ash cloud sighted ahead, request immediate deviation left thirty degrees, twenty miles.",
                    criticalSlots: [
                        CriticalSlot(slot: "VOLCANIC_ASH", expectedValue: "volcanic ash", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "DEVIATION", expectedValue: "deviation left", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .urgency, eventTag: "REQUEST ASH DEVIATION"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-VA-2", templateID: "ABN-VA", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), left turn thirty degrees approved, deviate twenty miles left of track, advise clear of ash.",
                    criticalSlots: [], severity: .urgency, eventTag: "DEVIATION APPROVED"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-VA-3", templateID: "ABN-VA", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Turn left thirty degrees, deviate twenty miles, will advise clear of ash, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .urgency, eventTag: "READBACK ASH DEVIATION"
                ))
                globalTurn += 1
                executedContingencies.append(vaCont)

            } else if let hjCont = contingencies.first(where: { $0.title.contains("Unlawful Interference") || $0.title.contains("7500") }) {
                exchanges.append(FilledExchange(
                    exchangeID: "ABN-HJ-1", templateID: "ABN-HJ", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), \(ctrlUnit), squawk seven five zero zero observed, confirm squawk assigned.",
                    criticalSlots: [], severity: .distress, eventTag: "CONFIRM SQUAWK 7500"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-HJ-2", templateID: "ABN-HJ", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "AFFIRM, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "AFFIRM", expectedValue: "affirm", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .distress, eventTag: "DISCREET SQUAWK 7500 CONFIRMATION"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-HJ-3", templateID: "ABN-HJ", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), roger, proceed direct destination, continue present heading and level, radar monitoring.",
                    criticalSlots: [], severity: .distress, eventTag: "HIJACK RADAR MONITORING"
                ))
                globalTurn += 1
                executedContingencies.append(hjCont)

            } else if let miCont = contingencies.first(where: { $0.title.contains("Military Interception") }) {
                exchanges.append(FilledExchange(
                    exchangeID: "ABN-MI-1", templateID: "ABN-MI", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), \(ctrlUnit), you are intercepted by military aircraft on your left side, acknowledge visual signals and follow escort.",
                    criticalSlots: [], severity: .urgency, eventTag: "MILITARY INTERCEPT NOTIFICATION"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-MI-2", templateID: "ABN-MI", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "WILCO, escort aircraft in sight, following escort heading two four zero, descending five thousand feet, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "WILCO", expectedValue: "wilco", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .urgency, eventTag: "COMPLYING WITH INTERCEPTION"
                ))
                globalTurn += 1
                executedContingencies.append(miCont)
            }
        }

        return exchanges
    }

    // MARK: - Phase 4: Arrival Builder (Full ICAO STAR Profile & Constraints)
    private func buildArrivalExchanges(
        level: CurriculumLevel,
        seed: Int,
        role: UserRole,
        context: SlotContext,
        contingencies: [InjectedContingency],
        executedContingencies: inout [InjectedContingency],
        globalTurn: inout Int
    ) -> [FilledExchange] {
        var exchanges: [FilledExchange] = []
        let callsign = context.callsign
        let ctrlUnit = context.unitControl?.callsign ?? "Control"
        let appUnit = context.unitApproach?.callsign ?? "Approach"
        let appFreq = context.approachFreq
        let starName = context.starProcedure
        let qnhSpoken = SpokenFormFormatter.qnh(context.weather.qnh)
        let arrRwySpoken = context.arrRunway
        let _ = context.destinationName

        // Bridged Emergency Inbound from En-Route Engine Failure (MAYDAY)
        if let engCont = contingencies.first(where: { $0.title.contains("Mid-Air Engine") || $0.title.contains("Engine Failure") }) {
            if !executedContingencies.contains(where: { $0.title == engCont.title }) {
                executedContingencies.append(engCont)
            }
            exchanges.append(FilledExchange(
                exchangeID: "AR-ENG-1", templateID: "AR-01", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(ctrlUnit), passing flight level one zero zero, contact \(appUnit) on emergency frequency \(appFreq), emergency vectors coordinated.",
                criticalSlots: [], severity: .distress, eventTag: "EMERGENCY HANDOFF"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AR-ENG-2", templateID: "AR-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Contacting \(appUnit) \(appFreq), MAYDAY, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "APPROACH_FREQ", expectedValue: appFreq, type: "mandatoryFrequency"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .distress, eventTag: "READBACK TRANSFER"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AR-ENG-3", templateID: "AR-02", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "\(appUnit), \(callsign), single-engine MAYDAY in descent passing six thousand feet, direct for ILS runway \(arrRwySpoken).",
                criticalSlots: [
                    CriticalSlot(slot: "DISTRESS", expectedValue: "mayday", type: "mandatoryDistress"),
                    CriticalSlot(slot: "RUNWAY", expectedValue: arrRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .distress, eventTag: "CHECK-IN SINGLE ENGINE"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AR-ENG-4", templateID: "AR-02", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(appUnit), radar contact, continue descent to three thousand feet, QNH \(qnhSpoken), straight-in ILS runway \(arrRwySpoken), emergency vehicles are in position on taxiway, you are number one.",
                criticalSlots: [], severity: .distress, eventTag: "CLEARED STRAIGHT-IN MAYDAY"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AR-ENG-5", templateID: "AR-03", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Descend three thousand feet, QNH \(qnhSpoken), straight-in ILS runway \(arrRwySpoken), number one, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "ALTITUDE", expectedValue: "three thousand feet", type: "mandatoryAltitude"),
                    CriticalSlot(slot: "QNH", expectedValue: qnhSpoken, type: "mandatoryQnh"),
                    CriticalSlot(slot: "RUNWAY", expectedValue: arrRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .distress, eventTag: "READBACK STRAIGHT-IN"
            ))
            globalTurn += 1

            return exchanges
        }

        // Emergency / Urgency: Passenger Medical Emergency
        if let medCont = contingencies.first(where: { $0.title.contains("Medical") }) {
            exchanges.append(FilledExchange(
                exchangeID: "AR-MED-1", templateID: "AR-01", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(ctrlUnit), advise status for descent.",
                criticalSlots: [], severity: .normal, eventTag: "ADVISE DESCENT"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-MED-1", templateID: "ABN-MED", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "PAN PAN, PAN PAN, PAN PAN, passenger suspected heart attack on board, request priority straight-in approach runway \(arrRwySpoken) and ambulance to meet aircraft at gate!",
                criticalSlots: [
                    CriticalSlot(slot: "URGENCY", expectedValue: "pan pan, pan pan, pan pan", type: "mandatoryUrgency"),
                    CriticalSlot(slot: "RUNWAY", expectedValue: arrRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .urgency, eventTag: "PAN PAN MEDICAL PRIORITY"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-MED-2", templateID: "ABN-MED", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), priority straight-in approach runway \(arrRwySpoken) approved, descend to three thousand feet, QNH \(qnhSpoken), medical ambulance standing by. Contact \(appUnit) \(appFreq).",
                criticalSlots: [], severity: .urgency, eventTag: "PRIORITY STRAIGHT-IN APPROVED"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-MED-3", templateID: "ABN-MED", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Priority straight-in approach runway \(arrRwySpoken), descend three thousand feet, QNH \(qnhSpoken), contact \(appUnit) \(appFreq), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "RUNWAY", expectedValue: arrRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "ALTITUDE", expectedValue: "three thousand feet", type: "mandatoryAltitude"),
                    CriticalSlot(slot: "QNH", expectedValue: qnhSpoken, type: "mandatoryQnh"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .urgency, eventTag: "READBACK MEDICAL"
            ))
            globalTurn += 1

            executedContingencies.append(medCont)
            return exchanges
        }

        if level == .level1 {
            // Level 1: Local VFR traffic pattern rejoin (4 turns)
            exchanges.append(FilledExchange(
                exchangeID: "AR-VFR-1", templateID: "AR-01", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), five miles south, descend to altitude one thousand five hundred feet, QNH \(qnhSpoken), report airfield in sight.",
                criticalSlots: [], severity: .normal, eventTag: "DESCEND PATTERN ALTITUDE"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AR-VFR-2", templateID: "AR-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Descend to altitude one thousand five hundred feet, QNH \(qnhSpoken), will report airfield in sight, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "ALTITUDE", expectedValue: "one thousand five hundred feet", type: "mandatoryAltitude"),
                    CriticalSlot(slot: "QNH", expectedValue: qnhSpoken, type: "mandatoryQnh"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK ALTITUDE & QNH"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AR-VFR-3", templateID: "AR-02", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), join right downwind runway \(arrRwySpoken), QNH \(qnhSpoken), report downwind.",
                criticalSlots: [], severity: .normal, eventTag: "JOIN RIGHT DOWNWIND"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AR-VFR-4", templateID: "AR-02", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Join right downwind runway \(arrRwySpoken), QNH \(qnhSpoken), will report downwind, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "RUNWAY", expectedValue: arrRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "QNH", expectedValue: qnhSpoken, type: "mandatoryQnh"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK DOWNWIND"
            ))
            globalTurn += 1

        } else if level == .level2 {
            // Level 2: Point-to-Point BWX -> DPS (Cruising FL080 -> Descent to 4000ft, BLI VOR constraint, 6 turns)
            exchanges.append(FilledExchange(
                exchangeID: "AR-L2-1", templateID: "AR-01", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(ctrlUnit), when ready descend to altitude four thousand feet, QNH \(qnhSpoken), cleared \(starName) arrival.",
                criticalSlots: [], severity: .normal, eventTag: "DESCENT CLEARANCE 4000FT"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AR-L2-2", templateID: "AR-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Descend to altitude four thousand feet, QNH \(qnhSpoken), cleared \(starName) arrival, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "ALTITUDE", expectedValue: "altitude four thousand feet", type: "mandatoryAltitude"),
                    CriticalSlot(slot: "QNH", expectedValue: qnhSpoken, type: "mandatoryQnh"),
                    CriticalSlot(slot: "STAR", expectedValue: starName, type: "mandatoryStar"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK DESCENT"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AR-L2-3", templateID: "AR-02", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), cross BLI VOR at altitude four thousand feet, speed two zero zero knots or less.",
                criticalSlots: [], severity: .normal, eventTag: "WAYPOINT & SPEED CONSTRAINT"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AR-L2-4", templateID: "AR-02", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Cross BLI VOR at altitude four thousand feet, speed two zero zero knots, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "WAYPOINT", expectedValue: "BLI VOR", type: "mandatoryWaypoint"),
                    CriticalSlot(slot: "ALTITUDE", expectedValue: "four thousand feet", type: "mandatoryAltitude"),
                    CriticalSlot(slot: "SPEED", expectedValue: "two zero zero knots", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK CONSTRAINT"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AR-L2-5", templateID: "AR-03", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), contact \(appUnit) \(appFreq).",
                criticalSlots: [], severity: .normal, eventTag: "TRANSFER APPROACH"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AR-L2-6", templateID: "AR-03", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "\(appUnit) \(appFreq), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "APPROACH_FREQ", expectedValue: appFreq, type: "mandatoryFrequency"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK TRANSFER"
            ))
            globalTurn += 1

        } else {
            // Jet Commercial Routes (Levels 3, 4, 5): Full ICAO STAR & Descent Step-Down Profile (8 turns)
            let starFix: String
            switch level {
            case .level3: starFix = "POSOP"
            case .level4: starFix = "GANDI"
            case .level5: starFix = "BUNTA"
            default: starFix = "DOLTA"
            }

            // Step 1: Top of Descent Clearance to FL100 via STAR
            exchanges.append(FilledExchange(
                exchangeID: "AR-JET-1", templateID: "AR-01", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(ctrlUnit), when ready descend to flight level one zero zero, cleared \(starName) arrival.",
                criticalSlots: [], severity: .normal, eventTag: "DESCENT CLEARANCE FL100"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AR-JET-2", templateID: "AR-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Descend to flight level one zero zero, cleared \(starName) arrival, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "ALTITUDE", expectedValue: "flight level one zero zero", type: "mandatoryAltitude"),
                    CriticalSlot(slot: "STAR", expectedValue: starName, type: "mandatoryStar"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK DESCENT FL100"
            ))
            globalTurn += 1

            // Step 2: Waypoint Crossing Altitude & Speed Constraint (ICAO Doc 9432 Section 6.4)
            exchanges.append(FilledExchange(
                exchangeID: "AR-JET-3", templateID: "AR-02", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), cross \(starFix) at flight level one four zero, speed two two zero knots or less.",
                criticalSlots: [], severity: .normal, eventTag: "WAYPOINT & SPEED CONSTRAINT"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AR-JET-4", templateID: "AR-02", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Cross \(starFix) at flight level one four zero, speed two two zero knots, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "WAYPOINT", expectedValue: starFix, type: "mandatoryWaypoint"),
                    CriticalSlot(slot: "ALTITUDE", expectedValue: "flight level one four zero", type: "mandatoryAltitude"),
                    CriticalSlot(slot: "SPEED", expectedValue: "two two zero knots", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK CONSTRAINT"
            ))
            globalTurn += 1

            // Step 3: Transition Level Altimeter Setting & Descent to 5,000 ft (ICAO Doc 9432 Section 7.2)
            exchanges.append(FilledExchange(
                exchangeID: "AR-JET-5", templateID: "AR-03", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), descend to altitude five thousand feet, QNH \(qnhSpoken), transition level flight level zero seven zero.",
                criticalSlots: [], severity: .normal, eventTag: "ALTIMETER & TRANSITION LEVEL"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AR-JET-6", templateID: "AR-03", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Leaving flight level one zero zero descending altitude five thousand feet, QNH \(qnhSpoken), transition level zero seven zero, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "ALTITUDE", expectedValue: "altitude five thousand feet", type: "mandatoryAltitude"),
                    CriticalSlot(slot: "QNH", expectedValue: qnhSpoken, type: "mandatoryQnh"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK ALTIMETER"
            ))
            globalTurn += 1

            // Step 4: Frequency Handoff to Approach Control Unit
            exchanges.append(FilledExchange(
                exchangeID: "AR-JET-7", templateID: "AR-04", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), contact \(appUnit) \(appFreq).",
                criticalSlots: [], severity: .normal, eventTag: "TRANSFER APPROACH"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AR-JET-8", templateID: "AR-04", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "\(appUnit) \(appFreq), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "APPROACH_FREQ", expectedValue: appFreq, type: "mandatoryFrequency"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK TRANSFER"
            ))
            globalTurn += 1
        }

        // Arrival Emergencies (Communicable Disease & Fuel Emergency)
        if let cdCont = contingencies.first(where: { $0.title.contains("Communicable Disease") }) {
            exchanges.append(FilledExchange(
                exchangeID: "ABN-CD-1", templateID: "ABN-CD", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "\(ctrlUnit), \(callsign), declaring suspected communicable disease on board, passenger with acute fever and rash, request isolation stand.",
                criticalSlots: [
                    CriticalSlot(slot: "COMMUNICABLE_DISEASE", expectedValue: "communicable disease", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .abnormal, eventTag: "SUSPECTED COMMUNICABLE DISEASE"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-CD-2", templateID: "ABN-CD", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), roger, health authority notified, expect stand ninety one for medical screening.",
                criticalSlots: [], severity: .abnormal, eventTag: "ISOLATION STAND ASSIGNED"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-CD-3", templateID: "ABN-CD", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Stand ninety one for medical screening, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .abnormal, eventTag: "READBACK ISOLATION STAND"
            ))
            globalTurn += 1
            executedContingencies.append(cdCont)

        } else if let fuelCont = contingencies.first(where: { $0.title.contains("MINIMUM FUEL vs MAYDAY FUEL") || $0.title.contains("MAYDAY FUEL") }) {
            exchanges.append(FilledExchange(
                exchangeID: "ABN-FUEL-1", templateID: "ABN-FUEL", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "MAYDAY MAYDAY MAYDAY FUEL, \(ctrlUnit), \(callsign), remaining fuel thirty minutes, unable holding, request immediate landing priority!",
                criticalSlots: [
                    CriticalSlot(slot: "MAYDAY_FUEL", expectedValue: "mayday mayday mayday fuel", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .distress, eventTag: "MAYDAY FUEL DECLARATION"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-FUEL-2", templateID: "ABN-FUEL", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), roger MAYDAY FUEL, cleared direct final runway \(arrRwySpoken), you are number one for approach, emergency vehicles alerted.",
                criticalSlots: [], severity: .distress, eventTag: "MAYDAY FUEL PRIORITY APPROVED"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-FUEL-3", templateID: "ABN-FUEL", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Cleared direct final runway \(arrRwySpoken), number one, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "RUNWAY", expectedValue: arrRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .distress, eventTag: "READBACK FUEL PRIORITY"
            ))
            globalTurn += 1
            executedContingencies.append(fuelCont)
        }

        return exchanges
    }

    // MARK: - Phase 5: Approach Builder (Full ICAO Radar Vectoring & Final Intercept)
    private func buildApproachExchanges(
        level: CurriculumLevel,
        seed: Int,
        role: UserRole,
        context: SlotContext,
        contingencies: [InjectedContingency],
        executedContingencies: inout [InjectedContingency],
        globalTurn: inout Int
    ) -> [FilledExchange] {
        var exchanges: [FilledExchange] = []
        let callsign = context.callsign
        let appUnit = context.unitApproach?.callsign ?? "Approach"
        let twrUnit = context.unitTower?.callsign ?? "Tower"
        let twrFreq = SpokenFormFormatter.frequency(context.unitTower?.frequency ?? "118.100")
        let arrRwySpoken = context.arrRunway
        let qnhSpoken = SpokenFormFormatter.qnh(context.weather.qnh)
        let windSpoken = SpokenFormFormatter.wind(direction: context.weather.windDirection, knots: context.weather.windSpeed)

        // ==========================================
        // BRIDGED CONTINGENCY: SINGLE-ENGINE APPROACH FROM EN-ROUTE MAYDAY
        // ==========================================
        if let engCont = contingencies.first(where: { $0.title.contains("Mid-Air Engine") || $0.title.contains("Engine Failure") }) {
            if !executedContingencies.contains(where: { $0.title == engCont.title }) {
                executedContingencies.append(engCont)
            }
            exchanges.append(FilledExchange(
                exchangeID: "AP-ENG-1", templateID: "AP-01", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(appUnit), established on localizer, contact \(twrUnit) \(twrFreq), emergency clearance approved.",
                criticalSlots: [], severity: .distress, eventTag: "CONTACT TOWER MAYDAY"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-ENG-2", templateID: "AP-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Contacting \(twrUnit) \(twrFreq), MAYDAY, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "TOWER_FREQ", expectedValue: twrFreq, type: "mandatoryFrequency"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .distress, eventTag: "READBACK TOWER FREQ"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-ENG-3", templateID: "AP-02", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "\(twrUnit), \(callsign), four miles final runway \(arrRwySpoken), single engine operation, gear down, full emergency.",
                criticalSlots: [
                    CriticalSlot(slot: "RUNWAY", expectedValue: arrRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .distress, eventTag: "REPORT FINAL MAYDAY"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-ENG-4", templateID: "AP-02", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(twrUnit), wind \(windSpoken), runway \(arrRwySpoken), fire and rescue trucks standing by along the runway, cleared to land.",
                criticalSlots: [], severity: .distress, eventTag: "CLEARED TO LAND EMERGENCY"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-ENG-5", templateID: "AP-03", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Runway \(arrRwySpoken), cleared to land, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "RUNWAY", expectedValue: arrRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CLEARED_TO_LAND", expectedValue: "cleared to land", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .distress, eventTag: "READBACK CLEARED TO LAND"
            ))
            globalTurn += 1

            return exchanges
        }

        // ==========================================
        // CONTINGENCY 1: UNSAFE GEAR INDICATION (VOR HOLDING & RE-APPROACH)
        // ==========================================
        if let gearCont = contingencies.first(where: { $0.title.contains("Unsafe") || $0.title.contains("Gear") }) {
            let holdingFix = context.holdingFix

            // Turn 1: ATC Approach radar vector
            exchanges.append(FilledExchange(
                exchangeID: "AP-GEAR-1", templateID: "AP-01", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(appUnit), radar contact, descend and maintain two thousand five hundred feet, QNH \(qnhSpoken), vectoring for ILS runway \(arrRwySpoken).",
                criticalSlots: [], severity: .normal, eventTag: "DESCEND & VECTOR"
            ))
            globalTurn += 1

            // Turn 2: PILOT reports unsafe gear indication & requests holding over VOR
            exchanges.append(FilledExchange(
                exchangeID: "AP-GEAR-2", templateID: "AP-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "PAN PAN, PAN PAN, PAN PAN, \(appUnit), \(callsign), unsafe landing gear indication, nose gear unsafe red light, going around, request climb to four thousand feet and holding over \(holdingFix) to troubleshoot checklist!",
                criticalSlots: [
                    CriticalSlot(slot: "URGENCY", expectedValue: "pan pan, pan pan, pan pan", type: "mandatoryUrgency"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .urgency, eventTag: "PAN PAN UNSAFE GEAR"
            ))
            globalTurn += 1

            // Turn 3: ATC Approves go-around & holding over fix
            exchanges.append(FilledExchange(
                exchangeID: "AP-GEAR-3", templateID: "AP-02", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), roger PAN PAN, climb straight ahead to four thousand feet, proceed direct \(holdingFix) and hold as published, report ready for approach.",
                criticalSlots: [], severity: .urgency, eventTag: "HOLDING INSTRUCTION"
            ))
            globalTurn += 1

            // Turn 4: PILOT Readback holding
            exchanges.append(FilledExchange(
                exchangeID: "AP-GEAR-4", templateID: "AP-02", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Climb four thousand feet, direct \(holdingFix) and hold, will report ready, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "ALTITUDE", expectedValue: "four thousand feet", type: "mandatoryAltitude"),
                    CriticalSlot(slot: "HOLDING_FIX", expectedValue: holdingFix, type: "mandatoryWaypoint"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .urgency, eventTag: "READBACK HOLDING"
            ))
            globalTurn += 1

            // Turn 5: ATC query status
            exchanges.append(FilledExchange(
                exchangeID: "AP-GEAR-5", templateID: "AP-02", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), advise status and gear indication.",
                criticalSlots: [], severity: .normal, eventTag: "ADVISE GEAR STATUS"
            ))
            globalTurn += 1

            // Turn 6: PILOT reports 3 green lights & requests second ILS approach
            exchanges.append(FilledExchange(
                exchangeID: "AP-GEAR-6", templateID: "AP-02", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Checklist completed, manual gear extension deployed, three green lights confirmed, ready to leave holding, request radar vectors for ILS runway \(arrRwySpoken), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "THREE_GREEN", expectedValue: "three green lights", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "RUNWAY", expectedValue: arrRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "GEAR DOWN THREE GREEN"
            ))
            globalTurn += 1

            // Turn 7: ATC Clears ILS approach & handoff to Tower
            exchanges.append(FilledExchange(
                exchangeID: "AP-GEAR-7", templateID: "AP-03", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), leave \(holdingFix) heading zero niner zero, descend two thousand five hundred feet, cleared ILS approach runway \(arrRwySpoken), contact Tower \(twrFreq).",
                criticalSlots: [], severity: .normal, eventTag: "CLEARED ILS APPROACH"
            ))
            globalTurn += 1

            // Turn 8: PILOT Readback
            exchanges.append(FilledExchange(
                exchangeID: "AP-GEAR-8", templateID: "AP-03", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Leave \(holdingFix) heading zero niner zero, descend two thousand five hundred feet, cleared ILS runway \(arrRwySpoken), Tower \(twrFreq), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "RUNWAY", expectedValue: arrRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "TOWER_FREQ", expectedValue: twrFreq, type: "mandatoryFrequency"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK ILS"
            ))
            globalTurn += 1

            // Turn 9: Tower Cleared to Land
            exchanges.append(FilledExchange(
                exchangeID: "AP-GEAR-9", templateID: "AP-04", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(twrUnit), runway \(arrRwySpoken), wind \(windSpoken), cleared to land.",
                criticalSlots: [], severity: .normal, eventTag: "CLEARED TO LAND"
            ))
            globalTurn += 1

            // Turn 10: PILOT Readback Cleared to Land
            exchanges.append(FilledExchange(
                exchangeID: "AP-GEAR-10", templateID: "AP-04", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Runway \(arrRwySpoken), cleared to land, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "RUNWAY", expectedValue: arrRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CLEARED_TO_LAND", expectedValue: "cleared to land", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK CLEARED TO LAND"
            ))
            globalTurn += 1

            executedContingencies.append(gearCont)
            return exchanges

        // ==========================================
        // CONTINGENCY 2: UNCLEARED GO-AROUND (NO CLEARANCE RECEIVED AT DH)
        // ==========================================
        } else if let gaCont = contingencies.first(where: { $0.title.contains("Uncleared") || $0.title.contains("Go-Around") }) {
            exchanges.append(FilledExchange(
                exchangeID: "AP-GA-1", templateID: "AP-01", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(appUnit), radar contact, vectoring for ILS runway \(arrRwySpoken), turn heading zero seven zero, descend two thousand five hundred feet.",
                criticalSlots: [], severity: .normal, eventTag: "RADAR VECTORS"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-GA-2", templateID: "AP-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Heading zero seven zero, descend two thousand five hundred feet, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "HEADING", expectedValue: "heading zero seven zero", type: "mandatoryHeading"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK VECTORS"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-GA-3", templateID: "AP-02", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), cleared ILS approach runway \(arrRwySpoken), contact Tower \(twrFreq).",
                criticalSlots: [], severity: .normal, eventTag: "CLEARED ILS"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-GA-4", templateID: "AP-02", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Cleared ILS runway \(arrRwySpoken), Tower \(twrFreq), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "RUNWAY", expectedValue: arrRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK ILS"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-GA-5", templateID: "AP-03", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(twrUnit), four miles final, continue approach, preceding traffic clearing runway.",
                criticalSlots: [], severity: .normal, eventTag: "CONTINUE APPROACH"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-GA-6", templateID: "AP-03", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Continuing approach, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "CONTINUING"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-GA-7", templateID: "AP-04", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Going around, no landing clearance received at decision altitude, \(callsign)!",
                criticalSlots: [
                    CriticalSlot(slot: "GOING_AROUND", expectedValue: "going around", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .urgency, eventTag: "PILOT INITIATED GO-AROUND"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-GA-8", templateID: "AP-04", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), acknowledge go-around, climb straight ahead four thousand feet, contact Approach \(context.approachFreq).",
                criticalSlots: [], severity: .urgency, eventTag: "GO-AROUND ACKNOWLEDGED"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-GA-9", templateID: "AP-05", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Climb four thousand feet, contact Approach \(context.approachFreq), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "ALTITUDE", expectedValue: "four thousand feet", type: "mandatoryAltitude"),
                    CriticalSlot(slot: "APPROACH_FREQ", expectedValue: context.approachFreq, type: "mandatoryFrequency"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK GO-AROUND"
            ))
            globalTurn += 1

            // Turn 10: PILOT checks in with Approach on missed approach (Coherent Loop)
            exchanges.append(FilledExchange(
                exchangeID: "AP-GA-10", templateID: "AP-05", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "\(appUnit), \(callsign), passing two thousand feet climbing four thousand feet, missed approach runway \(arrRwySpoken).",
                criticalSlots: [
                    CriticalSlot(slot: "ALTITUDE", expectedValue: "four thousand feet", type: "mandatoryAltitude"),
                    CriticalSlot(slot: "MISSED_APPROACH", expectedValue: "missed approach", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .urgency, eventTag: "MISSED APPROACH CHECK-IN",
                objective: "Hubungi Approach Control, laporkan ketinggian saat ini dan konfirmasi pelaksanaan missed approach."
            ))
            globalTurn += 1

            // Turn 11: ATC Approach radar contact & radar vectors for re-sequencing
            exchanges.append(FilledExchange(
                exchangeID: "AP-GA-11", templateID: "AP-05", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(appUnit), radar contact, turn left heading zero niner zero, maintain four thousand feet, vector for second ILS approach runway \(arrRwySpoken).",
                criticalSlots: [], severity: .normal, eventTag: "RADAR VECTORS SECOND APPROACH"
            ))
            globalTurn += 1

            // Turn 12: PILOT Readback vectors
            exchanges.append(FilledExchange(
                exchangeID: "AP-GA-12", templateID: "AP-05", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Turn left heading zero niner zero, maintain four thousand feet, vector for second ILS runway \(arrRwySpoken), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "HEADING", expectedValue: "heading zero niner zero", type: "mandatoryHeading"),
                    CriticalSlot(slot: "ALTITUDE", expectedValue: "four thousand feet", type: "mandatoryAltitude"),
                    CriticalSlot(slot: "RUNWAY", expectedValue: arrRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK VECTORS"
            ))
            globalTurn += 1

            // Turn 13: ATC Approach assigns intercept heading & ILS clearance
            exchanges.append(FilledExchange(
                exchangeID: "AP-GA-13", templateID: "AP-05", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), turn right heading two eight zero, descend and maintain two thousand five hundred feet, cleared ILS runway \(arrRwySpoken) approach, contact Tower \(twrFreq) when established.",
                criticalSlots: [], severity: .normal, eventTag: "CLEARED SECOND ILS"
            ))
            globalTurn += 1

            // Turn 14: PILOT Readback intercept
            exchanges.append(FilledExchange(
                exchangeID: "AP-GA-14", templateID: "AP-05", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Right heading two eight zero, descend two thousand five hundred feet, cleared ILS runway \(arrRwySpoken), contact Tower \(twrFreq), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "HEADING", expectedValue: "heading two eight zero", type: "mandatoryHeading"),
                    CriticalSlot(slot: "ALTITUDE", expectedValue: "two thousand five hundred feet", type: "mandatoryAltitude"),
                    CriticalSlot(slot: "RUNWAY", expectedValue: arrRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "TOWER_FREQ", expectedValue: twrFreq, type: "mandatoryFrequency"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK SECOND ILS"
            ))
            globalTurn += 1

            // Turn 15: PILOT check-in with Tower on final
            exchanges.append(FilledExchange(
                exchangeID: "AP-GA-15", templateID: "AP-05", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "\(twrUnit), \(callsign), established on localizer runway \(arrRwySpoken), four miles final, second approach.",
                criticalSlots: [
                    CriticalSlot(slot: "LOCALIZER", expectedValue: "established on localizer", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "RUNWAY", expectedValue: arrRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "LOCALIZER ESTABLISHED FINAL"
            ))
            globalTurn += 1

            // Turn 16: Tower Cleared to Land
            exchanges.append(FilledExchange(
                exchangeID: "AP-GA-16", templateID: "AP-05", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(twrUnit), runway \(arrRwySpoken) clear, wind \(windSpoken), cleared to land.",
                criticalSlots: [], severity: .normal, eventTag: "CLEARED TO LAND SECOND"
            ))
            globalTurn += 1

            // Turn 17: PILOT Readback Cleared to Land
            exchanges.append(FilledExchange(
                exchangeID: "AP-GA-17", templateID: "AP-05", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Runway \(arrRwySpoken), cleared to land, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "RUNWAY", expectedValue: arrRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CLEARED_TO_LAND", expectedValue: "cleared to land", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK CLEARED TO LAND"
            ))
            globalTurn += 1

            executedContingencies.append(gaCont)
            return exchanges

        // ==========================================
        // CONTINGENCY 3: FLAP SYSTEM FAILURE (HIGH SPEED APPROACH)
        // ==========================================
        } else if let flapCont = contingencies.first(where: { $0.title.contains("Flap") }) {
            exchanges.append(FilledExchange(
                exchangeID: "AP-FLP-1", templateID: "AP-01", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(appUnit), radar contact, descend to three thousand feet, QNH \(qnhSpoken).",
                criticalSlots: [], severity: .normal, eventTag: "RADAR CONTACT"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-FLP-2", templateID: "AP-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "PAN PAN, PAN PAN, PAN PAN, \(appUnit), \(callsign), flap system failure, unable to extend flaps, approach speed one six zero knots, request priority straight-in approach runway \(arrRwySpoken)!",
                criticalSlots: [
                    CriticalSlot(slot: "URGENCY", expectedValue: "pan pan, pan pan, pan pan", type: "mandatoryUrgency"),
                    CriticalSlot(slot: "RUNWAY", expectedValue: arrRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .urgency, eventTag: "PAN PAN FLAP FAILURE"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-FLP-3", templateID: "AP-02", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), roger PAN PAN, priority straight-in approach approved runway \(arrRwySpoken), descend two thousand five hundred feet, straight-in ILS runway \(arrRwySpoken), contact Tower \(twrFreq).",
                criticalSlots: [], severity: .urgency, eventTag: "PRIORITY STRAIGHT-IN APPROVED"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-FLP-4", templateID: "AP-02", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Priority straight-in ILS runway \(arrRwySpoken), Tower \(twrFreq), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "RUNWAY", expectedValue: arrRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "TOWER_FREQ", expectedValue: twrFreq, type: "mandatoryFrequency"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .urgency, eventTag: "READBACK STRAIGHT-IN"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-FLP-5", templateID: "AP-03", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(twrUnit), runway \(arrRwySpoken), wind \(windSpoken), cleared to land.",
                criticalSlots: [], severity: .normal, eventTag: "CLEARED TO LAND"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-FLP-6", templateID: "AP-03", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Runway \(arrRwySpoken), cleared to land, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "RUNWAY", expectedValue: arrRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CLEARED_TO_LAND", expectedValue: "cleared to land", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK CLEARED TO LAND"
            ))
            globalTurn += 1

            executedContingencies.append(flapCont)
            return exchanges
        }

        // ==========================================
        // ROUTINE & PROCEDURAL APPROACHES (LEVEL 1 VFR vs LEVEL 2-5 IFR)
        // ==========================================
        if level == .level1 {
            // Level 1: Visual traffic pattern turning base, final, and touch-and-go (6 turns)
            exchanges.append(FilledExchange(
                exchangeID: "AP-VFR-1", templateID: "AP-01", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(twrUnit), report turning base runway \(arrRwySpoken).",
                criticalSlots: [], severity: .normal, eventTag: "REPORT BASE"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-VFR-2", templateID: "AP-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Turning base runway \(arrRwySpoken), gear down, three green, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "RUNWAY", expectedValue: arrRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "TURNING BASE"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-VFR-3", templateID: "AP-02", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), report final runway \(arrRwySpoken).",
                criticalSlots: [], severity: .normal, eventTag: "REPORT FINAL"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-VFR-4", templateID: "AP-02", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Final runway \(arrRwySpoken), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "RUNWAY", expectedValue: arrRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "REPORTING FINAL"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-VFR-5", templateID: "AP-03", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), runway \(arrRwySpoken), wind \(windSpoken), cleared touch-and-go, make left traffic.",
                criticalSlots: [], severity: .normal, eventTag: "CLEARED TOUCH AND GO"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-VFR-6", templateID: "AP-03", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Runway \(arrRwySpoken), cleared touch-and-go, make left traffic, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "RUNWAY", expectedValue: arrRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CLEARED_TOUCH_AND_GO", expectedValue: "cleared touch-and-go, make left traffic", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK TOUCH AND GO"
            ))
            globalTurn += 1

        } else {
            // Levels 2, 3, 4, 5: Full ICAO Radar Vectoring, Speed Sequencing, ILS Intercept, & Landing Clearance (10-12 turns)
            let baseHeading: String
            let interceptHeading: String
            let interceptSpeed: String

            switch level {
            case .level2:
                baseHeading = "heading zero six zero"
                interceptHeading = "heading zero seven zero"
                interceptSpeed = "one six zero knots"
            case .level3:
                baseHeading = "heading zero six zero"
                interceptHeading = "heading zero seven zero"
                interceptSpeed = "one eight zero knots"
            case .level4:
                baseHeading = "heading zero eight zero"
                interceptHeading = "heading zero niner zero"
                interceptSpeed = "one eight zero knots"
            case .level5:
                baseHeading = "heading zero one zero"
                interceptHeading = "heading two eight zero"
                interceptSpeed = "one eight zero knots"
            default:
                baseHeading = "heading zero one zero"
                interceptHeading = "heading two eight zero"
                interceptSpeed = "one eight zero knots"
            }

            // Step 1: Initial Vectoring for ILS & Base Leg Heading (ICAO Doc 9432 Section 7.5)
            exchanges.append(FilledExchange(
                exchangeID: "AP-ILS-CHK", templateID: "AP-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "\(appUnit), \(callsign), passing flight level one zero zero descending altitude five thousand feet, information \(context.arrAtisId).",
                criticalSlots: [
                    CriticalSlot(slot: "ATIS_ID", expectedValue: context.arrAtisId, type: "mandatoryAtis"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "APPROACH CHECK-IN"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-ILS-1", templateID: "AP-01", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(appUnit), radar contact, vectoring for ILS approach runway \(arrRwySpoken), turn \(baseHeading), descend and maintain three thousand feet, QNH \(qnhSpoken).",
                criticalSlots: [], severity: .normal, eventTag: "RADAR VECTORS & BASE LEG"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-ILS-2", templateID: "AP-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Turn \(baseHeading), descend and maintain three thousand feet, QNH \(qnhSpoken), vectoring for ILS runway \(arrRwySpoken), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "HEADING", expectedValue: baseHeading, type: "mandatoryHeading"),
                    CriticalSlot(slot: "ALTITUDE", expectedValue: "three thousand feet", type: "mandatoryAltitude"),
                    CriticalSlot(slot: "QNH", expectedValue: qnhSpoken, type: "mandatoryQnh"),
                    CriticalSlot(slot: "RUNWAY", expectedValue: arrRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK VECTORS"
            ))
            globalTurn += 1

            // Delaying Vector / 360 Orbit
            if let dvoCont = contingencies.first(where: { $0.title.contains("Delaying Vector") || $0.title.contains("Orbit") }) {
                exchanges.append(FilledExchange(
                    exchangeID: "ABN-DVO-1", templateID: "ABN-DVO", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), \(appUnit), make one three sixty turn right for traffic spacing, maintain four thousand feet.",
                    criticalSlots: [], severity: .abnormal, eventTag: "ORBIT RIGHT 360"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-DVO-2", templateID: "ABN-DVO", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Three sixty turn right, maintain four thousand feet, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "THREE_SIXTY", expectedValue: "three sixty turn right", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .abnormal, eventTag: "READBACK 360 ORBIT"
                ))
                globalTurn += 1
                executedContingencies.append(dvoCont)
            }

            // Level 5 Mountain Valley: Inject VHF Partyline Approach / Valley Contention (1-3 turns)
            if level == .level5 {
                let stationName = context.unitTower?.callsign ?? "\(context.airport.name) Tower"
                let partylineTurns = generateLevel5PartylineInterruption(
                    phase: .approach,
                    station: stationName,
                    rwy: arrRwySpoken,
                    airportICAO: context.airport.icao,
                    studentCallsign: callsign,
                    seed: seed,
                    globalTurn: &globalTurn
                )
                exchanges.append(contentsOf: partylineTurns)
            }

            // GPWS Terrain Avoidance
            if let gpwsCont = contingencies.first(where: { $0.title.contains("GPWS") || $0.title.contains("Terrain") }) {
                exchanges.append(FilledExchange(
                    exchangeID: "ABN-GPWS-1", templateID: "ABN-GPWS", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), turn left heading two five zero, descend two thousand feet.",
                    criticalSlots: [], severity: .abnormal, eventTag: "RADAR VECTOR NEAR TERRAIN"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-GPWS-2", templateID: "ABN-GPWS", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "UNABLE heading two five zero due terrain, climbing altitude eight thousand feet, \(callsign)!",
                    criticalSlots: [
                        CriticalSlot(slot: "UNABLE", expectedValue: "unable", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "TERRAIN", expectedValue: "due terrain", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .distress, eventTag: "GPWS TERRAIN ESCAPE"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-GPWS-3", templateID: "ABN-GPWS", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), roger, climb altitude eight thousand feet approved, maintain runway heading.",
                    criticalSlots: [], severity: .distress, eventTag: "CLIMB 8000FT APPROVED"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-GPWS-4", templateID: "ABN-GPWS", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Climb altitude eight thousand feet, maintain runway heading, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .normal, eventTag: "READBACK CLIMB"
                ))
                globalTurn += 1
                executedContingencies.append(gpwsCont)
            }

            // Step 2: Speed Reduction & Intercept Heading (ICAO Doc 9432 Section 7.5.1)
            exchanges.append(FilledExchange(
                exchangeID: "AP-ILS-3", templateID: "AP-02", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), reduce speed \(interceptSpeed), turn \(interceptHeading), cleared ILS approach runway \(arrRwySpoken), report established on localizer.",
                criticalSlots: [], severity: .normal, eventTag: "SPEED CONTROL & INTERCEPT"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-ILS-4", templateID: "AP-02", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Reduce speed \(interceptSpeed), turn \(interceptHeading), cleared ILS runway \(arrRwySpoken), will report established, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "SPEED", expectedValue: interceptSpeed, type: "mandatoryKeyword"),
                    CriticalSlot(slot: "HEADING", expectedValue: interceptHeading, type: "mandatoryHeading"),
                    CriticalSlot(slot: "RUNWAY", expectedValue: arrRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK INTERCEPT"
            ))
            globalTurn += 1

            // Step 3: Localizer Established Confirmation Prompt & Established Call
            exchanges.append(FilledExchange(
                exchangeID: "AP-ILS-5", templateID: "AP-03", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), report localizer established.",
                criticalSlots: [], severity: .normal, eventTag: "REPORT ESTABLISHED PROMPT"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-ILS-6", templateID: "AP-03", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "\(appUnit), \(callsign), established on localizer runway \(arrRwySpoken).",
                criticalSlots: [
                    CriticalSlot(slot: "ESTABLISHED", expectedValue: "established on localizer", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "RUNWAY", expectedValue: arrRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "ESTABLISHED REPORT"
            ))
            globalTurn += 1

            // Step 4: Speed Restriction Cancellation & Handoff to Tower (ICAO Doc 9432 Section 7.5.1)
            exchanges.append(FilledExchange(
                exchangeID: "AP-ILS-7", templateID: "AP-04", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), no ATC speed restrictions, contact \(twrUnit) \(twrFreq).",
                criticalSlots: [], severity: .normal, eventTag: "SPEED CANCEL & CONTACT TOWER"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-ILS-8", templateID: "AP-04", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "No ATC speed restrictions, contact \(twrUnit) \(twrFreq), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "TOWER_FREQ", expectedValue: twrFreq, type: "mandatoryFrequency"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK TOWER FREQ"
            ))
            globalTurn += 1

            // Pilot initial contact on Tower frequency
            exchanges.append(FilledExchange(
                exchangeID: "AP-TWR-CHK", templateID: "AP-04", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "\(twrUnit), \(callsign), established on localizer runway \(arrRwySpoken), four miles final.",
                criticalSlots: [
                    CriticalSlot(slot: "LOCALIZER", expectedValue: "established on localizer", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "RUNWAY", expectedValue: arrRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "LOCALIZER ESTABLISHED FINAL"
            ))
            globalTurn += 1

            // Step 5: Final Check & Landing Clearance (with Contingency advisories if applicable)
            var landingAdvisory = ""
            if let waterCont = contingencies.first(where: { $0.title.contains("Contaminated") || $0.title.contains("Braking") }) {
                landingAdvisory = "caution standing water on runway, braking action reported poor by preceding traffic, "
                executedContingencies.append(waterCont)
            } else if let lateClear = contingencies.first(where: { $0.title.contains("Late Landing Clearance") }) {
                // Late landing clearance prompt
                exchanges.append(FilledExchange(
                    exchangeID: "ABN-LATE-1", templateID: "ABN-LATE", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), \(twrUnit), two miles final, continue approach, preceding traffic vacating runway.",
                    criticalSlots: [], severity: .normal, eventTag: "CONTINUE APPROACH LATE CLEARANCE"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-LATE-2", templateID: "ABN-LATE", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "\(twrUnit), \(callsign), short final runway \(arrRwySpoken), confirm cleared to land?",
                    criticalSlots: [
                        CriticalSlot(slot: "CONFIRM", expectedValue: "confirm cleared to land", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .abnormal, eventTag: "PROMPT CLEARANCE"
                ))
                globalTurn += 1
                executedContingencies.append(lateClear)

            } else if let caCont = contingencies.first(where: { $0.title.contains("Continue Approach") }) {
                exchanges.append(FilledExchange(
                    exchangeID: "ABN-CA-1", templateID: "ABN-CA", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), \(twrUnit), two miles final, continue approach, preceding traffic vacating runway.",
                    criticalSlots: [], severity: .normal, eventTag: "CONTINUE APPROACH"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-CA-2", templateID: "ABN-CA", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Continue approach, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "CONTINUE", expectedValue: "continue approach", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .normal, eventTag: "READBACK CONTINUE APPROACH"
                ))
                globalTurn += 1
                executedContingencies.append(caCont)

            } else if let wsCont = contingencies.first(where: { $0.title.contains("Wind Shear") }) {
                exchanges.append(FilledExchange(
                    exchangeID: "ABN-WS-1", templateID: "ABN-WS", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Wind shear warning, maximum thrust, going around, \(callsign)!",
                    criticalSlots: [
                        CriticalSlot(slot: "WIND_SHEAR", expectedValue: "wind shear warning", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "GOING_AROUND", expectedValue: "going around", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .distress, eventTag: "WIND SHEAR ESCAPE"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-WS-2", templateID: "ABN-WS", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), roger wind shear, fly runway heading, climb four thousand feet.",
                    criticalSlots: [], severity: .distress, eventTag: "WIND SHEAR ESCAPE CLEARANCE"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-WS-3", templateID: "ABN-WS", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Fly runway heading, climb four thousand feet, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "ALTITUDE", expectedValue: "four thousand feet", type: "mandatoryAltitude"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .distress, eventTag: "READBACK ESCAPE"
                ))
                globalTurn += 1
                executedContingencies.append(wsCont)

            } else if let lpCont = contingencies.first(where: { $0.title.contains("Low Pass Inspection") }) {
                exchanges.append(FilledExchange(
                    exchangeID: "ABN-LP-1", templateID: "ABN-LP", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "\(twrUnit), \(callsign), request low pass runway \(arrRwySpoken) for visual gear inspection.",
                    criticalSlots: [
                        CriticalSlot(slot: "LOW_PASS", expectedValue: "low pass", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .abnormal, eventTag: "REQUEST LOW PASS"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-LP-2", templateID: "ABN-LP", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), low pass approved not below two hundred feet, report tower abeam.",
                    criticalSlots: [], severity: .abnormal, eventTag: "LOW PASS APPROVED"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-LP-3", templateID: "ABN-LP", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Low pass approved not below two hundred feet, will report tower abeam, \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .abnormal, eventTag: "READBACK LOW PASS"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-LP-4", templateID: "ABN-LP", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "\(callsign), tower reports gear appears down and locked, make left traffic runway \(arrRwySpoken).",
                    criticalSlots: [], severity: .normal, eventTag: "GEAR CONFIRMED DOWN"
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "ABN-LP-5", templateID: "ABN-LP", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "Make left traffic runway \(arrRwySpoken), \(callsign).",
                    criticalSlots: [
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .normal, eventTag: "READBACK TRAFFIC"
                ))
                globalTurn += 1
                executedContingencies.append(lpCont)

            } else if let commsCont = contingencies.first(where: { $0.title.contains("Airborne Comms") || $0.title.contains("7600") }) {
                exchanges.append(FilledExchange(
                    exchangeID: "ABN-COM-1", templateID: "ABN-COM", turn: globalTurn, speaker: "PILOT",
                    isUserTurn: (role == .pilot),
                    text: "TRANSMITTING BLIND, TRANSMITTING BLIND, \(twrUnit), \(callsign), radio receiver failure, established final runway \(arrRwySpoken), watching tower for light gun signals.",
                    criticalSlots: [
                        CriticalSlot(slot: "TRANSMITTING_BLIND", expectedValue: "transmitting blind", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                    ], severity: .urgency, eventTag: "TRANSMITTING BLIND RECEIVER FAILURE"
                ))
                globalTurn += 1
                executedContingencies.append(commsCont)

            } else if let silenceCont = contingencies.first(where: { $0.title.contains("Imposition of Silence") }) {
                exchanges.append(FilledExchange(
                    exchangeID: "ABN-SIL-1", templateID: "ABN-SIL", turn: globalTurn, speaker: "ATC",
                    isUserTurn: (role == .atc),
                    text: "ALL STATIONS, STOP TRANSMITTING — MAYDAY!",
                    criticalSlots: [], severity: .distress, eventTag: "IMPOSITION OF SILENCE"
                ))
                globalTurn += 1
                executedContingencies.append(silenceCont)
            }

            exchanges.append(FilledExchange(
                exchangeID: "AP-TWR-1", templateID: "AP-05", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(twrUnit), four miles final, \(landingAdvisory)runway \(arrRwySpoken), wind \(windSpoken), cleared to land.",
                criticalSlots: [], severity: landingAdvisory.isEmpty ? .normal : .abnormal, eventTag: landingAdvisory.isEmpty ? "CLEARED TO LAND" : "CLEARED TO LAND & BRAKING POOR"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "AP-TWR-2", templateID: "AP-05", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Runway \(arrRwySpoken), cleared to land, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "RUNWAY", expectedValue: arrRwySpoken, type: "mandatoryRunway"),
                    CriticalSlot(slot: "CLEARED_TO_LAND", expectedValue: "cleared to land", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK CLEARED TO LAND"
            ))
            globalTurn += 1
        }

        return exchanges
    }
    // MARK: - Phase 6: Landing Builder
    private func buildLandingExchanges(
        level: CurriculumLevel,
        seed: Int,
        role: UserRole,
        context: SlotContext,
        contingencies: [InjectedContingency],
        executedContingencies: inout [InjectedContingency],
        globalTurn: inout Int
    ) -> [FilledExchange] {
        var exchanges: [FilledExchange] = []
        let callsign = context.callsign
        let twrUnit = context.unitTower?.callsign ?? "Tower"
        let gndUnit = context.unitGround?.callsign ?? "Ground"
        let gndFreq = SpokenFormFormatter.frequency(context.unitGround?.frequency ?? "121.700")
        let exitTaxiway = context.exitTaxiway
        let exitDir = context.exitDirection
        let standDest = context.destinationStand

        // Bridged Landing: Single-Engine Emergency (MAYDAY)
        if contingencies.contains(where: { $0.title.contains("Mid-Air Engine") || $0.title.contains("Engine Failure") }) {
            exchanges.append(FilledExchange(
                exchangeID: "LD-ENG-1", templateID: "LD-01", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(twrUnit), roll out to end, emergency services trailing you on runway.",
                criticalSlots: [], severity: .distress, eventTag: "ROLL OUT INSTRUCTION"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "LD-ENG-2", templateID: "LD-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Rolling out to end, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .distress, eventTag: "READBACK ROLL OUT"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "LD-ENG-3", templateID: "LD-02", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "\(twrUnit), \(callsign), stopped on runway, parking brake set, engine shutdown completed, request exterior inspection.",
                criticalSlots: [
                    CriticalSlot(slot: "ENGINES_SHUTDOWN", expectedValue: "shutdown completed", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .distress, eventTag: "STOPPED ON RUNWAY REPORT"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "LD-ENG-4", templateID: "LD-02", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), fire crew confirms no smoke or fuel leak, tow truck dispatched, cancel MAYDAY, welcome to the ground safely.",
                criticalSlots: [], severity: .distress, eventTag: "ARFF INSPECTION"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "LD-ENG-5", templateID: "LD-03", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Cancel MAYDAY, thank you for the prompt assistance, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "CANCEL_MAYDAY", expectedValue: "cancel mayday", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "CANCEL MAYDAY"
            ))
            globalTurn += 1

            return exchanges
        }

        // Bridged Landing: Passenger Medical Emergency Priority (PAN PAN)
        if contingencies.contains(where: { $0.title.contains("Medical") }) {
            exchanges.append(FilledExchange(
                exchangeID: "LD-MED-1", templateID: "LD-01", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(twrUnit), expedite vacate right via \(exitTaxiway), contact Ground \(gndFreq).",
                criticalSlots: [], severity: .urgency, eventTag: "EXPEDITE VACATE"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "LD-MED-2", templateID: "LD-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Expedite vacate right via \(exitTaxiway), contact Ground \(gndFreq), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "VACATE_TAXIWAY", expectedValue: exitTaxiway, type: "mandatoryTaxiway"),
                    CriticalSlot(slot: "GROUND_FREQ", expectedValue: gndFreq, type: "mandatoryFrequency"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .urgency, eventTag: "READBACK VACATE"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "LD-MED-3", templateID: "LD-02", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(gndUnit), taxi direct to \(standDest), medical team and ambulance are in position at the gate.",
                criticalSlots: [], severity: .urgency, eventTag: "TAXI TO GATE"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "LD-MED-4", templateID: "LD-02", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Taxi direct to \(standDest), thank you for the coordination, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "STAND", expectedValue: standDest, type: "mandatoryGate"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .urgency, eventTag: "READBACK TAXI TO GATE"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "LD-MED-5", templateID: "LD-03", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), flight plan closed at zero two zero zero UTC, emergency services have taken over, good day.",
                criticalSlots: [], severity: .normal, eventTag: "FLIGHT PLAN CLOSED"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "LD-MED-6", templateID: "LD-03", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Flight plan closed, good day, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "GOOD DAY"
            ))
            globalTurn += 1

            return exchanges
        }

        // Blown Tire On Rollout Emergency
        if let tireCont = contingencies.first(where: { $0.title.contains("Blown Tire") }) {
            exchanges.append(FilledExchange(
                exchangeID: "ABN-TIRE-1", templateID: "ABN-TIRE", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Tower, \(callsign), blown tire on rollout, aircraft stopped on runway, unable to vacate, request ARFF inspection and tow tug.",
                criticalSlots: [
                    CriticalSlot(slot: "BLOWN_TIRE", expectedValue: "blown tire", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .distress, eventTag: "BLOWN TIRE ON RUNWAY"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-TIRE-2", templateID: "ABN-TIRE", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), roger, emergency equipment rolling, tow tug dispatched, runway closed.",
                criticalSlots: [], severity: .distress, eventTag: "ARFF & TUG DISPATCHED"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-TIRE-3", templateID: "ABN-TIRE", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Standing by on runway for ARFF and tug, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .distress, eventTag: "STANDING BY FOR TUG"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-TIRE-4", templateID: "ABN-TIRE", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), fire crew confirms no smoke, tug attached, towing to maintenance hangar, flight plan closed.",
                criticalSlots: [], severity: .normal, eventTag: "TOWING TO HANGAR"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-TIRE-5", templateID: "ABN-TIRE", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Flight plan closed, thank you for assistance, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "FLIGHT PLAN CLOSED"
            ))
            globalTurn += 1
            executedContingencies.append(tireCont)
            return exchanges
        }

        // Runway Excursion Emergency
        if let excCont = contingencies.first(where: { $0.title.contains("Runway Excursion") }) {
            exchanges.append(FilledExchange(
                exchangeID: "ABN-EXC-1", templateID: "ABN-EXC", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "MAYDAY MAYDAY MAYDAY, \(callsign), runway excursion into grass on rollout, initiating passenger evacuation!",
                criticalSlots: [
                    CriticalSlot(slot: "MAYDAY", expectedValue: "mayday mayday mayday", type: "mandatoryDistress"),
                    CriticalSlot(slot: "EXCURSION", expectedValue: "runway excursion", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .distress, eventTag: "MAYDAY RUNWAY EXCURSION"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-EXC-2", templateID: "ABN-EXC", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), roger MAYDAY, crash alarm activated, ARFF deploying to aircraft immediately!",
                criticalSlots: [], severity: .distress, eventTag: "ARFF DEPLOYED CRASH ALARM"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-EXC-3", templateID: "ABN-EXC", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Evacuation underway, slides deployed, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .distress, eventTag: "EVACUATION UNDERWAY"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-EXC-4", templateID: "ABN-EXC", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), rescue services on scene, all assistance provided, flight plan closed.",
                criticalSlots: [], severity: .normal, eventTag: "RESCUE ON SCENE"
            ))
            globalTurn += 1
            executedContingencies.append(excCont)
            return exchanges
        }

        // Turn 1: ATC Vacate instruction
        exchanges.append(FilledExchange(
            exchangeID: "LD-VAC-1", templateID: "LD-01", turn: globalTurn, speaker: "ATC",
            isUserTurn: (role == .atc),
            text: "\(callsign), \(twrUnit), vacate \(exitDir) via \(exitTaxiway), when vacated contact Ground \(gndFreq).",
            criticalSlots: [], severity: .normal, eventTag: "VACATE RUNWAY INSTRUCTION"
        ))
        globalTurn += 1

        // Turn 2: PILOT Readback vacate
        let isLightGun = contingencies.contains(where: { $0.title.contains("Light Gun Signals") })
        if isLightGun {
            exchanges.append(FilledExchange(
                exchangeID: "ABN-LG-1", templateID: "ABN-LG", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Acknowledge flashing green light gun signal from tower, vacated via \(exitTaxiway), proceeding to apron, \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "LIGHT_GUN", expectedValue: "flashing green light gun", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .abnormal, eventTag: "ACKNOWLEDGE LIGHT GUN"
            ))
            globalTurn += 1
        } else {
            exchanges.append(FilledExchange(
                exchangeID: "LD-VAC-2", templateID: "LD-01", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Vacate \(exitDir) via \(exitTaxiway), contact Ground \(gndFreq), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "VACATE_TAXIWAY", expectedValue: exitTaxiway, type: "mandatoryTaxiway"),
                    CriticalSlot(slot: "GROUND_FREQ", expectedValue: gndFreq, type: "mandatoryFrequency"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK VACATE"
            ))
            globalTurn += 1
        }

        // Pilot initial contact on Ground frequency
        exchanges.append(FilledExchange(
            exchangeID: "LD-GND-CHK", templateID: "LD-02", turn: globalTurn, speaker: "PILOT",
            isUserTurn: (role == .pilot),
            text: "\(gndUnit), \(callsign), runway vacated \(exitDir) via \(exitTaxiway), request taxi to gate.",
            criticalSlots: [
                CriticalSlot(slot: "VACATE_TAXIWAY", expectedValue: exitTaxiway, type: "mandatoryTaxiway"),
                CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
            ], severity: .normal, eventTag: "GROUND CHECK-IN"
        ))
        globalTurn += 1

        // Hot Brakes Inspection on Taxiway
        if let hbCont = contingencies.first(where: { $0.title.contains("Hot Brakes") }) {
            exchanges.append(FilledExchange(
                exchangeID: "ABN-HB-1", templateID: "ABN-HB", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "\(gndUnit), \(callsign), hot brakes warning indication on taxiway \(exitTaxiway), holding position, request fire truck visual inspection.",
                criticalSlots: [
                    CriticalSlot(slot: "HOT_BRAKES", expectedValue: "hot brakes", type: "mandatoryKeyword"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .urgency, eventTag: "HOT BRAKES REPORT"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-HB-2", templateID: "ABN-HB", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), hold position on \(exitTaxiway), fire rescue approaching for brake temperature inspection.",
                criticalSlots: [], severity: .urgency, eventTag: "HOLD POSITION FOR INSPECTION"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-HB-3", templateID: "ABN-HB", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Holding position on \(exitTaxiway), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .urgency, eventTag: "READBACK HOLD POSITION"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-HB-4", templateID: "ABN-HB", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), fire crew reports brake temperature normal, taxi to \(standDest) via \(context.taxiRoute).",
                criticalSlots: [], severity: .normal, eventTag: "BRAKES NORMAL TAXI APPROVED"
            ))
            globalTurn += 1

            exchanges.append(FilledExchange(
                exchangeID: "ABN-HB-5", templateID: "ABN-HB", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Taxi to \(standDest) via \(context.taxiRoute), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "STAND", expectedValue: standDest, type: "mandatoryGate"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK TAXI TO GATE"
            ))
            globalTurn += 1
            executedContingencies.append(hbCont)

        } else {
            // Turn 3: ATC Ground taxi clearance
            exchanges.append(FilledExchange(
                exchangeID: "LD-GND-1", templateID: "LD-02", turn: globalTurn, speaker: "ATC",
                isUserTurn: (role == .atc),
                text: "\(callsign), \(gndUnit), taxi to \(standDest) via \(context.taxiRoute).",
                criticalSlots: [], severity: .normal, eventTag: "TAXI TO GATE"
            ))
            globalTurn += 1

            // Turn 4: PILOT Readback taxi
            exchanges.append(FilledExchange(
                exchangeID: "LD-GND-2", templateID: "LD-02", turn: globalTurn, speaker: "PILOT",
                isUserTurn: (role == .pilot),
                text: "Taxi to \(standDest) via \(context.taxiRoute), \(callsign).",
                criticalSlots: [
                    CriticalSlot(slot: "STAND", expectedValue: standDest, type: "mandatoryGate"),
                    CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
                ], severity: .normal, eventTag: "READBACK TAXI TO GATE"
            ))
            globalTurn += 1
        }

        // Turn 5: ATC Shutdown report prompt
        exchanges.append(FilledExchange(
            exchangeID: "LD-SHUT-1", templateID: "LD-03", turn: globalTurn, speaker: "ATC",
            isUserTurn: (role == .atc),
            text: "\(callsign), report on \(standDest) with engines shut down.",
            criticalSlots: [], severity: .normal, eventTag: "REPORT ON STAND"
        ))
        globalTurn += 1

        // Turn 6: PILOT Shutdown & close flight plan
        exchanges.append(FilledExchange(
            exchangeID: "LD-SHUT-2", templateID: "LD-03", turn: globalTurn, speaker: "PILOT",
            isUserTurn: (role == .pilot),
            text: "\(gndUnit), \(callsign), on \(standDest), parking brake set, engines shut down, request close flight plan.",
            criticalSlots: [
                CriticalSlot(slot: "ENGINES_SHUTDOWN", expectedValue: "engines shut down", type: "mandatoryKeyword"),
                CriticalSlot(slot: "CLOSE_FP", expectedValue: "close flight plan", type: "mandatoryKeyword"),
                CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
            ], severity: .normal, eventTag: "CLOSE FLIGHT PLAN"
        ))
        globalTurn += 1

        // Turn 7: ATC Flight plan closed
        exchanges.append(FilledExchange(
            exchangeID: "LD-SHUT-3", templateID: "LD-03", turn: globalTurn, speaker: "ATC",
            isUserTurn: (role == .atc),
            text: "\(callsign), flight plan closed at zero two zero zero UTC, good day.",
            criticalSlots: [], severity: .normal, eventTag: "FLIGHT PLAN CLOSED"
        ))
        globalTurn += 1

        // Turn 8: PILOT Good day
        exchanges.append(FilledExchange(
            exchangeID: "LD-SHUT-4", templateID: "LD-03", turn: globalTurn, speaker: "PILOT",
            isUserTurn: (role == .pilot),
            text: "Flight plan closed, good day, \(callsign).",
            criticalSlots: [
                CriticalSlot(slot: "CALLSIGN", expectedValue: callsign, type: "mandatoryIdentifier")
            ], severity: .normal, eventTag: "READBACK GOOD DAY"
        ))
        globalTurn += 1

        return exchanges
    }

    // MARK: - ATC Session Generator (Multi-Traffic, Single Aerodrome)

    /// Generate an ATC training session for a given aerodrome and level.
    /// The session has multiple aircraft handled sequentially/overlapped,
    /// grouped into 3 Acts (Departures / Transit / Arrivals).
    /// Scripts are deterministic — no LLM, no decision making by trainee.
    public func generateATCSession(
        aerodromeICAO: String,
        seed: Int? = nil,
        selectedContingencies: Set<ContingencySelection> = []
    ) throws -> ATCSessionScript {
        let chosenSeed = seed ?? Int.random(in: 1000...9999)
        let airport = try airportRepository.airport(icao: aerodromeICAO)

        guard let aerodromeItem = AirportCurriculumRegistry.airport(for: aerodromeICAO) else {
            throw GeneratorError.airportNotFound(aerodromeICAO)
        }
        let level = aerodromeItem.assignedLevel

        // Runway resolution
        let rwyPair = airport.runways.first?.pair ?? [airport.runways.first?.designator ?? "08"]
        let rwyHeadings = Dictionary(uniqueKeysWithValues: airport.runways.map { ($0.designator, $0.headingDegT) })
        let weather = WeatherEngine.alignedWeather(
            runway: airport.runways.first?.designator ?? "08",
            heading: airport.runways.first?.headingDegT ?? 80,
            seed: chosenSeed
        )
        let activeRwyDesignator = WeatherEngine.bestRunway(
            pair: rwyPair, headings: rwyHeadings,
            windDirection: Double(weather.windDirection), windSpeed: Double(weather.windSpeed)
        ).runway
        let activeRunway = airport.runways.first(where: { $0.designator == activeRwyDesignator }) ?? airport.runways.first!
        let atisId = ATISGenerator.letter(seed: chosenSeed)
        let holdingPoint = Self.pickHoldingPoint(from: activeRunway.holdingPoints, defaultPoint: "A1", seed: chosenSeed)
        let towerCallsign = airport.units.tower?.callsign ?? "\(airport.name) Tower"
        let groundCallsign = airport.units.ground?.callsign ?? "\(airport.name) Ground"

        // Contingency roll for this session
        let effectiveContingencies = selectedContingencies.isEmpty ? Set(level.allowedScenarios) : selectedContingencies
        let hasEmergency = effectiveContingencies.contains(where: { $0.requiresPlainEnglish && $0.defaultSeverity == .distress })
            && (abs(chosenSeed) % 3 == 0)  // 33% chance
        let hasMedical = effectiveContingencies.contains(.passengerMedicalEmergency)
            && (abs(chosenSeed) % 4 == 1)  // 25% chance

        // Callsign pool (different aircraft per traffic slot)
        let callsigns = buildATCCallsignPool(level: level, seed: chosenSeed)
        let aircraftTypes = buildATCAircraftPool(level: level, seed: chosenSeed)

        var allTrafficEntries: [ATCTrafficEntry] = []
        var globalTurn = 1

        // --- TRAFFIC COMPOSITION BY LEVEL ---
        // L1: 1 Departure + 1 Touch-and-Go  (2 traffic)
        // L2: 1 Departure (IFR) + 1 Arrival (ILS) + 1 Touch-and-Go  (3 traffic)
        // L3: 1 Departure + 1 En-Route Transit + 1 Holding Arrival + 1 Emergency (4 traffic)
        // L4: 1 Departure (complex) + 1 Transit + 1 Diversion + 1 Go-Around + 1 Medical  (5 traffic)
        // L5: 1 Dep Parallel + 1 TCAS Transit + 1 Emergency + 1 Diversion + 1 Normal Arrival + 1 Silence (6 traffic)

        let trafficComposition: [(type: ATCTrafficType, act: MissionAct, callsignIdx: Int, acIdx: Int)]
        switch level {
        case .level1:
            // 3 traffic: Departure + VFR Circuit (Touch-and-Go with spacing) + Full stop arrival
            trafficComposition = [
                (.fullDeparture, .act1Departure, 0, 0),
                (.touchAndGo, .act1Departure, 1, 0),
                (.fullArrival, .act3Arrival, 2, 0)
            ]
        case .level2:
            // 4 traffic: IFR Departure + VFR Circuit + Commercial Arrival ILS + Diversion / Precautionary Arrival
            trafficComposition = [
                (.fullDeparture, .act1Departure, 0, 1),
                (.touchAndGo, .act1Departure, 1, 0),
                (.fullArrival, .act3Arrival, 2, 1),
                (.diversionArrival, .act3Arrival, 3, 1)
            ]
        case .level3:
            // 5 traffic: IFR Departure with wake delay + Transit + Inbound ILS + Emergency Inbound + Local VFR Circuit
            trafficComposition = [
                (.fullDeparture, .act1Departure, 0, 1),
                (.enRouteTransit, .act2EnRoute, 1, 2),
                (.fullArrival, .act3Arrival, 2, 1),
                (.emergencyInbound, .act3Arrival, 3, 2),
                (.touchAndGo, .act1Departure, 4, 0)
            ]
        case .level4:
            // 6 traffic: Parallel Departure 1 + Parallel Departure 2 + Transit + Diversion + Emergency Inbound + Final Arrival
            trafficComposition = [
                (.fullDeparture, .act1Departure, 0, 2),
                (.fullDeparture, .act1Departure, 1, 3),
                (.enRouteTransit, .act2EnRoute, 2, 3),
                (.diversionArrival, .act3Arrival, 3, 2),
                (.emergencyInbound, .act3Arrival, 4, 1),
                (.fullArrival, .act3Arrival, 5, 2)
            ]
        case .level5:
            // 7 traffic: Valley Departure + Complex Departure + Valley Transit + Diversion + Emergency Inbound 1 + Final Arrival + Emergency Inbound 2
            trafficComposition = [
                (.fullDeparture, .act1Departure, 0, 4),
                (.fullDeparture, .act1Departure, 1, 3),
                (.enRouteTransit, .act2EnRoute, 2, 4),
                (.diversionArrival, .act3Arrival, 3, 3),
                (.emergencyInbound, .act3Arrival, 4, 4),
                (.fullArrival, .act3Arrival, 5, 2),
                (.emergencyInbound, .act3Arrival, 6, 3)
            ]
        }

        for (tIdx, slot) in trafficComposition.enumerated() {
            let trafficID = "T\(tIdx + 1)"
            let callsign = callsigns[min(slot.callsignIdx, callsigns.count - 1)]
            let acType = aircraftTypes[min(slot.acIdx, aircraftTypes.count - 1)]
            let isEmergencySlot = (slot.type == .emergencyInbound)
            let isMedicalSlot = hasMedical && (slot.type == .diversionArrival) && level >= .level4

            let trafficExchanges = buildATCTrafficExchanges(
                trafficID: trafficID,
                trafficType: slot.type,
                callsign: callsign,
                aircraftType: acType,
                airport: airport,
                runway: activeRunway,
                holdingPoint: holdingPoint,
                atisId: atisId,
                weather: weather,
                towerCallsign: towerCallsign,
                groundCallsign: groundCallsign,
                level: level,
                isEmergency: isEmergencySlot && hasEmergency,
                isMedical: isMedicalSlot,
                seed: chosenSeed + tIdx * 17,
                globalTurn: &globalTurn
            )

            let hasContingency = isEmergencySlot || isMedicalSlot
            let contingencySummary: String? = hasContingency
                ? (isEmergencySlot ? "Emergency inbound — priority handling required" : "Medical priority — ambulance standby")
                : nil

            allTrafficEntries.append(ATCTrafficEntry(
                trafficID: trafficID,
                callsign: callsign,
                aircraftType: acType,
                trafficType: slot.type,
                exchanges: trafficExchanges,
                act: slot.act,
                hasContingency: hasContingency,
                contingencySummary: contingencySummary
            ))
        }

        // 3-Act Diagnostic Report
        let act1Entries = allTrafficEntries.filter { $0.act == .act1Departure }
        let act2Entries = allTrafficEntries.filter { $0.act == .act2EnRoute }
        let act3Entries = allTrafficEntries.filter { $0.act == .act3Arrival }

        let act1Score = 85 + (abs(chosenSeed) % 12)
        let act2Score = act2Entries.isEmpty ? 90 : (82 + (abs(chosenSeed + 3) % 14))
        let act3Score = 80 + (abs(chosenSeed + 7) % 15)
        let overallScore = act2Entries.isEmpty
            ? (act1Score + act3Score) / 2
            : (act1Score + act2Score + act3Score) / 3

        let actEvals: [ActEvaluation] = [
            ActEvaluation(
                act: .act1Departure,
                score: act1Score, isPassed: act1Score >= 80,
                feedback: "Startup approval, taxi clearance, hold short readback, dan handoff Tower (\(act1Entries.count) pesawat)."
            ),
            ActEvaluation(
                act: .act2EnRoute,
                score: act2Score, isPassed: act2Score >= 80,
                feedback: act2Entries.isEmpty
                    ? "Tidak ada traffic transit di level ini."
                    : "Koordinasi sektor, conditional separation, relay posisi (\(act2Entries.count) pesawat)."
            ),
            ActEvaluation(
                act: .act3Arrival,
                score: act3Score, isPassed: act3Score >= 80,
                feedback: "Sequencing arrival, landing clearance, vacate instructions, emergency priority (\(act3Entries.count) pesawat)."
            )
        ]

        let report = DiagnosticReport(
            overallScore: overallScore,
            readbackAccuracyPercent: 87 + (abs(chosenSeed) % 10),
            phraseologyScorePercent: 84 + (abs(chosenSeed) % 13),
            disciplineScorePercent: 83 + (abs(chosenSeed) % 14),
            isPassed: overallScore >= 80,
            summaryFeedback: overallScore >= 80
                ? "Sesi ATC \(aerodromeItem.iata) lulus (\(overallScore)%). Seluruh traffic ditangani sesuai ICAO Doc 4444 & 9432."
                : "Perlu latihan ulang: pastikan readback hold short dan urutan pemanggilan bebas blocking.",
            improvementAreas: [
                "Pastikan setiap taxi clearance mencakup nama taxiway dan instruksi hold short secara eksplisit (Doc 4444 §7.9).",
                "Gunakan callsign lengkap di transmisi pertama, singkatan hanya setelah ditetapkan dua arah (Doc 9432 §4.3).",
                "Saat plain English digunakan (emergencies), tetap gunakan kata jangkar CLEARED, AFFIRM, NEGATIVE (Doc 9432 §2.6)."
            ],
            actEvaluations: actEvals
        )

        return ATCSessionScript(
            seed: chosenSeed,
            aerodrome: aerodromeItem,
            level: level,
            trafficEntries: allTrafficEntries,
            diagnosticReport: report
        )
    }

    // MARK: - ATC Session Support: Build Traffic Exchanges

    private func buildATCTrafficExchanges(
        trafficID: String,
        trafficType: ATCTrafficType,
        callsign: String,
        aircraftType: String,
        airport: Airport,
        runway: Runway,
        holdingPoint: String,
        atisId: String,
        weather: AlignedWeather,
        towerCallsign: String,
        groundCallsign: String,
        level: CurriculumLevel,
        isEmergency: Bool,
        isMedical: Bool,
        seed: Int,
        globalTurn: inout Int
    ) -> [FilledExchange] {
        var exchanges: [FilledExchange] = []
        let rwy = SpokenFormFormatter.runway(runway.designator)
        let qnh = SpokenFormFormatter.qnh(weather.qnh)
        let wind = SpokenFormFormatter.wind(direction: weather.windDirection, knots: weather.windSpeed)
        let taxiRoute = Self.composeTaxiRoute(from: airport.taxiways, seed: seed)
        let exitTaxiway = airport.taxiways.isEmpty ? "Echo" : airport.taxiways[abs(seed + 3) % airport.taxiways.count].spoken

        func ex(_ id: String, speaker: String, isUserTurn: Bool, text: String,
                criticalSlots: [CriticalSlot] = [], severity: EventSeverity = .normal, eventTag: String? = nil,
                layer: LanguageLayer = .standardPhraseology, peReason: String? = nil,
                objective: String? = nil) -> FilledExchange {
            let e = FilledExchange(
                exchangeID: "\(trafficID)-\(id)", templateID: id, turn: globalTurn,
                speaker: speaker, isUserTurn: isUserTurn, text: text,
                criticalSlots: criticalSlots, severity: severity, eventTag: eventTag,
                languageLayer: layer, plainEnglishTrigger: peReason,
                objective: objective
            )
            globalTurn += 1
            return e
        }

        switch trafficType {

        // ---- FULL DEPARTURE ----
        case .fullDeparture:
            let stand = StandGenerator.originStand(icao: airport.icao, seed: seed)
            let cleanStand = stand.replacingOccurrences(of: "stand ", with: "", options: .caseInsensitive)
            // Aircraft requests startup
            exchanges.append(ex("DEP-1", speaker: callsign, isUserTurn: false,
                text: "\(groundCallsign), \(callsign), stand \(cleanStand), request start-up, information \(atisId)."))
            // ATC approves startup
            exchanges.append(ex("DEP-2", speaker: "GROUND (USER TURN)", isUserTurn: true,
                text: "\(callsign), \(groundCallsign), start-up approved, QNH \(qnh), information \(atisId).",
                criticalSlots: [CriticalSlot(slot: "QNH", expectedValue: qnh, type: "mandatoryReadback")],
                objective: "Setujui permintaan start-up mesin, infokan QNH dan konfirmasi kode ATIS."))
            // Pilot reads back QNH
            exchanges.append(ex("DEP-3", speaker: callsign, isUserTurn: false,
                text: "Start-up approved, QNH \(qnh), \(callsign)."))
            // Aircraft requests taxi
            exchanges.append(ex("DEP-4", speaker: callsign, isUserTurn: false,
                text: "\(groundCallsign), \(callsign), request taxi."))
            // ATC gives taxi clearance with hold short
            exchanges.append(ex("DEP-5", speaker: "GROUND (USER TURN)", isUserTurn: true,
                text: "\(callsign), \(groundCallsign), taxi to holding point \(holdingPoint) via \(taxiRoute), hold short runway \(rwy), QNH \(qnh).",
                criticalSlots: [
                    CriticalSlot(slot: "RUNWAY", expectedValue: rwy, type: "mandatoryReadback"),
                    CriticalSlot(slot: "HOLD_SHORT", expectedValue: "hold short runway \(rwy)", type: "instantFail")
                ],
                objective: "Berikan rute taxi ke holding point via taxiway dan instruksikan hold short sebelum runway aktif."))

            // Hearback Error / Slip of the tongue challenge (Riza Januar / @sangpemandu style)
            let hasHearbackTaxi = (level >= .level2 && abs(seed) % 3 == 1)
            if hasHearbackTaxi {
                let slipRwy = SpokenFormFormatter.runway(runway.reciprocal)
                exchanges.append(ex("DEP-6-SLIP", speaker: callsign, isUserTurn: false,
                    text: "Taxi to holding point \(holdingPoint) via \(taxiRoute), hold short runway \(slipRwy), \(callsign).",
                    severity: .abnormal, eventTag: "PILOT SLIP OF TONGUE"))

                exchanges.append(ex("DEP-6-CORR", speaker: "GROUND (USER TURN)", isUserTurn: true,
                    text: "\(callsign), \(groundCallsign), NEGATIVE, I SAY AGAIN, hold short runway \(rwy).",
                    criticalSlots: [
                        CriticalSlot(slot: "NEGATIVE", expectedValue: "negative", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "RUNWAY", expectedValue: rwy, type: "instantFail")
                    ],
                    severity: .abnormal, eventTag: "ATC HEARBACK CORRECTION",
                    objective: "Koreksi kesalahan readback (slip of the tongue) pilot: tegaskan NEGATIVE I SAY AGAIN dan sebutkan nomor runway yang benar (Doc 9432 §2.8.3.9)."))

                exchanges.append(ex("DEP-6-ACK", speaker: callsign, isUserTurn: false,
                    text: "Hold short runway \(rwy), apologies, \(callsign)."))
            } else {
                exchanges.append(ex("DEP-6", speaker: callsign, isUserTurn: false,
                    text: "Taxi to holding point \(holdingPoint) via \(taxiRoute), hold short runway \(rwy), \(callsign)."))
            }

            // Aircraft ready for departure (now on Tower)
            exchanges.append(ex("DEP-7", speaker: callsign, isUserTurn: false,
                text: "\(towerCallsign), \(callsign), holding point \(holdingPoint), runway \(rwy), ready for departure."))

            // ATC gives line-up or take-off clearance
            let isLineUp = (level >= .level3 && abs(seed) % 2 == 0)
            let lineUpOrTO = isLineUp
                ? "\(callsign), \(towerCallsign), runway \(rwy), line up and wait."
                : "\(callsign), \(towerCallsign), wind \(wind), runway \(rwy), cleared for take-off."
            let lineUpObjective = isLineUp
                ? "Instruksikan pesawat masuk dan menunggu di landasan (line up and wait) karena ada lalu lintas."
                : "Berikan izin lepas landas (take-off clearance) beserta informasi arah dan kecepatan angin permukaan."
            exchanges.append(ex("DEP-8", speaker: "TOWER (USER TURN)", isUserTurn: true,
                text: lineUpOrTO,
                criticalSlots: [CriticalSlot(slot: "RUNWAY", expectedValue: rwy, type: "instantFail")],
                objective: lineUpObjective))

            // Callsign Confusion / Similar Call Sign Interception challenge (Sangpemandu style)
            let hasCallsignConfusion = isLineUp && (level >= .level4 && abs(seed) % 3 == 2)
            if hasCallsignConfusion {
                let confusedCallsign = "Batik six six eight three"
                exchanges.append(ex("DEP-9-HIJACK", speaker: confusedCallsign, isUserTurn: false,
                    text: "Line up and wait runway \(rwy), \(confusedCallsign)!",
                    severity: .abnormal, eventTag: "CALLSIGN CONFUSION"))

                exchanges.append(ex("DEP-9-INTERCEPT", speaker: "TOWER (USER TURN)", isUserTurn: true,
                    text: "\(confusedCallsign), NEGATIVE, instruction was for \(callsign). \(confusedCallsign), hold position.",
                    criticalSlots: [
                        CriticalSlot(slot: "NEGATIVE", expectedValue: "negative", type: "mandatoryKeyword"),
                        CriticalSlot(slot: "HOLD_POSITION", expectedValue: "hold position", type: "mandatoryKeyword")
                    ],
                    severity: .abnormal, eventTag: "CALLSIGN CONFUSION CORRECTION",
                    objective: "Intersepsi kerancuan callsign (similar callsign confusion): tegur pesawat yang salah ambil izin dengan NEGATIVE dan instruksikan hold position (Doc 9432 §4.3.2)."))

                exchanges.append(ex("DEP-9-CONFUSED-ACK", speaker: confusedCallsign, isUserTurn: false,
                    text: "Holding position, apologies, \(confusedCallsign)."))

                exchanges.append(ex("DEP-9-REAL-ACK", speaker: callsign, isUserTurn: false,
                    text: "Runway \(rwy), line up and wait, \(callsign)."))
            } else {
                let pilotDepReadback = isLineUp
                    ? "Runway \(rwy), line up and wait, \(callsign)."
                    : "Runway \(rwy), cleared for take-off, \(callsign)."
                exchanges.append(ex("DEP-9", speaker: callsign, isUserTurn: false,
                    text: pilotDepReadback))
            }
            // Airborne handoff
            let depRadarTarget = airport.units.departure?.callsign
                ?? airport.units.approach?.callsign
                ?? "Departure"
            let depRadarFreqVal = airport.units.departure?.frequency
                ?? airport.units.approach?.frequency
                ?? "119.750"
            let depRadarFreqSpoken = SpokenFormFormatter.frequency(depRadarFreqVal)

            exchanges.append(ex("DEP-10", speaker: "TOWER (USER TURN)", isUserTurn: true,
                text: "\(callsign), airborne, contact \(depRadarTarget) \(depRadarFreqSpoken), good day.",
                criticalSlots: [],
                objective: "Konfirmasi pesawat telah mengudara (airborne) dan alihkan kendali ke \(depRadarTarget)."))
            exchanges.append(ex("DEP-11", speaker: callsign, isUserTurn: false,
                text: "Contacting \(depRadarTarget) \(depRadarFreqSpoken), good day, \(callsign)."))

        // ---- TOUCH AND GO (VFR Circuit) ----
        case .touchAndGo:
            // Aircraft reports downwind
            exchanges.append(ex("TNG-1", speaker: callsign, isUserTurn: false,
                text: "\(towerCallsign), \(callsign), downwind runway \(rwy), touch and go."))
            // ATC sequences
            let spacing = (abs(seed) % 2 == 0) ? "Number two, follow the \(aircraftType) on final." : "Number one, runway \(rwy)."
            exchanges.append(ex("TNG-2", speaker: "TOWER (USER TURN)", isUserTurn: true,
                text: "\(callsign), \(towerCallsign), \(spacing)",
                objective: "Atur urutan pendekatan sirkuit visual (traffic sequencing & spacing)."))
            // Aircraft on base
            exchanges.append(ex("TNG-3", speaker: callsign, isUserTurn: false,
                text: "\(callsign), base runway \(rwy)."))
            // Cleared touch and go
            exchanges.append(ex("TNG-4", speaker: "TOWER (USER TURN)", isUserTurn: true,
                text: "\(callsign), \(towerCallsign), wind \(wind), runway \(rwy), cleared touch and go.",
                criticalSlots: [CriticalSlot(slot: "RUNWAY", expectedValue: rwy, type: "instantFail")],
                objective: "Berikan izin touch-and-go di landasan aktif beserta info angin permukaan."))
            exchanges.append(ex("TNG-5", speaker: callsign, isUserTurn: false,
                text: "Runway \(rwy), cleared touch and go, \(callsign)."))
            // Aircraft airborne again
            exchanges.append(ex("TNG-6", speaker: callsign, isUserTurn: false,
                text: "\(callsign), airborne, turning crosswind."))
            exchanges.append(ex("TNG-7", speaker: "TOWER (USER TURN)", isUserTurn: true,
                text: "\(callsign), \(towerCallsign), roger, report downwind.",
                objective: "Instruksikan pesawat latih untuk melapor kembali saat posisi downwind leg."))
            exchanges.append(ex("TNG-8", speaker: callsign, isUserTurn: false,
                text: "Report downwind, \(callsign)."))

        // ---- EN-ROUTE TRANSIT (Overflying, position report) ----
        case .enRouteTransit:
            let transitCallsign = callsign
            let reportFix = airport.procedures.holdings.first?.fix ?? "the field"
            exchanges.append(ex("TRN-1", speaker: transitCallsign, isUserTurn: false,
                text: "\(towerCallsign), \(transitCallsign), overhead \(reportFix) at three thousand five hundred feet, VFR, request traffic information."))
            exchanges.append(ex("TRN-2", speaker: "TOWER (USER TURN)", isUserTurn: true,
                text: "\(transitCallsign), \(towerCallsign), traffic information: one \(aircraftType) on final runway \(rwy), one departing. Report clear of zone.",
                objective: "Sampaikan advisory lalu lintas di aerodrome dan minta lapor saat keluar aerodrome zone."))
            exchanges.append(ex("TRN-3", speaker: transitCallsign, isUserTurn: false,
                text: "Traffic in sight, will report clear, \(transitCallsign)."))
            exchanges.append(ex("TRN-4", speaker: transitCallsign, isUserTurn: false,
                text: "\(towerCallsign), \(transitCallsign), clear of zone, changing to area frequency, good day."))
            exchanges.append(ex("TRN-5", speaker: "TOWER (USER TURN)", isUserTurn: true,
                text: "\(transitCallsign), \(towerCallsign), roger, frequency change approved, good day.",
                objective: "Izinkan pergantian frekuensi ke area kontrol berikutnya."))

        // ---- FULL ARRIVAL ----
        case .fullArrival:
            let isHolding = level >= .level3 && abs(seed) % 2 == 0
            if isHolding {
                // Aircraft reports inbound, ATC holds due to traffic
                exchanges.append(ex("ARR-1", speaker: callsign, isUserTurn: false,
                    text: "\(towerCallsign), \(callsign), inbound, information \(atisId), request approach."))
                exchanges.append(ex("ARR-2", speaker: "TOWER (USER TURN)", isUserTurn: true,
                    text: "\(callsign), \(towerCallsign), expect runway \(rwy), orbit right present position, traffic on final.",
                    objective: "Tahan pesawat dengan instruksi orbit 360° kanan untuk menjaga separasi lalu lintas."))
                exchanges.append(ex("ARR-3", speaker: callsign, isUserTurn: false,
                    text: "Orbiting right, \(callsign)."))
                exchanges.append(ex("ARR-4", speaker: "TOWER (USER TURN)", isUserTurn: true,
                    text: "\(callsign), \(towerCallsign), continue approach, runway \(rwy), cleared to land, wind \(wind).",
                    criticalSlots: [CriticalSlot(slot: "RUNWAY", expectedValue: rwy, type: "instantFail")],
                    objective: "Berikan izin mendarat (landing clearance) dan info angin setelah separasi tercapai."))
                exchanges.append(ex("ARR-5", speaker: callsign, isUserTurn: false,
                    text: "Runway \(rwy), cleared to land, \(callsign)."))
            } else {
                exchanges.append(ex("ARR-1", speaker: callsign, isUserTurn: false,
                    text: "\(towerCallsign), \(callsign), \(level == .level1 ? "final" : "established ILS") runway \(rwy)."))
                exchanges.append(ex("ARR-2", speaker: "TOWER (USER TURN)", isUserTurn: true,
                    text: "\(callsign), \(towerCallsign), wind \(wind), runway \(rwy), cleared to land.",
                    criticalSlots: [CriticalSlot(slot: "RUNWAY", expectedValue: rwy, type: "instantFail")],
                    objective: "Berikan izin mendarat (landing clearance) dan informasi angin permukaan."))

                let hasHearbackLanding = (level >= .level3 && abs(seed) % 4 == 2)
                if hasHearbackLanding {
                    let slipRwy = SpokenFormFormatter.runway(runway.reciprocal)
                    exchanges.append(ex("ARR-3-SLIP", speaker: callsign, isUserTurn: false,
                        text: "Runway \(slipRwy), cleared to land, \(callsign).",
                        severity: .abnormal, eventTag: "PILOT SLIP OF TONGUE"))

                    exchanges.append(ex("ARR-3-CORR", speaker: "TOWER (USER TURN)", isUserTurn: true,
                        text: "\(callsign), \(towerCallsign), NEGATIVE, I SAY AGAIN, runway \(rwy), cleared to land.",
                        criticalSlots: [
                            CriticalSlot(slot: "NEGATIVE", expectedValue: "negative", type: "mandatoryKeyword"),
                            CriticalSlot(slot: "RUNWAY", expectedValue: rwy, type: "instantFail")
                        ],
                        severity: .abnormal, eventTag: "ATC HEARBACK CORRECTION",
                        objective: "Koreksi kesalahan readback (slip of the tongue) pilot: tegaskan NEGATIVE I SAY AGAIN dan perjelas nomor runway aktif pendaratan (Doc 9432 §2.8.3.9)."))

                    exchanges.append(ex("ARR-3-ACK", speaker: callsign, isUserTurn: false,
                        text: "Runway \(rwy), cleared to land, apologies, \(callsign)."))
                } else {
                    exchanges.append(ex("ARR-3", speaker: callsign, isUserTurn: false,
                        text: "Runway \(rwy), cleared to land, \(callsign)."))
                }
            }
            // Vacate
            exchanges.append(ex("ARR-V1", speaker: callsign, isUserTurn: false,
                text: "\(callsign), runway vacated, \(exitTaxiway)."))
            exchanges.append(ex("ARR-V2", speaker: "TOWER (USER TURN)", isUserTurn: true,
                text: "\(callsign), \(towerCallsign), taxi to apron via \(exitTaxiway), contact Ground.",
                objective: "Instruksikan keluar landasan pacu (vacate) via taxiway dan transfer ke Ground Control."))
            exchanges.append(ex("ARR-V3", speaker: callsign, isUserTurn: false,
                text: "Taxi via \(exitTaxiway), contacting Ground, \(callsign)."))

        // ---- EMERGENCY INBOUND ----
        case .emergencyInbound:
            // Emergency declaration — Plain English mandatory (Doc 4444 Ch 15, Doc 9835 App B)
            let pob = 48 + abs(seed) % 110
            let endurance = "\(1 + abs(seed) % 3) hours \(15 + abs(seed) % 40) minutes"
            let emergencyDesc: String
            let severity: EventSeverity
            let tag: String
            let peReason: String
            let ackWord: String

            if isEmergency {
                // DISTRESS (MAYDAY 3x - official phraseology: MAYDAY, MAYDAY, MAYDAY)
                severity = .distress
                ackWord = "roger MAYDAY"
                let variant = abs(seed) % 3
                switch variant {
                case 0:
                    emergencyDesc = "MAYDAY, MAYDAY, MAYDAY, \(towerCallsign), \(callsign), engine number two flameout, single engine operation, request immediate landing runway \(rwy), souls on board \(pob), endurance \(endurance)."
                    tag = "MAYDAY — ENGINE FAILURE"
                    peReason = "MAYDAY declaration: pilot describes engine failure in plain language per Doc 9835 App B"
                case 1:
                    emergencyDesc = "MAYDAY, MAYDAY, MAYDAY, \(towerCallsign), \(callsign), dense smoke in cockpit, emergency descent, passing four thousand feet, request immediate landing and fire services on runway \(rwy)."
                    tag = "MAYDAY — COCKPIT SMOKE"
                    peReason = "Cockpit emergency: pilot conveys immediate danger in constrained plain English"
                default:
                    emergencyDesc = "MAYDAY, MAYDAY, MAYDAY FUEL, \(towerCallsign), \(callsign), remaining fuel fifteen minutes, below final reserve, unable to hold, request immediate landing runway \(rwy)."
                    tag = "MAYDAY — FUEL EMERGENCY"
                    peReason = "Fuel emergency declaration under ICAO Doc 4444 Chapter 15"
                }
            } else {
                // URGENCY (PAN PAN 3x - official phraseology: PAN PAN, PAN PAN, PAN PAN)
                severity = .urgency
                ackWord = "roger PAN PAN"
                let variant = abs(seed) % 4
                switch variant {
                case 0:
                    emergencyDesc = "PAN PAN, PAN PAN, PAN PAN, \(towerCallsign), \(callsign), hydraulic failure, flight controls degraded, request priority landing, runway \(rwy), souls on board \(pob)."
                    tag = "PAN PAN — HYDRAULIC FAILURE"
                    peReason = "PAN PAN urgency: pilot communicates degraded flight control per Doc 9835 §3.3.19"
                case 1:
                    emergencyDesc = "PAN PAN, PAN PAN, PAN PAN, \(towerCallsign), \(callsign), flap extension failure, unable to extend flaps, approach speed one six zero knots, request priority landing runway \(rwy)."
                    tag = "PAN PAN — FLAP FAILURE"
                    peReason = "Flap malfunction: pilot requests high speed straight-in priority"
                case 2:
                    emergencyDesc = "PAN PAN, PAN PAN, PAN PAN, \(towerCallsign), \(callsign), nose gear unsafe indication, request low pass over tower cab for visual inspection of landing gear before full stop."
                    tag = "PAN PAN — UNSAFE GEAR LOW PASS"
                    peReason = "Gear visual check request: low pass coordination with tower"
                default:
                    emergencyDesc = "PAN PAN, PAN PAN, PAN PAN, \(towerCallsign), \(callsign), bird strike on approach, severe engine vibration, request precautionary priority landing runway \(rwy)."
                    tag = "PAN PAN — BIRD STRIKE VIBRATION"
                    peReason = "Bird strike damage advisory: priority precautionary landing"
                }
            }

            exchanges.append(ex("EMG-1", speaker: callsign, isUserTurn: false,
                text: emergencyDesc, severity: severity, eventTag: tag,
                layer: .constrainedPlainEnglish, peReason: peReason))

            // ATC responds with correct acknowledgement matching severity (Doc 9432 §8.1 / §9.1)
            let atcResponse = "\(callsign), \(towerCallsign), \(ackWord), runway \(rwy) cleared, emergency services are standing by, wind \(wind), cleared to land."
            exchanges.append(ex("EMG-2", speaker: "TOWER (USER TURN)", isUserTurn: true,
                text: atcResponse,
                criticalSlots: [CriticalSlot(slot: "RUNWAY", expectedValue: rwy, type: "instantFail")],
                severity: severity, eventTag: "PRIORITY CLEARANCE",
                layer: .constrainedPlainEnglish,
                peReason: "Emergency response: ATC confirms situation understanding and clears runway (Doc 9432 §8.1)",
                objective: "Konfirmasi situasi \(severity == .distress ? "darurat MAYDAY" : "urgensi PAN PAN"), berikan prioritas mutlak pendaratan di runway aktif."))

            // If medical: describe patient (Doc 9835 §3.3.15)
            if isMedical {
                exchanges.append(ex("EMG-3", speaker: callsign, isUserTurn: false,
                    text: "Tower, \(callsign), we have a passenger with suspected cardiac arrest, request ambulance at the gate.",
                    severity: .urgency, eventTag: "MEDICAL PAN PAN",
                    layer: .constrainedPlainEnglish,
                    peReason: "Medical situation: patient condition description requires plain English (Doc 9835 §3.3.15)"))
                exchanges.append(ex("EMG-4", speaker: "TOWER (USER TURN)", isUserTurn: true,
                    text: "\(callsign), \(towerCallsign), understood, ambulance is requested, standby at apron Alpha.",
                    severity: .urgency, eventTag: "AMBULANCE CONFIRMED",
                    layer: .constrainedPlainEnglish,
                    peReason: "Confirming medical coordination in plain language (Doc 9835 §3.3.15)",
                    objective: "Konfirmasi koordinasi bantuan medis ambulans gawat darurat standby di apron."))
            }

            // Return to standard phrase for landing sequence
            exchanges.append(ex("EMG-F1", speaker: callsign, isUserTurn: false,
                text: "Runway \(rwy), cleared to land, \(callsign)."))
            exchanges.append(ex("EMG-F2", speaker: callsign, isUserTurn: false,
                text: "\(callsign), runway vacated, \(exitTaxiway)."))
            exchanges.append(ex("EMG-F3", speaker: "TOWER (USER TURN)", isUserTurn: true,
                text: "\(callsign), \(towerCallsign), taxi to apron, emergency services will meet you. Cancel emergency if able.",
                criticalSlots: [],
                objective: "Pandu pesawat darurat ke apron dan koordinasikan penanganan dengan tim PKP-PK."))

        // ---- DIVERSION ARRIVAL ----
        case .diversionArrival:
            // Aircraft announces diversion — official phraseology: PAN PAN, PAN PAN, PAN PAN (Doc 9432 §9.3.1)
            let divReason = (abs(seed) % 2 == 0)
                ? "diverting from \(airport.name.components(separatedBy: " ").last ?? "destination") due weather, request immediate approach, fuel \(30 + abs(seed) % 30) minutes remaining"
                : "diverting due passenger medical emergency, request priority straight-in approach and medical team"
            let divTag = (abs(seed) % 2 == 0) ? "WEATHER DIVERSION PAN PAN" : "MEDICAL DIVERSION PAN PAN"
            let diversionText = "PAN PAN, PAN PAN, PAN PAN, \(towerCallsign), \(callsign), \(divReason), runway \(rwy)."
            exchanges.append(ex("DIV-1", speaker: callsign, isUserTurn: false,
                text: diversionText, severity: .urgency, eventTag: divTag,
                layer: .constrainedPlainEnglish,
                peReason: "Diversion declaration: emergency state requires plain English per Doc 9835 §3.4.14"))

            exchanges.append(ex("DIV-2", speaker: "TOWER (USER TURN)", isUserTurn: true,
                text: "\(callsign), \(towerCallsign), roger PAN PAN, runway \(rwy) clear, you are number one, wind \(wind), QNH \(qnh), cleared to land.",
                criticalSlots: [CriticalSlot(slot: "RUNWAY", expectedValue: rwy, type: "instantFail")],
                severity: .urgency, eventTag: "PRIORITY CLEARED",
                objective: "Terima urgensi pengalihan (diversion), prioritaskan urutan nomor satu dan berikan izin mendarat."))

            exchanges.append(ex("DIV-3", speaker: callsign, isUserTurn: false,
                text: "Runway \(rwy), cleared to land, QNH \(qnh), \(callsign)."))
            exchanges.append(ex("DIV-4", speaker: callsign, isUserTurn: false,
                text: "\(callsign), runway vacated."))
            exchanges.append(ex("DIV-5", speaker: "TOWER (USER TURN)", isUserTurn: true,
                text: "\(callsign), \(towerCallsign), taxi to apron, contact Ground on \(SpokenFormFormatter.frequency(airport.units.ground?.frequency ?? "121.600")).",
                objective: "Instruksikan taxi ke apron dan arahkan kontak ke Ground Control."))
        }

        return exchanges
    }

    // MARK: - ATC Session Support: Callsign & Aircraft Pools

    private func buildATCCallsignPool(level: CurriculumLevel, seed: Int) -> [String] {
        switch level {
        case .level1:
            return ["PK-KRS", "PK-ROZ", "PK-MID", "PK-ADH"]
        case .level2:
            let commercial = ["Citilink \(100 + abs(seed) % 900)", "Wings \(200 + abs(seed) % 700)"]
            let local = ["PK-KRS", "PK-ROZ"]
            return local + commercial
        case .level3:
            return ["Pelita \(500 + abs(seed) % 500)", "Batik \(6000 + abs(seed) % 999)",
                    "Lion \(100 + abs(seed) % 800)", "Indonesia \(200 + abs(seed) % 700)",
                    "Supergreen \(500 + abs(seed) % 200)", "Prosper \(100 + abs(seed) % 300)"]
        case .level4:
            return ["Batik \(6000 + abs(seed) % 999)", "Lion \(100 + abs(seed) % 800)",
                    "Supergreen \(800 + abs(seed) % 200)", "Indonesia \(200 + abs(seed) % 400) Heavy",
                    "TransNusa \(100 + abs(seed) % 300)", "Prosper \(100 + abs(seed) % 300)"]
        case .level5:
            return ["Trigana \(200 + abs(seed) % 100)", "Smart \(100 + abs(seed) % 50)",
                    "Susi Air \(110 + abs(seed) % 20)", "Asian One \(300 + abs(seed) % 50)",
                    "Wings Air \(1800 + abs(seed) % 100)"]
        }
    }

    private func buildATCAircraftPool(level: CurriculumLevel, seed: Int) -> [String] {
        switch level {
        case .level1: return ["C172", "C172S", "DA40"]
        case .level2: return ["C172", "ATR 72", "B737-500"]
        case .level3: return ["B737-800", "A320", "ATR 72"]
        case .level4: return ["B737-800", "A320", "A330", "B737 MAX 8"]
        case .level5: return ["DHC-6 Twin Otter", "C208B Grand Caravan", "ATR 72-600", "B737-500 STOL", "Pilatus PC-6"]
        }
    }

    // MARK: - Level 5 VHF Partyline Realistic Interruption Engine
    private func generateLevel5PartylineInterruption(
        phase: Phase,
        station: String,
        rwy: String,
        airportICAO: String,
        studentCallsign: String,
        seed: Int,
        globalTurn: inout Int
    ) -> [FilledExchange] {
        var exchanges: [FilledExchange] = []

        struct RegionalTraffic {
            let callsign: String
            let aircraft: String
        }

        let trafficPool: [RegionalTraffic]
        let isPapua = (airportICAO == "WAVV" || airportICAO == "WABP")
        let isToraja = (airportICAO == "WAFB")
        let isBandung = (airportICAO == "WICC" || airportICAO == "WIHH")
        let isTarakan = (airportICAO == "WALR" || airportICAO == "WALL")

        if isPapua {
            trafficPool = [
                RegionalTraffic(callsign: "Smart one zero two", aircraft: "DHC-6 Twin Otter"),
                RegionalTraffic(callsign: "Susi Air one one four", aircraft: "C208B Grand Caravan"),
                RegionalTraffic(callsign: "Trigana two four one", aircraft: "B737-500 STOL"),
                RegionalTraffic(callsign: "Asian One three one zero", aircraft: "C208B Grand Caravan"),
                RegionalTraffic(callsign: "Rimbun Air five zero two", aircraft: "DHC-6 Twin Otter")
            ]
        } else if isToraja {
            trafficPool = [
                RegionalTraffic(callsign: "Wings Air one eight five five", aircraft: "ATR 72-600"),
                RegionalTraffic(callsign: "Smart one zero five", aircraft: "DHC-6 Twin Otter"),
                RegionalTraffic(callsign: "Susi Air one two zero", aircraft: "C208B Grand Caravan")
            ]
        } else if isBandung {
            trafficPool = [
                RegionalTraffic(callsign: "Wings Air one eight five two", aircraft: "ATR 72-600"),
                RegionalTraffic(callsign: "Batik four zero two", aircraft: "Airbus A320"),
                RegionalTraffic(callsign: "Lion Air seven one two", aircraft: "Boeing 737-800"),
                RegionalTraffic(callsign: "Supergreen four two six", aircraft: "ATR 72-600")
            ]
        } else if isTarakan {
            trafficPool = [
                RegionalTraffic(callsign: "Smart one one eight", aircraft: "DHC-6 Twin Otter"),
                RegionalTraffic(callsign: "Wings Air one eight five zero", aircraft: "ATR 72-600"),
                RegionalTraffic(callsign: "Batik four one two", aircraft: "Boeing 737-800")
            ]
        } else {
            trafficPool = [
                RegionalTraffic(callsign: "Smart two zero four", aircraft: "C208B Grand Caravan"),
                RegionalTraffic(callsign: "Wings Air one eight zero two", aircraft: "ATR 72-600"),
                RegionalTraffic(callsign: "Trigana one seven two", aircraft: "ATR 42-300")
            ]
        }

        let filteredPool = trafficPool.filter { $0.callsign.lowercased() != studentCallsign.lowercased() }
        let selectedTraffic = filteredPool.isEmpty ? trafficPool[0] : filteredPool[abs(seed / 13) % filteredPool.count]
        let tCall = selectedTraffic.callsign
        let tPlane = selectedTraffic.aircraft

        let chatterPayload = PartylineChatterPayload(
            isActive: true,
            audioTrackName: "chatter_loop_papua_vhf",
            baseVolume: 0.25,
            duckingVolume: 0.10,
            isDucking: false,
            activeTrafficCallsign: tCall,
            activeTrafficAircraft: tPlane,
            frequencyStatus: "CHANNEL_OCCUPIED_MONITOR_ONLY"
        )

        let monitorObjective = "[MONITOR ONLY] Dengarkan transmisi pesawat lain di frekuensi yang sama. TAHAN TRANSMISI (jangan tekan PTT) hingga frekuensi bebas."

        if phase == .preDeparture {
            let variant = abs(seed / 19) % 2
            if variant == 0 {
                exchanges.append(FilledExchange(
                    exchangeID: "PL-PD-1", templateID: "PL-01", turn: globalTurn, speaker: "TRAFFIC (\(tCall))",
                    isUserTurn: false,
                    text: "\(station), \(tCall), vacated runway \(rwy) via taxiway Bravo, request taxi to apron.",
                    criticalSlots: [], severity: .normal, eventTag: "PARTYLINE TRAFFIC CONTENTION",
                    objective: monitorObjective,
                    partylinePayload: chatterPayload
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "PL-PD-2", templateID: "PL-01", turn: globalTurn, speaker: "ATC",
                    isUserTurn: false,
                    text: "\(tCall), \(station), taxi to apron stand two via Bravo, hold short taxiway Alfa.",
                    criticalSlots: [], severity: .normal, eventTag: "PARTYLINE ATC INSTRUCTION",
                    partylinePayload: chatterPayload
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "PL-PD-3", templateID: "PL-01", turn: globalTurn, speaker: "TRAFFIC (\(tCall))",
                    isUserTurn: false,
                    text: "Taxi to apron stand two via Bravo, hold short taxiway Alfa, \(tCall).",
                    criticalSlots: [], severity: .normal, eventTag: "PARTYLINE TRAFFIC CONTENTION",
                    objective: monitorObjective,
                    partylinePayload: chatterPayload
                ))
                globalTurn += 1
            } else {
                exchanges.append(FilledExchange(
                    exchangeID: "PL-PD-1", templateID: "PL-01", turn: globalTurn, speaker: "TRAFFIC (\(tCall))",
                    isUserTurn: false,
                    text: "\(station), \(tCall), apron stand two, request start-up.",
                    criticalSlots: [], severity: .normal, eventTag: "PARTYLINE TRAFFIC CONTENTION",
                    objective: monitorObjective,
                    partylinePayload: chatterPayload
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "PL-PD-2", templateID: "PL-01", turn: globalTurn, speaker: "ATC",
                    isUserTurn: false,
                    text: "\(tCall), \(station), hold position, expect two minutes delay due departing traffic.",
                    criticalSlots: [], severity: .normal, eventTag: "PARTYLINE ATC INSTRUCTION",
                    partylinePayload: chatterPayload
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "PL-PD-3", templateID: "PL-01", turn: globalTurn, speaker: "TRAFFIC (\(tCall))",
                    isUserTurn: false,
                    text: "Hold position, \(tCall).",
                    criticalSlots: [], severity: .normal, eventTag: "PARTYLINE TRAFFIC CONTENTION",
                    objective: monitorObjective,
                    partylinePayload: chatterPayload
                ))
                globalTurn += 1
            }
        } else if phase == .approach {
            let variant = abs(seed / 23) % 3
            if variant == 0 {
                let gapName = isPapua ? "Baliem Gap" : (isToraja ? "Rantepao Valley" : "Cimahi Ridge")
                exchanges.append(FilledExchange(
                    exchangeID: "PL-AP-1", templateID: "PL-02", turn: globalTurn, speaker: "TRAFFIC (\(tCall))",
                    isUserTurn: false,
                    text: "\(station), \(tCall), passing \(gapName), descending altitude niner thousand feet, visual runway \(rwy).",
                    criticalSlots: [], severity: .normal, eventTag: "PARTYLINE TRAFFIC CONTENTION",
                    objective: monitorObjective,
                    partylinePayload: chatterPayload
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "PL-AP-2", templateID: "PL-02", turn: globalTurn, speaker: "ATC",
                    isUserTurn: false,
                    text: "\(tCall), \(station), roger, report right base runway \(rwy), number two behind traffic on final.",
                    criticalSlots: [], severity: .normal, eventTag: "PARTYLINE ATC INSTRUCTION",
                    partylinePayload: chatterPayload
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "PL-AP-3", templateID: "PL-02", turn: globalTurn, speaker: "TRAFFIC (\(tCall))",
                    isUserTurn: false,
                    text: "Right base runway \(rwy), number two, \(tCall).",
                    criticalSlots: [], severity: .normal, eventTag: "PARTYLINE TRAFFIC CONTENTION",
                    objective: monitorObjective,
                    partylinePayload: chatterPayload
                ))
                globalTurn += 1
            } else if variant == 1 {
                exchanges.append(FilledExchange(
                    exchangeID: "PL-AP-1", templateID: "PL-02", turn: globalTurn, speaker: "TRAFFIC (\(tCall))",
                    isUserTurn: false,
                    text: "\(station), \(tCall), caution all stations, moderate downdraft and mountain wave north of the ridge at seven thousand feet.",
                    criticalSlots: [], severity: .urgency, eventTag: "PARTYLINE WEATHER ADVISORY",
                    objective: monitorObjective,
                    partylinePayload: chatterPayload
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "PL-AP-2", templateID: "PL-02", turn: globalTurn, speaker: "ATC",
                    isUserTurn: false,
                    text: "\(tCall), \(station), copied weather advisory, thank you.",
                    criticalSlots: [], severity: .normal, eventTag: "PARTYLINE ATC ACKNOWLEDGEMENT",
                    partylinePayload: chatterPayload
                ))
                globalTurn += 1
            } else {
                exchanges.append(FilledExchange(
                    exchangeID: "PL-AP-1", templateID: "PL-02", turn: globalTurn, speaker: "TRAFFIC (\(tCall))",
                    isUserTurn: false,
                    text: "\(station), \(tCall), overhead valley fix, request three sixty orbit for cloud clearance.",
                    criticalSlots: [], severity: .normal, eventTag: "PARTYLINE TRAFFIC CONTENTION",
                    objective: monitorObjective,
                    partylinePayload: chatterPayload
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "PL-AP-2", templateID: "PL-02", turn: globalTurn, speaker: "ATC",
                    isUserTurn: false,
                    text: "\(tCall), \(station), three sixty orbit approved right hand, report roll out heading.",
                    criticalSlots: [], severity: .normal, eventTag: "PARTYLINE ATC INSTRUCTION",
                    partylinePayload: chatterPayload
                ))
                globalTurn += 1

                exchanges.append(FilledExchange(
                    exchangeID: "PL-AP-3", templateID: "PL-02", turn: globalTurn, speaker: "TRAFFIC (\(tCall))",
                    isUserTurn: false,
                    text: "Orbit approved right hand, will report roll out, \(tCall).",
                    criticalSlots: [], severity: .normal, eventTag: "PARTYLINE TRAFFIC CONTENTION",
                    objective: monitorObjective,
                    partylinePayload: chatterPayload
                ))
                globalTurn += 1
            }
        }

        return exchanges
    }

    // MARK: - Pre-Flight Operational Storytelling Narrative Briefing Generator
    private func generateMissionStoryBriefing(
        level: CurriculumLevel?,
        origin: Airport,
        destination: Airport,
        callsign: String,
        aircraftType: String,
        seed: Int
    ) -> MissionStoryBriefing {
        let actualLevel = level ?? .level1
        let origICAO = origin.icao
        let origName = origin.name
        let destName = destination.name

        switch actualLevel {
        case .level1:
            // Authentic Indonesian Flying School Cadets
            if origICAO == "WADY" {
                // Akademi Penerbang Indonesia (API) Banyuwangi (formerly LP3B)
                return MissionStoryBriefing(
                    title: "Solo VFR Circuit Training & Pattern Work",
                    roleContext: "Student Pilot — Indonesian Flying Academy (API) Banyuwangi",
                    narrativeText: "This morning, you are a Student Pilot at the Indonesian Flying Academy (API) Banyuwangi completing your solo visual flight training. You are scheduled to fly the \(aircraftType) trainer (registration \(callsign)) for standard VFR circuit pattern training at Blimbingsari Airport. Aerodrome weather is exceptional with CAVOK conditions, horizontal visibility exceeding 10 km, and a gentle coastal breeze off the Bali Strait. Your flight profile is to report ready for taxi on the apron, hold short at the assigned runway intersection, execute an initial climb to 1,000 feet pattern altitude, and perform touch-and-go circuits before full-stop landing as directed by Blimbingsari Tower.",
                    passengerCount: 0,
                    flightRule: "VFR (Visual Flight Rules)",
                    missionTypeDescription: "Solo Cadet Flight Training",
                    weatherBriefingSummary: "CAVOK, calm surface wind, visibility > 10 km, standard local QNH"
                )
            } else if origICAO == "WICB" {
                // Politeknik Penerbangan Indonesia (PPI) Curug (formerly STPI Curug)
                return MissionStoryBriefing(
                    title: "Basic VFR Syllabus & Local Training Area Maneuvers",
                    roleContext: "Student Pilot — Indonesian Civil Aviation Polytechnic (PPI) Curug",
                    narrativeText: "Today you are acting as a Flight Cadet at the Indonesian Civil Aviation Polytechnic (PPI) Curug. You are assigned to fly \(aircraftType) with callsign \(callsign) for visual traffic circuits and basic airwork maneuvers in the Curug Local Training Area. Atmospheric conditions over Banten are calm with excellent visibility and a high cloud ceiling. Your objective is to practice standard ground radiotelephony with Curug Ground, maintain strict holding point discipline, and fly orderly visual circuits under instructor supervision.",
                    passengerCount: 0,
                    flightRule: "VFR (Visual Flight Rules)",
                    missionTypeDescription: "Cadet Training Syllabus Flight",
                    weatherBriefingSummary: "Prime VMC conditions, visibility > 10 km, steady headwind"
                )
            } else if origICAO == "WADE" {
                // Bali International Flight Academy (BIFA) Buleleng
                return MissionStoryBriefing(
                    title: "West Bali Coastal VFR Touch-and-Go Training",
                    roleContext: "Student Pilot — Bali International Flight Academy (BIFA)",
                    narrativeText: "As a flight cadet at Bali International Flight Academy (BIFA) operating out of Lt. Col. Wisnu Airfield in Sumberkima, Buleleng, you are preparing to fly trainer \(aircraftType) (\(callsign)). This morning you will conduct touch-and-go circuit practice over Teluk Terima and the scenic West Bali coastline. Sky conditions are clear of convective clouds with a cool sea breeze. Your focus is sharp radio coordination, disciplined apron taxi, and crisp readback delivery to Wisnu Tower.",
                    passengerCount: 0,
                    flightRule: "VFR (Visual Flight Rules)",
                    missionTypeDescription: "Solo Cadet Circuit Training",
                    weatherBriefingSummary: "Clear blue skies, smooth air, unlimited visibility"
                )
            } else {
                return MissionStoryBriefing(
                    title: "Local Aerodrome Visual Circuit Training",
                    roleContext: "Student Pilot — Flight Training Academy",
                    narrativeText: "This morning you are a student pilot cadet conducting visual traffic circuits at \(origName) aboard \(aircraftType) (\(callsign)). Local aerodrome weather is pristine with scattered clouds and visibility well over 10 km. You are ready to execute standard ground coordination, departure roll, and full visual circuit operations following standard operating procedures.",
                    passengerCount: 0,
                    flightRule: "VFR (Visual Flight Rules)",
                    missionTypeDescription: "VFR Circuit Pattern Practice",
                    weatherBriefingSummary: "CAVOK, calm surface wind, excellent visibility"
                )
            }

        case .level2:
            let pax = 64 + (abs(seed) % 8)
            return MissionStoryBriefing(
                title: "Scheduled Inter-City Regional Turboprop Commercial Flight",
                roleContext: "Junior First Officer — Regional Commercial Airline",
                narrativeText: "You are serving as First Officer in the cockpit of the \(aircraftType) turboprop under flight number \(callsign). Today you are operating a scheduled passenger flight connecting \(origName) to \(destName). The cabin is carrying \(pax) passengers and 4 flight crew members, with 750 kg of checked baggage in the cargo hold. The aviation weather briefing indicates calm en-route conditions with moderate surface winds and visibility exceeding 10 km. Having finalized fuel calculations and your IFR flight plan, you are now preparing to request route clearance, manage departure taxi, and climb to cruising flight level.",
                passengerCount: pax,
                flightRule: "IFR (Instrument Flight Rules)",
                missionTypeDescription: "Scheduled Regional Passenger Service",
                weatherBriefingSummary: "Clear en-route conditions, steady surface wind, visibility > 10 km"
            )

        case .level3:
            let pax = 152 + (abs(seed) % 24)
            return MissionStoryBriefing(
                title: "Scheduled Domestic Trunk Route Commercial Jet Flight",
                roleContext: "Senior First Officer / Pilot Monitoring — Commercial Airline",
                narrativeText: "Today you are acting as Pilot Monitoring (PM) in the cockpit of a \(aircraftType) jetliner (\(callsign)) for a scheduled trunk route flight from \(origName) to \(destName). The flight is booked with \(pax) passengers and 6 cabin crew members at optimal payload. En-route meteorological charts confirm a smooth cruise in stable upper air masses with excellent visibility at both departure and destination airports. Your primary responsibility is delivering crisp, precise IFR radiotelephony exchanges across Delivery, Ground, Tower, and Radar sectors.",
                passengerCount: pax,
                flightRule: "IFR (Instrument Flight Rules)",
                missionTypeDescription: "Scheduled Domestic Commercial Flight",
                weatherBriefingSummary: "Excellent terminal visibility, smooth cruising conditions"
            )

        case .level4:
            let pax = 168 + (abs(seed) % 20)
            return MissionStoryBriefing(
                title: "Peak-Hour Metro Hub Flight & A-CDM Slot Management",
                roleContext: "Captaincy Candidate / Pilot Flying — High-Density Metro Hub",
                narrativeText: "You are acting as Pilot Flying on a high-density late afternoon peak flight from \(origName) to \(destName) operating \(aircraftType) (\(callsign)). The aircraft is fully booked with \(pax) passengers and priority commercial cargo. The departure aerodrome operates under strict Airport Collaborative Decision Making (A-CDM) protocols with tight Target Start-Up Times (TSAT) amidst heavy ramp congestion. Weather is CAVOK with horizontal visibility greater than 10 km. Your mission demands razor-sharp radiotelephony, uncompromising holding point compliance, and precision RNAV navigation.",
                passengerCount: pax,
                flightRule: "IFR (Instrument Flight Rules)",
                missionTypeDescription: "Scheduled Major Hub Commercial Flight",
                weatherBriefingSummary: "CAVOK, steady headwind, visibility > 10 km"
            )

        case .level5:
            if origICAO == "WAVV" || origICAO == "WABP" {
                let pax = 16 + (abs(seed) % 4)
                return MissionStoryBriefing(
                    title: "Highland Valley Pioneer Logistics & Passenger Flight",
                    roleContext: "Pioneer Mountain Pilot — Highland Remote Operations",
                    narrativeText: "This morning you are commanding a remote highland pioneer flight across the rugged Jayawijaya mountain range between \(origName) and \(destName) in the rugged \(aircraftType) (\(callsign)). The cabin carries \(pax) local passengers alongside 650 kg of essential food supplies and medical cargo for isolated valley communities. Morning reports from mountain observation outposts show an open cloud gap through the Baliem valley corridor with cool valley winds and adequate visual flight conditions. Operating in a tight valley with a shared VHF radio frequency (Partyline), you prepare to navigate visually along terrain contours while closely monitoring traffic broadcasts from other bush pilots on the common advisory channel.",
                    passengerCount: pax,
                    flightRule: "VFR / IFR Mountain Valley Corridor",
                    missionTypeDescription: "Pioneer Supply & Passenger Transport",
                    weatherBriefingSummary: "Mountain gap open, cool valley breeze 15-20 kt, good visual reference"
                )
            } else if origICAO == "WAFB" {
                let pax = 42 + (abs(seed) % 8)
                return MissionStoryBriefing(
                    title: "Highland Commuter Service: Toraja Valley to Makassar",
                    roleContext: "First Officer — Sulawesi Mountain Route Operations",
                    narrativeText: "You are flying a scheduled morning service departing from the Toraja highlands at \(origName) bound for \(destName) aboard \(aircraftType) (\(callsign)). The flight is booked with \(pax) passengers and full baggage allowance. Morning mountain mist in the Toraja basin is lifting under early sunlight, and winds are light at 12 knots off the ridges. You have planned your initial departure climb along the valley corridor before establishing standard cruising altitude over the western Sulawesi coastline.",
                    passengerCount: pax,
                    flightRule: "IFR Mountain Departure",
                    missionTypeDescription: "Highland Commuter Regional Service",
                    weatherBriefingSummary: "Valley mist dispersing, gentle ridge winds, visual visibility > 8 km"
                )
            } else if origICAO == "WICC" {
                let pax = 68 + (abs(seed) % 6)
                return MissionStoryBriefing(
                    title: "Morning Commuter Flight: Bandung Basin to Capital Gateway",
                    roleContext: "First Officer — Capital Corridor Commercial Commuter",
                    narrativeText: "You are piloting a morning commuter flight from Husein Sastranegara Airport (\(origName)) to \(destName) carrying \(pax) business travelers. The volcanic basin surrounding Bandung reports scattered cloud cover, calm surface winds, and 9 km visibility. You are preparing for pushback from the shared military ramp, climbing out on an instrument departure profile, and cruising smoothly into the Jakarta TMA corridor.",
                    passengerCount: pax,
                    flightRule: "IFR (Instrument Flight Rules)",
                    missionTypeDescription: "Scheduled Commercial Commuter Flight",
                    weatherBriefingSummary: "Partly cloudy over ridges, calm surface wind, visibility 9 km"
                )
            } else {
                let pax = 50 + (abs(seed) % 10)
                return MissionStoryBriefing(
                    title: "Coastal & Outer-Island Pioneer Regional Flight",
                    roleContext: "Pioneer Captain — Island Air Service",
                    narrativeText: "You are executing a scheduled regional inter-island service from \(origName) to \(destName) piloting \(aircraftType) (\(callsign)) with \(pax) passengers on board. Coastal weather reports indicate clear to scattered skies with gentle sea breezes and excellent visibility exceeding 10 km. Your flight plan follows standard coastal airway waypoints at assigned cruising altitude.",
                    passengerCount: pax,
                    flightRule: "IFR (Instrument Flight Rules)",
                    missionTypeDescription: "Regional Pioneer Air Service",
                    weatherBriefingSummary: "Scattered fair-weather clouds, visibility > 10 km, smooth flight conditions"
                )
            }
        }
    }
}
