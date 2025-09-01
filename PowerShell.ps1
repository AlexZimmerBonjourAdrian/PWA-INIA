Param(
  [ValidateSet('debug','release')]
  [string]$Configuration = 'debug',
  [switch]$Clean,
  [switch]$SkipInstall,
  [switch]$SkipBuild,
  [switch]$SkipSync,
  [string]$JavaHome
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-Step {
  Param(
    [Parameter(Mandatory=$true)][string]$Command,
    [Parameter(Mandatory=$true)][string]$Description
  )
  Write-Host "[RUN] $Description" -ForegroundColor Cyan
  Write-Host "      $Command" -ForegroundColor DarkGray
  cmd /c $Command
  if ($LASTEXITCODE -ne 0) {
    throw "Fallo: $Description (exit $LASTEXITCODE)"
  }
}

function Test-NpmInstalled {
  if (-not (Test-Path 'node_modules')) { return $false }
  $paths = @(
    'node_modules/@angular/core',
    'node_modules/@angular/cli',
    'node_modules/@capacitor/core'
  )
  foreach ($p in $paths) { if (-not (Test-Path $p)) { return $false } }
  return $true
}

function Resolve-GradleTask {
  Param([string]$Config)
  if ($Config -ieq 'release') { return 'assembleRelease' }
  return 'assembleDebug'
}

function Get-ExpectedApkPath {
  Param([string]$Config)
  $base = Join-Path -Path 'android' -ChildPath 'app\\build\\outputs\\apk'
  if ($Config -ieq 'release') {
    $rel = Join-Path $base 'release\\app-release.apk'
    $relUnsigned = Join-Path $base 'release\\app-release-unsigned.apk'
    if (Test-Path $rel) { return (Resolve-Path $rel).Path }
    if (Test-Path $relUnsigned) { return (Resolve-Path $relUnsigned).Path }
    return (Resolve-Path (Join-Path $base 'release')).Path
  }
  $dbg = Join-Path $base 'debug\\app-debug.apk'
  if (Test-Path $dbg) { return (Resolve-Path $dbg).Path }
  return (Resolve-Path (Join-Path $base 'debug')).Path
}

function Get-JavaVersionMajor {
  try {
    $out = & java -version 2>&1 | Out-String
    if ($out -match 'version\s+"(?<ver>[0-9]+)\.') {
      return [int]$Matches['ver']
    }
  } catch { }
  return $null
}

function Ensure-Java17 {
  Param([string]$OverrideHome)
  if ($OverrideHome) {
    if (-not (Test-Path (Join-Path $OverrideHome 'bin\\java.exe'))) {
      throw "JavaHome especificado no es válido: $OverrideHome"
    }
    $env:JAVA_HOME = $OverrideHome
    $env:PATH = (Join-Path $env:JAVA_HOME 'bin') + ";" + $env:PATH
    return $OverrideHome
  }

  $v = Get-JavaVersionMajor
  if ($v -ge 17) { return }

  # Intentar usar JAVA_HOME_17_X64 si existe
  if (-not $OverrideHome) {
    $candidates = @()
    if ($env:JAVA_HOME_17_X64) { $candidates += $env:JAVA_HOME_17_X64 }
    if ($env:JDK_17) { $candidates += $env:JDK_17 }
    foreach ($home in $candidates) {
      if ($home -and (Test-Path (Join-Path $home 'bin\\java.exe'))) {
        $env:JAVA_HOME = $home
        $env:PATH = (Join-Path $env:JAVA_HOME 'bin') + ";" + $env:PATH
        break
      }
    }
  }

  $v2 = Get-JavaVersionMajor
  if ($v2 -ge 17) { return }
  
  # Intentar instalación automática vía winget
  try {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
      Write-Host 'Intentando instalar JDK 17 con winget (EclipseAdoptium.Temurin.17.JDK)...' -ForegroundColor Yellow
      $installArgs = 'install -e --id EclipseAdoptium.Temurin.17.JDK --accept-package-agreements --accept-source-agreements --silent'
      cmd /c "winget $installArgs"
      # Buscar instalación
      $candidates = @(
        'C:\\Program Files\\Eclipse Adoptium',
        'C:\\Program Files\\Java',
        'C:\\Program Files\\Microsoft'
      )
      $found = $null
      foreach ($root in $candidates) {
        if (Test-Path $root) {
          $paths = Get-ChildItem -Path $root -Recurse -Depth 2 -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*jdk-17*' }
          foreach ($p in $paths) {
            if (Test-Path (Join-Path $p.FullName 'bin\\java.exe')) { $found = $p.FullName; break }
          }
          if ($found) { break }
        }
      }
      if ($found) {
        $env:JAVA_HOME = $found
        $env:PATH = (Join-Path $env:JAVA_HOME 'bin') + ";" + $env:PATH
      }
    }
  } catch { }

  # Si aún no hay Java 17, intentar descargar Temurin 17 (ZIP) y usarlo localmente
  function Install-JDK17-FromAdoptium {
    try {
      Write-Host 'Descargando JDK 17 (Temurin) desde Adoptium API...' -ForegroundColor Yellow
      $api = 'https://api.adoptium.net/v3/assets/latest/17/hotspot?architecture=x64&heap_size=normal&image_type=jdk&jvm_impl=hotspot&os=windows&vendor=eclipse'
      $resp = Invoke-RestMethod -Method GET -Uri $api -UseBasicParsing -TimeoutSec 300
      if (-not $resp) { return }
      $first = $resp | Select-Object -First 1
      $zipUrl = $null
      if ($first -and $first.binary) {
        if ($first.binary.package -and $first.binary.package.link) { $zipUrl = $first.binary.package.link }
        elseif ($first.binary.link) { $zipUrl = $first.binary.link }
      }
      if (-not $zipUrl) { return }
      $tmpZip = Join-Path $env:TEMP 'jdk17-temurin.zip'
      Invoke-WebRequest -Uri $zipUrl -OutFile $tmpZip -UseBasicParsing
      $tools = Join-Path (Get-Location) '.tools'
      if (-not (Test-Path $tools)) { New-Item -ItemType Directory -Path $tools | Out-Null }
      Expand-Archive -Path $tmpZip -DestinationPath $tools -Force
      # Buscar carpeta extraída con bin\java.exe
      $candidate = Get-ChildItem -Path $tools -Directory | Where-Object { $_.Name -match 'jdk-?17' } | Select-Object -First 1
      if (-not $candidate) {
        $candidate = Get-ChildItem -Path $tools -Recurse -Directory -Depth 2 | Where-Object { Test-Path (Join-Path $_.FullName 'bin\\java.exe') } | Select-Object -First 1
      }
      if ($candidate -and (Test-Path (Join-Path $candidate.FullName 'bin\\java.exe'))) {
        $env:JAVA_HOME = $candidate.FullName
        $env:PATH = (Join-Path $env:JAVA_HOME 'bin') + ";" + $env:PATH
      }
    } catch { }
  }

  Install-JDK17-FromAdoptium

  $v3 = Get-JavaVersionMajor
  if ($v3 -ge 17) { return $env:JAVA_HOME }

  throw "Se requiere JDK 17. Instálalo o proporciona -JavaHome 'C:\\Ruta\\a\\jdk-17'"
}

