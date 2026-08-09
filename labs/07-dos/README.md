# Lab 07 - Denial of service

Denial of Service | 60 menit | Level 3

## BACA INI DULU. JANGAN LEWATI.

**Alat di lab ini hanya boleh diarahkan ke dua container di dalam lab Anda
sendiri: `web` dan `web-aman`. Tidak ada target lain yang sah. Tidak ada
pengecualian.**

Yang dilarang keras, dan daftar ini bukan formalitas:

- Laptop teman sebelah, biarpun dia bilang boleh. Dia tidak berwenang
  memberi izin atas jaringan yang bukan miliknya.
- Wi-Fi kelas, jaringan kantor tempat kelas berlangsung, printer, router, access point.
- Alamat mana pun di internet, termasuk situs milik Anda sendiri yang
  di-hosting orang lain. Yang terganggu bukan cuma situs Anda, tapi juga
  tetangga satu server dan jalur penyedianya.
- Situs pemerintah, bank, sekolah, dan layanan publik. Ini termasuk
  "cuma coba sebentar".

### Konsekuensi hukumnya di Indonesia

Serangan denial of service masuk ke UU Informasi dan Transaksi Elektronik
(UU Nomor 11 Tahun 2008 beserta perubahannya). Pasal 33 melarang siapa pun
dengan sengaja dan tanpa hak melakukan tindakan apa pun yang berakibat
terganggunya Sistem Elektronik atau membuatnya tidak bekerja sebagaimana
mestinya. Ancaman pidananya ada di Pasal 49: penjara paling lama 10 tahun
dan atau denda paling banyak Rp10.000.000.000.

Tidak ada unsur "niat baik" atau "cuma belajar" yang menghapus pasal itu.
Yang membedakan pentester dari terdakwa cuma satu benda: izin tertulis dari
pemilik sistem, dengan cakupan dan jangka waktu yang jelas. Di lab ini, izin
itu berlaku untuk dua container dan tidak lebih.

Perlu ditegaskan juga: catatan ini bukan nasihat hukum. Kalau Anda perlu
kepastian untuk sebuah pekerjaan nyata, tanyakan ke penasihat hukum, bukan ke
pengajar.

### Tiga pagar yang sudah dipasang, dan kenapa tetap ada peringatan ini

1. **Jaringan lab dibuat internal.** Toolbox tidak punya rute keluar sama
   sekali. Diuji: `ping 8.8.8.8` dan `ping 192.168.18.1` dua-duanya menjawab
   `Network is unreachable`, dan `ip route` cuma memuat satu baris, yaitu
   subnet lab.
2. **Port kedua target diikat ke 127.0.0.1.** Diuji: dibuka lewat alamat LAN
   laptop, hasilnya kode 000. Peserta lain di ruangan yang sama tidak bisa
   menyentuhnya.
3. **Skrip serangan punya pemeriksa target sendiri.** Kalau Anda salah ketik
   dan menyebut alamat di luar subnet lab, skripnya berhenti sebelum
   mengirim satu paket pun.

Pagar itu melindungi lab ini. Pagar itu tidak ikut Anda pulang. Skrip yang
sama, dijalankan di laptop tanpa Docker, akan menembak apa pun yang Anda
tunjuk. Yang harus terbawa pulang adalah kebiasaannya, bukan pagarnya.

## Tujuan

Membuktikan sendiri bahwa denial of service tidak selalu butuh bandwidth
besar, dengan menjatuhkan sebuah web server memakai tiga teknik yang berbeda
lapisannya, lalu mengukur ulang setelah mitigasi dipasang. Nyambungnya ke
domain ujian CEH: Denial-of-Service dan DDoS, termasuk pembedaan volumetric
lawan protocol lawan application layer, dan countermeasure-nya.

## Waktu

60 menit. Langkah 1 sampai 8 sekitar 45 menit, sisanya untuk pertanyaan dan
tantangan tambahan.

## Peta lab

