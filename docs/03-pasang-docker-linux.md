# Pasang Docker di Linux

Perkiraan waktu 10 sampai 20 menit. Kerjakan di rumah, jangan di kelas.

Di Linux Anda tidak butuh Docker Desktop. Yang dibutuhkan cuma dua:

1. **Docker Engine**, mesin yang menjalankan container.
2. **Plugin compose**, supaya perintah `docker compose` ada. Launcher lab ini memakainya
   di hampir semua perintah.

Anda butuh akses `sudo` di laptop ini.

---

## Cara cepat, berlaku untuk hampir semua distribusi

Skrip resmi dari Docker mengenali distribusi Anda sendiri dan memasang Engine plus plugin
compose sekaligus:

```
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
```

Diunduh dulu baru dijalankan, bukan langsung disalurkan ke shell, supaya Anda sempat
membaca isinya kalau mau. Itu kebiasaan yang benar dan kelas ini kelas keamanan.

Setelah selesai, lompat ke bagian **Nyalakan layanannya**.

---

## Cara manual per distribusi

Pakai ini kalau Anda lebih suka repositori resmi distribusi Anda.

### Ubuntu dan Debian

```
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
```

Kalau Anda memakai Debian, ganti dua kemunculan `linux/ubuntu` di atas menjadi
`linux/debian`.

Peringatan yang sering menggigit: paket `docker.io` bawaan Ubuntu **tidak** membawa plugin
compose. Kalau Anda terlanjur memasang lewat jalur itu, tambahkan paketnya:

```
sudo apt-get install -y docker-compose-plugin
```

### Fedora

```
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf -y install docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
```

### Arch

```
sudo pacman -S --needed docker docker-compose
```

---

## Nyalakan layanannya

```
sudo systemctl enable --now docker
```

`enable` membuat Docker ikut menyala setiap kali laptop dinyalakan, `--now` menyalakannya
sekarang juga. Tanpa ini, Senin pagi Anda harus mengingat untuk menyalakannya manual.

Periksa:

```
systemctl status docker
```

---

## Masuk ke grup docker, supaya tidak perlu sudo terus

Ini bukan sekadar kenyamanan. Launcher `./lab` memanggil `docker` tanpa `sudo`. Kalau Anda
belum masuk grup `docker`, hampir semua perintah lab akan gagal dengan
`permission denied while trying to connect to the Docker daemon socket`.

```
sudo usermod -aG docker $USER
```

Perubahan grup **baru berlaku setelah Anda logout lalu login lagi**. Kalau tidak mau
logout untuk sesi terminal yang sedang berjalan, pakai:

```
newgrp docker
```

Perlu Anda ketahui sebagai orang keamanan: anggota grup `docker` praktis setara root di
mesin ini, karena bisa memasang berkas apa pun dari host ke dalam container. Di laptop
lab pribadi itu wajar. Di server produksi, itu keputusan yang harus dipikirkan.

---

## Uji hasilnya

```
docker version
docker compose version
```

Dua-duanya harus menampilkan nomor versi, bukan pesan error. Kalau `docker compose`
menjawab `is not a docker command`, plugin compose belum terpasang. Balik ke bagian
distribusi Anda di atas.

Lalu masuk ke folder repo lab dan jalankan pemeriksa kesiapan bawaannya:

```
./lab doctor
```

Yang Anda kejar adalah baris terakhir `SEMUA HIJAU`.

Kalau muncul `permission denied` saat menjalankan `./lab`, berkas launcher-nya belum bisa
dieksekusi. Ini terjadi kalau Anda mengunduh repo sebagai ZIP, bukan lewat git. Perbaiki
sekali saja:

```
chmod +x lab
```

Kalau ada yang merah atau kuning, catat pesannya lalu buka
[04-kalau-macet.md](04-kalau-macet.md).

---

## Catatan untuk laptop Linux berprosesor ARM

Kalau `./lab doctor` bilang emulasi amd64 tidak jalan, laptop Anda belum punya penangan
binfmt untuk arsitektur lain. Di Debian dan Ubuntu, pasang paketnya:

```
sudo apt-get install -y qemu-user-static binfmt-support
```

Lalu jalankan `./lab doctor` sekali lagi. Sebagian besar lab tetap jalan tanpa ini, jadi
kalau masih gagal, lanjut saja dan laporkan hasil `./lab doctor --report` ke instruktur.
