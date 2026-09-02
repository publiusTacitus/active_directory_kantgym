# ============================================================
# 06-create-credential-files.ps1
#
# Erzeugt aus der temporären Credential-CSV individuelle
# Credential-Dateien für die neu erstellten Benutzer.
#
# - Ausgabe als TXT
# - Unterordner nach Benutzertyp
# - Vorhandene Dateien werden NICHT überschrieben
# - Credential-CSV wird nur bei vollständigem Erfolg gelöscht
#
# Pipeline:
#
# 01 -> Benutzerdaten-import.csv
# 02 -> Benutzerdaten-validiert.csv
# 03 -> AD-OUs
# 04 -> AD-Gruppen
# 05 -> AD-Benutzer + Gruppenmitgliedschaften
# 06 -> individuelle Credential-TXT-Dateien
# ============================================================


# ------------------------------------------------------------
# Konfiguration
# ------------------------------------------------------------

$OutputFolderName = "credentials"

$CredentialCsvFileName = "Benutzerdaten-credentials-temp.csv"

$AllowedUserTypes = @(
    "Schueler",
    "Lehrkraefte",
    "Verwaltung",
    "IT"
)


# ------------------------------------------------------------
# Überschrift
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Credential-Dateien erzeugen ==="
Write-Output ""


# ------------------------------------------------------------
# Pfad zur Credential-CSV
# ------------------------------------------------------------

$CsvPath = Read-Host "Pfad zur temporaeren Credential-CSV-Datei"

if (-not (Test-Path $CsvPath)) {

    Write-Output ""
    Write-Output "[ABBRUCH] Credential-CSV-Datei wurde nicht gefunden:"
    Write-Output "         $CsvPath"

    exit 1
}


# ------------------------------------------------------------
# CSV einlesen
# ------------------------------------------------------------

try {

    $Credentials = Import-Csv `
        -Path $CsvPath `
        -Delimiter ";" `
        -Encoding UTF8 `
        -ErrorAction Stop

}
catch {

    Write-Output ""
    Write-Output "[ABBRUCH] Credential-CSV konnte nicht eingelesen werden:"
    Write-Output "         $($_.Exception.Message)"

    exit 1
}


if (-not $Credentials) {

    Write-Output ""
    Write-Output "[ABBRUCH] Credential-CSV enthaelt keine Datensaetze."

    exit 1
}


Write-Output "[OK] $($Credentials.Count) Datensaetze eingelesen."


# ------------------------------------------------------------
# CSV-Struktur prüfen
# ------------------------------------------------------------

$RequiredColumns = @(
    "Personalnummer",
    "Vorname",
    "Nachname",
    "BenutzerTyp",
    "SamAccountName",
    "Passwort"
)

$MissingColumns = @()

$CsvColumns = $Credentials[0].PSObject.Properties.Name

foreach ($Column in $RequiredColumns) {

    if ($CsvColumns -notcontains $Column) {

        $MissingColumns += $Column
    }
}


if ($MissingColumns.Count -gt 0) {

    Write-Output ""
    Write-Output "[ABBRUCH] Folgende Spalten fehlen in der Credential-CSV:"

    foreach ($Column in $MissingColumns) {

        Write-Output "         - $Column"
    }

    exit 1
}


Write-Output "[OK] CSV-Struktur ist vollstaendig."


# ------------------------------------------------------------
# Datensätze prüfen
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Credential-Daten pruefen ==="
Write-Output ""

$ValidationErrors = @()

$UsedSamAccountNames = @{}