| Container | Perannya | Dipanggil dari toolbox | Dari browser |
|---|---|---|---|
| toolbox | tempat Anda mengetik | - | - |
| web | target RENTAN | `web` port 80 | http://localhost:8710 |
| web-aman | target TERMITIGASI | `web-aman` port 80 | http://localhost:8711 |

Kedua target memakai image, isi halaman, dan jumlah pekerja yang sama persis.
Yang berbeda cuma setelan pertahanannya. Itu disengaja: kalau `web-aman`
diberi kapasitas lebih besar, yang terukur bukan mitigasinya lagi, tapi
tambahan sumber dayanya.

Perkakas di dalam toolbox untuk lab ini, semuanya di `/lab/serang/`:

| Berkas | Gunanya |
|---|---|
| `ukur.sh` | alat UKUR. Mengirim beberapa permintaan biasa lalu melaporkan berapa yang berhasil dan berapa lama |
| `slowloris.py` | serangan lapisan aplikasi, menahan koneksi dengan header yang tidak pernah selesai |
| `http-flood.py` | serangan lapisan aplikasi, membanjiri dengan permintaan yang sah |
| `syn-flood.py` | serangan lapisan protokol, membanjiri dengan SYN beralamat palsu |
| `kernel-metrik.sh` | pembaca metrik TCP dari SISI TARGET, dijalankan di dalam container target |

## Menyalakan

```
./lab up 07
```

Di Windows, ganti `./lab` dengan `.\lab.cmd` pada semua perintah di halaman
ini.

Buka http://localhost:8710 dan http://localhost:8711. Dua-duanya harus
menampilkan halaman Toko Kelontong Lab.

Anda akan butuh DUA jendela terminal sepanjang lab ini: satu untuk menyerang,
satu untuk mengukur. Buka dua-duanya sekarang, dan di masing-masing jalankan:

```
./lab sh 07
```

Sepanjang halaman ini, terminal yang menjalankan serangan disebut
**terminal A**, dan yang menjalankan pengukuran disebut **terminal B**.

## Langkah wajib

### 1. Ambil angka dasar

Tanpa angka dasar, semua yang Anda lihat sesudahnya cuma perasaan.

Di terminal B:

```
bash /lab/serang/ukur.sh web
bash /lab/serang/ukur.sh web-aman
```

Yang mestinya kelihatan, untuk kedua target:

```
  berhasil : 10 dari 10
  gagal    : 0
  rata-rata: 0.001 detik

  metrik pekerja Apache:
    BusyWorkers: 1
    IdleWorkers: 9
```

Catat tiga angka itu. `BusyWorkers` dan `IdleWorkers` adalah jumlah thread
pekerja Apache yang sedang sibuk dan yang menganggur. Server ini sengaja
dibatasi sepuluh pekerja saja, jadi angka totalnya selalu sepuluh.

### 2. Slowloris ke target rentan

Di terminal A:

```
python3 /lab/serang/slowloris.py web 30 12
```

Biarkan berjalan. Setelah sekitar sepuluh detik, di terminal B:

```
bash /lab/serang/ukur.sh web
```

Yang mestinya kelihatan:

```
  no   kode   detik
  1    000    0.000000
  2    000    0.000000
  ...
  berhasil : 0 dari 10
  gagal    : 10

  metrik pekerja Apache:
    TIDAK TERBACA. Halaman metrik ikut tidak bisa dibuka, dan itu
    bukan kerusakan alat ukur.
```

Kode `000` artinya curl tidak mendapat jawaban sama sekali. Coba juga muat
ulang http://localhost:8710 di browser: halaman itu sekarang mati, dan
matinya dari laptop Anda sendiri, bukan dari jaringan.

Perhatikan berapa banyak lalu lintas yang dipakai untuk itu. Tiga puluh
koneksi, masing-masing mengirim satu baris teks pendek tiap dua belas detik.
Totalnya beberapa ratus byte per menit, lebih kecil daripada satu ikon di
halaman web biasa.

Hentikan serangannya dengan Ctrl-C di terminal A, tunggu dua detik, lalu ukur
lagi. Server harus pulih sendiri tanpa di-restart.

