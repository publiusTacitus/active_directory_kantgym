# ============================================================
# 09-configure-file-server.ps1
#
# Konfiguriert die Firewall für SMB und erstellt Testdateien.
#
# Die Testdateien werden automatisch für die tatsächlich
# vorhandenen Klassenordner unter C:\Shares\Klassen erstellt.
#
# Das Skript ist idempotent und kann mehrfach ausgeführt werden.
# ============================================================

Write-Output ""
Write-Output "=== Konfiguration des Fileservers ==="
Write-Output ""

# ------------------------------------------------------------
# SMB-Firewallregel für Domain-Profil
# ------------------------------------------------------------

$SmbRule = Get-NetFirewallRule `
    -DisplayName "Datei- und Druckerfreigabe (SMB eingehend)" `
    -ErrorAction SilentlyContinue

if (-not $SmbRule) {

    Write-Output "[FEHLER] SMB-Firewallregel wurde nicht gefunden."
    exit 1
}

Set-NetFirewallRule `
    -DisplayName "Datei- und Druckerfreigabe (SMB eingehend)" `
    -Profile Domain

Write-Output "[OK] SMB eingehend fuer Domain-Profil aktiviert."

# ------------------------------------------------------------
# Testdateien
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== Testdateien ==="
Write-Output ""

$TestFiles = @{}

# ------------------------------------------------------------
# Statische Bereiche
# ------------------------------------------------------------

$TestFiles["C:\Shares\Schueler\README.txt"] = "Schülerbereich"
$TestFiles["C:\Shares\Lehrer\README.txt"] = "Lehrerbereich"
$TestFiles["C:\Shares\Verwaltung\README.txt"] = "Verwaltungsbereich"

# ------------------------------------------------------------
# Klassen aus vorhandenen Ordnern ermitteln
# ------------------------------------------------------------

$ClassFolder = "C:\Shares\Klassen"

if (-not (Test-Path $ClassFolder)) {

    Write-Output "[FEHLER] Klassenordner wurde nicht gefunden:"
    Write-Output "         $ClassFolder"
    exit 1
}

$ClassDirectories = Get-ChildItem `
    -Path $ClassFolder `
    -Directory `
    -ErrorAction Stop

Write-Output "[OK] $($ClassDirectories.Count) Klassenordner gefunden."

foreach ($ClassDirectory in $ClassDirectories) {

    $ClassName = $ClassDirectory.Name

    $TestFilePath = Join-Path `
        $ClassDirectory.FullName `
        "README.txt"

    $TestFiles[$TestFilePath] = "Klasse $ClassName"

    Write-Output "[KLASSE] $ClassName"
}

# ------------------------------------------------------------
# Dateien erstellen
# ------------------------------------------------------------

foreach ($File in $TestFiles.Keys) {

    if (Test-Path $File) {

        Write-Output "[VORHANDEN] $File"
    }
    else {

        try {

            Set-Content `
                -Path $File `
                -Value $TestFiles[$File] `
                -Encoding UTF8 `
                -ErrorAction Stop

            Write-Output "[ERSTELLT]  $File"
        }
        catch {

            Write-Output "[FEHLER] Testdatei konnte nicht erstellt werden:"
            Write-Output "         $File"
            Write-Output "         $($_.Exception.Message)"
        }
    }
}

# ------------------------------------------------------------
# Diagnose
# ------------------------------------------------------------

Write-Output ""
Write-Output "=== SMB-Firewallregel ==="

Get-NetFirewallRule `
    -DisplayName "Datei- und Druckerfreigabe (SMB eingehend)" |
    Select-Object DisplayName, Enabled, Profile

Write-Output ""
Write-Output "Fileserver-Konfiguration abgeschlossen."