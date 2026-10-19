# POC_MISSION: HERMES RADIOTELEPHONY CURRICULUM SIMULATOR

Proyek ini adalah evolusi dari `POC_Leveling`, yang dioptimalkan untuk memvalidasi **26 Misi Kanonikal**, **Hierarki Scaffolding Visual & Kognitif (Level 1–5)**, dan **State Machine Generator Exam Mode** berdasarkan standar resmi ICAO.

---

## 1. DOKUMEN SPESIFIKASI UTAMA (GROUND TRUTH)
1. **`MAPPING_SCAFFOLDING_SPEC.md`**: Spesifikasi scaffolding UI per level (*4-Slot Card*, *Cloze Text*, *Intent Badges*, *Cockpit HUD Strip*, *Partyline Audio Chatter*), batas jeda PTT (Uncapped, $\le 8\text{s}$, $\le 5\text{s}$, $\le 3\text{s}$, $\le 3\text{s}$), dan prinsip anti-teleprompter.
2. **`KURIKULUM_25_MISI_KANONIKAL.md`**: Rincian 25 misi kanonikal resmi dari Level 1 sampai Level 5 (M-101 s/d M-505) yang mencakup 23 bandara Indonesia.
3. **`VARIABEL_DINAMIS_DAN_EXAM_GENERATOR.md`**: Spesifikasi kolam variabel acak dinamis berbasis seed, aturan transponder oktal, aerodinamika pemilihan runway headwind, dan arsitektur generator Exam Mode.
4. **`ICAO_DOC_REFERENCE.md`**: Aturan sitasi pasal regulasi baku (*Doc 9432 Ch.X.X* / *Doc 4444: Ch.X.X*), pelarangan kata "ROGER" untuk readback clearance, dan taksonomi Doc 9835.

---

## 2. ARSITEKTUR KODE SWIFT
* **`Engine/Models.swift`**: Model data dasar aerodrome dan runway.
* **`Engine/ScriptEngineModels.swift`**: Struktur data payload scaffolding (`FourSlotCardPayload`, `ClozeMaskedPayload`, `IntentBadgePayload`, `AvionicsHUDPayload`, `SelectiveListeningBaitPayload`, `PartylineChatterPayload`, `HazardousInstructionPayload`), taksonomi severity ICAO, dan `CanonicalMissionRegistry` (26 misi).
* **`Engine/Generators.swift`**: Generator dinamis berbasis seed untuk callsign, STOL aircraft, squawk code oktal, stand, dan ATIS.
* **`Engine/WeatherEngine.swift`**: Aerodinamika vektor angin headwind/crosswind matematis dan seleksi landasan pacu.
* **`Engine/ScriptGeneratorEngine.swift`**: State machine generator misi dinamis, generator 26 misi kanonikal, dan engine pengisi scaffolding payload (`enrichExchangesWithScaffolding`).
* **`ContentView.swift`**: Antarmuka SwiftUI yang menyajikan pemilihan 26 Misi Kurikulum, Rute Bebas, Exam Mode, dan kartu scaffolding visual interaktif per level.
