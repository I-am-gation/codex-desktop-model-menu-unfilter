param(
    [switch]$ForceRefresh,
    [switch]$NoLaunch,
    [switch]$SkipOfficialRestartPrompt,
    [switch]$Silent
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationFramework

$productName = "Codex Desktop Model Menu Unfilter"
$installDir = Join-Path $env:LOCALAPPDATA "Programs\Codex-5.6"
$launcherDir = Join-Path $env:LOCALAPPDATA "Codex-5.6-Launcher"
$markerPath = Join-Path $installDir ".codex-5.6-source-version"
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

function Patch-CodexModelMenu {
    param([string]$ArchivePath)

    # Keep both strings exactly the same byte length so the ASAR index stays valid.
    $originalText = "if(u?n.has(r.model):!r.hidden){"
    $patchedText = "if(n.has(r.model)||!r.hidden) {"
    $encoding = [System.Text.Encoding]::GetEncoding(28591)
    $archiveBytes = [System.IO.File]::ReadAllBytes($ArchivePath)
    $archiveText = $encoding.GetString($archiveBytes)

    $originalIndex = $archiveText.IndexOf(
        $originalText,
        [System.StringComparison]::Ordinal
    )
    $patchedIndex = $archiveText.IndexOf(
        $patchedText,
        [System.StringComparison]::Ordinal
    )

    if ($patchedIndex -ge 0 -and $originalIndex -lt 0) {
        Write-LauncherLog "Model-menu patch is already present."
        return
    }

    if ($originalIndex -lt 0 -or $patchedIndex -ge 0) {
        throw "The patch target was not found uniquely. Update this patcher for the installed Codex version."
    }

    $secondOriginalIndex = $archiveText.IndexOf(
        $originalText,
        $originalIndex + $originalText.Length,
        [System.StringComparison]::Ordinal
    )
    if ($secondOriginalIndex -ge 0) {
        throw "The model-menu patch target appeared more than once."
    }

    $patchedBytes = [System.Text.Encoding]::UTF8.GetBytes($patchedText)
    if ($patchedBytes.Length -ne $originalText.Length) {
        throw "The replacement patch has an unexpected byte length."
    }

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

    Write-LauncherLog "Applied the Codex model-menu unfilter patch."
}

function Stop-OfficialCodexWithConsent {
    param([object]$OfficialMain)

    Add-Type -AssemblyName PresentationFramework
    $choice = [System.Windows.MessageBox]::Show(
        "The Microsoft Store Codex app is running at:`n$($OfficialMain.ExecutablePath)`n`nRestart it now with the unfiltered model menu?",
        $productName,
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    if ($choice -ne [System.Windows.MessageBoxResult]::Yes) {
        return $false
    }

    $mainProcess = Get-Process -Id $OfficialMain.ProcessId -ErrorAction SilentlyContinue
    if ($mainProcess) {
        [void]$mainProcess.CloseMainWindow()
        try {
            Wait-Process -Id $mainProcess.Id -Timeout 8 -ErrorAction Stop
        }
        catch {
            Stop-Process -Id $mainProcess.Id -Force -ErrorAction SilentlyContinue
        }
    }

    Start-Sleep -Milliseconds 500
    return $true
}

try {
    New-Item -ItemType Directory -Force -Path $launcherDir | Out-Null

    $package = Get-CodexStorePackage
    $sourceDir = Join-Path $package.InstallLocation "app"
    $sourceVersion = $package.Version.ToString()

    $runningCopy = Get-CimInstance Win32_Process |
        Where-Object {
            $_.ExecutablePath -and
            (Test-PathInsideDirectory `
                -CandidatePath $_.ExecutablePath `
                -DirectoryPath $installDir)
        } |
        Select-Object -First 1

    if ($runningCopy) {
        if ($NoLaunch) {
            throw "Close the patched Codex copy before repairing or updating it."
        }
        Start-Process -FilePath $exePath
        exit 0
    }

    $officialMain = Get-CimInstance Win32_Process |
        Where-Object {
            $_.Name -eq "ChatGPT.exe" -and
            $_.ExecutablePath -and
            (Test-PathInsideDirectory `
                -CandidatePath $_.ExecutablePath `
                -DirectoryPath $sourceDir) -and
            $_.CommandLine -notmatch "--type="
        } |
        Select-Object -First 1

    if ($officialMain -and -not $SkipOfficialRestartPrompt) {
        if (-not (Stop-OfficialCodexWithConsent -OfficialMain $officialMain)) {
            exit 0
        }
    }

    $copiedVersion = if (Test-Path -LiteralPath $markerPath) {
        (Get-Content -Raw -LiteralPath $markerPath).Trim()
    }
    else {
        ""
    }

    $needsRefresh =
        $ForceRefresh -or
        -not (Test-Path -LiteralPath $exePath) -or
        -not (Test-Path -LiteralPath $asarPath) -or
        $copiedVersion -ne $sourceVersion

    if ($needsRefresh) {
        $driveName = [System.IO.Path]::GetPathRoot($installDir).TrimEnd("\")
        $drive = Get-PSDrive -Name $driveName.TrimEnd(":")
        if ($drive.Free -lt 2500000000) {
            throw "At least 2.5 GB of free disk space is required to install or update."
        }

        Write-LauncherLog "Refreshing patched copy from Store version $sourceVersion."
        $installParent = Split-Path -Parent $installDir
        $stagingDir = Join-Path $installParent "Codex-5.6.staging-$PID"
        $rollbackDir = Join-Path $installParent "Codex-5.6.rollback"
        $stagingAsar = Join-Path $stagingDir "resources\app.asar"
        $stagingExe = Join-Path $stagingDir "ChatGPT.exe"
        $stagingMarker = Join-Path $stagingDir ".codex-5.6-source-version"

        Remove-DedicatedDirectory -Path $stagingDir -ExpectedParent $installParent
        Remove-DedicatedDirectory -Path $rollbackDir -ExpectedParent $installParent
        New-Item -ItemType Directory -Force -Path $stagingDir | Out-Null

        try {
            & robocopy.exe $sourceDir $stagingDir /MIR /COPY:DAT /DCOPY:DAT /R:1 /W:1 /XJ /NFL /NDL /NP | Out-Null
            $robocopyCode = $LASTEXITCODE
            if ($robocopyCode -ge 8) {
                throw "Robocopy failed with exit code $robocopyCode."
            }

            if (-not (Test-Path -LiteralPath $stagingExe)) {
                throw "The staged Codex executable is missing."
            }

            Patch-CodexModelMenu -ArchivePath $stagingAsar
            Set-Content -LiteralPath $stagingMarker -Value $sourceVersion -Encoding ASCII

            if (Test-Path -LiteralPath $installDir) {
                Move-Item -LiteralPath $installDir -Destination $rollbackDir
            }

            try {
                Move-Item -LiteralPath $stagingDir -Destination $installDir
            }
            catch {
                if (
                    -not (Test-Path -LiteralPath $installDir) -and
                    (Test-Path -LiteralPath $rollbackDir)
                ) {
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

            Write-LauncherLog "Patched Codex copy is ready."
        }
        catch {
            if (Test-Path -LiteralPath $stagingDir) {
                Remove-DedicatedDirectory -Path $stagingDir -ExpectedParent $installParent
            }
            if (
                -not (Test-Path -LiteralPath $installDir) -and
                (Test-Path -LiteralPath $rollbackDir)
            ) {
                Move-Item -LiteralPath $rollbackDir -Destination $installDir
            }
            throw
        }
    }

    if (-not $NoLaunch) {
        Start-Process -FilePath $exePath
    }
}
catch {
    $message = "$productName could not update or start.`n`n$($_.Exception.Message)`n`nLog: $logPath"
    Write-LauncherLog "ERROR: $($_.Exception.Message)"
    Show-ErrorMessage -Message $message
    exit 1
}
