# Launcher lab CEH buat Windows. Ditulis buat Windows PowerShell 5.1, yaitu
# yang bawaan Windows 10 dan 11, jadi NOL sintaks PowerShell 7 di sini:
# ga ada operator ternary, ga ada ??, ga ada -Parallel.
# Peserta manggilnya lewat lab.cmd biar ga kena ExecutionPolicy.
[CmdletBinding()]
param(
  [Parameter(Position=0)][string]$Command = "",
  [Parameter(Position=1)][string]$Arg1 = "",
  [Parameter(Position=2)][string]$Arg2 = "",
  [Parameter(ValueFromRemainingArguments=$true)][string[]]$Rest
)
$ErrorActionPreference = "Stop"
$RepoRoot    = $PSScriptRoot
$LabsDir     = Join-Path $RepoRoot "labs"
$SharedYml   = Join-Path $RepoRoot "_shared\compose.base.yaml"
$InternetYml = Join-Path $RepoRoot "_shared\compose.internet.yaml"
# Harus sama persis dengan default TOOLBOX_IMAGE di _shared\compose.base.yaml.
$ToolboxImage = "ceh-toolbox:1.0"
if ($env:TOOLBOX_IMAGE) { $ToolboxImage = $env:TOOLBOX_IMAGE }
$ProbeImages = @(
  "public.ecr.aws/docker/library/busybox:latest",
  "quay.io/quay/busybox:latest",
  "busybox:latest"
)
$MinRamGb = 6
$MinDiskGb = 25
$script:DoctorWarn = 0

function Say-Ok   ($m) { Write-Host "  OK   " -ForegroundColor Green  -NoNewline; Write-Host $m }
function Say-Warn ($m) { Write-Host " WARN  " -ForegroundColor Yellow -NoNewline; Write-Host $m; $script:DoctorWarn = 1 }
function Say-Bad  ($m) { Write-Host " GAGAL " -ForegroundColor Red    -NoNewline; Write-Host $m }
function Say-Info ($m) { Write-Host "       $m" }
function Say-Title($m) { Write-Host ""; Write-Host $m -ForegroundColor Cyan }
function Die      ($m) { Say-Bad $m; exit 1 }

# Baca berkas KEY=value. Sengaja bukan YAML, biar nol ketergantungan modul.
function Meta-Get($file, $key) {
  if (-not (Test-Path $file)) { return "" }
  foreach ($line in Get-Content $file) {
    if ($line -match "^\s*#") { continue }
    $i = $line.IndexOf("=")
    if ($i -lt 1) { continue }
    if ($line.Substring(0, $i) -eq $key) { return $line.Substring($i + 1) }
  }
  return ""
}

# --------------------------------------------------------------------------
# DETEKSI. Yang ditanya Docker Engine, bukan Windows. Di laptop Windows ARM
# (Snapdragon), "uname" atau PROCESSOR_ARCHITECTURE bisa bohong karena emulasi
# x86, sementara engine-nya arm64. Yang nentuin container itu engine-nya.
# --------------------------------------------------------------------------
function Detect-Engine {
  if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Die "Docker belum kepasang. Baca docs\01-pasang-docker-windows.md"
  }
  docker info 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Die "Engine Docker mati. Buka Docker Desktop dari Start Menu, tunggu tulisan 'Engine running', lalu ulangi."
  }
  $script:EngineArchRaw = (docker info --format "{{.Architecture}}").Trim()
  $script:EngineOs      = (docker info --format "{{.OSType}}").Trim()
  $script:EngineMem     = [int64](docker info --format "{{.MemTotal}}")
  $script:EngineCpus    = (docker info --format "{{.NCPU}}").Trim()
  if ($script:EngineArchRaw -eq "x86_64" -or $script:EngineArchRaw -eq "amd64") { $script:Arch = "amd64" }
  elseif ($script:EngineArchRaw -eq "aarch64" -or $script:EngineArchRaw -eq "arm64") { $script:Arch = "arm64" }
  else { $script:Arch = "unknown" }
  if ($script:EngineOs -ne "linux") {
    Die "Docker lo lagi di mode Windows containers. Klik kanan ikon Docker di taskbar, pilih 'Switch to Linux containers', lalu ulangi."
  }
}

