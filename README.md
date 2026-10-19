# HERMES — Radiotelephony Flight Simulation Engine
### Proof-of-Concept: Multi-Page Leveling & Grounded ICAO Radiotelephony Generator
**Repository:** `AdhiKrisna/POC_Script` | **Branch:** `POC_Leveling`  
**Apple Developer Academy Final Challenge — Team Abang Tukang Bakso**

---

## 1. Executive Summary & Visi Proyek

**HERMES** adalah mesin simulasi dan generator naskah komunikasi radio penerbangan (*Aeronautical Radiotelephony Simulation*) yang dirancang khusus untuk melatih **Student Pilot** dan **Air Traffic Controller (ATC) Trainee**.

Aplikasi ini menyimulasikan komunikasi suara dua arah VHF di seluruh fase penerbangan (*Pre-Departure*, *Departure*, *En-Route*, *Arrival*, *Approach*, hingga *Landing & Shutdown*) dengan kepatuhan 100% terhadap standar internasional penerbangan:
* **ICAO Doc 9432**: *Manual of Radiotelephony* (Edisi ke-4).
* **ICAO Doc 4444**: *Air Traffic Management (PANS-ATM)* (Edisi ke-16).
* **ICAO Doc 9835**: *Manual on the Implementation of ICAO Language Proficiency Requirements*.
* **AIP Indonesia (Aeronautical Information Publication)**: Data resmi aerodrome, frekuensi ATS, taxiway, runway, holding point, SID (*Standard Instrument Departure*), dan STAR (*Standard Terminal Arrival Route*).

### Arsitektur Repository `POC_Script`
Repository ini menaungi dua tonggak penting evolusi simulator HERMES RTF:
1. **Branch `POC_Leveling` (Cabang ini)**: Validasi arsitektur multi-page leveling berjenjang (L1 s/d L5), progresi peringkat pilot (Student Pilot hingga Airline Captain), Three-Act Flight Engine (Departure, En-Route, Arrival/Approach) mencakup 23 bandara kanonikal Indonesia, dan pure deterministic FSM generator dengan 0 ms latency.
2. **Branch `POC_Mission`**: Validasi 25 Misi Kanonikal resmi (M-101 s/d M-505), hierarki scaffolding visual & kognitif (4-Slot Cards, Cloze Text, Intent Badges, Avionics HUD, Partyline Chatter), serta State Machine Exam Mode.

### Mengapa Pure Deterministic Finite State Machine (FSM), Bukan LLM Runtime?
Pada tahap awal perancangan, opsi penggunaan Large Language Model (LLM) di runtime dipertimbangkan untuk menyusun dialog dinamis. Namun, keputusan arsitektur final **menolak keras penggunaan LLM runtime dan memilih Pure Complex Deterministic FSM** karena alasan-alasan teknis fundamental:
1. **Zero Latency (0 ms)**: Simulasi berjalan instan on-device tanpa jeda inferensi jaringan 3–8 detik per transmisi radio.
2. **100% Kepatuhan Fraseologi Baku Tanpa Halusinasi**: LLM secara alamiah memiliki kecenderungan *creative drift* dan menyisipkan *conversational filler* kasual (*"Alright"*, *"Roger that"*, *"Okay sir"*). FSM menjamin kepatuhan 100% pada frasa baku ICAO Bab 2.6 yang mutlak diperlukan untuk ujian kecakapan radio.
3. **Scoring ICAO Doc 9835 yang Akurat & Terukur**: Evaluasi kata kunci keselamatan (*Mandatory Readback Slots*) dievaluasi secara presisi dan konsisten terhadap slot data navigasi penerbangan.
4. **Offline First & Biaya Nol**: Berjalan sepenuhnya tanpa koneksi internet, tanpa kuota/biaya token API, serta tanpa membebani memori terpadu (Unified Memory) perangkat Apple Silicon / iOS.

---

