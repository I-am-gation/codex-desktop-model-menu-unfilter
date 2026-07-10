param(
    [switch]$ForceRefresh,
    [switch]$NoLaunch,
    [switch]$SkipOfficialRestartPrompt,
    [switch]$Silent,
    [switch]$SelfTest,
    [string]$Language
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationFramework

$productName = "Codex Desktop Model Menu Unfilter"
$patcherVersion = "1.0.1"
$markerSchema = 2
$installDir = Join-Path $env:LOCALAPPDATA "Programs\Codex-5.6"
$launcherDir = Join-Path $env:LOCALAPPDATA "Codex-5.6-Launcher"
$markerPath = Join-Path $installDir ".codex-model-menu-source.json"
$legacyMarkerName = ".codex-5.6-source-version"
$logPath = Join-Path $launcherDir "launcher.log"
$exePath = Join-Path $installDir "ChatGPT.exe"
$asarPath = Join-Path $installDir "resources\app.asar"

function Write-LauncherLog {
    param([string]$Message)
    New-Item -ItemType Directory -Force -Path $launcherDir | Out-Null
    $line = "{0:u} {1}" -f (Get-Date), $Message
    Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
}

function Show-ErrorMessage {
    param([string]$Message)
    if ($Silent) {
        Write-Error $Message
        return
    }

    [System.Windows.MessageBox]::Show(
        $Message,
        $productName,
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Error
    ) | Out-Null
}

function Get-CodexStorePackage {
    $package = Get-AppxPackage -Name "OpenAI.Codex" |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if (-not $package) {
        throw "The official Microsoft Store Codex app is not installed."
    }

    return $package
}

function Test-PathInsideDirectory {
    param(
        [string]$CandidatePath,
        [string]$DirectoryPath
    )

    try {
        $candidate = [System.IO.Path]::GetFullPath($CandidatePath).TrimEnd("\")
        $directory = [System.IO.Path]::GetFullPath($DirectoryPath).TrimEnd("\")
        return (
            $candidate.Equals($directory, [System.StringComparison]::OrdinalIgnoreCase) -or
            $candidate.StartsWith(
                $directory + "\",
                [System.StringComparison]::OrdinalIgnoreCase
            )
        )
    }
    catch {
        return $false
    }
}

function Remove-DedicatedDirectory {
    param(
        [string]$Path,
        [string]$ExpectedParent
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path).TrimEnd("\")
    $fullParent = [System.IO.Path]::GetFullPath($ExpectedParent).TrimEnd("\")
    $actualParent = [System.IO.Path]::GetDirectoryName($fullPath)
    if (-not $actualParent.Equals($fullParent, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove unexpected directory: $fullPath"
    }

    if (Test-Path -LiteralPath $fullPath) {
        Remove-Item -LiteralPath $fullPath -Recurse -Force
    }
}

function Get-StringOccurrenceCount {
    param(
        [string]$Text,
        [string]$Needle
    )

    $count = 0
    $offset = 0
    while ($offset -le ($Text.Length - $Needle.Length)) {
        $index = $Text.IndexOf($Needle, $offset, [System.StringComparison]::Ordinal)
        if ($index -lt 0) {
            break
        }
        $count++
        $offset = $index + $Needle.Length
    }
    return $count
}

function Patch-ExactLengthTarget {
    param(
        [string]$ArchivePath,
        [string]$OriginalText,
        [string]$PatchedText,
        [string]$PatchName
    )

    $originalBytes = [System.Text.Encoding]::UTF8.GetBytes($OriginalText)
    $patchedBytes = [System.Text.Encoding]::UTF8.GetBytes($PatchedText)
    if ($originalBytes.Length -ne $patchedBytes.Length) {
        throw "$PatchName replacement is not byte-length preserving."
    }

    $encoding = [System.Text.Encoding]::GetEncoding(28591)
    $lengthBefore = (Get-Item -LiteralPath $ArchivePath).Length
    $archiveBytes = [System.IO.File]::ReadAllBytes($ArchivePath)
    $archiveText = $encoding.GetString($archiveBytes)
    $originalCount = Get-StringOccurrenceCount -Text $archiveText -Needle $OriginalText
    $patchedCount = Get-StringOccurrenceCount -Text $archiveText -Needle $PatchedText

    if ($originalCount -eq 0 -and $patchedCount -eq 1) {
        Write-LauncherLog "$PatchName patch is already present."
        return
    }
    if ($originalCount -ne 1 -or $patchedCount -ne 0) {
        throw "$PatchName patch target was not found uniquely (original=$originalCount, patched=$patchedCount)."
    }

    $originalIndex = $archiveText.IndexOf($OriginalText, [System.StringComparison]::Ordinal)
    $stream = [System.IO.File]::Open(
        $ArchivePath,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::ReadWrite,
        [System.IO.FileShare]::Read
    )
    try {
        $stream.Position = $originalIndex
        $stream.Write($patchedBytes, 0, $patchedBytes.Length)
        $stream.Flush($true)
    }
    finally {
        $stream.Dispose()
    }

    $archiveBytes = $null
    $archiveText = $null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()

    $lengthAfter = (Get-Item -LiteralPath $ArchivePath).Length
    if ($lengthAfter -ne $lengthBefore) {
        throw "$PatchName patch changed the ASAR byte length."
    }

    $verifiedBytes = [System.IO.File]::ReadAllBytes($ArchivePath)
    $verifiedText = $encoding.GetString($verifiedBytes)
    $verifiedOriginalCount = Get-StringOccurrenceCount -Text $verifiedText -Needle $OriginalText
    $verifiedPatchedCount = Get-StringOccurrenceCount -Text $verifiedText -Needle $PatchedText
    if ($verifiedOriginalCount -ne 0 -or $verifiedPatchedCount -ne 1) {
        throw "$PatchName patch failed its post-write verification."
    }

    $verifiedBytes = $null
    $verifiedText = $null
    [System.GC]::Collect()
    Write-LauncherLog "Applied and verified the $PatchName patch."
}

function Patch-CodexModelMenu {
    param([string]$ArchivePath)

    Patch-ExactLengthTarget `
        -ArchivePath $ArchivePath `
        -OriginalText "if(u?n.has(r.model):!r.hidden){" `
        -PatchedText "if(n.has(r.model)||!r.hidden) {" `
        -PatchName "model-menu unfilter"

    # Preserve an explicit remote false while defaulting to i18n before its flag cache is ready.
    Patch-ExactLengthTarget `
        -ArchivePath $ArchivePath `
        -OriginalText 'a?.get(`enable_i18n`,!1)' `
        -PatchedText 'a?.get(`enable_i18n`,!0)' `
        -PatchName "i18n startup default"
}

function ConvertTo-ElectronLocale {
    param([string]$LanguageTag)

    if ([string]::IsNullOrWhiteSpace($LanguageTag)) {
        return "en-US"
    }

    $tag = $LanguageTag.Trim().Replace("_", "-")
    if ($tag -match "^(?i)zh-hans(?:-|$)") {
        return "zh-CN"
    }
    if ($tag -match "^(?i)zh-hant-(?:hk|mo)(?:-|$)") {
        return "zh-HK"
    }
    if ($tag -match "^(?i)zh-hant(?:-|$)") {
        return "zh-TW"
    }
    if ($tag -match "^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$") {
        return $tag
    }
    return "en-US"
}

function Get-PreferredElectronLocale {
    if (-not [string]::IsNullOrWhiteSpace($Language)) {
        return ConvertTo-ElectronLocale -LanguageTag $Language
    }

    try {
        $firstLanguage = Get-WinUserLanguageList | Select-Object -First 1
        if ($firstLanguage -and $firstLanguage.LanguageTag) {
            return ConvertTo-ElectronLocale -LanguageTag $firstLanguage.LanguageTag
        }
    }
    catch {
        Write-LauncherLog "Could not read the Windows user language list: $($_.Exception.Message)"
    }

    return ConvertTo-ElectronLocale -LanguageTag ([System.Globalization.CultureInfo]::CurrentUICulture.Name)
}

function Start-PatchedCodex {
    param(
        [string]$Path,
        [switch]$ExistingInstance
    )

    $locale = Get-PreferredElectronLocale
    Write-LauncherLog "Starting patched Codex with Electron locale $locale."
    $previousUpdaterSetting = [System.Environment]::GetEnvironmentVariable(
        "CODEX_SPARKLE_ENABLED",
        [System.EnvironmentVariableTarget]::Process
    )
    try {
        # A copied executable has no MSIX package identity; updates are handled by this launcher.
        [System.Environment]::SetEnvironmentVariable(
            "CODEX_SPARKLE_ENABLED",
            "false",
            [System.EnvironmentVariableTarget]::Process
        )
        $process = Start-Process `
            -FilePath $Path `
            -ArgumentList @("--lang=$locale") `
            -PassThru
    }
    finally {
        [System.Environment]::SetEnvironmentVariable(
            "CODEX_SPARKLE_ENABLED",
            $previousUpdaterSetting,
            [System.EnvironmentVariableTarget]::Process
        )
    }

    if (-not $ExistingInstance -and $process.WaitForExit(8000)) {
        $replacementMain = Get-MainElectronProcess `
            -Processes (Get-AppProcessesInDirectory -DirectoryPath $installDir)
        if (-not $replacementMain) {
            throw "The patched Codex process exited during startup with code $($process.ExitCode)."
        }
    }
}

function Get-AppProcessesInDirectory {
    param([string]$DirectoryPath)

    return @(
        Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
            Where-Object {
                $_.ExecutablePath -and
                (Test-PathInsideDirectory `
                    -CandidatePath $_.ExecutablePath `
                    -DirectoryPath $DirectoryPath)
            }
    )
}

function Get-MainElectronProcess {
    param([object[]]$Processes)

    return $Processes |
        Where-Object {
            $_.Name -eq "ChatGPT.exe" -and
            $_.CommandLine -notmatch "--type="
        } |
        Select-Object -First 1
}

function Stop-AppProcesses {
    param([string]$DirectoryPath)

    $processes = Get-AppProcessesInDirectory -DirectoryPath $DirectoryPath
    foreach ($item in $processes) {
        $process = Get-Process -Id $item.ProcessId -ErrorAction SilentlyContinue
        if ($process -and $process.MainWindowHandle -ne 0) {
            [void]$process.CloseMainWindow()
        }
    }

    $deadline = (Get-Date).AddSeconds(8)
    do {
        $remaining = Get-AppProcessesInDirectory -DirectoryPath $DirectoryPath
        if ($remaining.Count -eq 0) {
            return
        }
        Start-Sleep -Milliseconds 250
    } while ((Get-Date) -lt $deadline)

    foreach ($item in $remaining) {
        Stop-Process -Id $item.ProcessId -Force -ErrorAction SilentlyContinue
    }

    $forceDeadline = (Get-Date).AddSeconds(3)
    do {
        $remaining = Get-AppProcessesInDirectory -DirectoryPath $DirectoryPath
        if ($remaining.Count -eq 0) {
            return
        }
        Start-Sleep -Milliseconds 200
    } while ((Get-Date) -lt $forceDeadline)

    throw "Codex processes did not exit from $DirectoryPath"
}

function Confirm-AndStopApp {
    param(
        [string]$DirectoryPath,
        [string]$Description
    )

    $choice = [System.Windows.MessageBox]::Show(
        "$Description is running at:`n$DirectoryPath`n`nClose it and continue?",
        $productName,
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    if ($choice -ne [System.Windows.MessageBoxResult]::Yes) {
        return $false
    }

    Stop-AppProcesses -DirectoryPath $DirectoryPath
    return $true
}

function Read-InstalledState {
    if (-not (Test-Path -LiteralPath $markerPath)) {
        return $null
    }
    try {
        return Get-Content -Raw -LiteralPath $markerPath -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        Write-LauncherLog "Installed state is unreadable and will be rebuilt: $($_.Exception.Message)"
        return $null
    }
}

function Test-InstalledCopyCurrent {
    param(
        [object]$State,
        [object]$Package,
        [string]$SourceAsarHash,
        [long]$SourceAsarLength
    )

    if (-not $State -or
        $State.schema -ne $markerSchema -or
        $State.patcherVersion -ne $patcherVersion -or
        $State.sourcePackageFullName -ne $Package.PackageFullName -or
        $State.sourcePackageVersion -ne $Package.Version.ToString() -or
        $State.sourceAsarSha256 -ne $SourceAsarHash -or
        [long]$State.sourceAsarLength -ne $SourceAsarLength -or
        -not $State.patchedAsarSha256 -or
        -not (Test-Path -LiteralPath $exePath) -or
        -not (Test-Path -LiteralPath $asarPath)) {
        return $false
    }

    $installedHash = (Get-FileHash -LiteralPath $asarPath -Algorithm SHA256).Hash
    return $installedHash -eq $State.patchedAsarSha256
}

function Invoke-SelfTest {
    $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) "codex-model-menu-self-test-$PID.asar"
    $duplicatePath = Join-Path ([System.IO.Path]::GetTempPath()) "codex-model-menu-duplicate-test-$PID.asar"
    try {
        $fixture = 'prefix-if(u?n.has(r.model):!r.hidden){-middle-a?.get(`enable_i18n`,!1)-suffix'
        [System.IO.File]::WriteAllBytes($tempPath, [System.Text.Encoding]::UTF8.GetBytes($fixture))
        $beforeLength = (Get-Item -LiteralPath $tempPath).Length
        Patch-CodexModelMenu -ArchivePath $tempPath
        Patch-CodexModelMenu -ArchivePath $tempPath
        $afterText = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($tempPath))
        $lengthOkay = (Get-Item -LiteralPath $tempPath).Length -eq $beforeLength
        $modelOkay = $afterText.Contains("if(n.has(r.model)||!r.hidden) {")
        $i18nOkay = $afterText.Contains('a?.get(`enable_i18n`,!0)')
        $simplifiedLocale = ConvertTo-ElectronLocale "zh-Hans-CN"
        $traditionalLocale = ConvertTo-ElectronLocale "zh-Hant-HK"
        if (-not $lengthOkay -or -not $modelOkay -or -not $i18nOkay -or
            $simplifiedLocale -ne "zh-CN" -or $traditionalLocale -ne "zh-HK") {
            throw "Self-test assertions failed (length=$lengthOkay, model=$modelOkay, i18n=$i18nOkay, locales=$simplifiedLocale/$traditionalLocale)."
        }

        $duplicateFixture = 'if(u?n.has(r.model):!r.hidden){if(u?n.has(r.model):!r.hidden){a?.get(`enable_i18n`,!1)'
        [System.IO.File]::WriteAllBytes(
            $duplicatePath,
            [System.Text.Encoding]::UTF8.GetBytes($duplicateFixture)
        )
        $duplicateHash = (Get-FileHash -LiteralPath $duplicatePath -Algorithm SHA256).Hash
        $duplicateRejected = $false
        try {
            Patch-CodexModelMenu -ArchivePath $duplicatePath
        }
        catch {
            $duplicateRejected = $true
        }
        if (-not $duplicateRejected -or
            (Get-FileHash -LiteralPath $duplicatePath -Algorithm SHA256).Hash -ne $duplicateHash) {
            throw "Self-test did not safely reject a duplicate patch target."
        }
        Write-Host "Windows launcher self-test passed."
    }
    finally {
        Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $duplicatePath -Force -ErrorAction SilentlyContinue
    }
}

try {
    New-Item -ItemType Directory -Force -Path $launcherDir | Out-Null
    $lockPath = Join-Path $launcherDir "launcher.lock"
    try {
        $launcherLock = [System.IO.File]::Open(
            $lockPath,
            [System.IO.FileMode]::OpenOrCreate,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None
        )
    }
    catch {
        throw "Another Codex Model Menu install, update, or launch is already running."
    }

    if ($SelfTest) {
        Invoke-SelfTest
        exit 0
    }

    $package = Get-CodexStorePackage
    $sourceDir = Join-Path $package.InstallLocation "app"
    $sourceAsar = Join-Path $sourceDir "resources\app.asar"
    if (-not (Test-Path -LiteralPath $sourceAsar)) {
        throw "The official Codex app.asar was not found."
    }

    $sourceAsarItem = Get-Item -LiteralPath $sourceAsar
    $sourceAsarHash = (Get-FileHash -LiteralPath $sourceAsar -Algorithm SHA256).Hash
    $installedState = Read-InstalledState
    $needsRefresh = $ForceRefresh -or -not (Test-InstalledCopyCurrent `
        -State $installedState `
        -Package $package `
        -SourceAsarHash $sourceAsarHash `
        -SourceAsarLength $sourceAsarItem.Length)

    $copyProcesses = Get-AppProcessesInDirectory -DirectoryPath $installDir
    $copyMain = Get-MainElectronProcess -Processes $copyProcesses

    if ($needsRefresh -and $copyProcesses.Count -gt 0) {
        if ($NoLaunch) {
            throw "Close Codex Model Menu before repairing or updating it."
        }
        if (-not (Confirm-AndStopApp `
            -DirectoryPath $installDir `
            -Description "Codex Model Menu")) {
            exit 0
        }
        $copyProcesses = @()
        $copyMain = $null
    }
    elseif (-not $needsRefresh -and $copyMain) {
        if ($NoLaunch) {
            exit 0
        }
        Start-PatchedCodex -Path $exePath -ExistingInstance
        exit 0
    }
    elseif (-not $needsRefresh -and $copyProcesses.Count -gt 0) {
        Write-LauncherLog "Stopping orphaned patched Codex child processes before launch."
        Stop-AppProcesses -DirectoryPath $installDir
    }

    if ($needsRefresh) {
        $driveName = [System.IO.Path]::GetPathRoot($installDir).TrimEnd("\")
        $drive = Get-PSDrive -Name $driveName.TrimEnd(":")
        if ($drive.Free -lt 2500000000) {
            throw "At least 2.5 GB of free disk space is required to install or update."
        }

        Write-LauncherLog "Refreshing patched copy from $($package.PackageFullName), ASAR $sourceAsarHash."
        $installParent = Split-Path -Parent $installDir
        $stagingDir = Join-Path $installParent "Codex-5.6.staging-$PID"
        $rollbackDir = Join-Path $installParent "Codex-5.6.rollback"
        $stagingAsar = Join-Path $stagingDir "resources\app.asar"
        $stagingExe = Join-Path $stagingDir "ChatGPT.exe"
        $stagingMarker = Join-Path $stagingDir ".codex-model-menu-source.json"
        $stagingLegacyMarker = Join-Path $stagingDir $legacyMarkerName

        Remove-DedicatedDirectory -Path $stagingDir -ExpectedParent $installParent
        if (-not (Test-Path -LiteralPath $installDir) -and
            (Test-Path -LiteralPath $rollbackDir)) {
            Write-LauncherLog "Recovering the previous copy from an interrupted directory swap."
            Move-Item -LiteralPath $rollbackDir -Destination $installDir
        }
        elseif ((Test-Path -LiteralPath $installDir) -and
            (Test-Path -LiteralPath $rollbackDir)) {
            Remove-DedicatedDirectory -Path $rollbackDir -ExpectedParent $installParent
        }
        New-Item -ItemType Directory -Force -Path $stagingDir | Out-Null

        try {
            & robocopy.exe $sourceDir $stagingDir /MIR /COPY:DAT /DCOPY:DAT /R:1 /W:1 /XJ /NFL /NDL /NP | Out-Null
            $robocopyCode = $LASTEXITCODE
            if ($robocopyCode -ge 8) {
                throw "Robocopy failed with exit code $robocopyCode."
            }
            if (-not (Test-Path -LiteralPath $stagingExe) -or
                -not (Test-Path -LiteralPath $stagingAsar)) {
                throw "The staged Codex executable or app.asar is missing."
            }

            $stagedSourceHash = (Get-FileHash -LiteralPath $stagingAsar -Algorithm SHA256).Hash
            if ($stagedSourceHash -ne $sourceAsarHash) {
                throw "The staged source ASAR does not match the Microsoft Store source."
            }

            Patch-CodexModelMenu -ArchivePath $stagingAsar
            $patchedAsarHash = (Get-FileHash -LiteralPath $stagingAsar -Algorithm SHA256).Hash
            $state = [ordered]@{
                schema = $markerSchema
                patcherVersion = $patcherVersion
                sourcePackageFullName = $package.PackageFullName
                sourcePackageVersion = $package.Version.ToString()
                sourceAsarSha256 = $sourceAsarHash
                sourceAsarLength = $sourceAsarItem.Length
                patchedAsarSha256 = $patchedAsarHash
                preparedAt = (Get-Date).ToUniversalTime().ToString("o")
            }
            $state | ConvertTo-Json | Set-Content -LiteralPath $stagingMarker -Encoding UTF8
            Remove-Item -LiteralPath $stagingLegacyMarker -Force -ErrorAction SilentlyContinue

            if (Test-Path -LiteralPath $installDir) {
                Move-Item -LiteralPath $installDir -Destination $rollbackDir
            }

            try {
                Move-Item -LiteralPath $stagingDir -Destination $installDir
            }
            catch {
                if (-not (Test-Path -LiteralPath $installDir) -and
                    (Test-Path -LiteralPath $rollbackDir)) {
                    Move-Item -LiteralPath $rollbackDir -Destination $installDir
                }
                throw
            }

            if (Test-Path -LiteralPath $rollbackDir) {
                try {
                    Remove-DedicatedDirectory -Path $rollbackDir -ExpectedParent $installParent
                }
                catch {
                    Write-LauncherLog "Could not remove rollback directory: $($_.Exception.Message)"
                }
            }

            Write-LauncherLog "Patched Codex copy is ready with ASAR $patchedAsarHash."
        }
        catch {
            if (Test-Path -LiteralPath $stagingDir) {
                Remove-DedicatedDirectory -Path $stagingDir -ExpectedParent $installParent
            }
            if (-not (Test-Path -LiteralPath $installDir) -and
                (Test-Path -LiteralPath $rollbackDir)) {
                Move-Item -LiteralPath $rollbackDir -Destination $installDir
            }
            throw
        }
    }

    if (-not $NoLaunch) {
        $officialProcesses = Get-AppProcessesInDirectory -DirectoryPath $sourceDir
        if ($officialProcesses.Count -gt 0 -and -not $SkipOfficialRestartPrompt) {
            if (-not (Confirm-AndStopApp `
                -DirectoryPath $sourceDir `
                -Description "The Microsoft Store Codex app")) {
                exit 0
            }
        }
        Start-PatchedCodex -Path $exePath
    }
}
catch {
    $message = "$productName could not update or start.`n`n$($_.Exception.Message)`n`nLog: $logPath"
    Write-LauncherLog "ERROR: $($_.Exception.Message)"
    Show-ErrorMessage -Message $message
    exit 1
}
