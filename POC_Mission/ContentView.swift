import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit

public struct SystemColorCompat {
    public let color: Color
    public init(_ color: Color) { self.color = color }

    public static let systemBackground = SystemColorCompat(Color(nsColor: .windowBackgroundColor))
    public static let secondarySystemBackground = SystemColorCompat(Color(nsColor: .controlBackgroundColor))
    public static let systemGroupedBackground = SystemColorCompat(Color(nsColor: .underPageBackgroundColor))
    public static let secondarySystemGroupedBackground = SystemColorCompat(Color(nsColor: .controlBackgroundColor))
    public static let systemGray = SystemColorCompat(Color.gray)
    public static let systemGray2 = SystemColorCompat(Color.gray.opacity(0.8))
    public static let systemGray3 = SystemColorCompat(Color.gray.opacity(0.6))
    public static let systemGray4 = SystemColorCompat(Color.gray.opacity(0.35))
    public static let systemGray5 = SystemColorCompat(Color.gray.opacity(0.2))
    public static let systemGray6 = SystemColorCompat(Color.gray.opacity(0.1))
    public static let tertiarySystemBackground = SystemColorCompat(Color(nsColor: .controlBackgroundColor))
    public static let secondaryLabel = SystemColorCompat(Color(nsColor: .secondaryLabelColor))
    public static let tertiaryLabel = SystemColorCompat(Color(nsColor: .tertiaryLabelColor))
    public static let quaternaryLabel = SystemColorCompat(Color(nsColor: .quaternaryLabelColor))
    public static let label = SystemColorCompat(Color(nsColor: .labelColor))
}

extension Color {
    public init(_ compat: SystemColorCompat) {
        self = compat.color
    }
}

public enum CompatTitleDisplayMode {
    case automatic, inline, large
}

extension View {
    public func navigationBarTitleDisplayMode(_ mode: CompatTitleDisplayMode) -> some View {
        self
    }
}

extension ToolbarItemPlacement {
    public static var topBarTrailing: ToolbarItemPlacement { .automatic }
    public static var navigationBarTrailing: ToolbarItemPlacement { .automatic }
}
#endif

// MARK: - Root View: Curriculum Hub (Page Utama Pemilihan Level)
struct ContentView: View {
    var body: some View {
        NavigationStack {
            CurriculumHubView()
        }
    }
}

