# HERMES — Radiotelephony Flight Simulation Engine
### Proof-of-Concept: Canonical Missions, Scaffolding Hierarchy & Exam Engine
**Repository:** `AdhiKrisna/POC_Script` | **Branch:** `POC_Mission`  
**Apple Developer Academy Final Challenge — Team Abang Tukang Bakso**

---

## 1. Executive Summary & Visi Proyek

**HERMES** adalah simulator dan generator naskah komunikasi radio penerbangan (*Aeronautical Radiotelephony Simulation Engine*) yang dirancang untuk melatih **Student Pilot** dan **Air Traffic Controller (ATC) Trainee** menggunakan metodologi *Deliberate Practice* dan *Cognitive Scaffolding*.

Aplikasi ini menyimulasikan komunikasi suara dua arah VHF di seluruh fase penerbangan dengan kepatuhan 100% terhadap standar internasional penerbangan:
* **ICAO Doc 9432**: *Manual of Radiotelephony* (Edisi ke-4).
* **ICAO Doc 4444**: *Air Traffic Management (PANS-ATM)* (Edisi ke-16).
* **ICAO Doc 9835**: *Manual on the Implementation of ICAO Language Proficiency Requirements*.
* **AIP Indonesia (Aeronautical Information Publication)**: Data resmi 23 bandara kanonikal Indonesia, frekuensi ATS, taxiway, runway, holding point, SID, dan STAR.

### Arsitektur Repository `POC_Script`
Repository ini menaungi dua tonggak penting evolusi simulator HERMES RTF:
1. **Branch `POC_Leveling`**: Fondasi multi-page leveling berjenjang (L1 s/d L5), progresi peringkat pilot, Three-Act Flight Engine (Departure, En-Route, Arrival/Approach), integrasi dataset 23 bandara kanonikal Indonesia, dan pure deterministic FSM generator (0 ms latency).
2. **Branch `POC_Mission` (Cabang ini)**: Formalisasi **25 Misi Kanonikal** kurikulum resmi (M-101 s/d M-505), implementasi **Hierarki Scaffolding Visual & Kognitif** bertahap (4-Slot Cards, Cloze Text, Intent Badges, Cockpit HUD Strip, Partyline Audio Chatter), serta mesin **Exam Mode State Machine** dengan pengacakan variabel dinamis (seed-based).

### Mengapa Pure Deterministic Finite State Machine (FSM), Bukan LLM Runtime?
* **Zero Latency (0 ms)**: Berjalan instan secara on-device di iPhone/iPad tanpa jeda inferensi jaringan 3–8 detik.
* **100% Kepatuhan Fraseologi Baku Tanpa Halusinasi**: Mencegah *creative drift* dan kata pengisi kasual (*"Roger that"*, *"Alright"*). FSM mengunci frasa baku ICAO Bab 2.6.
* **Scoring ICAO Doc 9835 yang Akurat**: Evaluasi kata kunci keselamatan (*Mandatory Readback Slots*) diuji secara konsisten terhadap slot navigasi.
* **Offline First & Biaya Nol**: Berjalan sepenuhnya tanpa koneksi internet, tanpa kuota token API, dan ramah memori perangkat Apple Silicon.

---

## 2. Kurikulum 25 Misi Kanonikal Resmi (Level 1 – 5)

Kurikulum dirancang bertahap mengikuti silabus sekolah penerbangan dan lisensi pilot resmi, mencakup 23 bandara kanonikal Indonesia:

```
[LEVEL 1: FLIGHT CADET] ──► 5 Misi Lokal Sirkuit VFR (WADY, WICB, WADE)
[LEVEL 2: JUNIOR FO]    ──► 4 Misi P-to-P IFR Regional (WAHI, WADL, WAOO, WIPP)
[LEVEL 3: SENIOR FO]    ──► 6 Misi P-to-P Jet Single-Runway (WARS, WADD, WIDD, WIPT, WARQ, WALL)
[LEVEL 4: CAPTAIN]      ──► 5 Misi Hub Metropolitan (WIII, WARR, WAAA, WIMM, WIHH)
[LEVEL 5: SR CAPTAIN]   ──► 5 Misi Medan Lembah & Tebing Ekstrem (WAVV, WICC, WAFB, WABP, WALR)
──────────────────────────────────────────────────────────────────────────────────────────────────
TOTAL: 25 Misi Kanonikal Terstruktur
```