### 3. Slowloris ke target termitigasi

Serangan yang sama persis, target yang berbeda. Di terminal A:

```
python3 /lab/serang/slowloris.py web-aman 30 12
```

Di terminal B, setelah sekitar dua puluh detik:

```
bash /lab/serang/ukur.sh web-aman
```

Yang mestinya kelihatan: `berhasil : 10 dari 10`. Permintaan pertama boleh
saja lambat, sekitar dua sampai empat detik, karena ia sempat mengantre.
Sisanya kembali ke seperseribu detik.

Sekarang lihat sisi penyerangnya. Di terminal A, keluaran slowloris berubah:

```
putaran 1   soket tertahan: 30 dari 30   diputus server ronde ini:  0
putaran 2   soket tertahan: 30 dari 30   diputus server ronde ini: 10
```

Angka di kolom terakhir berayun antara 10 dan 20. Artinya server memutus
sepertiga sampai dua pertiga koneksi setiap ronde, dan skripnya sibuk membuka
ulang. Serangannya masih berjalan, tapi tidak pernah bisa menumpuk.

Hentikan dengan Ctrl-C, lalu cari tahu baris mana yang menyelamatkannya. Dari
folder repo, di terminal biasa (bukan di dalam toolbox):

```
diff labs/07-dos/web-conf/rentan.conf labs/07-dos/web-conf/aman.conf
```

Baris yang Anda cari adalah `RequestReadTimeout`. Di target rentan nilainya
`header=0 body=0`, artinya dimatikan. Di target aman nilainya
`header=3-6,MinRate=500 body=6,MinRate=500`.

### 4. HTTP flood, dan hasil yang mungkin mengejutkan

Di terminal A:

```
python3 /lab/serang/http-flood.py web 60 20
```

Di terminal B, sementara itu berjalan:

```
bash /lab/serang/ukur.sh web
```

Yang mestinya kelihatan:

```
  berhasil : 10 dari 10
  rata-rata: 0.001 detik

  metrik pekerja Apache:
    BusyWorkers: 6
    IdleWorkers: 4
```

`BusyWorkers` berayun antara 5 dan 10 tergantung kapan Anda mengukurnya. Jalankan
`ukur.sh` beberapa kali dan Anda akan melihat kolam pekerjanya sesekali habis.

Baca itu pelan-pelan. Kolam pekerja terpakai penuh, tapi layanannya TIDAK
mati. Di terminal A Anda akan melihat angka sekitar 40.000 respons per detik,
dan totalnya di atas 800.000 dalam dua puluh detik. Satu container Kali
membanjiri satu Apache sepuluh pekerja dengan empat puluh ribu permintaan per
detik, dan Apache melayani semuanya.

Itu bukan kegagalan lab. Itu jawaban atas satu pertanyaan yang sering keluar
di ujian: kenapa serangan flood hampir selalu berbentuk DDoS, bukan DoS.
Satu sumber tidak cukup. Yang dibutuhkan adalah banyak sumber sekaligus, atau
permintaan yang jauh lebih mahal untuk dilayani. Yang kedua itu yang dicoba
di langkah berikutnya.

Hentikan dengan Ctrl-C kalau belum selesai sendiri.

### 5. HTTP flood ke sumber daya yang mahal

Kedua target menyediakan berkas 8 MB di `/laporan.bin`. Sekarang banjirnya
diarahkan ke situ. Di terminal A:

```
python3 /lab/serang/http-flood.py web 40 20 /laporan.bin
```

Di terminal B:

```
bash /lab/serang/ukur.sh web
```

Yang mestinya kelihatan: masih `berhasil : 10 dari 10`, tapi rata-rata
waktunya naik beberapa kali lipat dibanding angka dasar, dan `BusyWorkers`
menempel di 7 sampai 10. Catat juga total respons yang dilaporkan penyerang
di akhir, angkanya belasan ribu.

Sekarang serangan yang sama ke target termitigasi. Di terminal A:

