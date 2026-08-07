# Wordlist bersama

Folder ini di-mount read-only ke `/wordlists` di dalam toolbox oleh
`_shared/compose.base.yaml`. Isinya ada di setiap lab tanpa perlu disalin ulang
per lab, dan tetap ada walau lab yang menyala tidak punya wordlist sendiri.

## Isinya

| Berkas | Baris | Dipakai untuk |
|---|---|---|
| `passwords.txt` | 100 | `hydra -P` dan `john --wordlist` |
| `users.txt` | 74 | `hydra -L` |
| `dirs.txt` | 136 | `gobuster dir -w` |

Contoh pemakaian dari dalam toolbox:

```
hydra -L /wordlists/users.txt -P /wordlists/passwords.txt -t 4 -f <target> http-get /
gobuster dir -u http://<target>/ -w /wordlists/dirs.txt -t 10
john --format=raw-md5 --wordlist=/wordlists/passwords.txt hash.txt
```

## Tiga tempat wordlist, dan bedanya

| Jalur | Asalnya | Kapan ada |
|---|---|---|
| `/usr/share/wordlists/rockyou-kecil.txt` | ikut ke dalam image toolbox | selalu, walau nol lab menyala |
| `/wordlists/` | folder ini, lewat mount | selalu, di lab mana pun |
| `/lab/wordlists/` dan `/lab/files/` | folder lab yang sedang menyala | cuma di lab yang memang punya |

Yang di `/lab` sengaja pendek dan disetel buat satu latihan tertentu, supaya
langkahnya selesai dalam hitungan detik di depan kelas. Yang di sini umum dan
dipakai lintas lab.

## Kenapa nol tumpang tindih dengan rockyou-kecil.txt

`passwords.txt` disusun supaya **tidak ada satu pun** barisnya yang sudah ada di
`/usr/share/wordlists/rockyou-kecil.txt`. Alasannya bukan kerapian. Kalau Anda
menggabung dua berkas itu, tiap baris kembar berubah jadi satu tebakan yang
percuma, dan pada serangan online tebakan percuma itu berarti waktu terbuang
plus satu baris log tambahan di sisi target yang membuat Anda lebih cepat
kelihatan.

Jadi dua berkas itu memang dirancang untuk disambung:

```
cat /usr/share/wordlists/rockyou-kecil.txt /wordlists/passwords.txt > /lab/gabungan.txt
sort -u /lab/gabungan.txt | wc -l
```

Hasilnya 302, sama persis dengan 202 tambah 100. Nol baris yang hilang karena
kembar. Silakan dibuktikan sendiri, itu latihan yang bagus.

## Kenapa nol baris komentar di dalam berkas .txt

Baris yang diawali `#` di dalam wordlist BUKAN komentar. Tidak satu pun dari
tiga perkakas yang dipakai di kelas ini melewatinya. Diuji di dalam
`ceh-toolbox:1.0` pada 2026-08-06 dengan wordlist tiga baris berisi satu baris
komentar, satu baris kosong, dan satu kata sungguhan:

| Perkakas | Yang terjadi pada baris `# ini baris komentar` |
|---|---|
| `hydra` | dikirim sebagai sandi, terlihat di header Basic auth sisi server |
| `gobuster` | diminta sebagai path, tercatat sebagai `GET /%23%20ini%20baris%20komentar` |
| `john` | keluar sebagai kandidat di `john --stdout` |

Baris kosong bernasib sama. hydra mengirim sandi kosong, john memakainya
sebagai kandidat.

Artinya satu baris judul yang ditaruh di dalam wordlist berubah jadi tebakan
sampah yang benar-benar terkirim ke target. Karena itu semua keterangan soal
wordlist ditulis di berkas README ini, dan berkas `.txt` di folder ini isinya
kandidat saja, nol komentar dan nol baris kosong.

## Urutan isi passwords.txt bukan acak

hydra mencoba dari baris pertama ke bawah, jadi urutan menentukan berapa cepat
sebuah sandi ketemu. Lima blok, berurutan:

1. Pola angka dan pola papan ketik
2. Sandi klasik yang belum ada di rockyou-kecil
3. Nama merek dan layanan
4. Bentuk yang lolos kebijakan sandi, huruf besar plus angka plus simbol
5. Kata Indonesia, nama kota, dan nama layanan lokal

Blok kelima yang paling sering dilewatkan orang, dan justru itu yang paling
sering kena di sini. Wordlist berbahasa Inggris yang Anda unduh dari internet
tidak akan pernah berisi `merahputih`, `bismillah`, atau `indihome`. Pelajaran
yang dibawa pulang dari folder ini cuma satu kalimat: **wordlist mengikuti
bahasa dan kebiasaan target, bukan bahasa perkakasnya.**

Hal yang sama berlaku untuk `users.txt`. Nama akun seperti `keuangan`,
`personalia`, dan `magang` tidak ada di daftar mana pun yang disusun di luar
negeri, padahal itu justru yang terpasang di banyak jaringan kantor di sini.

## Kenapa users.txt boleh mengulang isi daftar sandi

Anda akan melihat `admin`, `root`, dan `tomcat` muncul di `users.txt` padahal
kata yang sama juga ada di daftar sandi. Itu bukan kembar, karena perannya
berbeda. `hydra -L` memakainya sebagai nama pengguna, `hydra -P` memakainya
sebagai sandi, dan salah satu kombinasi yang paling sering berhasil di dunia
nyata adalah nama pengguna yang dipakai ulang sebagai sandinya sendiri.

`Administrator` ditulis dua kali, huruf besar dan huruf kecil, dengan sengaja.
Active Directory tidak membedakan huruf besar kecil pada nama akun, jadi di lab
03 satu ejaan saja sudah cukup. Layanan lain membedakan, dan Anda tidak selalu
tahu sedang berhadapan dengan yang mana sebelum mencoba. Dua baris jauh lebih
murah daripada satu akun yang terlewat.

## Aturan pakai

Wordlist ini bahan ajar. Sasarannya cuma container di dalam lab yang sedang
Anda nyalakan, dipanggil dengan nama layanannya. Membawa daftar ini ke sistem
yang bukan milik Anda, tanpa izin tertulis, bukan latihan lagi. Baca ulang
bagian "Aturan main" di README utama repo.
