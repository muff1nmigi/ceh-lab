# Domain Controller Active Directory sungguhan, dibangun di laptop peserta.
#
# ===========================================================================
# KENAPA DI-BUILD, BUKAN DITARIK JADI
# ===========================================================================
# Basisnya servercontainers/samba, image multiarch yang sudah diverifikasi
# jalan native di arm64 dan amd64. Tapi image itu APA ADANYA cuma file server:
# paket yang ada di dalamnya samba-server, dan di situ TIDAK ADA samba-tool
# maupun daemon "samba" yang menjalankan peran Domain Controller.
# Diperiksa pada 2026-08-06 di dalam image tersebut:
#
#   command -v samba samba-tool   ->  dua-duanya kosong
#   apk info | grep samba         ->  samba-server, samba-client, tanpa samba-dc
#
# Jadi baris "apk add samba-dc" di bawah bukan hiasan. Itu yang mengubah file
# server jadi Domain Controller: dia yang membawa /usr/sbin/samba (KDC,
# LDAP, DNS, DRSUAPI jadi satu proses) dan /usr/bin/samba-tool.
# Paketnya diambil dari repo Alpine, bukan Docker Hub, jadi kuota 100 tarikan
# per jam itu tidak kesenggol sama sekali.
#
# Provisioning domain dikerjakan SAAT BUILD, bukan saat container nyala.
# Alasannya waktu kelas: provision makan belasan detik dan menulis ke
# /var/lib/samba. Kalau dikerjakan saat start, tiap "./lab up" bayar lagi, dan
# tiap "./lab down -v" hasilnya hilang. Dikerjakan saat build, container nyala
# dalam hitungan detik dan domainnya selalu sama persis untuk semua peserta.
#
# Waktu build terukur di mesin penyusun (arm64, basis sudah ada di disk):
# 29 detik. Yang perlu diunduh cuma paket Alpine, sekitar 55 MB.
FROM servercontainers/samba:latest

# samba-dc  : daemon Domain Controller plus samba-tool
# ldb-tools : ldbsearch dan ldbmodify, dipakai instruktur buat mengintip
#             basis data direktori dari sisi server saat menjelaskan
RUN apk add --no-cache samba-dc ldb-tools

# ---------------------------------------------------------------------------
# Provision domain CEHLAB.LOCAL
# ---------------------------------------------------------------------------
# --use-rfc2307      atribut POSIX ikut dipasang, bikin enumerasi LDAP lebih
#                    kaya dan lebih mirip domain yang beneran dipakai
# --dns-backend      SAMBA_INTERNAL, biar tidak perlu BIND terpisah
# posix:eadb         extended attribute disimpan di berkas tdb, bukan di xattr
#                    filesystem. Wajib, karena overlayfs Docker tidak selalu
#                    mendukung xattr user namespace.
RUN rm -f /etc/samba/smb.conf \
 && samba-tool domain provision \
      --use-rfc2307 \
      --realm=CEHLAB.LOCAL \
      --domain=CEHLAB \
      --server-role=dc \
      --dns-backend=SAMBA_INTERNAL \
      --host-name=DC1 \
      --option="posix:eadb=/var/lib/samba/eadb.tdb" \
      --adminpass='Passw0rd!2026'

