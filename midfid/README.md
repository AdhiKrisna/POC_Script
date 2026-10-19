# HERMES RTF SIMULATOR: UI/UX WIREFRAME & PROTOTYPE SPECIFICATION
### Mid-Fidelity & High-Fidelity Design Documentation (Level 1–5 Scaffolding)
**Apple Developer Academy Final Challenge — Team Abang Tukang Bakso**

---

## 1. Executive Summary & Visi Desain

Dokumen ini mendefinisikan sistem antarmuka pengguna (*User Interface*) dan alur pengalaman pengguna (*User Experience*) untuk simulator **HERMES Radiotelephony (RTF)** berdasarkan wireframe sketsa resmi:
* **Screen 1: Preparation Context** (Briefing data penerbangan sebelum simulasi).
* **Screen 2: Interactive Simulation View** (Area transmisi radio suara interaktif dengan *faded scaffolding* Level 1 s/d Level 5).
* **Screen 3: Overall Summary & Diagnostic** (Evaluasi kuantitatif, analisis KPI, dan sitasi koreksi fraseologi ICAO).

Prototipe interaktif dapat langsung diakses di berkas:
👉 **`midfid/index.html`** (Dilengkapi *toggle* antara mode **Mid-Fi Wireframe** bergaya sketsa pensil dan **High-Fi Avionics** bergaya *cockpit dark ambient*).

---

## 2. Struktur Alur 3-Layar (Three-Screen User Journey)

```
┌───────────────────────────┐      ┌───────────────────────────┐      ┌───────────────────────────┐
│         SCREEN 1          │      │         SCREEN 2          │      │         SCREEN 3          │
│    Preparation Context    │ ───► │  Interactive Simulation   │ ───► │      Overall Summary      │
│ • Operational Flight Plan │      │ • Dual-VHF Radio Panel    │      │ • Circular Score Gauge    │
│ • Departure ATIS          │      │ • Dynamic Scaffolding     │      │ • KPI (Filler, PTT, Acc)  │
│ • Arrival ATIS            │      │ • Speech-To-Text Box      │      │ • Cited Error Diagnostic  │
│ • Injected Contingency    │      │ • Push-To-Talk Button     │      │ • Next Level / Retry CTA  │
└───────────────────────────┘      └───────────────────────────┘      └───────────────────────────┘
```

---

## 3. Matriks Scaffolding Berjenjang (Level 1 – 5)

Sesuai prinsip *Cognitive Load Theory (Sweller)* dan *ICAO Doc 9835*, antarmuka secara bertahap memangkas bantuan teks visual (*faded scaffolding*) agar taruna membangun *muscle memory* dan refleks bicara mandiri:

| Level & Pangkat | Karakter Ruang Udara | Scaffolding Visual di Screen 2 | Mode Transmisi | Batas Jeda PTT |
|---|---|---|---|---|
| **View Lv. 1**<br>Flight Cadet | **Sirkuit VFR Lokal**<br>(WADY, WICB, WADE) | **4-Slot Data Card + Verbatim Prompt**<br>• 4 Elemen: Stasiun, Callsign, Posisi, Aksi<br>• Teks contekan respons ATC lengkap | Visual + Teks Lengkap | **Uncapped**<br>(Bebas tanpa batas) |
| **View Lv. 2**<br>Junior FO | **Regional IFR Commuter**<br>(WAHI, WADL, WAOO, WIPP) | **Cloze Masked Text (Teks Rumpang)**<br>• Kalimat dasar tersedia, slot angka kritis dikosongkan `[ ___ ]`<br>• Melatih *working memory* tangkap angka | Teks Rumpang | **$\le 8$ detik**<br>(*Memory decay*) |
| **View Lv. 3**<br>Senior FO | **Busy Single-Runway Jet**<br>(WARS, WADD, WIDD, WIPT) | **Objective / Intention Card (Bahasa Indonesia)**<br>• Teks naskah bahasa Inggris dihilangkan total<br>• Hanya menyajikan kartu intensi operasional | Intensi 1 Kalimat | **$\le 5$ detik** |
| **View Lv. 4**<br>Captain | **Metropolitan Hub Multi-RWY**<br>(WIII, WARR, WAAA, WIMM) | **Cockpit Scratchpad HUD (Audio-First)**<br>• Zero visual verbal hints (100% audio RTF)<br>• Scratchpad telemetri: HDG, ALT, SPD, LOC, NAV | Audio Murni + Scratchpad | **$\le 3$ detik** |
| **View Lv. 5**<br>Senior Captain | **Extreme Mountain & Valley**<br>(WAVV, WICC, WAFB, WABP) | **High-Risk Valley HUD + GPWS Warning Alert**<br>• Peringatan bahaya visual tebing `⚠️ PULL UP!`<br>• Radio VHF partyline background noise | Audio + Alert Banner | **$\le 3$ detik**<br>(Instan) |

---

## 4. Rincian Komponen Layar (Detailed Screen Breakdown)

