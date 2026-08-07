# ============================================================================
# Build toolbox penyerang lab CEH, untuk Windows PowerShell.
#
#   .\toolbox\build.ps1
#
# Pilihan tambahan, semuanya opsional:
#   .\toolbox\build.ps1 -NoCache     ulang dari nol, abaikan cache
#   .\toolbox\build.ps1 -Quiet       keluaran build diringkas
#
# Kalau PowerShell menolak menjalankan skrip dengan pesan
# "running scripts is disabled on this system", jalankan sekali perintah ini
# di PowerShell yang sama, lalu ulangi:
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#
# Skrip ini mendeteksi sendiri arsitektur laptop dan membangun image native,
# jadi tidak ada yang perlu diubah baik di Windows Intel/AMD maupun Windows ARM.
# ============================================================================
[CmdletBinding()]
param(
  [switch]$NoCache,
  [switch]$Quiet
)

$ErrorActionPreference = 'Continue'

# Ditulis untuk Windows PowerShell 5.1, yaitu yang bawaan Windows 10 dan 11.
# Jadi nol sintaks PowerShell 7 di sini: tidak ada operator ternary, tidak ada
# ?? , dan tidak ada -Parallel.
$ImageName = 'ceh-toolbox'
$ImageTag  = '1.0'
$Image     = $ImageName + ':' + $ImageTag
$Ctx       = $PSScriptRoot

function Write-Ok    { param($m) Write-Host '  OK  ' -ForegroundColor Green  -NoNewline; Write-Host " $m" }
function Write-Bad   { param($m) Write-Host ' GAGAL' -ForegroundColor Red    -NoNewline; Write-Host " $m" }
function Write-Warn2 { param($m) Write-Host ' WARN ' -ForegroundColor Yellow -NoNewline; Write-Host " $m" }
function Write-Info  { param($m) Write-Host "       $m" }
function Write-Title { param($m) Write-Host ''; Write-Host $m -ForegroundColor White }

Write-Title 'BUILD TOOLBOX LAB CEH'

# ---------------------------------------------------------------------------
# 1. Pastikan Docker ada dan hidup. Dua keadaan ini beda, dan solusinya beda,
#    jadi pesannya juga harus beda.
# ---------------------------------------------------------------------------
$docker = Get-Command docker -ErrorAction SilentlyContinue
if (-not $docker) {
  Write-Bad 'Docker belum terpasang di laptop ini.'
  Write-Info 'Baca docs/01-pasang-docker-windows.md, pasang Docker Desktop, lalu ulangi.'
  exit 1
}
docker info *> $null
if ($LASTEXITCODE -ne 0) {
  Write-Bad 'Docker terpasang tetapi mesinnya belum jalan.'
  Write-Info 'Buka aplikasi Docker Desktop, tunggu sampai ikonnya hijau, lalu ulangi perintah ini.'
  exit 1
}
$dver = (docker version --format '{{.Client.Version}}' 2>$null)
Write-Ok "Docker jalan, versi $dver"

# ---------------------------------------------------------------------------
# 2. Deteksi arsitektur. Yang dipercaya adalah Docker Engine, bukan sistem
#    operasinya, karena engine jalan di dalam VM Linux.
# ---------------------------------------------------------------------------
$raw    = (docker info --format '{{.Architecture}}' 2>$null)
$ostype = (docker info --format '{{.OSType}}'       2>$null)

if ($ostype -ne 'linux') {
  Write-Bad 'Docker sedang di mode container Windows.'
  Write-Info "Klik kanan ikon Docker di taskbar, pilih 'Switch to Linux containers', lalu ulangi."
  exit 1
}

$platform = ''
$label    = ''
switch -Regex ($raw) {
  '^(x86_64|amd64)$'  { $platform = 'linux/amd64'; $label = 'Intel atau AMD' }
  '^(aarch64|arm64)$' { $platform = 'linux/arm64'; $label = 'Apple Silicon atau ARM' }
}
if ($platform -eq '') {
  Write-Warn2 "Arsitektur '$raw' tidak dikenal. Build tetap dilanjutkan tanpa --platform."
  Write-Info  'Kirim baris ini ke instruktur supaya dicatat.'
} else {
  $a = $platform.Split('/')[1]
  Write-Ok "Arsitektur terdeteksi: $a ($label). Image dibangun native, tanpa emulasi."
}