# ---------------------------------------------------------------------------
# Isi domainnya: pengguna, grup, dan satu SPN
# ---------------------------------------------------------------------------
# Sandi dipilih dengan sengaja, dan pembagiannya yang bikin lab ini punya alur:
#
#   magang   Password1            ADA di files/kandidat.txt apa adanya.
#                                 Ini satu-satunya akun yang jatuh ke tebakan
#                                 online (hydra). Titik masuk peserta.
#   bkupadm  Backup2026!          Kata dasarnya "Backup2026" ada di wordlist,
#                                 tanda serunya TIDAK. Jadi hydra gagal, dan
#                                 john dengan aturan mangling berhasil. Itu
#                                 pelajaran intinya: tebakan online lawan
#                                 cracking offline bukan hal yang sama.
#   sisanya                       Tidak ada di wordlist dan tidak bisa
#                                 diturunkan darinya. Memang harus ada akun
#                                 yang selamat, kalau semua jebol peserta
#                                 belajar hal yang salah.
RUN samba-tool user create magang  'Password1'           --description='Anak magang, akun sementara' \
 && samba-tool user create bkupadm 'Backup2026!'         --description='Operator backup' \
 && samba-tool user create jdoe    'Ku1nc3-Rambut-Merah' --given-name=John  --surname=Doe   --mail-address=jdoe@cehlab.local \
 && samba-tool user create asmith  'Tembak4u-Lurus-92'   --given-name=Alice --surname=Smith --mail-address=asmith@cehlab.local \
 && samba-tool user create svc_sql 'S3rvis-SQL-Rahasia'  --description='Service account SQL Server' \
 && samba-tool group add Helpdesk \
 && samba-tool group addmembers Helpdesk jdoe,asmith \
 && samba-tool group addmembers 'Domain Admins' bkupadm \
 && samba-tool spn add MSSQLSvc/sql.cehlab.local:1433 svc_sql

# ---------------------------------------------------------------------------
# Share [backup] plus berkas sisa audit
# ---------------------------------------------------------------------------
# Ini temuan yang paling sering muncul di pentest internal beneran: dump hash
# dari pekerjaan audit lama ditinggal di share yang bisa dibaca semua pegawai.
# Share ini TIDAK guest-writable dan TIDAK guest-readable. Null session cuma
# melihat namanya. Isinya baru terbuka setelah peserta punya kredensial.
#
# Hash di dalamnya format pwdump, dan nilainya asli: dihitung dari sandi yang
# beneran dipasang di akun-akun di atas, lalu diverifikasi dengan memakainya
# untuk pass-the-hash ke DC ini. RID-nya juga cocok dengan RID sungguhan yang
# keluar dari RID cycling di langkah 4, karena urutan pembuatan akun di atas
# tetap. Kalau urutan RUN di atas diubah, angka RID di sini ikut berubah.
RUN mkdir -p /srv/backup \
 && printf '%s\n' \
      '# Sisa pekerjaan audit internal 2025.' \
      '# Diminta dihapus setelah laporan disetujui. Belum dihapus.' \
      'Administrator:500:aad3b435b51404eeaad3b435b51404ee:76c69081cda424c2fcae99785e11e472:::' \
      'bkupadm:1104:aad3b435b51404eeaad3b435b51404ee:da7a868ae3207455a709066b8fdab1f6:::' \
      'jdoe:1105:aad3b435b51404eeaad3b435b51404ee:1fcecf3b307f7e390adbe18c2a527071:::' \
      'svc_sql:1107:aad3b435b51404eeaad3b435b51404ee:33e1e7ab5869dd64b9f375fe829567f6:::' \
      > /srv/backup/audit-ntds-2025.txt \
 && chmod 755 /srv/backup \
 && chmod 644 /srv/backup/audit-ntds-2025.txt \
 && printf '\n%s\n' \
      '[backup]' \
      '   path = /srv/backup' \
      '   read only = yes' \
      '   browseable = yes' \
      '   comment = Arsip tim backup' \
      >> /etc/samba/smb.conf

EXPOSE 53/tcp 53/udp 88/tcp 135/tcp 139/tcp 389/tcp 389/udp 445/tcp 464/tcp 636/tcp 3268/tcp 3269/tcp

# Entrypoint bawaan image dasar menjalankan smbd dan nmbd lewat runit, dan itu
# justru bentrok dengan peran DC. Daemon "samba" sudah menjalankan smbd, LDAP,
# KDC, dan DNS sekaligus dalam satu proses, jadi entrypoint lama dibuang.
ENTRYPOINT []
CMD ["samba", "-i", "--debuglevel=1"]