## 2. Arsitektur Aplikasi & Antarmuka Multi-Halaman

Aplikasi menggunakan arsitektur modular dua halaman (*Multi-Page Push Navigation Architecture*):

```
┌──────────────────────────────────────────────────────────────────┐
│ PAGE 1: Curriculum Hub (CurriculumHubView)                       │
│ • Seleksi 5 Level Kurikulum Berjenjang (L1 s/d L5)               │
│ • Pilot Rank Progression Status (SP, CPL, IR, ATPL, Master)      │
│ • Dynamic Airport Selector (23 Bandara Kanonikal Sesuai Level)   │
│ • Ringkasan Rute, Profil Pesawat, Jarak, & Topik Pembelajaran    │
└─────────────────────────────────┬────────────────────────────────┘
                                  │ Push Navigation (NavigationLink)
                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│ PAGE 2: Mission Simulator (MissionSimulatorView)                 │
│ • Cockpit HUD Bar (Origin, Dest, Callsign, FL, Squawk, Weather)  │
│ • Interactive Role Switcher: Student Pilot ⇄ ATC Trainee         │
│ • Scenario Picker Sheet (Targeted Drill 100% vs Fair Multi-Roll) │
│ • Passive Cockpit ATIS Broadcast Header Box (Doc 9432 Bab 4.4.3) │
│ • 6-Phase Scrollable Timeline Filter Tabs (All / 1..6)           │
│ • Turn-by-Turn Card View dengan Verifikasi Mandatory Readback    │
│ • Three-Act Mission Flow (Departure -> En-Route -> Arrival)      │
│ • Post-Session Diagnostic & Performance Report (Doc 9835)        │
└──────────────────────────────────────────────────────────────────┘
```

### Fitur Utama di Halaman Simulasi (`MissionSimulatorView`):
1. **Interactive Role Switcher**:
   * Mode **Pilot**: Pengguna berperan sebagai pilot yang menerima instruksi ATC dan wajib melakukan *readback* elemen navigasi dan keselamatan kritis.
   * Mode **ATC Trainee**: Pengguna berperan sebagai controller yang memandu pesawat, memantau separasi, menerbitkan perizinan, dan merespons situasi darurat.
2. **Interactive Scenario Picker (Modal Sheet)**:
   * Membuka katalog skenario kontinjensi sah yang terisolasi khusus untuk level aktif.
   * **Targeted Drill Mode (100% Guaranteed)**: Jika pengguna sengaja memilih 1 skenario spesifik (misalnya *Unsafe Gear* atau *Bird Strike Abort*), sistem menjamin 100% skenario tersebut muncul saat regenerasi.
   * **Bulk Actions**: Tombol *Pilih Semua* dan *Kosongkan (Routine Only)* untuk kemudahan demonstrasi pengujian.
3. **Cockpit ATIS Header Box (Pemisahan Pasif)**:
   * Sesuai ICAO Doc 9432 Bab 4.4.3 & 4.6.2, siaran ATIS disajikan sebagai panel instrumen rekaman pasif di atas timeline naskah (seperti radio COMM-2 kokpit). Menghilangkan dialog salah kaprah di mana pilot seolah-olah mengobrol dua arah dengan siaran ATIS.
4. **Adaptive Phase Filtering**:
   * Tab filter: *All Phases*, *1. Pre-Dep*, *2. Dep*, *3. En-Route*, *4. Arr*, *5. App*, *6. Landing*.

---

## 3. Kurikulum 5 Level Berjenjang (23 Bandara Kanonikal)

Kurikulum dirancang bertahap mengikuti silabus sekolah penerbangan dan lisensi pilot resmi (PPL $\rightarrow$ CPL $\rightarrow$ IR $\rightarrow$ ATPL $\rightarrow$ Mountain/Valley Master):