# 1 bisa, 0 ga bisa, 2 ga ketauan karena image ujinya ga ketarik.
function Probe-Amd64 {
  if ($script:Arch -eq "amd64") { return 1 }
  foreach ($p in $ProbeImages) {
    docker image inspect $p 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
      docker pull -q --platform linux/amd64 $p 2>&1 | Out-Null
      if ($LASTEXITCODE -ne 0) { continue }
    }
    docker run --rm --platform linux/amd64 $p true 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { return 1 } else { return 0 }
  }
  return 2
}

function Resolve-Lab($want) {
  if ([string]::IsNullOrWhiteSpace($want)) { Die "Sebutin ID lab-nya. Contoh: .\lab.cmd up 05" }
  $hits = @(Get-ChildItem -Path $LabsDir -Directory | Where-Object { $_.Name -like "$want-*" })
  if ($hits.Count -eq 0) { Say-Bad "Lab '$want' ga ketemu."; Say-Info "Daftar lab: .\lab.cmd list"; exit 1 }
  if ($hits.Count -gt 1) { Die "ID '$want' cocok ke lebih dari satu folder. Ini bug repo, lapor ke instruktur." }
  $script:LabDir  = $hits[0].FullName
  $script:LabId   = $want
  $script:LabProj = "ceh-$want"
  $script:LabMeta = Join-Path $script:LabDir "meta.env"
  if (-not (Test-Path (Join-Path $script:LabDir "compose.yaml"))) { Die "Lab '$want' rusak, compose.yaml ga ada." }
  # Satu-satunya saklar yang mengizinkan lab nyentuh internet, isinya harus "1".
  $script:LabInternet = ((Meta-Get $script:LabMeta "INTERNET") -eq "1")
}

# --project-directory itu WAJIB. Tanpa itu, './files' di compose lab nyasar
# ke folder _shared. Ini kejadian nyata waktu ngetes, bukan teori.
#
# Fungsi ini SENGAJA ga balikin exit code lewat "return". Versi lama begitu,
# jadi tiap pemanggil harus nulis "| Out-Null" buat nelen angkanya, dan itu
# ikut nelen sesi interaktif: ".\lab.cmd sh 05" ga pernah ngasih shell ke
# peserta Windows. Sekarang exit code-nya ditaruh di $script:DcExit.
function Dc {
  $env:REPO_ROOT = $RepoRoot
  $env:TOOLBOX_IMAGE = $ToolboxImage
  $files = @("-f", $SharedYml, "-f", (Join-Path $script:LabDir "compose.yaml"))
  # Berkas internet ditumpuk PALING AKHIR supaya setelan toolbox-nya menang.
  if ($script:LabInternet) { $files += @("-f", $InternetYml) }
  $pre = @("compose", "-p", $script:LabProj, "--project-directory", $script:LabDir) + $files
  & docker ($pre + $args)
  $script:DcExit = $LASTEXITCODE
}

function Toolbox-Ready {
  docker image inspect $ToolboxImage 2>&1 | Out-Null
  return ($LASTEXITCODE -eq 0)
}

function Count-Emulated {
  $f = Join-Path $script:LabDir "compose.yaml"
  return @(Select-String -Path $f -Pattern '^\s*platform:\s*linux/amd64\s*$').Count
}

