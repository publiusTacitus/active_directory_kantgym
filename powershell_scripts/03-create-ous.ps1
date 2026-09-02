# ============================================================
# 03-create-ous.ps1
# Erstellt die Organisationseinheiten (OUs) für das
# Active-Directory-Modell des Kant-Gymnasiums.
#
# Das Skript ist idempotent und kann mehrfach ausgeführt werden.
# ============================================================

Import-Module ActiveDirectory

# ------------------------------------------------------------
# Domäne
# ------------------------------------------------------------

$DomainDN = (Get-ADDomain).DistinguishedName

Write-Output ""
Write-Output "=== Active-Directory-OUs konfigurieren ==="
Write-Output ""
Write-Output "Domaene: $DomainDN"
Write-Output ""

# ------------------------------------------------------------
# OU-Struktur
# ------------------------------------------------------------

$OUs = @(

    # --------------------------------------------------------
    # Stamm-OUs
    # --------------------------------------------------------

    @{
        Name = "Benutzer"
        Path = $DomainDN
    },
    @{
        Name = "Computer"
        Path = $DomainDN
    },
    @{
        Name = "Server"
        Path = $DomainDN
    },
    @{
        Name = "Gruppen"
        Path = $DomainDN
    },

    # --------------------------------------------------------
    # Benutzer
    # --------------------------------------------------------

    @{
        Name = "Schueler"
        Path = "OU=Benutzer,$DomainDN"
    },
    @{
        Name = "Lehrkraefte"
        Path = "OU=Benutzer,$DomainDN"
    },
    @{
        Name = "Verwaltung"
        Path = "OU=Benutzer,$DomainDN"
    },
    @{
        Name = "IT"
        Path = "OU=Benutzer,$DomainDN"
    },

    # --------------------------------------------------------
    # Computer
    # --------------------------------------------------------

    @{
        Name = "Unterricht"
        Path = "OU=Computer,$DomainDN"
    },
    @{
        Name = "Lehrkraefte"
        Path = "OU=Computer,$DomainDN"
    },
    @{
        Name = "Verwaltung"
        Path = "OU=Computer,$DomainDN"
    },
    @{
        Name = "Pruefung"
        Path = "OU=Computer,$DomainDN"
    },

    # --------------------------------------------------------
    # Gruppen
    # --------------------------------------------------------

    @{
        Name = "Rollen"
        Path = "OU=Gruppen,$DomainDN"
    },
    @{
        Name = "Klassen"
        Path = "OU=Gruppen,$DomainDN"
    },
    @{
        Name = "Ressourcen"
        Path = "OU=Gruppen,$DomainDN"
    }
)

# ------------------------------------------------------------
# OUs erstellen
# ------------------------------------------------------------

foreach ($OU in $OUs) {

    $Name = $OU.Name
    $Path = $OU.Path

    $ExistingOU = Get-ADOrganizationalUnit `
        -Filter "Name -eq '$Name'" `
        -SearchBase $Path `
        -SearchScope OneLevel `
        -ErrorAction SilentlyContinue

    if ($ExistingOU) {

        Write-Output "[VORHANDEN] OU=$Name,$Path"

        continue
    }

    try {

        New-ADOrganizationalUnit `
            -Name $Name `
            -Path $Path `
            -ProtectedFromAccidentalDeletion $true `
            -ErrorAction Stop

        Write-Output "[ERSTELLT]  OU=$Name,$Path"
    }
    catch {

        Write-Output "[FEHLER]    OU=$Name,$Path"
        Write-Output "            $($_.Exception.Message)"
    }
}

# ============================================================
# Zusammenfassung
# ============================================================

Write-Output ""
Write-Output "=== Zusammenfassung der OU-Struktur ==="
Write-Output ""

$RootOUs = Get-ADOrganizationalUnit `
    -SearchBase $DomainDN `
    -SearchScope OneLevel `
    -Filter * |
    Sort-Object Name

foreach ($OU in $RootOUs) {

    Write-Output $OU.DistinguishedName

    $ChildOUs = Get-ADOrganizationalUnit `
        -SearchBase $OU.DistinguishedName `
        -SearchScope OneLevel `
        -Filter * |
        Sort-Object Name

    foreach ($ChildOU in $ChildOUs) {

        Write-Output "    $($ChildOU.DistinguishedName)"

        $GrandChildOUs = Get-ADOrganizationalUnit `
            -SearchBase $ChildOU.DistinguishedName `
            -SearchScope OneLevel `
            -Filter * |
            Sort-Object Name

        foreach ($GrandChildOU in $GrandChildOUs) {

            Write-Output "        $($GrandChildOU.DistinguishedName)"
        }
    }
}

Write-Output ""
Write-Output "OU-Konfiguration abgeschlossen."