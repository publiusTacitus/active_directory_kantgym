# ============================================================
# 12-cleanup-old-class-shares.ps1
#
# Prüft SMB-Freigaben und Klassenordner auf veraltete Klassen
# und entfernt diese nach ausdrücklicher Bestätigung.
#
# Die aktuell verwendeten Klassen werden aus der validierten
# Benutzerdaten-CSV ermittelt.
#
# Das Skript betrifft ausschließlich Klassenfreigaben.
# Die festen Freigaben Schueler, Lehrer und Verwaltung werden
# nicht verändert.
# ============================================================

Import-Module ActiveDirectory

# ------------------------------------------------------------
# Konfiguration
# ------------------------------------------------------------

$ShareRoot = "C:\Shares"
$ClassFolderRoot = Join-Path $ShareRoot "Klassen"

$FixedShares = @(
    "Schueler",
    "Lehrer",
    "Verwaltung"
)

# ------------------------------------------------------------
# Überschrift
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Veraltete Klassenfreigaben bereinigen ==="
Write-Output ""

# ------------------------------------------------------------
# Validierte CSV auswählen
# ------------------------------------------------------------

$CsvPath = Read-Host "Pfad zur validierten CSV-Datei"

if (-not (Test-Path $CsvPath)) {

    Write-Output ""
    Write-Output "[ABBRUCH] CSV-Datei wurde nicht gefunden:"
    Write-Output "         $CsvPath"
    exit 1
}

# ------------------------------------------------------------
# CSV einlesen
# ------------------------------------------------------------

try {

    $Users = Import-Csv `
        -Path $CsvPath `
        -Delimiter ";" `
        -Encoding UTF8 `
        -ErrorAction Stop
}
catch {

    Write-Output ""
    Write-Output "[ABBRUCH] CSV-Datei konnte nicht eingelesen werden:"
    Write-Output "         $($_.Exception.Message)"
    exit 1
}

if (-not $Users) {

    Write-Output ""
    Write-Output "[ABBRUCH] CSV-Datei enthält keine Datensätze."
    exit 1
}

Write-Output "[OK] $($Users.Count) Datensätze eingelesen."

# ------------------------------------------------------------
# CSV-Struktur prüfen
# ------------------------------------------------------------

$RequiredColumns = @(
    "BenutzerTyp",
    "Klassen"
)

$MissingColumns = @()

foreach ($Column in $RequiredColumns) {

    if ($Users[0].PSObject.Properties.Name -notcontains $Column) {

        $MissingColumns += $Column
    }
}

if ($MissingColumns.Count -gt 0) {

    Write-Output ""
    Write-Output "[ABBRUCH] Folgende Spalten fehlen:"

    foreach ($Column in $MissingColumns) {

        Write-Output "         - $Column"
    }

    exit 1
}

Write-Output "[OK] CSV-Struktur ist vollständig."

# ------------------------------------------------------------
# Aktuelle Klassen ermitteln
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Aktuelle Klassen ermitteln ==="
Write-Output ""

$CurrentClasses = @()

foreach ($User in $Users) {

    if ([string]::IsNullOrWhiteSpace($User.Klassen)) {
        continue
    }

    foreach ($Klasse in ($User.Klassen -split "\|")) {

        $Klasse = $Klasse.Trim()

        if (-not [string]::IsNullOrWhiteSpace($Klasse)) {

            if ($CurrentClasses -notcontains $Klasse) {

                $CurrentClasses += $Klasse
            }
        }
    }
}

$CurrentClasses = $CurrentClasses | Sort-Object

if ($CurrentClasses.Count -gt 0) {

    Write-Output "[OK] Aktuell verwendete Klassen:"

    foreach ($Klasse in $CurrentClasses) {

        Write-Output "      - $Klasse"
    }
}
else {

    Write-Output "[INFO] In der CSV wurden keine Klassen gefunden."
}

