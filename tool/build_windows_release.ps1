[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification='signtool requires plain text password argument for non-interactive CI signing')]
param(
  [switch]$Clean,
  [switch]$NoObfuscate,
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
$script:IsWindowsHost = ($env:OS -eq 'Windows_NT')

$global:BuildMutex = $null
$global:BuildMutexOwned = $false

function Enter-BuildMutex {
  param(
    [string]$Name = 'Global\AltyaziEditoru_WindowsBuild_Mutex',
    [int]$TimeoutMs = 120000
  )

  $global:BuildMutex = New-Object System.Threading.Mutex($false, $Name)
  $global:BuildMutexOwned = $global:BuildMutex.WaitOne($TimeoutMs)
  if (-not $global:BuildMutexOwned) {
    throw "Another Windows build is currently running. Wait for it to finish and retry."
  }
}

function Exit-BuildMutex {
  if ($global:BuildMutexOwned -and $null -ne $global:BuildMutex) {
    try {
      $global:BuildMutex.ReleaseMutex() | Out-Null
    } catch {
    }
  }

  if ($null -ne $global:BuildMutex) {
    $global:BuildMutex.Dispose()
  }

  $global:BuildMutexOwned = $false
  $global:BuildMutex = $null
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

function Invoke-CheckedFlutter {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$CliArgs
  )

  & flutter @CliArgs
  if ($LASTEXITCODE -ne 0) {
    throw "flutter $($CliArgs -join ' ') failed with exit code $LASTEXITCODE"
  }
}

function Test-PubGetRequired {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,
    [switch]$Force
  )

  if ($Force) {
    return $true
  }

  $packageConfigPath = Join-Path $RepoRoot '.dart_tool/package_config.json'
  if (-not (Test-Path $packageConfigPath)) {
    return $true
  }

  $pubspecPath = Join-Path $RepoRoot 'pubspec.yaml'
  $pubspecLockPath = Join-Path $RepoRoot 'pubspec.lock'
  $packageConfigMtime = (Get-Item $packageConfigPath).LastWriteTimeUtc

  if (Test-Path $pubspecPath) {
    $pubspecMtime = (Get-Item $pubspecPath).LastWriteTimeUtc
    if ($pubspecMtime -gt $packageConfigMtime) {
      return $true
    }
  }

  if (Test-Path $pubspecLockPath) {
    $pubspecLockMtime = (Get-Item $pubspecLockPath).LastWriteTimeUtc
    if ($pubspecLockMtime -gt $packageConfigMtime) {
      return $true
    }
  }

  return $false
}

function Get-VsDevCmdPath {
  if (-not $script:IsWindowsHost) {
    return $null
  }

  $vswherePath = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
  if (Test-Path $vswherePath) {
    $installationPath = & $vswherePath -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
    if (-not [string]::IsNullOrWhiteSpace($installationPath)) {
      $vsDevCmdCandidate = Join-Path $installationPath 'Common7\Tools\VsDevCmd.bat'
      if (Test-Path $vsDevCmdCandidate) {
        return $vsDevCmdCandidate
      }
    }
  }

  $candidates = @(
    'C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat',
    'C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\Tools\VsDevCmd.bat',
    'C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\VsDevCmd.bat',
    'C:\Program Files\Microsoft Visual Studio\17\Community\Common7\Tools\VsDevCmd.bat',
    'C:\Program Files\Microsoft Visual Studio\18\Community\Common7\Tools\VsDevCmd.bat'
  )

  foreach ($candidate in $candidates) {
    if (Test-Path $candidate) {
      return $candidate
    }
  }

  return $null
}

