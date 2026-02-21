[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification='signtool requires plain text password argument for non-interactive CI signing')]
param(
  [switch]$Clean,
  [switch]$NoObfuscate,
  [switch]$SkipBuild,
  [switch]$ForcePubGet,
  [string]$CodeSignPfxPath,
  [string]$CodeSignPfxPassword,
  [string]$CodeSignCertThumbprint,
  [string]$CodeSignTimestampUrl = 'http://timestamp.digicert.com',
  [string]$GoogleOauthClientId,
  [string]$DropboxClientId,
  [string]$YandexClientId,
  [string]$YandexClientSecret,
  [string]$GDriveUpdateFolderId,
  [string]$GDriveUpdateFolderUrl
)

$ErrorActionPreference = 'Stop'

$global:InstallerMutex = $null
$global:InstallerMutexOwned = $false

function Enter-InstallerMutex {
  param(
    [string]$Name = 'Global\AltyaziEditoru_WindowsInstaller_Mutex',
    [int]$TimeoutMs = 120000
  )

  $global:InstallerMutex = New-Object System.Threading.Mutex($false, $Name)
  $global:InstallerMutexOwned = $global:InstallerMutex.WaitOne($TimeoutMs)
  if (-not $global:InstallerMutexOwned) {
    throw "Another installer build is currently running. Wait for it to finish and retry."
  }
}

function Exit-InstallerMutex {
  if ($global:InstallerMutexOwned -and $null -ne $global:InstallerMutex) {
    try {
      $global:InstallerMutex.ReleaseMutex() | Out-Null
    } catch {
    }
  }

  if ($null -ne $global:InstallerMutex) {
    $global:InstallerMutex.Dispose()
  }

  $global:InstallerMutexOwned = $false
  $global:InstallerMutex = $null
}

function Get-IsccPath {
  $candidates = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles(x86)\Inno Setup 6\ISCC.exe"
  )

  foreach ($candidate in $candidates) {
    if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path $candidate)) {
      return $candidate
    }
  }

  $command = Get-Command ISCC.exe -ErrorAction SilentlyContinue
  if ($null -ne $command) {
    return $command.Source
  }

  throw "Inno Setup compiler (ISCC.exe) not found. Install Inno Setup 6 and retry."
}

function Get-PubspecVersion {
  param(
    [Parameter(Mandatory = $true)]
    [string]$PubspecPath
  )

  if (-not (Test-Path $PubspecPath)) {
    throw "pubspec.yaml not found: $PubspecPath"
  }

  $versionLine = Get-Content -Path $PubspecPath | Where-Object { $_ -match '^\s*version\s*:' } | Select-Object -First 1
  if ([string]::IsNullOrWhiteSpace($versionLine)) {
    throw "Could not find 'version' field in pubspec.yaml"
  }

  $rawVersion = ($versionLine -replace '^\s*version\s*:\s*', '').Trim()
  if ([string]::IsNullOrWhiteSpace($rawVersion)) {
    throw "pubspec.yaml version is empty"
  }

  return ($rawVersion -split '\+')[0]
}

function Get-SignToolPath {
  $candidates = @(
    "$env:ProgramFiles (x86)\Windows Kits\10\bin\x64\signtool.exe",
    "$env:ProgramFiles\Windows Kits\10\bin\x64\signtool.exe"
  )

  foreach ($candidate in $candidates) {
    if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path $candidate)) {
      return $candidate
    }
  }

  $command = Get-Command signtool.exe -ErrorAction SilentlyContinue
  if ($null -ne $command) {
    return $command.Source
  }

  throw "signtool.exe not found. Install Windows SDK Signing Tools and retry."
}

function Test-CodeSigningConfigured {
  return (
    -not [string]::IsNullOrWhiteSpace($CodeSignCertThumbprint) -or
    -not [string]::IsNullOrWhiteSpace($CodeSignPfxPath)
  )
}

function Write-InstallerHowToInstallFile {
  param(
    [Parameter(Mandatory = $true)]
    [string]$OutputDir
  )

  if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
  }

  $targetPath = Join-Path $OutputDir 'how to install.txt'

  $content = @"
AI Subtitle Translator & Editor - How to Install (Unsigned Build)