### Rincian Kurikulum per Level:
| Level & Pangkat | Karakter Ruang Udara | Pesawat | UI Scaffolding | PTT Timeout | Karakteristik Misi |
|---|---|---|---|---|---|
| **Level 1**<br>Flight Cadet | **3 Bandara Sekolah**<br>(`WADY`, `WICB`, `WADE`) | C172, PA-28, DA40 | **4-Slot Data Card**<br>(Stasiun, Callsign, Posisi, Aksi) | **Uncapped**<br>(Tanpa batas) | 5 Misi Sirkuit Lokal VFR (100% Rutin Murni). Penanaman struktur dasar transmisi radio. |
| **Level 2**<br>Junior FO | **4 Bandara Regional**<br>(`WAHI`, `WADL`, `WAOO`, `WIPP`) | ATR 72, C208 | **Cloze Text**<br>(Teks rumpang, angka kritis dikosongkan) | **$\le 8$ detik** | 4 Misi P-to-P Regional. 4 anomali darat/tanjak (Pushback Delay, Stop, Unable, Hold Short). |
| **Level 3**<br>Senior FO | **6 Bandara Single-Runway**<br>(`WARS`, `WADD`, `WIDD`, `WIPT`, `WARQ`, `WALL`) | A320, B737-800 | **Intent Badges**<br>(Kartu Intensi Bahasa Indonesia) | **$\le 5$ detik** | 6 Misi P-to-P Jet Komersial. Skenario kompaun 2-fase (Holding EAT, Flap Failure, Go-Around). |
| **Level 4**<br>Captain | **5 Bandara Hub Metro**<br>(`WIII`, `WARR`, `WAAA`, `WIMM`, `WIHH`) | B777, A330, A320 | **Universal Cockpit HUD Strip**<br>(Audio-Only, instrumen kokpit) | **$\le 3$ detik** | 5 Misi Hub Lintas Pulau. Callsign umpan (Selective Listening Bait), CTOT slot delay, RTO check. |
| **Level 5**<br>Senior Captain | **5 Bandara Medan Ekstrem**<br>(`WAVV`, `WICC`, `WAFB`, `WABP`, `WALR`) | B735 STOL, ATR-72, DHC-6 | **HUD Strip + Partyline Chatter**<br>(Suara latar VHF interaktif) | **$\le 3$ detik** | 5 Misi Lembah & Tebing Ekstrem. GPWS warning, dekompresi FL170 MORA Papua, instruksi ATC berbahaya. |

---

## 3. Matriks Hierarki Scaffolding Visual & Kognitif

Prinsip utama pedagogi HERMES RTF Simulator adalah **Anti-Teleprompter**: antarmuka pengguna bukan tempat menyontek kalimat lengkap bahasa Inggris. Bantuan teks dipangkas secara bertahap agar taruna membangun *mental model* dan refleks mandiri:

1. **Level 1 — 4-Slot Flight Data Card**:
   * Menanamkan struktur baku ICAO: `[Stasiun] + [Callsign] + [Posisi] + [Permintaan / Aksi]`.
   * Dilengkapi lencana warna terpisah dan panduan pengucapan fonetik angka (*WUN, TOO, TREE, FOW-ER, FIFE, SIX, SEV-EN, AIT, NIN-ER, ZE-RO*).
2. **Level 2 — Cloze Masked Text**:
   * Teks rumpang di mana variabel kunci penerbangan dikosongkan (`[RUNWAY]`, `[ALTITUDE]`, `[QNH]`, `[CALLSIGN]`).
   * Melatih pendengaran aktif (*active listening*) dan mengatasi kelupaan memori kerja (*working memory decay*).
3. **Level 3 — Intent Badges (Bahasa Indonesia)**:
   * Teks skrip bahasa Inggris dihilangkan total. Digantikan oleh lencana tujuan operasional 1 kalimat dalam bahasa Indonesia.
   * Siswa wajib menerjemahkan intensi operasional menjadi fraseologi standar ICAO secara mandiri di bawah tekanan waktu $\le 5$ detik.
4. **Level 4 — Universal Cockpit HUD Strip**:
   * Tampilan visual hanya berupa bar instrumen status fisik pesawat (Waypoint, Flap, Gear, Speed, Altimeter, Baro).
   * Siswa mendengarkan audio instruksi ATC bertumpuk dan merespons tanpa bantuan teks apapun.
5. **Level 5 — Cockpit HUD + Partyline Audio Chatter**:
   * Menghadirkan simulasi frekuensi VHF nyata: lalu lintas radio pesawat lain terdengar di latar belakang dengan efek radio ducking.
   * Siswa dilatih menyaring panggilan (*selective attention*) di tengah gangguan audio dan bahaya instruksi ATC yang melanggar batas keselamatan (*Hazardous Instruction Challenge*).

