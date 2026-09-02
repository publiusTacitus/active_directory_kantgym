# ============================================================
# 05-create-users.ps1
#
# Erstellt AD-Benutzer aus der von 03 validierten CSV-Datei
# sowie eine temporäre Credential-CSV.
#
# Pipeline:
#
# 01 -> Benutzerdaten-import.csv
# 02 -> Benutzerdaten-validiert.csv
# 03 -> AD-OUs
# 04 -> AD-Gruppen
# 05 -> AD-Benutzer + Gruppenmitgliedschaften
#
# Das Skript ist idempotent und kann mehrfach ausgeführt werden.
# ============================================================

Import-Module ActiveDirectory

$Domain = Get-ADDomain
$DomainDN = $Domain.DistinguishedName
$DomainName = $Domain.DNSRoot

# ------------------------------------------------------------
# Validierte CSV auswählen
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Benutzer aus validierter CSV erstellen ==="
Write-Output ""

$CsvPath = Read-Host "Pfad zur validierten CSV-Datei"

if (-not (Test-Path $CsvPath)) {

    Write-Output ""
    Write-Output "[ABBRUCH] CSV-Datei wurde nicht gefunden."
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
    "Personalnummer",
    "Vorname",
    "Nachname",
    "BenutzerTyp",
    "Klassen",
    "SamAccountName"
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

Write-Output "[OK] CSV-Struktur ist vollstaendig."

# ------------------------------------------------------------
# SamAccountNames prüfen
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Accountnamen prüfen ==="
Write-Output ""

$SamNameErrors = @()
$UsedSamNames = @{}

foreach ($User in $Users) {

    $SamAccountName = if ($null -ne $User.SamAccountName) {
        $User.SamAccountName.Trim()
    }
    else {
        ""
    }

    # Leerer Accountname
    if ([string]::IsNullOrWhiteSpace($SamAccountName)) {

        $SamNameErrors += `
            "Leerer SamAccountName bei Personalnummer $($User.Personalnummer)"

        continue
    }

    # Zeichenprüfung
    if ($SamAccountName -notmatch '^[a-zA-Z0-9._-]+$') {

        $SamNameErrors += `
            "Ungültiger SamAccountName '$SamAccountName' bei Personalnummer $($User.Personalnummer)"

        continue
    }

    # Doppelte Accountnamen innerhalb der CSV
    if ($UsedSamNames.ContainsKey($SamAccountName.ToLowerInvariant())) {

        $SamNameErrors += `
            "Doppelter SamAccountName in der CSV: $SamAccountName"
    }
    else {

        $UsedSamNames[$SamAccountName.ToLowerInvariant()] = $true
    }
}

if ($SamNameErrors.Count -gt 0) {

    Write-Output ""

    foreach ($ErrorMessage in $SamNameErrors) {

        Write-Output "[FEHLER] $ErrorMessage"
    }

    Write-Output ""
    Write-Output "[ABBRUCH] Die validierte CSV enthaelt ungueltige Accountnamen."
    Write-Output "          Bitte zuerst 03b erneut ausfuehren."

    exit 1
}

Write-Output "[OK] Alle Accountnamen sind vorhanden und eindeutig."

# ------------------------------------------------------------
# Passwortgenerierung
# ------------------------------------------------------------

function New-RandomPassword {

    param(
        [int]$Length = 14
    )

    $Lower   = "abcdefghijkmnopqrstuvwxyz"
    $Upper   = "ABCDEFGHJKLMNPQRSTUVWXYZ"
    $Numbers = "23456789"
    $Special = "!@#$%&*+-="

    $All = $Lower + $Upper + $Numbers + $Special

    $Password = @()

    $Password += $Lower[
        (Get-Random -Minimum 0 -Maximum $Lower.Length)
    ]

    $Password += $Upper[
        (Get-Random -Minimum 0 -Maximum $Upper.Length)
    ]

    $Password += $Numbers[
        (Get-Random -Minimum 0 -Maximum $Numbers.Length)
    ]

    $Password += $Special[
        (Get-Random -Minimum 0 -Maximum $Special.Length)
    ]

    for ($i = $Password.Count; $i -lt $Length; $i++) {

        $Password += $All[
            (Get-Random -Minimum 0 -Maximum $All.Length)
        ]
    }

    return -join ($Password | Sort-Object { Get-Random })
}

# ------------------------------------------------------------
# Ergebnislisten
# ------------------------------------------------------------

$CreatedUsers = @()
$ExistingUsers = @()
$FailedUsers = @()
$GroupErrors = 0

# ------------------------------------------------------------
# Benutzer erstellen / prüfen
# ------------------------------------------------------------

foreach ($User in $Users) {

    $SamAccountName = $User.SamAccountName.Trim()

    Write-Output ""
    Write-Output "--- $SamAccountName ---"

    # --------------------------------------------------------
    # OU anhand des Benutzertyps bestimmen
    # --------------------------------------------------------

    switch ($User.BenutzerTyp) {

        "Schueler" {

            $OU = "OU=Schueler,OU=Benutzer,$DomainDN"
        }

        "Lehrkraefte" {

            $OU = "OU=Lehrkraefte,OU=Benutzer,$DomainDN"
        }

        "Verwaltung" {

            $OU = "OU=Verwaltung,OU=Benutzer,$DomainDN"
        }

        "IT" {

            $OU = "OU=IT,OU=Benutzer,$DomainDN"
        }

        default {

            Write-Output "[FEHLER] Unbekannter Benutzertyp:"
            Write-Output "         $($User.BenutzerTyp)"

            $FailedUsers += $User
            continue
        }
    }

    # --------------------------------------------------------
    # Gruppen bestimmen
    # --------------------------------------------------------

    $Groups = @()

    switch ($User.BenutzerTyp) {

        "Schueler" {

            $Groups += "GG_Schueler"

            if (-not [string]::IsNullOrWhiteSpace($User.Klassen)) {

                foreach ($Klasse in ($User.Klassen -split "\|")) {

                    $Klasse = $Klasse.Trim()

                    if ($Klasse) {

                        $Groups += "GG_Klasse_$Klasse"
                    }
                }
            }
        }

        "Lehrkraefte" {

            $Groups += "GG_Lehrkraefte"
            $Groups += "GG_Lehrkraefte_Schueler"

            if (-not [string]::IsNullOrWhiteSpace($User.Klassen)) {

                foreach ($Klasse in ($User.Klassen -split "\|")) {

                    $Klasse = $Klasse.Trim()

                    if ($Klasse) {

                        $Groups += "GG_Lehrer_Klasse_$Klasse"
                    }
                }
            }
        }

        "Verwaltung" {

            $Groups += "GG_Verwaltung"
        }

        "IT" {

            $Groups += "GG_IT_Administratoren"
        }
    }

    # Doppelte Gruppen entfernen
    $Groups = $Groups | Select-Object -Unique

    # --------------------------------------------------------
    # Benutzer anhand des SamAccountName suchen
    # --------------------------------------------------------

    $ExistingUser = Get-ADUser `
        -Filter "SamAccountName -eq '$SamAccountName'" `
        -ErrorAction SilentlyContinue

    # --------------------------------------------------------
    # Benutzer existiert bereits
    # --------------------------------------------------------

    if ($ExistingUser) {

        Write-Output "[VORHANDEN] Benutzer: $SamAccountName"

        $ExistingUsers += $User
    }

    # --------------------------------------------------------
    # Benutzer neu erstellen
    # --------------------------------------------------------

    else {

        try {

            $PlainPassword = New-RandomPassword

            $SecurePassword = ConvertTo-SecureString `
                $PlainPassword `
                -AsPlainText `
                -Force

            # Eindeutiger AD-Objektname
            #
            # Wichtig bei z.B.:
            #
            # Sebastian Schuster [S30001]
            # Sebastian Schuster [S30032]

            $ADName = "$($User.Vorname) $($User.Nachname) [$($User.Personalnummer)]"

            $DisplayName = "$($User.Vorname) $($User.Nachname)"

            New-ADUser `
                -SamAccountName $SamAccountName `
                -UserPrincipalName "$SamAccountName@$DomainName" `
                -Name $ADName `
                -DisplayName $DisplayName `
                -GivenName $User.Vorname `
                -Surname $User.Nachname `
                -EmployeeID $User.Personalnummer `
                -Path $OU `
                -AccountPassword $SecurePassword `
                -Enabled $true `
                -ChangePasswordAtLogon $true `
                -ErrorAction Stop

            Write-Output "[ERSTELLT] Benutzer: $SamAccountName"

            $CreatedUsers += [PSCustomObject]@{
                Personalnummer = $User.Personalnummer
                Vorname        = $User.Vorname
                Nachname       = $User.Nachname
                BenutzerTyp    = $User.BenutzerTyp
                SamAccountName = $SamAccountName
                Passwort       = $PlainPassword
            }
        }
        catch {

            Write-Output "[FEHLER] Benutzer konnte nicht erstellt werden:"
            Write-Output "         $($_.Exception.Message)"

            $FailedUsers += $User
            continue
        }
    }

    # --------------------------------------------------------
    # Gruppenmitgliedschaften
    # --------------------------------------------------------

    foreach ($Group in $Groups) {

        $IsMember = Get-ADGroupMember `
            -Identity $Group `
            -ErrorAction SilentlyContinue |
            Where-Object {
                $_.SamAccountName -eq $SamAccountName
            }

        if ($IsMember) {

            Write-Output "[VORHANDEN] $SamAccountName -> $Group"
        }
        else {

            try {

                Add-ADGroupMember `
                    -Identity $Group `
                    -Members $SamAccountName `
                    -ErrorAction Stop

                Write-Output "[HINZUGEFUEGT] $SamAccountName -> $Group"
            }
            catch {

                Write-Output "[FEHLER] Gruppenmitgliedschaft:"
                Write-Output "         $SamAccountName -> $Group"
                Write-Output "         $($_.Exception.Message)"

                $GroupErrors++
            }
        }
    }
}

# ------------------------------------------------------------
# Zugangsdaten der neu erstellten Benutzer
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Neu erstellte Benutzer ==="
Write-Output ""

if ($CreatedUsers.Count -gt 0) {

    $CreatedUsers |
        Format-Table `
            Personalnummer,
            Vorname,
            Nachname,
            BenutzerTyp,
            SamAccountName,
            Passwort `
        -AutoSize
}
else {

    Write-Output "Keine neuen Benutzer erstellt."
}

# ------------------------------------------------------------
# Zusammenfassung
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Zusammenfassung ==="
Write-Output ""

Write-Output "Datensaetze:         $($Users.Count)"
Write-Output "Neu erstellt:        $($CreatedUsers.Count)"
Write-Output "Bereits vorhanden:   $($ExistingUsers.Count)"
Write-Output "Benutzerfehler:      $($FailedUsers.Count)"
Write-Output "Gruppenfehler:       $GroupErrors"

if (
    $FailedUsers.Count -eq 0 -and
    $GroupErrors -eq 0
) {

    Write-Output ""
    Write-Output "[OK] Benutzerimport abgeschlossen."
}
else {

    Write-Output ""
    Write-Output "[WARNUNG] Einige Benutzer konnten nicht vollstaendig verarbeitet werden."
}

# ------------------------------------------------------------
# Temporäre Credential-Datei
# ------------------------------------------------------------

$CredentialCsvPath = Join-Path `
    (Split-Path $CsvPath -Parent) `
    "Benutzerdaten-credentials-temp.csv"

if (Test-Path $CredentialCsvPath) {

    Write-Output ""
    Write-Output "[FEHLER] Eine temporaere Credential-Datei existiert bereits:"
    Write-Output "         $CredentialCsvPath"
    Write-Output "[ABBRUCH] Bitte die vorhandene Datei zuerst verarbeiten oder loeschen."

    exit 1
}

if (
    $CreatedUsers.Count -gt 0 -and
    $FailedUsers.Count -eq 0 -and
    $GroupErrors -eq 0
) {

    $CreatedUsers |
        Select-Object `
            Personalnummer,
            Vorname,
            Nachname,
            BenutzerTyp,
            SamAccountName,
            Passwort |
        Export-Csv `
            -Path $CredentialCsvPath `
            -Delimiter ";" `
            -Encoding UTF8 `
            -NoTypeInformation

    Write-Output ""
    Write-Output "[ERSTELLT] Temporaere Credential-Datei:"
    Write-Output "           $CredentialCsvPath"
}