// MARK: - Page 1: Curriculum Hub
struct CurriculumHubView: View {
    @State private var selectedLevel: CurriculumLevel = .level1
    @State private var selectedPath: SimulationMode = .mission

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("HERMES RTF")
                        .font(.title2.weight(.bold))
                    Text("Pilih level, lalu jalankan misi latihan atau ujian level.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Interactive UI Prototype Showcase (Mid-Fi & High-Fi)
                NavigationLink(destination: PrototypeShowcaseView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "paintpalette.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("Interactive UI Prototype")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("Mid-Fi & High-Fi")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.12))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                            }
                            Text("Simulasi 3-layar wireframe & avionics cockpit dark mode (Lv 1–5).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Picker("Level", selection: $selectedLevel) {
                    ForEach(CurriculumLevel.allCases) { level in
                        Text("L\(level.rawValue)").tag(level)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedLevel.title)
                        .font(.headline)
                    Text(selectedLevel.curriculumObjective)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Picker("Jalur", selection: $selectedPath) {
                    Text("Misi").tag(SimulationMode.mission)
                    Text("Exam").tag(SimulationMode.exam)
                }
                .pickerStyle(.segmented)

                if selectedPath == .mission {
                    missionList
                } else {
                    examCard
                }
            }
            .padding()
        }
        .navigationTitle("RTF Simulator")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var missionList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Misi Level \(selectedLevel.rawValue)")
                .font(.headline)
            ForEach(CanonicalMissionRegistry.missions(for: selectedLevel)) { mission in
                NavigationLink(destination: MissionSimulatorView(canonicalMission: mission, mode: .mission)) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(mission.code).font(.caption.weight(.bold)).foregroundColor(.blue)
                            Text(mission.title).font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                        }
                        Text(mission.subtitle).font(.caption).foregroundColor(.secondary)
                        Text(mission.learningObjective).font(.caption2).foregroundColor(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var examCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Exam Level \(selectedLevel.rawValue)", systemImage: "graduationcap.fill")
                .font(.headline)
                .foregroundColor(.purple)
            Text(examRuleDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
            NavigationLink(destination: MissionSimulatorView(level: selectedLevel, mode: .exam)) {
                Label("Mulai Exam Level \(selectedLevel.rawValue)", systemImage: "play.fill")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.purple.opacity(0.08))
        .cornerRadius(12)
    }

    private var examRuleDescription: String {
        switch selectedLevel {
        case .level1: "Sirkuit VFR rutin dengan Four-Slot Card sebagai fondasi struktur transmisi."
        case .level2: "Satu anomali terkontrol; Cloze Masked untuk angka, arah, dan clearance."
        case .level3: "Dua kejadian lintas fase; teks jawaban disembunyikan dan hanya Kartu Intensi tersedia."
        case .level4: "Checkride hub bertahap; respons dari audio dan Cockpit HUD tanpa naskah jawaban."
        case .level5: "Kedaruratan non-linear; audio dan partyline, tanpa naskah jawaban pilot."
        }
    }
}

// MARK: - Page 2: Mission Simulator View (Page Selanjutnya / Pushed)
struct MissionSimulatorView: View {
    let level: CurriculumLevel
    let originICAO: String
    let destinationICAO: String?
    let role: UserRole
    let canonicalMission: CanonicalMission?

    @State private var selectedMode: SimulationMode = .mission
    @State private var selectedContingencies: Set<ContingencySelection> = []
    @State private var activeActFilter: ActFilter = .all
    @State private var missionScript: FlightMissionScript?
    @State private var errorMessage: String?
    @State private var currentSeed: Int = Int.random(in: 1000...9999)
    @State private var hasCopiedScript: Bool = false
    @State private var showCopiedToast: Bool = false
    @State private var showDiagnosticModal: Bool = false
    @State private var showBriefingSheet: Bool = false
    @State private var showContingencyDetailSheet: Bool = false
    @State private var showPlainEnglishSheet: Bool = false

    private let engine = ScriptGeneratorEngine()

    /// Primary init: from airport selection (preferred entry point)
    public init(originICAO: String, destinationICAO: String?, role: UserRole = .pilot, canonicalMission: CanonicalMission? = nil, mode: SimulationMode = .mission) {
        let effLevel = AirportCurriculumRegistry.effectiveLevel(origin: originICAO, destination: destinationICAO)
        self.level = canonicalMission?.level ?? effLevel
        self.originICAO = originICAO
        self.destinationICAO = destinationICAO
        self.role = role
        self.canonicalMission = canonicalMission
        self._selectedMode = State(initialValue: mode)
    }

    /// Canonical mission direct init
    public init(canonicalMission: CanonicalMission, role: UserRole = .pilot, mode: SimulationMode = .mission) {
        self.level = canonicalMission.level
        self.originICAO = canonicalMission.originICAO
        self.destinationICAO = canonicalMission.destinationICAO
        self.role = role
        self.canonicalMission = canonicalMission
        self._selectedMode = State(initialValue: mode)
    }

    /// Legacy init: for backward-compat unit tests only
    public init(level: CurriculumLevel, mode: SimulationMode = .mission) {
        let airports = AirportCurriculumRegistry.airports(for: level)
        let originICAO = airports.first?.icao ?? "WADY"
        self.level = level
        self.originICAO = originICAO
        self.destinationICAO = (airports.count > 1) ? airports[1].icao : originICAO
        self.role = .pilot
        self.canonicalMission = nil
        self._selectedMode = State(initialValue: mode)
    }

    enum ActFilter: String, CaseIterable, Identifiable {
        case all = "Semua (3 Babak)"
        case act1 = "Act 1: Departure"
        case act2 = "Act 2: En-Route"
        case act3 = "Act 3: Arrival"

        var id: String { rawValue }

        var act: MissionAct? {
            switch self {
            case .all: return nil
            case .act1: return .act1Departure
            case .act2: return .act2EnRoute
            case .act3: return .act3Arrival
            }
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            cockpitHudBar

            if let mission = missionScript {
                statusStripView(mission: mission)
                actCheckpointStepper
                if let act = activeActFilter.act {
                    actCheckpointDetailBanner(act: act, mission: mission)
                }
                scriptTimelineView(mission: mission)
            } else {
                emptyMissionView
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle(navigationTitleText)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarItems
        }
        .sheet(isPresented: $showBriefingSheet) {
            if let mission = missionScript {
                FlightBriefingSheet(mission: mission)
            }
        }
        .sheet(isPresented: $showContingencyDetailSheet) {
            if let mission = missionScript {
                ContingencyDetailSheet(contingencies: mission.contingencies)
            }
        }

        .sheet(isPresented: $showDiagnosticModal) {
            if let diag = missionScript?.diagnosticReport, let mission = missionScript {
                DiagnosticReportSheet(
                    report: diag,
                    mission: mission,
                    onNextLevel: nil,
                    onRegenerate: {
                        showDiagnosticModal = false
                        currentSeed = Int.random(in: 1000...9999)
                        generateMission()
                    },
                    onRetryAct: { targetAct in
                        showDiagnosticModal = false
                        activeActFilter = (targetAct == .act1Departure) ? .act1 : ((targetAct == .act2EnRoute) ? .act2 : .act3)
                        generateMission(targetAct: targetAct)
                    }
                )
            }
        }
        .sheet(isPresented: $showPlainEnglishSheet) {
            if let mission = missionScript {
                PlainEnglishExplainerSheet(
                    exchanges: mission.plainEnglishExchanges,
                    totalTurns: mission.totalExchanges
                )
            }
        }
        .onAppear {
            if selectedContingencies.isEmpty {
                selectedContingencies = Set(level.allowedScenarios)
            }
            if missionScript == nil {
                generateMission()
            }
        }
        .overlay(alignment: .top) {
            if showCopiedToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Seluruh naskah disalin ke clipboard")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 6)
            }
        }
    }

    private var navigationTitleText: String {
        if let mission = missionScript {
            let origIata = mission.originAirport.iata ?? mission.originAirport.icao
            let destIata = mission.destinationAirport.iata ?? mission.destinationAirport.icao
            if selectedMode == .exam {
                return "Exam L\(level.rawValue): \(origIata)"
            }
            return "\(origIata) → \(destIata)"
        }
        if let c = canonicalMission {
            return "\(c.code) · L\(level.rawValue)"
        }
        if selectedMode == .exam {
            return "Exam L\(level.rawValue)"
        }
        let orig = AirportCurriculumRegistry.airport(for: originICAO)?.iata ?? originICAO
        let dest = AirportCurriculumRegistry.airport(for: destinationICAO ?? originICAO)?.iata ?? destinationICAO ?? originICAO
        return "\(orig) → \(dest)"
    }

    private var missionDisplayTitle: String {
        if let c = canonicalMission {
            return "\(c.code): \(c.title)"
        }
        if selectedMode == .exam {
            if let mission = missionScript {
                let origIata = mission.originAirport.iata ?? mission.originAirport.icao
                let name = mission.originAirport.name
                return "Exam L\(level.rawValue): \(origIata) (\(name))"
            }
            return "Exam Checkride Level \(level.rawValue)"
        }
        let orig = AirportCurriculumRegistry.airport(for: originICAO)?.iata ?? originICAO
        let dest = AirportCurriculumRegistry.airport(for: destinationICAO ?? originICAO)?.iata ?? destinationICAO ?? originICAO
        return "\(orig) → \(dest)"
    }

    // MARK: - Cockpit HUD Bar
    @ViewBuilder
    private var cockpitHudBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "airplane.circle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(missionDisplayTitle)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                if let mission = missionScript {
                    Text("\(mission.missionContext.aircraftType) · \(mission.callsign) · \(mission.totalExchanges) Turns")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Level \(level.rawValue) • \(level.levelCategory)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let mission = missionScript {
                let peCount = mission.plainEnglishExchanges.count
                if peCount > 0 {
                    Button(action: { showPlainEnglishSheet = true }) {
                        HStack(spacing: 3) {
                            Image(systemName: "text.bubble.fill")
                                .font(.system(size: 10))
                            Text("Plain EN (\(peCount))")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { showBriefingSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 10))
                        Text("Briefing")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - 3-Act Checkpoint Stepper
    @ViewBuilder
    private var actCheckpointStepper: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ActFilter.allCases) { opt in
                    Button(action: {
                        activeActFilter = opt
                    }) {
                        HStack(spacing: 5) {
                            if opt.act != nil {
                                Image(systemName: "shield.checkerboard")
                                    .font(.system(size: 11))
                                    .foregroundColor(activeActFilter == opt ? .white : .blue)
                            }

                            Text(opt.rawValue)
                                .font(.system(size: 11, weight: .bold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(activeActFilter == opt ? Color.blue : Color(.secondarySystemBackground))
                        .foregroundColor(activeActFilter == opt ? .white : .primary)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(activeActFilter == opt ? Color.blue : Color.secondary.opacity(0.2), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Act Checkpoint Detail Banner
    @ViewBuilder
    private func actCheckpointDetailBanner(act: MissionAct, mission: FlightMissionScript) -> some View {
        let actPhases = act.phases
        let actExchanges = mission.phaseScripts.filter { actPhases.contains($0.phase) }.flatMap { $0.exchanges }

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(act.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.blue)

                    Text("• \(actExchanges.count) Transmisi")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Text(act.subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: {
                generateMission(targetAct: act)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10, weight: .bold))
                    Text("Ulangi Babak")
                        .font(.system(size: 10, weight: .bold))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.blue.opacity(0.12))
                .foregroundColor(.blue)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }

    // MARK: - Status Strip View
    @ViewBuilder
    private func statusStripView(mission: FlightMissionScript) -> some View {
        Button(action: {
            showContingencyDetailSheet = true
        }) {
            HStack(spacing: 10) {
                Image(systemName: mission.contingencies.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(mission.contingencies.isEmpty ? .green : .orange)
                    .font(.system(size: 15))

                VStack(alignment: .leading, spacing: 2) {
                    if mission.contingencies.isEmpty {
                        Text("Penerbangan Normal (Rutin)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.primary)
                        Text("Seluruh fase mengikuti prosedur baku ICAO Doc 9432.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    } else {
                        Text("⚠️ \(mission.contingencies.count) Kondisi Khusus Aktif")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.orange)
                        Text(mission.contingencies.map { "[\($0.severity.rawValue)] \($0.title)" }.joined(separator: " • "))
                            .font(.system(size: 10))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(mission.contingencies.isEmpty ? Color.green.opacity(0.2) : Color.orange.opacity(0.35), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // MARK: - Script Timeline View
    @ViewBuilder
    private func scriptTimelineView(mission: FlightMissionScript) -> some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                // Pre-Flight Operational Story Briefing (Before Phase 1)
                if (activeActFilter == .all || activeActFilter == .act1), let story = mission.storyBriefing {
                    preFlightStoryCard(story)
                }

                ForEach(filteredPhases(mission: mission)) { phaseScript in
                    PhaseCardView(
                        phaseScript: phaseScript,
                        userRole: role,
                        simulationMode: selectedMode,
                        phaseContingencies: mission.contingencies.filter { $0.triggerPhase == phaseScript.phase }
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Pre-Flight Story Briefing Card
    @ViewBuilder
    private func preFlightStoryCard(_ story: MissionStoryBriefing) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "book.pages.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 13))
                Text("PRE-FLIGHT STORY BRIEFING")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.blue)

                Spacer()

                Text(story.flightRule)
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(story.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                Text(story.roleContext)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            Text(story.narrativeText)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 9))
                    Text(story.passengerCount == 0 ? "Solo Cadet (No Passengers)" : "\(story.passengerCount) Passengers")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.secondary)

                Text("•")
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 9))
                    Text(story.weatherBriefingSummary)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundColor(.secondary)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Empty View
    @ViewBuilder
    private var emptyMissionView: some View {
        Spacer()
        VStack(spacing: 12) {
            Image(systemName: "airplane")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(errorMessage ?? "Tekan Generate untuk membuat simulasi.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button(action: { generateMission() }) {
                Text("Generate RTF Dialogue")
                    .bold()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        Spacer()
    }

    // MARK: - Toolbar Items (Pilot)
    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button(action: {
                copyScriptToClipboard()
            }) {
                Image(systemName: hasCopiedScript ? "checkmark" : "doc.on.doc")
                    .foregroundColor(hasCopiedScript ? .green : .accentColor)
            }
            .disabled(missionScript == nil)
            .accessibilityLabel("Salin Seluruh Naskah")

            Button(action: {
                currentSeed = Int.random(in: 1000...9999)
                generateMission()
            }) {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel("Acak Ulang Skenario")
        }
    }

    private func copyScriptToClipboard() {
        guard let script = missionScript else { return }
        let text = script.exportAsPlainText()
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif

        withAnimation(.easeInOut(duration: 0.2)) {
            hasCopiedScript = true
            showCopiedToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeInOut(duration: 0.2)) {
                hasCopiedScript = false
                showCopiedToast = false
            }
        }
    }

    private func statusStripBackground(contingencies: [InjectedContingency]) -> Color {
        if contingencies.isEmpty { return Color.secondary.opacity(0.08) }
        let hasDistress = contingencies.contains { $0.severity == .distress }
        return hasDistress ? Color.red.opacity(0.1) : Color.orange.opacity(0.1)
    }

    private func statusStripBorder(contingencies: [InjectedContingency]) -> Color {
        if contingencies.isEmpty { return Color.clear }
        let hasDistress = contingencies.contains { $0.severity == .distress }
        return hasDistress ? Color.red.opacity(0.4) : Color.orange.opacity(0.4)
    }

    private func generateMission(targetAct: MissionAct? = nil) {
        do {
            if let cMission = canonicalMission {
                missionScript = try engine.generateCanonicalMission(
                    mission: cMission,
                    role: role,
                    mode: selectedMode,
                    seed: currentSeed
                )
            } else if selectedMode == .exam {
                missionScript = try engine.generateExamMission(
                    level: level,
                    role: role,
                    seed: currentSeed
                )
            } else {
                missionScript = try engine.generateDynamicMission(
                    originICAO: originICAO,
                    destinationICAO: destinationICAO,
                    role: role,
                    mode: selectedMode,
                    seed: currentSeed,
                    selectedContingencies: selectedContingencies,
                    retryAct: targetAct
                )
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            missionScript = nil
        }
    }

    private func filteredPhases(mission: FlightMissionScript) -> [PhaseScript] {
        if let act = activeActFilter.act {
            let actPhases = Set(act.phases)
            return mission.phaseScripts.filter { actPhases.contains($0.phase) }
        }
        return mission.phaseScripts
    }
}

// MARK: - Phase Card View
struct PhaseCardView: View {
    let phaseScript: PhaseScript
    let userRole: UserRole
    let simulationMode: SimulationMode
    let phaseContingencies: [InjectedContingency]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(phaseScript.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.blue)

                Spacer()

                Text(phaseScript.phase.frequencyRole)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(5)
            }

            Text(phaseScript.educationalGoal)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !phaseContingencies.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(phaseContingencies, id: \.title) { cont in
                        HStack(spacing: 6) {
                            Image(systemName: cont.severity == .distress ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(cont.severity == .distress ? .red : .orange)
                            Text("[\(cont.severity.rawValue)] \(cont.title)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(cont.severity == .distress ? .red : .orange)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(cont.severity == .distress ? Color.red.opacity(0.1) : Color.orange.opacity(0.1))
                        .cornerRadius(5)
                    }
                }
            }

            Divider()

            ForEach(phaseScript.exchanges) { exchange in
                ExchangeRowView(
                    exchange: exchange,
                    userRole: userRole,
                    mode: simulationMode
                )

                if exchange.id != phaseScript.exchanges.last?.id {
                    Divider()
                        .opacity(0.3)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - Scenario Multi-Select Modal Sheet
struct ScenarioPickerSheet: View {
    let level: CurriculumLevel
    @Binding var selectedContingencies: Set<ContingencySelection>
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Skenario Berjenjang: Level \(level.rawValue) — \(level.levelCategory)")
                            .font(.headline)
                            .bold()
                        Text("Default semua skenario aktif. Setiap skenario yang dicentang memiliki peluang 50% untuk terjadi secara acak dalam simulasi penerbangan.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            Button(action: {
                                selectedContingencies = Set(level.allowedScenarios)
                            }) {
                                Text("Pilih Semua (\(level.allowedScenarios.count))")
                                    .font(.caption)
                                    .bold()
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundColor(.blue)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                selectedContingencies.removeAll()
                            }) {
                                Text("Kosongkan (Routine Only)")
                                    .font(.caption)
                                    .bold()
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.secondary.opacity(0.15))
                                    .foregroundColor(.primary)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }

                Section("Skenario Tersedia (\(level.allowedScenarios.count) Opsi)") {
                    ForEach(level.allowedScenarios) { cont in
                        let isSelected = selectedContingencies.contains(cont)
                        Button(action: {
                            if isSelected {
                                selectedContingencies.remove(cont)
                            } else {
                                selectedContingencies.insert(cont)
                            }
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isSelected ? .blue : .secondary)
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(cont.shortDisplayName)
                                            .font(.subheadline)
                                            .bold()
                                            .foregroundColor(.primary)

                                        Text(cont.defaultSeverity.rawValue)
                                            .font(.system(size: 8, weight: .heavy))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(severityBadgeColor(cont.defaultSeverity).opacity(0.15))
                                            .foregroundColor(severityBadgeColor(cont.defaultSeverity))
                                            .cornerRadius(3)

                                        Text("Phase \(cont.triggerPhase.rawValue)")
                                            .font(.system(size: 8, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }

                                    Text(cont.rawValue)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Pilih Skenario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terapkan & Roll") {
                        dismiss()
                        onApply()
                    }
                    .bold()
                }
            }
        }
    }

    private func severityBadgeColor(_ sev: EventSeverity) -> Color {
        switch sev {
        case .distress: .red
        case .urgency: .yellow
        case .abnormal: .orange
        case .normal: .green
        }
    }
}

// MARK: - Flight Briefing Modal Sheet (Separating Flight Plan & ATIS)
struct FlightBriefingSheet: View {
    let mission: FlightMissionScript
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header Route Summary
                    headerRouteBanner

                    // 0. Pre-Flight Story Briefing
                    if let story = mission.storyBriefing {
                        storyBriefingCard(story)
                    }

                    // 1. Operational Flight Plan (OFP) Card
                    flightPlanCard

                    // 2. Departure ATIS Card
                    departureAtisCard

                    // 3. Arrival ATIS Card
                    arrivalAtisCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Flight Briefing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Selesai") { dismiss() }
                }
            }
        }
    }

    // MARK: - Story Briefing Card
    private func storyBriefingCard(_ story: MissionStoryBriefing) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("PRE-FLIGHT STORY BRIEFING", systemImage: "book.pages.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.blue)
                Spacer()
                Text(story.flightRule)
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(story.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                Text(story.roleContext)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            Text(story.narrativeText)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 9))
                    Text(story.passengerCount == 0 ? "Solo Cadet (No Passengers)" : "\(story.passengerCount) Passengers")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.secondary)

                Text("•")
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 9))
                    Text(story.weatherBriefingSummary)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundColor(.secondary)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.3), lineWidth: 0.8))
    }

    // MARK: - Route Header Banner
    private var headerRouteBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(mission.originAirport.icao)
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundColor(.primary)
                Text(mission.originAirport.name)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(spacing: 2) {
                Image(systemName: "airplane")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.blue)
                Text(mission.level?.levelCategory ?? "IFR")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.blue)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(mission.destinationAirport.icao)
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundColor(.primary)
                Text(mission.destinationAirport.name)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4), lineWidth: 0.5))
    }

    // MARK: - 1. Operational Flight Plan (OFP) Card
    private var flightPlanCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("1. OPERATIONAL FLIGHT PLAN (OFP)", systemImage: "doc.text.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.blue)
                Spacer()
                Text("ICAO FPL")
                    .font(.system(size: 10, weight: .black))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                GridRow {
                    Text("Callsign").font(.caption).foregroundColor(.secondary)
                    Text(mission.callsign).font(.caption).bold().foregroundColor(.primary)
                    Text("Aircraft").font(.caption).foregroundColor(.secondary)
                    Text(mission.missionContext.aircraftType).font(.caption).bold().foregroundColor(.primary)
                }

                GridRow {
                    Text("Stand Asal").font(.caption).foregroundColor(.secondary)
                    Text(mission.missionContext.standOrigin).font(.caption).bold().foregroundColor(.primary)
                    Text("Stand Tujuan").font(.caption).foregroundColor(.secondary)
                    Text(mission.missionContext.standDestination).font(.caption).bold().foregroundColor(.primary)
                }

                GridRow {
                    Text("Cruising").font(.caption).foregroundColor(.secondary)
                    Text(mission.missionContext.cruisingLevel).font(.caption).bold().foregroundColor(.primary)
                    Text("Initial Climb").font(.caption).foregroundColor(.secondary)
                    Text(mission.missionContext.initialAlt).font(.caption).bold().foregroundColor(.primary)
                }

                GridRow {
                    Text("Assigned SID").font(.caption).foregroundColor(.secondary)
                    Text(mission.missionContext.sidProcedure).font(.caption).bold().foregroundColor(.blue)
                    Text("Assigned STAR").font(.caption).foregroundColor(.secondary)
                    Text(mission.missionContext.starProcedure).font(.caption).bold().foregroundColor(.blue)
                }

                GridRow {
                    Text("Squawk Code").font(.caption).foregroundColor(.secondary)
                    Text(mission.missionContext.squawkCode).font(.caption).bold().foregroundColor(.purple)
                    Text("Dep Runway").font(.caption).foregroundColor(.secondary)
                    Text("RWY \(mission.missionContext.depRunway.designator)").font(.caption).bold().foregroundColor(.primary)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("Informasi di atas memengaruhi CRAFT clearance, stand pushback, cruising level, dan taxi-in ke gate.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4), lineWidth: 0.5))
    }

    // MARK: - 2. Departure ATIS Card
    private var departureAtisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("2. DEPARTURE ATIS", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.indigo)
                Spacer()
                Text("INFO \(mission.missionContext.depAtisId)")
                    .font(.system(size: 11, weight: .black))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.indigo.opacity(0.15))
                    .foregroundColor(.indigo)
                    .cornerRadius(6)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RUNWAY AKTIF")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Text("RWY \(mission.missionContext.depRunway.designator)")
                        .font(.subheadline)
                        .bold()
                }

                Divider().frame(height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("ANGIN PERMUKAAN")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%03d", mission.missionContext.depWeather.windDirection))° / \(mission.missionContext.depWeather.windSpeed) kts")
                        .font(.subheadline)
                        .bold()
                }

                Divider().frame(height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("ALTIMETER (QNH)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Text("\(mission.missionContext.depWeather.qnh) hPa")
                        .font(.subheadline)
                        .bold()
                }

                Divider().frame(height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("VISIBILITY")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Text("CAVOK >10km")
                        .font(.subheadline)
                        .bold()
                }
            }

            // Voice ATIS Broadcast Transcript
            VStack(alignment: .leading, spacing: 4) {
                Text("TRANSKRIP SUARA VHF COMM-2 (ICAO DOC 9432 §4.4.3):")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Text("\"\(mission.missionContext.depAtisBroadcastText)\"")
                    .font(.system(size: 11, design: .serif))
                    .foregroundColor(.primary)
                    .italic()
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                Text("⚠️ Aturan Wajib: Pilot memantau ATIS secara pasif dan WAJIB menyebutkan 'Information \(mission.missionContext.depAtisId)' pada initial call ke Delivery/Ground.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Cockpit D-ATIS MCDU Display Box
            VStack(alignment: .leading, spacing: 4) {
                Text("DIGITAL D-ATIS (COCKPIT MCDU / ACARS READOUT):")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                Text(mission.missionContext.depDATISText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.3))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.07, green: 0.1, blue: 0.14))
                    .cornerRadius(8)
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4), lineWidth: 0.5))
    }

    // MARK: - 3. Arrival ATIS Card
    private var arrivalAtisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("3. ARRIVAL ATIS (DESTINATION ADVISORY)", systemImage: "airplane.arrival")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.teal)
                Spacer()
                Text("INFO \(mission.missionContext.arrAtisId)")
                    .font(.system(size: 11, weight: .black))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.teal.opacity(0.15))
                    .foregroundColor(.teal)
                    .cornerRadius(6)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("EXPECTED RUNWAY")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Text("RWY \(mission.missionContext.arrRunway.designator)")
                        .font(.subheadline)
                        .bold()
                }

                Divider().frame(height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("ANGIN TUJUAN")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%03d", mission.missionContext.arrWeather.windDirection))° / \(mission.missionContext.arrWeather.windSpeed) kts")
                        .font(.subheadline)
                        .bold()
                }

                Divider().frame(height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("QNH TUJUAN")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Text("\(mission.missionContext.arrWeather.qnh) hPa")
                        .font(.subheadline)
                        .bold()
                }

                Divider().frame(height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("APPROACH")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Text("ILS DME")
                        .font(.subheadline)
                        .bold()
                }
            }

            // Voice Arrival ATIS Transcript
            VStack(alignment: .leading, spacing: 4) {
                Text("TRANSKRIP SUARA VHF COMM-2 (ICAO DOC 9432 §4.6.2):")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Text("\"\(mission.missionContext.arrAtisBroadcastText)\"")
                    .font(.system(size: 11, design: .serif))
                    .foregroundColor(.primary)
                    .italic()
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                Text("⚠️ Aturan Wajib: Pilot menyatakan 'Information \(mission.missionContext.arrAtisId)' pada initial check-in ke Approach Control saat memasuki wilayah kedatangan.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Cockpit D-ATIS MCDU Display Box
            VStack(alignment: .leading, spacing: 4) {
                Text("DIGITAL D-ATIS (COCKPIT MCDU / ACARS READOUT):")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                Text(mission.missionContext.arrDATISText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.3))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.07, green: 0.1, blue: 0.14))
                    .cornerRadius(8)
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4), lineWidth: 0.5))
    }
}

