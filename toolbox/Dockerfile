# ============================================================================
# ceh-toolbox: terminal penyerang untuk lab CEH Course-Net.
#
# Image ini DI-BUILD LOKAL di laptop peserta, bukan ditarik dari registry.
# Alasannya menghilangkan tiga penyebab gagal sekaligus:
#   1. image di registry ternyata tidak ada,
#   2. paket GHCR default-nya private, jadi tarikan ditolak,
#   3. Docker Hub membatasi 100 tarikan per jam per IP untuk pengguna anonim.
# Yang tetap ditarik hanya satu, yaitu basis kalilinux/kali-rolling, dan itu
# sudah dipastikan punya varian arm64 maupun amd64 sehingga jalan native di
# laptop Apple Silicon maupun Intel/AMD. Paket-paketnya sendiri datang dari
# http.kali.org, bukan dari Docker Hub, jadi tidak kena batas tarikan itu.
#
# Cara build, jalankan dari akar repo:
#   macOS dan Linux :  bash toolbox/build.sh     atau  ./lab build
#   Windows         :  .\toolbox\build.ps1       atau  .\lab.cmd build
#
# Catatan hashcat: hashcat sengaja TIDAK dipasang. Di dalam container, baik
# arm64 maupun amd64, hashcat selalu berhenti dengan "No devices found/left"
# karena paket pocl-opencl-icd tidak tersedia di repo Kali. Untuk praktik
# password cracking dipakai john the ripper. Nama hashcat tetap perlu dihafal
# karena keluar di ujian, tetapi tidak dipakai di langkah praktik.
# ============================================================================

FROM kalilinux/kali-rolling:latest

LABEL org.opencontainers.image.title="ceh-toolbox"
LABEL org.opencontainers.image.description="Terminal penyerang untuk lab CEH Course-Net. Build lokal, multiarch."
LABEL org.opencontainers.image.source="https://github.com/muffinmigi/ceh-lab"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TERM=xterm-256color \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/.local/bin \
    PIP_ROOT_USER_ACTION=ignore