# --------------------------------------------------------------------------
function Cmd-Doctor($report) {
  Say-Title "CEK KESIAPAN LAB CEH"
  Say-Info ("waktu   : " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
  Say-Info ("sistem  : Windows " + [System.Environment]::OSVersion.Version + " " + $env:PROCESSOR_ARCHITECTURE)
  Say-Info ("shell   : PowerShell " + $PSVersionTable.PSVersion)

  if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Say-Bad "Docker belum kepasang."
    Say-Info "Ikutin docs\01-pasang-docker-windows.md, sekitar 20 menit termasuk restart."
    return
  }
  Say-Ok ("Docker kepasang, versi " + (docker version --format "{{.Client.Version}}"))
  docker info 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { Say-Bad "Engine Docker mati. Buka Docker Desktop, tunggu 'Engine running', ulangi."; return }
  Say-Ok "Engine Docker jalan"

  Detect-Engine
  docker compose version 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { Say-Bad "'docker compose' ga ada. Pasang ulang Docker Desktop."; return }
  Say-Ok ("docker compose ada, versi " + (docker compose version --short))

  if ($script:Arch -eq "arm64") { Say-Ok "Arsitektur terdeteksi: arm64 (Windows ARM). Ga usah lo apa-apain." }
  elseif ($script:Arch -eq "amd64") { Say-Ok "Arsitektur terdeteksi: amd64 (Intel atau AMD). Ga usah lo apa-apain." }
  else { Say-Bad "Arsitektur '$($script:EngineArchRaw)' ga dikenal. Kirim layar ini ke instruktur."; return }

  $ramGb = [math]::Round($script:EngineMem / 1GB, 1)
  if ($ramGb -ge $MinRamGb) { Say-Ok "RAM buat Docker: $ramGb GB, CPU: $($script:EngineCpus)" }
  else {
    Say-Warn "RAM buat Docker cuma $ramGb GB, saran minimal $MinRamGb GB."
    Say-Info "Naikin lewat berkas C:\Users\$env:USERNAME\.wslconfig, isi: [wsl2] lalu memory=8GB, lalu jalanin: wsl --shutdown"
  }

  Say-Info "nguji jalanin container amd64, sebentar ya"
  $emu = Probe-Amd64
  if ($emu -eq 1 -and $script:Arch -eq "arm64") { Say-Ok "Emulasi amd64 jalan. Lab yang cuma punya versi Intel tetap bisa lo jalanin, cuma lebih pelan." }
  elseif ($emu -eq 1) { Say-Ok "Container amd64 jalan native" }
  elseif ($emu -eq 2) { Say-Warn "Ga bisa nguji emulasi, image ujinya ga ketarik. Bukan penghalang, lanjut aja." }
  else { Say-Warn "Emulasi amd64 GA jalan. Docker Desktop: Settings, General, cek opsi emulasi. Lapor ke instruktur." }

  $drive = (Get-Item $RepoRoot).PSDrive.Name
  $freeGb = [math]::Round((Get-PSDrive $drive).Free / 1GB, 0)
  if ($freeGb -lt $MinDiskGb) { Say-Warn "Sisa disk cuma $freeGb GB. Semua lab butuh sekitar $MinDiskGb GB. Kosongin dulu." }
  else { Say-Ok "Sisa disk: $freeGb GB" }

  $pullOk = $false
  foreach ($p in $ProbeImages) { docker pull -q $p 2>&1 | Out-Null; if ($LASTEXITCODE -eq 0) { $pullOk = $true; break } }
  if ($pullOk) { Say-Ok "Bisa narik image dari internet" }
  else { Say-Warn "Ga bisa narik image. Cek koneksi, atau pakai: .\lab.cmd offline load E:\" }

  if (Toolbox-Ready) { Say-Ok "Image toolbox udah ada: $ToolboxImage" }
  else {
    Say-Warn "Image toolbox '$ToolboxImage' belum dibikin."
    Say-Info "Jalanin: .\lab.cmd build   Sekali doang, dan lakuin di rumah, bukan di kelas."
  }

  Write-Host ""
  if ($script:DoctorWarn -eq 0) { Say-Ok "SEMUA HIJAU. Lanjut: .\lab.cmd build lalu .\lab.cmd pull core" }
  else { Say-Warn "Ada catatan kuning di atas. Kirim laporan ini ke instruktur sebelum hari-H." }
}

function Cmd-List {
  Write-Host ""; Write-Host "DAFTAR LAB   (nyalain: .\lab.cmd up <id>)" -ForegroundColor Cyan; Write-Host ""
  $last = ""
  foreach ($d in (Get-ChildItem -Path $LabsDir -Directory | Sort-Object Name)) {
    if ($d.Name -eq "_template") { continue }
    $m = Join-Path $d.FullName "meta.env"
    if (-not (Test-Path $m)) { continue }
    $modul = Meta-Get $m "MODUL"
    if ($modul -ne $last) {
      Write-Host ""
      Write-Host ("  Modul " + $modul + "  " + (Meta-Get $m "MODUL_NAMA")) -ForegroundColor White
      $last = $modul
    }
    "{0,-6} {1,-46} {2,3} menit  lv{3}" -f (Meta-Get $m "ID"), (Meta-Get $m "JUDUL"), (Meta-Get $m "DURASI"), (Meta-Get $m "LEVEL") | ForEach-Object { Write-Host ("    " + $_) }
  }
  Write-Host ""
}

function Cmd-Up($id, $opts) {
  Detect-Engine; Resolve-Lab $id
  if (-not (Toolbox-Ready)) {
    Say-Bad "Image toolbox '$ToolboxImage' belum ada di laptop lo."
    Say-Info "Bikin dulu, sekali doang: .\lab.cmd build"
    Say-Info "Sengaja ga dibikin otomatis di sini, karena build-nya 5-15 menit"
    Say-Info "dan itu bukan yang mau lo tungguin waktu kelas lagi jalan."
    exit 1
  }
  $profiles = @()
  foreach ($o in $opts) {
    if ($o -eq "--x86")   { $profiles += "x86" }
    elseif ($o -eq "--bonus") { $profiles += "bonus" }
    elseif ($o) { Die "Opsi '$o' ga dikenal." }
  }
  if ($profiles -contains "x86" -and $script:Arch -ne "amd64") {
    Die "Opsi --x86 cuma buat laptop Intel/AMD. Laptop lo arm64, jalanin tanpa opsi itu: .\lab.cmd up $id"
  }
  $emu = Count-Emulated
  if ($emu -gt 0 -and $script:Arch -eq "arm64") {
    if ((Probe-Amd64) -eq 0) { Die "Lab ini butuh container amd64 dan laptop lo belum bisa emulasi. Jalanin .\lab.cmd doctor." }
    Say-Warn "$emu layanan jalan lewat emulasi. Nyalainnya bisa 1-3 menit, sabar."
  }
  $env:COMPOSE_PROFILES = ($profiles -join ",")
  Say-Title "Nyalain lab $id"
  if ($script:LabInternet) {
    Say-Warn "LAB INI TERHUBUNG KE INTERNET. Cuma lab ini, dan cuma selama nyala."
    Say-Info "Rute ke jaringan lokal diblokir dari dalam toolbox, tapi tetap:"
    Say-Info "arahin perintah lo cuma ke target yang disebut di README lab ini."
  }
  $waitArgs = @("--wait", "--wait-timeout", "240")
  if ((Meta-Get $script:LabMeta "WAIT") -eq "0") { $waitArgs = @() }
  Dc (@("up", "-d", "--quiet-pull") + $waitArgs)
  if ($script:DcExit -ne 0) {
    Say-Bad "Ada layanan yang gagal nyala. Log 40 baris terakhir:"
    Dc @("logs", "--tail", "40")
    Say-Info "Coba: .\lab.cmd reset $id"
    Say-Info "Masih gagal, panggil instruktur dan tunjukin layar ini."
    exit 1
  }
  $url = Meta-Get $script:LabMeta "URL"
  Write-Host ""
  Say-Ok "Lab $id nyala."
  if ($url) { Say-Info "buka di browser   : $url" }
  Say-Info "terminal penyerang: .\lab.cmd sh $id"
  Say-Info "panduan langkahnya: labs\$(Split-Path $script:LabDir -Leaf)\README.md"
  Say-Info "kalau udah selesai: .\lab.cmd down $id"
  Write-Host ""
}

function Cmd-Down($id) { Detect-Engine; Resolve-Lab $id; Dc @("down","-v","--remove-orphans"); Say-Ok "Lab $id dimatiin." }
function Cmd-Reset($id){ Detect-Engine; Resolve-Lab $id; Dc @("down","-v","--remove-orphans"); Cmd-Up $id @() }
function Cmd-Sh($id, $svc) {
  Detect-Engine; Resolve-Lab $id
  if (-not $svc) { $svc = "toolbox" }
  # Cadangan ke "sh" cuma buat container yang beneran nol bash, dan itu
  # ditanyain langsung. Alasannya sama persis dengan cmd_sh di skrip "lab":
  # kode keluar bash bukan penebak yang sah, karena "exit" tanpa argumen
  # mewarisi status perintah terakhir.
  Dc @("exec", "-T", $svc, "sh", "-c", "command -v bash >/dev/null 2>&1") | Out-Null
  # Tanpa "| Out-Null" di dua baris ini, dan itu memang intinya: sesi interaktif.
  if ($script:DcExit -eq 0) { Dc @("exec", $svc, "bash") } else { Dc @("exec", $svc, "sh") }
}
function Cmd-Logs($id) { Detect-Engine; Resolve-Lab $id; Dc @("logs","-f","--tail","100") }

function Cmd-Build {
  Detect-Engine
  $ctx = Join-Path $RepoRoot "toolbox"
  if (-not (Test-Path (Join-Path $ctx "Dockerfile"))) { Die "toolbox\Dockerfile ga ada di repo ini. Tarik ulang repo-nya." }
  Say-Title "Bikin image toolbox: $ToolboxImage"
  Say-Info "Ini sekali doang. Di internet kencang sekitar 5 sampai 15 menit."
  Say-Info "Lakuin di rumah, jangan di kelas."
  # Kalau toolbox punya skrip build sendiri, itu yang dipakai. Dua jalur build
  # yang beda bakal pelan-pelan berbeda isinya, dan itu ketahuannya di kelas.
  $own = Join-Path $ctx "build.ps1"
  if (Test-Path $own) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $own
    if ($LASTEXITCODE -ne 0) { Say-Bad "Build toolbox gagal. Layar di atas itu yang dibaca instruktur."; exit 1 }
    Say-Ok "Toolbox siap. Lanjut: .\lab.cmd pull core"
    return
  }
  & docker build --pull -t $ToolboxImage $ctx
  if ($LASTEXITCODE -ne 0) {
    Say-Bad "Build toolbox gagal. Layar di atas itu yang dibaca instruktur."
    Say-Info "Penyebab paling sering: koneksi putus di tengah, atau disk penuh."
    exit 1
  }
  Say-Ok "Toolbox siap. Lanjut: .\lab.cmd pull core"
}