# ------------------------------------------------------------
# Vorhandene Klassenordner ermitteln
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Vorhandene Klassenordner prüfen ==="
Write-Output ""

if (-not (Test-Path $ClassFolderRoot -PathType Container)) {

    Write-Output "[INFO] Klassenordner existiert nicht:"
    Write-Output "      $ClassFolderRoot"

    Write-Output ""
    Write-Output "Bereinigungskontrolle abgeschlossen."
    exit 0
}

$ExistingClassFolders = Get-ChildItem `
    -Path $ClassFolderRoot `
    -Directory `
    -ErrorAction Stop |
    Select-Object -ExpandProperty Name |
    Sort-Object

if ($ExistingClassFolders.Count -gt 0) {

    Write-Output "[OK] Vorhandene Klassenordner:"

    foreach ($Klasse in $ExistingClassFolders) {

        Write-Output "      - $Klasse"
    }
}
else {

    Write-Output "[INFO] Keine Klassenordner vorhanden."
}

# ------------------------------------------------------------
# Veraltete Klassen ermitteln
# ------------------------------------------------------------

$ObsoleteClasses = @()

foreach ($Klasse in $ExistingClassFolders) {

    if ($CurrentClasses -notcontains $Klasse) {

        $ObsoleteClasses += $Klasse
    }
}

# ------------------------------------------------------------
# Veraltete Klassen anzeigen
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Veraltete Klassen ==="
Write-Output ""

if ($ObsoleteClasses.Count -eq 0) {

    Write-Output "[OK] Keine veralteten Klassen gefunden."

    Write-Output ""
    Write-Output "=== Zusammenfassung ==="
    Write-Output ""

    Write-Output "Aktuelle Klassen:       $($CurrentClasses.Count)"
    Write-Output "Vorhandene Ordner:      $($ExistingClassFolders.Count)"
    Write-Output "Veraltete Klassen:      0"

    Write-Output ""
    Write-Output "[OK] Fileserver entspricht dem aktuellen Klassenbestand."
    Write-Output ""
    Write-Output "Bereinigungskontrolle abgeschlossen."

    exit 0
}

Write-Output "[WARNUNG] Folgende Klassen sind nicht mehr aktuell:"

foreach ($Klasse in $ObsoleteClasses) {

    Write-Output "      - $Klasse"
}

# ------------------------------------------------------------
# Zugehörige SMB-Freigaben prüfen
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Zugehörige SMB-Freigaben ==="
Write-Output ""

$ObsoleteShares = @()

foreach ($Klasse in $ObsoleteClasses) {

    $ShareName = "Klasse_$Klasse"

    $ExistingShare = Get-SmbShare `
        -Name $ShareName `
        -ErrorAction SilentlyContinue

    if ($ExistingShare) {

        $ObsoleteShares += $ExistingShare

        Write-Output "[GEFUNDEN] SMB-Freigabe: $ShareName"
        Write-Output "           Pfad: $($ExistingShare.Path)"
    }
    else {

        Write-Output "[NICHT VORHANDEN] SMB-Freigabe: $ShareName"
    }
}

# ------------------------------------------------------------
# Sicherheitskontrolle
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Sicherheitskontrolle ==="
Write-Output ""

Write-Output "Folgende Klassen werden als veraltet erkannt:"

foreach ($Klasse in $ObsoleteClasses) {

    Write-Output "  - $Klasse"
}

Write-Output ""
Write-Output "Das Skript kann für diese Klassen:"
Write-Output "  1. die SMB-Freigabe entfernen"
Write-Output "  2. den Klassenordner entfernen"
Write-Output ""
Write-Output "ACHTUNG: Dabei werden auch die Dateien innerhalb dieser"
Write-Output "Klassenordner gelöscht."
Write-Output ""

$Confirmation = Read-Host "Zum Fortfahren exakt JA eingeben"

if ($Confirmation -cne "JA") {

    Write-Output ""
    Write-Output "[ABBRUCH] Keine Änderungen vorgenommen."
    Write-Output ""
    Write-Output "Bereinigungskontrolle abgeschlossen."

    exit 0
}

# ------------------------------------------------------------
# Bereinigung
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Bereinigung durchführen ==="
Write-Output ""

$RemovedShares = @()
$RemovedFolders = @()
$FailedCleanup = @()

foreach ($Klasse in $ObsoleteClasses) {

    $ShareName = "Klasse_$Klasse"
    $FolderPath = Join-Path $ClassFolderRoot $Klasse

    Write-Output "--- Klasse $Klasse ---"

    # --------------------------------------------------------
    # SMB-Freigabe entfernen
    # --------------------------------------------------------

    $ExistingShare = Get-SmbShare `
        -Name $ShareName `
        -ErrorAction SilentlyContinue

    if ($ExistingShare) {

        try {

            Remove-SmbShare `
                -Name $ShareName `
                -Force `
                -ErrorAction Stop

            Write-Output "[ENTFERNT] SMB-Freigabe: $ShareName"

            $RemovedShares += $ShareName
        }
        catch {

            Write-Output "[FEHLER] SMB-Freigabe konnte nicht entfernt werden:"
            Write-Output "         $ShareName"
            Write-Output "         $($_.Exception.Message)"

            $FailedCleanup += $Klasse
        }
    }
    else {

        Write-Output "[NICHT VORHANDEN] SMB-Freigabe: $ShareName"
    }

    # --------------------------------------------------------
    # Klassenordner entfernen
    # --------------------------------------------------------

    if (Test-Path $FolderPath -PathType Container) {

        try {

            Remove-Item `
                -Path $FolderPath `
                -Recurse `
                -Force `
                -ErrorAction Stop

            Write-Output "[ENTFERNT] Klassenordner: $FolderPath"

            $RemovedFolders += $Klasse
        }
        catch {

            Write-Output "[FEHLER] Klassenordner konnte nicht entfernt werden:"
            Write-Output "         $FolderPath"
            Write-Output "         $($_.Exception.Message)"

            if ($FailedCleanup -notcontains $Klasse) {

                $FailedCleanup += $Klasse
            }
        }
    }
    else {

        Write-Output "[NICHT VORHANDEN] Klassenordner: $FolderPath"
    }

    Write-Output ""
}