```
python3 /lab/serang/http-flood.py web-aman 40 20 /laporan.bin
```

Di terminal B:

```
bash /lab/serang/ukur.sh web-aman
```

**Hasilnya tidak seluruhnya lebih baik, dan itu bagian terpenting dari lab
ini.** Yang terukur di mesin penguji:

| | web (rentan) | web-aman (termitigasi) |
|---|---|---|
| respons yang berhasil diperas penyerang | 18.073 | 60 |
| permintaan sah yang berhasil | 10 dari 10 | 8 dari 10 |
| rata-rata waktu permintaan sah | 0,003 detik | 0,808 detik |

Angka di laptop Anda tidak akan sama persis, dan tidak perlu sama. Yang harus
sama adalah arahnya: penyerang mendapat dua sampai tiga angka lebih sedikit
dari `web-aman`, sementara permintaan sah ke `web-aman` justru lebih sering
gagal.

`mod_ratelimit` di `aman.conf` membatasi bandwidth tiap koneksi ke 2 MiB per
detik. Hasilnya penyerang menyedot sekitar 300 kali lebih sedikit data,
jadi jalur keluar server terlindungi. Tapi karena tiap unduhan
jadi berlangsung empat detik, sepuluh pekerja Apache justru tertahan lebih
lama, dan permintaan sah mulai gagal.

Kesimpulan yang harus Anda bawa: **mitigasi punya harga, dan harganya cuma
ketahuan kalau diukur.** Membatasi bandwidth per koneksi melindungi satu hal
dan memperburuk hal lain. Di dunia nyata pasangannya adalah pembatasan jumlah
koneksi per alamat, dan itu tidak ada di Apache bawaan.

### 6. SYN flood ke target rentan

Dua serangan tadi berada di lapisan aplikasi. Yang ini di lapisan protokol:
ia tidak pernah menyentuh Apache sama sekali.

Di terminal A:

```
python3 /lab/serang/syn-flood.py web 20 0
```

Di terminal B, setelah sekitar empat detik:

```
bash /lab/serang/ukur.sh web 8 3
```

Yang mestinya kelihatan, dan angkanya memang berayun antara nol sampai tiga
yang lolos:

```
  berhasil : 0 dari 8
  gagal    : 8
```

Kalau di layar Anda ada satu atau dua yang berhasil dengan waktu sekitar satu
detik, itu bukan kegagalan. Satu detik adalah waktu tunggu kernel Anda sebelum
mengirim ulang SYN yang tidak dijawab, dan kadang percobaan kedua itu kebagian
tempat di antrean yang baru saja kosong. Yang penting: dari 0,0006 detik
menjadi 1 detik, atau gagal sama sekali.

Sekarang perhatikan sesuatu yang aneh: metrik Apache tetap terbaca kalau Anda
membukanya tepat waktu, dan isinya `BusyWorkers: 1, IdleWorkers: 9`. Apache
sehat walafiat. Yang penuh bukan Apache, tapi antrean koneksi setengah jadi
di kernel, dan koneksi Anda tidak pernah sampai ke Apache.

Buktikan dari sisi target. Di terminal ketiga, atau setelah menghentikan
serangan:

```
./lab sh 07 web
sh /serang/kernel-metrik.sh
exit
```

Yang mestinya kelihatan:

```
tcp_syncookies       : 0
SyncookiesSent         0
TCPReqQFullDoCookies   0
TCPReqQFullDrop        1216083
```

`TCPReqQFullDrop` adalah jumlah paket SYN yang dibuang kernel karena antrean
penuh. Tiap satuan di sana adalah satu calon pengunjung yang koneksinya tidak
pernah dijawab.

Hentikan serangan dengan Ctrl-C.

### 7. SYN flood ke target termitigasi

Serangan yang sama persis. Di terminal A:

```
python3 /lab/serang/syn-flood.py web-aman 20 0
```

Di terminal B:

```
bash /lab/serang/ukur.sh web-aman 8 3
```