// MARK: - Multi-Contingency Detail Modal Sheet
struct ContingencyDetailSheet: View {
    let contingencies: [InjectedContingency]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if contingencies.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.green)
                            Text("Penerbangan Normal (Rutin)")
                                .font(.headline)
                                .bold()
                            Text("Seluruh fase penerbangan ini berjalan sesuai rute dan prosedur baku ICAO Doc 9432 tanpa ada kondisi darurat atau penundaan abnormal.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(contingencies.count) Kondisi Khusus Aktif pada Sesi Ini")
                                .font(.subheadline)
                                .bold()
                            Text("Skenario berikut tersebar di berbagai babak penerbangan secara realistis dan memerlukan respon fraseologi khusus sesuai standar ICAO.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 2)

                        ForEach(contingencies, id: \.title) { cont in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: cont.severity == .distress ? "exclamationmark.octagon.fill" : (cont.severity == .urgency ? "exclamationmark.triangle.fill" : "info.circle.fill"))
                                        .foregroundColor(cont.severity == .distress ? .red : (cont.severity == .urgency ? .orange : .blue))
                                        .font(.title3)

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(cont.severity.rawValue)
                                                .font(.system(size: 8, weight: .black))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(severityColor(cont.severity).opacity(0.15))
                                                .foregroundColor(severityColor(cont.severity))
                                                .cornerRadius(4)

                                            Text("FASE: \(cont.triggerPhase.rawValue.uppercased())")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(.secondary)

                                            if cont.title.contains("Weather") || cont.title.contains("Gear") || cont.title.contains("Flap") || cont.title.contains("Medical") || cont.title.contains("EFATO") {
                                                Text("PLAIN EN")
                                                    .font(.system(size: 8, weight: .black))
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .background(Color.orange.opacity(0.15))
                                                    .foregroundColor(.orange)
                                                    .cornerRadius(3)
                                            }
                                        }

                                        Text(cont.title)
                                            .font(.headline)
                                            .bold()
                                    }
                                }

                                Divider()

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Situasi Skenario:")
                                        .font(.caption2)
                                        .bold()
                                        .foregroundColor(.primary)
                                    Text(cont.summary)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Dampak ke Alur Penerbangan (Downstream):")
                                        .font(.caption2)
                                        .bold()
                                        .foregroundColor(.primary)
                                    Text(cont.downstreamEffect)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(12)
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(severityColor(cont.severity).opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Kondisi Khusus (\(contingencies.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tutup") { dismiss() }
                }
            }
        }
    }

    private func severityColor(_ sev: EventSeverity) -> Color {
        switch sev {
        case .distress: .red
        case .urgency: .orange
        case .abnormal: .blue
        case .normal: .gray
        }
    }
}

