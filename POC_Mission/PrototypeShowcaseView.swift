import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Prototype Mode (Mid-Fi Wireframe vs High-Fi Avionics Dark)
public enum PrototypeThemeMode: String, CaseIterable, Identifiable {
    case midFidelity = "Mid-Fi Wireframe"
    case highFidelity = "High-Fi Avionics"

    public var id: String { rawValue }
}

public enum PrototypeScreenStep: Int, CaseIterable, Identifiable {
    case prepContext = 1
    case simulation = 2
    case summary = 3

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .prepContext: return "1. Prep Context"
        case .simulation: return "2. Simulation"
        case .summary: return "3. Summary"
        }
    }
}

// MARK: - Main Prototype Showcase View
public struct PrototypeShowcaseView: View {
    @State private var themeMode: PrototypeThemeMode = .midFidelity
    @State private var activeStep: PrototypeScreenStep = .prepContext

    // Simulation Interactive State
    @State private var selectedLevel: Int = 1
    @State private var activeFreq: String = "RX 121.90"
    @State private var activeStation: String = "(TOWER)"
    @State private var stbyFreq: String = "118.70"
    @State private var stbyStation: String = "(GROUND)"
    @State private var isPttPressed: Bool = false
    @State private var showTranscript: Bool = false
    @State private var showCitationSheet: Bool = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            topControlBar

