import Foundation

public struct SelectedRunway: Equatable, Sendable {
    public let runway: String
    public let headwindKnots: Double
    public let crosswindKnots: Double

    public init(runway: String, headwindKnots: Double, crosswindKnots: Double) {
        self.runway = runway
        self.headwindKnots = headwindKnots
        self.crosswindKnots = crosswindKnots
    }
}

public struct AlignedWeather: Equatable, Sendable {
    public let runway: String
    public let heading: Double
    public let windDirection: Int
    public let windSpeed: Int
    public let headwindKnots: Double
    public let crosswindKnots: Double
    public let qnh: Int

    public init(
        runway: String,
        heading: Double,
        windDirection: Int,
        windSpeed: Int,
        headwindKnots: Double,
        crosswindKnots: Double,
        qnh: Int
    ) {
        self.runway = runway
        self.heading = heading
        self.windDirection = windDirection
        self.windSpeed = windSpeed
        self.headwindKnots = headwindKnots
        self.crosswindKnots = crosswindKnots
        self.qnh = qnh
    }
}

public enum WeatherEngine {
    public static func windComponents(
        runwayHeading: Double,
        windDirection: Double,
        windSpeed: Double
    ) -> (headwind: Double, crosswind: Double) {
        let diffRad = abs(windDirection - runwayHeading) * .pi / 180.0
        let headwind = windSpeed * cos(diffRad)
        let crosswind = windSpeed * abs(sin(diffRad))
        return (
            (headwind * 10).rounded() / 10,
            (crosswind * 10).rounded() / 10
        )
    }

    public static func bestRunway(
        pair: [String],
        headings: [String: Double],
        windDirection: Double,
        windSpeed: Double
    ) -> SelectedRunway {
        var bestRwy = pair.first ?? ""
        var bestHw = -999.0
        var bestXw = 0.0

        for rwy in pair {
            let hdg = headings[rwy] ?? 0.0
            let (hw, xw) = windComponents(
                runwayHeading: hdg,
                windDirection: windDirection,
                windSpeed: windSpeed
            )
            if hw > bestHw {
                bestHw = hw
                bestXw = xw
                bestRwy = rwy
            }
        }

        return SelectedRunway(runway: bestRwy, headwindKnots: bestHw, crosswindKnots: bestXw)
    }

    public static func alignedWeather(
        runway: String,
        heading: Double,
        seed: Int,
        level: CurriculumLevel? = nil
    ) -> AlignedWeather {
        // Linear congruential generator for deterministic pseudo-randomness
        var state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        func nextRandom(min: Double, max: Double) -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let unit = Double(state >> 16) / Double(1 << 48)
            return min + unit * (max - min)
        }

        // Pseudo-random selection between primary heading and reciprocal runway heading
        let isReciprocalFlow = (abs(seed) % 2 == 1)
        let baseHeading = isReciprocalFlow ? (heading + 180.0) : heading
        let delta = nextRandom(min: -35.0, max: 35.0)
        let rawDir = (baseHeading + delta).truncatingRemainder(dividingBy: 360.0)
        let windDir = Int((rawDir + 360.0).truncatingRemainder(dividingBy: 360.0).rounded())

        // Level-specific wind speed and QNH ranges per VARIABEL_DINAMIS_KURIKULUM_LEVEL_1_5.pdf
        let minSpeed: Double
        let maxSpeed: Double
        let minQnh: Double
        let maxQnh: Double

        switch level {
        case .level1:
            // Angin 05–12 kt (Tenang) | QNH 1008–1016 hPa
            minSpeed = 5.0; maxSpeed = 12.0
            minQnh = 1008.0; maxQnh = 1016.0
        case .level2:
            // Angin 08–15 kt (Crosswind <= 15 kt) | QNH 1006–1018 hPa
            minSpeed = 8.0; maxSpeed = 15.0
            minQnh = 1006.0; maxQnh = 1018.0
        case .level3:
            // Angin 10–20 kt (Angin aktif) | QNH 1004–1016 hPa
            minSpeed = 10.0; maxSpeed = 20.0
            minQnh = 1004.0; maxQnh = 1016.0
        case .level4:
            // Angin 15–25 kt (Crosswind basah) | QNH 1002–1014 hPa
            minSpeed = 15.0; maxSpeed = 25.0
            minQnh = 1002.0; maxQnh = 1014.0
        case .level5:
            // Angin 15–30 kt (Gusting & Microburst) | QNH 1010–1022 hPa (Elevasi tinggi)
            minSpeed = 15.0; maxSpeed = 30.0
            minQnh = 1010.0; maxQnh = 1022.0
        case .none:
            minSpeed = 7.0; maxSpeed = 18.0
            minQnh = 1008.0; maxQnh = 1016.0
        }

        let windSpeed = Int(nextRandom(min: minSpeed, max: maxSpeed).rounded())
        let qnh = Int(nextRandom(min: minQnh, max: maxQnh).rounded())

        let (hw, xw) = windComponents(
            runwayHeading: heading,
            windDirection: Double(windDir),
            windSpeed: Double(windSpeed)
        )

        return AlignedWeather(
            runway: runway,
            heading: heading,
            windDirection: windDir,
            windSpeed: windSpeed,
            headwindKnots: hw,
            crosswindKnots: xw,
            qnh: qnh
        )
    }
}