// MARK: - Exchange Row View (Script Presentation)
struct ExchangeRowView: View {
    let exchange: FilledExchange
    let userRole: UserRole
    let mode: SimulationMode

    private var shouldHideSpeechText: Bool {
        if exchange.clozePayload != nil && !exchange.isUserTurn {
            return true
        }
        guard mode == .exam && exchange.isUserTurn else { return false }
        return exchange.scaffoldingType == .intentBadge ||
               exchange.scaffoldingType == .cockpitHUDStrip ||
               exchange.scaffoldingType == .partylineHUD
    }

    private var examAudioOnlyExplanation: String {
        switch exchange.scaffoldingType {
        case .intentBadge:
            return "Exam Mode: Teks Inggris Disembunyikan — Ucapkan dari Kartu Intensi di Atas!"
        case .cockpitHUDStrip:
            return "Exam Mode: Audio-Only — Baca Instrumen HUD dan Tanggapi ATC!"
        case .partylineHUD:
            return "Exam Mode: Audio-Only + Partyline — Waspadai Perintah Bahaya ATC!"
        default:
            return "Exam Mode: Audio-Only"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Speaker indicator column
            VStack(spacing: 3) {
                Text(exchange.speaker)
                    .font(.system(size: 10, weight: .black))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(speakerColor.opacity(0.16))
                    .foregroundColor(speakerColor)
                    .cornerRadius(5)

                Text("#\(exchange.turn)")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(width: 52)

            // Content column
            VStack(alignment: .leading, spacing: 8) {
                // Header tags row
                HStack(spacing: 6) {
                    if exchange.speaker.contains("TRAFFIC") {
                        Text("📻 TRAFIK DI FREKUENSI")
                            .font(.system(size: 9, weight: .black))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.teal.opacity(0.18))
                            .foregroundColor(.teal)
                            .cornerRadius(4)
                    } else if exchange.isUserTurn {
                        Text("▶ ANDA")
                            .font(.system(size: 9, weight: .black))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.18))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }

                    if let tag = exchange.eventTag {
                        Text(tag)
                            .font(.system(size: 9, weight: .heavy))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(tagColor(exchange.severity).opacity(0.16))
                            .foregroundColor(tagColor(exchange.severity))
                            .cornerRadius(4)
                    }

                    if exchange.languageLayer == .constrainedPlainEnglish {
                        Text("[Plain EN]")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.18))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                }

                // Objective Banner
                if let obj = exchange.objective {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "target")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(.top, 1)
                        Text("Objective: \(obj)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.blue.opacity(0.2), lineWidth: 0.5))
                }

                // Scaffolding UI Presentation (Level 1..5)
                if let type = exchange.scaffoldingType {
                    scaffoldingCardView(type: type)
                }

                // Script spoken text
                if !shouldHideSpeechText {
                    Text("\"\(exchange.text)\"")
                        .font(.system(size: 13, weight: exchange.isUserTurn ? .semibold : .regular))
                        .foregroundColor(.primary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform.circle.fill")
                            .foregroundColor(.purple)
                            .font(.system(size: 13))
                        Text(examAudioOnlyExplanation)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.purple)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.purple.opacity(0.12))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.purple.opacity(0.25), lineWidth: 0.5))
                }

                if exchange.languageLayer == .constrainedPlainEnglish, let reason = exchange.plainEnglishTrigger {
                    Text("→ \(reason)")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                        .italic()
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Readback requirements
                if mode == .mission && !exchange.criticalSlots.isEmpty && exchange.isUserTurn {
                    HStack(alignment: .top, spacing: 5) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                            .padding(.top, 1)
                        Text("Wajib readback: \(exchange.criticalSlots.map { $0.expectedValue }.joined(separator: ", "))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.green)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.green.opacity(0.25), lineWidth: 0.5))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func scaffoldingCardView(type: ScaffoldingType) -> some View {
        switch type {
        case .fourSlotCard:
            if let p = exchange.fourSlotPayload {
                FourSlotCardView(payload: p)
            }
        case .clozeMasked:
            if let p = exchange.clozePayload {
                ClozeMaskedView(payload: p, fullSpeechText: exchange.text, isExam: mode == .exam)
            }
        case .intentBadge:
            if let p = exchange.intentPayload, exchange.isUserTurn {
                IntentBadgeCardView(payload: p, isExam: mode == .exam)
            }
        case .cockpitHUDStrip:
            if let p = exchange.hudPayload {
                CockpitHUDStripView(payload: p, bait: exchange.baitPayload)
            }
        case .partylineHUD:
            if let p = exchange.hudPayload {
                PartylineHUDStripView(payload: p, partyline: exchange.partylinePayload, hazard: exchange.hazardPayload)
            }
        }
    }

    private var speakerColor: Color {
        if exchange.speaker.contains("TRAFFIC") {
            return Color.teal
        }
        return exchange.speaker == "PILOT" ? Color.blue : Color.purple
    }

    private func tagColor(_ sev: EventSeverity) -> Color {
        switch sev {
        case .distress: .red
        case .urgency: .orange
        case .abnormal: Color(red: 0.85, green: 0.5, blue: 0.1)
        case .normal: .blue
        }
    }
}

// MARK: - Scaffolding UI Subviews (MAPPING_SCAFFOLDING.pdf & LAMPIRAN)

struct SlotBadgeView: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 8, weight: .black))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(color.opacity(0.12))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(color.opacity(0.3), lineWidth: 0.5)
        )
    }
}

struct HUDMetricPill: View {
    let label: String
    let value: String

    private var displayValue: String {
        if label == "XPDR" {
            return formatXpdrCode(value)
        }
        return value
    }

    private func formatXpdrCode(_ raw: String) -> String {
        let map: [String: String] = [
            "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4",
            "five": "5", "six": "6", "seven": "7", "eight": "8", "niner": "9", "nine": "9"
        ]
        let tokens = raw.lowercased().components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        let digits = tokens.compactMap { map[$0] }
        if digits.count == 4 {
            return digits.joined()
        }
        let numericOnly = raw.filter { $0.isNumber }
        if numericOnly.count >= 4 {
            return String(numericOnly.prefix(4))
        }
        return raw
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .black))
                .foregroundColor(.secondary)
            Text(displayValue)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.15), lineWidth: 0.5))
    }
}

