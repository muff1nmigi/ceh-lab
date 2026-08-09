# Menyiapkan Kali VM

Semua lab di repo ini dikerjakan **di dalam Kali VM kalian**, bukan di laptop langsung.
Kali VM sudah jadi syarat masuk kelas, jadi panduan ini bukan cara memasangnya dari nol,
melainkan cara memastikan VM yang sudah ada cukup sehat untuk dipakai lima hari.

Kalau VM kalian belum ada sama sekali, kabari instruktur hari ini juga, jangan menunggu
hari pertama.

---

## Kenapa di dalam VM, bukan di laptop

Tiga alasan, dan yang ketiga yang paling penting.

Pertama, seragam. Semua orang berada di Kali yang sama, jadi perintah yang muncul di slide
jalan apa adanya di layar kalian.

Kedua, bersih. Selesai kelas, VM-nya bisa kalian hapus dan laptop kalian kembali seperti
semula. Tidak ada sisa tool keamanan yang bikin antivirus kantor rewel di kemudian hari.

Ketiga, dan ini soal keamanan: target lab sengaja dikurung supaya tidak bisa menyentuh
jaringan kelas. Pagar itu dibangun di lapisan jaringan Docker **di dalam VM**. Kalau kalian
menjalankan lab di laptop langsung, pagarnya berdiri di tempat yang berbeda dan satu
perintah yang salah arah bisa keluar ke jaringan Course-Net. Itu bukan latihan lagi.

---

## Ukuran VM yang dibutuhkan

| Hal | Minimal | Enaknya |
|---|---|---|
| RAM | 6 GB | 8 GB |
| CPU | 2 vCPU | 4 vCPU |
| Disk kosong DI DALAM VM | 30 GB | 40 GB |

Angka disk itu ruang kosong di dalam Kali, bukan ukuran file VM di laptop kalian.
Cek dengan `df -h /` di Terminal Kali, lihat kolom Avail.

### Cara menaikkan RAM

Matikan dulu VM-nya, jangan di-suspend.

| Aplikasi VM | Jalannya |
|---|---|
| VirtualBox | Pilih VM, Settings, System, geser Base Memory |
| VMware Workstation Pro | Pilih VM, Edit virtual machine settings, Memory |
| VMware Fusion | Pilih VM, Settings, Processors and Memory |
| Parallels Desktop | Pilih VM, Configure, Hardware, CPU and Memory |
| UTM | Pilih VM, Edit, System, Memory |

Jangan memberikan lebih dari setengah RAM laptop kalian. Laptop 8 GB berarti VM 4 GB,
dan itu di bawah minimal, jadi kabari instruktur kalau kalian di posisi itu.

---

## Pastikan internet dari dalam VM jalan

Nyalakan VM, buka Terminal di dalam Kali, lalu:

```
curl -sI https://github.com | head -1
```

Yang kalian tunggu `HTTP/2 200`.

Kalau yang muncul justru pesan semacam `TLS connect error` atau `handshake failed`,
**jangan diutak-atik sendiri**. Itu biasanya bukan salah Kali, melainkan jaringan atau
router yang memperlakukan perangkat baru secara berbeda. Kabari instruktur beserta
tampilan pesannya, biasanya selesai dengan mengganti mode jaringan VM.

Kalau kalian mau mencoba satu hal sebelum bertanya, ganti mode jaringan VM dari Bridged
menjadi NAT, lalu ulangi perintah di atas. Mode NAT membuat VM keluar memakai identitas
laptop kalian, dan itu sering langsung menyelesaikan masalahnya.

---

## Pastikan jam VM benar

```
date
```

Zona waktunya boleh apa saja, yang penting jamnya tidak meleset jauh. Jam yang salah
membuat validasi sertifikat gagal, dan gejalanya mirip sekali dengan masalah jaringan.

Kalau perlu diluruskan:

```
sudo timedatectl set-ntp true
sudo timedatectl set-timezone Asia/Jakarta
```

---

## Berikutnya

Kalau tiga hal di atas beres, lanjut ke
[02-pasang-docker-di-kali.md](02-pasang-docker-di-kali.md).
