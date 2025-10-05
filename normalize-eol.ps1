<#
normalize-eol.ps1

Script PowerShell pour normaliser les fins de ligne CRLF -> LF sur les fichiers suivis par git.

Comportement:
- Par défaut : applique les changements (mode "apply").
- Option : -DryRun pour simuler sans modifier.
- Option : -SetGitExecutable pour marquer les fichiers débutant par shebang (#!) comme exécutables
  dans l'index git (git update-index --chmod=+x).

Le script crée une sauvegarde du fichier original avec le suffixe .bak avant modification.

Usage:
  # appliquer (par défaut)
  pwsh ./scripts/normalize-eol.ps1

  # simuler (ne rien modifier)
  pwsh ./scripts/normalize-eol.ps1 -DryRun

  # appliquer et marquer les scripts comme exécutables dans l'index git
  pwsh ./scripts/normalize-eol.ps1 -SetGitExecutable
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Apply,
    [switch]$SetGitExecutable,
    [string]$BackupSuffix = '.bak'
)

function Write-Log { param([string]$m) Write-Host $m }

# Déterminer mode d'exécution :
# - Si l'utilisateur passe explicitement -Apply ou -DryRun, respecter.
# - Si aucun des deux n'est fourni, appliquer par défaut (Apply = $true).
if ($DryRun -and $Apply) {
    Write-Error "Ne pouvez pas fournir à la fois -DryRun et -Apply."
    exit 2
}
if ($PSBoundParameters.ContainsKey('Apply')) { 
    $FinalApply = $Apply.IsPresent
} elseif ($PSBoundParameters.ContainsKey('DryRun')) {
    $FinalApply = -not $DryRun.IsPresent
} else {
    # Aucun switch fourni -> appliquer par défaut
    $FinalApply = $true
}

# Backwards-compatible alias in local variable
$Apply = $FinalApply

# Vérifier qu'on est dans un dépôt git et que l'on se situe à la racine du dépôt
# Utiliser des invocations PowerShell-safe et comparer les chemins résolus (Windows-friendly)
$gitTop = & git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($gitTop)) {
    Write-Error "Ce script doit être exécuté depuis la racine d'un dépôt git (introuvable)."
    exit 2
}
$gitTop = $gitTop.Trim()
$cwd = (Get-Item -Path .).FullName
# Normaliser les séparateurs et comparer en insensible à la casse
$norm = { param($p) (Resolve-Path -LiteralPath $p).ProviderPath.TrimEnd('\') }
try { $gitTopNorm = & $norm $gitTop; $cwdNorm = & $norm $cwd } catch { $gitTopNorm = $gitTop; $cwdNorm = $cwd }
if (-not ($gitTopNorm.Equals($cwdNorm, [System.StringComparison]::InvariantCultureIgnoreCase))) {
    Write-Error "Ce script doit être exécuté depuis la racine d'un dépôt git. Chemin courant : $cwdNorm ; racine git détectée : $gitTopNorm"
    exit 2
}

# Récupérer la liste des fichiers suivis par git
$filesRaw = git ls-files -z
if ([string]::IsNullOrEmpty($filesRaw)) { Write-Log 'Aucun fichier suivi par git trouvé.'; exit 0 }
$files = $filesRaw -split "\0" | Where-Object { $_ -ne '' }

$changed = New-Object System.Collections.Generic.List[string]
$chmodMarked = New-Object System.Collections.Generic.List[string]
$createdBackups = New-Object System.Collections.Generic.List[string]

foreach ($f in $files) {
    if (-not (Test-Path -LiteralPath $f -PathType Leaf -ErrorAction SilentlyContinue)) { continue }
    # Lire les octets du fichier
    try { $bytes = [System.IO.File]::ReadAllBytes($f) } catch { Write-Warning "Ne peut pas lire $f : $_"; continue }
    # Ignorer les fichiers binaires qui contiennent un octet nul
    if ($bytes -contains 0) { continue }

    # Détecter présence CRLF (0x0D 0x0A)
    $hasCRLF = $false
    for ($i=0; $i -lt ($bytes.Length - 1); $i++) { if ($bytes[$i] -eq 13 -and $bytes[$i+1] -eq 10) { $hasCRLF = $true; break } }
    if (-not $hasCRLF) { continue }

    $relPath = $f
    if (-not $Apply) { Write-Log "[DRY] Would normalize EOL: $relPath"; continue }

    # Créer la sauvegarde
    $backup = "$f$BackupSuffix"
    $backupExisted = Test-Path -LiteralPath $backup
    try { Copy-Item -LiteralPath $f -Destination $backup -Force } catch { Write-Warning "Impossible de créer la sauvegarde $backup" }
    if (-not $backupExisted) { $createdBackups.Add($backup) }

    # Convertir CRLF -> LF
    $out = New-Object System.Collections.Generic.List[byte]
    $idx = 0
    while ($idx -lt $bytes.Length) {
        if ($idx -lt ($bytes.Length - 1) -and $bytes[$idx] -eq 13 -and $bytes[$idx+1] -eq 10) { $out.Add(10) | Out-Null; $idx += 2 } else { $out.Add($bytes[$idx]) | Out-Null; $idx++ }
    }
    try { [System.IO.File]::WriteAllBytes($f, $out.ToArray()); Write-Log "Normalized: $relPath"; $changed.Add($relPath) } catch { Write-Warning "Échec écriture $f : $_"; continue }

    # Vérifier le shebang (premières bytes -> texte) et marquer exécutable si demandé
    try {
        $peek = if ($bytes.Length -gt 2048) { $bytes[0..2047] } else { $bytes }
        $firstStr = [System.Text.Encoding]::UTF8.GetString($peek)
    } catch { $firstStr = '' }
    if ($firstStr.StartsWith('#!')) {
        if ($SetGitExecutable) {
            try { git update-index --add --chmod=+x -- "$f" 2>$null; Write-Log "Marked +x in git index: $relPath"; $chmodMarked.Add($relPath) } catch { Write-Warning "Impossible de marquer +x pour $relPath" }
        } else {
            Write-Log "Note: $relPath commence par shebang. Relancer avec -SetGitExecutable pour marquer exécutable dans git." 
        }
    }
}

if (-not $Apply) { 
    Write-Log 'Dry-run complete. Rerun without -DryRun to apply.' 
} else { 
    Write-Log "Applied normalization: $($changed.Count) files modified, $($chmodMarked.Count) files marked +x in git index." 
    # Supprimer les sauvegardes .bak créées par ce script
    if ($createdBackups.Count -gt 0) {
        foreach ($b in $createdBackups) {
            try { Remove-Item -LiteralPath $b -Force -ErrorAction Stop; Write-Log "Removed backup: $b" } catch { Write-Warning "Failed to remove backup $b : $_" }
        }
    }
}

exit 0