Yang mestinya kelihatan: `berhasil : 8 dari 8`, dan rata-rata waktu kembali
ke angka dasar. Serangan yang tadi mematikan `web` sepenuhnya tidak
meninggalkan bekas di `web-aman`.

Lalu lihat metrik kernelnya:

```
./lab sh 07 web-aman
sh /serang/kernel-metrik.sh
exit
```

Yang mestinya kelihatan:

```
tcp_syncookies       : 1
SyncookiesSent         206906
TCPReqQFullDoCookies   206906
TCPReqQFullDrop        0
```

Ini penjelasannya. Saat antrean SYN penuh, kernel punya dua pilihan. Tanpa
SYN cookies ia membuang paketnya, dan itu yang terjadi di langkah 6. Dengan
SYN cookies ia tidak menyimpan apa-apa: ia menaruh seluruh keterangan koneksi
di dalam nomor urut SYN-ACK, lalu melupakannya. Kalau klien memang sungguhan,
ACK yang ia kirim balik membawa keterangan itu dan koneksi dibangun dari nol.
Kalau klien palsu, tidak ada ACK, dan tidak ada satu byte pun memori yang
terbuang. `TCPReqQFullDrop 0` artinya nol calon pengunjung ditolak.

Hentikan serangan dengan Ctrl-C.

### 8. Isi tabel ini

Salin ke catatan Anda dan isi dari angka Anda sendiri, bukan dari angka di
halaman ini.

| Serangan | Lapisan | web berhasil dari 10 | web-aman berhasil dari 10 | Mitigasi yang bekerja |
|---|---|---|---|---|
| Slowloris | | | | |
| HTTP flood halaman kecil | | | | |
| HTTP flood berkas 8 MB | | | | |
| SYN flood | | | | |

## Pertanyaan

Jawabannya cuma ketemu kalau Anda benar-benar menjalankan langkah di atas.

1. Di langkah 2, berapa `BusyWorkers` yang terbaca saat slowloris berjalan?
   Kenapa jawabannya bukan sekadar angka, dan apa artinya untuk cara Anda
   memantau server yang sedang diserang?
2. Slowloris mengirim jauh lebih sedikit data daripada HTTP flood, tapi cuma
   slowloris yang mematikan `web`. Sebutkan sumber daya apa yang sebenarnya
   dihabiskan masing-masing serangan.
3. Di langkah 5, `web-aman` melayani permintaan sah LEBIH BURUK daripada
   `web`, padahal ia yang punya mitigasi. Jelaskan sebabnya, lalu sebutkan
   apa yang justru berhasil dilindungi oleh mitigasi itu.
4. Di langkah 6, `BusyWorkers` cuma 1 padahal layanannya mati total. Kalau
   Anda cuma memantau metrik aplikasi, serangan seperti ini akan terlihat
   seperti apa di dasbor Anda?
5. Dari `kernel-metrik.sh` di langkah 6 dan 7, sebutkan satu penghitung yang
   nilainya nol di satu target dan besar di target lain, lalu jelaskan
   kenapa perbedaannya persis di situ.
6. `RequestReadTimeout header=3-6,MinRate=500` punya tiga angka. Jelaskan apa
   yang dilakukan masing-masing, dan kenapa `MinRate` perlu ada. Petunjuk:
   pikirkan pengguna yang koneksinya lambat tapi jujur.
7. Kalau target ini ada di belakang CDN atau load balancer, mana dari empat
   serangan tadi yang tidak akan pernah sampai ke server asal, dan kenapa?

## Tantangan tambahan

Untuk yang selesai lebih cepat. Tidak wajib, dan tidak ada yang perlu dikejar
kalau langkah 1 sampai 8 belum beres.

