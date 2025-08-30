Param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

try {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {}

Write-Host 'Descargando metadatos de JDK 17 (Temurin) desde Adoptium...' -ForegroundColor Cyan
$api = 'https://api.adoptium.net/v3/assets/latest/17/hotspot?architecture=x64&heap_size=normal&image_type=jdk&jvm_impl=hotspot&os=windows&vendor=eclipse'
$resp = Invoke-RestMethod -Method GET -Uri $api -UseBasicParsing -TimeoutSec 300
if (-not $resp) { throw 'No se pudo obtener metadatos de Adoptium' }

$asset = $resp | Select-Object -First 1
$zipUrl = $null
if ($asset -and $asset.binary) {
  if ($asset.binary.package -and $asset.binary.package.link) { $zipUrl = $asset.binary.package.link }
  elseif ($asset.binary.link) { $zipUrl = $asset.binary.link }
}
if (-not $zipUrl) { throw 'No se encontró enlace de descarga en la respuesta' }

Write-Host ("Descargando JDK 17 desde: {0}" -f $zipUrl) -ForegroundColor Cyan
$zipPath = Join-Path $env:TEMP 'jdk17-temurin.zip'
Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing

$toolsDir = Join-Path (Get-Location) '.tools'
if (-not (Test-Path $toolsDir)) { New-Item -ItemType Directory -Path $toolsDir | Out-Null }

Expand-Archive -Path $zipPath -DestinationPath $toolsDir -Force

# Buscar carpeta extraída que contenga bin\java.exe
$candidate = Get-ChildItem -Path $toolsDir -Directory | Where-Object { $_.Name -match 'jdk-?17' } | Select-Object -First 1
if (-not $candidate) {
  $candidate = Get-ChildItem -Path $toolsDir -Recurse -Directory -Depth 3 | Where-Object { Test-Path (Join-Path $_.FullName 'bin\java.exe') } | Select-Object -First 1
}
if (-not $candidate) { throw 'No se encontró carpeta JDK 17 extraída' }

$javaHome = $candidate.FullName
$marker = Join-Path $toolsDir 'jdk17.path'
Set-Content -Path $marker -Value $javaHome -Encoding ASCII

Write-Output $javaHome
Write-Host ("JDK 17 listo en: {0}" -f $javaHome) -ForegroundColor Green