# ---------------------------------------------------------------------------
# 3. Jaga supaya tag di sini tidak melenceng dari yang dicari compose.
#    Kalau dua berkas ini beda, gejalanya "image tidak ditemukan" saat lab
#    dinyalakan, dan penyebabnya tidak kelihatan sama sekali dari pesan itu.
# ---------------------------------------------------------------------------
$baseYml = Join-Path (Split-Path -Parent $Ctx) '_shared\compose.base.yaml'
if (Test-Path $baseYml) {
  $needle = 'TOOLBOX_IMAGE:-' + $Image + '}'
  if (-not (Select-String -Path $baseYml -SimpleMatch -Pattern $needle -Quiet)) {
    Write-Warn2 "Tag di skrip ini ($Image) tidak cocok dengan default di _shared\compose.base.yaml."
    Write-Info  'Ini bug repo, tolong laporkan ke instruktur.'
  }
}

# ---------------------------------------------------------------------------
# 4. Build. Basisnya satu image saja dari Docker Hub, sisanya dari repo Kali,
#    jadi batas 100 tarikan per jam Docker Hub praktis tidak tersentuh.
# ---------------------------------------------------------------------------
Write-Info "konteks build : $Ctx"
Write-Info "tag hasil     : $Image"
Write-Info 'Perlu internet dan sekitar 3 sampai 10 menit, tergantung kecepatan jaringan.'
Write-Host ''

$progress = 'plain'
if ($Quiet) { $progress = 'auto' }

# Namanya sengaja bukan $args. Di PowerShell $args itu variabel otomatis dan
# tidak boleh ditimpa di skrip ber-CmdletBinding.
$dargs = @('build')
if ($NoCache) { $dargs += '--no-cache' }
$dargs += @("--progress=$progress", '-t', $Image, '-t', ($ImageName + ':latest'))
if ($platform -ne '') { $dargs += @('--platform', $platform) }
$dargs += $Ctx

$start = Get-Date
& docker @dargs
$code = $LASTEXITCODE
$elapsed = [int]((Get-Date) - $start).TotalSeconds

if ($code -ne 0) {
  Write-Host ''
  Write-Bad "Build gagal setelah $elapsed detik."
  Write-Info 'Tiga penyebab yang paling sering, urut dari yang paling sering:'
  Write-Info '1. Internet putus atau lambat waktu apt mengambil paket.'
  Write-Info '   Solusi: sambungkan ulang, jalankan lagi perintah yang sama.'
  Write-Info '2. Repo Kali sedang tidak sinkron, biasanya pesannya'
  Write-Info "   'Hash Sum mismatch' atau '404 Not Found'."
  Write-Info '   Solusi: ulangi dengan  .\toolbox\build.ps1 -NoCache'
  Write-Info "3. Disk penuh, pesannya 'no space left on device'."
  Write-Info '   Solusi: jalankan  docker system prune -a  lalu ulangi.'
  Write-Info 'Kalau masih gagal, salin 20 baris terakhir layar ini dan kirim ke instruktur.'
  exit 1
}

# ---------------------------------------------------------------------------
# 5. Uji singkat. Image yang berhasil dibangun belum tentu isinya jalan,
#    jadi jangan berhenti di kata "Successfully built".
# ---------------------------------------------------------------------------
Write-Host ''
Write-Title 'UJI SINGKAT'
$smoke = 'nmap --version | head -1; printf "john "; john --list=build-info | head -1; printf "sqlmap "; sqlmap --version; gobuster --version | head -1'
$out = & docker run --rm $Image sh -c $smoke 2>&1
$out | ForEach-Object { Write-Host "       $_" }
if ($LASTEXITCODE -ne 0) {
  Write-Bad 'Image terbangun tetapi gagal dijalankan. Kirim keluaran ini ke instruktur.'
  exit 1
}
Write-Ok 'Perkakas inti menjawab.'

# Yang dilaporkan adalah pemakaian disk, bukan ukuran unduhan. Dua angka ini
# beda jauh, dan yang bikin disk peserta penuh adalah yang pertama.
$size = (docker images $Image --format '{{.Size}}' 2>$null | Select-Object -First 1)
if (-not $size) { $size = 'tidak terbaca' }
Write-Host ''
Write-Ok "Toolbox siap. Tag: $Image"
Write-Info "waktu build   : $elapsed detik"
Write-Info "pakai disk    : $size"
Write-Info 'Langkah berikutnya:  .\lab.cmd doctor'
Write-Host ''