# ---------------------------------------------------------------------------
# Satu layer untuk pasang plus bersih-bersih. Kalau dipisah jadi dua layer,
# berkas yang dihapus tetap ikut terbawa di layer sebelumnya dan ukurannya
# tidak turun sama sekali.
# ---------------------------------------------------------------------------
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      openssl \
      libcap2-bin \
      procps \
      iproute2 \
      iputils-ping \
      less \
      nano \
      vim-tiny \
      jq \
      unzip \
      git \
      curl \
      wget \
      whois \
      bind9-dnsutils \
      bind9-host \
      openssh-client \
      ftp \
      tcpdump \
      nmap \
      ncat \
      netcat-traditional \
      netcat-openbsd \
      smbclient \
      ldap-utils \
      enum4linux \
      enum4linux-ng \
      nikto \
      gobuster \
      sqlmap \
      hydra \
      john \
      python3 \
      python3-pip \
      python3-venv \
      pipx \
    ; \
    apt-get clean; \
    rm -rf \
      /var/lib/apt/lists/* \
      /var/cache/apt/archives/* \
      /usr/share/doc/* \
      /usr/share/man/* \
      /usr/share/locale/?? \
      /usr/share/locale/??_* \
      /tmp/* \
      /var/tmp/*

# ---------------------------------------------------------------------------
# Wordlist. Dua sumber, sengaja dipisah supaya jelas mana yang selalu ada.
#
#   /usr/share/wordlists/rockyou-kecil.txt  ikut ke dalam image, selalu ada,
#                                           cukup untuk demo cracking di kelas.
#   /wordlists                              titik mount dari repo, diisi oleh
#                                           _shared/wordlists lewat ./lab up.
#
# rockyou penuh (133 MB) sengaja tidak dibawa. Ukurannya membengkakkan image
# tanpa menambah apa pun yang dipelajari peserta, dan untuk demo di kelas
# justru merugikan karena john jadi lama selesainya.
# ---------------------------------------------------------------------------
COPY wordlists/rockyou-kecil.txt /usr/share/wordlists/rockyou-kecil.txt

RUN set -eux; \
    mkdir -p /wordlists /lab; \
    ln -sf /usr/share/wordlists/rockyou-kecil.txt /usr/share/wordlists/kecil.txt

# ---------------------------------------------------------------------------
# Buang file capability dari binari nmap. Ini WAJIB, bukan penghalusan.
#
# Paket nmap Kali menaruh cap_net_bind_service,cap_net_admin,cap_net_raw=eip
# di /usr/lib/nmap/nmap. CAP_NET_ADMIN tidak ada di daftar capability bawaan
# Docker, dan kernel menolak exec berkas yang minta capability di luar daftar
# itu. Akibatnya nmap mati sebelum jalan dengan pesan yang menyesatkan:
#
#   /usr/bin/nmap: 6: exec: /usr/lib/nmap/nmap: Operation not permitted
#
# Peserta akan mengira nmap-nya rusak, padahal ini soal capability. Setelah
# capability berkasnya dibuang, nmap memakai capability milik container.
# _shared/compose.base.yaml memberi NET_RAW, dan itu sudah cukup: diuji
# 2026-08-06 di dalam stack compose asli, nmap -sS mengirim SYN mentah lalu
# membalas RST tanpa menyelesaikan handshake, jadi tetap SYN scan sungguhan.
# Kalau NET_RAW dicabut, nmap TIDAK turun diam-diam ke connect scan, dia
# berhenti dengan "Couldn't open a raw socket", yang justru bagus karena
# kegagalannya kelihatan.
# ---------------------------------------------------------------------------
RUN set -eux; \
    setcap -r /usr/lib/nmap/nmap; \
    getcap /usr/lib/nmap/nmap || true; \
    nmap --version | head -1

# ---------------------------------------------------------------------------
# Gerbang mutu, jalan saat build di laptop peserta, bukan cuma di laptop
# instruktur. Kalau satu saja perkakas inti tidak ada, build berhenti di sini
# dengan pesan yang jelas. Lebih baik gagal sekarang daripada gagal hari-H
# di tengah latihan.
# ---------------------------------------------------------------------------
RUN set -eu; \
    gagal=0; \
    for t in nmap ncat nc dig host whois curl wget git python3 pipx \
             smbclient ldapsearch enum4linux enum4linux-ng nikto gobuster \
             sqlmap hydra john tcpdump ip ping nano less jq unzip ssh ftp; do \
      if ! command -v "$t" >/dev/null 2>&1; then \
        echo "GAGAL: perkakas '$t' tidak terpasang"; gagal=1; \
      fi; \
    done; \
    [ -s /usr/share/wordlists/rockyou-kecil.txt ] || { echo "GAGAL: wordlist kosong"; gagal=1; }; \
    nmap --version >/dev/null 2>&1 || { echo "GAGAL: nmap terpasang tetapi tidak bisa dijalankan"; gagal=1; }; \
    john --list=build-info >/dev/null 2>&1 || { echo "GAGAL: john terpasang tetapi tidak bisa dijalankan"; gagal=1; }; \
    [ "$gagal" -eq 0 ] || { echo "Build dihentikan. Kirim keluaran ini ke instruktur."; exit 1; }; \
    echo "Semua perkakas inti terpasang."

# ---------------------------------------------------------------------------
# Perintah bantu, dipanggil peserta kalau lupa apa saja yang ada di sini.
# ---------------------------------------------------------------------------
RUN set -eu; \
    printf '%s\n' \
      '#!/bin/sh' \
      'echo "ceh-toolbox, terminal penyerang lab CEH Course-Net"' \
      'echo "arsitektur : $(uname -m)"' \
      'echo "wordlist   : /usr/share/wordlists/rockyou-kecil.txt (bawaan image)"' \
      'echo "             /wordlists (dari repo, hanya kalau lab lagi nyala)"' \
      'echo "kerja di   : /lab"' \
      'echo' \
      'echo "Versi perkakas inti:"' \
      'nmap --version 2>/dev/null | head -1' \
      'printf "john "; john --list=build-info 2>/dev/null | head -1' \
      'printf "smbclient "; smbclient --version 2>/dev/null' \
      'printf "sqlmap "; sqlmap --version 2>/dev/null' \
      'gobuster --version 2>/dev/null | head -1' \
      'hydra -h 2>&1 | head -1 | cut -c1-14' \
      'nikto -Version 2>/dev/null | head -1' \
      'echo' \
      'echo "Perkakas lain yang siap dipakai:"' \
      'echo "  jaringan  : ncat, nc, nc.traditional, tcpdump, ip, ping"' \
      'echo "  DNS       : dig, host, whois"' \
      'echo "  SMB dan AD: smbclient, enum4linux, enum4linux-ng, ldapsearch"' \
      'echo "  web       : curl, wget, gobuster, nikto, sqlmap"' \
      'echo "  lain      : ssh, ftp, git, python3, pipx, jq, unzip, nano, less"' \
      'echo' \
      'echo "hashcat sengaja tidak ada. Di dalam container hashcat selalu"' \
      'echo "berhenti dengan No devices found. Pakai john untuk cracking."' \
      > /usr/local/bin/toolbox-info; \
    chmod 0755 /usr/local/bin/toolbox-info

WORKDIR /lab

# Compose menimpa command ini dengan "tail -f /dev/null" supaya container
# tetap hidup dan peserta masuk lewat ./lab sh. Kalau image dijalankan
# sendirian tanpa compose, yang keluar shell interaktif.
CMD ["/bin/bash"]