---

## 4. Dual Mode: Misi Kurikulum vs Exam Mode

Aplikasi menyediakan dua jalur latihan utama di `CurriculumHubView`:

### A. Jalur Misi (Curriculum Mission Mode)
* Akses langsung ke seluruh **25 Misi Kanonikal** berjenjang (M-101 hingga M-505).
* Dilengkapi kartu scaffolding visual interaktif sesuai level aktif.
* Menyajikan ringkasan rute, profil armada, frekuensi kerja ATS, dan data bandara resmi AIP.

### B. Jalur Ujian (Exam Mode State Machine)
* Mode evaluasi ketat untuk sertifikasi kelulusan level dengan rotasi dinamis aerodrome basis:
  * **Level 1 Exam (Cadet Checkride)**: Rotasi dinamis antara 3 bandara sekolah penerbang (**WADY** Banyuwangi, **WICB** Curug, **WADE** Buleleng). Sirkuit lokal VFR rutin 1 putaran penuh (100% normal, tanpa anomali), evaluasi kepatuhan struktur 4-elemen dasar, dan rotasi arah sirkuit (*left/right traffic*).
  * **Level 2 Exam (Junior FO Checkride)**: Rotasi dinamis antara 4 bandara regional (**WAHI** YIA, **WADL** Lombok, **WAOO** Banjarmasin, **WIPP** Palembang). 100% anomali tunggal terdistribusi seimbang 25% (*deterministic single hook: seed % 4*): *Pushback Delay* (2–5m), *Stop Pushback Immediately*, *Unable Altitude Profile* (minta FL140), dan *Hold Short Exact*.
  * **Level 3 Exam (Senior FO Checkride)**: Rotasi dinamis antara 6 bandara landasan tunggal (**WARS** Semarang, **WADD** Bali, **WIDD** Batam, **WIPT** Padang, **WARQ** Solo, **WALL** Balikpapan). 100% skenario kompaun 2-fase lintas rute (1 Keberangkatan: *Backtrack / Wake Turb / Conditional Line-Up / Immediate Take-off* $\times$ 1 Kedatangan: *Holding EAT / Delaying Orbit / Continue Approach / Flap Failure*).
  * **Level 4 Exam (Captaincy Checkride)**: Rotasi dinamis antara 5 metropolitan hub (**WIII** Cengkareng, **WARR** Surabaya, **WAAA** Makassar, **WIMM** Medan, **WIHH** Halim). 2-Stage Checkride: Spot Check High-Speed RTO (*Exam 4A*) + 12 Variasi Gate-to-Gate (*Exam 4B*: 3 Darat $\times$ 4 Udara/Terminal) dengan *Bait Callsign* untuk menguji *Selective Auditory Attention*.
  * **Level 5 Exam (Command Checkride)**: Rotasi dinamis pasangan rute medan lembah & tebing ekstrem (Wamena **WAVV** $\leftrightarrow$ Timika **WABP**, Bandung **WICC** $\rightarrow$ Halim **WIHH**, Toraja **WAFB** $\rightarrow$ Makassar **WAAA**, Tarakan **WALR** $\rightarrow$ Balikpapan **WALL**). 100% kedaruratan mutlak berbasis 3 Trajektori Penerbangan ICAO (11 Variasi: *Immediate Abort EFATO + Excursion ARFF*, *In-Flight Diversion Decompression FL170 MORA / MAYDAY FUEL*, dan *Tactical Recovery GPWS / Wind Shear / Go-Around*).
* Kolam variabel dinamis berbasis *Seed*: nomor penerbangan, arah angin aktual, tekanan QNH, dan nomor landasan pacu diacak secara matematis sesuai rentang spesifikasi resmi `VARIABEL_DINAMIS_KURIKULUM_LEVEL_1_5.pdf`.

---

## 5. Mesin Variabel Dinamis & Aturan Aerodinamika

1. **Kalkulasi Vektor Angin (Headwind vs Tailwind)**:
   * Menghitung komponen vektor angin $W_s \cos(\Delta\theta)$ terhadap kedua ujung landasan pacu.
   * Secara otomatis memilih landasan pacu aktif dengan komponen *headwind* terbesar dan mengunci seluruh instruksi taksi, holding point, dan fraseologi terkait.
