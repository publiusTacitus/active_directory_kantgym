# ============================================================
# 01-convert-user-import.ps1
#
# Konvertiert die Excel-Benutzerdaten in eine einheitliche CSV.
#
# Eingabe:
#   Excel-Datei mit den Sheets:
#   - Schueler
#   - Lehrkraefte
#   - Verwaltung
#   - IT
#
# Ausgabe:
#   CSV mit den Spalten:
#   Personalnummer;Vorname;Nachname;BenutzerTyp;Klassen
#
# Dieses Skript nimmt keine Änderungen im Active Directory vor.
# ============================================================

# ------------------------------------------------------------
# Konfiguration
# ------------------------------------------------------------

$RequiredSheets = @(
    "Schueler",
    "Lehrkraefte",
    "Verwaltung",
    "IT"
)

$RequiredColumns = @(
    "Personalnummer",
    "Vorname",
    "Nachname",
    "BenutzerTyp",
    "Klassen"
)

# ------------------------------------------------------------
# Excel-Modul prüfen
# ------------------------------------------------------------

if (-not (Get-Module -ListAvailable -Name ImportExcel)) {

    Write-Output "[FEHLER] Das PowerShell-Modul 'ImportExcel' ist nicht installiert."
    Write-Output "        Installation mit:"
    Write-Output "        Install-Module ImportExcel -Scope CurrentUser"

    exit 1
}

Import-Module ImportExcel

# ------------------------------------------------------------
# Eingabedatei
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Benutzerdaten aus Excel konvertieren ==="
Write-Output ""

$ExcelPath = Read-Host "Pfad zur Excel-Datei eingeben"

if (-not (Test-Path $ExcelPath -PathType Leaf)) {

    Write-Output "[FEHLER] Datei wurde nicht gefunden:"
    Write-Output "        $ExcelPath"

    exit 1
}

# ------------------------------------------------------------
# Excel-Arbeitsmappe prüfen
# ------------------------------------------------------------

try {
    $Workbook = Open-ExcelPackage -Path $ExcelPath -ErrorAction Stop
}
catch {

    Write-Output "[FEHLER] Excel-Datei konnte nicht geöffnet werden."
    Write-Output "        $($_.Exception.Message)"

    exit 1
}

$AvailableSheets = $Workbook.Workbook.Worksheets.Name

Write-Output ""
Write-Output "Vorhandene Worksheets:"
foreach ($Sheet in $AvailableSheets) {
    Write-Output "  - $Sheet"
}

# ------------------------------------------------------------
# Benötigte Worksheets prüfen
# ------------------------------------------------------------

foreach ($SheetName in $RequiredSheets) {

    if ($AvailableSheets -notcontains $SheetName) {

        Write-Output ""
        Write-Output "[FEHLER] Benötigtes Worksheet fehlt: $SheetName"

        Close-ExcelPackage $Workbook -NoSave

        exit 1
    }
}

# ------------------------------------------------------------
# Daten einlesen
# ------------------------------------------------------------

$AllUsers = @()

foreach ($SheetName in $RequiredSheets) {

    Write-Output ""
    Write-Output "--- Worksheet: $SheetName ---"

    try {

        $Rows = Import-Excel `
            -Path $ExcelPath `
            -WorksheetName $SheetName `
            -ErrorAction Stop

    }
    catch {

        Write-Output "[FEHLER] Worksheet konnte nicht eingelesen werden:"
        Write-Output "        $SheetName"
        Write-Output "        $($_.Exception.Message)"

        Close-ExcelPackage $Workbook -NoSave

        exit 1
    }

    if (-not $Rows) {

        Write-Output "[INFO] Worksheet enthält keine Datensaetze."
        continue
    }

    # --------------------------------------------------------
    # Spalten prüfen
    # --------------------------------------------------------

    $ActualColumns = @(
        $Rows[0].PSObject.Properties.Name
    )

    foreach ($Column in $RequiredColumns) {

        if ($ActualColumns -notcontains $Column) {

            Write-Output "[FEHLER] Spalte '$Column' fehlt in Worksheet '$SheetName'."

            Close-ExcelPackage $Workbook -NoSave

            exit 1
        }
    }

    Write-Output "[OK] $($Rows.Count) Datensaetze eingelesen."

    # --------------------------------------------------------
    # Nur benötigte Spalten übernehmen
    # --------------------------------------------------------

    foreach ($Row in $Rows) {

        $AllUsers += [PSCustomObject]@{
            Personalnummer = $Row.Personalnummer
            Vorname        = $Row.Vorname
            Nachname       = $Row.Nachname
            BenutzerTyp    = $Row.BenutzerTyp
            Klassen        = $Row.Klassen
        }
    }
}

Close-ExcelPackage $Workbook -NoSave

# ------------------------------------------------------------
# Leere Zeilen entfernen
# ------------------------------------------------------------

$AllUsers = @(
    $AllUsers | Where-Object {
        $_.Personalnummer -or
        $_.Vorname -or
        $_.Nachname
    }
)

Write-Output ""
Write-Output "=== Zusammenfassung ==="
Write-Output "Datensaetze insgesamt: $($AllUsers.Count)"

# ------------------------------------------------------------
# Ausgabedatei
# ------------------------------------------------------------

$ExcelDirectory = Split-Path $ExcelPath -Parent
$ExcelName = [System.IO.Path]::GetFileNameWithoutExtension($ExcelPath)

$CsvPath = Join-Path `
    $ExcelDirectory `
    "$ExcelName-import.csv"

# ------------------------------------------------------------
# CSV erzeugen
# ------------------------------------------------------------

try {

    $AllUsers |
        Export-Csv `
            -Path $CsvPath `
            -Delimiter ";" `
            -Encoding UTF8 `
            -NoTypeInformation `
            -Force `
            -ErrorAction Stop

    Write-Output ""
    Write-Output "[ERSTELLT] CSV-Datei:"
    Write-Output "           $CsvPath"
}
catch {

    Write-Output ""
    Write-Output "[FEHLER] CSV-Datei konnte nicht erstellt werden."
    Write-Output "        $($_.Exception.Message)"

    exit 1
}

# ------------------------------------------------------------
# Abschluss
# ------------------------------------------------------------

Write-Output ""
Write-Output "Konvertierung abgeschlossen."