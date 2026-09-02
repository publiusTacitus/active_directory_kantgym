# ============================================================
# 02-validate-user-import.ps1
#
# Validiert den vorbereiteten Benutzerimport und erzeugt
# eindeutige Vorschlaege fuer die Accountnamen.
#
# Keine Änderungen am Active Directory.
# ============================================================

Import-Module ActiveDirectory

# ------------------------------------------------------------
# Konfiguration
# ------------------------------------------------------------

$CsvPath = Read-Host "Pfad zur Import-CSV"

if (-not (Test-Path $CsvPath)) {
    Write-Output "[FEHLER] CSV-Datei nicht gefunden: $CsvPath"
    exit 1
}

$AllowedUserTypes = @(
    "Schueler",
    "Lehrkraefte",
    "Verwaltung",
    "IT"
)


# ------------------------------------------------------------
# Gegebenenfalls frühere Version von 
# "Benutzerdaten-validiert.csv" entfernen
# ------------------------------------------------------------

$ValidatedCsvPath = Join-Path `
    (Split-Path $CsvPath -Parent) `
    "Benutzerdaten-validiert.csv"

if (Test-Path $ValidatedCsvPath) {
    Remove-Item $ValidatedCsvPath -Force
    Write-Output "[INFO] Alte validierte CSV wurde entfernt."
}

# ------------------------------------------------------------
# Hilfsfunktionen
# ------------------------------------------------------------

function Normalize-Name {
    param (
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $Text = $Text.Trim().ToLowerInvariant()

    # Deutsche Sonderzeichen
    $Text = $Text -replace "ä", "ae"
    $Text = $Text -replace "ö", "oe"
    $Text = $Text -replace "ü", "ue"
    $Text = $Text -replace "ß", "ss"

    # Alles ausser Buchstaben und Zahlen entfernen
    $Text = $Text -replace "[^a-z0-9]", ""

    return $Text
}

function New-UniqueSamAccountName {
    param (
        [string]$GivenName,
        [string]$Surname,
        [hashtable]$UsedNames
    )

    $FirstName = Normalize-Name $GivenName
    $LastName  = Normalize-Name $Surname

    if ([string]::IsNullOrWhiteSpace($FirstName) -or
        [string]::IsNullOrWhiteSpace($LastName)) {

        return $null
    }

    # Grundform:
    # erster Buchstabe des Vornamens + Nachname
    $BaseName = $FirstName.Substring(0,1) + $LastName

    # Falls frei:
    if (-not $UsedNames.ContainsKey($BaseName)) {
        $UsedNames[$BaseName] = 1
        return $BaseName
    }

    # Weitere Buchstaben des Vornamens verwenden
    for ($i = 2; $i -le $FirstName.Length; $i++) {

        $Candidate = $FirstName.Substring(0,$i) + $LastName

        if (-not $UsedNames.ContainsKey($Candidate)) {
            $UsedNames[$Candidate] = 1
            return $Candidate
        }
    }

    # Falls auch der vollständige Name bereits vergeben ist:
    $Counter = 2

    do {
        $Candidate = $BaseName + $Counter
        $Counter++
    }
    while ($UsedNames.ContainsKey($Candidate))

    $UsedNames[$Candidate] = 1

    return $Candidate
}

# ------------------------------------------------------------
# CSV einlesen
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Benutzerimport validieren ==="
Write-Output ""

$Rows = Import-Csv `
    -Path $CsvPath `
    -Delimiter ";" `
    -Encoding UTF8

if (-not $Rows) {
    Write-Output "[FEHLER] Die CSV-Datei enthaelt keine Datensaetze."
    exit 1
}

Write-Output "[OK] $($Rows.Count) Datensaetze eingelesen."

# ------------------------------------------------------------
# Grundlegende Struktur prüfen
# ------------------------------------------------------------

$RequiredColumns = @(
    "Personalnummer",
    "Vorname",
    "Nachname",
    "BenutzerTyp",
    "Klassen"
)

$CsvColumns = $Rows[0].PSObject.Properties.Name

foreach ($Column in $RequiredColumns) {

    if ($Column -notin $CsvColumns) {

        Write-Output "[FEHLER] Fehlende Spalte: $Column"
        exit 1
    }
}

Write-Output "[OK] CSV-Struktur ist vollstaendig."

# ------------------------------------------------------------
# Personalnummern prüfen
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Personalnummern ==="
Write-Output ""

$UsedPersonnelNumbers = @{}
$ValidationErrors = @()

foreach ($Row in $Rows) {

    $PersonnelNumber = $Row.Personalnummer.Trim()

    if ([string]::IsNullOrWhiteSpace($PersonnelNumber)) {

        $ValidationErrors += `
            "Leere Personalnummer bei $($Row.Vorname) $($Row.Nachname)"

        continue
    }

    if ($UsedPersonnelNumbers.ContainsKey($PersonnelNumber)) {

        $ValidationErrors += `
            "Doppelte Personalnummer: $PersonnelNumber"
    }
    else {

        $UsedPersonnelNumbers[$PersonnelNumber] = $true
    }
}

if ($ValidationErrors.Count -eq 0) {
    Write-Output "[OK] Alle Personalnummern sind vorhanden und eindeutig."
}

# ------------------------------------------------------------
# BenutzerTyp prüfen
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Benutzertypen ==="
Write-Output ""

foreach ($Row in $Rows) {

    if ($Row.BenutzerTyp -notin $AllowedUserTypes) {

        $ValidationErrors += `
            "Ungueltiger BenutzerTyp '$($Row.BenutzerTyp)' bei Personalnummer $($Row.Personalnummer)"
    }
}