struct FourSlotCardView: View {
    let payload: FourSlotCardPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: "rectangle.split.2x2.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("4-SLOT DATA CARD")
                        .font(.system(size: 10, weight: .black))
                }
                .foregroundColor(.blue)

                if let guide = payload.phoneticGuide {
                    Text(guide)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top)], spacing: 6) {
                SlotBadgeView(title: "STASIUN", value: payload.station, color: .blue)
                SlotBadgeView(title: "CALLSIGN", value: payload.callsign, color: .purple)
                SlotBadgeView(title: "POSISI", value: payload.position, color: .orange)
                SlotBadgeView(title: "AKSI / PESAN", value: payload.action, color: .green)
            }
        }
        .padding(10)
        .background(Color.blue.opacity(0.06))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.25), lineWidth: 1))
    }
}

struct ClozeMaskedView: View {
    let payload: ClozeMaskedPayload
    var fullSpeechText: String? = nil
    var isExam: Bool = false
    @State private var showFullText: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("TRANSMISI ATC (TEKS RUMPANG / CLOZE)", systemImage: "character.textbox")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.orange)
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "timer")
                        .font(.system(size: 9))
                    Text("≤ \(Int(payload.timeoutSeconds))s")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(4)
            }

            Text(payload.displayTemplate)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(6)
                .fixedSize(horizontal: false, vertical: true)

            if !payload.maskedSlots.isEmpty {
                HStack(spacing: 5) {
                    Text("Slot Diuji:")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                    ForEach(payload.maskedSlots, id: \.slotId) { s in
                        Text("[\(s.type)]")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.12))
                            .cornerRadius(3)
                    }
                }
            }

            if !isExam, let full = fullSpeechText {
                Button(action: { showFullText.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: showFullText ? "eye.slash" : "eye")
                            .font(.system(size: 9))
                        Text(showFullText ? "Sembunyikan Kunci Transmisi ATC" : "Lihat Transmisi Lengkap ATC")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
                }
                .buttonStyle(.plain)

                if showFullText {
                    Text("\"\(full)\"")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(4)
                }
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.06))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.25), lineWidth: 1))
    }
}

struct IntentBadgeCardView: View {
    let payload: IntentBadgePayload
    let isExam: Bool
    @State private var showSecretAnswer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("KARTU INTENSI OPERASIONAL", systemImage: "target")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.indigo)
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "timer")
                        .font(.system(size: 9))
                    Text("≤ \(Int(payload.timeoutSeconds))s")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(.indigo)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.indigo.opacity(0.15))
                .cornerRadius(4)
            }

            Text(payload.primaryIntent)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.primary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            if let constraint = payload.criticalConstraint {
                HStack(alignment: .top, spacing: 5) {
                    Text("💡 Catatan Kritis:")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.indigo)
                    Text(constraint)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let hint = payload.hint {
                Text(hint)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !isExam {
                Button(action: { showSecretAnswer.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: showSecretAnswer ? "eye.slash" : "eye")
                        Text(showSecretAnswer ? "Sembunyikan Kunci Fraseologi" : "Lihat Kunci Fraseologi")
                    }
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.indigo)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)

                if showSecretAnswer {
                    Text("\"\(payload.expectedSpeech)\"")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.indigo)
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.indigo.opacity(0.1))
                        .cornerRadius(6)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(10)
        .background(Color.indigo.opacity(0.08))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.indigo.opacity(0.25), lineWidth: 1))
    }
}

struct CockpitHUDStripView: View {
    let payload: AvionicsHUDPayload
    let bait: SelectiveListeningBaitPayload?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("COCKPIT HUD STRIP (CURRENT CONDITION)", systemImage: "display")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.cyan)
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "timer")
                        .font(.system(size: 9))
                    Text("≤ \(Int(payload.timeoutSeconds))s")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(.cyan)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.cyan.opacity(0.15))
                .cornerRadius(4)
            }

            HStack(spacing: 6) {
                HUDMetricPill(label: "HDG", value: payload.headingDeg.map { "\($0)°" } ?? "---")
                HUDMetricPill(label: "ALT", value: payload.altitudeFt.map { "\($0) FT" } ?? "---")
                HUDMetricPill(label: "SPD", value: payload.airspeedKt.map { "\($0) KT" } ?? "---")
                HUDMetricPill(label: "XPDR", value: payload.squawkCode ?? "---")
                HUDMetricPill(label: "COM1", value: payload.comm1Freq ?? "---")
            }

            if let b = bait, b.isBaitTurn {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 11))
                    Text("UMPAN CALLSIGN MIRIP (\(b.targetCallsign)): TAHAN DIRI, JANGAN MENJAWAB!")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.12))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.red.opacity(0.3), lineWidth: 0.5))
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.35), lineWidth: 1))
    }
}

struct PartylineHUDStripView: View {
    let payload: AvionicsHUDPayload
    let partyline: PartylineChatterPayload?
    let hazard: HazardousInstructionPayload?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow
            metricsRow
            if let p = partyline {
                partylineView(p)
            }
            if let h = hazard, h.isHazardous {
                hazardView(h)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.35), lineWidth: 1))
    }

    private var headerRow: some View {
        HStack {
            Label("MEDAN EKSTREM + PARTYLINE (CURRENT CONDITION)", systemImage: "mountain.2.fill")
                .font(.system(size: 9, weight: .black))
                .foregroundColor(.orange)
            Spacer()
            HStack(spacing: 3) {
                Image(systemName: "radio")
                    .font(.system(size: 9))
                Text("VHF 25% (Duck 10%)")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(.orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.15))
            .cornerRadius(4)
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 6) {
            HUDMetricPill(label: "HDG", value: payload.headingDeg.map { "\($0)°" } ?? "---")
            HUDMetricPill(label: "ALT", value: payload.altitudeFt.map { "\($0) FT" } ?? "---")
            HUDMetricPill(label: "SPD", value: payload.airspeedKt.map { "\($0) KT" } ?? "---")
            HUDMetricPill(label: "XPDR", value: payload.squawkCode ?? "---")
            HUDMetricPill(label: "COM1", value: payload.comm1Freq ?? "---")
        }
    }

    private func partylineView(_ p: PartylineChatterPayload) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "waveform")
                    .font(.system(size: 9))
                    .foregroundColor(.teal)
                if let call = p.activeTrafficCallsign {
                    Text("📻 VHF FREKUENSI TERPAKAI: \(call) (\(p.activeTrafficAircraft ?? "Trafik"))")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.teal)
                } else {
                    Text("VHF PARTYLINE AKTIF (\(p.audioTrackName)): Volume \(Int(p.baseVolume * 100))% (Ducking \(Int(p.duckingVolume * 100))%)")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.teal)
                }
            }
            if p.frequencyStatus == "CHANNEL_OCCUPIED_MONITOR_ONLY" {
                Text("⛔ FREKUENSI SIBUK — TAHAN TRANSMISI / JANGAN TEKAN PTT!")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.orange)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.teal.opacity(0.1))
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.teal.opacity(0.25), lineWidth: 0.5))
    }

    private func hazardView(_ h: HazardousInstructionPayload) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("AUTHORITY BIAS BREAKER (DILARANG PATUH):")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.red)
            }
            Text(h.hazardDescription)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text("🎯 Objective: Tolak instruksi penurunan dan minta tanjak ke ketinggian aman!")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.12))
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.red.opacity(0.35), lineWidth: 0.5))
    }
}