EN:
Why antivirus may warn:
Unsigned installers/apps can look suspicious to heuristic scanners, especially after a new release, when reputation is low, files are packed/obfuscated, or binaries changed. This does not always mean malware.
If antivirus blocks or quarantines the installer/app:
1) Open Windows Security > Virus & threat protection > Protection history.
2) Find this installer/app event and choose Restore / Allow on device.
3) Add exclusion for installer file and install folder if needed.
4) Re-download from official source and run installer again.
1) Download the installer from the official source.
2) If Windows SmartScreen appears, click More info > Run anyway.
3) Right click installer and choose Run as administrator.
4) Complete setup and launch the app.

TR:
Neden antivirüs uyarısı çıkar:
İmzasız yükleyiciler/uygulamalar, özellikle yeni sürümlerde itibar düşük olduğunda, dosyalar paketli/obfuscate olduğunda veya ikili dosyalar değiştiğinde sezgisel taramalarda şüpheli görünebilir. Bu her zaman zararlı yazılım olduğu anlamına gelmez.
Antivirüs engeller veya karantinaya alırsa:
1) Windows Güvenliği > Virüs ve tehdit koruması > Koruma geçmişi bölümünü açın.
2) Bu kurulum/uygulama kaydını bulun ve Geri yükle / Cihaza izin ver seçin.
3) Gerekirse kurulum dosyası ve kurulum klasörü için hariç tutma ekleyin.
4) Kurulumu resmi kaynaktan yeniden indirip tekrar çalıştırın.
1) Kurulumu resmi kaynaktan indirin.
2) Windows SmartScreen çıkarsa Daha fazla bilgi > Yine de çalıştır'a tıklayın.
3) Kuruluma sağ tıklayıp Yönetici olarak çalıştır seçin.
4) Kurulumu tamamlayın ve uygulamayı açın.

FR:
Pourquoi l'antivirus peut afficher une alerte :
Les installateurs/applications non signés peuvent paraître suspects pour l'analyse heuristique, surtout après une nouvelle version, lorsque la réputation est faible, que les fichiers sont empaquetés/obfusqués ou que les binaires ont changé. Cela ne signifie pas toujours un malware.
Si l'antivirus bloque ou met en quarantaine :
1) Ouvrez Sécurité Windows > Protection contre les virus et menaces > Historique de protection.
2) Trouvez l'événement de cet installateur/app et choisissez Restaurer / Autoriser sur l'appareil.
3) Ajoutez une exclusion pour le fichier d'installation et le dossier d'installation si nécessaire.
4) Retéléchargez depuis la source officielle puis relancez l'installation.
1) Téléchargez l'installateur depuis la source officielle.
2) Si SmartScreen s'affiche, cliquez sur Informations complémentaires > Exécuter quand même.
3) Clic droit sur l'installateur puis Exécuter en tant qu'administrateur.
4) Terminez l'installation et lancez l'application.

DE:
Warum Antivirus warnen kann:
Unsigneierte Installer/Apps können für heuristische Scanner verdächtig wirken, besonders direkt nach einem Release, bei geringer Reputation, gepackten/obfuskierten Dateien oder geänderten Binärdateien. Das bedeutet nicht automatisch Malware.
Wenn Antivirus blockiert oder in Quarantäne verschiebt:
1) Öffne Windows-Sicherheit > Viren- & Bedrohungsschutz > Schutzverlauf.
2) Suche den Eintrag zu diesem Installer/App und wähle Wiederherstellen / Auf Gerät zulassen.
3) Füge bei Bedarf Ausnahmen für Installer-Datei und Installationsordner hinzu.
4) Lade die Datei erneut aus offizieller Quelle und starte die Installation erneut.
1) Lade den Installer aus der offiziellen Quelle herunter.
2) Falls SmartScreen erscheint: Weitere Informationen > Trotzdem ausführen.
3) Rechtsklick auf den Installer > Als Administrator ausführen.
4) Installation abschließen und App starten.

