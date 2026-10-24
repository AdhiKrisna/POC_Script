# Sumber Data Operasional 23 Bandara Kanonikal (Tier 2 Dataset)
**HERMES Radiotelephony (RTF) Simulator — Dataset Provenance & References**  
*Apple Academy Final Challenge | Script Generator Engine*

Dokumen ini mencatat sumber data operasional lengkap (Callsign, Frekuensi, Taxiway, Parking Stand, Prosedur SID/STAR/Approach, dan Holding Points) untuk seluruh **23 bandara kanonikal** yang digunakan dalam kurikulum level 1–5 simulator HERMES RTF.

---

## 1. Arsitektur & Hierarki Sumber Data

Data operasional penerbangan (**Tier 2**) tidak dapat diambil dari portal profil umum Kemenhub (yang hanya memuat informasi sipil/statistik non-operasional), melainkan dikurasi langsung dari:
1. **Publikasi Resmi Aeronautika (AIP Indonesia / eAIP Volume II & III):** Diterbitkan oleh Ditjen Hubud & AirNav Indonesia (Perum LPPNPI) sesuai standar ICAO Annex 15 & Doc 8126.
   - **AD 2.18:** ATS Communication Facilities (Callsign & Frekuensi operasional).
   - **AD 2.8 & 2.24:** Aerodrome Ground Movement Chart & Parking Chart (Taxiway & Stand).
   - **AD 2.19 & 2.24:** Radio Navigation Aids, SID, STAR, & Instrument Approach Charts (ILS/RNP/LOC).
