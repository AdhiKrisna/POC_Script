# SPESIFIKASI MAPPING & COGNITIVE SCAFFOLDING (LEVEL 1 – 5)

Dokumen ini disusun berdasarkan **MAPPING_SCAFFOLDING.pdf**, **LAMPIRAN_MAPPING_SCAFFOLDING.pdf**, dan keputusan desain *Deliberate Practice* radiotelephony ICAO (Doc 9432, Doc 4444, Doc 9835).

---

## 1. PRINSIP DASAR: ANTI-TELEPROMPTER & COGNITIVE PROGRESSION
Prinsip utama pedagogi HERMES RTF Simulator:
* **Hanya Level 1 yang 100% Prosedur Rutin Murni.** Level 2 s/d 5 pasti menghadapi anomali/krisis operasional pada mode ujian (*Exam Mode*).
* **Anti-Teleprompter:** Layar bukan tempat menyontek kalimat lengkap bahasa Inggris. Bantuan teks dipangkas secara progresif agar taruna membangun *muscle memory* dan refleks bicara mandiri dari ingatan (*mental model*).
* **Script Generator Prompt Rule:** Generator naskah wajib membundel seluruh data state UI/scaffolding khusus per level ke dalam setiap *turn* dialog (`FilledExchange`), bukan sekadar teks gelembung dialog (*speech bubbles*).

---

## 2. MATRIKS ARSITEKTUR SCAFFOLDING (LEVEL 1 – 5)

| Level & Pangkat | Karakter Rute & Bandara | Scaffolding Visual (UI) | Beban Ingatan & Jeda PTT | Karakter Misi Harian | Karakter Exam Mode (Ujian Naik Level) |
|---|---|---|---|---|---|
| **Level 1**<br>Flight Cadet | **3 Bandara Sekolah** (`WADY`, `WICB`, `WADE`)<br>C172, PA-28, DA40 | **4-Slot Data Card**<br>(Token Warna: Stasiun, Callsign, Posisi, Aksi) | 1 elemen per turn<br>**PTT: Uncapped** (Bebas) | 5 Misi Sirkuit Lokal<br>(100% Rutin Murni) | **100% Rutin VFR Sirkuit**<br>(One-shot, visual chart aerodrome) |
| **Level 2**<br>Junior FO | **4 Bandara Regional** (`WAHI`, `WADL`, `WAOO`, `WIPP`)<br>ATR 72-600, C208 | **Cloze Text**<br>(Teks rumpang, angka kritis dikosongkan) | 2 elemen per turn<br>**PTT: ≤ 8s** (*Memory decay*) | 4 Misi P-to-P Regional<br>(4 Anomali Darat/Tanjak) | **100% Anomali Tunggal (4 × 25%)**<br>(Modulo 4: Pushback Delay, Stop, Unable, Hold Short) |
| **Level 3**<br>Senior FO | **6 Bandara Single-Runway** (`WARS`, `WADD`, `WIDD`, `WIPT`, `WARQ`, `WALL`)<br>A320, B737-800 | **Intent Badges**<br>(Kartu Maksud 1 kalimat Bhs Indo, teks Inggris hilang) | 3 elemen bersyarat<br>**PTT: ≤ 5s** | 6 Misi P-to-P Jet Komersial<br>(8 Skenario Taktis ICAO) | **100% Kompaun 2-Fase (4 × 4 = 16 Variasi)**<br>(1 Keberangkatan + 1 Kedatangan; Flap di M-305) |
| **Level 4**<br>Captain | **5 Bandara Hub Metro** (`WIII`, `WARR`, `WAAA`, `WIMM`, `WIHH`)<br>B777, A330, A320 | **Universal Cockpit HUD Strip**<br>(Kondisi fisik pesawat saat ini, Audio-Only) | 3–4 instruksi bertumpuk<br>**PTT: ≤ 3s** | 5 Misi Hub Lintas Pulau<br>(8 Skenario Kompaun Hub) | **2-Stage Captaincy Checkride:**<br>• Exam 4A: Spot Check RTO (2 min)<br>• Exam 4B: Line Check End-to-End ($3 \times 4 = 12$ Variasi) |
| **Level 5**<br>Senior Captain | **5 Bandara Medan Ekstrem** (`WAVV`, `WICC`, `WAFB`, `WABP`, `WALR`)<br>B735 STOL, ATR-72, DHC-6 | **Cockpit HUD + Partyline Chatter**<br>(VHF background 25% ducking 10%) | Respons krisis hidup/mati<br>**PTT: ≤ 3s** (Instan) | 5 Misi Lembah & Tebing Ekstrem<br>(8 Kedaruratan Mutlak) | **100% Kedaruratan Berbasis 3 Trajektori (11 Variasi):**<br>• Pola 1: Abort (EFATO + Excursion)<br>• Pola 2: Diversion (Dekompresi FL170 / MAYDAY FUEL)<br>• Pola 3: Recovery (GPWS / Windshear / Go-Around) |

