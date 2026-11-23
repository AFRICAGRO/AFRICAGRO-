# =====================================================================
#  WANZALA : FREEDOM — Installation de l'atelier de création (Windows 10/11)
#
#  Lancer dans PowerShell (clic droit > « Exécuter en tant qu'administrateur ») :
#     Set-ExecutionPolicy -Scope Process Bypass
#     .\installer-windows.ps1
#
#  Options :
#     -AvecVisualStudio   installe aussi Visual Studio 2022 (≈ 30 Go, nécessaire pour le C++ d'Unreal)
#     -SansOutilsArt      n'installe pas Krita, GIMP, Inkscape, Audacity, QGIS
#
#  Le script peut être relancé sans risque : ce qui est déjà installé est ignoré.
# =====================================================================
param(
    [switch]$AvecVisualStudio,
    [switch]$SansOutilsArt
)

$ErrorActionPreference = "Continue"
$echecs = @()

function Titre($t) { Write-Host "`n=== $t ===" -ForegroundColor Cyan }

function Installer($id, $nom) {
    Write-Host "-> $nom ($id)" -ForegroundColor Yellow
    winget install --id $id -e --accept-package-agreements --accept-source-agreements --silent
    if ($LASTEXITCODE -ne 0) {
        # winget renvoie aussi un code d'erreur quand le logiciel est DÉJÀ installé :
        # on vérifie donc s'il est présent avant de le compter comme un échec.
        winget list --id $id -e --accept-source-agreements | Out-Null
        if ($LASTEXITCODE -ne 0) { $script:echecs += "$nom (winget id : $id)" }
        else { Write-Host "   déjà installé" -ForegroundColor Green }
    }
}

# ---------------------------------------------------------------------
Titre "1. Vérification de l'ordinateur"
$ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
$gpu = (Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name) -join ", "
$disque = [math]::Round((Get-PSDrive C).Free / 1GB)
Write-Host "Mémoire vive : $ram Go (minimum conseillé 32 Go)"
Write-Host "Carte graphique : $gpu (conseillé : RTX 3060 12 Go ou mieux)"
Write-Host "Espace libre sur C: : $disque Go (Unreal + projet : prévoir 150 Go et plus)"
if ($ram -lt 16)    { Write-Host "ATTENTION : moins de 16 Go de mémoire, Unreal sera très lent." -ForegroundColor Red }
if ($disque -lt 150) { Write-Host "ATTENTION : moins de 150 Go libres." -ForegroundColor Red }

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "winget est introuvable. Installez « App Installer » depuis le Microsoft Store, puis relancez." -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------
Titre "2. Outils de base"
Installer "Git.Git"                  "Git"
Installer "GitHub.GitLFS"            "Git LFS (gros fichiers 3D)"
Installer "Python.Python.3.12"       "Python 3.12"
Installer "astral-sh.uv"             "uv (lance les serveurs MCP de Claude)"

# ---------------------------------------------------------------------
Titre "3. Création 3D et moteur"
Installer "BlenderFoundation.Blender"     "Blender"
Installer "EpicGames.EpicGamesLauncher"   "Epic Games Launcher (pour installer Unreal Engine 5)"
if ($AvecVisualStudio) {
    Write-Host "-> Visual Studio 2022 Community + charge « Développement de jeux en C++ »" -ForegroundColor Yellow
    winget install --id Microsoft.VisualStudio.2022.Community -e --silent --accept-package-agreements --accept-source-agreements `
        --override "--quiet --wait --add Microsoft.VisualStudio.Workload.NativeGame --add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended"
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) { $echecs += "Visual Studio 2022 Community" }
}

# ---------------------------------------------------------------------
if (-not $SansOutilsArt) {
    Titre "4. Art, son et cartographie"
    Installer "KDE.Krita"          "Krita (dessin, concept art)"
    Installer "GIMP.GIMP.3"        "GIMP (retouche d'images)"
    Installer "Inkscape.Inkscape"  "Inkscape (logos, interface)"
    Installer "Audacity.Audacity"  "Audacity (son)"
    Installer "OSGeo.QGIS"         "QGIS (données satellites)"
}

# ---------------------------------------------------------------------
Titre "5. Claude"
Installer "Anthropic.Claude" "Application Claude (Desktop)"
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "-> Claude Code (installateur officiel)" -ForegroundColor Yellow
    try { Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression }
    catch { $echecs += "Claude Code (voir https://code.claude.com/docs)" }
}

# Rafraîchit le PATH de cette fenêtre pour trouver uv, git et claude tout juste installés
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" +
            "$env:USERPROFILE\.local\bin"

# ---------------------------------------------------------------------
Titre "6. Connecteur Blender pour Claude (Blender MCP)"
if (Get-Command uvx -ErrorAction SilentlyContinue) {
    # installe et active l'extension « MCP » dans Blender
    uvx mcp-for-blender install-addon
    if ($LASTEXITCODE -ne 0) { $echecs += "Extension Blender MCP (relancer : uvx mcp-for-blender install-addon)" }
    # pré-télécharge les deux serveurs pour que Claude les démarre sans attendre
    uvx --from unreal-engine-mcp python -c "print('connecteur Unreal prêt')"
    uvx --from mcp-for-blender python -c "print('connecteur Blender prêt')"
} else {
    $echecs += "uvx introuvable : fermer PowerShell, en rouvrir un et relancer ce script"
}

if (Get-Command git -ErrorAction SilentlyContinue) { git lfs install | Out-Null }

# ---------------------------------------------------------------------
Titre "Bilan"
if ($echecs.Count -eq 0) {
    Write-Host "Tout est installé." -ForegroundColor Green
} else {
    Write-Host "À installer à la main :" -ForegroundColor Red
    $echecs | ForEach-Object { Write-Host "  - $_" }
}
Write-Host @"

Étapes manuelles restantes (voir jeu/installation/INSTALLATION.md) :
  1. Ouvrir Epic Games Launcher, créer un compte, onglet Unreal Engine > Bibliothèque > installer UE 5 (dernière version).
  2. Créer le projet « TerreLibre » (modèle Third Person), puis lancer configurer-projet-unreal.ps1.
  3. Dans le dossier du dépôt, lancer « claude » : accepter les serveurs Blender et Unreal proposés (.mcp.json).
"@
