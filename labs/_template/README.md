# Lab __ID__ - __JUDUL__

Modul CEH __MODUL__ - __MODUL_NAMA__ | 45 menit | Level 2

## Yang dibuktikan di lab ini

Satu kalimat. Bukan daftar fitur, tapi apa yang Anda buktikan sendiri di akhir
jam ini.

## Menyalakan

```
./lab up __ID__          # macOS, Linux
.\lab.cmd up __ID__      # Windows
```

Buka: http://localhost:PORT
Terminal penyerang: `./lab sh __ID__`

## Peta lab

| Container | Perannya | Alamat dari dalam toolbox |
|---|---|---|
| toolbox | tempat Anda mengetik | - |
| target | yang diserang | `target` port 80 |

Dari dalam toolbox, panggil target memakai NAMANYA, bukan localhost.
`curl http://target/` jalan, `curl http://localhost/` tidak jalan.
Alasannya: setiap container punya localhost sendiri.

## Langkah

### 1. Pemetaan

```
nmap -sV -p- target
```

Yang dicari: layanan apa yang terbuka, dan versinya berapa.

<details><summary>Kalau macet, buka ini</summary>

Kalau nmap menjawab "0 hosts up", container target belum siap.
Tunggu 20 detik lalu ulangi. Masih gagal, jalankan `./lab reset __ID__`.
</details>

### 2. Eksploitasi

```
perintahnya di sini
```

Yang dicari: bukti konkret, misalnya isi berkas `/flag.txt`.

<details><summary>Kalau macet, buka ini</summary>

Petunjuk bertahap. Petunjuk, bukan jawaban.
</details>

### 3. Bukti

Salin keluaran ini ke catatan Anda. Kalau di kelas ada review, ini yang dibaca.

```
target:
temuan:
bukti:
```

## Ceklis, diisi sendiri

- [ ] Saya menemukan port dan versi layanannya
- [ ] Saya mendapat akses
- [ ] Saya bisa menjelaskan KENAPA ini jalan, bukan cuma menyalin perintahnya
- [ ] Saya tahu mitigasinya apa

## Nyambung ke exam

Poin CEH yang keluar dari lab ini, tulis 2 sampai 4 baris. Pakai istilah persis
yang dipakai di soal, bukan parafrase.

## Membereskan

```
./lab down __ID__
```

## Pagar

Target lab ini cuma container di dalam compose lab ini.

Pagarnya bukan cuma imbauan. Jaringan lab dibuat internal, jadi dari dalam
toolbox memang tidak ada jalan keluar sama sekali: bukan ke internet, bukan ke
jaringan kelas, bukan ke laptop peserta lain. Kalau Anda mengarahkan nmap ke
subnet kelas, nmap menjawab "failed to determine route" dan nol host discan.
Itu perilaku yang benar, bukan kerusakan.

Alasannya sederhana. Kelas ini berjalan di jaringan kantor yang bukan milik
kita, dan memindai jaringan orang lain tanpa izin tertulis itu bukan latihan,
itu masalah hukum. Yang boleh Anda serang cuma yang disebut di tabel Peta lab
di atas.