### 1. Screen 1: Preparation Context
* **Tujuan Pedagogis:** Membangun *situational awareness* taruna sebelum menekan tombol PTT pertama kali.
* **Komponen:**
  1. **Operational Flight Plan (OFP):** Callsign, Aircraft Type, Departure Aerodrome, Stand Parkir, Destination Aerodrome, Planned Cruising, Initial Altitude, Assigned Routing (SID & STAR), Assigned Squawk.
  2. **Departure ATIS:** Pengenal stasiun, Huruf ATIS (`Information November`), Runway aktif, Angin permukaan, Jarak pandang (*CAVOK*), Tekanan Altimeter (*QNH 1011 hPa*).
  3. **Injected Contingency:** Ringkasan kondisi khusus yang akan dihadapi penerbangan (misal: *Pushback Delay karena pesawat lain melintas*).
  4. **Goal Badge:** Penjelasan tujuan pembelajaran fase.
  5. **CTA Button:** Tombol **"START MISSION ➔"**.

---

### 2. Screen 2: Interactive Simulation View
* **Tujuan Pedagogis:** Area latihan berbicara langsung menirukan kokpit pesawat sesungguhnya.
* **Komponen:**
  1. **Dual-Frequency Radio Avionics Panel (VHF COMM):**
     * Menampilkan saluran **ACTIVE** (misal: `RX 121.90 TOWER`) dan **STANDBY** (misal: `118.70 GROUND`).
     * Dilengkapi tombol **Transfer Swap (`⇅`)** yang dapat diklik untuk membalik frekuensi secara instan.
  2. **Dynamic Scaffolding Workspace:** Berubah secara otomatis mengikuti Level 1 s/d 5.
  3. **Speech-To-Text (STT) Transcription Box:**
     * Menampilkan placeholder `"Your Answer will be Showed here"`.
     * Saat pilot berbicara, muncul visualisasi gelombang suara (*waveform animation*) disusul hasil transkripsi teks otomatis.
  4. **Push-To-Talk (PTT) Button:**
     * Tombol lingkaran besar di area jangkauan jempol bawah layar.
     * Mengadopsi mekanisme *press-and-hold* atau *tap-to-talk* dengan umpan balik visual dan haptik.
  5. **Action Button:** Tombol **"EVALUATE & SUMMARY ➔"**.

---

### 3. Screen 3: Overall Summary & Diagnostic
* **Tujuan Pedagogis:** Memberikan umpan balik obyektif berbasis rubrik kompetensi ICAO Doc 9835.
* **Komponen:**
  1. **Circular Score Gauge:** Skor persentase (misal: `98%`), status evaluasi (`"Great Job!"`), dan kalimat motivasi.
  2. **Performance Metrics (KPI):**
     * `Filler words : 0 times` *(Lancar)*.
     * `Clearability phraseology : 98%` *(Clear)*.
     * `PTT Reflex : 315 ms` *(Responsive)*.
  3. **Review Diagnostic List:**
     * Kartu kesalahan spesifik (misal: penggunaan kata terlarang *"ROGER"* pada izin pushback).
     * Tautan sitasi regulasi resmi (misal: `Reference : ICAO Doc 4444 §8.3 & Doc 9432 §2.6`).
     * Kartu kelalaian (misal: tidak menyebutkan *Callsign* di akhir transmisi).
  4. **Action Button:** Tombol **"NEXT / RETRY MISSION ➔"**.

---

## 5. Token Desain: Mid-Fidelity vs High-Fidelity

| Parameter | Mode Mid-Fidelity Wireframe | Mode High-Fidelity Avionics Dark |
|---|---|---|
| **Latar Belakang** | Kertas bergrid titik (`#F7F7F5`, dot `#D6D6D0`) | Deep Obsidian Black (`#07090E`, glowing cyan dots) |
| **Gaya Garis / Border** | Garis pensil tegas 1.5–2px (`#2C3038`), shadow kartun hitam | Glassmorphic border semi-transparan (`rgba(255,255,255,0.12)`) |
| **Warna Aksen Aktif** | Biru arsitektur (`#2F54EB`), Oranye penanda (`#FA8C16`) | Neon Phosphor Green (`#00FF88`), Cobalt Cyan (`#00E5FF`) |
| **Panel Radio COMM** | Kotak putih dengan garis batas wireframe | Linear Gradient Dark (`#121824` ke `#0B0E14`), neon glow |
| **Tombol PTT** | Lingkaran putih border tebal hitam | Radial gradient dark metalik dengan ambient spotlight glow |
| **Tipografi** | Monospace teknis (`SF Mono`) + System Sans | SF Pro Rounded + SF Mono dengan text-shadow halus |

---

## 6. Cara Menguji Prototipe
1. Buka berkas **`midfid/index.html`** di peramban web (Safari, Chrome, atau Preview Pane).
2. Gunakan tombol di toolbar atas untuk berpindah antara:
   * **✏️ Mid-Fi Wireframe** dan **✨ High-Fi Avionics**.
   * Layar **1. Prep Context**, **2. Simulation**, dan **3. Summary**.
3. Di Layar Simulasi, klik pil **Lv. 1 s/d Lv. 5** untuk melihat perubahan instan format scaffolding.
4. Klik tombol transfer frekuensi `⇅` untuk menguji animasi pergantian radio.
5. Klik dan tahan tombol **Push To Talk** untuk memicu animasi gelombang suara dan kemunculan teks transkripsi STT.
6. Di Layar Summary, klik tautan sitasi regulasi untuk membuka modal penjelasan pasal larangan kata *"ROGER"*.

---
*Dibuat untuk Apple Developer Academy Final Challenge — Team Abang Tukang Bakso.*