1. **Pasang mitigasinya sendiri ke target yang rentan.** Kedua setelan ada di
   repo, dan `web` bisa dipindah ke setelan aman lewat satu variabel:

   ```
   DOS_MODE=aman ./lab reset 07
   ```

   Di Windows PowerShell:

   ```
   $env:DOS_MODE="aman"; .\lab.cmd reset 07
   ```

   Pastikan berhasil dengan `curl -I http://localhost:8710/` dan lihat header
   `X-Lab-Mode`. Lalu ulangi langkah 2 ke `web` dan buktikan ia sekarang
   bertahan. Untuk kembali, jalankan `./lab reset 07` tanpa variabel itu.
   Catatan jujur: yang berpindah cuma setelan Apache. SYN cookies diatur di
   `compose.yaml` lewat `sysctls`, jadi `web` tetap rentan terhadap langkah 6.

2. **Cari ambang batasnya.** Turunkan jumlah soket slowloris satu per satu
   dari 30. Berapa soket paling sedikit yang masih bisa mematikan `web`?
   Cocokkan jawaban Anda dengan `MaxRequestWorkers` dan
   `AsyncRequestWorkerFactor` di `web-conf/rentan.conf`, lalu jelaskan
   selisihnya kalau ada.

3. **Lihat paketnya, jangan cuma akibatnya.** Jalankan
   `tcpdump -ni eth0 -c 20 'tcp[tcpflags] & tcp-syn != 0'` di toolbox sambil
   menjalankan SYN flood. Perhatikan alamat asal tiap paket. Lalu jalankan
   `ip neigh` di toolbox dan jelaskan kenapa balasan SYN-ACK dari target tidak
   pernah sampai ke mana pun. Petunjuk: alamat asal palsu itu memang ada di
   subnet lab, tapi tidak ada mesin yang menjawab ARP untuknya.

4. **Ukur ambang SYN flood.** Argumen ketiga `syn-flood.py` adalah paket per
   detik, dan `0` berarti secepatnya. Coba 500, lalu 5000, lalu 0. Pada laju
   berapa layanan mulai gagal sebagian, dan pada laju berapa gagal total?

5. **Baca antreannya langsung.** Sambil SYN flood berjalan, di dalam container
   target jalankan `awk 'NR>1 && $4=="03"' /proc/net/tcp | wc -l`. Angka `03`
   itu kode state SYN_RECV. Bandingkan angkanya dengan `ListenBacklog 4` di
   berkas setelan, lalu jelaskan kenapa angkanya tidak persis sama.

## Yang tidak bisa dikerjakan di lab ini, dan kenapa

Bagian ini sama pentingnya dengan langkah-langkah di atas. Kalau Anda pulang
dengan gambaran bahwa DoS itu seperti yang barusan, gambarannya salah.

**Serangan volumetrik.** Yang paling sering muncul di berita, dan justru yang
paling tidak bisa dipelajari di sini. DDoS besar diukur dalam ratusan gigabit
per detik dan puluhan juta paket per detik, dikirim dari puluhan ribu mesin di
banyak negara. Yang jatuh bukan servernya, tapi jalur masuk ke pusat datanya,
jauh sebelum paketnya sampai ke server. Satu container di satu laptop tidak
bisa mendekati skala itu, dan tidak boleh mencobanya di jaringan mana pun.

**Serangan amplifikasi dan refleksi.** DNS, NTP, memcached, dan SSDP bisa
dipakai memantulkan lalu lintas ke korban dengan pengganda puluhan sampai
ribuan kali. Teknik ini WAJIB memalsukan alamat korban dan mengirim ke server
pihak ketiga di internet. Artinya, mencobanya berarti menyerang dua pihak
sekaligus: pemilik server pemantul dan korban. Tidak ada versi yang aman dari
teknik ini di luar lab yang benar-benar terputus dari internet dengan lebih
dari satu server, dan lab ini tidak punya jalan ke internet sama sekali.
Untuk ujian, yang perlu diingat adalah rasio amplifikasinya dan bahwa
pertahanannya ada di penyedia layanan, bukan di korban.

