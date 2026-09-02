# ============================================================
# 13-create-gpo-shortcuts.ps1
#
# Erzeugt die Shortcuts.xml für die GPO_Netzwerkfreigaben.
#
# Die Klassen werden automatisch aus den vorhandenen
# Fileserver-Klassenordnern ermittelt.
#
# Feste Verknüpfungen:
# - Lehrer
# - Schueler
# - Verwaltung
#
# Dynamische Verknüpfungen:
# - eine Verknüpfung pro vorhandenem Klassenordner
#
# Die bestehende Shortcuts.xml wird vor dem Überschreiben
# automatisch als .bak-Datei gesichert.
#
# ============================================================

# ------------------------------------------------------------
# Konfiguration
# ------------------------------------------------------------

$ShareRoot = "C:\Shares"

$ClassFolder = Join-Path `
    $ShareRoot `
    "Klassen"

$GpoShortcutsFolder = `
    "C:\Windows\SYSVOL\sysvol\kant-gymnasium.test\Policies\{0F968AEF-4554-43D1-911F-CB36BC5AF9B0}\User\Preferences\Shortcuts"

$OutputPath = Join-Path `
    $GpoShortcutsFolder `
    "Shortcuts.xml"

$BackupPath = Join-Path `
    $GpoShortcutsFolder `
    "Shortcuts.xml.bak"

# ------------------------------------------------------------
# Überschrift
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== GPO-Shortcuts konfigurieren ==="
Write-Output ""

# ------------------------------------------------------------
# Klassenordner prüfen
# ------------------------------------------------------------

if (-not (Test-Path $ClassFolder -PathType Container)) {

    Write-Output "[FEHLER] Klassenordner wurde nicht gefunden:"
    Write-Output "         $ClassFolder"

    exit 1
}

try {

    $ClassDirectories = Get-ChildItem `
        -Path $ClassFolder `
        -Directory `
        -ErrorAction Stop

}
catch {

    Write-Output "[FEHLER] Klassenordner konnten nicht gelesen werden:"
    Write-Output "         $($_.Exception.Message)"

    exit 1
}

# ------------------------------------------------------------
# Nur gültige Klassennamen berücksichtigen
# ------------------------------------------------------------

$Classes = @(
    $ClassDirectories |
        Where-Object {
            $_.Name -match '^[0-9]+[a-z]$'
        } |
        Select-Object -ExpandProperty Name |
        Sort-Object
)


Write-Output "=== Klassen aus Fileserver ermitteln ==="
Write-Output ""

if ($Classes.Count -eq 0) {

    Write-Output "[WARNUNG] Keine gültigen Klassenordner gefunden."

}
else {

    Write-Output "[OK] $($Classes.Count) Klassenordner gefunden."

    foreach ($Class in $Classes) {

        Write-Output "      - $Class"
    }
}

# ------------------------------------------------------------
# Zielordner prüfen
# ------------------------------------------------------------

if (-not (Test-Path $GpoShortcutsFolder -PathType Container)) {

    Write-Output ""
    Write-Output "[FEHLER] GPO-Shortcut-Ordner wurde nicht gefunden:"
    Write-Output "         $GpoShortcutsFolder"

    exit 1
}

# ------------------------------------------------------------
# Bestehende Shortcuts.xml sichern
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Bestehende GPO-Konfiguration sichern ==="
Write-Output ""

if (Test-Path $OutputPath -PathType Leaf) {

    try {

        Copy-Item `
            -Path $OutputPath `
            -Destination $BackupPath `
            -Force `
            -ErrorAction Stop

        Write-Output "[GESICHERT] $BackupPath"

    }
    catch {

        Write-Output "[FEHLER] Bestehende Shortcuts.xml konnte nicht gesichert werden:"
        Write-Output "         $($_.Exception.Message)"

        exit 1
    }

}
else {

    Write-Output "[INFO] Keine bestehende Shortcuts.xml gefunden."
}

# ------------------------------------------------------------
# XML-Struktur erstellen
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Shortcut-Konfiguration erzeugen ==="
Write-Output ""