            ScrollView {
                VStack(spacing: 16) {
                    switch activeStep {
                    case .prepContext:
                        screen1PreparationContext
                    case .simulation:
                        screen2SimulationView
                    case .summary:
                        screen3SummaryView
                    }
                }
                .padding()
            }
        }
        .background(themeBgColor.ignoresSafeArea())
        .navigationTitle(navigationTitleText)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCitationSheet) {
            icaoCitationSheet
        }
    }

    private var navigationTitleText: String {
        switch activeStep {
        case .prepContext: return "Preparation Context"
        case .simulation: return "View Lv. \(selectedLevel) (Simulation)"
        case .summary: return "Overall Summary"
        }
    }

    // MARK: - Top Control Bar (Theme & Step Switcher)
    private var topControlBar: some View {
        VStack(spacing: 8) {
            HStack {
                Picker("Theme", selection: $themeMode) {
                    ForEach(PrototypeThemeMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Picker("Step", selection: $activeStep) {
                ForEach(PrototypeScreenStep.allCases) { step in
                    Text(step.title).tag(step)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(themeCardBg)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(themeBorderColor),
            alignment: .bottom
        )
    }

    // MARK: - Screen 1: Preparation Context
    private var screen1PreparationContext: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Info
            HStack {
                Label("MISSION BRIEFING", systemImage: "doc.text.magnifyingglass")
                    .font(.caption.weight(.black))
                    .foregroundColor(themeAccent)
                Spacer()
                Text("M-201 · WAHI ➔ WADL")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
            }

            // Card 0: Pre-Flight Operational Story Briefing
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "book.pages.fill")
                        Text("PRE-FLIGHT STORY BRIEFING")
                    }
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(themeAccent)

                    Spacer()

                    Text("IFR Commercial")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(themeSubtleBg)
                        .cornerRadius(4)
                        .foregroundColor(themeAccent)
                }

                Divider().background(themeBorderColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Scheduled Inter-City Regional Turboprop Commercial Flight")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(themeTextMain)
                    Text("Junior First Officer — Supergreen Air (ATR 72-600)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }

                Text("You are serving as First Officer in the cockpit of the ATR 72-600 turboprop under flight number Supergreen 426. Today you are operating a scheduled passenger flight connecting Yogyakarta International (WAHI) to Lombok Zainuddin Abdul Madjid (WADL). The aircraft is carrying 68 passengers and 4 flight crew members. The aviation weather briefing indicates calm en-route conditions with moderate surface winds and visibility exceeding 10 km. Having finalized fuel calculations and your IFR flight plan, you are now preparing to request IFR clearance, manage departure taxi, and climb to cruising flight level FL150.")
                    .font(.system(size: 11))
                    .foregroundColor(themeTextMain)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Label("68 Passengers", systemImage: "person.2.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("•").foregroundColor(.secondary)
                    Label("CAVOK (> 10 km)", systemImage: "sun.max.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(14)
            .background(themeCardBg)
            .cornerRadius(cardRadius)
            .overlay(cardBorder)

            // Card 1: Operational Flight Plan (OFP)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("OPERATIONAL FLIGHT PLAN (OFP)")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(themeTextMain)
                    Spacer()
                    Text("ICAO FPL")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(themeSubtleBg)
                        .cornerRadius(4)
                }
                Divider().background(themeBorderColor)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ofpItem(label: "Callsign", value: "WGN 502")
                    ofpItem(label: "Aircraft", value: "B737-800")
                    ofpItem(label: "Departure", value: "WAHI (YIA)")
                    ofpItem(label: "Parking Stand", value: "STAND GA-4")
                    ofpItem(label: "Destination", value: "WADL (LOP)")
                    ofpItem(label: "Assigned Squawk", value: "SSR 4287")
                    ofpItem(label: "Planned Cruising", value: "FL250")
                    ofpItem(label: "Initial Altitude", value: "4,000 FT")
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("ASSIGNED ROUTING")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("SID JOG 1C | STAR RWY 13")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(themeAccent)
                }
            }
            .padding(14)
            .background(themeCardBg)
            .cornerRadius(cardRadius)
            .overlay(cardBorder)

            // Card 2: Departure ATIS
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("DEPARTURE ATIS (VHF COMM-2)")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(themeTextMain)
                    Spacer()
                    Text("Info November")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
                Divider().background(themeBorderColor)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ofpItem(label: "Station", value: "WAHI / YIA")
                    ofpItem(label: "Runway in Use", value: "RWY 11")
                    ofpItem(label: "Surface Wind", value: "086° / 12 KT")
                    ofpItem(label: "Visibility", value: "CAVOK (>10KM)")
                    ofpItem(label: "Altimeter (QNH)", value: "1011 hPa")
                    ofpItem(label: "Air Temp", value: "30°C / 25°C")
                }
            }
            .padding(14)
            .background(themeCardBg)
            .cornerRadius(cardRadius)
            .overlay(cardBorder)

            // Card 3: Injected Contingency
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("INJECTED CONTINGENCY: PUSHBACK DELAY")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.orange)
                }
                Text("Lalu lintas melintas di belakang stand parkir. Pilot wajib menahan pushback dengan instruksi: 'Hold position, expect three minutes delay'.")
                    .font(.caption)
                    .foregroundColor(themeTextMain)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(cardRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cardRadius)
                    .stroke(Color.orange.opacity(0.4), lineWidth: 1)
            )

            // Goals Note
            HStack(spacing: 8) {
                Image(systemName: "scope")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Goals: to give information before starting the mission.")
                    .font(.caption.italic())
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)

            // Start CTA Button
            Button(action: {
                withAnimation { activeStep = .simulation }
            }) {
                HStack {
                    Text("START MISSION")
                        .font(.subheadline.weight(.bold))
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(themeButtonBg)
                .foregroundColor(themeButtonFg)
                .cornerRadius(cardRadius)
            }
        }
    }

    // MARK: - Screen 2: Interactive Simulation View
    private var screen2SimulationView: some View {
        VStack(spacing: 14) {
            // Level Selector Bar
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { lvl in
                    Button(action: {
                        selectedLevel = lvl
                        showTranscript = false
                    }) {
                        Text("Lv. \(lvl)")
                            .font(.system(size: 11, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(selectedLevel == lvl ? themeAccent : themeSubtleBg)
                            .foregroundColor(selectedLevel == lvl ? Color.black : themeTextMain)
                            .cornerRadius(6)
                    }
                }
            }
            .padding(3)
            .background(themeSubtleBg)
            .cornerRadius(8)

            // Radio Comm Avionics Box
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ACTIVE comm 1")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.green)
                    Text(activeFreq)
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundColor(themeMode == .highFidelity ? Color(red: 0.0, green: 1.0, blue: 0.5) : themeTextMain)
                    Text(activeStation)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    swapFrequencies()
                }) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 38, height: 38)
                        .background(themeSubtleBg)
                        .foregroundColor(themeAccent)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(themeBorderColor, lineWidth: 1.5))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("[STBY] comm 2")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(stbyFreq)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text(stbyStation)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(themeCardBg)
            .cornerRadius(cardRadius)
            .overlay(cardBorder)

            // Dynamic Workspace Content per Level
            VStack(alignment: .leading, spacing: 10) {
                switch selectedLevel {
                case 1:
                    level1Content
                case 2:
                    level2Content
                case 3:
                    level3Content
                case 4:
                    level4Content
                default:
                    level5Content
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(themeCardBg)
            .cornerRadius(cardRadius)
            .overlay(cardBorder)

            // Speech-To-Text Box
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("SPEECH-TO-TEXT TRANSCRIPTION")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    if isPttPressed {
                        HStack(spacing: 3) {
                            Circle().fill(Color.red).frame(width: 6, height: 6)
                            Text("LISTENING")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(.red)
                        }
                    }
                }

                if isPttPressed {
                    HStack(spacing: 4) {
                        ForEach(0..<6) { _ in
                            Capsule()
                                .fill(themeAccent)
                                .frame(width: 4, height: CGFloat.random(in: 10...26))
                                .animation(.easeInOut(duration: 0.2).repeatForever(), value: isPttPressed)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 32)
                } else if showTranscript {
                    Text(sampleTranscript(for: selectedLevel))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(themeMode == .highFidelity ? Color.green : themeTextMain)
                } else {
                    Text("Your Answer will be Showed here...")
                        .font(.system(size: 12).italic())
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(themeSubtleBg)
            .cornerRadius(cardRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cardRadius)
                    .stroke(themeBorderColor, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            )

            // Push To Talk Button
            VStack(spacing: 6) {
                Button(action: {
                    togglePttSimulation()
                }) {
                    ZStack {
                        Circle()
                            .fill(isPttPressed ? themeAccent : themeCardBg)
                            .frame(width: 76, height: 76)
                            .shadow(color: themeMode == .highFidelity ? themeAccent.opacity(0.4) : Color.black.opacity(0.15), radius: isPttPressed ? 12 : 4)

                        Circle()
                            .stroke(isPttPressed ? Color.white : themeBorderColor, lineWidth: 3)
                            .frame(width: 76, height: 76)

                        VStack(spacing: 2) {
                            Image(systemName: isPttPressed ? "waveform.badge.mic" : "mic.fill")
                                .font(.system(size: 22))
                                .foregroundColor(isPttPressed ? Color.black : themeTextMain)
                            Text("PUSH TO TALK")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(isPttPressed ? Color.black : themeTextMain)
                        }
                    }
                }
                .buttonStyle(.plain)

                Text(isPttPressed ? "Lepas untuk selesai bicara" : "Tekan untuk simulasi berbicara")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)

            // Finish CTA Button
            Button(action: {
                withAnimation { activeStep = .summary }
            }) {
                HStack {
                    Text("EVALUATE & SUMMARY")
                        .font(.subheadline.weight(.bold))
                    Image(systemName: "chart.bar.xaxis")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(themeButtonBg)
                .foregroundColor(themeButtonFg)
                .cornerRadius(cardRadius)
            }
        }
    }

    // Level 1: Full Scaffolding
    private var level1Content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("COCKPIT CONTEXT: WGN 502 | QNH 1011 | HDG 180")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("🎯 OBJECTIVE OPERASIONAL:")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.blue)
                Text("Minta izin taksi ke holding point Runway 18.")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(themeTextMain)
            }
            .padding(8)
            .background(Color.blue.opacity(0.08))
            .cornerRadius(6)

            VStack(alignment: .leading, spacing: 3) {
                Text("ATC TRANSMISSION:")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(themeAccent)
                Text("\"WGN 502, TAXI TO RUNWAY 18 VIA ALPHA\"")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(themeTextMain)
            }
            .padding(8)
            .background(themeSubtleBg)
            .cornerRadius(6)

            HStack(spacing: 6) {
                slotBadge(title: "1. Station", value: "Tower", color: .blue)
                slotBadge(title: "2. Callsign", value: "WGN 502", color: .purple)
                slotBadge(title: "3. Position", value: "Holding A", color: .orange)
                slotBadge(title: "4. Action", value: "Taxi RWY 18", color: .green)
            }
        }
    }

    // Level 2: Cloze Text
    private var level2Content: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("🎯 OBJECTIVE OPERASIONAL:")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.orange)
                Text("Dengarkan instruksi radar ATC dan lengkapi angka heading dan flight level yang hilang.")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(themeTextMain)
            }
            .padding(8)
            .background(Color.orange.opacity(0.08))
            .cornerRadius(6)

            Text("PROMPT TEKS RUMPANG (CLOZE TEST):")
                .font(.system(size: 9, weight: .black))
                .foregroundColor(themeAccent)

            Text("Turn left heading [ ___ ], Maintain FL [ ___ ], QNH [ ___ ], Supergreen 426")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(themeSubtleBg)
                .cornerRadius(6)

            Text("⏱️ PTT Timer: ≤ 8 detik (Melatih working memory)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // Level 3: Intention Card
    private var level3Content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.orange)
                Text("OBJECTIVE OPERASIONAL (INTENSI BHSA INDONESIA):")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.orange)
            }

            Text("\"Lakukan readback instruksi backtrack 180° di Runway 13 dan masuk posisi menahan (Line Up and Wait).\"")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(themeTextMain)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(themeSubtleBg)
                .cornerRadius(6)

            Text("💡 Dikasih Objectivenya aja (No English Script cheat) | PTT ≤ 5s")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // Level 4: Cockpit Scratchpad
    private var level4Content: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("🎯 OBJECTIVE OPERASIONAL:")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(themeAccent)
                Text("Dengarkan radio ATC, sesuaikan kecepatan dan intercept localizer ILS RWY 10.")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(themeTextMain)
            }
            .padding(8)
            .background(themeAccent.opacity(0.08))
            .cornerRadius(6)

            HStack {
                Text("COCKPIT SCRATCHPAD (AUDIO-ONLY HUD)")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(themeAccent)
                Spacer()
                Text("DENGAR RADIO")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.red)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                scratchpadItem(label: "HDG", value: "280° >")
                scratchpadItem(label: "ALT", value: "6000 ft >")
                scratchpadItem(label: "SPD", value: "250 kt >")
                scratchpadItem(label: "LOC", value: "15 NM SUB >")
                scratchpadItem(label: "NAV", value: "SLOP 1R >")
                scratchpadItem(label: "ILS", value: "RWY 10 >")
            }
        }
    }

    // Level 5: Extreme Mountain HUD + GPWS + Partyline Interruption
    private var level5Content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.octagon.fill")
                    .foregroundColor(.red)
                Text("⚠️ GPWS TERRAIN ALERT AHEAD")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.red)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Vektor ATC 250° membahayakan pesawat menabrak tebing.")
                    .font(.caption)
                    .foregroundColor(themeTextMain)

                VStack(alignment: .leading, spacing: 2) {
                    Text("🎯 OBJECTIVE OPERASIONAL:")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.red)
                    Text("Tolak instruksi penurunan ATC karena ada tebing (Authority Breaker), dan minta izin tanjak ke ketinggian aman.")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(themeTextMain)
                }
                .padding(8)
                .background(Color.black.opacity(0.2))
                .cornerRadius(6)
            }
            .padding(10)
            .background(Color.red.opacity(0.12))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.red.opacity(0.4), lineWidth: 1))

            // LIVE VHF PARTYLINE TRAFFIC INTERCEPT
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "radio")
                            .font(.system(size: 9))
                        Text("VHF 122.200 MHz — TRAFIK LAIN DI FREKUENSI")
                            .font(.system(size: 9, weight: .black))
                    }
                    .foregroundColor(themeAccent)

                    Spacer()

                    Text("⛔ FREKUENSI TERPAKAI")
                        .font(.system(size: 8, weight: .heavy))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(4)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("TRAFFIC [Smart 102]: \"Wamena Tower, Smart 102, passing Baliem Gap, descending 9000 ft.\"")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(themeAccent)
                    Text("ATC: \"Smart 102, Wamena Tower, roger, report right base runway 15.\"")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.purple)
                    Text("TRAFFIC [Smart 102]: \"Right base runway 15, Smart 102.\"")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(themeAccent)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.25))
                .cornerRadius(6)

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 10))
                    Text("Frekuensi kini telah bersih (Silence observed). Giliran Anda On-Mic.")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green)
                }
            }
            .padding(8)
            .background(themeAccent.opacity(0.06))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(themeAccent.opacity(0.25), lineWidth: 1))
        }
    }

    // MARK: - Screen 3: Overall Summary & Diagnostic
    private var screen3SummaryView: some View {
        VStack(spacing: 16) {
            // Circular Score Gauge
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(themeBorderColor, lineWidth: 8)
                        .frame(width: 100, height: 100)

                    Circle()
                        .trim(from: 0.0, to: 0.98)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))

                    Text("98%")
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(themeTextMain)
                }

                Text("Great Job!")
                    .font(.headline.weight(.bold))
                    .foregroundColor(themeTextMain)

                Text("A little bit more improvement and you are ready to go.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            // KPI Summary Table
            VStack(spacing: 10) {
                kpiRow(label: "Filler word", value: "0 times", tag: "Lancar", tagColor: .green)
                kpiRow(label: "Clearability phraseology", value: "98%", tag: "Clear", tagColor: .green)
                kpiRow(label: "PTT Reflex", value: "315 ms", tag: "Responsive", tagColor: .green)
            }
            .padding(14)
            .background(themeCardBg)
            .cornerRadius(cardRadius)
            .overlay(cardBorder)

            // Review Diagnostic Section
            VStack(alignment: .leading, spacing: 10) {
                Text("REVIEW DIAGNOSTIC")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.secondary)

                // Error Card 1
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Wrong Phraseology at Turn 6")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.red)
                    }

                    Text("\"PK-ABC, Pushback approve, ROGER\"")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .padding(6)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(4)

                    Button(action: { showCitationSheet = true }) {
                        HStack(spacing: 3) {
                            Image(systemName: "info.circle")
                            Text("Reference : ICAO Doc 4444: 8-3 (Klik detail)")
                        }
                        .font(.caption2)
                        .foregroundColor(.blue)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(themeCardBg)
                .cornerRadius(cardRadius)
                .overlay(cardBorder)

                // Error Card 2
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Missing : Your Callsign at Turn 10")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                    }

                    Text("\"BWX Tower, [CALLSIGN] ready to pushback\"")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .padding(6)
                        .background(Color.orange.opacity(0.08))
                        .cornerRadius(4)

                    Text("Sesuai Doc 9432 §2.8.3, callsign wajib diletakkan di akhir readback.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(themeCardBg)
                .cornerRadius(cardRadius)
                .overlay(cardBorder)
            }

            // Next CTA Button
            Button(action: {
                withAnimation { activeStep = .prepContext }
            }) {
                HStack {
                    Text("NEXT / RETRY MISSION")
                        .font(.subheadline.weight(.bold))
                    Image(systemName: "arrow.clockwise")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(themeButtonBg)
                .foregroundColor(themeButtonFg)
                .cornerRadius(cardRadius)
            }
        }
    }

    // MARK: - ICAO Citation Modal Sheet
    private var icaoCitationSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "nosign")
                        .font(.title2)
                        .foregroundColor(.red)
                    Text("Larangan Kata 'ROGER' untuk Clearance")
                        .font(.headline)
                        .foregroundColor(.red)
                }

                Text("ICAO Doc 9432 Bab 2.6 & Doc 4444 §8.3:")
                    .font(.subheadline.weight(.bold))

                Text("\"ROGER under no circumstances to be used in reply to a question requiring READ BACK or a direct answer in the affirmative (AFFIRM) or negative (NEGATIVE).\"")
                    .font(.system(size: 13, design: .monospaced))
                    .padding(12)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(8)

                Text("Kata 'ROGER' hanya berarti pesan telah diterima di telinga, bukan konfirmasi keselamatan otorisasi. Pilot wajib mengulang lengkap nomor runway, ketinggian, atau menggunakan kata WILCO.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: { showCitationSheet = false }) {
                    Text("Mengerti")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()
            .navigationTitle("Sitasi Regulasi")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Helpers & Subcomponents
    private func ofpItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(themeTextMain)
        }
    }

    private func slotBadge(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(themeTextMain)
        }
        .padding(5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(color.opacity(0.4), lineWidth: 1))
    }

    private func scratchpadItem(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(themeAccent)
        }
        .padding(6)
        .background(themeSubtleBg)
        .cornerRadius(4)
    }

    private func kpiRow(label: String, value: String, tag: String, tagColor: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(themeTextMain)
            Text(":")
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(themeTextMain)
            Spacer()
            Text(tag)
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(tagColor.opacity(0.15))
                .foregroundColor(tagColor)
                .cornerRadius(4)
        }
    }

    private func swapFrequencies() {
        let tempFreq = activeFreq
        let tempStation = activeStation
        activeFreq = stbyFreq
        activeStation = stbyStation
        stbyFreq = tempFreq
        stbyStation = tempStation

        #if canImport(UIKit)
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        #endif
    }

    private func togglePttSimulation() {
        isPttPressed.toggle()
        #if canImport(UIKit)
        let impact = UIImpactFeedbackGenerator(style: isPttPressed ? .heavy : .rigid)
        impact.impactOccurred()
        #endif

        if isPttPressed {
            showTranscript = false
        } else {
            showTranscript = true
        }
    }

    private func sampleTranscript(for level: Int) -> String {
        switch level {
        case 1: return "\"Tower, Taxiing to RWY 18 VIA ALPHA, WGN 502\""
        case 2: return "\"Turn left heading zero six zero, maintain flight level one five zero, Supergreen four two six\""
        case 3: return "\"Backtrack runway one three, line up and wait, Lion Air seven five zero\""
        case 4: return "\"Reduce speed one eight zero knots, turn heading zero niner zero, cleared ILS runway one zero, Garuda two eight three Heavy\""
        default: return "\"UNABLE heading two five zero due terrain, climbing altitude eight thousand feet, Asian One three six four!\""
        }
    }

    // Dynamic Theme Tokens
    private var themeBgColor: Color {
        themeMode == .highFidelity ? Color(red: 0.04, green: 0.05, blue: 0.08) : Color(red: 0.96, green: 0.96, blue: 0.95)
    }

    private var themeCardBg: Color {
        themeMode == .highFidelity ? Color(red: 0.08, green: 0.11, blue: 0.16) : Color.white
    }

    private var themeSubtleBg: Color {
        themeMode == .highFidelity ? Color(red: 0.12, green: 0.16, blue: 0.23) : Color(red: 0.92, green: 0.92, blue: 0.90)
    }

    private var themeBorderColor: Color {
        themeMode == .highFidelity ? Color.cyan.opacity(0.3) : Color(red: 0.2, green: 0.2, blue: 0.25)
    }

    private var themeTextMain: Color {
        themeMode == .highFidelity ? Color.white : Color(red: 0.1, green: 0.1, blue: 0.12)
    }

    private var themeAccent: Color {
        themeMode == .highFidelity ? Color.cyan : Color.blue
    }

    private var themeButtonBg: Color {
        themeMode == .highFidelity ? Color.cyan : Color(red: 0.1, green: 0.1, blue: 0.15)
    }

    private var themeButtonFg: Color {
        themeMode == .highFidelity ? Color.black : Color.white
    }

    private var cardRadius: CGFloat {
        themeMode == .highFidelity ? 14 : 8
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: cardRadius)
            .stroke(themeBorderColor, lineWidth: themeMode == .highFidelity ? 1 : 1.5)
            .shadow(color: themeMode == .midFidelity ? Color.black.opacity(0.7) : Color.cyan.opacity(0.2), radius: themeMode == .highFidelity ? 4 : 0, x: themeMode == .midFidelity ? 2 : 0, y: themeMode == .midFidelity ? 2 : 0)
    }
}