**Botnet dan lalu lintas yang benar-benar terdistribusi.** Di sini semua
serangan berasal dari satu alamat. Di dunia nyata itu justru yang paling
mudah dilawan: blokir satu alamat, selesai. Kesulitan sesungguhnya adalah
membedakan seratus ribu alamat penyerang dari seratus ribu pelanggan.
Konsekuensinya, semua mitigasi yang berbasis "berapa banyak dari satu alamat"
jauh lebih lemah di lapangan daripada di lab ini.

**Rate limit jumlah permintaan.** Ini pantas diluruskan karena namanya sering
tertukar. Apache bawaan TIDAK punya pembatas jumlah permintaan per detik.
`mod_ratelimit` yang dipakai di `aman.conf` membatasi BANDWIDTH per koneksi,
satuannya KiB per detik, dan sudah terlihat di langkah 5 bahwa efeknya
berbeda. Pembatas jumlah permintaan yang sebenarnya ada di tempat lain:
`mod_evasive` atau `mod_qos` untuk Apache, `limit_req` dan `limit_conn` untuk
nginx, atau di lapisan yang lebih depan seperti WAF, load balancer, dan CDN.
Kalau soal ujian menyebut rate limiting sebagai countermeasure DoS, yang
dimaksud adalah pembatas jumlah permintaan itu, bukan pembatas bandwidth.

**Mitigasi di lapisan jaringan.** Pertahanan sungguhan terhadap SYN flood
tidak berhenti di SYN cookies. Ada `iptables` dengan modul `hashlimit` dan
`connlimit`, ada scrubbing center milik penyedia, ada anycast yang menyebar
serangan ke banyak lokasi, dan ada BGP blackholing sebagai pilihan terakhir
yang justru menyelesaikan serangan dengan cara mengorbankan korbannya.
Semuanya butuh perangkat jaringan atau kerja sama penyedia yang tidak ada di
dalam satu laptop.

**Angka di lab ini tidak bisa dipakai membandingkan apa pun.** `web` sengaja
dibuat dengan sepuluh pekerja dan antrean koneksi empat. Server produksi
memakai ratusan sampai ribuan pekerja dan antrean 511 ke atas. Angka kecil itu
dipilih supaya efeknya kelihatan dalam hitungan detik di kelas. Jangan pernah
mengutip hasil lab ini sebagai ukuran ketahanan Apache.

**Satu catatan jujur tentang SYN flood.** Saat menyiapkan lab ini, versi
pertamanya memakai `ListenBacklog 16` dan tidak berefek sama sekali, bahkan
pada 63 ribu paket per detik. Kernel Linux modern memangkas sendiri antrean
SYN-nya lebih cepat daripada skrip mengisinya. Angka 4 dipakai supaya
serangannya punya efek yang bisa diukur di kelas. Artinya: di server yang
dikonfigurasi wajar, dengan SYN cookies menyala seperti bawaan hampir semua
distribusi Linux hari ini, SYN flood dari satu sumber praktis tidak berguna.
Itu bukan cacat lab, itu temuan yang layak Anda bawa ke ujian dan ke
pekerjaan.

## Mematikan dan membereskan

```
./lab down 07
```

Perintah itu menghapus container, jaringan, dan volume lab ini. Berkas 8 MB
`/laporan.bin` dibuat di dalam container, jadi ia ikut hilang dan tidak
meninggalkan apa-apa di laptop Anda.

Sebelum menutup, pastikan tidak ada serangan yang masih berjalan di latar:

```
./lab sh 07
pkill -f slowloris.py; pkill -f http-flood.py; pkill -f syn-flood.py
exit
```

Kalau Anda sempat memakai `DOS_MODE=aman`, variabel itu cuma hidup di dalam
satu perintah shell, jadi tidak ada yang perlu dikembalikan. Untuk memastikan,
`./lab reset 07` tanpa variabel apa pun mengembalikan `web` ke mode rentan.

Kalau ragu apakah masih ada yang menyala:

```
./lab nuke
```

## Pagar, sekali lagi

Target sah di lab ini cuma `web` dan `web-aman`, keduanya di dalam compose
lab ini. Tidak ada target lain yang sah, di lab ini maupun di lab mana pun
sepanjang minggu ini.