if (
    $Rows |
    Where-Object { $_.BenutzerTyp -notin $AllowedUserTypes } |
    Measure-Object |
    Select-Object -ExpandProperty Count
) {
    # Fehler wurden bereits gesammelt.
}
else {
    Write-Output "[OK] Alle BenutzerTyp-Werte sind gueltig."
}

# ------------------------------------------------------------
# Namen prüfen
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Namen ==="
Write-Output ""

foreach ($Row in $Rows) {

    if ([string]::IsNullOrWhiteSpace($Row.Vorname)) {

        $ValidationErrors += `
            "Fehlender Vorname bei Personalnummer $($Row.Personalnummer)"
    }

    if ([string]::IsNullOrWhiteSpace($Row.Nachname)) {

        $ValidationErrors += `
            "Fehlender Nachname bei Personalnummer $($Row.Personalnummer)"
    }
}

if (
    ($Rows |
        Where-Object {
            [string]::IsNullOrWhiteSpace($_.Vorname) -or
            [string]::IsNullOrWhiteSpace($_.Nachname)
        }).Count -eq 0
) {

    Write-Output "[OK] Alle Vor- und Nachnamen sind vorhanden."
}

# ------------------------------------------------------------
# Klassen prüfen
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Klassen ==="
Write-Output ""

foreach ($Row in $Rows) {

    $Classes = @()

    if (-not [string]::IsNullOrWhiteSpace($Row.Klassen)) {

        $Classes = $Row.Klassen.Split("|") |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -ne "" }
    }

    switch ($Row.BenutzerTyp) {

        "Schueler" {

            if ($Classes.Count -ne 1) {

                $ValidationErrors += `
                    "Schueler $($Row.Personalnummer) muss genau eine Klasse haben."
            }
        }

        "Lehrkraefte" {

            if ($Classes.Count -eq 0) {

                $ValidationErrors += `
                    "Lehrkraft $($Row.Personalnummer) hat keine Klasse."
            }
        }

        "Verwaltung" {
            
            if ($Classes.Count -gt 0) {

                $ValidationErrors += `
                    "Verwaltung $($Row.Personalnummer) darf keine Klasse haben."
            }
        }

        "IT" {

            if ($Classes.Count -gt 0) {

                $ValidationErrors += `
                    "IT-Benutzer $($Row.Personalnummer) darf keine Klasse haben."
            }
        }
    }
}

