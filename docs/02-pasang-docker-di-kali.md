# Memasang Docker di dalam Kali

Semua perintah di halaman ini dijalankan **di Terminal, di dalam Kali VM kalian**.
Semuanya sudah diuji di Kali 2026.2 sebelum diberikan ke kalian, jadi kalau ada yang
berperilaku beda, itu layak dilaporkan.

Perkiraan waktu 10 menit, sebagian besarnya menunggu unduhan.

---

## Langkah 1. Pasang paketnya

```
sudo apt update
sudo apt install -y docker.io docker-cli docker-compose git curl
```

**Perhatikan namanya `docker-compose`.** Banyak panduan di internet menyebut
`docker-compose-v2`, dan paket dengan nama itu **tidak ada di repo Kali**. Kalau kalian
mengetiknya, apt berhenti dengan `Unable to locate package` dan **tidak memasang satu pun
paket lain di baris yang sama**, termasuk Docker. Gejalanya membingungkan karena kelihatan
seperti Docker gagal dipasang, padahal yang salah cuma satu nama.

Meskipun namanya `docker-compose`, yang terpasang adalah Compose versi 2, dan perintahnya
`docker compose` dengan spasi, bukan `docker-compose` dengan tanda hubung.

---

## Langkah 2. Nyalakan layanannya

```
sudo systemctl enable --now docker
```

`enable` membuatnya ikut menyala setiap VM dinyalakan, `--now` menyalakannya sekarang juga.

---

## Langkah 3. Izinkan user kalian memakai Docker tanpa sudo

```
sudo usermod -aG docker $USER
```

**Setelah perintah ini, keluar dari sesi lalu masuk lagi, atau restart VM-nya.**
Keanggotaan grup baru terbaca saat sesi baru dimulai. Tanpa itu setiap perintah docker
akan menjawab `permission denied` dan kalian akan tergoda memakai sudo terus, yang bikin
file hasil kerja jadi milik root dan menyusahkan di lab berikutnya.

---

## Langkah 4. Pastikan berhasil

```
docker --version
docker compose version
docker run --rm hello-world
```

Tiga-tiganya harus menjawab, dan yang terakhir mencetak `Hello from Docker!`.

Kalau `docker compose version` menjawab bahwa perintahnya tidak dikenal, berarti paket
`docker-compose` belum masuk. Ulangi langkah 1 dan baca keluarannya sampai habis,
jangan cuma melihat baris terakhir.

Kalau `docker run` menjawab `permission denied`, berarti langkah 3 belum berlaku.
Keluar dari sesi lalu masuk lagi.

---

## Langkah 5. Ambil repo lab dan periksa kesiapan

```
git clone https://github.com/muff1nmigi/ceh-lab.git
cd ceh-lab
./lab doctor
```

`./lab doctor` memeriksa Docker, arsitektur, RAM, sisa disk, dan koneksi ke registry.
Yang kalian kejar baris terakhirnya `SEMUA HIJAU`.

Kalau ada baris kuning yang tidak hilang:

```
./lab doctor --report
```

Perintah itu menulis satu file di folder repo. Kirim file itu ke instruktur, bukan
tangkapan layar, karena isinya jauh lebih lengkap.

---

## Langkah 6. Bangun terminal penyerang

```
./lab build
```

Sekali saja, sekitar 4 menit dan 1,2 GB. Yang kalian tunggu:

```
OK   Toolbox siap. Tag: ceh-toolbox:1.0
```

---

## Langkah 7. Tarik bahan lab dari rumah

```
./lab pull core
```

Kerjakan ini **di rumah**, bukan di kelas. Docker membatasi 100 unduhan per jam untuk
setiap alamat internet, dan di kelas kita semua berbagi satu alamat. Sepuluh orang yang
mengunduh bersamaan menghabiskan jatah itu dalam hitungan menit.

---

## Selesai

Coba lab pertama:

```
./lab up 00a
```

Buka browser **di dalam Kali**, alamatnya <http://localhost:8000>. Kalau muncul tulisan
`LAB CEH SIAP`, kalian sudah siap sepenuhnya. Matikan lagi dengan `./lab down 00a`.

Kalau ada yang macet, baca [03-kalau-macet.md](03-kalau-macet.md).
