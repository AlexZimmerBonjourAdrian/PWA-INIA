Param(
  [Parameter(Position=0)]
  [string]$Option = 'help'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Show-Usage {
  Write-Host "Uso: .\\run.ps1 <opcion>" -ForegroundColor Cyan
  Write-Host "Opciones:" -ForegroundColor Cyan
  Write-Host "  1  Compilar APK (debug)" -ForegroundColor Gray
  Write-Host "  2  Compilar APK (release)" -ForegroundColor Gray
  Write-Host "  3  Iniciar servidor de desarrollo (npm start)" -ForegroundColor Gray
  Write-Host "  4  Build web (Angular producción)" -ForegroundColor Gray
  Write-Host "  5  Sincronizar Capacitor Android (npx cap sync android)" -ForegroundColor Gray
  Write-Host "  6  Instalar JDK 17 portátil (.tools)" -ForegroundColor Gray
  Write-Host "  7  Abrir Android Studio (npx cap open android)" -ForegroundColor Gray
}

switch ($Option) {
  '1' {
    & .\PowerShell.ps1 -Configuration debug
    break
  }
  '2' {
    & .\PowerShell.ps1 -Configuration release
    break
  }
  '3' {
    Write-Host "Iniciando servidor de desarrollo..." -ForegroundColor Green
    Start-Process powershell -ArgumentList "-NoExit","-Command","npm start"
    break
  }
  '4' {
    Write-Host "Ejecutando build de producción (web)..." -ForegroundColor Green
    cmd /c "npm run -s build"
    break
  }
  '5' {
    Write-Host "Sincronizando Capacitor Android..." -ForegroundColor Green
    cmd /c "npx cap sync android"
    break
  }
  '6' {
    Write-Host "Instalando JDK 17 portátil en .tools..." -ForegroundColor Green
    & .\scripts\InstallJdk17.ps1
    break
  }
  '7' {
    Write-Host "Abriendo proyecto Android en Android Studio..." -ForegroundColor Green
    cmd /c "npx cap open android"
    break
  }
  Default { Show-Usage }
}