IT:
Perché l'antivirus può mostrare un avviso:
Installer/app non firmati possono sembrare sospetti ai controlli euristici, soprattutto dopo una nuova release, con reputazione bassa, file impacchettati/offuscati o binari modificati. Non significa sempre malware.
Se l'antivirus blocca o mette in quarantena:
1) Apri Sicurezza di Windows > Protezione da virus e minacce > Cronologia protezione.
2) Trova l'evento relativo a questo installer/app e scegli Ripristina / Consenti nel dispositivo.
3) Aggiungi un'esclusione per file installer e cartella di installazione se necessario.
4) Riscarica dalla fonte ufficiale e avvia di nuovo l'installazione.
1) Scarica l'installer dalla fonte ufficiale.
2) Se compare SmartScreen: Altre informazioni > Esegui comunque.
3) Clic destro sull'installer > Esegui come amministratore.
4) Completa l'installazione e avvia l'app.

ES:
Por qué el antivirus puede mostrar una alerta:
Los instaladores/aplicaciones sin firma pueden parecer sospechosos para el análisis heurístico, especialmente tras una nueva versión, con baja reputación, archivos empaquetados/ofuscados o binarios cambiados. No siempre significa malware.
Si el antivirus bloquea o pone en cuarentena:
1) Abre Seguridad de Windows > Protección contra virus y amenazas > Historial de protección.
2) Busca el evento de este instalador/app y elige Restaurar / Permitir en el dispositivo.
3) Agrega una exclusión para el instalador y la carpeta de instalación si hace falta.
4) Vuelve a descargar desde la fuente oficial y ejecuta otra vez.
1) Descarga el instalador desde la fuente oficial.
2) Si aparece SmartScreen: Más información > Ejecutar de todas formas.
3) Clic derecho en el instalador > Ejecutar como administrador.
4) Completa la instalación y abre la app.

PT:
Por que o antivírus pode alertar:
Instaladores/apps sem assinatura podem parecer suspeitos para análise heurística, especialmente após uma nova versão, com baixa reputação, arquivos empacotados/ofuscados ou binários alterados. Isso nem sempre significa malware.
Se o antivírus bloquear ou colocar em quarentena:
1) Abra Segurança do Windows > Proteção contra vírus e ameaças > Histórico de proteção.
2) Encontre o evento deste instalador/app e escolha Restaurar / Permitir no dispositivo.
3) Adicione exclusão para o arquivo instalador e pasta de instalação, se necessário.
4) Baixe novamente da fonte oficial e execute outra vez.
1) Baixe o instalador da fonte oficial.
2) Se o SmartScreen aparecer: Mais informações > Executar assim mesmo.
3) Clique com o botão direito no instalador > Executar como administrador.
4) Conclua a instalação e inicie o app.

RU:
Почему антивирус может предупреждать:
Неподписанные установщики/приложения могут выглядеть подозрительно для эвристики, особенно сразу после релиза, при низкой репутации, упаковке/обфускации или изменении бинарников. Это не всегда означает вредоносное ПО.
Если антивирус блокирует или помещает в карантин:
1) Откройте Безопасность Windows > Защита от вирусов и угроз > Журнал защиты.
2) Найдите событие для этого установщика/приложения и выберите Восстановить / Разрешить на устройстве.
3) При необходимости добавьте исключение для файла установщика и папки установки.
4) Скачайте снова из официального источника и повторите запуск.
1) Скачайте установщик из официального источника.
2) Если появится SmartScreen: Дополнительно > Выполнить в любом случае.
3) Нажмите правой кнопкой по установщику > Запуск от имени администратора.
4) Завершите установку и запустите приложение.

EL:
Γιατί μπορεί να εμφανιστεί προειδοποίηση από antivirus:
Μη υπογεγραμμένοι εγκαταστάτες/εφαρμογές μπορεί να φαίνονται ύποπτοι σε ευρετικούς ελέγχους, ειδικά μετά από νέα έκδοση, με χαμηλή φήμη, πακεταρισμένα/obfuscated αρχεία ή αλλαγμένα binaries. Αυτό δεν σημαίνει πάντα κακόβουλο λογισμικό.
Αν το antivirus μπλοκάρει ή βάλει σε καραντίνα:
1) Άνοιξε Windows Security > Virus & threat protection > Protection history.
2) Βρες το συμβάν για αυτόν τον installer/app και επίλεξε Restore / Allow on device.
3) Πρόσθεσε εξαίρεση για το αρχείο installer και τον φάκελο εγκατάστασης αν χρειάζεται.
4) Κατέβασε ξανά από την επίσημη πηγή και ξανατρέξε την εγκατάσταση.
1) Κατεβάστε το πρόγραμμα εγκατάστασης από επίσημη πηγή.
2) Αν εμφανιστεί SmartScreen: Περισσότερες πληροφορίες > Εκτέλεση ούτως ή άλλως.
3) Δεξί κλικ στο αρχείο εγκατάστασης > Εκτέλεση ως διαχειριστής.
4) Ολοκληρώστε την εγκατάσταση και ανοίξτε την εφαρμογή.

