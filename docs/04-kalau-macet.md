# Kalau macet

Cari gejala Anda di tabel, lalu buka bagiannya. Kalau sudah dicoba dan tetap macet,
panggil instruktur dan tunjukkan layar Anda apa adanya, jangan diringkas.

| Gejala | Bagian |
|---|---|
| `port is already allocated`, atau halaman terbuka tapi isinya aplikasi lain | [1. Port sudah terpakai](#1-port-sudah-terpakai) |
| `error from registry: denied` saat menarik image | [2. denied saat menarik image](#2-denied-saat-menarik-image) |
| `toomanyrequests`, `You have reached your pull rate limit` | [3. Kuota Docker Hub habis](#3-kuota-docker-hub-habis) |
| Docker Desktop tidak mau menyala dan menyebut WSL | [4. WSL2 belum aktif, khusus Windows](#4-wsl2-belum-aktif-khusus-windows) |
| `no space left on device`, atau laptop tiba-tiba penuh | [5. Disk penuh](#5-disk-penuh) |
| Container menyala tapi halamannya tidak terbuka | [6. Container nyala tapi halaman tidak terbuka](#6-container-nyala-tapi-halaman-tidak-terbuka) |
| Berkas di folder lab hilang sendiri | [7. Antivirus menghapus perkakas](#7-antivirus-menghapus-perkakas) |
| `permission denied` saat menjalankan `./lab` | [8. Launcher tidak bisa dijalankan](#8-launcher-tidak-bisa-dijalankan) |
| `bad interpreter: /usr/bin/env bash^M` | [9. Akhiran baris salah](#9-akhiran-baris-salah) |
| `Docker lo lagi di mode container Windows` | [10. Docker sedang di mode Windows containers](#10-docker-sedang-di-mode-windows-containers) |

---

## 1. Port sudah terpakai

### Gejalanya

Bentuk pertama, terang-terangan:

```
Bind for 0.0.0.0:3000 failed: port is already allocated
```

Bentuk kedua, dan ini yang jahat: lab Anda menyala tanpa pesan error apa pun, tapi ketika
Anda buka `http://localhost:3000` yang muncul justru aplikasi lain, bukan lab. Ini sudah
diuji dan terbukti terjadi di macOS: kalau ada program lain di laptop Anda yang sudah
mendengarkan di port yang sama, container tetap bisa didaftarkan di port itu, dan yang
menjawab browser Anda adalah program lama, bukan lab.

Kesimpulan praktisnya: **kalau halaman lab menampilkan sesuatu yang tidak Anda kenali,
curigai port bentrok duluan, bukan labnya yang rusak.**

### Sebabnya

Ada program lain yang sudah memakai port itu. Tersangka yang paling sering: server
pengembangan Node atau React di port 3000, Tomcat atau Jenkins di port 8080, XAMPP atau
Apache di port 8000 dan 8080, dan lab lain dari repo ini yang lupa dimatikan.

### Obatnya

Pertama, matikan semua lab yang mungkin masih menyala:

```
./lab nuke          # macOS dan Linux
.\lab.cmd nuke      # Windows
```

Kalau masih bentrok, cari siapa yang memakai port itu.

macOS dan Linux:

```
lsof -nP -iTCP:3000 -sTCP:LISTEN
```

Windows, di PowerShell:

```
netstat -ano | findstr :3000
tasklist /FI "PID eq <nomor PID dari baris di atas>"
```

Tutup program itu, lalu nyalakan lagi labnya:

```
./lab up 05
```

Ganti angka `3000` dengan port yang disebut pesan error Anda. Port tiap lab bisa dilihat
dengan `./lab info <id>`.

---

## 2. denied saat menarik image

### Gejalanya

```
Image ghcr.io/contoh/nama-image:1.0 Error error from registry: denied
Error response from daemon: error from registry: denied
denied
```

Ini muncul saat `./lab up` atau `./lab pull`.

### Sebabnya

Docker berhasil menghubungi registry, tapi registry menolak memberikan image itu.
Penyebabnya salah satu dari tiga:

1. Image itu memang tidak ada di sana, misalnya karena nama atau tagnya salah ketik.
2. Image itu ada, tapi ditandai privat, jadi hanya pemiliknya yang bisa menariknya.
3. Image itu belum sempat diunggah oleh pembuat lab.

Perhatikan bahwa pesannya `denied`, bukan `toomanyrequests`. Ini **bukan** masalah kuota.
Menunggu satu jam tidak akan mengubah apa pun.

### Obatnya

Ini bukan sesuatu yang bisa Anda perbaiki dari sisi laptop Anda. Yang harus Anda lakukan:

1. Salin nama image yang disebut di pesan error, lengkap dengan tagnya.
2. Kirim ke instruktur.

Per 6 Agustus 2026, ada satu kasus yang sudah dikenal: image terminal penyerang
(`toolbox`) yang dipakai bersama oleh semua lab belum tersedia, sehingga `./lab up` dan
`./lab pull core` berhenti dengan pesan ini. Perbaikannya sedang dikerjakan sebelum kelas
dimulai. Kalau Anda tersandung kasus itu, Anda tidak salah dan tidak perlu memperbaiki
apa pun. Baca bagian Status di [README](../README.md).

---

## 3. Kuota Docker Hub habis

### Gejalanya

```
toomanyrequests: You have reached your pull rate limit.
```

Atau `./lab doctor` memberi baris kuning yang bilang image ujinya tidak bisa ditarik.

### Sebabnya, dan kenapa di kelas jauh lebih cepat habis

Docker Hub membatasi penarikan image untuk pengguna yang tidak login. Batas itu dihitung
**per alamat IP publik, bukan per laptop**. Angka pastinya bisa dibaca langsung dari
tanggapan server, dan pada 6 Agustus 2026 hasil pengukurannya:

```
ratelimit-limit: 100;w=3600
```

Artinya 100 penarikan per 3600 detik, yaitu 100 per jam per alamat IP.

Di rumah, satu laptop memakai jatah 100 itu sendirian dan praktis tidak pernah habis. Di
kelas, semua laptop keluar lewat satu koneksi yang sama, jadi bagi Docker Hub semuanya
tampak seperti satu pelanggan. Sepuluh peserta yang menyalakan lab yang sama pada menit
yang sama menghabiskan jatah satu jam dalam hitungan menit, dan setelah itu semua orang
kena tolak sekaligus, termasuk yang belum menarik apa pun.

### Obatnya

Urut dari yang paling ampuh.

**Cegah, jangan obati. Tarik image di rumah, malam sebelumnya:**

```
./lab pull core          # macOS dan Linux
.\lab.cmd pull core      # Windows
```

Image yang sudah ada di laptop tidak ditarik ulang, jadi laptop Anda tidak menambah beban
kuota kelas sama sekali.

**Kalau sudah terlanjur kena di kelas:**

1. Berhenti mengulang perintahnya. Setiap percobaan yang gagal tetap dihitung dan
   memperlambat pemulihan untuk semua orang.
2. Pakai bundel offline dari flashdisk instruktur:
   ```
   ./lab offline load /Volumes/NAMA-FLASHDISK      # macOS
   ./lab offline load /media/$USER/NAMA-FLASHDISK  # Linux
   .\lab.cmd offline load E:\                      # Windows
   ```
   Cara ini tidak menyentuh internet sama sekali.
3. Login ke akun Docker Hub gratis kalau Anda punya. Kuota pengguna yang login dihitung
   per akun, bukan per alamat IP, jadi Anda keluar dari antrean bersama.
   ```
   docker login
   ```

**Cara melihat sisa kuota Anda sendiri**, kalau Anda ingin memastikan sebelum menarik
banyak image. Perintah ini butuh `curl` dan `jq`:

```
TOK=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" | jq -r .token)
curl -s --head -H "Authorization: Bearer $TOK" \
  https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest | grep -i ratelimit-remaining
```

---

## 4. WSL2 belum aktif, khusus Windows

### Gejalanya

Docker Desktop menolak menyala, atau menyala lalu langsung berhenti, dengan pesan yang
menyebut WSL, WSL 2, atau virtual machine platform. Bisa juga `./lab.cmd doctor` berhenti
di baris `Engine Docker mati`.

### Sebabnya

Salah satu dari tiga, urut dari yang paling sering:

1. **Laptop belum di-restart** setelah `wsl --install`. Ini penyebab nomor satu.
2. Virtualisasi mati di BIOS atau UEFI.
3. WSL terpasang tapi versinya masih 1, bukan 2.

### Obatnya

Kerjakan berurutan, jangan dilompati.

1. Restart laptop. Restart betulan, bukan sign out dan bukan menutup layar.
2. Buka Task Manager, tab Performance, klik CPU, lihat baris `Virtualization`. Kalau
   tertulis `Disabled`, ikuti Langkah 1 di
   [01-pasang-docker-windows.md](01-pasang-docker-windows.md).
3. Buka PowerShell sebagai Administrator dan jalankan:
   ```
   wsl --install
   wsl --update
   wsl --set-default-version 2
   wsl --status
   ```
   Yang Anda cari di keluaran `wsl --status`: `Default Version: 2`.
4. Restart lagi, lalu buka Docker Desktop dan tunggu sampai tertulis `Engine running`.

---

## 5. Disk penuh

### Gejalanya

```
no space left on device
```

Atau lab gagal menyala tanpa alasan jelas, atau laptop Anda tiba-tiba kehabisan ruang
padahal Anda merasa tidak menyimpan apa-apa.

### Sebabnya

Image lab itu besar. Satu image bisa 500 MB sampai 1 GB, dan repo ini butuh sekitar 25 GB
kalau semua lab ditarik. Ditambah lagi, image lama yang sudah tidak dipakai tidak dihapus
sendiri, dan cache build ikut menumpuk.

### Obatnya

Lihat dulu ke mana ruangnya pergi:

```
docker system df
```

Keluarannya menyebutkan berapa yang bisa direbut kembali di kolom `RECLAIMABLE`.

Langkah pertama, matikan semua lab yang menyala:

```
./lab nuke          # macOS dan Linux
.\lab.cmd nuke      # Windows
```

Kalau masih kurang, bersihkan yang benar-benar tidak terpakai:

```
docker system prune
```

Kalau masih kurang juga, dan Anda paham konsekuensinya:

```
docker system prune -a
```

**Baca ini sebelum menjalankan `prune -a`.** Perintah itu menghapus semua image yang
sedang tidak dipakai container aktif, termasuk image lab yang sudah susah payah Anda tarik
di rumah. Menariknya lagi memakan jatah kuota Docker Hub, dan kalau Anda melakukannya di
kelas, Anda menghabiskan jatah satu kelas. Jangan jalankan ini pada hari kelas. Kalau
memang harus, jalankan di rumah lalu tarik ulang dengan `./lab pull core`.

Di Windows, kalau berkas disk WSL2 sudah membengkak dan cara di atas belum cukup, Docker
Desktop punya jalan terakhir: menu Troubleshoot, lalu `Clean / Purge data`. Itu
mengosongkan seluruh data Docker Anda, jadi anggap sebagai pilihan terakhir dan lakukan
di rumah.

---

## 6. Container nyala tapi halaman tidak terbuka

`./lab up` bilang lab menyala, tapi browser Anda menampilkan
`This site can't be reached` atau halaman kosong. Telusuri berurutan.

### Periksa 1. Apakah URL dan portnya benar

```
./lab info 05
```

Perintah ini menampilkan URL persis untuk lab itu, lengkap dengan portnya. Salin dari
situ, jangan mengetik dari ingatan.

### Periksa 2. Apakah aplikasinya sudah selesai menyala

Container bisa berstatus jalan sementara aplikasi di dalamnya masih memuat. Aplikasi web
yang berat butuh 30 sampai 60 detik. Lihat lognya:

```
./lab logs 05
```

Tunggu sampai muncul baris yang menandakan servernya siap menerima permintaan, lalu tekan
Ctrl-C untuk keluar dari log, lalu muat ulang browser.

### Periksa 3. Apakah ada program lain yang membajak portnya

Kalau halaman terbuka tapi isinya bukan lab, itu port bentrok. Baca
[bagian 1](#1-port-sudah-terpakai).

### Periksa 4. Anda memakai localhost dari dalam terminal penyerang

Ini kesalahpahaman yang paling sering terjadi, dan penting untuk dipahami, bukan sekadar
dihafal.

Setiap container punya `localhost` sendiri. Dari dalam terminal penyerang,
`http://localhost:3000` menunjuk ke terminal penyerang itu sendiri, bukan ke target.
Yang benar adalah memanggil target dengan **nama layanannya**:

```
curl http://juiceshop:3000/
```

Ringkasnya:

| Anda mengetik dari | Alamat yang benar |
|---|---|
| Browser di laptop Anda | `http://localhost:<port yang disebut ./lab info>` |
| Terminal penyerang `./lab sh` | `http://<nama-layanan>:<port asli layanan itu>` |

### Periksa 5. Anda mengetik https padahal labnya http

Lab di repo ini memakai `http://`. Browser modern sering diam-diam mengubahnya menjadi
`https://` dan hasilnya gagal tersambung. Ketik `http://` secara lengkap.

### Kalau lima-limanya sudah dicek

Nyalakan ulang labnya dari nol:

```
./lab reset 05
```

Masih gagal, panggil instruktur dan tunjukkan keluaran `./lab logs 05`.

---

## 7. Antivirus menghapus perkakas

### Gejalanya

Berkas di dalam folder repo hilang sendiri. Atau `./lab up` mengeluh berkas tidak
ditemukan padahal Anda tidak menghapus apa pun. Atau muncul notifikasi keamanan yang
menyebut nama seperti `HackTool`, `RiskWare`, atau `PUA`.

### Sebabnya

Ini bukan tanda laptop Anda terinfeksi, dan bukan tanda materi kelas berbahaya. Perkakas
pengujian keamanan memang dikenali oleh antivirus sebagai perkakas pengujian keamanan.
Daftar kata sandi umum, berkas `.war` untuk diunggah ke Tomcat, dan pemindai jaringan
semuanya termasuk kategori yang wajar dicurigai kalau ditemukan di laptop biasa. Antivirus
tidak tahu bahwa Anda sedang mengikuti kelas.

### Obatnya

Yang benar adalah **mengecualikan satu folder**, bukan mematikan antivirus. Mematikan
antivirus seluruhnya di laptop yang Anda pakai sehari-hari adalah harga yang terlalu mahal
untuk satu minggu kelas.

Di Windows, dengan Windows Security bawaan:

1. Buka Windows Security dari Start Menu.
2. Pilih Virus and threat protection.
3. Di bagian Virus and threat protection settings, klik Manage settings.
4. Gulir ke Exclusions, klik Add or remove exclusions.
5. Klik Add an exclusion, pilih Folder, lalu arahkan ke folder repo lab Anda.

Di macOS dan Linux, antivirus bawaan tidak melakukan ini, jadi biasanya Anda tidak
terpengaruh. Kalau laptop Anda memakai antivirus pihak ketiga, cari menu yang namanya
Exclusions, Exceptions, atau Allowed list, lalu tambahkan folder repo lab.

Tiga catatan penting:

1. Kecualikan **folder repo lab saja**, bukan seluruh disk dan bukan folder Downloads.
2. Hapus pengecualian itu setelah kelas selesai. Menyisakan lubang permanen demi
   kenyamanan satu minggu bukan kebiasaan yang mau Anda bawa pulang dari kelas keamanan.
3. Kalau laptop Anda milik kantor dan pengaturan antivirusnya dikunci, Anda tidak akan
   bisa menambahkan pengecualian. Pakai laptop pribadi.

---

## 8. Launcher tidak bisa dijalankan

### Gejalanya

```
permission denied: ./lab
```

atau

```
zsh: permission denied: ./lab
```

### Sebabnya

Berkas `lab` kehilangan tanda boleh dieksekusi. Ini terjadi kalau Anda mengunduh repo
sebagai ZIP dari tombol Code di GitHub, karena format ZIP tidak menyimpan tanda itu.

### Obatnya

```
chmod +x lab
```

Cukup sekali. Kalau Anda mengambil repo lewat `git clone`, masalah ini tidak muncul sama
sekali, jadi itu cara yang disarankan.

---

## 9. Akhiran baris salah

### Gejalanya

```
/usr/bin/env: 'bash\r': No such file or directory
```

atau

```
bad interpreter: /usr/bin/env bash^M
```

### Sebabnya

Berkas skrip tersimpan dengan akhiran baris gaya Windows (CRLF), padahal bash butuh gaya
Unix (LF). Karakter `\r` yang tersisa ikut terbaca sebagai bagian dari nama program.

Repo ini sudah memasang aturan di berkas `.gitattributes` supaya git menyimpan skripnya
dengan LF di semua sistem operasi, jadi kalau Anda `git clone` masalah ini tidak muncul.

### Obatnya

Ambil ulang repo dengan git, bukan dengan mengunduh ZIP dan bukan dengan menyalinnya lewat
editor teks:

```
git clone https://github.com/muff1nmigi/ceh-lab.git
```

Kalau Anda pernah menyetel `core.autocrlf` menjadi `true`, kembalikan dulu sebelum clone
ulang:

```
git config --global core.autocrlf false
```

---

## 10. Docker sedang di mode Windows containers

### Gejalanya

Launcher berhenti dengan pesan yang menyebut mode container Windows.

### Sebabnya

Docker Desktop di Windows bisa menjalankan container Linux atau container Windows, dan
hanya satu mode aktif pada satu waktu. Semua lab di repo ini adalah container Linux.

### Obatnya

Klik kanan ikon Docker di taskbar, pilih `Switch to Linux containers`. Tunggu Docker
Desktop menyala kembali, lalu ulangi perintah Anda.