function Import-VsDevCmdEnvironment {
  if (-not $script:IsWindowsHost) {
    return
  }

  $vsDevCmd = Get-VsDevCmdPath
  if ([string]::IsNullOrWhiteSpace($vsDevCmd)) {
    throw 'Visual Studio C++ build tools not found. Install Visual Studio 2022 (Desktop development with C++) and retry.'
  }

  $output = & cmd /c "`"$vsDevCmd`" -arch=x64 -host_arch=x64 >nul && set"
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to initialize VS developer environment using: $vsDevCmd"
  }

  $loaded = $false
  foreach ($line in $output) {
    if ($line -match '^([^=]+)=(.*)$') {
      $name = $matches[1]
      $value = $matches[2]
      [Environment]::SetEnvironmentVariable($name, $value, 'Process')
      if ($name -eq 'VSCMD_VER' -and -not [string]::IsNullOrWhiteSpace($value)) {
        $loaded = $true
      }
    }
  }

  if (-not $loaded) {
    throw "VS developer environment did not load correctly from: $vsDevCmd"
  }
}

function Set-WindowsToolchainEnv {
  if (-not $script:IsWindowsHost) {
    return
  }

  $pathEntries = [System.Collections.Generic.List[string]]::new()
  if (-not [string]::IsNullOrWhiteSpace($env:Path)) {
    $env:Path.Split(';') | ForEach-Object {
      if (-not [string]::IsNullOrWhiteSpace($_)) {
        $pathEntries.Add($_)
      }
    }
  }

  $libEntries = [System.Collections.Generic.List[string]]::new()
  if (-not [string]::IsNullOrWhiteSpace($env:LIB)) {
    $env:LIB.Split(';') | ForEach-Object {
      if (-not [string]::IsNullOrWhiteSpace($_)) {
        $libEntries.Add($_)
      }
    }
  }

  $vsBase = $null
  $vsDevCmdPath = Get-VsDevCmdPath
  if (-not [string]::IsNullOrWhiteSpace($vsDevCmdPath)) {
    $vsBaseCandidate = Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $vsDevCmdPath))) 'VC\Tools\MSVC'
    if (Test-Path $vsBaseCandidate) {
      $vsBase = $vsBaseCandidate
    }
  }

  if ($null -eq $vsBase) {
    $fallbackVsBase = @(
      'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC',
      'C:\Program Files\Microsoft Visual Studio\17\Community\VC\Tools\MSVC',
      'C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\MSVC'
    )

    foreach ($candidate in $fallbackVsBase) {
      if (Test-Path $candidate) {
        $vsBase = $candidate
        break
      }
    }
  }

  if (Test-Path $vsBase) {
    $latestMsvc = Get-ChildItem -Path $vsBase -Directory |
      Sort-Object Name -Descending |
      Select-Object -First 1

    if ($null -ne $latestMsvc) {
      $msvcBin = Join-Path $latestMsvc.FullName 'bin\Hostx64\x64'
      $msvcLib = Join-Path $latestMsvc.FullName 'lib\x64'

      if ((Test-Path $msvcBin) -and -not $pathEntries.Contains($msvcBin)) {
        $pathEntries.Insert(0, $msvcBin)
      }
      if ((Test-Path $msvcLib) -and -not $libEntries.Contains($msvcLib)) {
        $libEntries.Insert(0, $msvcLib)
      }
    }
  }

  $sdkLibRoot = 'C:\Program Files (x86)\Windows Kits\10\Lib'
  if (Test-Path $sdkLibRoot) {
    $latestSdk = Get-ChildItem -Path $sdkLibRoot -Directory |
      Where-Object { $_.Name -match '^10\.' } |
      Sort-Object Name -Descending |
      Select-Object -First 1

    if ($null -ne $latestSdk) {
      $ucrtLib = Join-Path $latestSdk.FullName 'ucrt\x64'
      $umLib = Join-Path $latestSdk.FullName 'um\x64'

      if ((Test-Path $ucrtLib) -and -not $libEntries.Contains($ucrtLib)) {
        $libEntries.Insert(0, $ucrtLib)
      }
      if ((Test-Path $umLib) -and -not $libEntries.Contains($umLib)) {
        $libEntries.Insert(0, $umLib)
      }
    }
  }

  $env:Path = ($pathEntries -join ';')
  if ($libEntries.Count -gt 0) {
    $env:LIB = ($libEntries -join ';')
  }
}

function Assert-WindowsBuildToolchain {
  if (-not $script:IsWindowsHost) {
    return
  }

  $requiredCommands = @('cl.exe', 'cmake.exe', 'nmake.exe')
  foreach ($commandName in $requiredCommands) {
    $resolvedCommand = Get-Command $commandName -ErrorAction SilentlyContinue
    if ($null -eq $resolvedCommand) {
      throw "Missing required tool '$commandName'. Ensure Visual Studio C++ toolchain is installed and VS developer environment is loaded."
    }
  }
}

function Set-WindowsBuildDefaults {
  if (-not $script:IsWindowsHost) {
    return
  }

  $env:CMAKE_GENERATOR = 'NMake Makefiles'
  $env:CMAKE_C_COMPILER = 'cl.exe'
  $env:CMAKE_CXX_COMPILER = 'cl.exe'

  if ([string]::IsNullOrWhiteSpace($env:FLUTTER_ROOT)) {
    $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
    if ($null -ne $flutterCommand -and -not [string]::IsNullOrWhiteSpace($flutterCommand.Source)) {
      $flutterBinDir = Split-Path -Parent $flutterCommand.Source
      if (-not [string]::IsNullOrWhiteSpace($flutterBinDir)) {
        $flutterRootCandidate = Split-Path -Parent $flutterBinDir
        if (Test-Path $flutterRootCandidate) {
          $env:FLUTTER_ROOT = $flutterRootCandidate
        }
      }
    }
  }
}

function Invoke-ManualWindowsNMakeBuild {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot
  )

  $generatedConfigPath = Join-Path $RepoRoot 'windows/flutter/ephemeral/generated_config.cmake'
  if (-not (Test-Path $generatedConfigPath)) {
    throw "Fallback cannot continue because generated Flutter config is missing: $generatedConfigPath"
  }

  $manualBuildDir = Join-Path $RepoRoot 'build/windows/x64-nmake-rel'
  Remove-PathWithRetry -Path $manualBuildDir -AllowFailure

  $cmakeArgs = @(
    '-S', 'windows',
    '-B', $manualBuildDir,
    '-G', 'NMake Makefiles',
    '-DCMAKE_BUILD_TYPE=Release',
    '-DCMAKE_C_COMPILER=cl.exe',
    '-DCMAKE_CXX_COMPILER=cl.exe',
    '-DFLUTTER_TARGET_PLATFORM=windows-x64'
  )

  & cmake @cmakeArgs
  if ($LASTEXITCODE -ne 0) {
    throw "cmake configure failed with exit code $LASTEXITCODE"
  }

  & cmake '--build' $manualBuildDir
  if ($LASTEXITCODE -ne 0) {
    throw "cmake build failed with exit code $LASTEXITCODE"
  }

  & cmake '--install' $manualBuildDir
  if ($LASTEXITCODE -ne 0) {
    throw "cmake install failed with exit code $LASTEXITCODE"
  }

  $fallbackRunnerDir = Join-Path $manualBuildDir 'runner'
  if (-not (Test-Path $fallbackRunnerDir)) {
    throw "Fallback build output not found: $fallbackRunnerDir"
  }

  $releaseRunnerDir = Join-Path $RepoRoot 'build/windows/x64/runner/Release'
  Remove-PathWithRetry -Path $releaseRunnerDir -AllowFailure
  New-Item -ItemType Directory -Path $releaseRunnerDir -Force | Out-Null
  Copy-Item -Path (Join-Path $fallbackRunnerDir '*') -Destination $releaseRunnerDir -Recurse -Force
}

function Remove-PathWithRetry {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [int]$MaxRetries = 5,
    [int]$DelayMs = 600,
    [switch]$AllowFailure
  )

  if (-not (Test-Path $Path)) {
    return
  }

  for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
    try {
      Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
      return
    } catch {
      if ($attempt -eq $MaxRetries) {
        if ($AllowFailure) {
          Write-Warning "Could not remove '$Path' after $MaxRetries attempts. Continuing build. Last error: $($_.Exception.Message)"
          return
        }
        throw "Failed to remove '$Path' after $MaxRetries attempts. Close running app/VS build tasks and retry. Last error: $($_.Exception.Message)"
      }
      Start-Sleep -Milliseconds $DelayMs
    }
  }
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

Enter-BuildMutex
try {
  Import-VsDevCmdEnvironment
  Set-WindowsToolchainEnv
  Assert-WindowsBuildToolchain
  Set-WindowsBuildDefaults

  $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
  $pubspecPath = Join-Path $repoRoot 'pubspec.yaml'
  $pubspecVersion = Get-PubspecVersion -PubspecPath $pubspecPath

  if ($Clean) {
    Invoke-CheckedFlutter -CliArgs @('clean')
  }

  if (Test-PubGetRequired -RepoRoot $repoRoot -Force:$ForcePubGet) {
    Write-Host 'Running flutter pub get (dependencies changed or missing).'
    Invoke-CheckedFlutter -CliArgs @('pub', 'get')
  } else {
    Write-Host 'Skipping flutter pub get (dependencies up-to-date).'
  }

  # Clean stale/generated Windows folders that are commonly left in a locked state.
  Remove-PathWithRetry -Path "windows/flutter/ephemeral/.plugin_symlinks" -AllowFailure
  Remove-PathWithRetry -Path "windows/flutter/ephemeral/cpp_client_wrapper" -AllowFailure
  Remove-PathWithRetry -Path "build/windows/x64/CMakeFiles" -AllowFailure
  Remove-PathWithRetry -Path "build/windows/x64/flutter" -AllowFailure

  $cmakeCachePath = "build/windows/x64/CMakeCache.txt"
  if (Test-Path $cmakeCachePath) {
    Remove-Item -Path $cmakeCachePath -Force -ErrorAction SilentlyContinue
  }

  $cmakeInstallPath = "build/windows/x64/cmake_install.cmake"
  if (Test-Path $cmakeInstallPath) {
    Remove-Item -Path $cmakeInstallPath -Force -ErrorAction SilentlyContinue
  }

  $symbolsDir = "build/symbols/windows"
  $flutterBuildArgs = @("build", "windows", "--release", "--split-debug-info=$symbolsDir")

  if (-not $NoObfuscate) {
    $flutterBuildArgs += "--obfuscate"
  }

  if (-not [string]::IsNullOrWhiteSpace($GoogleOauthClientId)) {
    $flutterBuildArgs += "--dart-define=GOOGLE_OAUTH_CLIENT_ID=$GoogleOauthClientId"
  }

  if (-not [string]::IsNullOrWhiteSpace($DropboxClientId)) {
    $flutterBuildArgs += "--dart-define=DROPBOX_CLIENT_ID=$DropboxClientId"
  }

  if (-not [string]::IsNullOrWhiteSpace($YandexClientId)) {
    $flutterBuildArgs += "--dart-define=YANDEX_CLIENT_ID=$YandexClientId"
  }

  if (-not [string]::IsNullOrWhiteSpace($YandexClientSecret)) {
    $flutterBuildArgs += "--dart-define=YANDEX_CLIENT_SECRET=$YandexClientSecret"
  }

  if (-not [string]::IsNullOrWhiteSpace($GDriveUpdateFolderId)) {
    $flutterBuildArgs += "--dart-define=GDRIVE_UPDATE_FOLDER_ID=$GDriveUpdateFolderId"
  }

  if (-not [string]::IsNullOrWhiteSpace($GDriveUpdateFolderUrl)) {
    $flutterBuildArgs += "--dart-define=GDRIVE_UPDATE_FOLDER_URL=$GDriveUpdateFolderUrl"
  }

  try {
    Invoke-CheckedFlutter -CliArgs $flutterBuildArgs
  } catch {
    if ($script:IsWindowsHost) {
      Write-Warning "Flutter Windows build failed in default path. Trying deterministic NMake fallback path."
      Invoke-ManualWindowsNMakeBuild -RepoRoot $repoRoot
    } else {
      Write-Warning "Windows build failed. Automatic 'flutter clean' retry is disabled to protect build/windows artifacts. Retry with -Clean explicitly if needed."
      throw
    }
  }

  $releaseExePath = Join-Path $repoRoot 'build/windows/x64/runner/Release/altyazi_editoru.exe'
  if (Test-CodeSigningConfigured) {
    Invoke-CodeSign -TargetFile $releaseExePath
    Write-Host "Signed app executable: $releaseExePath"
  } else {
    Write-Warning 'Code signing is not configured. Unsigned builds may be blocked by SmartScreen/antivirus on other PCs.'
  }

  Write-Host "Windows release build completed."
  Write-Host "Package version (pubspec): $pubspecVersion"
  Write-Host "Output: build/windows/x64/runner/Release"
  if (-not $NoObfuscate) {
    Write-Host "Symbols: $symbolsDir"
  }
} finally {
  Exit-BuildMutex
}