| Level | Rute & Jarak Representatif | Jenis Lisensi / Profil | Karakteristik Ruang Udara | Fokus Pembelajaran Radiotelephony |
| :---: | :---: | :---: | :---: | :--- |
| **Level 1** | **BWX – BWX**<br>(WADY – WADY)<br>*Sirkuit Visual* | PPL / Siswa Mula<br>**C172, PA-28, DA-40**<br>(Single Engine Piston) | Uncontrolled / Class D Aerodrome (1.000–1.500 ft AGL) | Pola sirkuit visual (*Traffic Pattern*), *touch-and-go*, *wind shift*, *visual orbit spacing 360°*, *extend downwind*, *blind transmission (NORDO)*, dan pengenalan *rejected take-off roll (RTO)*. Bandara: WADY, WADE, WAOO, WARQ, WARS. |
| **Level 2** | **BWX – DPS**<br>(WADY – WADD)<br>*55 NM* | CPL / Navigasi Lintas Batas<br>**ATR 72, Dash 8, C208**<br>(Regional Turboprop, FL080) | Transisi VFR ke IFR, batas FIR Surabaya – Bali | Navigasi lintas batas, handoff Tower ke Bali Control, penyeberangan Selat Bali, deviasi awan CB, kegagalan flap di Bali, dan darurat medis penumpang. Dijamin 100% terbang airborne ke tujuan. Bandara: WADY, WADD, WICB, WIPP, WIPT. |
| **Level 3** | **DPS – SUB**<br>(WADD – WARR)<br>*165 NM* | Instrument Rating (IR)<br>**A320, B737**<br>(Commercial Jet, FL240) | Controlled Class A/C Airspace, Tactical Radar Vectoring | Pemanduan vektor radar Surabaya, separasi kecepatan (*speed control*), separasi *wake turbulence*, *radar avoiding action turn*, penanganan roda tidak terkunci (*unsafe gear VOR holding*), dan *uncleared go-around*. Bandara: WADD, WARR, WADL, WAHI, WALL, WIDD. |
| **Level 4** | **SUB – CGK**<br>(WARR – WIII)<br>*365 NM* | Airline Transport Pilot (ATPL)<br>**B737, A320, A330**<br>(Jet Transport, FL360) | High-Density Airspace, Parallel Runways, CDM Slot | Mitigasi *runway incursion crossing*, kegagalan mesin jelajah (*mid-air engine out diversion*), penurunan darurat dekompresi kabin (FL360 ke FL100), pendekatan paralel, dan penegakan *silence imposition*. Bandara: WIII, WARR, WAAA, WIMM, WIHH. |
| **Level 5** | **TIM – WMX**<br>(WABP – WAVV)<br>*110 NM* | Mountain / Valley Operations<br>**DHC-6, ATR 72, C208, A320**<br>(STOL / High Performance) | Extreme Terrain, High-Altitude Valley (El >5.000 ft) | Navigasi lembah pegunungan tinggi, *valley visual blind transmission*, wind shear kuat di final, *hazardous ATC instruction challenge*, dan kegagalan sensor GPS/RNAV di area pegunungan. Bandara: WAVV, WICC, WAFB, WABP, WALR. |

---

## 4. Distribusi Skenario & Model Probabilitas "Fair"

### A. Katalog 30 Skenario Kontinjensi ICAO
Skenario diklasifikasikan ke dalam 4 tingkatan keparahan resmi (*Event Severity*):
1. **Normal**: Kondisi rutin operasional (Conditional Line-Up, Backtrack, Routine ILS).
2. **Abnormal**: Deviasi operasional tanpa ancaman langsung jiwa (Runway Change akibat angin, Wake Turbulence Delay, Bird Hazard Dispersal, Weather Deviation, Holding Delay).
3. **Urgency (PAN PAN)**: Keamanan pesawat terancam tetapi tidak memerlukan bantuan segera (Unsafe Gear Indication, Flap System Failure, Medical Heart Attack, Uncleared Go-Around).
4. **Distress (MAYDAY)**: Kondisi ancaman bahaya maut yang memerlukan pertolongan darurat segera (Bird Strike Abort, EFATO, Mid-Air Engine Out, Cabin Decompression Emergency Descent, TCAS RA).

