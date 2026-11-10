<#
<#
.SYNOPSIS
    Surveillance système : CPU, mémoire (RAM) et disques.
.DESCRIPTION
    Affiche une mesure ponctuelle de la charge CPU, de la mémoire
    et de l'occupation des lecteurs fixes locaux.
    Compatible Windows PowerShell 5.1 et PowerShell 7+ sous Windows.
    Les calculs utilisent les valeurs brutes ; seul l'affichage est arrondi.
.NOTES
    Auteur initial : Étudiant 1
    Maintenance    : Étudiant 2
    Projet         : Évaluation Git/GitHub - Systèmes & Réseaux
#>

#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw "Ce script doit être exécuté sous Windows."
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "          SURVEILLANCE SYSTÈME            " -ForegroundColor Cyan
Write-Host " Date    : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host " Machine : $env:COMPUTERNAME"
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Utilisation du processeur
Write-Host "--- [1] UTILISATION DU PROCESSEUR ---" -ForegroundColor Yellow
try {
    $cpu = Get-CimInstance -ClassName Win32_Processor |
        Measure-Object -Property LoadPercentage -Average

    if ($cpu.Count -eq 0 -or $null -eq $cpu.Average) {
        throw "Aucune mesure de charge CPU disponible."
    }

    Write-Host ("Charge CPU moyenne : {0:N1} %" -f $cpu.Average)
}
catch {
    Write-Warning "CPU indisponible : $($_.Exception.Message)"
}
Write-Host ""

# 2. Utilisation de la mémoire
Write-Host "--- [2] UTILISATION DE LA MÉMOIRE (RAM) ---" -ForegroundColor Yellow
try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem

    if ($null -eq $os.TotalVisibleMemorySize -or $null -eq $os.FreePhysicalMemory) {
        throw "Mesures mémoire absentes."
    }

    # Ces propriétés sont exprimées en Kio.
    $totalRamKB = [double]$os.TotalVisibleMemorySize
    $freeRamKB  = [double]$os.FreePhysicalMemory

    if ($totalRamKB -le 0 -or $freeRamKB -lt 0 -or $freeRamKB -gt $totalRamKB) {
        throw "Valeurs mémoire incohérentes."
    }

    $usedRamKB = $totalRamKB - $freeRamKB

    [PSCustomObject]@{
        "Total (Gio)"   = "{0:N2}" -f ($totalRamKB / 1MB)
        "Utilisé (Gio)" = "{0:N2}" -f ($usedRamKB / 1MB)
        "Libre (Gio)"   = "{0:N2}" -f ($freeRamKB / 1MB)
        "Utilisation"  = "{0:N1} %" -f ($usedRamKB / $totalRamKB * 100)
    } | Format-Table -AutoSize | Out-Host
}
catch {
    Write-Warning "Mémoire indisponible : $($_.Exception.Message)"
}
Write-Host ""

# 3. Occupation des lecteurs fixes locaux
Write-Host "--- [3] OCCUPATION DES DISQUES LOCAUX ---" -ForegroundColor Yellow
try {
    $disks = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType = 3")

    if ($disks.Count -eq 0) {
        Write-Host "Aucun lecteur fixe local détecté."
    }
    else {
        $disksReport = foreach ($disk in $disks) {
            $volumeLabel = if ([string]::IsNullOrWhiteSpace($disk.VolumeName)) {
                "[Sans nom]"
            }
            else {
                $disk.VolumeName
            }

            $row = [ordered]@{
                "Lecteur"       = $disk.DeviceID
                "Nom du volume" = $volumeLabel
                "Total (Gio)"   = "Indisponible"
                "Utilisé (Gio)" = "Indisponible"
                "Libre (Gio)"   = "Indisponible"
                "Occupation"    = "Indisponible"
            }

            if ($null -ne $disk.Size -and $null -ne $disk.FreeSpace) {
                $totalBytes = [double]$disk.Size
                $freeBytes  = [double]$disk.FreeSpace

                if ($totalBytes -gt 0 -and $freeBytes -ge 0 -and $freeBytes -le $totalBytes) {
                    $usedBytes = $totalBytes - $freeBytes

                    $row["Total (Gio)"]   = "{0:N2}" -f ($totalBytes / 1GB)
                    $row["Utilisé (Gio)"] = "{0:N2}" -f ($usedBytes / 1GB)
                    $row["Libre (Gio)"]   = "{0:N2}" -f ($freeBytes / 1GB)
                    $row["Occupation"]   = "{0:N1} %" -f ($usedBytes / $totalBytes * 100)
                }
            }

            [PSCustomObject]$row
        }

        $disksReport | Format-Table -AutoSize | Out-Host
    }
}
catch {
    Write-Warning "Disques indisponibles : $($_.Exception.Message)"
}

Write-Host "==========================================" -ForegroundColor Cyan