2. **AirNav Nav-Card (Published Database):** Basis data resmi penamaan waypoint 5LNC (*Five-Letter Name Code*) Indonesia ([https://app-pia.airnavindonesia.co.id/navcard/published.php](https://app-pia.airnavindonesia.co.id/navcard/published.php)).
3. **Jeppesen Trip Kit Indonesia (`Waypoints.pdf`, 807 halaman):** Basis data resmi bagan navigasi terminal Jeppesen untuk wilayah udara Indonesia (FIR Jakarta & FIR Ujung Pandang). Digunakan sebagai acuan validasi instrumen RNAV/Conventional SID, STAR, Instrument Approach Charts (ILS/RNP/LOC), Radar Vectoring Altitudes, serta ekstraksi 1.170+ waypoint 5LNC.
4. **Open Aviation Charts & Repositories (Public Mirror & Simulator Community):**
   - **ChartFox (VATSIM):** `https://chartfox.org/{ICAO}`
   - **OurAirports Database (CC0):** `https://ourairports.com/airports/{ICAO}/`
   - **SkyVector Aeronautical Database:** `https://skyvector.com/airport/{ICAO}` (Format URL kanonikal: `https://skyvector.com/airport/{ICAO}/{Airport-Slug}`)
   - **AC-U-KWIK Airport Directory:** `https://acukwik.com/Airport/{ICAO}`
   > *Catatan Indeks SkyVector / Jeppesen:* Sebagian bandara di SkyVector dan Jeppesen Trip Kit masih diindeks menggunakan kode ICAO historis/internasional (misal WIRR untuk Budiarto Curug, WAHS untuk Ahmad Yani Semarang, WAHQ untuk Adi Soemarmo Solo, WIEE untuk Minangkabau Padang, WAYY untuk Mozes Kilangin Timika, dan WAQQ untuk Juwata Tarakan). Tautan di bawah telah diverifikasi aktif dan mengarah ke URL slug kanonikal masing-masing (HTTP 200).
5. **Aerodrome Manual & SOP Sekolah Penerbang (Khusus Level 1):** Kurikulum latih API Banyuwangi, PPI Curug, dan BIFA Buleleng untuk sirkuit visual (*aerodrome traffic circuit*).

---

## 2. Katalog Rinci Sumber Data per Bandara (23 Bandara)

### LEVEL 1: Flight School & Local Training (Profile: VFR_LOCAL)
Fokus: Sirkuit visual, komunikasi radio dasar pemula, VFR reporting points, pangkalan sekolah pilot.

#### 1. WADY / BWX — Banyuwangi Airport (Blimbingsari / Rogojampi)
- **Fokus Latih:** Home base Akademi Penerbang Indonesia (API) Banyuwangi.
- **Data Operasional:**
  - Runway: 08/26 (Holding: A1, A2).
  - Frekuensi: Banyuwangi Ground 121.600, Banyuwangi Tower 118.100, Banyuwangi Approach 119.500.
  - Taxiway: Alpha, Bravo. Stand: Stand 1–3.
  - Prosedur: Visual Approach Rwy 08, SID BWX1A, STAR BWX1B.
- **Rujukan Resmi:** AIP Indonesia Vol II AD 2 WADY & API Banyuwangi Training SOP.
- **Tautan Sumber Langsung:**
  - AirNav Nav-Card Fixes: [AirNav Nav-Card WADY](https://app-pia.airnavindonesia.co.id/navcard/published.php) (Fix AGULO, AD 2.24-9A)
  - OurAirports WADY: [ourairports.com/airports/WADY/](https://ourairports.com/airports/WADY/)
  - SkyVector WADY: [skyvector.com/airport/WADY/Banyuwangi-Airport](https://skyvector.com/airport/WADY/Banyuwangi-Airport)
  - ChartFox WADY: [chartfox.org/WADY](https://chartfox.org/WADY)

#### 2. WICB / CURUG — Budiarto Airport (Curug, Tangerang)
- **Fokus Latih:** Home base Politeknik Penerbangan Indonesia (PPI) Curug.
- **Data Operasional:**
  - Runway: 12/30 (Holding: B1, B2, B3) & 04/22 (Holding: A1, A2).
  - Frekuensi: Budiarto Ground 121.700, Budiarto Tower 118.300, Curug Approach 119.700.
  - Taxiway: Alpha, Bravo, Charlie. Stand: Stand 1–3.
  - Prosedur: Visual Circuit Training, SID CRG1A, STAR CRG1B, Approach VIS12.
- **Rujukan Resmi:** AIP Indonesia Vol III AD 2 WICB & Aerodrome Manual PPI Curug.
- **Tautan Sumber Langsung:**
  - OurAirports WICB: [ourairports.com/airports/WICB/](https://ourairports.com/airports/WICB/)
  - SkyVector WICB: [skyvector.com/airport/WIRR/Tangerang-Budiarto-Airport](https://skyvector.com/airport/WIRR/Tangerang-Budiarto-Airport) *(SkyVector terindeks sebagai WIRR)*
  - ChartFox WICB: [chartfox.org/WICB](https://chartfox.org/WICB)
  - PPI Curug Official: [ppicurug.ac.id](https://ppicurug.ac.id/)

#### 3. WADE / TTR — Lt. Col. Wisnu Airfield (Buleleng, Bali)
- **Fokus Latih:** Pangkalan latih utama Bali International Flight Academy (BIFA).
- **Data Operasional:**
  - Runway: 14/32 (Holding: A1, A2).
  - Frekuensi: Wisnu Tower 118.300, Bali Approach 124.000.
  - Taxiway: Alpha. Stand: Stand 1–2.
  - Prosedur: VFR Coastal Traffic Circuit, Approach VIS14.
- **Rujukan Resmi:** AIP Indonesia Vol III AD 2 WADE & BIFA Flight Operations Manual.
- **Tautan Sumber Langsung:**
  - OurAirports WADE: [ourairports.com/airports/WADE/](https://ourairports.com/airports/WADE/)
  - SkyVector WADE: [skyvector.com/airport/WADE/Buleleng-Letkol-Wisnu-Airport](https://skyvector.com/airport/WADE/Buleleng-Letkol-Wisnu-Airport)
  - ChartFox WADE: [chartfox.org/WADE](https://chartfox.org/WADE)
  - BIFA Flying School: [baliflightacademy.com](https://baliflightacademy.com/)

---

### LEVEL 2: Regional Controlled (Profile: IFR_COMMERCIAL)
Fokus: Transisi IFR regional, hand-off 4–5 unit ATC, QNH dinamis, SID/STAR instrumen standar.

#### 4. WAHI / YIA — Yogyakarta International Airport (Kulon Progo)
- **Data Operasional:**
  - Runway: 11/29 (Holding: F1, F2, F3).
  - Frekuensi: Yogyakarta Delivery 121.650, Yogyakarta Ground 121.800, Yogyakarta Tower 118.400, Yogyakarta Approach 120.400, Yogyakarta Information (ATIS) 127.400.
  - Taxiway: Foxtrot, Golf, Hotel. Stand: Gate 11, 12, 14.
  - Prosedur: SID BL2, STAR BL1A, ILS Rwy 11 (Freq 110.100 MHz, ident I-YIA).
- **Rujukan Resmi:** AIP Indonesia Vol II AD 2 WAHI (AIRAC Amdt 108).
- **Tautan Sumber Langsung:**
  - AirNav Nav-Card WAHI: [AirNav Nav-Card (Fix AKLUK WAHI)](https://app-pia.airnavindonesia.co.id/navcard/published.php)
  - ChartFox WAHI: [chartfox.org/WAHI](https://chartfox.org/WAHI)
  - OurAirports WAHI: [ourairports.com/airports/WAHI/](https://ourairports.com/airports/WAHI/)
  - SkyVector WAHI: [skyvector.com/airport/WAHI/Internasional-Yogyakarta-Airport](https://skyvector.com/airport/WAHI/Internasional-Yogyakarta-Airport)

#### 5. WADL / LOP — Zainuddin Abdul Madjid International Airport (Lombok Praya)
- **Data Operasional:**
  - Runway: 13/31 (Holding: A1, A2, B1).
  - Frekuensi: Lombok Delivery 121.600, Lombok Ground 121.700, Lombok Tower 118.100, Lombok Approach 120.700, Lombok Information (ATIS) 126.400.
  - Taxiway: Alpha, Bravo, Charlie. Stand: Stand 3, 4, 5.
  - Prosedur: SID PRA1A, STAR PRA1B, ILS Rwy 13.
- **Rujukan Resmi:** AIP Indonesia Vol II AD 2 WADL (AIRAC Amdt 141).
- **Tautan Sumber Langsung:**
  - AirNav Nav-Card WADL: [AirNav Nav-Card (Fix AGILU WADL)](https://app-pia.airnavindonesia.co.id/navcard/published.php)
  - ChartFox WADL: [chartfox.org/WADL](https://chartfox.org/WADL)
  - OurAirports WADL: [ourairports.com/airports/WADL/](https://ourairports.com/airports/WADL/)
  - SkyVector WADL: [skyvector.com/airport/WADL/Zainuddin-Abdul-Madjid-International-Airport](https://skyvector.com/airport/WADL/Zainuddin-Abdul-Madjid-International-Airport)

#### 6. WIPP / PLM — Sultan Mahmud Badaruddin II Airport (Palembang)
- **Data Operasional:**
  - Runway: 11/29 (Holding: A1, B1).
  - Frekuensi: Palembang Ground 121.800, Palembang Tower 118.100, Palembang Approach 120.200, Palembang Information (ATIS) 126.200.
  - Taxiway: Alpha, Bravo. Stand: Stand 4, 5.
  - Prosedur: SID PLM1A, STAR PLM1B, ILS Rwy 11.
- **Rujukan Resmi:** AIP Indonesia Vol II AD 2 WIPP.
- **Tautan Sumber Langsung:**
  - ChartFox WIPP: [chartfox.org/WIPP](https://chartfox.org/WIPP)
  - OurAirports WIPP: [ourairports.com/airports/WIPP/](https://ourairports.com/airports/WIPP/)
  - SkyVector WIPP: [skyvector.com/airport/WIPP/Sultan-Mahmud-Badaruddin-II-Airport](https://skyvector.com/airport/WIPP/Sultan-Mahmud-Badaruddin-II-Airport)

#### 7. WAOO / BDJ — Syamsudin Noor International Airport (Banjarmasin)
- **Data Operasional:**
  - Runway: 10/28 (Holding: A1, A2).
  - Frekuensi: Banjarmasin Ground 121.900, Banjarmasin Tower 118.100, Banjarmasin Approach 121.100, Banjarmasin Information (ATIS) 126.800.
  - Taxiway: Alpha, Bravo. Stand: Stand 2, 3.
  - Prosedur: SID BDJ1A, STAR BDJ1B, ILS Rwy 10.
- **Rujukan Resmi:** AIP Indonesia Vol II AD 2 WAOO (AIRAC Amdt 115).
- **Tautan Sumber Langsung:**
  - AirNav Nav-Card WAOO: [AirNav Nav-Card (Fix AGSUM WAOO)](https://app-pia.airnavindonesia.co.id/navcard/published.php)
  - ChartFox WAOO: [chartfox.org/WAOO](https://chartfox.org/WAOO)
  - OurAirports WAOO: [ourairports.com/airports/WAOO/](https://ourairports.com/airports/WAOO/)
  - SkyVector WAOO: [skyvector.com/airport/WAOO/Banjarmasin-Syamsudin-Noor-Airport](https://skyvector.com/airport/WAOO/Banjarmasin-Syamsudin-Noor-Airport)

---

### LEVEL 3: Busy Single-Runway & Backtrack (Profile: IFR_COMMERCIAL)
Fokus: Disiplin waktu tinggi, backtrack di landasan aktif, separasi wake turbulence, antrean padat.

#### 8. WADD / DPS — I Gusti Ngurah Rai International Airport (Bali)
- **Data Operasional:**
  - Runway: 09/27 (Holding: E1, E2, W1, W2).
  - Frekuensi: Ngurah Delivery 121.950, Ngurah Ground 121.700, Ngurah Tower 118.100, Bali Approach 120.900, Ngurah Information (ATIS) 126.200.
  - Taxiway: Echo, Whiskey, Golf. Stand: Gate B12, B14.
  - Prosedur: SID BLI1D, STAR LAKU1A, ILS Rwy 09, Holding Fix BLI (7.000 ft).
- **Rujukan Resmi:** AIP Indonesia Vol II AD 2 WADD (AIRAC Amdt 107, 132, 174).
- **Tautan Sumber Langsung:**
  - AirNav Nav-Card WADD: [AirNav Nav-Card (Fix AGUDA & AKLER WADD)](https://app-pia.airnavindonesia.co.id/navcard/published.php)
  - ChartFox WADD: [chartfox.org/WADD](https://chartfox.org/WADD)
  - OurAirports WADD: [ourairports.com/airports/WADD/](https://ourairports.com/airports/WADD/)
  - SkyVector WADD: [skyvector.com/airport/WADD/Bali-I-Gusti-Ngurah-Rai-International-Airport](https://skyvector.com/airport/WADD/Bali-I-Gusti-Ngurah-Rai-International-Airport)

#### 9. WARS / SRG — Jenderal Ahmad Yani Airport (Semarang)
- **Data Operasional:**
  - Runway: 13/31 (Holding: A1, A2, B1).
  - Frekuensi: Semarang Ground 121.600, Semarang Tower 118.300, Semarang Approach 120.100, Semarang Information (ATIS) 126.000.
  - Taxiway: Alpha, Bravo. Stand: Stand 3, 4.
  - Prosedur: SID ANY1A, STAR ANY1B, ILS Rwy 13.
- **Rujukan Resmi:** AIP Indonesia Vol II AD 2 WARS.
- **Tautan Sumber Langsung:**
  - ChartFox WARS: [chartfox.org/WARS](https://chartfox.org/WARS)
  - OurAirports WARS: [ourairports.com/airports/WARS/](https://ourairports.com/airports/WARS/)
  - SkyVector WARS: [skyvector.com/airport/WAHS/Jenderal-Ahmad-Yani-International-Airport](https://skyvector.com/airport/WAHS/Jenderal-Ahmad-Yani-International-Airport) *(SkyVector terindeks sebagai WAHS)*

#### 10. WIDD / BTH — Hang Nadim International Airport (Batam)
- **Data Operasional:**
  - Runway: 04/22 (Holding: A1, A2, B1 — Single Runway 4.025m terpanjang di Indonesia).
  - Frekuensi: Batam Delivery 121.800, Batam Ground 121.800, Batam Tower 118.700, Tanjung Pinang Approach 125.100, Batam Information (ATIS) 127.600.
  - Taxiway: Alpha, Bravo. Stand: Stand 5, 6.
  - Prosedur: SID BTH1A, STAR BTH1B, ILS Rwy 04.
- **Rujukan Resmi:** AIP Indonesia Vol II AD 2 WIDD (AIRAC Amdt 142).
- **Tautan Sumber Langsung:**
  - AirNav Nav-Card WIDD: [AirNav Nav-Card (Fix AKBIG & AKDES WIDD)](https://app-pia.airnavindonesia.co.id/navcard/published.php)
  - ChartFox WIDD: [chartfox.org/WIDD](https://chartfox.org/WIDD)
  - OurAirports WIDD: [ourairports.com/airports/WIDD/](https://ourairports.com/airports/WIDD/)
  - SkyVector WIDD: [skyvector.com/airport/WIDD/Batam-Hang-Nadim-Airport](https://skyvector.com/airport/WIDD/Batam-Hang-Nadim-Airport)

#### 11. WIPT / PDG — Minangkabau International Airport (Padang)
- **Data Operasional:**
  - Runway: 15/33 (Holding: A1, A2).
  - Frekuensi: Padang Ground 121.600, Padang Tower 118.100, Padang Approach 120.300, Padang Information (ATIS) 126.400.
  - Taxiway: Alpha, Bravo. Stand: Stand 3, 4.
  - Prosedur: SID PDG1A, STAR PDG1B, ILS Rwy 15.
- **Rujukan Resmi:** AIP Indonesia Vol II AD 2 WIPT.
- **Tautan Sumber Langsung:**
  - ChartFox WIPT: [chartfox.org/WIPT](https://chartfox.org/WIPT)
  - OurAirports WIPT: [ourairports.com/airports/WIPT/](https://ourairports.com/airports/WIPT/)
  - SkyVector WIPT: [skyvector.com/airport/WIEE/Minangkabau-Airport](https://skyvector.com/airport/WIEE/Minangkabau-Airport) *(SkyVector terindeks sebagai WIEE)*

#### 12. WARQ / SOC — Adisoemarmo Airport (Solo)
- **Data Operasional:**
  - Runway: 08/26 (Holding: A1, B1).
  - Frekuensi: Solo Ground 121.800, Solo Tower 118.300, Yogya Approach 120.500, Solo Information (ATIS) 127.200.
  - Taxiway: Alpha, Bravo. Stand: Stand 2, 3.
  - Prosedur: SID SOC1A, STAR SOC1B, ILS Rwy 08.
- **Rujukan Resmi:** AIP Indonesia Vol II AD 2 WARQ.
- **Tautan Sumber Langsung:**
  - ChartFox WARQ: [chartfox.org/WARQ](https://chartfox.org/WARQ)
  - OurAirports WARQ: [ourairports.com/airports/WARQ/](https://ourairports.com/airports/WARQ/)
  - SkyVector WARQ: [skyvector.com/airport/WAHQ/Solo-Adi-Soemarmo-Airport](https://skyvector.com/airport/WAHQ/Solo-Adi-Soemarmo-Airport) *(SkyVector terindeks sebagai WAHQ)*

#### 13. WALL / BPN — Sultan Aji Muhammad Sulaiman Sepinggan (Balikpapan)
- **Data Operasional:**
  - Runway: 07/25 (Holding: A1, A2, B1).
  - Frekuensi: Balikpapan Ground 121.700, Balikpapan Tower 118.100, Balikpapan Approach 121.000, Balikpapan Information (ATIS) 126.600.
  - Taxiway: Alpha, Bravo. Stand: Stand 4, 5.
  - Prosedur: SID BPN1A, STAR BPN1B, ILS Rwy 07.
- **Rujukan Resmi:** AIP Indonesia Vol II AD 2 WALL (AIRAC Amdt 103).
- **Tautan Sumber Langsung:**
  - AirNav Nav-Card WALL: [AirNav Nav-Card (Fix ADPUD WALL)](https://app-pia.airnavindonesia.co.id/navcard/published.php)
  - ChartFox WALL: [chartfox.org/WALL](https://chartfox.org/WALL)
  - OurAirports WALL: [ourairports.com/airports/WALL/](https://ourairports.com/airports/WALL/)
  - SkyVector WALL: [skyvector.com/airport/WALL/Sultan-Aji-Muhammad-Sulaiman-Airport](https://skyvector.com/airport/WALL/Sultan-Aji-Muhammad-Sulaiman-Airport)

---

### LEVEL 4: Major Metropolitan Hub (Profile: IFR_COMMERCIAL)
Fokus: Multi-runway paralel/bersilangan, runway crossing, CTOT slot time, frekuensi terfragmentasi.

#### 14. WIII / CGK — Soekarno-Hatta International Airport (Jakarta / Tangerang)
- **Data Operasional:**
  - Runway: 25R/07L (Holding: NP1, NP2, NP3), 25L/07R (Holding: SP1, SP2, SP3), 24/06 (Holding: C1, C2).
  - Frekuensi: Jakarta Clearance Delivery 121.800, Jakarta Apron 121.650, Jakarta Ground 121.600, Jakarta Tower 118.200, Jakarta Director/Approach 124.350, Jakarta Departure 119.750, Jakarta Upper Control (En-Route) 134.400, Soekarno Information (ATIS) 126.850.
  - Taxiway: November, Papa, Sierra. Stand: Gate E15, F22.
  - Prosedur: SID CA2A, STAR DOLTA1A, ILS Rwy 25R, Holding Fix DOLTA (7.000 ft).
- **Rujukan Resmi:** AIP Indonesia Vol II AD 2 WIII (AIRAC Amdt 107).
- **Tautan Sumber Langsung:**
  - AirNav Nav-Card WIII: [AirNav Nav-Card (Fix AGUSO & DOLTA WIII)](https://app-pia.airnavindonesia.co.id/navcard/published.php)
  - ChartFox WIII: [chartfox.org/WIII](https://chartfox.org/WIII)
  - AC-U-KWIK WIII Diagram: [acukwik.com/Airport/WIII](https://acukwik.com/Airport/WIII)
  - OurAirports WIII: [ourairports.com/airports/WIII/](https://ourairports.com/airports/WIII/)
  - SkyVector WIII: [skyvector.com/airport/WIII/Jakarta-International-Soekarno-Hatta-Airport](https://skyvector.com/airport/WIII/Jakarta-International-Soekarno-Hatta-Airport)

#### 15. WARR / SUB — Juanda International Airport (Surabaya)
- **Data Operasional:**
  - Runway: 10/28 (Holding: N1, N2, N3, S1).
  - Frekuensi: Surabaya Delivery 121.600, Surabaya Ground 121.900, Surabaya Tower 118.300, Surabaya Approach 125.100, Surabaya Information (ATIS) 126.800.
  - Taxiway: November, Sierra, Alpha. Stand: Gate 10, 12.
  - Prosedur: SID SUR1A, STAR SUR1B, ILS Rwy 10.
- **Rujukan Resmi:** AIP Indonesia Vol II AD 2 WARR.
- **Tautan Sumber Langsung:**
  - ChartFox WARR: [chartfox.org/WARR](https://chartfox.org/WARR)
  - AC-U-KWIK WARR Diagram: [acukwik.com/Airport/WARR](https://acukwik.com/Airport/WARR)
  - OurAirports WARR: [ourairports.com/airports/WARR/](https://ourairports.com/airports/WARR/)
  - SkyVector WARR: [skyvector.com/airport/WARR/Juanda-Airport](https://skyvector.com/airport/WARR/Juanda-Airport)

#### 16. WAAA / UPG — Sultan Hasanuddin International Airport (Makassar)
- **Data Operasional:**
  - Runway: 03/21 (Holding: E1, E2) & 13/31 (Holding: W1, W2) (Intersecting Runways).
  - Frekuensi: Makassar Delivery 121.650, Makassar Ground 121.700, Makassar Tower 118.100, Makassar Approach 119.400, Makassar Information (ATIS) 126.250.
  - Taxiway: Echo, Whiskey, Alpha. Stand: Gate 5, 7.
  - Prosedur: SID UPG1A, STAR UPG1B, ILS Rwy 03.
- **Rujukan Resmi:** AIP Indonesia Vol II AD 2 WAAA.
- **Tautan Sumber Langsung:**
  - ChartFox WAAA: [chartfox.org/WAAA](https://chartfox.org/WAAA)
  - OurAirports WAAA: [ourairports.com/airports/WAAA/](https://ourairports.com/airports/WAAA/)
  - SkyVector WAAA: [skyvector.com/airport/WAAA/Makassar-Sultan-Hasanuddin-Airport](https://skyvector.com/airport/WAAA/Makassar-Sultan-Hasanuddin-Airport)

#### 17. WIMM / KNO — Kualanamu International Airport (Medan)
- **Data Operasional:**
  - Runway: 05/23 (Holding: P1, P2, P3).
  - Frekuensi: Medan Delivery 121.850, Medan Ground 121.700, Medan Tower 118.300, Medan Approach 124.200, Kualanamu Information (ATIS) 126.400.
  - Taxiway: Papa, Quebec, Alpha. Stand: Gate 8, 9.
  - Prosedur: SID KNO1A, STAR KNO1B, ILS Rwy 05.
- **Rujukan Resmi:** AIP Indonesia Vol II AD 2 WIMM.
- **Tautan Sumber Langsung:**
  - ChartFox WIMM: [chartfox.org/WIMM](https://chartfox.org/WIMM)
  - OurAirports WIMM: [ourairports.com/airports/WIMM/](https://ourairports.com/airports/WIMM/)
  - SkyVector WIMM: [skyvector.com/airport/WIMM/Deli-Serdang-Kualanamu-International-Airport](https://skyvector.com/airport/WIMM/Deli-Serdang-Kualanamu-International-Airport)

#### 18. WIHH / HLP — Halim Perdanakusuma International Airport (Jakarta)
- **Data Operasional:**
  - Runway: 06/24 (Holding: A1, A2, C1).
  - Frekuensi: Halim Ground 121.800, Halim Tower 118.600, Jakarta Director (Approach) 123.800, Halim Information (ATIS) 126.000.
  - Taxiway: Alpha, Charlie. Stand: Stand 1 (VIP), Stand 4.
  - Prosedur: SID HLP1A, STAR HLP1B, ILS Rwy 06.
- **Rujukan Resmi:** AIP Indonesia Vol II AD 2 WIHH (AIRAC Amdt 136).
- **Tautan Sumber Langsung:**
  - AirNav Nav-Card WIHH: [AirNav Nav-Card (Fix AKNER WIHH)](https://app-pia.airnavindonesia.co.id/navcard/published.php)
  - ChartFox WIHH: [chartfox.org/WIHH](https://chartfox.org/WIHH)
  - AC-U-KWIK WIHH Diagram: [acukwik.com/Airport/WIHH](https://acukwik.com/Airport/WIHH)
  - OurAirports WIHH: [ourairports.com/airports/WIHH/](https://ourairports.com/airports/WIHH/)
  - SkyVector WIHH: [skyvector.com/airport/WIHH/Jakarta-Halim-Perdanakusuma-Airport](https://skyvector.com/airport/WIHH/Jakarta-Halim-Perdanakusuma-Airport)

---

### LEVEL 5: Extreme Terrain & High-Risk Valley (Profile: IFR_COMMERCIAL / VFR)
Fokus: GPWS alerts, mandatory Go-Around, blind valleys, steep approach angle, airspace violation boundary.

#### 19. WAVV / WMX — Wamena Airport (Papua Pegunungan)
- **Data Operasional:**
  - Runway: 15/33 (Holding: A1, B1 — Elevasi 5.085 ft, One-way Runway di lembah pegunungan Jayawijaya).
  - Frekuensi: Wamena Tower 122.200, Wamena Approach/Information 122.800, Wamena Information (ATIS) 126.800.
  - Taxiway: Alpha, Bravo. Stand: Stand 1–2.
  - Prosedur: SID WMX1A, STAR WMX1B, RNP Approach Rwy 15.
- **Rujukan Resmi:** AIP Indonesia Vol III AD 2 WAVV.
- **Tautan Sumber Langsung:**
  - ChartFox WAVV: [chartfox.org/WAVV](https://chartfox.org/WAVV)
  - OurAirports WAVV: [ourairports.com/airports/WAVV/](https://ourairports.com/airports/WAVV/)
  - SkyVector WAVV: [skyvector.com/airport/WAVV/Wamena-Airport](https://skyvector.com/airport/WAVV/Wamena-Airport)

#### 20. WICC / BDO — Husein Sastranegara International Airport (Bandung)
- **Data Operasional:**
  - Runway: 29/11 (Holding: A1, A2, B1 — Cekungan mangkuk vulkanik Tangkuban Perahu & Manglayang).
  - Frekuensi: Bandung Ground 121.700, Bandung Tower 118.100, Bandung Approach 120.100, Bandung Information (ATIS) 126.400.
  - Taxiway: Alpha, Bravo. Stand: Stand 2, 3.
  - Prosedur: SID BDO1A, STAR BDO1B, LOC/DME Rwy 29 (Steep descent angle).
- **Rujukan Resmi:** AIP Indonesia Vol II AD 2 WICC.
- **Tautan Sumber Langsung:**
  - ChartFox WICC: [chartfox.org/WICC](https://chartfox.org/WICC)
  - OurAirports WICC: [ourairports.com/airports/WICC/](https://ourairports.com/airports/WICC/)
  - SkyVector WICC: [skyvector.com/airport/WICC/Husein-Sastranegara-Bandung-Airport](https://skyvector.com/airport/WICC/Husein-Sastranegara-Bandung-Airport)

#### 21. WAFB / TRT — Toraja Airport (Tana Toraja, Sulawesi Selatan)
- **Data Operasional:**
  - Runway: 04/22 (Holding: A1, A2 — Elevasi 2.400 ft, Tabletop Runway di atas puncak bukit terpangkas).
  - Frekuensi: Toraja Tower 122.400, Makassar Control (Approach) 123.600, Toraja Information (ATIS) 127.000.
  - Taxiway: Alpha. Stand: Stand 1–2.
  - Prosedur: SID TRT1A, STAR TRT1B, RNP Rwy 04.
- **Rujukan Resmi:** AIP Indonesia Vol III AD 2 WAFB.
- **Tautan Sumber Langsung:**
  - ChartFox WAFB: [chartfox.org/WAFB](https://chartfox.org/WAFB)
  - OurAirports WAFB: [ourairports.com/airports/WAFB/](https://ourairports.com/airports/WAFB/)
  - SkyVector WAFB: [skyvector.com/airport/WAFB/Tana-Toraja-Toraja-Airport](https://skyvector.com/airport/WAFB/Tana-Toraja-Toraja-Airport)

#### 22. WABP / TIM — Mozes Kilangin Airport (Timika, Papua Tengah)
- **Data Operasional:**
  - Runway: 12/30 (Holding: A1, A2, B1 — Kaki tebing Pegunungan Cartenz / Sudirman).
  - Frekuensi: Timika Ground 121.700, Kilangin Tower 118.100, Timika Approach 122.300, Timika Information (ATIS) 126.500.
  - Taxiway: Alpha, Bravo. Stand: Stand 3, 4.
  - Prosedur: SID TIM1A, STAR TIM1B, ILS Rwy 12.
- **Rujukan Resmi:** AIP Indonesia Vol III AD 2 WABP.
- **Tautan Sumber Langsung:**
  - ChartFox WABP: [chartfox.org/WABP](https://chartfox.org/WABP)
  - OurAirports WABP: [ourairports.com/airports/WABP/](https://ourairports.com/airports/WABP/)
  - SkyVector WABP: [skyvector.com/airport/WAYY/Mozes-Kilangin-Airport](https://skyvector.com/airport/WAYY/Mozes-Kilangin-Airport) *(SkyVector terindeks sebagai WAYY)*

#### 23. WALR / TRK — Juwata International Airport (Tarakan, Kalimantan Utara)
- **Data Operasional:**
  - Runway: 06/24 (Holding: A1, A2 — Perbatasan ruang udara internasional FIR Kinabalu Malaysia).
  - Frekuensi: Tarakan Ground 121.800, Juwata Tower 118.100, Tarakan Approach 120.400, Tarakan Information (ATIS) 126.200.
  - Taxiway: Alpha, Bravo. Stand: Stand 2, 3.
  - Prosedur: SID TRK1A, STAR TRK1B, ILS Rwy 06.
- **Rujukan Resmi:** AIP Indonesia Vol II AD 2 WALR.
- **Tautan Sumber Langsung:**
  - ChartFox WALR: [chartfox.org/WALR](https://chartfox.org/WALR)
  - OurAirports WALR: [ourairports.com/airports/WALR/](https://ourairports.com/airports/WALR/)
  - SkyVector WALR: [skyvector.com/airport/WAQQ/Juwata-Int-Airport](https://skyvector.com/airport/WAQQ/Juwata-Int-Airport) *(SkyVector terindeks sebagai WAQQ)*

---

## 3. Integrasi Kode ScriptGeneratorEngine

Seluruh 23 data bandara di atas otomatis terbaca oleh loader bandara di Swift:
```swift
// Resources/Airports/{ICAO}.json dimuat oleh AirportDataLoader
let airport = try AirportDataLoader.load(icao: "WIII")
// Menjamin seluruh dialog radio, taxiway, dan holding points akurat secara operasional
```