---

## 3. DETAIL IMPLEMENTASI UI SCAFFOLDING PER LEVEL

### Level 1: Four-Slot Flight Data Card
* **Tujuan Pedagogi:** Menanamkan struktur baku 4 elemen ICAO: `[Stasiun] + [Callsign] + [Posisi] + [Aksi / Permintaan]`, melatih artikulasi fonetik angka per digit, dan menghilangkan *mic fright*.
* **Komponen Layar:**
  1. `SlotBadgeView` (Biru): Nama stasiun tujuan ATC (misal: *Banyuwangi Tower*).
  2. `SlotBadgeView` (Ungu): Tanda panggil pesawat (misal: *Skyfox 12* / *PK-WIC*).
  3. `SlotBadgeView` (Oranye): Posisi aktual pesawat (misal: *Apron Stand 1* / *Holding Point A1 Runway 08*).
  4. `SlotBadgeView` (Hijau): Aksi atau pesan yang diminta (misal: *Radio check 118.1* / *Ready for departure*).
  5. `PhoneticNumbersGuide`: Panduan pelafalan standar penerbangan (WUN, TOO, TREE, FOW-ER, FIFE, SIX, SEV-EN, AIT, NIN-ER, ZE-RO).

### Level 2: Cloze Text (Teks Rumpang)
* **Tujuan Pedagogi:** Melatih pendengaran aktif (*active listening*) untuk menangkap angka kritis yang berubah acak tiap sesi dan mengatasi pembusukan memori kerja (*working memory decay*).
* **Komponen Layar:**
  1. Template kalimat di mana angka penting diganti menjadi kotak kosong `[ ___ ]`.
  2. Indikator slot kritis yang diuji (`[RUNWAY]`, `[ALTITUDE]`, `[QNH]`, `[CALLSIGN]`).
  3. Timer hitung mundur PTT $\le 8\text{ detik}$.

### Level 3: Intent Badges (Kartu Intensi Operasional Bahasa Indonesia)
* **Tujuan Pedagogi:** Teks naskah bahasa Inggris HILANG TOTAL. Siswa dilatih merangkai kalimat radio sendiri di kepala berdasarkan maksud operasional.
* **Komponen Layar:**
  1. Header Intensi: `🎯 INTENSI OPERASIONAL`.
  2. Kalimat Intensi (1 kalimat Bahasa Indonesia padat), misal: *"Masuk dan tunggu di Runway 25L di belakang pesawat yang sedang mendarat."*
  3. Catatan Kritis: misal *"Wajib sebut kata 'BEHIND' di awal dan akhir readback."*
  4. Aturan ICAO: sitasi pasal Doc 9432 / Doc 4444.
  5. Timer hitung mundur PTT $\le 5\text{ detik}$.

### Level 4: Universal Cockpit HUD Strip (Audio-Only)
* **Tujuan Pedagogi:** Mensimulasikan kokpit jet komersial metropolitan padat. Tidak ada bantuan teks naskah. Siswa hanya mengandalkan instrumen pesawat aktual dan pendengaran selektif (*selective listening*).
* **Komponen Layar:**
  1. Avionics Strip: `HDG` (Heading), `ALT` (Altitude), `SPD` (Airspeed), `XPDR` (Squawk Oktal), `COM1` (Frekuensi aktif), `FIX` (Waypoint).
  2. *Callsign Confusion Bait Alert:* Peringatan saat ATC memanggil pesawat lain dengan nomor identik. Siswa **wajib diam / TIDAK menekan PTT** selama 4 detik.
  3. Timer batas bicara PTT $\le 3\text{ detik}$.

### Level 5: Extreme Mountain HUD + Partyline Audio Chatter
* **Tujuan Pedagogi:** Melatih taruna menghadapi ruang udara ekstrem tanpa radar (*non-radar procedural*) dan memecah kepatuhan buta pada kontroler (*Authority Bias Breaker*).
* **Komponen Layar:**
  1. Mountain Avionics Strip (elevasi tinggi, medan pegunungan).
  2. Indikator *Partyline Chatter* VHF aktif (volume 25%, auto-ducking ke 10% saat transmisi berlangsung).
  3. *Authority Bias Breaker Alert:* Banner peringatan keselamatan saat instruksi ATC keliru (misal: diarahkan menabrak tebing Gunung Malabar). Siswa wajib membantah tegas dengan frasa baku *"UNABLE due terrain"*.
  4. Timer batas bicara PTT $\le 3\text{ detik}$ (instan).