AR:
لماذا قد يظهر تحذير من مضاد الفيروسات:
قد تبدو أدوات التثبيت/التطبيقات غير الموقعة مشبوهة للفحص السلوكي، خاصة بعد إصدار جديد أو عند انخفاض السمعة أو عند وجود ضغط/إخفاء للكود أو تغيّر الملفات الثنائية. هذا لا يعني دائماً وجود برمجية خبيثة.
إذا قام مضاد الفيروسات بالحظر أو الحجر:
1) افتح Windows Security > Virus & threat protection > Protection history.
2) ابحث عن حدث هذا المُثبّت/التطبيق واختر Restore / Allow on device.
3) أضف استثناءً لملف المُثبّت ومجلد التثبيت عند الحاجة.
4) أعد التنزيل من المصدر الرسمي ثم شغّل التثبيت مرة أخرى.
1) قم بتنزيل المثبّت من المصدر الرسمي.
2) إذا ظهرت SmartScreen اختر مزيد من المعلومات ثم تشغيل على أي حال.
3) اضغط بزر الفأرة الأيمن على المثبّت واختر تشغيل كمسؤول.
4) أكمل التثبيت ثم شغّل التطبيق.

IN:
एंटीवायरस चेतावनी क्यों दिखा सकता है:
अनसाइन किए गए इंस्टॉलर/ऐप heuristic स्कैन में संदिग्ध लग सकते हैं, खासकर नई रिलीज़ के बाद, कम प्रतिष्ठा, पैक/obfuscate फाइलें या बदले हुए बाइनरी होने पर। इसका मतलब हमेशा malware नहीं होता।
अगर एंटीवायरस ब्लॉक/क्वारंटीन करे:
1) Windows Security > Virus & threat protection > Protection history खोलें।
2) इस इंस्टॉलर/ऐप की एंट्री ढूंढें और Restore / Allow on device चुनें।
3) ज़रूरत हो तो इंस्टॉलर फ़ाइल और इंस्टॉल फ़ोल्डर के लिए exclusion जोड़ें।
4) आधिकारिक स्रोत से फिर डाउनलोड करके दोबारा चलाएँ।
1) इंस्टॉलर आधिकारिक स्रोत से डाउनलोड करें।
2) यदि SmartScreen दिखे तो More info > Run anyway चुनें।
3) इंस्टॉलर पर राइट-क्लिक करके Run as administrator चुनें।
4) इंस्टॉलेशन पूरा करें और ऐप खोलें।

ID:
Mengapa antivirus bisa memberi peringatan:
Installer/aplikasi tanpa tanda tangan bisa terlihat mencurigakan bagi pemindaian heuristik, terutama setelah rilis baru, saat reputasi masih rendah, file dipaketkan/diobfuscate, atau biner berubah. Ini tidak selalu berarti malware.
Jika antivirus memblokir atau mengarantina:
1) Buka Windows Security > Virus & threat protection > Protection history.
2) Cari event installer/app ini lalu pilih Restore / Allow on device.
3) Tambahkan exclusion untuk file installer dan folder instalasi bila perlu.
4) Unduh ulang dari sumber resmi lalu jalankan kembali.
1) Unduh installer dari sumber resmi.
2) Jika SmartScreen muncul, pilih More info > Run anyway.
3) Klik kanan installer lalu pilih Run as administrator.
4) Selesaikan instalasi dan jalankan aplikasi.