foreach ($Credential in $Credentials) {

    $SamAccountName = $Credential.SamAccountName


    # --------------------------------------------------------
    # Pflichtfelder
    # --------------------------------------------------------

    if ([string]::IsNullOrWhiteSpace($Credential.Personalnummer)) {

        $ValidationErrors += `
            "Leere Personalnummer bei $($Credential.Vorname) $($Credential.Nachname)"
    }


    if ([string]::IsNullOrWhiteSpace($Credential.Vorname)) {

        $ValidationErrors += `
            "Leerer Vorname bei Personalnummer $($Credential.Personalnummer)"
    }


    if ([string]::IsNullOrWhiteSpace($Credential.Nachname)) {

        $ValidationErrors += `
            "Leerer Nachname bei Personalnummer $($Credential.Personalnummer)"
    }


    if ([string]::IsNullOrWhiteSpace($SamAccountName)) {

        $ValidationErrors += `
            "Leerer SamAccountName bei Personalnummer $($Credential.Personalnummer)"
    }


    if ([string]::IsNullOrWhiteSpace($Credential.Passwort)) {

        $ValidationErrors += `
            "Leeres Passwort bei SamAccountName $SamAccountName"
    }


    # --------------------------------------------------------
    # BenutzerTyp prüfen
    # --------------------------------------------------------

    if ($Credential.BenutzerTyp -notin $AllowedUserTypes) {

        $ValidationErrors += `
            "Ungueltiger BenutzerTyp '$($Credential.BenutzerTyp)' bei SamAccountName $SamAccountName"
    }


    # --------------------------------------------------------
    # Doppelte SamAccountNames
    # --------------------------------------------------------

    if (-not [string]::IsNullOrWhiteSpace($SamAccountName)) {

        if ($UsedSamAccountNames.ContainsKey($SamAccountName)) {

            $ValidationErrors += `
                "Doppelter SamAccountName: $SamAccountName"
        }
        else {

            $UsedSamAccountNames[$SamAccountName] = $true
        }
    }
}


# ------------------------------------------------------------
# Validierung abbrechen, wenn Fehler vorhanden
# ------------------------------------------------------------

if ($ValidationErrors.Count -gt 0) {

    Write-Output "[FEHLER] Credential-Daten sind nicht vollstaendig."

    Write-Output ""

    foreach ($ErrorMessage in $ValidationErrors) {

        Write-Output "[FEHLER] $ErrorMessage"
    }

    Write-Output ""
    Write-Output "[ABBRUCH] Es wurden keine Credential-Dateien erzeugt."

    exit 1
}


Write-Output "[OK] Alle Credential-Daten sind vollstaendig und eindeutig."


# ------------------------------------------------------------
# Ausgabeordner bestimmen
# ------------------------------------------------------------

$CsvDirectory = Split-Path $CsvPath -Parent

$OutputFolder = Join-Path `
    $CsvDirectory `
    $OutputFolderName


# ------------------------------------------------------------
# Ausgabeordner erstellen
# ------------------------------------------------------------

if (-not (Test-Path $OutputFolder)) {

    try {

        New-Item `
            -Path $OutputFolder `
            -ItemType Directory `
            -ErrorAction Stop |
            Out-Null

        Write-Output "[ERSTELLT] Ausgabeordner:"
        Write-Output "           $OutputFolder"

    }
    catch {

        Write-Output ""
        Write-Output "[ABBRUCH] Ausgabeordner konnte nicht erstellt werden:"
        Write-Output "         $OutputFolder"
        Write-Output "         $($_.Exception.Message)"

        exit 1
    }

}
else {

    Write-Output "[OK] Ausgabeordner vorhanden:"
    Write-Output "     $OutputFolder"
}


# ------------------------------------------------------------
# Credential-Dateien erzeugen
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Credential-Dateien ==="
Write-Output ""

$CreatedFiles = @()

$FailedFiles = @()

$SkippedFiles = @()


foreach ($Credential in $Credentials) {

    $Personalnummer = $Credential.Personalnummer.Trim()

    $SamAccountName = $Credential.SamAccountName.Trim()

    $BenutzerTyp = $Credential.BenutzerTyp.Trim()


    Write-Output "--- $SamAccountName ---"


    # --------------------------------------------------------
    # Unterordner nach Benutzertyp
    # --------------------------------------------------------

    $TypeFolder = Join-Path `
        $OutputFolder `
        $BenutzerTyp


    if (-not (Test-Path $TypeFolder)) {

        try {

            New-Item `
                -Path $TypeFolder `
                -ItemType Directory `
                -ErrorAction Stop |
                Out-Null

            Write-Output "[ERSTELLT] Unterordner:"
            Write-Output "           $TypeFolder"

        }
        catch {

            Write-Output "[FEHLER] Unterordner konnte nicht erstellt werden:"
            Write-Output "         $TypeFolder"
            Write-Output "         $($_.Exception.Message)"

            $FailedFiles += $Credential

            continue
        }

    }


    # --------------------------------------------------------
    # Dateiname
    # --------------------------------------------------------

    $FileName = "${Personalnummer}_${SamAccountName}.txt"


    $OutputPath = Join-Path `
        $TypeFolder `
        $FileName


    # --------------------------------------------------------
    # Vorhandene Datei schützen
    # --------------------------------------------------------

    if (Test-Path $OutputPath) {

        Write-Output "[UEBERSPRUNGEN] Datei existiert bereits:"
        Write-Output "               $OutputPath"

        $SkippedFiles += $Credential

        continue
    }


    # --------------------------------------------------------
    # Inhalt erzeugen
    # --------------------------------------------------------

    $Content = @"
Kant-Gymnasium
Benutzerkonto

========================================================

Personalnummer: $Personalnummer
Name: $($Credential.Vorname) $($Credential.Nachname)
Benutzername: $SamAccountName
Benutzertyp: $BenutzerTyp

Temporäres Passwort: $($Credential.Passwort)

========================================================

Hinweis:

Dies ist ein temporäres Erstpasswort.
Beim ersten Anmelden muss das Passwort geändert werden.

========================================================
"@


    # --------------------------------------------------------
    # Datei schreiben
    # --------------------------------------------------------

    try {

        Set-Content `
            -Path $OutputPath `
            -Value $Content `
            -Encoding UTF8 `
            -ErrorAction Stop

        Write-Output "[ERSTELLT] $FileName"

        $CreatedFiles += $Credential

    }
    catch {

        Write-Output "[FEHLER] Datei konnte nicht erstellt werden:"
        Write-Output "         $OutputPath"
        Write-Output "         $($_.Exception.Message)"

        $FailedFiles += $Credential
    }
}


# ------------------------------------------------------------
# Zusammenfassung
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Zusammenfassung ==="
Write-Output ""

Write-Output "Datensaetze:            $($Credentials.Count)"
Write-Output "Dateien erstellt:      $($CreatedFiles.Count)"
Write-Output "Dateien uebersprungen: $($SkippedFiles.Count)"
Write-Output "Dateifehler:           $($FailedFiles.Count)"


# ------------------------------------------------------------
# Fehlerdetails
# ------------------------------------------------------------

if ($FailedFiles.Count -gt 0) {

    Write-Output ""
    Write-Output "=== Dateien mit Fehlern ==="
    Write-Output ""

    foreach ($Credential in $FailedFiles) {

        Write-Output "[FEHLER] $($Credential.Personalnummer)_$($Credential.SamAccountName).txt"
    }
}


# ------------------------------------------------------------
# Übersprungene Dateien
# ------------------------------------------------------------

if ($SkippedFiles.Count -gt 0) {

    Write-Output ""
    Write-Output "=== Bereits vorhandene Dateien ==="
    Write-Output ""

    foreach ($Credential in $SkippedFiles) {

        Write-Output "[UEBERSPRUNGEN] $($Credential.Personalnummer)_$($Credential.SamAccountName).txt"
    }
}


# ------------------------------------------------------------
# Credential-CSV nur bei vollständigem Erfolg löschen
# ------------------------------------------------------------

Write-Output ""

if (
    $FailedFiles.Count -eq 0 -and
    $SkippedFiles.Count -eq 0 -and
    $CreatedFiles.Count -eq $Credentials.Count
) {

    Write-Output "[OK] Alle Credential-Dateien wurden erfolgreich erstellt."

    Write-Output ""
    Write-Output "=== Temporaere Credential-Datei ==="
    Write-Output ""

    try {

        Remove-Item `
            -Path $CsvPath `
            -Force `
            -ErrorAction Stop

        Write-Output "[GELOESCHT] Temporaere Credential-CSV:"
        Write-Output "           $CsvPath"

    }
    catch {

        Write-Output "[WARNUNG] Credential-Dateien wurden erfolgreich erstellt,"
        Write-Output "          aber die temporaere Credential-CSV konnte nicht geloescht werden."
        Write-Output "          $($_.Exception.Message)"

        Write-Output ""
        Write-Output "[WICHTIG] Die Credential-CSV enthaelt weiterhin Passwoerter."
        Write-Output "          Bitte nach erfolgreicher Kontrolle manuell loeschen."
    }

    Write-Output ""
    Write-Output "Ausgabeordner:"
    Write-Output $OutputFolder
}
elseif ($SkippedFiles.Count -gt 0 -and $FailedFiles.Count -eq 0) {

    Write-Output "[HINWEIS] Nicht alle Dateien wurden neu erstellt."
    Write-Output "[INFO] Bereits vorhandene Dateien wurden nicht ueberschrieben."
    Write-Output ""
    Write-Output "[SICHERHEIT] Die temporaere Credential-CSV wurde NICHT geloescht."
    Write-Output ""
    Write-Output "Bitte Ursache pruefen und die Verarbeitung erst danach erneut ausfuehren."
}
else {

    Write-Output "[WARNUNG] Nicht alle Credential-Dateien konnten erstellt werden."
    Write-Output ""
    Write-Output "[SICHERHEIT] Die temporaere Credential-CSV wurde NICHT geloescht."
    Write-Output ""
    Write-Output "Bitte Fehler beheben und die Verarbeitung anschliessend erneut ausfuehren."
}