### B. Model Probabilitas yang Adil (*Fair Pedagogical Distribution*)
Sistem menerapkan distribusi kurikulum berimbang untuk menjaga kualitas pedagogis:
* **55% – 70% dari Seed**: **ROUTINE NORMAL FLIGHT (Penerbangan Utuh 100% Mulus)**.
  Mahasiswa berlatih percakapan standar end-to-end dari Phase 1 hingga Phase 6.
* **30% – 45% dari Seed**: **SINGLE FOCUSED CONTINGENCY FLIGHT (Tepat 1 Kejadian Khas)**.
  Siswa fokus melatih 1 prosedur tertentu sesuai levelnya (misalnya deviasi awan CB di Selat Bali, atau roda macet di Surabaya).
* **Maksimal 5% dari Seed**: **DUAL COHERENT CONTINGENCY** (kombinasi 2 gangguan minor di fase berbeda tanpa saling bertentangan).
* **Targeted Drill Mode**: Jika pengguna membuka modal sheet dan hanya mencentang skenario tertentu (misal *Unsafe Gear*), skenario tersebut **100% langsung muncul** di setiap regenerasi seed.

---

## 5. Pacing & Ritme Autentik Fase Arrival & Approach (Doc 9432 Bab 6 & 7)

Fase penurunan (*Arrival*) dan pendekatan akhir (*Approach*) mengimplementasikan **20 pertukaran dialog berbobot (~9–10 menit simulasi)** yang menyajikan prosedur radar sesungguhnya:

### A. Phase 4: Arrival (8 Turns, ~3.6 Menit)
1. **Top of Descent Clearance**:
   ATC mengizinkan penurunan awal ke FL100 via prosedur STAR tunggal yang sah (misal: `DOLTA One Alfa (DOLTA 1A)` tanpa string garis miring ambigu).
2. **Waypoint Altitude & Speed Constraints (Doc 9432 Bab 6.4)**:
   ATC memberikan restriksi ketinggian dan kecepatan di waypoint pintu masuk STAR:  
   `ATC: "[Callsign], cross BUNTA at flight level one four zero, speed two two zero knots or less."`  
   `PILOT: "Cross BUNTA at flight level one four zero, speed two two zero knots, [Callsign]."`
3. **Transition Level & Altimeter Setting (Doc 9432 Bab 7.2)**:
   Saat melintasi transition level, ATC menerbitkan QNH aerodrome tujuan dan mengizinkan penurunan ke ketinggian 5.000 ft. Pilot wajib me-readback QNH dan ketinggian.
4. **Handoff ke Approach Control**:
   Transfer tertib dari En-Route Radar Controller ke Approach Terminal Controller.

### B. Phase 5: Approach (10–12 Turns, ~4.5–5.5 Menit)
1. **Initial Vectoring & Base Leg Heading (Doc 9432 Bab 7.5)**:
   ATC Approach memberikan kontak radar dan mengarahkan vektor base leg:  
   `"Turn heading zero one zero, descend and maintain three thousand feet, QNH one zero one five, vectoring for ILS runway two five right."`
2. **Speed Reduction & Intercept Heading (30° Angle Closing)**:
   ATC mengatur separasi kecepatan (*"reduce speed one eight zero knots"*) dan memberikan heading potong 30° ke arah localizer (*"turn heading two eight zero, cleared ILS approach runway two five right, report established on localizer"*).
3. **Localizer Established Confirmation**:
   Pilot memantau indikator CDI di kokpit dan melapor saat jarum localizer terkunci:  
   `"Jakarta Approach, [Callsign], established on localizer runway two five right."`
4. **Speed Restriction Cancelled & Transfer ke Tower**:
   ATC mencabut batasan kecepatan (*"no ATC speed restrictions"*) dan menyerahkan frekuensi ke Tower Controller (`118.75`).
