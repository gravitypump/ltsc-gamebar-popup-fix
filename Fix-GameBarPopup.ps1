<#
.SYNOPSIS
    Silences the "We can't open this 'ms-gamebar' link" popup that appears when an
    Xbox controller is turned on, on Windows editions without Xbox Game Bar
    (Windows 10/11 LTSC, IoT Enterprise, debloated installs).

.DESCRIPTION
    Windows still tries to open ms-gamebar:// (and related) links when a controller
    connects or its Guide button is pressed, even when Game Bar is not installed.
    With no handler registered, Windows shows the "Your device needs a new app"
    popup every time.

    This script registers a silent, do-nothing handler (systray.exe, a built-in
    Windows stub that exits immediately) for those link types machine-wide, and
    turns off the per-user Game Bar controller/capture toggles.

    The handler must be registered machine-wide (HKLM). Registering it only for
    the current user (HKCU) is NOT enough: the popup keeps appearing.

.PARAMETER Undo
    Removes the handlers this script added. The per-user Game Bar toggles are left
    as they are.

.EXAMPLE
    .\Fix-GameBarPopup.ps1
.EXAMPLE
    .\Fix-GameBarPopup.ps1 -Undo
#>
[CmdletBinding()]
param(
    [switch]$Undo
)

$ErrorActionPreference = 'Stop'

$protocols = 'ms-gamebar', 'ms-gamebarservices', 'ms-gamingoverlay'
$handler   = "$env:SystemRoot\System32\systray.exe"

# Re-launch elevated if needed (HKLM writes require admin).
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    if ($Undo) { $argList += '-Undo' }
    $p = Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList $argList -Verb RunAs -Wait -PassThru
    exit $p.ExitCode
}

if ($Undo) {
    foreach ($proto in $protocols) {
        foreach ($root in 'HKLM\SOFTWARE\Classes', 'HKCU\Software\Classes') {
            $key = "$root\$proto"
            $cmd = (Get-ItemProperty -Path "Registry::$key\shell\open\command" -ErrorAction SilentlyContinue).'(default)'
            # Only remove keys that point at our stub, so a real Game Bar install is never touched.
            if ($cmd -and $cmd -like '*systray.exe*') {
                # reg.exe rather than Remove-Item: the PowerShell registry provider is
                # refused access when deleting under HKLM\SOFTWARE\Classes, even as admin.
                & reg.exe delete $key /f | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "Failed to remove $key" }
                Write-Host "Removed $key"
            }
        }
    }
    Write-Host 'Undo complete.'
    exit 0
}

foreach ($proto in $protocols) {
    $key = "HKLM:\SOFTWARE\Classes\$proto"
    $existing = (Get-ItemProperty -Path "$key\shell\open\command" -ErrorAction SilentlyContinue).'(default)'
    if ($existing -and $existing -notlike '*systray.exe*') {
        Write-Warning "$proto already has a handler ($existing); leaving it alone."
        continue
    }
    New-Item -Path "$key\shell\open\command" -Force | Out-Null
    Set-ItemProperty -Path $key -Name '(default)' -Value "URL:$proto"
    New-ItemProperty -Path $key -Name 'URL Protocol' -Value '' -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $key -Name 'NoOpenWith'   -Value '' -PropertyType String -Force | Out-Null
    Set-ItemProperty -Path "$key\shell\open\command" -Name '(default)' -Value $handler
    Write-Host "Registered silent handler for ${proto}:"
}

# Per-user toggles: don't open Game Bar from the controller button, no capture.
$toggles = @(
    @{ Path = 'HKCU:\Software\Microsoft\GameBar';                         Name = 'UseNexusForGameBarEnabled' },
    @{ Path = 'HKCU:\Software\Microsoft\GameBar';                         Name = 'ShowStartupPanel' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR';  Name = 'AppCaptureEnabled' },
    @{ Path = 'HKCU:\System\GameConfigStore';                             Name = 'GameDVR_Enabled' }
)
foreach ($t in $toggles) {
    if (-not (Test-Path $t.Path)) { New-Item -Path $t.Path -Force | Out-Null }
    New-ItemProperty -Path $t.Path -Name $t.Name -Value 0 -PropertyType DWord -Force | Out-Null
}
Write-Host 'Turned off Game Bar controller button and capture toggles for the current user.'
Write-Host 'Done. Power-cycle your controller to check. If the popup persists, sign out and back in.'
