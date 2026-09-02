# ============================================================
# 08-cleanup-file-structure
#
# Prüft die Klassenordner auf dem Fileserver gegen die aktuell
# in der validierten CSV verwendeten Klassen.
#
# Sicherheitsprinzip:
# - Aktuelle Klassen bleiben erhalten.
# - Veraltete Klassenordner werden erkannt.
# - Leere veraltete Klassenordner werden automatisch gelöscht.
# - Veraltete Klassenordner mit Inhalt werden NICHT gelöscht.
#
# Das Skript ist idempotent und kann mehrfach ausgeführt werden.
# ============================================================

# ------------------------------------------------------------
# Konfiguration
# ------------------------------------------------------------

$ShareRoot = "C:\Shares"
$ClassesRoot = Join-Path $ShareRoot "Klassen"

# ------------------------------------------------------------
# Überschrift
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Klassenordner bereinigen ==="
Write-Output ""

# ------------------------------------------------------------
# Pfad zur validierten CSV
# ------------------------------------------------------------

$CsvPath = Read-Host "Pfad zur validierten CSV-Datei"

if (-not (Test-Path $CsvPath -PathType Leaf)) {

    Write-Output ""
    Write-Output "[ABBRUCH] Validierte CSV-Datei wurde nicht gefunden:"
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
    Write-Output "[ABBRUCH] CSV-Datei enthaelt keine Datensaetze."

    exit 1
}

Write-Output "[OK] $($Users.Count) Datensaetze eingelesen."

# ------------------------------------------------------------
# CSV-Struktur prüfen
# ------------------------------------------------------------

$RequiredColumns = @(
    "BenutzerTyp",
    "Klassen"
)

$MissingColumns = @()
$CsvColumns = $Users[0].PSObject.Properties.Name

foreach ($Column in $RequiredColumns) {

    if ($CsvColumns -notcontains $Column) {

        $MissingColumns += $Column
    }
}

if ($MissingColumns.Count -gt 0) {

    Write-Output ""
    Write-Output "[ABBRUCH] Folgende Spalten fehlen in der CSV:"

    foreach ($Column in $MissingColumns) {

        Write-Output "         - $Column"
    }

    exit 1
}

Write-Output "[OK] CSV-Struktur ist vollstaendig."

# ------------------------------------------------------------
# Fileserver-Verzeichnis prüfen
# ------------------------------------------------------------

if (-not (Test-Path $ClassesRoot -PathType Container)) {

    Write-Output ""
    Write-Output "[ABBRUCH] Klassenverzeichnis existiert nicht:"
    Write-Output "         $ClassesRoot"

    exit 1
}

# ------------------------------------------------------------
# Aktuelle Klassen aus der CSV ermitteln
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

            $CurrentClasses += $Klasse
        }
    }
}

$CurrentClasses = $CurrentClasses |
    Sort-Object -Unique

if ($CurrentClasses.Count -gt 0) {

    Write-Output "[OK] Aktuell verwendete Klassen:"

    foreach ($Klasse in $CurrentClasses) {

        Write-Output "      - $Klasse"
    }

}
else {

    Write-Output "[HINWEIS] Keine Klassen werden aktuell verwendet."
}

# ------------------------------------------------------------
# Vorhandene Klassenordner ermitteln
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Vorhandene Klassenordner pruefen ==="
Write-Output ""

$ExistingClassFolders = Get-ChildItem `
    -Path $ClassesRoot `
    -Directory `
    -ErrorAction Stop |
    Select-Object -ExpandProperty Name

if ($ExistingClassFolders.Count -gt 0) {

    Write-Output "[OK] Vorhandene Klassenordner:"

    foreach ($Folder in ($ExistingClassFolders | Sort-Object)) {

        Write-Output "      - $Folder"
    }

}
else {

    Write-Output "[HINWEIS] Keine Klassenordner vorhanden."
}

# ------------------------------------------------------------
# Veraltete Klassenordner bestimmen
# ------------------------------------------------------------

$ObsoleteFolders = @()

foreach ($Folder in $ExistingClassFolders) {

    if ($CurrentClasses -notcontains $Folder) {

        $ObsoleteFolders += $Folder
    }
}

Write-Output ""
Write-Output "=== Veraltete Klassenordner ==="
Write-Output ""

if ($ObsoleteFolders.Count -eq 0) {

    Write-Output "[OK] Keine veralteten Klassenordner gefunden."

}
else {

    foreach ($Folder in ($ObsoleteFolders | Sort-Object)) {

        $FolderPath = Join-Path $ClassesRoot $Folder

        Write-Output "--- $Folder ---"
        Write-Output "Pfad: $FolderPath"

        # ----------------------------------------------------
        # Prüfen, ob der Ordner leer ist
        # ----------------------------------------------------

        $Contents = Get-ChildItem `
            -Path $FolderPath `
            -Force `
            -ErrorAction Stop

        if ($Contents.Count -eq 0) {

            try {

                Remove-Item `
                    -Path $FolderPath `
                    -Force `
                    -ErrorAction Stop

                Write-Output "[GELOESCHT] Leerer veralteter Klassenordner."

            }
            catch {

                Write-Output "[FEHLER] Klassenordner konnte nicht geloescht werden."
                Write-Output "         $($_.Exception.Message)"
            }

        }
        else {

            Write-Output "[WARNUNG] Klassenordner enthaelt noch Daten."
            Write-Output "[NICHT GELOESCHT] $FolderPath"

            Write-Output ""
            Write-Output "Enthaltene Elemente:"

            foreach ($Item in $Contents) {

                Write-Output "         $($Item.Name)"
            }
        }

        Write-Output ""
    }
}

# ------------------------------------------------------------
# Zusammenfassung
# ------------------------------------------------------------

$RemainingClassFolders = Get-ChildItem `
    -Path $ClassesRoot `
    -Directory `
    -ErrorAction Stop

$RemainingFolderNames = $RemainingClassFolders |
    Select-Object -ExpandProperty Name

$StillObsolete = @()

foreach ($Folder in $RemainingFolderNames) {

    if ($CurrentClasses -notcontains $Folder) {

        $StillObsolete += $Folder
    }
}

Write-Output ""
Write-Output "=== Zusammenfassung ==="
Write-Output ""

Write-Output "Aktuelle Klassen:              $($CurrentClasses.Count)"
Write-Output "Vorhandene Klassenordner:      $($ExistingClassFolders.Count)"
Write-Output "Veraltete Klassenordner:       $($ObsoleteFolders.Count)"
Write-Output "Veraltete Ordner verbleibend:  $($StillObsolete.Count)"

if ($StillObsolete.Count -eq 0) {

    Write-Output ""
    Write-Output "[OK] Fileserver entspricht dem aktuellen Klassenbestand."

}
else {

    Write-Output ""
    Write-Output "[WARNUNG] Veraltete Klassenordner wurden wegen vorhandener"
    Write-Output "          Inhalte nicht geloescht."

    foreach ($Folder in ($StillObsolete | Sort-Object)) {

        Write-Output "          - $Folder"
    }
}

Write-Output ""
Write-Output "Klassenordner-Bereinigung abgeschlossen."
