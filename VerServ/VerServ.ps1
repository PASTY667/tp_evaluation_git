# Controle des services
    [string[]]$Services = @("Spooler", "wuauserv", "BITS")
)

# Le compte rendu est recree a chaque execution, a cote du script.
$Rapport = Join-Path -Path $PSScriptRoot -ChildPath "rapport_services.txt"
"Compte rendu du $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" |
    Set-Content -LiteralPath $Rapport -Encoding UTF8 -ErrorAction Stop

foreach ($Nom in $Services) {
    try {
        $Service = Get-Service -Name $Nom -ErrorAction Stop
    }
    catch {
        $Ligne = "$Nom : service introuvable ou inaccessible."
        Write-Output $Ligne
        Add-Content -LiteralPath $Rapport -Value $Ligne -Encoding UTF8 -ErrorAction Stop
        continue
    }

    # Tous les etats sont consignes, y compris Stopped (arrete).
    $Ligne = "{0} ({1}) : {2}" -f $Service.Name, $Service.DisplayName, $Service.Status
    Write-Output $Ligne
    Add-Content -LiteralPath $Rapport -Value $Ligne -Encoding UTF8 -ErrorAction Stop
}

Write-Output "Compte rendu termine : $Rapport"