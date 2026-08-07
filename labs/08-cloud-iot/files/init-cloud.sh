#!/bin/bash
# Penyemai akun AWS palsu untuk lab 08.
#
# Berkas ini dipasang ke /etc/localstack/init/ready.d/ di dalam container
# LocalStack, jadi dia jalan DI DALAM container itu, bukan di toolbox. Di sana
# tersedia awslocal, yang tidak ada di toolbox Kali. Itu disengaja: peserta
# menyerang pakai curl dan HTTP polos, bukan pakai AWS CLI, karena yang mau
# diajarkan adalah bentuk API-nya.
#
# Semua nama, kunci, dan sandi di bawah ini FIKSI. Nusatera Hidro bukan
# perusahaan yang ada, dan tidak ada satu pun nilai di sini yang berlaku di
# AWS sungguhan.
#
# Urutannya penting: kunci akses deploy-bot dibuat DULU, lalu ID-nya ditulis
# ke berkas .env yang bocor. Dengan begitu kunci yang ditemukan peserta di S3
# beneran nyambung ke pengguna IAM yang ada, dan langkah "siapa pemilik kunci
# ini" punya jawaban yang bisa dibuktikan, bukan cuma cerita.
set -eu

PUB=nusatera-arsip-publik
INT=nusatera-arsip-internal
TMP=/tmp/semai
mkdir -p "$TMP"

echo "[semai] membuat bucket"
awslocal s3api create-bucket --bucket "$PUB" >/dev/null
awslocal s3api create-bucket --bucket "$INT" >/dev/null

# ---------------------------------------------------------------------------
# Salah konfigurasi nomor satu: Block Public Access dimatikan seluruhnya, lalu
# bucket policy memberi Principal "*". Ini kombinasi yang bikin bucket beneran
# terbuka ke internet di AWS asli.
# ---------------------------------------------------------------------------
echo "[semai] membuka $PUB"
awslocal s3api put-public-access-block --bucket "$PUB" \
  --public-access-block-configuration \
  'BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false' >/dev/null

cat > "$TMP/policy-publik.json" <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SemuaOrangBolehBaca",
      "Effect": "Allow",
      "Principal": "*",
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::nusatera-arsip-publik",
        "arn:aws:s3:::nusatera-arsip-publik/*"
      ]
    }
  ]
}
JSON
awslocal s3api put-bucket-policy --bucket "$PUB" --policy "file://$TMP/policy-publik.json" >/dev/null

# Pembanding yang dikonfigurasi benar. Bukan supaya aksesnya ditolak
# (LocalStack community memang tidak menegakkan itu, dan README mengatakannya
# terang-terangan), tapi supaya peserta punya dua konfigurasi untuk
# dibandingkan waktu membaca ?publicAccessBlock dan ?policy.
echo "[semai] mengunci $INT"
awslocal s3api put-public-access-block --bucket "$INT" \
  --public-access-block-configuration \
  'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true' >/dev/null

# ---------------------------------------------------------------------------
# Pengguna IAM. Satu kelewat longgar, satu jalur eskalasi yang lebih halus,
# satu yang memang dibatasi dengan benar.
# ---------------------------------------------------------------------------
echo "[semai] membuat pengguna IAM"
awslocal iam create-user --user-name deploy-bot   >/dev/null
awslocal iam create-user --user-name svc-backup   >/dev/null
awslocal iam create-user --user-name magang-2026  >/dev/null

# Salah konfigurasi nomor dua: wildcard di Action dan Resource sekaligus.
cat > "$TMP/deploy.json" <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    { "Sid": "SementaraSajaKatanya", "Effect": "Allow", "Action": "*", "Resource": "*" }
  ]
}
JSON
awslocal iam put-user-policy --user-name deploy-bot \
  --policy-name AksesPenuhSementara --policy-document "file://$TMP/deploy.json" >/dev/null

# Jalur eskalasi yang lebih halus: kelihatan sempit karena cuma iam dan s3,
# tapi iam:* berarti pengguna ini bisa menulis policy baru untuk dirinya
# sendiri, jadi efektifnya sama dengan administrator.
cat > "$TMP/backup.json" <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    { "Sid": "BackupHarian", "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:ListBucket"],
      "Resource": "arn:aws:s3:::nusatera-arsip-internal/*" },
    { "Sid": "PerluBuatRotasiKunci", "Effect": "Allow",
      "Action": "iam:*", "Resource": "*" }
  ]
}
JSON
awslocal iam put-user-policy --user-name svc-backup \
  --policy-name RotasiKunciBackup --policy-document "file://$TMP/backup.json" >/dev/null

# Yang ini benar. Ada supaya peserta punya pembanding bentuk policy yang sehat.
cat > "$TMP/magang.json" <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    { "Sid": "BacaLaporanSaja", "Effect": "Allow", "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::nusatera-arsip-internal/laporan/*" }
  ]
}
JSON
awslocal iam put-user-policy --user-name magang-2026 \
  --policy-name BacaLaporanSaja --policy-document "file://$TMP/magang.json" >/dev/null

