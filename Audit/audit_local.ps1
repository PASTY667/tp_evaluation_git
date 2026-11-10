<#
.SYNOPSIS
    Liste les comptes utilisateurs locaux et leurs informations d'audit.

.DESCRIPTION
    Le script ne modifie aucun compte. Il affiche les comptes locaux et leurs
    propriétés administratives, ainsi que leurs appartenances directes aux
    groupes locaux avec un affichage moderne et structuré.

.PARAMETER CsvPath
    Chemin facultatif vers lequel exporter le rapport au format CSV.

.EXAMPLE
    .\audit_local.ps1

.EXAMPLE
    .\audit_local.ps1 -CsvPath .\rapport_comptes_locaux.csv
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string] $CsvPath
)

# 1. Vérification des prérequis
$requiredCommands = @('Get-LocalUser', 'Get-LocalGroup', 'Get-LocalGroupMember')
foreach ($commandName in $requiredCommands) {
    if (-not (Get-Command -Name $commandName -ErrorAction SilentlyContinue)) {
        throw "La commande '$commandName' est indisponible. Exécutez ce script sur Windows avec le module Microsoft.PowerShell.LocalAccounts."
    }
}

Write-Host "`n[+] Récupération des comptes et groupes locaux..." -ForegroundColor Cyan

# 2. Collecte des données
$localUsers = @(Get-LocalUser -ErrorAction Stop)
$groupMemberships = @{}

foreach ($group in (Get-LocalGroup -ErrorAction Stop)) {
    try {
        $members = Get-LocalGroupMember -Group $group.Name -ErrorAction Stop
        foreach ($member in $members) {
            if ($null -ne $member.SID) {
                $sid = $member.SID.Value
                if (-not $groupMemberships.ContainsKey($sid)) {
                    $groupMemberships[$sid] = [System.Collections.Generic.List[string]]::new()
                }
                $groupMemberships[$sid].Add($group.Name)
            }
        }
    }
    catch {
        Write-Warning "Impossible de lire les membres du groupe '$($group.Name)' : $_"
    }
}

# 3. Construction des objets d'audit
$report = foreach ($user in $localUsers) {
    $sid = $user.SID.Value
    $userGroups = if ($groupMemberships.ContainsKey($sid)) {
        $groupMemberships[$sid] | Sort-Object
    } else {
        @()
    }

    [PSCustomObject]@{
        Name                  = $user.Name
        FullName              = $user.FullName
        Enabled               = $user.Enabled
        Description           = $user.Description
        SID                   = $sid
        LastLogon             = $user.LastLogon
        PasswordLastSet       = $user.PasswordLastSet
        PasswordExpires       = $user.PasswordExpires
        PasswordRequired      = $user.PasswordRequired
        UserMayChangePassword = $user.UserMayChangePassword
        AccountExpires        = $user.AccountExpires
        Groups                = ($userGroups -join ', ')
    }
}

$report = @($report | Sort-Object -Property @{ Expression = { $_.Enabled }; Descending = $true }, Name)

# 4. Rendu / Export
if ($CsvPath) {
    $report | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
    Write-Host "[✓] Rapport exporté avec succès vers : $((Resolve-Path -Path $CsvPath).Path)" -ForegroundColor Green
}
else {
    # En-tête de section
    Write-Host "`n========================= RÉSUMÉ DES COMPTES LOCAUX =========================" -ForegroundColor DarkCyan

    # Vue synthétique sous forme de tableau formaté
    $report | Select-Object `
        @{ Name = 'Statut';        Expression = { if ($_.Enabled) { "[ACTIF]" } else { "[DÉSACTIVÉ]" } } },
        @{ Name = 'Utilisateur';   Expression = { $_.Name } },
        @{ Name = 'Groupes';       Expression = { if ($_.Groups) { $_.Groups } else { '-' } } },
        @{ Name = 'Dernier Logon'; Expression = { if ($_.LastLogon) { $_.LastLogon.ToString('dd/MM/yyyy HH:mm') } else { 'Jamais' } } },
        @{ Name = 'MDP Défini le'; Expression = { if ($_.PasswordLastSet) { $_.PasswordLastSet.ToString('dd/MM/yyyy') } else { 'Jamais' } } } |
        Format-Table -AutoSize

    Write-Host "=============================== DÉTAILS ======================================`n" -ForegroundColor DarkCyan

    # Fiches détaillées aérées par utilisateur
    foreach ($entry in $report) {
        $statusColor = if ($entry.Enabled) { "Green" } else { "DarkGray" }
        $statusLabel = if ($entry.Enabled) { "ACTIF" } else { "DÉSACTIVÉ" }

        Write-Host "● $($entry.Name)" -ForegroundColor Yellow -NoNewline
        Write-Host " [$statusLabel]" -ForegroundColor $statusColor

        Write-Host ("  " + ("-" * 45)) -ForegroundColor DarkGray
        Write-Host "  Nom complet      : $(if ($entry.FullName) { $entry.FullName } else { '-' })"
        Write-Host "  Description      : $(if ($entry.Description) { $entry.Description } else { '-' })"
        Write-Host "  SID              : $($entry.SID)"
        Write-Host "  Groupes          : $(if ($entry.Groups) { $entry.Groups } else { 'Aucun' })" -ForegroundColor Cyan
        Write-Host "  Dernier accès    : $(if ($entry.LastLogon) { $entry.LastLogon.ToString('dd/MM/yyyy HH:mm:ss') } else { 'Jamais' })"
        Write-Host "  Dernier mdp      : $(if ($entry.PasswordLastSet) { $entry.PasswordLastSet.ToString('dd/MM/yyyy HH:mm:ss') } else { 'Jamais' })"
        Write-Host "  Mdp expire       : $(if ($entry.PasswordExpires) { $entry.PasswordExpires.ToString('dd/MM/yyyy') } else { 'Jamais' })"
        Write-Host "  Compte expire    : $(if ($entry.AccountExpires) { $entry.AccountExpires.ToString('dd/MM/yyyy') } else { 'Jamais' })"
        Write-Host "  Politique mdp    : Requis=$($entry.PasswordRequired) | Modifiable=$($entry.UserMayChangePassword)"
        Write-Host ""
    }
}