function Cmd-Info($id) {
  Resolve-Lab $id
  Say-Title ("Lab " + $id + "  " + (Meta-Get $script:LabMeta "JUDUL"))
  Say-Info ("modul CEH  : " + (Meta-Get $script:LabMeta "MODUL") + " " + (Meta-Get $script:LabMeta "MODUL_NAMA"))
  Say-Info ("durasi     : " + (Meta-Get $script:LabMeta "DURASI") + " menit")
  $u = Meta-Get $script:LabMeta "URL";        if ($u) { Say-Info "buka       : $u" }
  $k = Meta-Get $script:LabMeta "KREDENSIAL"; if ($k) { Say-Info "kredensial : $k" }
  Say-Info ("panduan    : labs\" + (Split-Path $script:LabDir -Leaf) + "\README.md")
  if ($script:LabInternet) { Say-Info "internet   : NYALA buat lab ini, rute ke jaringan lokal tetap diblokir" }
  else { Say-Info "internet   : mati, lab ini terkurung di jaringannya sendiri" }
  Write-Host ""
}

function Cmd-Pull($what) {
  Detect-Engine
  if (-not $what) { $what = "core" }
  if ($what -eq "all" -or $what -eq "core") {
    $n = 0
    foreach ($d in (Get-ChildItem -Path $LabsDir -Directory | Sort-Object Name)) {
      if ($d.Name -eq "_template") { continue }
      $m = Join-Path $d.FullName "meta.env"
      if (-not (Test-Path $m)) { continue }
      if ($what -eq "core" -and (Meta-Get $m "TIER") -ne "core") { continue }
      Resolve-Lab (Meta-Get $m "ID")
      Write-Host ("  tarik " + (Meta-Get $m "ID") + " " + (Meta-Get $m "JUDUL"))
      # --ignore-buildable bikin toolbox dilewat, karena toolbox dibangun
      # lokal dan ga pernah ada di registry mana pun.
      Dc @("pull","--quiet","--ignore-buildable")
      if ($script:DcExit -ne 0) { Dc @("pull","--quiet","--ignore-pull-failures") }
      $n++
    }
    Say-Ok "$n lab siap dipakai tanpa internet."
  } else {
    Resolve-Lab $what
    Dc @("pull","--ignore-buildable")
    if ($script:DcExit -ne 0) { Dc @("pull","--ignore-pull-failures") }
    Say-Ok "Image lab $what udah ada di laptop lo."
  }
}

function Cmd-Nuke {
  Detect-Engine
  $n = 0
  foreach ($d in (Get-ChildItem -Path $LabsDir -Directory)) {
    # _template WAJIB dilewat. ID-nya masih "__ID__", dan Resolve-Lab bakal
    # exit 1 di situ, jadi versi lama bikin nuke mati sebelum matiin satu lab.
    if ($d.Name -eq "_template") { continue }
    $m = Join-Path $d.FullName "meta.env"
    if (-not (Test-Path $m)) { continue }
    Resolve-Lab (Meta-Get $m "ID")
    Dc @("down","-v","--remove-orphans")
    $n++
  }
  Say-Ok "Beres. $n lab dimatiin."
}

# Muat image dari flashdisk. Peserta ga perlu tau arsitekturnya.
function Cmd-OfflineLoad($src) {
  Detect-Engine
  if (-not $src) { Die "Sebutin foldernya. Contoh: .\lab.cmd offline load E:\ceh-bundle" }
  $dir = Join-Path $src ("bundle-" + $script:Arch)
  if (-not (Test-Path $dir)) {
    if (Test-Path (Join-Path $src "manifest.txt")) { $dir = $src }
    else { Die "Ga nemu folder bundle-$($script:Arch) di dalam '$src'. Pastikan flashdisknya kesalin utuh." }
  }
  Say-Title "Muat image dari flashdisk (arsitektur laptop lo: $($script:Arch))"
  $n = 0; $gagal = 0
  foreach ($f in (Get-ChildItem -Path $dir -Filter *.tar.gz | Sort-Object Name)) {
    $n++
    Write-Host ("  [$n] " + $f.Name)
    docker load -i $f.FullName 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Say-Bad ("    gagal: " + $f.Name); $gagal++ }
  }
  Write-Host ""
  if ($n -eq 0) { Die "Nol berkas .tar.gz di '$dir'. Salah folder?" }
  elseif ($gagal -eq 0) { Say-Ok "$n image kemuat. Lo sekarang bisa jalanin semua lab TANPA internet."; Say-Info "Coba: .\lab.cmd up 00a" }
  else { Say-Warn "$n berkas dicoba, $gagal gagal. Panggil instruktur." }
}