# ---------------------------------------------------------------------------
# Kunci akses deploy-bot. ID-nya dipanen di sini supaya bisa ditanam ke berkas
# .env yang bocor, jadi rantai temuannya nyambung beneran.
# ---------------------------------------------------------------------------
echo "[semai] membuat kunci akses deploy-bot"
awslocal iam create-access-key --user-name deploy-bot --output json > "$TMP/kunci.json"
AK=$(python3 -c 'import json,sys; print(json.load(open("/tmp/semai/kunci.json"))["AccessKey"]["AccessKeyId"])')
SK=$(python3 -c 'import json,sys; print(json.load(open("/tmp/semai/kunci.json"))["AccessKey"]["SecretAccessKey"])')

# ---------------------------------------------------------------------------
# Isi bucket.
# ---------------------------------------------------------------------------
echo "[semai] mengisi bucket"

cat > "$TMP/index.html" <<'HTML'
<!doctype html>
<title>Nusatera Hidro</title>
<h1>Arsip publik Nusatera Hidro</h1>
<p>Halaman ini sengaja kosong. Berkas yang menarik tidak ditautkan dari sini.</p>
HTML

# Salah konfigurasi nomor tiga: kredensial ditulis langsung di berkas
# konfigurasi, lalu berkasnya ikut tercadangkan ke bucket yang terbuka.
cat > "$TMP/app-produksi.env" <<ENVFILE
# Konfigurasi aplikasi portal-pelanggan, lingkungan produksi.
# Disalin ke sini oleh skrip cadangan harian. JANGAN dibagikan.
APP_ENV=production
APP_DEBUG=false
APP_URL=https://portal.nusatera-hidro.example

DB_HOST=db-produksi.internal
DB_NAME=portal_pelanggan
DB_USER=portal_app
DB_PASSWORD=Tirta#Nusa2026!

# Dipakai skrip cadangan untuk menulis ke S3.
AWS_DEFAULT_REGION=us-east-1
AWS_ACCESS_KEY_ID=$AK
AWS_SECRET_ACCESS_KEY=$SK

# Catatan tim OT, jangan dihapus.
# Endpoint SCADA plant WTP-01A dipindah ke jaringan yang sama dengan aplikasi
# supaya dashboard bisa menarik data. Detailnya di dokumen/runbook-ot.txt.
ENVFILE

cat > "$TMP/runbook-ot.txt" <<'TXT'
RUNBOOK OPERASI TEKNOLOGI, NUSATERA HIDRO
Unit  : WTP-01A
Revisi: 4
Status: INTERNAL

1. Akses PLC
   Kontroler unit ini bicara Modbus TCP.
   Host  : plc
   Port  : 502
   Unit ID: 1

   Catatan integrator: kontroler tidak mendukung autentikasi apa pun.
   Pengamanan diserahkan sepenuhnya ke segmentasi jaringan. Permintaan
   pemasangan firewall OT sudah diajukan sejak revisi 2 dan belum disetujui.

2. Register yang dipakai dashboard
   Angka di bawah adalah alamat protokol, bukan penomoran 4xxxx vendor.

   Holding register, boleh dibaca dan DITULIS
     0      putaran pompa intake, rpm
     1      dosis klorin, ppm dikali sepuluh
     2      batas tekanan pipa, kPa
     3      mode operasi, 0 manual 1 auto
     10-17  tag perangkat, teks ASCII dua huruf per register
     30-36  catatan integrator, teks ASCII dua huruf per register

   Input register, baca saja
     0      level tangki, cm
     1      aliran, liter per menit
     2      tekanan, kPa
     3      turbiditas, NTU dikali sepuluh

   Coil, boleh dibaca dan DITULIS
     0      pompa intake
     1      pompa dosing
     2      katup bypass
     3      alarm

   Discrete input, baca saja
     0      sensor tangki penuh
     1      pompa fault
     2      pintu panel terbuka

3. Peringatan
   Menulis coil 2 membuka katup bypass, artinya air melewati unit dosing
   tanpa diolah. Jangan pernah dilakukan dari jaringan kantor.
TXT

cat > "$TMP/gaji-2026.csv" <<'CSV'
nip,nama,jabatan,gaji_pokok
2019004,Rina Ambarwati,Operator WTP,7100000
2021011,Bagas Setiawan,Teknisi Instrumen,8300000
2017002,Sri Handayani,Supervisor OT,12500000
CSV

awslocal s3 cp "$TMP/index.html"       "s3://$PUB/index.html"                  >/dev/null
awslocal s3 cp "$TMP/app-produksi.env" "s3://$PUB/cadangan/app-produksi.env"   >/dev/null
awslocal s3 cp "$TMP/runbook-ot.txt"   "s3://$PUB/dokumen/runbook-ot.txt"      >/dev/null
awslocal s3 cp "$TMP/gaji-2026.csv"    "s3://$INT/hr/gaji-2026.csv"            >/dev/null

# ---------------------------------------------------------------------------
# Hadiah akhir rantai. Baru masuk akal diambil setelah peserta membuktikan
# kunci yang bocor itu milik pengguna yang boleh melakukan apa saja.
# ---------------------------------------------------------------------------
echo "[semai] membuat secret"
awslocal secretsmanager create-secret --name nusatera/prod/basisdata \
  --description "Kredensial basis data produksi portal pelanggan" \
  --secret-string '{"host":"db-produksi.internal","user":"root","pass":"R0ot-Tirta-2026"}' >/dev/null

rm -rf "$TMP"
echo "[semai] SELESAI. Akun palsu Nusatera Hidro siap diaudit."
