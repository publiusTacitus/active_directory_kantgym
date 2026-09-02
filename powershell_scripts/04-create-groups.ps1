# ============================================================
# 04-create-groups.ps1
#
# Erstellt globale und Domain-Local-Sicherheitsgruppen und
# richtet deren Verschachtelungen ein.
#
# Struktur:
#   Benutzer → Global Groups → Domain Local Groups → Ressourcen
#
# Die klassenbezogenen Gruppen werden automatisch aus den
# tatsächlich in Benutzerdaten-validiert.csv vorhandenen
# Klassen abgeleitet.
#
# Das Skript ist idempotent und kann mehrfach ausgeführt werden.
# ============================================================

Import-Module ActiveDirectory

$Domain = Get-ADDomain
$DomainDN = $Domain.DistinguishedName

# ------------------------------------------------------------
# Überschrift
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== AD-Gruppen konfigurieren ==="
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
# Klassen aus der CSV ermitteln
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Klassen aus der CSV ermitteln ==="
Write-Output ""

$Classes = @()

foreach ($User in $Users) {

if (-not [string]::IsNullOrWhiteSpace($User.Klassen)) {

    foreach ($Klasse in ($User.Klassen -split "\|")) {

        $Klasse = $Klasse.Trim()

        if (-not [string]::IsNullOrWhiteSpace($Klasse)) {

            $Classes += $Klasse
        }
    }
}

}

$Classes = $Classes |
Sort-Object -Unique

if ($Classes.Count -eq 0) {

Write-Output "[ABBRUCH] Es konnten keine Klassen aus der CSV ermittelt werden."
exit 1

}

Write-Output "[OK] Folgende Klassen wurden ermittelt:"

foreach ($Klasse in $Classes) {

Write-Output "     - $Klasse"

}

Write-Output ""
Write-Output "Anzahl Klassen: $($Classes.Count)"

# ------------------------------------------------------------
# Gruppen definieren
# ------------------------------------------------------------

$Groups = @(

# --------------------------------------------------------
# Rollen
# --------------------------------------------------------

@{
    Name     = "GG_Schueler"
    OU       = "OU=Rollen,OU=Gruppen,$DomainDN"
    Scope    = "Global"
    Category = "Security"
},
@{
    Name     = "GG_Lehrkraefte"
    OU       = "OU=Rollen,OU=Gruppen,$DomainDN"
    Scope    = "Global"
    Category = "Security"
},
@{
    Name     = "GG_Verwaltung"
    OU       = "OU=Rollen,OU=Gruppen,$DomainDN"
    Scope    = "Global"
    Category = "Security"
},
@{
    Name     = "GG_IT_Administratoren"
    OU       = "OU=Rollen,OU=Gruppen,$DomainDN"
    Scope    = "Global"
    Category = "Security"
},

# --------------------------------------------------------
# Ressourcenberechtigungen für Lehrkräfte
# --------------------------------------------------------

@{
    Name     = "GG_Lehrkraefte_Schueler"
    OU       = "OU=Rollen,OU=Gruppen,$DomainDN"
    Scope    = "Global"
    Category = "Security"
},

# --------------------------------------------------------
# Allgemeine Domain-Local Ressourcen-Gruppen
# --------------------------------------------------------

@{
    Name     = "DL_Share_Schueler_RW"
    OU       = "OU=Ressourcen,OU=Gruppen,$DomainDN"
    Scope    = "DomainLocal"
    Category = "Security"
},
@{
    Name     = "DL_Share_Lehrer_RW"
    OU       = "OU=Ressourcen,OU=Gruppen,$DomainDN"
    Scope    = "DomainLocal"
    Category = "Security"
},
@{
    Name     = "DL_Share_Verwaltung_RW"
    OU       = "OU=Ressourcen,OU=Gruppen,$DomainDN"
    Scope    = "DomainLocal"
    Category = "Security"
}

)

# ------------------------------------------------------------
# Klassenbezogene Gruppen dynamisch ergänzen
# ------------------------------------------------------------

foreach ($Klasse in $Classes) {

# --------------------------------------------------------
# Schülergruppe
# --------------------------------------------------------

$Groups += @{
    Name     = "GG_Klasse_$Klasse"
    OU       = "OU=Klassen,OU=Gruppen,$DomainDN"
    Scope    = "Global"
    Category = "Security"
}

# --------------------------------------------------------
# Lehrergruppe
# --------------------------------------------------------

$Groups += @{
    Name     = "GG_Lehrer_Klasse_$Klasse"
    OU       = "OU=Klassen,OU=Gruppen,$DomainDN"
    Scope    = "Global"
    Category = "Security"
}

# --------------------------------------------------------
# Domain-Local Ressourcen-Gruppe
# --------------------------------------------------------

$Groups += @{
    Name     = "DL_Share_Klasse_${Klasse}_RW"
    OU       = "OU=Ressourcen,OU=Gruppen,$DomainDN"
    Scope    = "DomainLocal"
    Category = "Security"
}

}

# ------------------------------------------------------------
# Gruppen erstellen
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Gruppen erstellen ==="
Write-Output ""

