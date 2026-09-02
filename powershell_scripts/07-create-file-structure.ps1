# ============================================================
# 07-create-file-structure.ps1
#
# Erstellt die Verzeichnisstruktur für den Fileserver.
#
# Die benötigten Klassenordner werden automatisch aus den
# vorhandenen AD-Klassengruppen GG_Klasse_* abgeleitet.
#
# Das Skript ist idempotent und kann mehrfach ausgeführt werden.
# ============================================================

Import-Module ActiveDirectory

$ShareRoot = "C:\Shares"

# ------------------------------------------------------------
# Überschrift
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Erstelle Fileserver-Verzeichnisstruktur ==="
Write-Output ""

# ------------------------------------------------------------
# Klassen aus dem AD ermitteln
# ------------------------------------------------------------

Write-Output "=== Klassen aus dem AD ermitteln ==="
Write-Output ""

try {

    $ClassGroups = Get-ADGroup `
        -Filter 'Name -like "GG_Klasse_*"' `
        -ErrorAction Stop

}
catch {

    Write-Output "[ABBRUCH] Klassengruppen konnten nicht aus dem AD gelesen werden:"
    Write-Output "         $($_.Exception.Message)"
    exit 1
}

$Classes = @()

foreach ($Group in $ClassGroups) {

    if ($Group.Name -match '^GG_Klasse_(.+)$') {

        $Classes += $Matches[1]
    }
}

$Classes = $Classes |
    Sort-Object -Unique

if ($Classes.Count -eq 0) {

    Write-Output "[WARNUNG] Keine Klassengruppen gefunden."
    Write-Output "[INFO] Es werden keine Klassenordner erstellt."

}
else {

    Write-Output "[OK] $($Classes.Count) Klassen gefunden:"

    foreach ($Class in $Classes) {

        Write-Output "     - $Class"
    }
}

# ------------------------------------------------------------
# Verzeichnisse bestimmen
# ------------------------------------------------------------

$Directories = @(
    $ShareRoot,
    "$ShareRoot\Schueler",
    "$ShareRoot\Klassen",
    "$ShareRoot\Lehrer",
    "$ShareRoot\Verwaltung"
)

foreach ($Class in $Classes) {

    $Directories += "$ShareRoot\Klassen\$Class"
}

# ------------------------------------------------------------
# Verzeichnisse erstellen
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Verzeichnisse erstellen ==="
Write-Output ""

foreach ($Directory in $Directories) {

    if (Test-Path $Directory) {

        Write-Output "[VORHANDEN] $Directory"
    }
    else {

        try {

            New-Item `
                -Path $Directory `
                -ItemType Directory `
                -ErrorAction Stop |
                Out-Null

            Write-Output "[ERSTELLT]  $Directory"
        }
        catch {

            Write-Output "[FEHLER] Verzeichnis konnte nicht erstellt werden:"
            Write-Output "         $Directory"
            Write-Output "         $($_.Exception.Message)"
        }
    }
}

# ------------------------------------------------------------
# Diagnose
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Verzeichnisstruktur ==="
Write-Output ""

if (Test-Path $ShareRoot) {

    Get-ChildItem `
        -Path $ShareRoot `
        -Directory `
        -Recurse |
        Select-Object FullName
}

# ------------------------------------------------------------
# Abschluss
# ------------------------------------------------------------

Write-Output ""
Write-Output "Fileserver-Verzeichnisstruktur abgeschlossen."