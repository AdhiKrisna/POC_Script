# SPESIFIKASI VARIABEL DINAMIS & STATE MACHINE EXAM GENERATOR

Dokumen ini memuat standarisasi variabel dinamis (*dynamic variable pools*) dan arsitektur pengacakan *Exam Mode* (Ujian Naik Level) berdasarkan **Variabel_Dinamis.pdf** dan diskusi tim.

---

## 1. FILOSOFI: SEED-BASED DYNAMIC VARIABLES
* Skenario misi dan kompetensi ICAO tetap **DIKUNCI**, tetapi variabel operasionalnya **DIACAK REALISTIS** berbasis *Random Seed*.
* Taruna mengulang misi yang sama untuk mengasah *muscle memory*, tetapi telinga tidak bisa menghafal mati angka karena nomor penerbangan, arah angin, QNH, dan nomor landasan selalu berubah dinamis.

---

## 2. KOLAM VARIABEL DINAMIS PER LEVEL

| Level | Kategori Rute | Kolam Pesawat & Operator | Kolam Callsign Pemain | Rentang Cuaca & Altimetri | Variabel Khusus Level |
|---|---|---|---|---|---|
| **Level 1** | Flight School & Local Circuit | Cessna 172 Skyhawk<br>Piper Archer PA-28<br>Diamond DA40 | `Skyfox [10–99]`<br>`Indo Air [01–20]`<br>Reg: `PK-WIC`, `PK-ABC`, `PK-KRS` | **05–12 kt** (Angin tenang)<br>Visibilitas: **CAVOK** ($\ge 10\text{ km}$)<br>QNH: **1008–1016 hPa** | • Arah sirkuit: *Left Traffic* vs *Right Traffic*<br>• Squawk: Tetap `1200` (VFR) |
| **Level 2** | Regional Commuter IFR | ATR 72-600<br>Cessna 208B Grand Caravan | `Wings Air [1800–1899]`<br>`Susi Air [100–299]`<br>`Supergreen [400–499]` | **08–15 kt** (Crosswind $\le 15\text{ kt}$)<br>Visibilitas: 6–10 km<br>QNH: **1006–1018 hPa**<br>Alt: **FL140–FL180** | • Waktu tunda dorong: 2–5 menit<br>• Alasan tunda: traffic apron / inspeksi |
| **Level 3** | Busy Single-Runway Jet | Airbus A320-200<br>Boeing 737-800 NG | `Garuda [300–399]`<br>`Batik [6300–6399]`<br>`Lion Air [700–799]`<br>`Supergreen [500–599]` | **10–20 kt** (Angin aktif)<br>Visibilitas: 5–8 km (Hujan ringan)<br>QNH: **1004–1016 hPa**<br>Alt: **FL240–FL280** | • Callsign trafik depan: *Garuda / Lion / Citilink*<br>• Waktu EAT Holding: +10 s/d +20 min UTC<br>• Kecepatan Flap Asymmetry: **155–165 kt** |
| **Level 4** | Major Hub Multi-Runway | Boeing 777-300ER Heavy<br>Airbus A330-300 Heavy<br>Airbus A320 / B737-800 | `Garuda [100–299] Heavy`<br>`Batik [7000–7199]`<br>`Lion Air [800–899]` | **15–25 kt** (Crosswind basah)<br>Visibilitas: 3–6 km<br>QNH: **1002–1014 hPa**<br>Alt: **FL300–FL380** | • **Callsign Umpan (Bait):** Mirip siswa (selective listening)<br>• Waktu Slot CTOT: +15 s/d +30 min UTC<br>• Restriksi kecepatan: 250 / 210 / 180 / 160 kt |
| **Level 5** | Extreme Terrain & High-Risk Valley | Boeing 737-500 STOL<br>ATR 72-600<br>DHC-6 Twin Otter | `Trigana [200–299]`<br>`Smart [100–199]`<br>`Batik [400–499]`<br>`Asian One [300–399]` | **15–30 kt** (Gusting microburst)<br>Visibilitas: 2–5 km (Kabut lembah)<br>QNH: 1000–1018 hPa (Elevasi tinggi)<br>Alt: **FL170–FL360** | • **Toraja (WAFB):** STOL Turboprop murni<br>• **Papua Decompression:** FL170 (MORA Jayawijaya)<br>• Transmisi VHF Partyline background |

---

## 3. ATURAN MATEMATIKA TRANSPONDER (SQUAWK CODE)
* **Level 1 (VFR):** Tetap `1200` ("one two zero zero").
* **Level 2 s/d 5 (IFR):** Wajib menggunakan bilangan **Oktal 4-digit (digit 0 sampai 7 saja)**:
  * Digit 1: $4 \dots 7$
  * Digit 2: $0 \dots 7$
  * Digit 3: $0 \dots 7$
  * Digit 4: $0 \dots 7$
  * Contoh: `4201`, `5310`, `6704`. Kode darurat terlarang diacak (`7500`, `7600`, `7700`) kecuali pada skenario darurat spesifik.