2. **Aturan Transponder Oktal (Squawk Code)**:
   * Level 1 (VFR): Tetap `1200`.
   * Level 2–5 (IFR): Menggunakan bilangan oktal 4-digit valid ($0\dots 7$), mencegah kode darurat terlarang (`7500`, `7600`, `7700`) muncul secara acak di kondisi normal.
3. **Format Waktu & Pengucapan ICAO**:
   * Penomoran stand/gate dan runway selalu dibaca per digit fonetik (`Stand one two`, `Runway two five left`).
   * Pelarangan kata *"ROGER"* untuk konfirmasi perizinan navigasi/keselamatan (wajib *full readback* atau *WILCO*).

---

## 6. Dokumentasi Teknis Primer (`Docs/`)

Folder `POC_Mission/Docs/` memuat 4 dokumen spesifikasi primer:

1. **`KURIKULUM_25_MISI_KANONIKAL.md`**: Rincian lengkap 25 misi kanonikal resmi dari Level 1 sampai Level 5 (M-101 s/d M-505) yang mencakup 23 bandara Indonesia.
2. **`MAPPING_SCAFFOLDING_SPEC.md`**: Spesifikasi komprehensif arsitektur visual scaffolding UI per level, batas jeda PTT, dan prinsip anti-teleprompter.
3. **`VARIABEL_DINAMIS_DAN_EXAM_GENERATOR.md`**: Spesifikasi kolam variabel acak dinamis berbasis seed, aturan transponder oktal, aerodinamika runway headwind, dan arsitektur Exam Mode.
4. **`ICAO_DOC_REFERENCE.md`**: Aturan sitasi pasal regulasi baku (*Doc 9432 Ch.X.X* / *Doc 4444: Ch.X.X*), larangan kata "ROGER", dan taksonomi Doc 9835.

Data sumber 23 bandara kanonikal dan referensi AIP Indonesia terdokumentasi di:
* **`POC_Mission/Resources/Airports/AirportDataSources.md`**

---

## 7. Struktur Direktori Proyek

```
POC_Mission/
├── README.md                                  <- Dokumentasi teknis branch POC_Mission (file ini)
├── POC_Mission.xcodeproj                      <- Proyek Xcode utama (iOS / iPadOS)
└── POC_Mission/
    ├── MyApp.swift                            <- Entry point SwiftUI (@main)
    ├── ContentView.swift                      <- UI Curriculum Hub (25 Misi, Exam Mode, Scaffolding Cards)
    ├── Engine/
    │   ├── Models.swift                       <- Data model aerodrome, runway, frekuensi ATS
    │   ├── ScriptEngineModels.swift           <- Payload scaffolding, CanonicalMissionRegistry, taksonomi ICAO
    │   ├── ScriptGeneratorEngine.swift        <- State machine misi dinamis & enricher scaffolding
    │   ├── Generators.swift                   <- Generator dinamis callsign, ATIS, squawk oktal, stand
    │   ├── WeatherEngine.swift                <- Aerodinamika vektor angin headwind & seleksi runway
    │   ├── SpokenFormFormatter.swift          <- Formatter pengucapan fonetik ICAO & waktu UTC
    │   ├── Repositories.swift                 <- Airport repository & pemuat template lokal
    │   └── EmergencyResponseEngine.swift      <- Evaluasi respon darurat & kepatuhan readback
    ├── Docs/                                  <- 4 Dokumen spesifikasi ground-truth
    └── Resources/
        ├── Airports/                          <- 23 Dataset resmi bandara AIP Indonesia (.json)
        │   └── AirportDataSources.md          <- Catatan sumber & sitasi resmi AIP eAIP
        └── Templates/                         <- Template percakapan standar ICAO Doc 9432
```

---

## 8. Panduan Menjalankan via Xcode & Terminal

### Kebutuhan Sistem
* macOS 14.0+ (Sonoma atau Sequoia).
* Xcode 16.0+ dengan iOS 18+ SDK.

### Cara Menjalankan via Xcode
1. Buka file proyek:
   ```bash
   open POC_Mission.xcodeproj
   ```
2. Pilih skema target: **`POC_Mission`**.
3. Pilih perangkat tujuan: **iPhone 16** atau **iPhone 16 Pro (Simulator)**.
4. Tekan **Run (Cmd + R)**.

### Build Test via Terminal
```bash
xcodebuild -scheme POC_Mission -destination 'generic/platform=iOS' build
```

---
*Dokumentasi ini disusun untuk Apple Developer Academy Final Challenge — Team Abang Tukang Bakso.*
