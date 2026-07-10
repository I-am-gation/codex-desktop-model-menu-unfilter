param(
    [switch]$Repair,
    [switch]$Silent
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationFramework

$productName = "Codex Desktop Model Menu Unfilter"
$packageRoot = Split-Path -Parent $PSScriptRoot
$sourceLauncherScript = Join-Path $PSScriptRoot "Launch-Codex-Model-Menu.ps1"
$sourceLauncherCode = Join-Path $PSScriptRoot "CodexModelMenuLauncher.cs"
$installDir = Join-Path $env:LOCALAPPDATA "Programs\Codex-5.6"
$launcherDir = Join-Path $env:LOCALAPPDATA "Codex-5.6-Launcher"
$installedLauncherScript = Join-Path $launcherDir "Launch-Codex-Model-Menu.ps1"
$installedLauncherCode = Join-Path $launcherDir "CodexModelMenuLauncher.cs"
$launcherExe = Join-Path $launcherDir "CodexModelMenuLauncher.exe"
$desktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "Codex Model Menu.lnk"
$startMenuDir = Join-Path ([Environment]::GetFolderPath("Programs")) "OpenAI"
$startMenuShortcut = Join-Path $startMenuDir "Codex Model Menu.lnk"
$legacyDesktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "Codex 5.6.lnk"
$legacyStartMenuShortcut = Join-Path $startMenuDir "Codex 5.6.lnk"
$legacyLauncherCode = Join-Path $launcherDir "Codex56Launcher.cs"
$legacyLauncherExe = Join-Path $launcherDir "Codex56Launcher.exe"

function Show-Message {
    param(
        [string]$Text,
        [System.Windows.MessageBoxImage]$Icon
    )

    if ($Silent) {
        Write-Host $Text
        return
    }

    [System.Windows.MessageBox]::Show(
        $Text,
        $productName,
        [System.Windows.MessageBoxButton]::OK,
        $Icon
    ) | Out-Null
}

function Get-CSharpCompiler {
    $candidates = @(
        (Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"),
        (Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe")
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    throw "The Windows .NET Framework C# compiler was not found."
}

function New-CodexShortcut {
    param([string]$Path)

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($Path)
    $shortcut.TargetPath = $launcherExe
    $shortcut.WorkingDirectory = $installDir
    $shortcut.IconLocation = "$launcherExe,0"
    $shortcut.Description = "Codex Desktop with an unfiltered local model menu"
    $shortcut.Save()
}

try {
    $package = Get-AppxPackage -Name "OpenAI.Codex" |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if (-not $package) {
        throw "Install the official Codex app from Microsoft Store before running this installer."
    }

    New-Item -ItemType Directory -Force -Path $launcherDir | Out-Null
    Copy-Item -LiteralPath $sourceLauncherScript -Destination $installedLauncherScript -Force
    Copy-Item -LiteralPath $sourceLauncherCode -Destination $installedLauncherCode -Force
    Unblock-File -LiteralPath $installedLauncherScript -ErrorAction SilentlyContinue
    Unblock-File -LiteralPath $installedLauncherCode -ErrorAction SilentlyContinue

    $launcherArguments = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $installedLauncherScript,
        "-ForceRefresh",
        "-NoLaunch",
        "-SkipOfficialRestartPrompt"
    )
    if ($Silent) {
        $launcherArguments += "-Silent"
    }
    & powershell.exe @launcherArguments
    if ($LASTEXITCODE -ne 0) {
        throw "The patched Codex copy could not be prepared."
    }

    $compiler = Get-CSharpCompiler
    & $compiler /nologo /target:winexe /optimize+ "/out:$launcherExe" `
        $installedLauncherCode
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $launcherExe)) {
        throw "The local launcher could not be compiled."
    }
    Unblock-File -LiteralPath $launcherExe -ErrorAction SilentlyContinue

    New-Item -ItemType Directory -Force -Path $startMenuDir | Out-Null
    New-CodexShortcut -Path $desktopShortcut
    New-CodexShortcut -Path $startMenuShortcut
    Remove-Item -LiteralPath $legacyDesktopShortcut -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $legacyStartMenuShortcut -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $legacyLauncherCode -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $legacyLauncherExe -Force -ErrorAction SilentlyContinue

    $installRecord = [ordered]@{
        patcher_version = "1.0.0"
        store_codex_version = $package.Version.ToString()
        installed_at = (Get-Date).ToString("o")
        package_source = $packageRoot
    }
    $installRecord |
        ConvertTo-Json |
        Set-Content -LiteralPath (Join-Path $launcherDir "install.json") -Encoding UTF8

    $verb = if ($Repair) { "repaired" } else { "installed" }
    Show-Message `
        -Text "$productName was $verb successfully.`n`nUse the 'Codex Model Menu' desktop shortcut." `
        -Icon ([System.Windows.MessageBoxImage]::Information)
    exit 0
}
catch {
    Show-Message `
        -Text "Installation failed.`n`n$($_.Exception.Message)" `
        -Icon ([System.Windows.MessageBoxImage]::Error)
    Write-Error $_
    exit 1
}
