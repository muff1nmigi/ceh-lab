# Pasang Docker di Windows

Perkiraan waktu 25 sampai 40 menit, termasuk dua kali restart. Kerjakan di rumah, jangan
di kelas.

Anda butuh hak administrator di laptop ini. Kalau laptopnya milik kantor dan dikunci
kebijakan perusahaan, kemungkinan besar pemasangan akan gagal di tengah jalan. Pakai
laptop pribadi.

## Yang dibutuhkan

| Hal | Minimal |
|---|---|
| Windows | Windows 11, atau Windows 10 64-bit versi 22H2 (build 19045) ke atas |
| RAM | 8 GB |
| Sisa disk kosong | 25 GB |
| Virtualisasi di BIOS | Harus aktif, cara ceknya di Langkah 1 |
| Hak administrator | Wajib |

Cara melihat versi Windows Anda: tekan tombol Windows, ketik `winver`, tekan Enter.

---

## Langkah 1. Pastikan virtualisasi aktif

Docker di Windows berjalan di atas WSL2, dan WSL2 butuh fitur virtualisasi prosesor. Kalau
fitur ini mati, semua langkah berikutnya akan gagal dengan pesan yang membingungkan. Jadi
periksa duluan.

1. Klik kanan taskbar, pilih Task Manager.
2. Buka tab Performance, klik CPU.
3. Lihat baris **Virtualization**.

Kalau tertulis `Enabled`, lanjut ke Langkah 2.

Kalau tertulis `Disabled`, Anda harus menyalakannya di BIOS atau UEFI:

1. Restart laptop, dan saat logo pabrikan muncul tekan tombol masuk BIOS berulang kali.
   Tombolnya beda per merek, umumnya F2, F10, Del, atau Esc. Kalau tidak tahu, cari
   "masuk BIOS" plus merek laptop Anda.
2. Cari menu yang namanya Advanced, CPU Configuration, atau Security.
3. Cari opsi bernama `Intel Virtualization Technology`, `Intel VT-x`, atau `SVM Mode`
   untuk prosesor AMD. Ubah ke `Enabled`.
4. Simpan dan keluar, biasanya tombol F10.
5. Setelah Windows menyala, periksa lagi lewat Task Manager.

---

## Langkah 2. Pasang WSL2

Buka PowerShell **sebagai Administrator**. Caranya: tekan tombol Windows, ketik
`powershell`, klik kanan Windows PowerShell, pilih Run as administrator.

Jalankan:

```
wsl --install
```

Perintah ini memasang komponen WSL2 sekaligus satu distribusi Linux. Biarkan sampai
selesai, jangan ditutup di tengah jalan.

## Langkah 3. RESTART LAPTOP ANDA

**Ini langkah yang paling sering dilewatkan, dan melewatkannya membuat semua langkah
sesudahnya gagal.**

WSL2 belum benar-benar aktif sampai laptop di-restart. Bukan sign out, bukan tutup layar,
tapi **restart**.

Kalau nanti Docker Desktop menolak menyala dan menyebut-nyebut WSL, sembilan dari sepuluh
kali jawabannya adalah restart yang belum dilakukan di titik ini.

Setelah menyala kembali, buka PowerShell biasa dan periksa:

```
wsl --status
wsl --version
```

Yang Anda cari: `Default Version: 2`. Kalau bukan 2, jalankan:

```
wsl --set-default-version 2
wsl --update
```

---

## Langkah 4. Pasang Docker Desktop

1. Buka <https://www.docker.com/products/docker-desktop/> dan unduh installer untuk
   Windows. Berkasnya sekitar 500 MB sampai 1 GB, jadi pakai koneksi yang stabil.
2. Jalankan `Docker Desktop Installer.exe`.
3. Di layar Configuration, pastikan opsi **Use WSL 2 instead of Hyper-V** dicentang.
4. Klik Ok dan tunggu. Pemasangan minta izin administrator, izinkan.
5. Kalau installer meminta restart di akhir, **restart lagi**. Jangan ditunda.

## Langkah 5. Nyalakan Docker Desktop pertama kali

1. Buka Docker Desktop dari Start Menu.
2. Muncul kotak persetujuan **Docker Subscription Service Agreement**. Baca sekilas, lalu
   klik Accept. Docker Desktop gratis untuk pemakaian pribadi dan pendidikan.
3. Kalau diminta membuat akun atau mengisi survei, Anda boleh melewatinya. Akun Docker
   tidak wajib untuk kelas ini.
4. Tunggu sampai indikator di kiri bawah jendela Docker Desktop berubah menjadi
   **Engine running**. Penyalaan pertama bisa memakan waktu 1 sampai 3 menit.

Kalau ikon Docker di taskbar menawarkan `Switch to Windows containers`, jangan diklik.
Lab ini butuh mode Linux containers, dan itu memang mode bawaannya.

---

## Langkah 6. Uji hasilnya

Buka PowerShell biasa, masuk ke folder repo lab, lalu jalankan:

```
docker version
docker compose version
```

Dua-duanya harus menampilkan nomor versi, bukan pesan error.

Setelah itu jalankan pemeriksa kesiapan bawaan repo ini:

```
.\lab.cmd doctor
```

Yang Anda kejar adalah baris terakhir `SEMUA HIJAU`.

Kalau ada yang merah atau kuning, catat pesannya lalu buka
[04-kalau-macet.md](04-kalau-macet.md).

---

## Dua hal yang perlu Anda tahu

### Simpan repo lab di disk lokal

Taruh folder repo di `C:\Users\<nama-anda>\ceh-lab` atau tempat sejenis. Hindari
menaruhnya di dalam folder OneDrive atau di drive jaringan. Sinkronisasi yang berjalan
di latar belakang bisa mengunci berkas saat Docker sedang memakainya, dan gejalanya
susah dikenali.

### Kalau Docker kebagian RAM terlalu sedikit

`.\lab.cmd doctor` akan memberi tahu kalau RAM untuk Docker di bawah 6 GB. Di Windows,
jatah RAM itu diatur lewat berkas konfigurasi WSL2, bukan lewat menu Docker Desktop.

Buat berkas `C:\Users\<nama-anda>\.wslconfig` dengan isi:

```
[wsl2]
memory=8GB
```

Lalu di PowerShell jalankan:

```
wsl --shutdown
```

Buka lagi Docker Desktop, tunggu `Engine running`, lalu jalankan `.\lab.cmd doctor` sekali
lagi.