// MARK: - Diagnostic Report Modal Sheet
struct DiagnosticReportSheet: View {
    let report: DiagnosticReport
    let mission: FlightMissionScript
    let onNextLevel: (() -> Void)?
    let onRegenerate: () -> Void
    var onRetryAct: ((MissionAct) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 6) {
                        Image(systemName: report.isPassed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(report.isPassed ? .green : .orange)

                        Text(report.isPassed ? "LULUS EVALUASI ICAO (≥ 80%)" : "PERLU LATIHAN ULANG (< 80%)")
                            .font(.headline)
                            .bold()
                            .foregroundColor(report.isPassed ? .green : .orange)

                        Text("Total Skor Ketertiban Radio")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("\(report.overallScore)%")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(12)

                    // MARK: - RAPOR KETERTIBAN RADIO (APP_FLOW_CIA.pdf)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "list.bullet.clipboard.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.blue)
                            Text("RAPOR KETERTIBAN RADIO (REAL-TIME METRICS)")
                                .font(.caption2)
                                .bold()
                                .foregroundColor(.primary)
                        }

                        Divider()

                        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                            GridRow {
                                Text("Kecepatan Bicara").font(.caption).foregroundColor(.secondary)
                                HStack(spacing: 4) {
                                    Text("\(report.actualWpm) WPM").font(.caption).bold()
                                    Text(report.actualWpm >= 100 && report.actualWpm <= 120 ? "[PAS]" : "[DEV]")
                                        .font(.system(size: 8, weight: .black))
                                        .foregroundColor(report.actualWpm >= 100 && report.actualWpm <= 120 ? .green : .orange)
                                }
                                Text("Refleks PTT").font(.caption).foregroundColor(.secondary)
                                HStack(spacing: 4) {
                                    Text("\(report.pttLatencyMs) ms").font(.caption).bold()
                                    Text("[RESPONSIF]")
                                        .font(.system(size: 8, weight: .black))
                                        .foregroundColor(.green)
                                }
                            }

                            GridRow {
                                Text("Suara Gumam (Uh/Um)").font(.caption).foregroundColor(.secondary)
                                HStack(spacing: 4) {
                                    Text("\(report.fillerWordsCount) kali").font(.caption).bold()
                                    Text("[BERSIH]")
                                        .font(.system(size: 8, weight: .black))
                                        .foregroundColor(.green)
                                }
                                Text("Jeda Macet Tengah").font(.caption).foregroundColor(.secondary)
                                HStack(spacing: 4) {
                                    Text("\(report.hesitationCount) kali").font(.caption).bold()
                                    Text("[LANCAR]")
                                        .font(.system(size: 8, weight: .black))
                                        .foregroundColor(.green)
                                }
                            }

                            GridRow {
                                Text("Kejelasan Angka").font(.caption).foregroundColor(.secondary)
                                HStack(spacing: 4) {
                                    Text("\(report.numbersAccuracyPercentVal)%").font(.caption).bold()
                                    Text("[TEGAS]")
                                        .font(.system(size: 8, weight: .black))
                                        .foregroundColor(.green)
                                }
                                Text("Standar WPM").font(.caption).foregroundColor(.secondary)
                                Text("100–120 WPM").font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)

                    // MARK: - HIERARKI RISIKO KESELAMATAN 4 PILAR
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PEMBOBOTAN RISIKO KESELAMATAN (40% : 25% : 20% : 15%)")
                            .font(.caption2)
                            .bold()
                            .foregroundColor(.secondary)

                        VStack(spacing: 6) {
                            rubricBar(
                                title: "1. Kejelasan & Ketepatan Angka (Doc 4444 §12.3)",
                                weight: "Bobot 40% (Risiko Fatal)",
                                score: report.numbersScore,
                                color: .red
                            )
                            rubricBar(
                                title: "2. Standar Frase Baku (Doc 4444 Ch 12)",
                                weight: "Bobot 25% (Ambiguitas)",
                                score: report.phraseologyScore,
                                color: .blue
                            )
                            rubricBar(
                                title: "3. Disiplin Refleks Tombol PTT (Annex 10 Vol. II)",
                                weight: "Bobot 20% (Integritas Radio)",
                                score: report.pttDisciplineScore,
                                color: .indigo
                            )
                            rubricBar(
                                title: "4. Kelancaran Bicara & WPM (Doc 9835)",
                                weight: "Bobot 15% (Beban Mental)",
                                score: report.fluencyScore,
                                color: .teal
                            )
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray4), lineWidth: 0.5))

                    // 3-Act Checkpoint Table
                    VStack(alignment: .leading, spacing: 8) {
                        Text("EVALUASI CHECKPOINT 3 BABAK (ICAO DOC 9432)")
                            .font(.caption2)
                            .bold()
                            .foregroundColor(.secondary)

                        ForEach(report.actEvaluations) { actEval in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(actEval.act.title)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.primary)

                                    Spacer()

                                    Text("\(actEval.score)%")
                                        .font(.system(size: 12, weight: .black))
                                        .foregroundColor(actEval.isPassed ? .green : .red)

                                    Text(actEval.isPassed ? "LULUS" : "GAGAL")
                                        .font(.system(size: 9, weight: .black))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(actEval.isPassed ? Color.green.opacity(0.18) : Color.red.opacity(0.18))
                                        .foregroundColor(actEval.isPassed ? .green : .red)
                                        .cornerRadius(4)

                                    if let retry = onRetryAct {
                                        Button(action: { retry(actEval.act) }) {
                                            Text("Ulangi")
                                                .font(.system(size: 10, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.orange.opacity(0.2))
                                                .foregroundColor(.orange)
                                                .cornerRadius(4)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                Text(actEval.feedback)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .padding(10)
                            .background(Color.secondary.opacity(0.06))
                            .cornerRadius(8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Critical Guardrails (Instant Fail)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .foregroundColor(.red)
                            Text("GUARDRAILS PELANGGARAN KRITIS (INSTANT FAIL)")
                                .font(.caption2)
                                .bold()
                                .foregroundColor(.red)
                        }

                        Text("Gagal di babak berjalan jika melakukan salah satu pelanggaran berikut:")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            criticalRuleRow("1. Salah Nomor Runway saat Readback", doc: "Doc 4444 Sec 12.2.3")
                            criticalRuleRow("2. Gagal Membacakan Instruksi Hold Short", doc: "Doc 4444 Ch 7")
                            criticalRuleRow("3. Altitude Bust (Deviasi Ketinggian/FL)", doc: "Doc 9432 Sec 4.6")
                            criticalRuleRow("4. Salah Kode Transponder Squawk", doc: "Doc 4444 Sec 12.2.3")
                        }
                        .padding(8)
                        .background(Color.red.opacity(0.06))
                        .cornerRadius(8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Non-Critical Penalties (Toleransi Poin)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("TOLERANSI NON-KRITIS (ICAO DOC 9835)")
                                .font(.caption2)
                                .bold()
                                .foregroundColor(.blue)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("• Pelafalan Fonetik Minor:")
                                    .font(.system(size: 10, weight: .medium))
                                Spacer()
                                Text("-10 Poin")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                            HStack {
                                Text("• Jeda Transmisi > 4 Detik:")
                                    .font(.system(size: 10, weight: .medium))
                                Spacer()
                                Text("-10 Poin")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                            HStack {
                                Text("• Struktur Urutan Kata Terbalik:")
                                    .font(.system(size: 10, weight: .medium))
                                Spacer()
                                Text("-5 Poin")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.06))
                        .cornerRadius(8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Area Peningkatan Feedback
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Area Peningkatan (Feedback Instruktur):")
                            .font(.caption2)
                            .bold()

                        ForEach(report.improvementAreas, id: \.self) { area in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                Text(area)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(10)

                    HStack(spacing: 12) {
                        Button(action: onRegenerate) {
                            Text("Latihan Ulang")
                                .font(.subheadline)
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.secondary.opacity(0.15))
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                        }

                        if let nextAction = onNextLevel {
                            Button(action: nextAction) {
                                Text("Lanjut Level Berikutnya")
                                    .font(.subheadline)
                                    .bold()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Diagnostik ICAO Doc 9835")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tutup") { dismiss() }
                }
            }
        }
    }

    private func criticalRuleRow(_ title: String, doc: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.primary)
            Spacer()
            Text(doc)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }

    private func rubricBar(title: String, weight: String, score: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                Text("\(score)%")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(score >= 80 ? color : .red)
            }
            HStack {
                Text(weight)
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                Spacer()
                Text(score >= 80 ? "MEMENUHI" : "DI BAWAH STANDAR")
                    .font(.system(size: 7, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(score >= 80 ? color.opacity(0.12) : Color.red.opacity(0.12))
                    .foregroundColor(score >= 80 ? color : .red)
                    .cornerRadius(3)
            }
            ProgressView(value: Double(score), total: 100.0)
                .tint(color)
                .scaleEffect(x: 1, y: 0.6, anchor: .center)
        }
        .padding(6)
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(6)
    }
}

// MARK: - ATC Session Runner View
/// ATC-specific view that replaces MissionSimulatorView for role = .atc.
/// Shows multi-traffic session grouped by 3 Acts, with plain-English badges.
struct ATCSessionRunnerView: View {
    let aerodromeICAO: String

    @State private var session: ATCSessionScript?
    @State private var errorMessage: String?
    @State private var activeActFilter: ATCActFilter = .all
    @State private var showDiagnosticSheet: Bool = false
    @State private var showScenarioPickerSheet: Bool = false
    @State private var showATCContingenciesSheet: Bool = false
    @State private var showPlainEnglishSheet: Bool = false
    @State private var selectedContingencies: Set<ContingencySelection> = []

    private let engine = ScriptGeneratorEngine()

    enum ATCActFilter: String, CaseIterable, Identifiable {
        case all = "Semua Traffic"
        case act1 = "Act 1: Departures"
        case act2 = "Act 2: Transit"
        case act3 = "Act 3: Arrivals"
        var id: String { rawValue }
        var act: MissionAct? {
            switch self {
            case .all: nil
            case .act1: .act1Departure
            case .act2: .act2EnRoute
            case .act3: .act3Arrival
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // HUD Bar
            atcHudBar

            if let session = session {
                // Act Filter
                actFilterBar

                // Traffic entries list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        let entries = filteredEntries(session: session)
                        if entries.isEmpty {
                            Text("Tidak ada traffic di babak ini.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(entries) { entry in
                                ATCTrafficCard(entry: entry)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            } else if let err = errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange).font(.largeTitle)
                    Text(err).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                }.padding()
            } else {
                ProgressView("Memuat sesi ATC...").padding()
            }
        }
        .navigationTitle(session.map { "\($0.aerodrome.iata) Tower / Ground (L\($0.level.rawValue))" } ?? "ATC Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button(action: { showScenarioPickerSheet = true }) {
                        Image(systemName: "slider.horizontal.3")
                    }
                    Button(action: { generateSession() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    Button(action: {
                        if let s = session {
                            #if canImport(UIKit)
                            UIPasteboard.general.string = s.exportAsPlainText()
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                            #elseif canImport(AppKit)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(s.exportAsPlainText(), forType: .string)
                            #endif
                        }
                    }) {
                        Image(systemName: "doc.on.doc")
                    }
                    .disabled(session == nil)
                    if session?.diagnosticReport != nil {
                        Button(action: { showDiagnosticSheet = true }) {
                            Image(systemName: "chart.bar.doc.horizontal")
                        }
                    }
                    if let s = session {
                        ShareLink(
                            item: s.exportAsPlainText(),
                            subject: Text("HERMES ATC Script: \(s.aerodrome.iata) L\(s.level.rawValue)"),
                            message: Text("Script sesi simulasi pemanduan lalu lintas ICAO Doc 4444")
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showDiagnosticSheet) {
            if let diag = session?.diagnosticReport {
                ATCDiagnosticSheet(
                    report: diag,
                    onRegenerate: { showDiagnosticSheet = false; generateSession() }
                )
            }
        }
        .sheet(isPresented: $showATCContingenciesSheet) {
            if let s = session {
                ATCContingenciesSheet(session: s)
            }
        }
        .sheet(isPresented: $showPlainEnglishSheet) {
            if let s = session {
                PlainEnglishExplainerSheet(
                    exchanges: s.plainEnglishExchanges,
                    totalTurns: s.trafficEntries.flatMap { $0.exchanges }.count
                )
            }
        }
        .onAppear {
            if session == nil {
                if selectedContingencies.isEmpty {
                    let level = AirportCurriculumRegistry.level(for: aerodromeICAO)
                    selectedContingencies = Set(level.allowedScenarios)
                }
                generateSession()
            }
        }
    }

    // MARK: - HUD Bar
    private var atcHudBar: some View {
        HStack(spacing: 8) {
            if let session = session {
                HStack(spacing: 6) {
                    Image(systemName: "headphones.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.indigo)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(session.aerodrome.name)
                            .font(.system(size: 10, weight: .bold))
                            .lineLimit(1)
                        Text("\(session.trafficEntries.count) Traffic · \(String(format: "%.0f", session.estimatedDurationMinutes)) min · L\(session.level.rawValue)")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Active Contingency Events badge in ATC
                let contTraffic = session.trafficEntries.filter { $0.hasContingency }
                if !contTraffic.isEmpty {
                    Button(action: { showATCContingenciesSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                            Text("\(contTraffic.count) Event")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.12))
                        .foregroundColor(.orange)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }

                // Plain English badge count (Clickable Explainer Sheet)
                let peCount = session.plainEnglishExchanges.count
                if peCount > 0 {
                    Button(action: { showPlainEnglishSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "text.bubble.fill")
                                .font(.system(size: 9))
                            Text("Plain English (\(peCount))")
                                .font(.system(size: 9, weight: .bold))
                            Image(systemName: "info.circle")
                                .font(.system(size: 8))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.12))
                        .foregroundColor(.orange)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.orange.opacity(0.35), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Act Filter Bar
    private var actFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ATCActFilter.allCases) { opt in
                    Button(action: { activeActFilter = opt }) {
                        Text(opt.rawValue)
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(activeActFilter == opt ? Color.indigo : Color(.secondarySystemBackground))
                            .foregroundColor(activeActFilter == opt ? .white : .primary)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(activeActFilter == opt ? Color.indigo : Color(.systemGray4), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Filtering
    private func filteredEntries(session: ATCSessionScript) -> [ATCTrafficEntry] {
        guard let act = activeActFilter.act else { return session.trafficEntries }
        return session.trafficEntries(for: act)
    }

    // MARK: - Generate
    private func generateSession() {
        do {
            session = try engine.generateATCSession(
                aerodromeICAO: aerodromeICAO,
                seed: Int.random(in: 1000...9999),
                selectedContingencies: selectedContingencies
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            session = nil
        }
    }
}

// MARK: - ATC Diagnostic Modal Sheet
struct ATCDiagnosticSheet: View {
    let report: DiagnosticReport
    let onRegenerate: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 6) {
                        Image(systemName: report.isPassed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(report.isPassed ? .green : .orange)

                        Text(report.isPassed ? "LULUS EVALUASI ICAO ATC (≥ 80%)" : "PERLU LATIHAN ULANG (< 80%)")
                            .font(.headline)
                            .bold()
                            .foregroundColor(report.isPassed ? .green : .orange)

                        Text("Skor Evaluasi ATC Multi-Traffic")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("\(report.overallScore)%")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(12)

                    // 3-Act Checkpoint Table
                    VStack(alignment: .leading, spacing: 8) {
                        Text("EVALUASI CHECKPOINT 3 BABAK ATC (ICAO DOC 4444 & 9432)")
                            .font(.caption2)
                            .bold()
                            .foregroundColor(.secondary)

                        ForEach(report.actEvaluations) { actEval in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(ATCSessionScript.atcActTitle(for: actEval.act))
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.primary)

                                    Spacer()

                                    Text("\(actEval.score)%")
                                        .font(.system(size: 12, weight: .black))
                                        .foregroundColor(actEval.isPassed ? .green : .red)

                                    Text(actEval.isPassed ? "LULUS" : "GAGAL")
                                        .font(.system(size: 9, weight: .black))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(actEval.isPassed ? Color.green.opacity(0.18) : Color.red.opacity(0.18))
                                        .foregroundColor(actEval.isPassed ? .green : .red)
                                        .cornerRadius(4)
                                }

                                Text(actEval.feedback)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .padding(10)
                            .background(Color.secondary.opacity(0.06))
                            .cornerRadius(8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Area Peningkatan Feedback
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Area Peningkatan (Feedback Instruktur ATC):")
                            .font(.caption2)
                            .bold()

                        ForEach(report.improvementAreas, id: \.self) { area in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                Text(area)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(10)

                    Button(action: onRegenerate) {
                        Text("Latihan Ulang Sesi ATC")
                            .font(.subheadline)
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.indigo)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("Diagnostik ATC (ICAO Doc 4444)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tutup") { dismiss() }
                }
            }
        }
    }
}

// MARK: - ATC Traffic Card
struct ATCTrafficCard: View {
    let entry: ATCTrafficEntry

    @State private var isExpanded: Bool = true

    var trafficColor: Color {
        switch entry.trafficType {
        case .fullDeparture: .blue
        case .touchAndGo: .teal
        case .enRouteTransit: .gray
        case .fullArrival: .green
        case .emergencyInbound: .red
        case .diversionArrival: .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: 8) {
                    // Traffic type icon
                    Image(systemName: entry.trafficType.icon)
                        .font(.system(size: 13))
                        .foregroundColor(trafficColor)

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(entry.callsign)
                                .font(.system(size: 12, weight: .bold))
                            Text("(\(entry.aircraftType))")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(entry.trafficType.rawValue)
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(trafficColor.opacity(0.12))
                                .foregroundColor(trafficColor)
                                .cornerRadius(4)
                        }
                        HStack(spacing: 6) {
                            Text("\(entry.exchanges.count) turns")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            if entry.hasContingency {
                                Text("⚡ \(entry.contingencySummary ?? "Event")")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                            let peCount = entry.plainEnglishExchanges.count
                            if peCount > 0 {
                                Text("[Plain EN: \(peCount)]")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(trafficColor.opacity(0.06))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)

            // Exchanges (collapsed by default for compact view)
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(entry.exchanges) { ex in
                        ATCExchangeRow(exchange: ex)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
    }
}

// MARK: - ATC Exchange Row
struct ATCExchangeRow: View {
    let exchange: FilledExchange

    var isPlainEnglish: Bool { exchange.languageLayer == .constrainedPlainEnglish }

    var severityColor: Color {
        switch exchange.severity {
        case .distress: .red
        case .urgency: .orange
        default: isPlainEnglish ? Color(red: 0.85, green: 0.5, blue: 0.1) : Color(red: 0.12, green: 0.12, blue: 0.14)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 6) {
                // Speaker indicator
                Text("T\(exchange.turn)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 22, alignment: .trailing)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(exchange.speaker)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(exchange.isUserTurn ? Color(red: 0.35, green: 0.3, blue: 0.7) : .secondary)

                        if exchange.isUserTurn {
                            Text("▶ ANDA")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(Color(red: 0.35, green: 0.3, blue: 0.7))
                        }

                        if isPlainEnglish {
                            Text("[Plain EN]")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.12))
                                .foregroundColor(.orange)
                                .cornerRadius(3)
                        }

                        if let tag = exchange.eventTag {
                            Text("[\(tag)]")
                                .font(.system(size: 8))
                                .foregroundColor(severityColor)
                        }
                    }

                    Text("\"\(exchange.text)\"")
                        .font(.system(size: 11, weight: exchange.isUserTurn ? .medium : .regular))
                        .foregroundColor(severityColor)
                        .fixedSize(horizontal: false, vertical: true)

                    if let obj = exchange.objective {
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .font(.system(size: 8))
                                .foregroundColor(Color(red: 0.35, green: 0.3, blue: 0.7))
                            Text("Objective: \(obj)")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(Color(red: 0.35, green: 0.3, blue: 0.7))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.indigo.opacity(0.08))
                        .cornerRadius(4)
                    }

                    if isPlainEnglish, let reason = exchange.plainEnglishTrigger {
                        Text("→ \(reason)")
                            .font(.system(size: 9))
                            .foregroundColor(.orange.opacity(0.75))
                            .italic()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Information Sheets for Home Hub

// 1. Airports Catalog Sheet (7 Airports)
struct AirportsInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Kurikulum RTF berjenjang memetakan 23 bandara ke dalam 5 tingkatan kompleksitas ruang udara sesuai ICAO Doc 4444 dan KONSEP MAPPING CIA.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                ForEach(CurriculumLevel.allCases) { lvl in
                    let list = AirportCurriculumRegistry.airports(for: lvl)
                    Section(header: Text("Level \(lvl.rawValue): \(lvl.levelCategory)").bold()) {
                        ForEach(list) { ap in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("\(ap.iata) / \(ap.icao)")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.primary)

                                    Spacer()

                                    Text(ap.primaryFreq)
                                        .font(.system(size: 10, weight: .semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                }

                                Text(ap.name)
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary)

                                HStack(spacing: 6) {
                                    Text(ap.city)
                                    Text("•")
                                    Text(ap.runwaySummary)
                                }
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Katalog 23 Bandara")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tutup") { dismiss() }
                }
            }
        }
    }
}

// 2. 3-Act Engine Architecture Sheet
struct ThreeActEngineInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Perjalanan Penerbangan Pilot (Flight Journey)")
                            .font(.headline)
                            .bold()
                        Text("Dalam simulator ini, 6 fase penerbangan resmi ICAO (Pre-Dep, Dep, En-Route, Arr, App, Landing) dikonsolidasikan ke dalam 3 Babak Pedagogis berprinsip Deliberate Practice. Siswa memiliki target evaluasi per babak (checkpoint) yang mandiri.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                    actExplainerCard(
                        actNumber: "Act 1",
                        title: "Departure / Keberangkatan",
                        icon: "airplane.departure",
                        color: .blue,
                        phases: "Fase 1 (Pre-Departure) + Fase 2 (Departure)",
                        focus: "Penerimaan paket ATIS, CRAFT route clearance, koordinasi start-up & pushback, taxi dengan kepatuhan wajib hold short landasan aktif, instruksi line up and wait, hingga izin take-off clearance dan airborne handoff."
                    )

                    actExplainerCard(
                        actNumber: "Act 2",
                        title: "En-Route & Circuit / Jelajah",
                        icon: "arrow.right.circle",
                        color: .teal,
                        phases: "Fase 3 (En-Route / Sirkuit Latih Visual)",
                        focus: "Climb ke cruising level, laporan posisi di fix/waypoint, separasi radar en-route, restriksi kecepatan, dan penanganan deviasi cuaca awan CB atau sirkuit visual latih (downwind/base leg)."
                    )

                    actExplainerCard(
                        actNumber: "Act 3",
                        title: "Arrival & Landing / Kedatangan",
                        icon: "airplane.arrival",
                        color: .green,
                        phases: "Fase 4 (Arrival) + Fase 5 (Approach) + Fase 6 (Landing)",
                        focus: "Penurunan rute STAR, transition altitude/QNH, vektor radar intersep ILS localizer, laporan established, izin mendarat (landing clearance), keluar landasan via taxiway (vacating), taxi in ke gate, hingga penutupan flight plan."
                    )

                    // Checkpoint Evaluation Rule Card
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .foregroundColor(.indigo)
                            Text("Aturan Checkpoint & Pengulangan Babak")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.primary)
                        }

                        Text("Jika taruna melakukan kesalahan kritis (salah nomor runway, gagal baca hold short, altitude bust) atau skor akurasi < 80% pada salah satu babak, simulasi dapat diulang khusus pada babak tersebut tanpa harus mengulang dari awal.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color.indigo.opacity(0.08))
                    .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("Struktur 3 Babak Pilot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tutup") { dismiss() }
                }
            }
        }
    }

    private func actExplainerCard(actNumber: String, title: String, icon: String, color: Color, phases: String, focus: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(color)
                    Text("\(actNumber): \(title)")
                        .font(.system(size: 13, weight: .bold))
                }

                Spacer()

                Text(phases)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Text(focus)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray4), lineWidth: 0.5))
    }
}

// 3. Scenarios Catalog Sheet (30 Scenarios)
struct ScenariosInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Katalog \(CurriculumLevel.allCases.flatMap { $0.allowedScenarios }.count) skenario abnormal dan darurat yang menguji ketepatan respon fraseologi baku dan penggunaan Plain English sesuai ICAO Doc 4444 Bab 15 dan Doc 9835.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Tingkat Keparahan ICAO").bold()) {
                    HStack(spacing: 12) {
                        severityPill(title: "Distress (MAYDAY)", color: .red)
                        severityPill(title: "Urgency (PAN PAN)", color: .orange)
                        severityPill(title: "Abnormal", color: .blue)
                    }
                    .padding(.vertical, 2)
                }

                ForEach(CurriculumLevel.allCases) { lvl in
                    Section(header: Text("Level \(lvl.rawValue): \(lvl.levelCategory)").bold()) {
                        ForEach(lvl.allowedScenarios) { scn in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(scn.shortDisplayName)
                                        .font(.system(size: 12, weight: .bold))

                                    Spacer()

                                    Text(scn.defaultSeverity.rawValue)
                                        .font(.system(size: 8, weight: .black))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(severityColor(scn.defaultSeverity).opacity(0.15))
                                        .foregroundColor(severityColor(scn.defaultSeverity))
                                        .cornerRadius(4)

                                    if scn.requiresPlainEnglish {
                                        Text("Plain EN")
                                            .font(.system(size: 8, weight: .bold))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.12))
                                            .foregroundColor(.orange)
                                            .cornerRadius(4)
                                    }
                                }

                                Text(scn.rawValue)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Katalog \(CurriculumLevel.allCases.flatMap { $0.allowedScenarios }.count) Skenario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tutup") { dismiss() }
                }
            }
        }
    }

    private func severityPill(title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title).font(.system(size: 9, weight: .semibold)).foregroundColor(.primary)
        }
    }

    private func severityColor(_ sev: EventSeverity) -> Color {
        switch sev {
        case .distress: .red
        case .urgency: .orange
        case .abnormal: .blue
        case .normal: .gray
        }
    }
}

