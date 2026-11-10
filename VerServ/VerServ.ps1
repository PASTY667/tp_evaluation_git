# Controle des services - version avec un defaut volontaire.
param(
    [string[]]$Services = @("Spooler", "wuauserv", "BITS")
)

# Le rapport est recree dans le dossier du script.
$Rapport = Join-Path $PSScriptRoot "rapport_services.txt"

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

    # DEFAUT VOLONTAIRE : interrompt le script si le service est arrete.
    if ($Service.Status -eq "Stopped") {
        throw "Echec du controle : le service '$Nom' est arrete."
    }

    $Ligne = "{0} ({1}) : {2}" -f $Service.Name, $Service.DisplayName, $Service.Status
    Write-Output $Ligne
    Add-Content -LiteralPath $Rapport -Value $Ligne -Encoding UTF8 -ErrorAction Stop
}

Write-Output "Compte rendu termine : $Rapport"