<#
.SYNOPSIS
    Creates the missing Start Menu and Desktop shortcuts for BlueBird Simulations NEST,
    and (by default) marks NEST to always run as administrator so installing the 757 does not fail with a permission error.

.DESCRIPTION
    The NEST 1.0.0.0 installer copies the program to
    %LOCALAPPDATA%\Programs\BlueBird Simulations\NEST and registers an uninstaller,
    but never creates a shortcut. Windows Search only finds apps that have a Start Menu
    shortcut, so after installing, NEST looks like it is not there at all.

    This script:
      * finds the NEST install from its uninstall registry entry (falls back to the default path)
      * creates "BlueBird NEST.lnk" in your Start Menu and on your Desktop
      * sets the per-user "Run this program as an administrator" compatibility flag on bbs_nest.exe
    Everything is per-user (HKCU and your own profile). The script itself does not need admin rights.

.PARAMETER NoAdmin
    Do not set the run-as-administrator flag (and remove it if a previous run set it).

.PARAMETER NoDesktop
    Do not create the Desktop shortcut.

.PARAMETER NoStartMenu
    Do not create the Start Menu shortcut.

.PARAMETER Uninstall
    Remove the shortcuts and the run-as-administrator flag this script created.

.PARAMETER ExePath
    Use this bbs_nest.exe instead of searching for it.

.EXAMPLE
    .\Install-NestShortcut.ps1
.EXAMPLE
    .\Install-NestShortcut.ps1 -NoAdmin -NoDesktop
.EXAMPLE
    .\Install-NestShortcut.ps1 -Uninstall
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$NoAdmin,
    [switch]$NoDesktop,
    [switch]$NoStartMenu,
    [switch]$Uninstall,
    [string]$ExePath
)

$ErrorActionPreference = 'Stop'
$ShortcutName = 'BlueBird NEST.lnk'
$LayersKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
$StartMenuLnk = Join-Path ([Environment]::GetFolderPath('Programs')) $ShortcutName
$DesktopLnk = Join-Path ([Environment]::GetFolderPath('Desktop')) $ShortcutName

function Find-NestExe {
    $uninstallRoots = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($root in $uninstallRoots) {
        if (-not (Test-Path $root)) { continue }
        foreach ($entry in Get-ChildItem $root -ErrorAction SilentlyContinue) {
            $p = Get-ItemProperty $entry.PSPath -ErrorAction SilentlyContinue
            if ($p.DisplayName -notmatch 'BlueBird.*NEST') { continue }
            foreach ($candidate in @($p.DisplayIcon, (Join-Path "$($p.InstallLocation)" 'bbs_nest.exe'))) {
                if ($candidate) {
                    $c = $candidate.Trim('"') -replace ',\d+$', ''
                    if (Test-Path -LiteralPath $c -PathType Leaf) { return (Resolve-Path -LiteralPath $c).Path }
                }
            }
        }
    }
    $default = Join-Path $env:LOCALAPPDATA 'Programs\BlueBird Simulations\NEST\bbs_nest.exe'
    if (Test-Path -LiteralPath $default -PathType Leaf) { return $default }
    return $null
}

function New-Shortcut([string]$Path, [string]$Target) {
    if ($PSCmdlet.ShouldProcess($Path, 'Create shortcut')) {
        $dir = Split-Path $Path
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $ws = New-Object -ComObject WScript.Shell
        $s = $ws.CreateShortcut($Path)
        $s.TargetPath = $Target
        $s.WorkingDirectory = Split-Path $Target
        $s.IconLocation = "$Target,0"
        $s.Description = 'BlueBird Simulations NEST'
        $s.Save()
        Write-Host "  created  $Path"
    }
}

function Remove-IfPresent([string]$Path) {
    if ((Test-Path -LiteralPath $Path) -and $PSCmdlet.ShouldProcess($Path, 'Remove shortcut')) {
        Remove-Item -LiteralPath $Path -Force
        Write-Host "  removed  $Path"
    }
}

function Set-RunAsAdmin([string]$Exe, [bool]$Enable) {
    if (-not (Test-Path $LayersKey)) {
        if (-not $Enable) { return }
        New-Item -Path $LayersKey -Force | Out-Null
    }
    $current = (Get-ItemProperty -Path $LayersKey -Name $Exe -ErrorAction SilentlyContinue).$Exe
    # Keep any other compatibility layers the user already set (e.g. HIGHDPIAWARE), only add or drop RUNASADMIN.
    $layers = @()
    if ($current) { $layers = $current.Trim() -replace '^~\s*', '' -split '\s+' | Where-Object { $_ -and $_ -ne 'RUNASADMIN' } }
    if ($Enable) { $layers += 'RUNASADMIN' }
    if ($layers.Count -eq 0) {
        if ($null -ne $current -and $PSCmdlet.ShouldProcess($Exe, 'Remove run-as-administrator flag')) {
            Remove-ItemProperty -Path $LayersKey -Name $Exe
            Write-Host "  cleared  run-as-administrator flag"
        }
        return
    }
    $value = '~ ' + ($layers -join ' ')
    if ($value -ne $current -and $PSCmdlet.ShouldProcess($Exe, "Set compatibility layers to '$value'")) {
        Set-ItemProperty -Path $LayersKey -Name $Exe -Value $value
        Write-Host "  set      $value  (HKCU AppCompatFlags\Layers)"
    }
}

Write-Host 'BlueBird NEST shortcut fix'
$exe = if ($ExePath) { (Resolve-Path -LiteralPath $ExePath).Path } else { Find-NestExe }

if ($Uninstall) {
    Remove-IfPresent $StartMenuLnk
    Remove-IfPresent $DesktopLnk
    if ($exe) { Set-RunAsAdmin $exe $false }
    Write-Host 'Done. NEST itself was not touched.'
    return
}

if (-not $exe) {
    Write-Error "Could not find bbs_nest.exe. Install NEST first, or pass -ExePath 'C:\path\to\bbs_nest.exe'."
}
Write-Host "  found    $exe"

if (-not $NoStartMenu) { New-Shortcut $StartMenuLnk $exe }
if (-not $NoDesktop) { New-Shortcut $DesktopLnk $exe }
Set-RunAsAdmin $exe (-not $NoAdmin)

Write-Host ''
Write-Host 'Done. Search "BlueBird NEST" in Start, or use the Desktop icon.'
if (-not $NoAdmin) { Write-Host 'Windows will show a UAC prompt each time NEST starts; that is expected.' }
