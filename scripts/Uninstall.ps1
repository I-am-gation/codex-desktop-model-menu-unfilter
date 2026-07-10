$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationFramework

$productName = "Codex Desktop Model Menu Unfilter"
$installDir = Join-Path $env:LOCALAPPDATA "Programs\Codex-5.6"
$launcherDir = Join-Path $env:LOCALAPPDATA "Codex-5.6-Launcher"
$desktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "Codex Model Menu.lnk"
$startMenuShortcut = Join-Path (
    Join-Path ([Environment]::GetFolderPath("Programs")) "OpenAI"
) "Codex Model Menu.lnk"
$legacyDesktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "Codex 5.6.lnk"
$legacyStartMenuShortcut = Join-Path (
    Join-Path ([Environment]::GetFolderPath("Programs")) "OpenAI"
) "Codex 5.6.lnk"

function Show-Message {
    param(
        [string]$Text,
        [System.Windows.MessageBoxButton]$Buttons,
        [System.Windows.MessageBoxImage]$Icon
    )

    Add-Type -AssemblyName PresentationFramework
    return [System.Windows.MessageBox]::Show(
        $Text,
        $productName,
        $Buttons,
        $Icon
    )
}

function Assert-ExactChildPath {
    param(
        [string]$Target,
        [string]$ExpectedParent
    )

    $fullTarget = [System.IO.Path]::GetFullPath($Target).TrimEnd("\")
    $fullParent = [System.IO.Path]::GetFullPath($ExpectedParent).TrimEnd("\")
    $actualParent = [System.IO.Path]::GetDirectoryName($fullTarget)
    if (-not $actualParent.Equals($fullParent, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove unexpected path: $fullTarget"
    }
}

try {
    $running = Get-CimInstance Win32_Process |
        Where-Object {
            if (-not $_.ExecutablePath) {
                return $false
            }
            $candidate = [System.IO.Path]::GetFullPath($_.ExecutablePath).TrimEnd("\")
            $directory = [System.IO.Path]::GetFullPath($installDir).TrimEnd("\")
            return (
                $candidate.Equals($directory, [System.StringComparison]::OrdinalIgnoreCase) -or
                $candidate.StartsWith(
                    $directory + "\",
                    [System.StringComparison]::OrdinalIgnoreCase
                )
            )
        }

    if ($running) {
        $choice = Show-Message `
            -Text "The patched Codex app is running. Close it and continue uninstalling?" `
            -Buttons ([System.Windows.MessageBoxButton]::YesNo) `
            -Icon ([System.Windows.MessageBoxImage]::Question)
        if ($choice -ne [System.Windows.MessageBoxResult]::Yes) {
            exit 0
        }

        $running |
            ForEach-Object {
                Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
            }
        Start-Sleep -Milliseconds 500
    }

    Remove-Item -LiteralPath $desktopShortcut -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $startMenuShortcut -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $legacyDesktopShortcut -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $legacyStartMenuShortcut -Force -ErrorAction SilentlyContinue

    Assert-ExactChildPath `
        -Target $installDir `
        -ExpectedParent (Join-Path $env:LOCALAPPDATA "Programs")
    Assert-ExactChildPath `
        -Target $launcherDir `
        -ExpectedParent $env:LOCALAPPDATA

    if (Test-Path -LiteralPath $installDir) {
        Remove-Item -LiteralPath $installDir -Recurse -Force
    }
    if (Test-Path -LiteralPath $launcherDir) {
        Remove-Item -LiteralPath $launcherDir -Recurse -Force
    }

    Show-Message `
        -Text "The patched Codex copy was removed. The official Store app and Codex configuration were not changed." `
        -Buttons ([System.Windows.MessageBoxButton]::OK) `
        -Icon ([System.Windows.MessageBoxImage]::Information) | Out-Null
    exit 0
}
catch {
    Show-Message `
        -Text "Uninstall failed.`n`n$($_.Exception.Message)" `
        -Buttons ([System.Windows.MessageBoxButton]::OK) `
        -Icon ([System.Windows.MessageBoxImage]::Error) | Out-Null
    Write-Error $_
    exit 1
}