function Show-Usage {
@"
Pemakaian:  .\lab.cmd <perintah> [ID lab]

  doctor              Cek laptop lo siap apa belum. JALANIN INI DULUAN.
  build               Bikin image toolbox di laptop lo. SEKALI DOANG, di rumah.
  list                Daftar semua lab.
  info   <id>         Keterangan satu lab.
  up     <id>         Nyalain lab.        Contoh: .\lab.cmd up 05
  sh     <id>         Masuk ke terminal penyerang.
  logs   <id>         Lihat log.
  down   <id>         Matiin lab.
  reset  <id>         Matiin lalu nyalain lagi dari nol.
  pull   <id|core|all>  Tarik image duluan.
  nuke                Matiin SEMUA lab.
  offline load <dir>  Muat image dari flashdisk.
"@ | Write-Host
}

switch ($Command) {
  "doctor"  { if ($Arg1 -eq "--report") {
                Start-Transcript -Path ("laporan-siap-" + $env:COMPUTERNAME + ".txt") -Force | Out-Null
                Cmd-Doctor $true
                Stop-Transcript | Out-Null
                Write-Host ""
                Write-Host ("Laporan ada di berkas: laporan-siap-" + $env:COMPUTERNAME + ".txt")
                Write-Host "Kirim berkas itu ke instruktur."
              } else { Cmd-Doctor $false } }
  "build"   { Cmd-Build }
  "list"    { Cmd-List }
  "ls"      { Cmd-List }
  "info"    { Cmd-Info $Arg1 }
  "up"      { $o = @(); if ($Arg2) { $o += $Arg2 }; if ($Rest) { $o += $Rest }; Cmd-Up $Arg1 $o }
  "down"    { Cmd-Down $Arg1 }
  "reset"   { Cmd-Reset $Arg1 }
  "sh"      { Cmd-Sh $Arg1 $Arg2 }
  "shell"   { Cmd-Sh $Arg1 $Arg2 }
  "logs"    { Cmd-Logs $Arg1 }
  "pull"    { Cmd-Pull $Arg1 }
  "nuke"    { Cmd-Nuke }
  "offline" { if ($Arg1 -eq "load") { Cmd-OfflineLoad $Arg2 } else { Die "Pakai: .\lab.cmd offline load <folder>" } }
  "version" { Write-Host "lab 1.0.0" }
  default   { Show-Usage }
}
