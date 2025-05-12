param (
 [string]$SoftwareName = "Google Chrome",
 [string]$BackupRoot = "C:\Users\Udaykiran.ragidi\SoftwareBackups",
 [string]$LogPath = "C:\Users\Udaykiran.ragidi\VC2013-Remediation-Precheck-Log.txt"
)

# Ensure directories exist
New-Item -Path $BackupRoot -ItemType Directory -Force | Out-Null
New-Item -Path (Split-Path $LogPath) -ItemType Directory -Force | Out-Null

# Registry paths to search
$registryPaths = @(
 "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
 "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

# DLLs to check for
$dllsToCheck = @(
    "KERNEL32.dll", "ADVAPI32.dll", "WINMM.dll", "COMCTL32.dll",
    "SHLWAPI.dll", "GDI32.dll", "SHELL32.dll", "VERSION.dll",
    "USP10.dll", "ole32.dll", "OLEAUT32.dll", "OLEACC.dll",
    "PSAPI.DLL", "secur32.dll", "t2embed.dll", "riched20.dll",
    "USER32.dll", "CRYPTUI.dll", "IMM32.dll"
)


# Initialize log
$log = @()
$found = $false

# 1. Registry Backup
foreach ($path in $registryPaths) {
 $keys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
 foreach ($key in $keys) {
 $props = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue
 if ($props.DisplayName -eq $SoftwareName) {
 $found = $true
 $backupPath = Join-Path -Path $BackupRoot -ChildPath "$env:COMPUTERNAME-$($props.DisplayName).reg"
 $regPath = $key.Name
 reg export "$regPath" "$backupPath" /y | Out-Null
 $log += "[$env:COMPUTERNAME] Registry backup completed for: $SoftwareName"
 break
 }
 }
 if ($found) { break }
}

if (-not $found) {
 $log += "[$env:COMPUTERNAME] Software not found in registry: $SoftwareName"
}

# 2. Dependency Check
foreach ($dll in $dllsToCheck) {
 $dllFound = Get-ChildItem -Path "C:\Windows\System32" -Filter $dll -ErrorAction SilentlyContinue
 if ($dllFound) {
 $log += "[$env:COMPUTERNAME] DLL found: $dll in System32"
 }
}

$services = Get-WmiObject -Class Win32_Service
foreach ($svc in $services) {
 if ($svc.PathName -match ".*(Program Files|System32).*") {
 foreach ($dll in $dllsToCheck) {
 if (Test-Path "$($svc.PathName)\$dll") {
 $log += "[$env:COMPUTERNAME] Service '$($svc.Name)' may use $dll"
 }
 }
 }
}

$apps = Get-ChildItem -Path "C:\Program Files", "C:\Program Files (x86)" -Recurse -ErrorAction SilentlyContinue -Include *.exe, *.dll
foreach ($app in $apps) {
 foreach ($dll in $dllsToCheck) {
 if ($app.Name -eq $dll) {
 $log += "[$env:COMPUTERNAME] Found $dll in $($app.FullName)"
 }
 }
}

if ($log.Count -eq 0) {
 $log += "[$env:COMPUTERNAME] No dependencies or software found."
}

# Write log
Add-Content -Path $LogPath -Value $log

Write-Host "Precheck completed. Log saved to $LogPath"
