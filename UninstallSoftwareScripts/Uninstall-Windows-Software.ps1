<#
.SYNOPSIS
    Uninstalls a specified software from a Windows system safely with rollback.

.DESCRIPTION
    This script uninstalls software by reading uninstall info from registry.
    It supports both local and remote machines and logs all actions.
    A rollback mechanism attempts to reinstall the software from a predefined installer.

.NOTES
    Author: Uday Kiran Ragidi
    Created: 11-05-2025
    Tested: Windows 10, Windows 11

.EXAMPLE
    .\Uninstall-Software-Safe.ps1 -SoftwareName "Notepad++" -ComputerName "localhost"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$SoftwareName,

    [Parameter(Mandatory = $true)]
    [string]$ComputerName
)

# Set up logging
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logPath = "C:\Logs\Uninstall-$SoftwareName-$ComputerName-$timestamp.log"
Start-Transcript -Path $logPath -Append

Write-Host "Starting uninstallation of '$SoftwareName' on $ComputerName" -ForegroundColor Green

# Define rollback function
function Invoke-Rollback {
    $installerPath = "C:\Installers\npp.8.6.4.Installer.x64.exe"  # Update path to actual installer

    if (Test-Path $installerPath) {
        Write-Warning "Rollback started: Reinstalling $SoftwareName from $installerPath"
        $arguments = "/S"  # Silent install

        $installProcess = Start-Process -FilePath $installerPath -ArgumentList $arguments -Wait -PassThru

        if ($installProcess.ExitCode -eq 0) {
            Write-Host "Rollback successful: $SoftwareName reinstalled." -ForegroundColor Green
        } else {
            Write-Error "Rollback failed: Installer exited with code $($installProcess.ExitCode)"
        }
    } else {
        Write-Error "Rollback failed: Installer not found at $installerPath"
    }
}

function Uninstall-FromRegistry {
    param(
        [string]$TargetSoftware
    )

    # Check 64-bit and 32-bit uninstall registry paths
    $uninstallPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $app = $null
    foreach ($path in $uninstallPaths) {
        $app = Get-ItemProperty $path -ErrorAction SilentlyContinue |
               Where-Object { $_.DisplayName -like "*$TargetSoftware*" }
        if ($app) { break }
    }

    if ($app) {
        Write-Output "Found software: $($app.DisplayName)"
        $uninstallString = $app.UninstallString

        if ($uninstallString) {
            Write-Output "Uninstall string: $uninstallString"
            # Normalize uninstall string
            if ($uninstallString -match 'msiexec') {
                $arguments = $uninstallString.Replace("msiexec.exe", "")
                Start-Process -FilePath "msiexec.exe" -ArgumentList $arguments -Wait
            } else {
                Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "$uninstallString /S" -Wait
            }

            Write-Output "$($app.DisplayName) uninstalled successfully."
        } else {
            Write-Warning "Uninstall string not found for $TargetSoftware."
        }
    } else {
        Write-Warning "Software '$TargetSoftware' not found in registry."
    }
}

try {
    if ($ComputerName -ne "localhost") {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock ${function:Uninstall-FromRegistry} -ArgumentList $SoftwareName
    } else {
        Uninstall-FromRegistry -TargetSoftware $SoftwareName
    }
}
catch {
    Write-Error "Error occurred: $_"
    Invoke-Rollback
}
finally {
    Stop-Transcript
    Write-Host "Uninstallation script completed. Logs saved to $logPath"
}
