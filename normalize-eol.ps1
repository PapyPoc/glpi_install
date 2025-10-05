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
    [switch]$SetGitExecutable,
    [string]$BackupSuffix = '.bak'
)

function Write-Log { param([string]$m) Write-Host $m }

# Le script applique par défaut; si -DryRun fourni, il simule
$Apply = -not $DryRun

# Vérifier qu'on est dans un dépôt git
try { git rev-parse --git-dir >/dev/null 2>&1 } catch { Write-Error 'Ce script doit être exécuté depuis la racine d\''un dépôt git.'; exit 2 }

# Récupérer la liste des fichiers suivis par git
$filesRaw = git ls-files -z
if ([string]::IsNullOrEmpty($filesRaw)) { Write-Log 'Aucun fichier suivi par git trouvé.'; exit 0 }
$files = $filesRaw -split "\0" | Where-Object { $_ -ne '' }

$changed = New-Object System.Collections.Generic.List[string]
$chmodMarked = New-Object System.Collections.Generic.List[string]

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
    try { Copy-Item -LiteralPath $f -Destination $backup -Force } catch { Write-Warning "Impossible de créer la sauvegarde $backup" }

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

if (-not $Apply) { Write-Log 'Dry-run complete. Rerun without -DryRun to apply.' } else { Write-Log "Applied normalization: $($changed.Count) files modified, $($chmodMarked.Count) files marked +x in git index." }

exit 0