5. **Tower 4-Miles Final & Landing Clearance**:
   Pada posisi 4 mil final, Tower mengonfirmasi runway bebas dan menerbitkan izin mendarat beserta kondisi angin permukaan aktual dan peringatan landasan basah (*braking action poor*) jika aktif.

---

## 6. Kepatuhan Baku Regulasi Penerbangan (ICAO Standards)

Aplikasi mengunci aturan fraseologi baku berikut tanpa kompromi:
1. **Larangan Penggunaan Kata "ROGER" oleh Pilot (Doc 9432 Bab 2.6)**:
   Pilot dilarang keras menjawab perizinan menggunakan kata "Roger". Pilot wajib melakukan *full readback* nomor runway/ketinggian/heading, atau menggunakan kata **WILCO** / **AFFIRM**.
2. **Prosedur Baku Line Up and Wait (Doc 9432 Bab 4.5.3)**:
   Menggantikan lompatan langsung take-off. Seluruh level menerapkan otorisasi masuk dan menahan di landasan (*Line Up and Wait*), termasuk variasi *Conditional Line Up*.
3. **Pemisahan Inisiasi Pembatalan Lepas Landas (Doc 9432 Bab 4.5.11 vs 4.5.12)**:
   * **ATC-Initiated Abort (Bab 4.5.11)**: Berlaku untuk bahaya eksternal di landasan (*vehicle entering runway*). ATC memanggil duluan: `"STOP IMMEDIATELY, [Callsign], STOP IMMEDIATELY!"`.
   * **Pilot-Initiated Abort (Bab 4.5.12)**: Berlaku untuk kerusakan internal pesawat (*bird strike*, mesin meledak). Pilot yang merasakan masalah $\rightarrow$ Pilot yang menekan PTT duluan.
4. **Single Cohesive Transmission (Doc 9432 Bab 4.10 & Doc 4444 Bab 12.3.1.2)**:
   Informasi kondisi aerodrome temporer disatukan langsung dalam satu transmisi dengan instruksi masuk landasan.
5. **Format Pengucapan Angka Fonetik & Waktu UTC (Doc 9432 Bab 2.5)**:
   Seluruh angka diformat fonetik ICAO terpisah (`one zero one two`, `flight level two four zero`), dan waktu mematuhi menit berjalan UTC.
6. **Konsistensi Prosedur Navigasi (Anti-Slash Purity)**:
   Prosedur STAR dan SID mengunci rute tunggal yang sah (misal: `DOLTA One Alfa (DOLTA 1A)`), bebas dari artefak string bergaris miring ganda.

---

## 7. Inovasi "Zero Empty Phase" (Adaptive Ground Response Pipeline)

Jika pesawat membatalkan lepas landas di Phase 2 (Departure), seluruh fase berikutnya dialihkan secara adaptif ke protokol penanganan darurat darat resmi ICAO:
* **Phase 3**: *Runway Assessment & Brake Cooling* (Evaluasi suhu rem panas, penahanan lalu lintas final).
* **Phase 4**: *ARFF & Safety Operations Escort* (Pemeriksaan eksternal oleh armada pemadam Tender One).
* **Phase 5**: *Runway Vacated & Aerodrome Reopening* (Laporan pengosongan landasan, pembukaan kembali aerodrome untuk trafik).
* **Phase 6**: *Maintenance Stand & Flight Plan Cancellation* (Parkir di stand perawatan, pembatalan rencana penerbangan pada jam UTC).

---

## 8. Dokumentasi Teknis & Spesifikasi Engine (`Docs/`)

Folder `POC_Leveling/Docs/` memuat 8 dokumen spesifikasi teknis primer:

