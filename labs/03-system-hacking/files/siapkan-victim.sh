#!/bin/bash
# Dijalankan sekali saat container "victim" nyala, lewat kait /custom-cont-init.d
# milik image linuxserver/openssh-server. Isinya sengaja bikin mesin ini rapuh
# dengan TIGA cara yang berbeda, karena tiga-tiganya keluar di exam CEH modul 6.
#
# Kenapa disiapkan lewat skrip yang di-mount, bukan lewat Dockerfile kedua:
# supaya lab ini cuma punya SATU build (Domain Controller). Menambah build
# kedua berarti menambah lima menit lagi ke persiapan peserta, dan isi berkas
# ini semuanya hal yang bisa dikerjakan saat container nyala.
#
# CATATAN AMAN: container ini duduk di jaringan lab yang internal. Root di
# dalam sini bukan root di laptop peserta.
set -u

PENGGUNA="${USER_NAME:-magang}"

# ---------------------------------------------------------------------------
# 1. SALAH KONFIGURASI SUDO
# ---------------------------------------------------------------------------
# awk boleh dijalankan sebagai root tanpa sandi. Kelihatannya sepele, padahal
# awk bisa memanggil system(), jadi ini sama saja memberikan shell root.
# Pola yang sama muncul di dunia nyata dengan tar, find, vi, dan less.
echo "${PENGGUNA} ALL=(root) NOPASSWD: /usr/bin/awk" >> /etc/sudoers

# ---------------------------------------------------------------------------
# 2. BIT SUID DI BINER YANG SALAH
# ---------------------------------------------------------------------------
# find punya -exec. Dengan bit SUID root, -exec ikut jalan sebagai root.
chmod u+s /usr/bin/find

# ---------------------------------------------------------------------------
# 3. CRON MILIK ROOT MENJALANKAN SKRIP YANG BISA DITULIS SIAPA SAJA
# ---------------------------------------------------------------------------
# Skripnya 0777. Siapa pun yang bisa menulis ke situ menentukan apa yang
# dijalankan root satu menit kemudian.
mkdir -p /opt/backup
cat > /opt/backup/backup.sh <<'SKRIP'
#!/bin/sh
# Backup harian. Dijalankan cron milik root tiap menit selama lab hidup.
date >> /var/log/backup.log
SKRIP
chmod 0777 /opt/backup/backup.sh
mkdir -p /etc/crontabs
cat > /etc/crontabs/root <<'CRON'
# Cron milik root. Berkas ini sengaja bisa dibaca semua pengguna.
* * * * * /opt/backup/backup.sh
CRON
# Urutannya penting dan ini sudah kena sekali waktu diuji: "crontab -u"
# menulis ulang berkasnya dengan izin 0600, jadi chmod HARUS sesudahnya.
# Kalau dibalik, peserta tidak bisa membaca jadwal cron dan jalur ketiga ini
# jadi tidak bisa ditemukan sama sekali.
crontab -u root /etc/crontabs/root 2>/dev/null
chmod 0644 /etc/crontabs/root

# ---------------------------------------------------------------------------
# Bukti yang cuma bisa dibaca root, dipakai peserta buat menutup langkahnya
# ---------------------------------------------------------------------------
printf 'CEH-LAB-03 root di victim tercapai\n' > /root/bukti-root.txt
chmod 600 /root/bukti-root.txt

# Sandi root diisi supaya /etc/shadow punya sesuatu untuk dipecahkan di
# tantangan tambahan. Nilainya ada di files/kandidat.txt.
echo "root:Welcome1" | chpasswd

echo "[lab03] victim siap: sudo awk, SUID find, cron world-writable"