CN:
为什么杀毒软件会报警：
未签名的安装包/应用在启发式扫描中可能被判定为可疑，尤其是新版本刚发布、信誉尚低、文件经过打包/混淆或二进制发生变化时。这并不一定代表恶意软件。
如果被杀毒软件拦截或隔离：
1) 打开 Windows 安全中心 > 病毒和威胁防护 > 保护历史记录。
2) 找到该安装包/应用的记录，并选择 恢复 / 允许在设备上。
3) 必要时为安装包文件和安装目录添加排除项。
4) 从官方来源重新下载后再次运行安装。
1) 请从官方来源下载安装程序。
2) 若出现 SmartScreen，请点击 更多信息 > 仍要运行。
3) 右键安装程序并选择 以管理员身份运行。
4) 完成安装并启动应用。

JA:
ウイルス対策ソフトが警告する理由：
未署名のインストーラー/アプリは、特に新規リリース直後で評価が低い場合、ファイルのパック/難読化、バイナリ変更がある場合に、ヒューリスティック検出で疑わしいと判定されることがあります。必ずしもマルウェアを意味しません。
ウイルス対策ソフトによりブロック/隔離された場合：
1) Windows セキュリティ > ウイルスと脅威の防止 > 保護の履歴 を開きます。
2) このインストーラー/アプリの項目を見つけ、復元 / デバイスで許可 を選びます。
3) 必要に応じてインストーラーファイルとインストール先フォルダを除外に追加します。
4) 公式配布元から再ダウンロードして再実行します。
1) 公式配布元からインストーラーをダウンロードしてください。
2) SmartScreen が表示されたら「詳細情報」>「実行」を選択します。
3) インストーラーを右クリックして「管理者として実行」を選択します。
4) インストール完了後、アプリを起動します。

KO:
백신 경고가 뜨는 이유:
서명되지 않은 설치 프로그램/앱은 휴리스틱 검사에서 의심 대상으로 보일 수 있습니다. 특히 신규 배포 직후 평판이 낮거나, 파일이 패키징/난독화되어 있거나, 바이너리가 변경된 경우에 더 자주 발생합니다. 항상 악성코드를 의미하는 것은 아닙니다.
백신이 차단하거나 격리한 경우:
1) Windows 보안 > 바이러스 및 위협 방지 > 보호 기록을 엽니다.
2) 해당 설치 프로그램/앱 항목을 찾아 복원 / 장치에서 허용을 선택합니다.
3) 필요하면 설치 파일과 설치 폴더를 예외로 추가합니다.
4) 공식 배포처에서 다시 다운로드 후 재실행합니다.
1) 공식 배포처에서 설치 파일을 다운로드하세요.
2) SmartScreen 경고가 나오면 추가 정보 > 실행을 선택하세요.
3) 설치 파일을 마우스 오른쪽 클릭 후 관리자 권한으로 실행하세요.
4) 설치를 완료하고 앱을 실행하세요.
"@

  Set-Content -Path $targetPath -Value $content -Encoding utf8
  return $targetPath
}

function Invoke-GenerateIcoFromAppLogo {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,
    [Parameter(Mandatory = $true)]
    [string]$OutputPath
  )

  $generatorScript = Join-Path $RepoRoot 'tool/generate_installer_icon.dart'
  if (-not (Test-Path $generatorScript)) {
    Write-Warning "Icon generator not found: $generatorScript"
    return
  }

  $sourcePng = Join-Path $RepoRoot 'assets/icon/app_icon.png'
  if (-not (Test-Path $sourcePng)) {
    throw "App logo PNG not found: $sourcePng"
  }

  $absoluteOut = $OutputPath
  if (-not [System.IO.Path]::IsPathRooted($absoluteOut)) {
    $absoluteOut = Join-Path $RepoRoot $OutputPath
  }

  $outDir = Split-Path -Parent $absoluteOut
  if (-not [string]::IsNullOrWhiteSpace($outDir) -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
  }

  Write-Host "Generating ICO: $absoluteOut"
  & dart run $generatorScript $sourcePng $absoluteOut
  if ($LASTEXITCODE -ne 0) {
    throw "generate_installer_icon.dart failed with exit code $LASTEXITCODE"
  }
}