$XmlWriterSettings = New-Object `
    System.Xml.XmlWriterSettings

$XmlWriterSettings.Indent = $true
$XmlWriterSettings.Encoding = New-Object `
    System.Text.UTF8Encoding($false)
$XmlWriterSettings.OmitXmlDeclaration = $false

try {

    # --------------------------------------------------------
    # XML direkt in die Zieldatei schreiben
    # --------------------------------------------------------

    $XmlWriter = [System.Xml.XmlWriter]::Create(
        $OutputPath,
        $XmlWriterSettings
    )

    $XmlWriter.WriteStartDocument()

    $XmlWriter.WriteStartElement(
        "Shortcuts"
    )

    $XmlWriter.WriteAttributeString(
        "clsid",
        "{872ECB34-B2EC-401b-A585-D32574AA90EE}"
    )


    # --------------------------------------------------------
    # Hilfsfunktion für Shortcut-Elemente
    # --------------------------------------------------------

    function Add-Shortcut {

        param (
            [string]$Name,
            [string]$TargetPath,
            [string[]]$Groups
        )


        $XmlWriter.WriteStartElement(
            "Shortcut"
        )

        $XmlWriter.WriteAttributeString(
            "clsid",
            "{4F2F7C55-2790-433e-8127-0739D1CFA327}"
        )

        $XmlWriter.WriteAttributeString(
            "name",
            $Name
        )

        $XmlWriter.WriteAttributeString(
            "status",
            $Name
        )

        $XmlWriter.WriteAttributeString(
            "image",
            "1"
        )

        $XmlWriter.WriteAttributeString(
            "removePolicy",
            "1"
        )

        $XmlWriter.WriteAttributeString(
            "userContext",
            "1"
        )

        $XmlWriter.WriteAttributeString(
            "bypassErrors",
            "1"
        )

        # ----------------------------------------------------
        # Properties
        # ----------------------------------------------------

        $XmlWriter.WriteStartElement(
            "Properties"
        )

        $XmlWriter.WriteAttributeString(
            "pidl",
            ""
        )

        $XmlWriter.WriteAttributeString(
            "targetType",
            "FILESYSTEM"
        )

        $XmlWriter.WriteAttributeString(
            "action",
            "R"
        )

        $XmlWriter.WriteAttributeString(
            "comment",
            ""
        )

        $XmlWriter.WriteAttributeString(
            "shortcutKey",
            "0"
        )

        $XmlWriter.WriteAttributeString(
            "startIn",
            ""
        )

        $XmlWriter.WriteAttributeString(
            "arguments",
            ""
        )

        $XmlWriter.WriteAttributeString(
            "iconIndex",
            "0"
        )

        $XmlWriter.WriteAttributeString(
            "targetPath",
            $TargetPath
        )

        $XmlWriter.WriteAttributeString(
            "iconPath",
            ""
        )

        $XmlWriter.WriteAttributeString(
            "window",
            ""
        )

        $XmlWriter.WriteAttributeString(
            "shortcutPath",
            "%DesktopDir%\$Name"
        )

        $XmlWriter.WriteEndElement()

        # ----------------------------------------------------
        # Zielgruppenadressierung
        # ----------------------------------------------------

        $XmlWriter.WriteStartElement(
            "Filters"
        )


        if ($Groups.Count -eq 1) {

            $XmlWriter.WriteStartElement(
                "FilterGroup"
            )

            $XmlWriter.WriteAttributeString(
                "bool",
                "AND"
            )

            $XmlWriter.WriteAttributeString(
                "not",
                "0"
            )

            $XmlWriter.WriteAttributeString(
                "name",
                $Groups[0]
            )

            $XmlWriter.WriteAttributeString(
                "sid",
                ""
            )

            $XmlWriter.WriteAttributeString(
                "userContext",
                "1"
            )

            $XmlWriter.WriteAttributeString(
                "primaryGroup",
                "0"
            )

            $XmlWriter.WriteAttributeString(
                "localGroup",
                "0"
            )

            $XmlWriter.WriteEndElement()

        }
        else {

            # ------------------------------------------------
            # Mehrere Gruppen = OR
            # ------------------------------------------------

            $FirstGroup = $true

            foreach ($Group in $Groups) {

                $XmlWriter.WriteStartElement(
                    "FilterGroup"
                )

                if ($FirstGroup) {

                    $XmlWriter.WriteAttributeString(
                        "bool",
                        "AND"
                    )

                    $FirstGroup = $false

                }
                else {

                    $XmlWriter.WriteAttributeString(
                        "bool",
                        "OR"
                    )
                }

                $XmlWriter.WriteAttributeString(
                    "not",
                    "0"
                )

                $XmlWriter.WriteAttributeString(
                    "name",
                    $Group
                )

                $XmlWriter.WriteAttributeString(
                    "sid",
                    ""
                )

                $XmlWriter.WriteAttributeString(
                    "userContext",
                    "1"
                )

                $XmlWriter.WriteAttributeString(
                    "primaryGroup",
                    "0"
                )

                $XmlWriter.WriteAttributeString(
                    "localGroup",
                    "0"
                )

                $XmlWriter.WriteEndElement()
            }
        }


        $XmlWriter.WriteEndElement()
        $XmlWriter.WriteEndElement()
    }

    # --------------------------------------------------------
    # Lehrer
    # --------------------------------------------------------

    Add-Shortcut `
        -Name "Lehrer" `
        -TargetPath "\\DC01\Lehrer" `
        -Groups @(
            "GG_Lehrkraefte"
        )

    Write-Output "[ERZEUGT] Lehrer"


    # --------------------------------------------------------
    # Schüler
    # --------------------------------------------------------

    Add-Shortcut `
        -Name "Schueler" `
        -TargetPath "\\DC01\Schueler" `
        -Groups @(
            "GG_Schueler",
            "GG_Lehrkraefte_Schueler"
        )

    Write-Output "[ERZEUGT] Schueler"


    # --------------------------------------------------------
    # Klassen
    # --------------------------------------------------------

    foreach ($Class in $Classes) {

        $ShortcutName = "Klasse_$Class"

        $TargetPath = "\\DC01\$ShortcutName"

        $StudentGroup = "GG_Klasse_$Class"

        $TeacherGroup = "GG_Lehrer_Klasse_$Class"


        Add-Shortcut `
            -Name $ShortcutName `
            -TargetPath $TargetPath `
            -Groups @(
                $StudentGroup,
                $TeacherGroup
            )

        Write-Output "[ERZEUGT] $ShortcutName"
    }

    # --------------------------------------------------------
    # Verwaltung
    # --------------------------------------------------------

    Add-Shortcut `
        -Name "Verwaltung" `
        -TargetPath "\\DC01\Verwaltung" `
        -Groups @(
            "GG_Verwaltung"
        )

    Write-Output "[ERZEUGT] Verwaltung"


    # --------------------------------------------------------
    # XML abschließen
    # --------------------------------------------------------

    $XmlWriter.WriteEndElement()

    $XmlWriter.WriteEndDocument()

    $XmlWriter.Flush()
    $XmlWriter.Close()

}
catch {

    if ($XmlWriter) {
        $XmlWriter.Close()
    }

    Write-Output ""
    Write-Output "[FEHLER] XML-Datei konnte nicht erzeugt werden:"
    Write-Output "         $($_.Exception.Message)"

    Write-Output ""
    Write-Output "[INFO] Die Sicherung der vorherigen XML-Datei bleibt erhalten:"
    Write-Output "       $BackupPath"

    exit 1
}

# ------------------------------------------------------------
# Ergebnis
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Zusammenfassung ==="
Write-Output ""

Write-Output "Klassen erkannt:       $($Classes.Count)"
Write-Output "Shortcuts erzeugt:     $(3 + $Classes.Count)"

Write-Output ""
Write-Output "[OK] Shortcuts.xml wurde aktualisiert."

Write-Output ""
Write-Output "Zieldatei:"
Write-Output " $OutputPath"

if (Test-Path $BackupPath -PathType Leaf) {

    Write-Output ""
    Write-Output "Sicherung:"
    Write-Output " $BackupPath"
}

Write-Output ""
Write-Output "GPO-Shortcut-Konfiguration abgeschlossen."