if ($ValidationErrors.Count -eq 0) {
    Write-Output "[OK] Klassenangaben sind konsistent."
}

# ------------------------------------------------------------
# Accountnamen erzeugen
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Vorgeschlagene Accountnamen ==="
Write-Output ""

$UsedSamNames = @{}
$Results = @()

foreach ($Row in $Rows) {

    $SamAccountName = New-UniqueSamAccountName `
        -GivenName $Row.Vorname `
        -Surname $Row.Nachname `
        -UsedNames $UsedSamNames

    if (-not $SamAccountName) {

        $ValidationErrors += `
            "Accountname konnte nicht erzeugt werden: $($Row.Personalnummer)"

        continue
    }

    $Results += [PSCustomObject]@{
        Personalnummer = $Row.Personalnummer
        Vorname        = $Row.Vorname
        Nachname       = $Row.Nachname
        BenutzerTyp    = $Row.BenutzerTyp
        Klassen        = $Row.Klassen
        SamAccountName = $SamAccountName
    }
}

$Results |
    Format-Table `
        Personalnummer,
        Vorname,
        Nachname,
        BenutzerTyp,
        Klassen,
        SamAccountName `
        -AutoSize

# ------------------------------------------------------------
# Gegen vorhandene AD-Konten prüfen
# ------------------------------------------------------------

$ADConflicts = 0

foreach ($Result in $Results) {

    $ExistingUser = $null

    try {
        $ExistingUser = Get-ADUser `
            -Identity $Result.SamAccountName `
            -ErrorAction Stop
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        $ExistingUser = $null
    }
    catch {
        Write-Output "[FEHLER] AD-Abfrage fuer $($Result.SamAccountName) fehlgeschlagen:"
        Write-Output "         $($_.Exception.Message)"
        $AdConflicts++
        continue
    }

    if ($ExistingUser) {

        Write-Output "[KONFLIKT] $($Result.SamAccountName) existiert bereits im AD."
        $AdConflicts++
    }
}

if ($AdConflicts -eq 0) {

    Write-Output "[OK] Keine Konflikte mit bestehenden AD-Benutzern."
}

# ------------------------------------------------------------
# Zusammenfassung
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Zusammenfassung ==="
Write-Output ""

Write-Output "Datensaetze:          $($Rows.Count)"
Write-Output "Validierungsfehler:  $($ValidationErrors.Count)"
Write-Output "AD-Konflikte:        $AdConflicts"

if ($ValidationErrors.Count -gt 0) {

    Write-Output ""
    Write-Output "=== Validierungsfehler ==="
    Write-Output ""

    foreach ($ErrorMessage in $ValidationErrors) {

        Write-Output "[FEHLER] $ErrorMessage"
    }
}

Write-Output ""

if (
    $ValidationErrors.Count -eq 0 -and
    $AdConflicts -eq 0
) {

    Write-Output "[OK] Import kann an 03c uebergeben werden."

    # --------------------------------------------------------
    # Validierte CSV erzeugen
    # --------------------------------------------------------

    $ValidatedCsvPath = Join-Path `
        (Split-Path $CsvPath -Parent) `
        "Benutzerdaten-validiert.csv"

    $Results |
        Select-Object `
            Personalnummer,
            Vorname,
            Nachname,
            BenutzerTyp,
            Klassen,
            SamAccountName |
        Export-Csv `
            -Path $ValidatedCsvPath `
            -Delimiter ";" `
            -Encoding UTF8 `
            -NoTypeInformation

    Write-Output ""
    Write-Output "[ERSTELLT] Validierte CSV-Datei:"
    Write-Output $ValidatedCsvPath
}
else {

    Write-Output "[ABBRUCH] Import muss vor der Benutzererstellung korrigiert werden."
}
