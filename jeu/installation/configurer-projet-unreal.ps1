# =====================================================================
#  TERRE LIBRE — Prépare un projet Unreal Engine 5 pour être piloté par Claude
#
#  Après avoir créé le projet dans Unreal (modèle Third Person), Unreal FERMÉ :
#     Set-ExecutionPolicy -Scope Process Bypass
#     .\configurer-projet-unreal.ps1 -Projet "C:\Chemin\TerreLibre\TerreLibre.uproject"
#
#  Ce que fait le script (une sauvegarde .bak de chaque fichier est créée) :
#   - active les plugins Python Editor Script, Remote Control API, Water, PCG,
#     Landmass, Chaos Vehicles ;
#   - active l'exécution Python à distance (utilisée par le connecteur Unreal de Claude),
#     limitée à cet ordinateur ;
#   - active World Partition par défaut pour les nouveaux niveaux.
# =====================================================================
param([Parameter(Mandatory = $true)][string]$Projet)

if (-not (Test-Path $Projet)) { Write-Host "Fichier introuvable : $Projet" -ForegroundColor Red; exit 1 }
$dossier = Split-Path $Projet -Parent

# --- 1. Plugins dans le .uproject -----------------------------------
Copy-Item $Projet "$Projet.bak" -Force
$up = Get-Content $Projet -Raw | ConvertFrom-Json
if (-not $up.Plugins) { $up | Add-Member -NotePropertyName Plugins -NotePropertyValue @() }
$voulus = "PythonScriptPlugin", "RemoteControl", "Water", "PCG", "Landmass", "ChaosVehiclesPlugin"
foreach ($nom in $voulus) {
    $p = $up.Plugins | Where-Object { $_.Name -eq $nom }
    if ($p) { $p.Enabled = $true }
    else { $up.Plugins += [pscustomobject]@{ Name = $nom; Enabled = $true } }
    Write-Host "Plugin activé : $nom"
}
$up | ConvertTo-Json -Depth 10 | Set-Content $Projet -Encoding UTF8

# --- 2. DefaultEngine.ini -------------------------------------------
$ini = Join-Path $dossier "Config\DefaultEngine.ini"
if (-not (Test-Path $ini)) { New-Item -ItemType File -Force $ini | Out-Null }
Copy-Item $ini "$ini.bak" -Force
$contenu = Get-Content $ini -Raw
$ajout = @"

[/Script/PythonScriptPlugin.PythonScriptPluginSettings]
bRemoteExecution=True
RemoteExecutionMulticastGroupEndpoint=239.0.0.1:6766
RemoteExecutionMulticastTtl=0
"@
if ($contenu -notmatch "bRemoteExecution") {
    Add-Content $ini $ajout
    Write-Host "Exécution Python à distance activée (limitée à cet ordinateur)."
} else {
    Write-Host "Exécution Python à distance déjà configurée : rien changé."
}

# --- 3. DefaultEditor.ini : World Partition pour les nouveaux niveaux -
$ed = Join-Path $dossier "Config\DefaultEditor.ini"
if (-not (Test-Path $ed)) { New-Item -ItemType File -Force $ed | Out-Null }
if ((Get-Content $ed -Raw) -notmatch "bEnableWorldPartition") {
    Add-Content $ed "`n[/Script/UnrealEd.LevelEditorMiscSettings]`nbEnableWorldPartition=True`n"
}

Write-Host "`nTerminé. Ouvrez le projet : Unreal proposera de recompiler/activer les plugins, acceptez." -ForegroundColor Green
Write-Host "Ensuite, dans le dossier du dépôt AFRICAGRO-, lancez « claude » puis tapez /mcp pour vérifier les connecteurs."
