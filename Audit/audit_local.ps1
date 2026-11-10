<#
.SYNOPSIS
    Liste les comptes utilisateurs locaux et leurs informations d'audit.

.DESCRIPTION
    Le script ne modifie aucun compte. Il affiche les comptes locaux et leurs
    propriétés administratives, ainsi que leurs appartenances directes aux
    groupes locaux.

.PARAMETER CsvPath
    Chemin facultatif vers lequel exporter le rapport au format CSV.

.EXAMPLE
    .\Audit\audit_local.ps1

.EXAMPLE
    .\Audit\audit_local.ps1 -CsvPath .\rapport_comptes_locaux.csv
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string] $CsvPath
)

$logDirectory = Join-Path -Path $PSScriptRoot -ChildPath 'logs'
New-Item -ItemType Directory -Path $logDirectory -Force -ErrorAction Stop | Out-Null

$logFileName = 'audit_local_{0}_{1}.log' -f (Get-Date -Format 'yyyyMMdd_HHmmss_fff'), $PID
$logPath = Join-Path -Path $logDirectory -ChildPath $logFileName
Start-Transcript -Path $logPath -ErrorAction Stop | Out-Null

try {
Write-Output "Journal d'exécution : $logPath"

$requiredCommands = @(
    'Get-LocalUser',
    'Get-LocalGroup',
    'Get-LocalGroupMember'
)

foreach ($commandName in $requiredCommands) {
    if (-not (Get-Command -Name $commandName -ErrorAction SilentlyContinue)) {
        throw "La commande '$commandName' est indisponible. Exécutez ce script sur Windows avec le module Microsoft.PowerShell.LocalAccounts."
    }
}

$localUsers = @(Get-LocalUser -ErrorAction Stop)
$groupMemberships = @{}

foreach ($group in (Get-LocalGroup -ErrorAction Stop)) {
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

$report = foreach ($user in $localUsers) {
    $sid = $user.SID.Value
    $groups = if ($groupMemberships.ContainsKey($sid)) {
        ($groupMemberships[$sid] | Sort-Object) -join ', '
    }
    else {
        ''
    }

    [PSCustomObject]@{
        Name                 = $user.Name
        FullName             = $user.FullName
        Enabled              = $user.Enabled
        Description          = $user.Description
        SID                  = $sid
        LastLogon            = $user.LastLogon
        PasswordLastSet      = $user.PasswordLastSet
        PasswordExpires      = $user.PasswordExpires
        PasswordRequired     = $user.PasswordRequired
        UserMayChangePassword = $user.UserMayChangePassword
        AccountExpires       = $user.AccountExpires
        Groups               = $groups
    }
}

$report = @($report | Sort-Object Name)

if ($CsvPath) {
    $report | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
    Write-Output "Rapport exporté vers : $((Resolve-Path -Path $CsvPath).Path)"
}
else {
    $report | Format-List
}
}
finally {
    Stop-Transcript | Out-Null
}