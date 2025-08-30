# PwaIniaProject

Proyecto generado con [Angular CLI](https://github.com/angular/angular-cli) v20.2.1 y actualizado para funcionar como PWA e incluir empaquetado Android (APK) con Capacitor.

## Cambios principales realizados

- PWA habilitado con `@angular/pwa`.
  - Registro del Service Worker en `src/app/app.config.ts` con `provideServiceWorker('ngsw-worker.js', { enabled: !isDevMode(), registrationStrategy: 'registerWhenStable:30000' })`.
  - `manifest.webmanifest` en `public/` y enlace en `src/index.html` (se corrigieron duplicados).
  - `ngsw-config.json` para caché de assets y PWA.
- Redirección al iniciar la app hacia `https://zimmzimmgames.com` en `src/app/app.ts`.
- Integración de Capacitor para Android:
  - Paquetes: `@capacitor/core`, `@capacitor/cli`, `@capacitor/android`.
  - Configuración en `capacitor.config.ts` con `webDir: 'dist/pwa-inia-project/browser'` y `server.allowNavigation: ['zimmzimmgames.com']`.
  - Proyecto Android agregado en `android/` y sincronizado.
- Script de automatización `PowerShell.ps1` para construir APK (debug/release). Incluye manejo de JDK 17 (auto-descarga portátil si falta) y `-JavaHome` opcional.
- Script auxiliar `scripts/InstallJdk17.ps1` para descargar/instalar JDK 17 (portátil) en `.tools/`.

## Requisitos

- Node.js 18/20.
- JDK 17 (el script puede descargar una versión portátil en `.tools`).
- Android SDK (el wrapper Gradle puede instalar componentes faltantes automáticamente al compilar).

## Desarrollo

Inicia el servidor local de desarrollo:

```bash
npm start
```

Luego abre `http://localhost:4200/`. En ejecución normal, la app redirige a `https://zimmzimmgames.com` al iniciar.

## Build web (PWA)

Compilar en producción:

```bash
npm run build
```

El resultado queda en `dist/pwa-inia-project/browser`. Para probar el Service Worker, sirve la carpeta estática (por ejemplo):

```bash
npx http-server dist/pwa-inia-project/browser -p 8080
```

## Android (APK) con Capacitor

Sincronizar Capacitor y plugins (si cambiaste la web):

```bash
npx cap sync android
```

Generar APK con el script PowerShell (debug por defecto):

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerShell.ps1 -Configuration debug
```

Si tienes un JDK 17 específico, pásalo explícitamente:

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerShell.ps1 -Configuration debug -JavaHome "C:\Program Files\Eclipse Adoptium\jdk-17"
```

El script:

- Instala dependencias npm (omitible con `-SkipInstall`).
- Compila Angular producción (omitible con `-SkipBuild`).
- Sincroniza Capacitor (`npx cap sync android`, omitible con `-SkipSync`).
- Asegura JDK 17 (detecta, intenta instalar o usa `-JavaHome`).
- Compila APK con Gradle.

Salida esperada (debug):

```
android\app\build\outputs\apk\debug\app-debug.apk
```

Instalar en dispositivo/emulador:

```powershell
adb install "android\app\build\outputs\apk\debug\app-debug.apk"
```

Para release:

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerShell.ps1 -Configuration release
```

## Ejecución rápida (run.ps1)

Menú rápido para tareas comunes (build APK, dev server, sync, instalar JDK 17):

```powershell
./run.ps1 1
```

Si hay restricción de ejecución:

```powershell
powershell -ExecutionPolicy Bypass -File .\run.ps1 1
```

Opciones disponibles:

- 1: Compilar APK (debug)
- 2: Compilar APK (release)
- 3: Iniciar servidor de desarrollo (npm start)
- 4: Build web (Angular producción)
- 5: Sincronizar Capacitor Android (npx cap sync android)
- 6: Instalar JDK 17 portátil (.tools)
- 7: Abrir Android Studio (npx cap open android)

Nota: Para firmar release, necesitarás un keystore y configurar firma en el proyecto Android (se puede automatizar en una iteración futura).

## Comandos útiles

- Servir en desarrollo: `npm start`
- Build producción (web): `npm run build`
- Sincronizar Capacitor: `npx cap sync android`
- Abrir Android Studio (opcional): `npx cap open android`

## Referencias

- Angular PWA: `https://angular.dev/tools/pwa`
- Capacitor: `https://capacitorjs.com/`

