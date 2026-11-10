<#
.SYNOPSIS
    Surveillance système : CPU, Mémoire (RAM) et Disques.
.DESCRIPTION
    Script d'audit système n'exigeant aucun privilège administrateur particulier.
    Compatible Windows PowerShell 5.1+ et PowerShell 7+.
.NOTES
    Auteur initial : Étudiant 1
    Maintenance    : Étudiant 2 (Correction formatage disques - Issue #7)
    Projet         : Évaluation Git/GitHub - Systèmes & Réseaux
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "          SURVEILLANCE SYSTÈME            " -ForegroundColor Cyan
Write-Host " Date    : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host " Machine : $env:COMPUTERNAME"
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Utilisation du Processeur (CPU)
Write-Host "--- [1] UTILISATION DU PROCESSEUR ---" -ForegroundColor Yellow
try {
    $cpu = Get-CimInstance -ClassName Win32_Processor | Measure-Object -Property LoadPercentage -Average
    $cpuUsage = [math]::Round($cpu.Average, 1)
    Write-Host "Charge CPU globale : $cpuUsage %"
}
catch {
    Write-Warning "Impossible de récupérer les métriques CPU : $_"
}
Write-Host ""

# 2. Utilisation de la Mémoire (RAM)
Write-Host "--- [2] UTILISATION DE LA MÉMOIRE (RAM) ---" -ForegroundColor Yellow
try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $totalRamGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeRamGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedRamGB  = [math]::Round($totalRamGB - $freeRamGB, 2)
    $ramPercent = [math]::Round(($usedRamGB / $totalRamGB) * 100, 1)

    [PSCustomObject]@{
        "Total (Go)"    = "{0:N2}" -f $totalRamGB
        "Utilisé (Go)"  = "{0:N2}" -f $usedRamGB
        "Libre (Go)"    = "{0:N2}" -f $freeRamGB
        "Utilisation %" = "$ramPercent %"
    } | Format-Table -AutoSize
}
catch {
    Write-Warning "Impossible de récupérer les métriques mémoire : $_"
}
Write-Host ""

# 3. Utilisation des Disques (Section Corrigée)
Write-Host "--- [3] OCCUPATION DES DISQUES LOCAUX ---" -ForegroundColor Yellow
try {
    # DriveType = 3 correspond aux disques fixes locaux
    $disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType = 3"
    
    $disksReport = foreach ($disk in $disks) {
        $totalBytes = [double]$disk.Size
        $freeBytes  = [double]$disk.FreeSpace
        
        if ($totalBytes -gt 0) {
            $totalGB = [math]::Round($totalBytes / 1GB, 2)
            $freeGB  = [math]::Round($freeBytes / 1GB, 2)
            $usedGB  = [math]::Round($totalGB - $freeGB, 2)
            $pctUsed = [math]::Round(($usedGB / $totalGB) * 100, 1)
        } else {
            $totalGB = 0.00
            $freeGB  = 0.00
            $usedGB  = 0.00
            $pctUsed = 0.0
        }

        $volumeLabel = if ([string]::IsNullOrWhiteSpace($disk.VolumeName)) { "[Système / Sans nom]" } else { $disk.VolumeName }

        [PSCustomObject]@{
            "Lecteur"       = $disk.DeviceID
            "Nom Volume"    = $volumeLabel
            "Total (Go)"    = "{0:N2}" -f $totalGB
            "Utilisé (Go)"  = "{0:N2}" -f $usedGB
            "Libre (Go)"    = "{0:N2}" -f $freeGB
            "Occupation"    = "$pctUsed %"
        }
    }
    
    $disksReport | Format-Table -AutoSize
}
catch {
    Write-Warning "Impossible de récupérer les métriques disques : $_"
}

Write-Host "==========================================" -ForegroundColor Cyan