// 4. ATC Contingencies Detail Sheet
struct ATCContingenciesSheet: View {
    let session: ATCSessionScript
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    let contTraffic = session.trafficEntries.filter { $0.hasContingency }
                    if contTraffic.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.green)
                            Text("Lalu Lintas Normal")
                                .font(.headline)
                                .bold()
                            Text("Seluruh pergerakan pesawat di stasiun ini berjalan lancar tanpa ada situasi darurat atau prioritas pendaratan mendesak.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(contTraffic.count) Pesawat Memerlukan Penanganan Khusus")
                                .font(.subheadline)
                                .bold()
                            Text("Sebagai controller, Anda wajib memberikan prioritas separasi, memandu rute darurat, atau menyiagakan armada darat PKP-PK.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 2)

                        ForEach(contTraffic) { t in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(t.trafficType.rawValue.uppercased())
                                                .font(.system(size: 8, weight: .black))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(Color.red.opacity(0.15))
                                                .foregroundColor(.red)
                                                .cornerRadius(4)

                                            Text("BABAK: \(t.act.title.uppercased())")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(.secondary)
                                        }

                                        Text("\(t.callsign) (\(t.aircraftType))")
                                            .font(.headline)
                                            .bold()
                                    }

                                    Spacer()
                                }

                                Divider()

                                if let sum = t.contingencySummary {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Situasi Skenario:")
                                            .font(.caption2)
                                            .bold()
                                            .foregroundColor(.primary)
                                        Text(sum)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Tindakan Controller ATC:")
                                        .font(.caption2)
                                        .bold()
                                        .foregroundColor(.primary)
                                    Text("Berikan izin pendaratan prioritas langsung, instruksikan pengosongan landasan terhadap pesawat lain, dan siagakan kendaraan darurat di taxiway Alpha.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(12)
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.3), lineWidth: 1))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Event Sesi ATC")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tutup") { dismiss() }
                }
            }
        }
    }
}