Write-Host "=== Build APK ($Configuration) ===" -ForegroundColor Green

if ($Clean) {
  if (Test-Path 'dist') { Write-Host 'Limpieza: dist' -ForegroundColor Yellow; Remove-Item -Recurse -Force 'dist' }
  if (Test-Path 'android\\app\\build') { Write-Host 'Limpieza: android/app/build' -ForegroundColor Yellow; Remove-Item -Recurse -Force 'android\\app\\build' }
}

if (-not $SkipInstall) {
  if (Test-NpmInstalled) {
    Write-Host 'Dependencias npm detectadas. Omitiendo npm install.' -ForegroundColor Yellow
  } else {
    Invoke-Step -Command "npm install --no-audit --no-fund" -Description 'Instalar dependencias npm'
  }
}

if (-not $SkipBuild) {
  Invoke-Step -Command "npm run -s build" -Description 'Construir Angular (producción)'
}

if (-not (Test-Path 'capacitor.config.ts') -and -not (Test-Path 'capacitor.config.json')) {
  throw 'No se encontró capacitor.config.ts|json. Asegúrate de tener Capacitor configurado.'
}

if (-not $SkipSync) {
  Invoke-Step -Command "npx cap sync android" -Description 'Sincronizar Capacitor (web -> Android)'
}

$gradlewBat = Join-Path -Path 'android' -ChildPath 'gradlew.bat'
if (-not (Test-Path $gradlewBat)) {
  throw 'No se encontró android/gradlew.bat. ¿Se añadió la plataforma Android? Ejecuta: npx cap add android'
}

# Asegurar JDK 17 antes de invocar Gradle
$usedJavaHome = Ensure-Java17 -OverrideHome $JavaHome

$gradleTask = Resolve-GradleTask -Config $Configuration
$javaProp = ''
if ($usedJavaHome) {
  $javaProp = " -Dorg.gradle.java.home=`"$usedJavaHome`""
}
Invoke-Step -Command "cd android && gradlew.bat $gradleTask$javaProp" -Description "Compilar APK ($Configuration) con Gradle"

$apkPath = Get-ExpectedApkPath -Config $Configuration
Write-Host "APK generado o carpeta destino: $apkPath" -ForegroundColor Green

Write-Host "Listo. Puedes instalar el APK (debug) con: adb install `"$apkPath`"" -ForegroundColor Green


