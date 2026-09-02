# ============================================================
# 10-configure-ntfs-permissions.ps1
#
# Konfiguriert die NTFS-Berechtigungen für die Fileserver-
# Verzeichnisse.
#
# Prinzip:
# - Vererbung wird auf den Share-Verzeichnissen deaktiviert.
# - SYSTEM erhält FullControl.
# - Administratoren erhalten FullControl.
# - Die jeweilige Domain-Local-Gruppe erhält Modify.
#
# Die klassenbezogenen Verzeichnisse und Gruppen werden
# automatisch aus den vorhandenen AD-Gruppen abgeleitet.
#
# Das Skript ist idempotent und kann mehrfach ausgeführt werden.
# ============================================================

Import-Module ActiveDirectory

$Domain = Get-ADDomain
$DomainNetBIOS = $Domain.NetBIOSName

# ------------------------------------------------------------
# Share-Definitionen
# ------------------------------------------------------------

$ShareDefinitions = @(
    @{
        Name  = "Schueler"
        Path  = "C:\Shares\Schueler"
        Group = "$DomainNetBIOS\DL_Share_Schueler_RW"
    },
    @{
        Name  = "Lehrer"
        Path  = "C:\Shares\Lehrer"
        Group = "$DomainNetBIOS\DL_Share_Lehrer_RW"
    },
    @{
        Name  = "Verwaltung"
        Path  = "C:\Shares\Verwaltung"
        Group = "$DomainNetBIOS\DL_Share_Verwaltung_RW"
    }
)

# ------------------------------------------------------------
# Klassen aus vorhandenen AD-Gruppen ermitteln
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

foreach ($ClassGroup in $ClassGroups) {

    if ($ClassGroup.Name -match '^DL_Share_Klasse_(.+)_RW$') {

        $Klasse = $Matches[1]

        $ShareDefinitions += @{
            Name  = "Klasse $Klasse"
            Path  = "C:\Shares\Klassen\$Klasse"
            Group = "$DomainNetBIOS\$($ClassGroup.Name)"
        }
    }
}

if ($ClassGroups.Count -gt 0) {

    Write-Output "[OK] $($ClassGroups.Count) Klassen-Gruppen gefunden."

}
else {

    Write-Output "[HINWEIS] Keine klassenbezogenen Gruppen gefunden."
}

# ------------------------------------------------------------
# NTFS-Berechtigungen konfigurieren
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== NTFS-Berechtigungen konfigurieren ==="
Write-Output ""

foreach ($Share in $ShareDefinitions) {

    $Path  = $Share.Path
    $Group = $Share.Group

    Write-Output "--- $($Share.Name) ---"
    Write-Output "Pfad:   $Path"
    Write-Output "Gruppe: $Group"

    if (-not (Test-Path $Path -PathType Container)) {

        Write-Output "[FEHLER] Verzeichnis existiert nicht: $Path"
        Write-Output ""
        continue
    }

    try {

        $Acl = Get-Acl $Path -ErrorAction Stop

        # ----------------------------------------------------
        # Vererbung deaktivieren und geerbte ACEs entfernen
        # ----------------------------------------------------

        $Acl.SetAccessRuleProtection($true, $false)

        # ----------------------------------------------------
        # Gewünschte Standardberechtigungen
        # ----------------------------------------------------

        $Rules = @(
            [System.Security.AccessControl.FileSystemAccessRule]::new(
                "SYSTEM",
                "FullControl",
                "ContainerInherit,ObjectInherit",
                "None",
                "Allow"
            ),

            [System.Security.AccessControl.FileSystemAccessRule]::new(
                "Administratoren",
                "FullControl",
                "ContainerInherit,ObjectInherit",
                "None",
                "Allow"
            ),

            [System.Security.AccessControl.FileSystemAccessRule]::new(
                $Group,
                "Modify",
                "ContainerInherit,ObjectInherit",
                "None",
                "Allow"
            )
        )

        foreach ($Rule in $Rules) {

            $Acl.SetAccessRule($Rule)
        }

        Set-Acl `
            -Path $Path `
            -AclObject $Acl `
            -ErrorAction Stop

        Write-Output "[OK] NTFS-Berechtigungen gesetzt."

    }
    catch {

        Write-Output "[FEHLER] NTFS-Berechtigungen konnten nicht gesetzt werden."
        Write-Output "         $($_.Exception.Message)"
    }

    Write-Output ""
}

# ------------------------------------------------------------
# Diagnose
# ------------------------------------------------------------

Write-Output "=== Zusammenfassung der NTFS-Berechtigungen ==="
Write-Output ""

foreach ($Share in $ShareDefinitions) {

    Write-Output "--- $($Share.Name) ---"
    Write-Output "Pfad: $($Share.Path)"

    if (-not (Test-Path $Share.Path -PathType Container)) {

        Write-Output "[FEHLER] Verzeichnis nicht vorhanden."
        Write-Output ""
        continue
    }

    Get-Acl $Share.Path |
        Select-Object -ExpandProperty Access |
        Select-Object IdentityReference,
                      FileSystemRights,
                      AccessControlType,
                      IsInherited |
        Format-Table -AutoSize |
        Out-String |
        ForEach-Object {
            Write-Output $_.TrimEnd()
        }

    Write-Output ""
}

Write-Output "NTFS-Konfiguration abgeschlossen."