// 5. Plain English Explainer Sheet (ICAO Doc 9835 §4.3.1 Layer 2)
struct PlainEnglishExplainerSheet: View {
    let exchanges: [FilledExchange]
    let totalTurns: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // ICAO Doc 9835 Concept Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "character.book.closed.fill")
                                .font(.title2)
                                .foregroundColor(.orange)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Hirarki Bahasa ICAO Doc 9835")
                                    .font(.headline)
                                    .bold()
                                Text("Panduan Penggunaan Bahasa Inggris Baku & Terbatas (§4.3.1)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Kapan Plain English Digunakan?")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.primary)

                            Text("Berdasarkan standar ICAO Doc 9835, seluruh komunikasi rutin wajib menggunakan fraseologi baku (Layer 1 - Doc 9432). Namun, jika terjadi situasi abnormal, non-rutin, atau darurat yang tidak memiliki padanan frase baku (misal: menjelaskan gejala medis penumpang, kerusakan mesin spesifik, atau koordinasi cuaca ekstrem), pilot dan ATC diwajibkan beralih ke Constrained Plain English (Layer 2).")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("Aturan Kata Jangkar (Anchor Words):")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.primary)
                                .padding(.top, 2)

                            Text("Meskipun menggunakan Plain English, transmisi harus tetap diawali atau diakhiri dengan kata jangkar resmi (ROGER, WILCO, AFFIRM, NEGATIVE, MAYDAY, PAN PAN) untuk menjaga kepastian pemahaman.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                    // Session Summary Card
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Frekuensi pada Sesi Ini")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(exchanges.count) dari \(totalTurns) Transmisi (\(Int(Double(exchanges.count) / Double(max(totalTurns, 1)) * 100))%)")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.orange)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(10)

                    // Breakdown List
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Daftar Transmisi Plain English:")
                            .font(.subheadline)
                            .bold()

                        if exchanges.isEmpty {
                            Text("Tidak ada penggunaan Plain English pada sesi ini. Seluruh percakapan menggunakan fraseologi standar ICAO Doc 9432.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(exchanges, id: \.exchangeID) { ex in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Turn \(ex.turn) • \(ex.speaker)")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.primary)

                                        Spacer()

                                        if let tag = ex.eventTag {
                                            Text(tag)
                                                .font(.system(size: 8, weight: .black))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(Color.orange.opacity(0.15))
                                                .foregroundColor(.orange)
                                                .cornerRadius(4)
                                        }
                                    }

                                    Text("\"\(ex.text)\"")
                                        .font(.system(size: 12, weight: .medium, design: .serif))
                                        .foregroundColor(.primary)
                                        .padding(8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.systemBackground))
                                        .cornerRadius(6)

                                    if let trigger = ex.plainEnglishTrigger {
                                        HStack(alignment: .top, spacing: 4) {
                                            Image(systemName: "link")
                                                .font(.system(size: 9))
                                                .foregroundColor(.blue)
                                            Text("Rujukan ICAO: \(trigger)")
                                                .font(.system(size: 10))
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(10)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Penjelasan Plain English")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tutup") { dismiss() }
                }
            }
        }
    }
}
