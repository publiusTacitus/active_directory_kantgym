# ============================================================
# 11-create-shares.ps1
#
# Erstellt und prüft die SMB-Freigaben.
#
# Die klassenbezogenen Freigaben werden automatisch aus den
# vorhandenen Domain-Local-Klassengruppen im AD abgeleitet.
#
# Das Skript ist idempotent und kann mehrfach ausgeführt werden.
# ============================================================

Import-Module ActiveDirectory

$Domain = Get-ADDomain
$DomainNetBIOS = $Domain.NetBIOSName

# ------------------------------------------------------------
# Feste Freigaben
# ------------------------------------------------------------

$Shares = @(
    @{
        Name  = "Schueler"
        Path  = "C:\Shares\Schueler"
        Group = "DL_Share_Schueler_RW"
    },
    @{
        Name  = "Lehrer"
        Path  = "C:\Shares\Lehrer"
        Group = "DL_Share_Lehrer_RW"
    },
    @{
        Name  = "Verwaltung"
        Path  = "C:\Shares\Verwaltung"
        Group = "DL_Share_Verwaltung_RW"
    }
)

# ------------------------------------------------------------
# Klassen aus dem AD ermitteln
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Klassen aus dem AD ermitteln ==="
Write-Output ""

try {

    $ClassGroups = Get-ADGroup `
        -Filter 'Name -like "DL_Share_Klasse_*_RW"' `
        -ErrorAction Stop

}
catch {

    Write-Output "[FEHLER] Klassen-Gruppen konnten nicht aus dem AD gelesen werden."
    Write-Output "         $($_.Exception.Message)"
    exit 1
}

if ($ClassGroups.Count -gt 0) {

    Write-Output "[OK] $($ClassGroups.Count) Klassen-Gruppen gefunden."

}
else {

    Write-Output "[HINWEIS] Keine klassenbezogenen Gruppen gefunden."
}

# ------------------------------------------------------------
# Klassenfreigaben aus den AD-Gruppen ableiten
# ------------------------------------------------------------

foreach ($ClassGroup in $ClassGroups) {

    if ($ClassGroup.Name -match '^DL_Share_Klasse_(.+)_RW$') {

        $Klasse = $Matches[1]

        $Shares += @{
            Name  = "Klasse_$Klasse"
            Path  = "C:\Shares\Klassen\$Klasse"
            Group = $ClassGroup.Name
        }
    }
}

# ------------------------------------------------------------
# SMB-Freigaben konfigurieren
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== SMB-Freigaben konfigurieren ==="
Write-Output ""

foreach ($Share in $Shares) {

    $Name  = $Share.Name
    $Path  = $Share.Path
    $Group = "$DomainNetBIOS\$($Share.Group)"

    Write-Output "--- $Name ---"
    Write-Output "Pfad:   $Path"
    Write-Output "Gruppe: $Group"

    # --------------------------------------------------------
    # Verzeichnis prüfen
    # --------------------------------------------------------

    if (-not (Test-Path $Path -PathType Container)) {

        Write-Output "[FEHLER] Verzeichnis existiert nicht."
        Write-Output ""

        continue
    }

    # --------------------------------------------------------
    # SMB-Freigabe prüfen / erstellen
    # --------------------------------------------------------

    $ExistingShare = Get-SmbShare `
        -Name $Name `
        -ErrorAction SilentlyContinue

    if (-not $ExistingShare) {

        try {

            New-SmbShare `
                -Name $Name `
                -Path $Path `
                -ChangeAccess $Group `
                -ErrorAction Stop |
                Out-Null

            Write-Output "[ERSTELLT] SMB-Freigabe angelegt."

        }
        catch {

            Write-Output "[FEHLER] SMB-Freigabe konnte nicht erstellt werden."
            Write-Output "         $($_.Exception.Message)"
        }

    }
    else {

        Write-Output "[VORHANDEN] SMB-Freigabe existiert bereits."

    }

    # --------------------------------------------------------
    # SMB-Berechtigung prüfen
    # --------------------------------------------------------

    $Access = Get-SmbShareAccess `
        -Name $Name `
        -ErrorAction SilentlyContinue

    $ExpectedAccess = $Access |
        Where-Object {
            $_.AccountName -eq $Group -and
            $_.AccessControlType -eq "Allow" -and
            $_.AccessRight -eq "Change"
        }

    if ($ExpectedAccess) {

        Write-Output "[OK] $Group besitzt Change-Berechtigung."

    }
    else {

        Write-Output "[FEHLER] Erwartete SMB-Berechtigung fehlt."

        Write-Output "        Vorhandene Berechtigungen:"

        $Access |
            Select-Object AccountName,
                          AccessControlType,
                          AccessRight |
            Format-Table -AutoSize |
            Out-String |
            Write-Output
    }

    Write-Output ""
}

# ============================================================
# Diagnose
# ============================================================

Write-Output "=== Zusammenfassung der SMB-Freigaben ==="
Write-Output ""

Get-SmbShare |
    Where-Object {
        $_.Path -like "C:\Shares\*"
    } |
    Select-Object Name, Path |
    Sort-Object Name |
    Format-Table -AutoSize |
    Out-String |
    Write-Output

Write-Output ""
Write-Output "=== Zusammenfassung der SMB-Berechtigungen ==="
Write-Output ""

foreach ($Share in $Shares) {

    Write-Output "--- $($Share.Name) ---"

    Get-SmbShareAccess `
        -Name $Share.Name `
        -ErrorAction SilentlyContinue |
        Select-Object AccountName,
                      AccessControlType,
                      AccessRight |
        Format-Table -AutoSize |
        Out-String |
        Write-Output
}

Write-Output ""
Write-Output "SMB-Freigabekonfiguration abgeschlossen."