function Invoke-GenerateAllWindowsIcons {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot
  )

  Write-Host 'Generating Windows icons from assets/icon/app_icon.png...'
  Invoke-GenerateIcoFromAppLogo -RepoRoot $RepoRoot -OutputPath 'tool/installer_icon.ico'
  Invoke-GenerateIcoFromAppLogo -RepoRoot $RepoRoot -OutputPath 'windows/runner/resources/app_icon.ico'
  Invoke-GenerateIcoFromAppLogo -RepoRoot $RepoRoot -OutputPath 'windows/runner/resources/tray_icon.ico'
}

function Invoke-CodeSign {
  param(
    [Parameter(Mandatory = $true)]
    [string]$TargetFile
  )

  if (-not (Test-CodeSigningConfigured)) {
    return
  }

  if (-not (Test-Path $TargetFile)) {
    throw "Code sign target not found: $TargetFile"
  }

  $signToolPath = Get-SignToolPath
  $signArgs = @('sign', '/fd', 'SHA256', '/td', 'SHA256', '/tr', $CodeSignTimestampUrl)

  if (-not [string]::IsNullOrWhiteSpace($CodeSignCertThumbprint)) {
    $signArgs += @('/sha1', $CodeSignCertThumbprint)
  } elseif (-not [string]::IsNullOrWhiteSpace($CodeSignPfxPath)) {
    if (-not (Test-Path $CodeSignPfxPath)) {
      throw "Code signing PFX not found: $CodeSignPfxPath"
    }
    $signArgs += @('/f', $CodeSignPfxPath)
    if (-not [string]::IsNullOrWhiteSpace($CodeSignPfxPassword)) {
      $signArgs += @('/p', $CodeSignPfxPassword)
    }
  }

  $signArgs += $TargetFile

  & $signToolPath @signArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Code signing failed for '$TargetFile' with exit code $LASTEXITCODE"
  }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$releaseScript = Join-Path $PSScriptRoot 'build_windows_release.ps1'
$installerScript = Join-Path $PSScriptRoot 'windows_installer.iss'
$pubspecPath = Join-Path $repoRoot 'pubspec.yaml'

if (-not (Test-Path $releaseScript)) {
  throw "Release script not found: $releaseScript"
}

if (-not (Test-Path $installerScript)) {
  throw "Installer script not found: $installerScript"
}