# ------------------------------------------------------------
# Diagnose
# ------------------------------------------------------------

Write-Output "=== Zusammenfassung ==="
Write-Output ""

Write-Output "Aktuelle Klassen:        $($CurrentClasses.Count)"
Write-Output "Vorhandene Ordner:       $($ExistingClassFolders.Count)"
Write-Output "Veraltete Klassen:       $($ObsoleteClasses.Count)"
Write-Output "Freigaben entfernt:      $($RemovedShares.Count)"
Write-Output "Ordner entfernt:         $($RemovedFolders.Count)"
Write-Output "Bereinigungsfehler:      $($FailedCleanup.Count)"

Write-Output ""

if ($FailedCleanup.Count -eq 0) {

    Write-Output "[OK] Bereinigung erfolgreich abgeschlossen."
}
else {

    Write-Output "[WARNUNG] Nicht alle veralteten Klassen konnten vollständig entfernt werden."

    Write-Output ""
    Write-Output "Betroffene Klassen:"

    foreach ($Klasse in $FailedCleanup) {

        Write-Output "  - $Klasse"
    }
}

Write-Output ""
Write-Output "=== Verbleibende Klassenfreigaben ==="
Write-Output ""

Get-SmbShare |
    Where-Object {
        $_.Name -like "Klasse_*" -and
        $_.Path -like "$ClassFolderRoot\*"
    } |
    Select-Object Name, Path |
    Sort-Object Name |
    Format-Table -AutoSize |
    Out-String |
    Write-Output

Write-Output ""
Write-Output "Bereinigung der Klassenfreigaben abgeschlossen."