foreach ($Group in $Groups) {

$ExistingGroup = $null

try {

    $ExistingGroup = Get-ADGroup `
        -Identity $Group.Name `
        -ErrorAction Stop
}
catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {

    $ExistingGroup = $null
}

if ($ExistingGroup) {

    Write-Output "[VORHANDEN] $($Group.Name)"
    continue
}

try {

    New-ADGroup `
        -Name $Group.Name `
        -SamAccountName $Group.Name `
        -GroupScope $Group.Scope `
        -GroupCategory $Group.Category `
        -Path $Group.OU `
        -ErrorAction Stop

    Write-Output "[ERSTELLT]  $($Group.Name)"
}
catch {

    Write-Output "[FEHLER] Gruppe konnte nicht erstellt werden:"
    Write-Output "         $($Group.Name)"
    Write-Output "         $($_.Exception.Message)"
}

}

# ------------------------------------------------------------
# Gruppenverschachtelungen
# ------------------------------------------------------------

$Nesting = @(

# --------------------------------------------------------
# Schülerbereich
# --------------------------------------------------------

@{
    Parent = "DL_Share_Schueler_RW"
    Member = "GG_Schueler"
},
@{
    Parent = "DL_Share_Schueler_RW"
    Member = "GG_Lehrkraefte_Schueler"
},
@{
    Parent = "GG_Lehrkraefte_Schueler"
    Member = "GG_Lehrkraefte"
},

# --------------------------------------------------------
# Lehrerbereich
# --------------------------------------------------------

@{
    Parent = "DL_Share_Lehrer_RW"
    Member = "GG_Lehrkraefte"
},

# --------------------------------------------------------
# Verwaltungsbereich
# --------------------------------------------------------

@{
    Parent = "DL_Share_Verwaltung_RW"
    Member = "GG_Verwaltung"
}

)

# ------------------------------------------------------------
# Klassenbezogene Verschachtelungen dynamisch ergänzen
# ------------------------------------------------------------

foreach ($Klasse in $Classes) {

$Nesting += @{
    Parent = "DL_Share_Klasse_${Klasse}_RW"
    Member = "GG_Klasse_$Klasse"
}

$Nesting += @{
    Parent = "DL_Share_Klasse_${Klasse}_RW"
    Member = "GG_Lehrer_Klasse_$Klasse"
}

}

# ------------------------------------------------------------
# Verschachtelungen einrichten
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Gruppenverschachtelungen ==="
Write-Output ""

$NestingErrors = 0

foreach ($Relation in $Nesting) {

$IsMember = Get-ADGroupMember `
    -Identity $Relation.Parent `
    -ErrorAction SilentlyContinue |
    Where-Object {
        $_.SamAccountName -eq $Relation.Member
    }

if ($IsMember) {

    Write-Output "[VORHANDEN] $($Relation.Member) -> $($Relation.Parent)"
}
else {

    try {

        Add-ADGroupMember `
            -Identity $Relation.Parent `
            -Members $Relation.Member `
            -ErrorAction Stop

        Write-Output "[HINZUGEFUEGT] $($Relation.Member) -> $($Relation.Parent)"
    }
    catch {

        Write-Output "[FEHLER] Verschachtelung konnte nicht erstellt werden:"
        Write-Output "         $($Relation.Member) -> $($Relation.Parent)"
        Write-Output "         $($_.Exception.Message)"

        $NestingErrors++
    }
}

}

# ------------------------------------------------------------
# Diagnose
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Gruppen ==="
Write-Output ""

Get-ADGroup -Filter * |
    Where-Object {
        $_.Name -like "GG_*" -or $_.Name -like "DL_*"
    } |
    Sort-Object Name |
    Select-Object Name, GroupScope, GroupCategory, DistinguishedName |
    Format-Table -AutoSize

Write-Output ""
Write-Output "=== Gruppenverschachtelungen ==="
Write-Output ""

foreach ($Relation in $Nesting) {

$Member = Get-ADGroupMember `
    -Identity $Relation.Parent `
    -ErrorAction SilentlyContinue |
    Where-Object {
        $_.SamAccountName -eq $Relation.Member
    }

if ($Member) {

    Write-Output "[OK] $($Relation.Member) -> $($Relation.Parent)"
}
else {

    Write-Output "[FEHLER] $($Relation.Member) fehlt in $($Relation.Parent)"
}

}

# ------------------------------------------------------------
# Zusammenfassung
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Zusammenfassung ==="
Write-Output ""

Write-Output "Datensaetze CSV: $($Users.Count)"
Write-Output "Ermittelte Klassen: $($Classes.Count)"
Write-Output "Gruppen definiert: $($Groups.Count)"
Write-Output "Verschachtelungen: $($Nesting.Count)"
Write-Output "Verschachtelungsfehler: $NestingErrors"

Write-Output ""
Write-Output "=== Erkannte Klassen ==="
Write-Output ""

foreach ($Klasse in $Classes) {

Write-Output "[OK] $Klasse"

}

Write-Output ""

if ($NestingErrors -eq 0) {

Write-Output "[OK] Gruppenkonfiguration abgeschlossen."

}
else {

Write-Output "[WARNUNG] Gruppenkonfiguration wurde mit Fehlern abgeschlossen."

}