Enter-InstallerMutex
try {
  Push-Location $repoRoot
  try {
    # Always (re)generate icons first so both the compiled EXE and the installer
    # reflect the latest app logo.
    Invoke-GenerateAllWindowsIcons -RepoRoot $repoRoot

    if (-not $SkipBuild) {
      $releaseArgs = @()
      if ($Clean) { $releaseArgs += '-Clean' }
      if ($NoObfuscate) { $releaseArgs += '-NoObfuscate' }
      if ($ForcePubGet) { $releaseArgs += '-ForcePubGet' }
      if (-not [string]::IsNullOrWhiteSpace($CodeSignPfxPath)) {
        $releaseArgs += '-CodeSignPfxPath'
        $releaseArgs += $CodeSignPfxPath
      }
      if (-not [string]::IsNullOrWhiteSpace($CodeSignPfxPassword)) {
        $releaseArgs += '-CodeSignPfxPassword'
        $releaseArgs += $CodeSignPfxPassword
      }
      if (-not [string]::IsNullOrWhiteSpace($CodeSignCertThumbprint)) {
        $releaseArgs += '-CodeSignCertThumbprint'
        $releaseArgs += $CodeSignCertThumbprint
      }
      if ((Test-CodeSigningConfigured) -and -not [string]::IsNullOrWhiteSpace($CodeSignTimestampUrl)) {
        $releaseArgs += '-CodeSignTimestampUrl'
        $releaseArgs += $CodeSignTimestampUrl
      }
      if (-not [string]::IsNullOrWhiteSpace($GoogleOauthClientId)) {
        $releaseArgs += '-GoogleOauthClientId'
        $releaseArgs += $GoogleOauthClientId
      }
      if (-not [string]::IsNullOrWhiteSpace($DropboxClientId)) {
        $releaseArgs += '-DropboxClientId'
        $releaseArgs += $DropboxClientId
      }
      if (-not [string]::IsNullOrWhiteSpace($YandexClientId)) {
        $releaseArgs += '-YandexClientId'
        $releaseArgs += $YandexClientId
      }
      if (-not [string]::IsNullOrWhiteSpace($YandexClientSecret)) {
        $releaseArgs += '-YandexClientSecret'
        $releaseArgs += $YandexClientSecret
      }
      if (-not [string]::IsNullOrWhiteSpace($GDriveUpdateFolderId)) {
        $releaseArgs += '-GDriveUpdateFolderId'
        $releaseArgs += $GDriveUpdateFolderId
      }
      if (-not [string]::IsNullOrWhiteSpace($GDriveUpdateFolderUrl)) {
        $releaseArgs += '-GDriveUpdateFolderUrl'
        $releaseArgs += $GDriveUpdateFolderUrl
      }

      & $releaseScript @releaseArgs
      if ($LASTEXITCODE -ne 0) {
        throw "Release build failed with exit code $LASTEXITCODE"
      }
    }

    $isccPath = Get-IsccPath
    $pubspecVersion = Get-PubspecVersion -PubspecPath $pubspecPath
    $installerOutDir = Join-Path $repoRoot 'build/windows/installer'
    $guideSourceDir = $PSScriptRoot
    $howToInstallPath = Write-InstallerHowToInstallFile -OutputDir $guideSourceDir
    Write-Host "Install guide source ready: $howToInstallPath"

    if (-not (Test-Path $installerOutDir)) {
      New-Item -ItemType Directory -Path $installerOutDir -Force | Out-Null
    }

    $installerBaseName = "AI_Subtitle_Translator_Editor_Desktop_v$pubspecVersion"
    $expectedInstallerPath = Join-Path $installerOutDir "$installerBaseName.exe"

    if (Test-Path $expectedInstallerPath) {
      try {
        $item = Get-Item -LiteralPath $expectedInstallerPath -ErrorAction Stop
        $item.Attributes = 'Normal'
      } catch {
      }

      try {
        Remove-Item -LiteralPath $expectedInstallerPath -Force -ErrorAction Stop
      } catch {
        Write-Warning "Previous installer output is in use and could not be deleted: $expectedInstallerPath"
      }
    }

    Write-Host "Using pubspec version for installer: $pubspecVersion"

    $compileSucceeded = $false
    $attempts = 0
    while (-not $compileSucceeded -and $attempts -lt 3) {
      $attempts++
      & $isccPath "/DMyAppVersion=$pubspecVersion" "/O$installerOutDir" "/F$installerBaseName" $installerScript
      if ($LASTEXITCODE -eq 0) {
        $compileSucceeded = $true
        break
      }

      # Common failure: output file is locked by AV/Explorer. Wait and retry.
      Write-Warning "Installer compile attempt $attempts failed with exit code $LASTEXITCODE. Retrying..."
      Start-Sleep -Seconds (2 * $attempts)

      if (Test-Path $expectedInstallerPath) {
        try {
          $item = Get-Item -LiteralPath $expectedInstallerPath -ErrorAction Stop
          $item.Attributes = 'Normal'
        } catch {
        }
        try {
          Remove-Item -LiteralPath $expectedInstallerPath -Force -ErrorAction Stop
        } catch {
        }
      }
    }

    if (-not $compileSucceeded) {
      throw "Installer compile failed after $attempts attempt(s). If the output file is locked, close any Explorer preview/AV quarantine window and retry."
    }

    if (Test-Path $installerOutDir) {
      $guideOutputPath = Join-Path $installerOutDir 'how to install.txt'
      Copy-Item -Path $howToInstallPath -Destination $guideOutputPath -Force
      Write-Host "Install guide ready: $guideOutputPath"

      $latest = Get-ChildItem -Path $installerOutDir -Filter '*.exe' |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

      if ($null -ne $latest) {
        if (Test-CodeSigningConfigured) {
          Invoke-CodeSign -TargetFile $latest.FullName
          Write-Host "Signed installer: $($latest.FullName)"
        } else {
          Write-Warning 'Installer is unsigned. Unsigned installers are commonly blocked by SmartScreen/antivirus.'
        }
        Write-Host "Installer ready: $($latest.FullName)"
      }
    }
  } finally {
    Pop-Location
  }
} finally {
  Exit-InstallerMutex
}