---

## 4. ATURAN PENENTUAN RUNWAY AKTIF (AERODYNAMICS HEADWIND)
* Arah angin diacak dengan deviasi $\pm 20^\circ$ dari sumbu landasan.
* Sistem menghitung komponen vektor *headwind* ($W_s \cos(\Delta\theta)$) antara runway utama dan runway resiprokalnya (misal: 08 vs 26 di WADY, 09 vs 27 di WADD).
* Runway dengan komponen *headwind* terbesar otomatis terpilih dan mengunci seluruh jalur taksi, holding point, dan fraseologi fase berikutnya.

---

## 5. ARSITEKTUR STATE MACHINE EXAM GENERATOR (LEVEL 1 – 5)

```
[SEED INPUT] ──► [1. PROBABILITY RESOLVER] ──► [2. CRISIS MUTUAL EXCLUSION] ──► [3. DOWNSTREAM BRIDGING]
```

### 1. Level 1 Exam: Linear Circuit Generator
* **Karakter:** **100% Rutin VFR Sirkuit Lokal (0% Anomali).**
* Ujian sirkuit 1 siklus penuh di WADY / WICB / WADE dengan denah visual aerodrome tanpa contek teks.

### 2. Level 2 Exam: Deterministic Single-Point Inserter
* **Karakter:** **100% Anomali Tunggal (0% Normal).**
* Seimbang modulo 4 ($4 \times 25\%$):
  $$\text{Seed} \pmod 4 \Longrightarrow \begin{cases} 
  0 \longrightarrow \text{Pushback Delay} & [25\%] \\ 
  1 \longrightarrow \text{Stop Pushback Immediately} & [25\%] \\ 
  2 \longrightarrow \text{Unable Altitude Profile} & [25\%] \\ 
  3 \longrightarrow \text{Hold Short Mandatory Readback} & [25\%] 
  \end{cases}$$

### 3. Level 3 Exam: Dual-Phase Tactical Composer
* **Karakter:** **100% Kompaun 2-Fase (1 Keberangkatan + 1 Kedatangan).**
* Di Level 3 terdapat 4 skenario keberangkatan dan 4 skenario kedatangan:
  * **Kolam Keberangkatan (Pilih 1 dari 4):**
    1. Runway Backtrack (*Doc 9432 Ch.4.4.2*)
    2. Wake Turbulence Wait (*Doc 4444: Ch.5.8*)
    3. Conditional Line-Up 'Behind' (*Doc 9432 Ch.4.5.7*)
    4. Immediate Take-off or Vacate (*Doc 9432 Ch.4.5.5*)
  * **Kolam Kedatangan (Pilih 1 dari 4):**
    1. Holding Pattern & EAT (*Doc 4444: Ch.5.5*)
    2. Delaying Vector / Orbit 360° (*Doc 9432 Ch.4.6.5*)
    3. Continue Approach on Short Final (*Doc 9432 Ch.4.7.1*)
    4. Flap Asymmetry High Speed (*Doc 9432 Ch.9*)
* **Total Variasi Pasangan Acak:** $4 \times 4 = \mathbf{16\text{ Variasi Pasangan Anti-Patah}}$. Kedua masalah dipisahkan oleh fase jelajah yang tenang sehingga naskah dijamin 100% koheren.

### 4. Level 4 Exam: 2-Stage Captaincy Synchronizer
* **Karakter:** **2-Stage Captaincy Checkride:**
  * **Exam 4A (Spot Check):** High-Speed RTO di kecepatan 110 knot saat take-off roll (2 menit).
  * **Exam 4B (Line Check):** Penerbangan kompaun end-to-end ($3\text{ Ground} \times 4\text{ Air} = \mathbf{12\text{ Variasi}}$).
  * Menguji ketajaman pendengaran selektif (*Callsign Confusion Bait Turn*) dan kepatuhan instan TCAS RA.

### 5. Level 5 Exam: Trajectory-Driven Crisis Branching
* **Karakter:** **100% Kedaruratan Mutlak berbasis 3 Pola Trajektori Nyata (11 Variasi).** Alur tidak dipaksakan 6 fase end-to-end melainkan mengikuti trajektori krisis:
  * **Pola 1 (Immediate Abort):** EFATO Mesin Kanan ➔ Air-Turn-Back ➔ Pendaratan 1 Mesin ➔ Tergelincir Rumput (*Runway Excursion*) ➔ Busa Pemadam ARFF. (Total 8–10 Turn).
  * **Pola 2 (In-Flight Diversion):** Dekompresi Kabin ke FL170 atau MAYDAY FUEL ➔ Potong Rute Langsung ➔ Pendaratan Straight-in Prioritas. ($2 \times 2 = 4\text{ Variasi}$).
  * **Pola 3 (Tactical Recovery):** GPWS Terrain Avoidance / Wind Shear / Pilot Go-Around ➔ Manuver Lolos Mandiri ➔ Re-vectoring ➔ Safe Landing. ($3 \times 2 = 6\text{ Variasi}$).
