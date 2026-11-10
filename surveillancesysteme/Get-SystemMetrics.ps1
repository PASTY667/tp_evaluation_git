<#
.SYNOPSIS
    Surveillance système : CPU, Mémoire (RAM) et Disques.
.DESCRIPTION
    Script d'audit système n'exigeant aucun privilège administrateur particulier.
    Compatible Windows PowerShell 5.1+ et PowerShell 7+.
.NOTES
    Auteur  : Étudiant 1
    Projet  : Évaluation Git/GitHub - Systèmes & Réseaux
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
        "Total (Go)"    = $totalRamGB
        "Utilisé (Go)"  = $usedRamGB
        "Libre (Go)"    = $freeRamGB
        "Utilisation %" = "$ramPercent %"
    } | Format-Table -AutoSize
}
catch {
    Write-Warning "Impossible de récupérer les métriques mémoire : $_"
}
Write-Host ""

# 3. Utilisation des Disques
Write-Host "--- [3] OCCUPATION DES DISQUES LOCAUX ---" -ForegroundColor Yellow
try {
    # DriveType = 3 correspond aux disques fixes locaux
    Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType = 3" | ForEach-Object {
        $totalGB = [math]::Round($_.Size / 1GB, 2)
        $freeGB  = [math]::Round($_.FreeSpace / 1GB, 2)
        $usedGB  = [math]::Round($totalGB - $freeGB, 2)
        $pctUsed = if ($totalGB -gt 0) { [math]::Round(($usedGB / $totalGB) * 100, 1) } else { 0 }

        [PSCustomObject]@{
            "Lecteur"       = $_.DeviceID
            "Volume"        = $_.VolumeName
            "Taille (Go)"   = $totalGB
            "Utilisé (Go)"  = $usedGB
            "Libre (Go)"    = $freeGB
            "Utilisation %" = "$pctUsed %"
        }
    } | Format-Table -AutoSize
}
catch {
    Write-Warning "Impossible de récupérer les métriques disques : $_"
}

Write-Host "==========================================" -ForegroundColor Cyan