1. **`DATASET_SCHEMA.md`**: Spesifikasi skema JSON dua tingkat (Tier 1 fisik bandara & Tier 2 data operasional penerbangan).
2. **`GENERATOR_LOGIC.md`**: Logika alur 5-langkah pure deterministic finite state machine (FSM).
3. **`REQUEST_AND_EMERGENCY_RESPONSE_ENGINE.md`**: Spesifikasi state machine untuk permintaan pilot, skenario abnormal, dan respons darurat.
4. **`WIND_WEATHER_AND_DYNAMIC_VARIABLES.md`**: Perhitungan vektor aerodinamika angin (headwind/crosswind) dan pemilihan landasan pacu.
5. **`FULL_END_TO_END_SCRIPT_GENERATOR_PLAN.md`**: Arsitektur end-to-end 3-act (6-phase) mission generator.
6. **`ICAO_PHRASEOLOGY_VS_PLAIN_LANGUAGE_REFERENCE.md`**: Kompendium otoritatif standar fraseologi ICAO vs Plain Aviation English.
7. **`ATC_SESSION_MODE_SPEC_AND_ARCHIVE.md`**: Spesifikasi dan arsip kode implementasi mode controller (ATC).
8. **`TEMPLATE_SCHEMA.md`**: Format skema template percakapan per fase penerbangan.

Data sumber 23 bandara kanonikal dan referensi AIP Indonesia terdokumentasi di:
* **`POC_Leveling/Resources/Airports/AirportDataSources.md`**

---

## 9. Struktur Direktori Proyek

```
POC_Leveling/
├── README.md                                  <- Dokumentasi teknis branch POC_Leveling
├── POC_Leveling.xcodeproj                     <- Proyek Xcode utama (iOS / iPadOS)
└── POC_Leveling/
    ├── MyApp.swift                            <- Entry point SwiftUI (@main)
    ├── ContentView.swift                      <- Antarmuka pengguna multi-halaman & komponen UI
    ├── Engine/
    │   ├── Models.swift                       <- Data model bandara, runway, taxiway, frekuensi ATS
    │   ├── ScriptEngineModels.swift           <- Model kurikulum 5 level, 30 kontinjensi, SlotContext
    │   ├── ScriptGeneratorEngine.swift        <- Mesin generator naskah FSM & Sequential Flow Assembler
    │   ├── Generators.swift                   <- Generator pesawat realistis & rute penerbangan
    │   ├── WeatherEngine.swift                <- Mesin kalkulasi komponen angin & penyesuaian QNH
    │   ├── SpokenFormFormatter.swift          <- Formatter pengucapan fonetik ICAO, knot, waktu UTC
    │   ├── Repositories.swift                 <- Airport repository & pemuat template lokal
    │   └── EmergencyResponseEngine.swift      <- Penilai respon darurat & scoring Doc 9835
    ├── Docs/                                  <- 8 Dokumen spesifikasi teknis primer
    └── Resources/
        ├── Airports/                          <- 23 Dataset resmi bandara AIP Indonesia (.json)
        │   └── AirportDataSources.md          <- Catatan sumber & sitasi resmi AIP eAIP
        └── Templates/                         <- Template percakapan standar ICAO Doc 9432
```

---

## 10. Panduan Menjalankan via Xcode & Terminal

### Kebutuhan Sistem
* macOS 14.0+ (Sonoma atau Sequoia).
* Xcode 16.0+ dengan iOS 18+ SDK.

### Cara Menjalankan via Xcode
1. Buka file proyek:
   ```bash
   open POC_Leveling.xcodeproj
   ```
2. Pilih skema target: **`POC_Leveling`**.
3. Pilih perangkat tujuan: **iPhone 16** atau **iPhone 16 Pro (Simulator)**.
4. Tekan **Run (Cmd + R)**.

### Build Test via Terminal
```bash
xcodebuild -scheme POC_Leveling -destination 'generic/platform=iOS' build
```

---
*Dokumentasi ini disusun untuk Apple Developer Academy Final Challenge — Team Abang Tukang Bakso.*
