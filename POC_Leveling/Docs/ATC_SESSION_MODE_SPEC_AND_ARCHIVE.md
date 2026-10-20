# ATC Session Mode Specification & Implementation Archive

> **Dokumen Arsip:** Dokumen ini menyimpan spesifikasi lengkap, arsitektur data, model Swift, logika generator dialog, dan antarmuka SwiftUI untuk **Mode ATC (Air Traffic Controller)** dari `POC_Leveling`. Dokumen ini dibuat agar seluruh aset dan konteks pemanduan lalu lintas multi-pesawat dapat diaktifkan kembali (*re-enabled / restored*) sewaktu-waktu tanpa kehilangan pekerjaan sebelumnya.

---

## 1. Konsep Desain Mode ATC (Single Aerodrome Multi-Traffic)

Berbeda dengan Pilot yang menjalani navigasi linier satu pesawat dari Asal ke Tujuan, **Mode ATC mengendalikan satu stasiun aerodrome** yang memandu banyak pesawat secara simultan melintasi 3 Babak Operasi:
* **Act 1: Departures & Circuit Operations:** Pengendalian pergerakan darat (Ground), startup approval, taxi route clearance, penegakan hold short, antrean take-off di runway, dan integrasi sirkuit visual latih VFR (touch-and-go).
* **Act 2: Airspace Transit & Tactical Sequencing:** Koordinasi ruang udara terminal TMA, pemisahan separasi pesawat lintas udara (overflight transit), pengaturan kecepatan, dan izin bersyarat.
* **Act 3: Arrivals & Emergency Handling:** Pengurutan antrean pendaratan, vektor final ILS, izin mendarat (cleared to land), penanganan darurat (MAYDAY / PAN-PAN), dan pengerahan tim PKP-PK.

---

## 2. Kapasitas Trafik per Level Bandara ATC

| Level | Contoh Aerodrome | Jumlah Trafik | Komposisi Trafik |
|---|---|---|---|
| **Level 1** | Banyuwangi (WADY), Budiarto (WICB), Wisnu (WADE) | 3 Trafik | 1 Full Departure + 1 VFR Touch-and-Go + 1 Full Stop Arrival |
| **Level 2** | YIA (WAHI), Lombok (WADL), Palembang (WIPP), Banjarmasin (WAOO) | 4 Trafik | 1 IFR Departure + 1 VFR Circuit + 1 Commercial Arrival ILS + 1 Diversion Arrival |
| **Level 3** | Ngurah Rai (WADD), Semarang (WARS), Batam (WIDD), Padang (WIPT), Solo (WARQ), Sepinggan (WALL) | 5 Trafik | 1 IFR Dep (Wake Delay) + 1 Overflight Transit + 1 Inbound ILS + 1 Emergency Inbound + 1 Local Circuit |
| **Level 4** | Soekarno-Hatta (WIII), Juanda (WARR), Makassar (WAAA), Medan (WIMM), Halim (WIHH) | 6 Trafik | 2 Parallel Departures + 1 Transit + 1 Diversion + 1 Emergency Inbound + 1 Final Arrival |
| **Level 5** | Wamena (WAVV), Bandung (WICC), Toraja (WAFB), Timika (WABP), Tarakan (WALR) | 7 Trafik | 2 Valley Departures + 1 Valley Transit + 1 Diversion + 2 Emergency Inbounds + 1 Final Arrival |

---

## 3. Fitur Realistis ATC yang Telah Diimplementasikan

### A. Slip of the Tongue & Hearback Error Correction (ICAO Doc 9432 Ch.2.8.3.9)
Ketika pilot salah membaca nomor runway atau ketinggian:
```text
ATC [USER]: "Batik 6001, Jakarta Ground, taxi to holding point NP2 via Papa, hold short runway two five right, QNH one zero one two."
PILOT:      "Taxi to holding point NP2 via Papa, hold short runway zero seven left, Batik 6001." (SLIP)
ATC [USER]: "Batik 6001, Jakarta Ground, NEGATIVE, I SAY AGAIN, hold short runway two five right."
PILOT:      "Hold short runway two five right, apologies, Batik 6001."
```

### B. Callsign Confusion Interception (ICAO Doc 9432 Ch.4.3.2)
Ketika pesawat lain yang memiliki kemiripan nomor penerbangan salah mengambil izin line-up:
```text
ATC [USER]: "Batik 6002, Jakarta Tower, runway two five right, line up and wait."
INTRUDER:   "Line up and wait runway two five right, Batik six six eight three!"
ATC [USER]: "Batik six six eight three, NEGATIVE, instruction was for Batik 6002. Batik six six eight three, hold position."
INTRUDER:   "Holding position, apologies, Batik six six eight three."
PILOT:      "Runway two five right, line up and wait, Batik 6002."
```

---

## 4. Model Swift Pendukung (Tersimpan di `ScriptEngineModels.swift`)

```swift
public enum ATCTrafficType: String, Codable, Sendable, CaseIterable, Identifiable {
    case fullDeparture = "Departure"
    case touchAndGo = "Touch & Go"
    case enRouteTransit = "En-Route Transit"
    case fullArrival = "Full Arrival"
    case emergencyInbound = "Emergency MAYDAY"
    case diversionArrival = "Diversion"
    ...
}

public struct ATCTrafficEntry: Identifiable, Codable, Sendable {
    public var id: String { trafficID }
    public let trafficID: String
    public let callsign: String
    public let aircraftType: String
    public let trafficType: ATCTrafficType
    public let exchanges: [FilledExchange]
    public let act: MissionAct
    public let hasContingency: Bool
    public let contingencySummary: String?
}

public struct ATCSessionScript: Identifiable, Sendable {
    public var id: Int { seed }
    public let seed: Int
    public let aerodrome: AirportCurriculumItem
    public let level: CurriculumLevel
    public let trafficEntries: [ATCTrafficEntry]
    public let diagnosticReport: DiagnosticReport?
    ...
}
```

---

## 5. Komponen View UI ATC (Arsip Kode SwiftUI)

Jika sewaktu-waktu ingin mengembalikan mode ATC ke layar utama, cukup:
1. Kembalikan picker peran di `CurriculumHubView` (`Picker("Role", selection: $selectedRole)`).
2. Tampilkan view `ATCSessionRunnerView(aerodromeICAO: selectedAtcICAO)` saat peran ATC dipilih.
3. Kode `ATCSessionRunnerView`, `ATCDiagnosticSheet`, `ATCTrafficCard`, `ATCExchangeRow`, dan `ATCContingenciesSheet` tetap tersedia secara utuh di basis kode `ContentView.swift`.
