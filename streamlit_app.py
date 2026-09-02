
import streamlit as st
from pathlib import Path


# ---------------------------------------------------------
# Pfade
# ---------------------------------------------------------

BASE_DIR = Path(__file__).resolve().parent
ASSETS_DIR = BASE_DIR / "assets"
GRAPHS_DIR = ASSETS_DIR / "graphs"
SCREENSHOTS_DIR = ASSETS_DIR / "screenshots"
GPRESULTS_DIR = ASSETS_DIR / "gpresults"


# ---------------------------------------------------------
# Hilfsfunktionen
# ---------------------------------------------------------


def show_image(path, filename, caption=None, width="content"):
    """Zeigt ein Bild aus assets an."""

    path = path / filename

    if path.exists():
        st.image(path, caption=caption, width=width)
    else:
        st.warning(f"Bild nicht gefunden: {path}")


def gpresult_download(filename, label_):
    path = GPRESULTS_DIR / filename

    if path.exists():
        st.download_button(
            label=label_,
            data=path.read_bytes(),
            file_name=filename,
            mime="text/html",
            use_container_width=True
        )
    else:
        st.warning(f"Datei nicht gefunden: {path}")


# ---------------------------------------------------------
# Titel
# ---------------------------------------------------------

st.set_page_config(page_title="KANTGYM – Active-Directory", layout="wide")

st.title("KANTGYM – Automatisierte Active-Directory-Umgebung für ein fiktives Gymnasium", text_alignment="center")


# ---------------------------------------------------------
# Überblick
# ---------------------------------------------------------

st.markdown("---")

st.header("**Projektüberblick**", text_alignment="center")

st.space("xxsmall")

with st.container(border=True, horizontal_alignment="center"):

    st.markdown(
        """
        Dieses Projekt bildet eine realistische Active-Directory-Umgebung für ein fiktives deutsches Gymnasium ab. 
        Ziel ist eine zentral verwaltete Windows-Client-Infrastruktur mit automatisierter Benutzerverwaltung,
        rollenbasierten Berechtigungen, Dateifreigaben und Gruppenrichtliniensteuerung.
    
        Die Umgebung wurde vollständig in Hyper-V aufgebaut und anschließend 
        anhand verschiedener Benutzer- und Client-Szenarien getestet.
        """,
        text_alignment="center"
    )

st.space("small")

col1, col2, col3, col4 = st.columns(4)

with col1:
    st.metric("Domäne", "kant-gymnasium.test")

with col2:
    st.metric("Domänencontroller", "DC01")

with col3:
    st.metric("PowerShell-Skripte", "13")

with col4:
    st.metric("Gruppenrichtlinien (GPOs)", "13")


# ---------------------------------------------------------
# Infrastruktur
# ---------------------------------------------------------

st.markdown("---")

with st.container(horizontal_alignment="center"):

    st.header("1. Infrastruktur", text_alignment="center")

    st.markdown(
        """
        Ein Windows Server (2025) fungiert als zentraler Domain Controller mit DNS- und Dateiserverdiensten. 
        Die mit Windows-11-Education betriebenen Clients sind in Unterrichts-, Prüfungs-, Lehrkräfte- und 
        Verwaltungscomputer gruppiert.
        """,
        text_alignment="center"
    )

    show_image(
        GRAPHS_DIR,
        "01_KANTGYM_Infrastruktur.png",
        caption="KANTGYM – Infrastruktur und Server-/Client-Rollen",
    )


# ---------------------------------------------------------
# Active-Directory-Struktur
# ---------------------------------------------------------

st.markdown("---")

with st.container(horizontal_alignment="center"):

    st.header("2. Active-Directory-Struktur", text_alignment="center")

    st.markdown(
        """
        Benutzer, Computer und Gruppen werden getrennt in entsprechenden Organisationseinheiten (OUs) verwaltet. 
        Rollen- und Ressourcengruppen bilden die Grundlage für die spätere Rechtevergabe.
        """,
        text_alignment="center"
    )

    show_image(
        GRAPHS_DIR,
        "02_KANTGYM_AD_Struktur.png",
        caption="KANTGYM – Active-Directory-Struktur mit OUs und Gruppen",
    )


# ---------------------------------------------------------
# Berechtigungsmodell
# ---------------------------------------------------------

st.markdown("---")

with st.container(horizontal_alignment="center"):

    st.header("3. Berechtigungsmodell", text_alignment="center")

    st.markdown(
        """
        Die Berechtigungen folgen einem rollenbasierten Modell. Benutzer werden über globale Gruppen ihren 
        Rollen zugeordnet, während domänenlokale Gruppen die Zugriffsrechte auf konkrete Ressourcen steuern. 
        Dadurch bleiben Benutzerverwaltung und Ressourcenberechtigungen voneinander getrennt.
        """,
        text_alignment="center"
    )

    show_image(
        GRAPHS_DIR,
        "03_KANTGYM_Berechtigungsmodell.png",
        caption="KANTGYM – Rollenbasiertes Berechtigungsmodell",
    )

    st.caption(
        "Zusätzlich erhalten Lehrkräfte über GG_Lehrkraefte_Schueler "
        "Zugriff auf die Schülerfreigabe.",
        text_alignment="center"
    )


# ---------------------------------------------------------
# Gruppenrichtlinien
# ---------------------------------------------------------

st.markdown("---")

with st.container(horizontal_alignment="center"):

    st.header("4. Gruppenrichtlinien", text_alignment="center")

    st.markdown(
        """
        Steuerung zentraler Einstellungen für Benutzer und Computer. Umfasst unter anderem 
        Sicherheitsrichtlinien, Anmeldeberechtigungen, Geräteeinstellungen, Benutzeroberflächen 
        und den Zugriff auf Netzwerkfreigaben.
        """,
        text_alignment="center"
    )

    show_image(
        GRAPHS_DIR,
        "04_KANTGYM_Richtlinienobjekte.png",
        caption="KANTGYM – Gruppenrichtlinienstruktur und -zuordnung",
    )


st.space("xxsmall")
st.markdown("### Gruppenrichtlinienobjekte – Beispiele", text_alignment="center")
st.space("xxsmall")

col5, col6 = st.columns(2)

with col5:

    with st.container(height=50, border=False):

        st.markdown(
            """
            **GPO_Clients_Baseline** – Aktiviert grundlegende Sicherheitsvorgaben für Firewall, 
            Microsoft Defender Antivirus und Echtzeitschutz. Bei der Benutzeranmeldung wird 
            außerdem auf die Netzwerkverfügbarkeit gewartet.
            """,
            text_alignment="center"
        )

    show_image(
        SCREENSHOTS_DIR,
        "GPO_Clients_Baseline_Einstellungen.png",
        caption="GPO_Clients_Baseline",
    )

with col6:

    with st.container(height=50, border=False, horizontal_alignment="center"):

        st.markdown(
            """
            **GPO_Clients_Settings_Pruefung** – Sperrt den Zugriff auf Wechselmedien für Prüfungscomputer.
            """,
            text_alignment="center"
        )

    show_image(
        SCREENSHOTS_DIR,
        "GPO_Clients_Pruefung_Wechselmedien.png",
        caption="GPO_Clients_Settings_Pruefung",
    )


# ---------------------------------------------------------
# Benutzerdaten- und Provisionierungspipeline
# ---------------------------------------------------------

st.markdown("---")

with st.container(horizontal_alignment="center"):

    st.header("5. Benutzerdaten- und Provisionierungspipeline", text_alignment="center")

    st.markdown(
        """
        Die Benutzerverwaltung beginnt mit den strukturierten Stammdaten aus Excel. 
        PowerShell übernimmt Validierung, Aufbereitung und Provisionierung der Benutzer und Gruppen 
        in Active Directory. Anschließend werden Zugangsdaten, Dateistrukturen, Berechtigungen, Freigaben 
        und GPO-Verknüpfungen automatisiert eingerichtet.
        """,
        text_alignment="center"
    )

    col7, col8 = st.columns([4, 1])

    with col7:

        with st.container(border=False, horizontal_alignment="center"):

            show_image(
                GRAPHS_DIR,
                "05_Benutzerdaten_Pipeline.png",
                caption="KANTGYM – Automatisierte Benutzerdaten- und Provisionierungspipeline",
            )

    with col8:

        with st.container(border=True, horizontal_alignment="left"):

            st.subheader("Nicht abgebildete Skripte")

            st.markdown(
                """
                Dateiserver- und Freigabekonfiguration
                - 07_create-file-structure.ps1
                - 08_cleanup-file-structure.ps1
                - 09_configure-file-server.ps1
                - 10_configure-ntfs-permissions.ps1
                - 11_create-shares.ps1
                - 12_cleanup-old-class-shares.ps1
                """
            )

            st.markdown(
                """
                Gruppenrichtlinien
                - 13_create-gpo-shortcuts.ps1
                """
            )


# ---------------------------------------------------------
# Ergebnis auf dem Client
# ---------------------------------------------------------

st.markdown("---")

st.header("6. Ergebnis auf dem Client", text_alignment="center")

st.markdown(
    """
    Die konfigurierten Benutzer- und Gruppenrichtlinien führen abhängig von der Benutzerrolle zu 
    unterschiedlichen Arbeitsumgebungen. Neben den rollenabhängigen Einstellungen werden den 
    Benutzern automatisch die für ihre Aufgaben relevanten Netzwerkfreigaben bereitgestellt.
    """,
    text_alignment="center"
)

col9, col10, col11 = st.columns(3)

with col9:
    show_image(
        SCREENSHOTS_DIR,
        "Beispiel_Desktop_Schueler.png",
        caption="Schüler – rollenabhängige Desktop-Konfiguration und Netzwerkfreigaben",
        width="stretch"
    )

with col10:
    show_image(
        SCREENSHOTS_DIR,
        "Beispiel_Desktop_Lehrkraefte.png",
        caption="Lehrkräfte – rollenabhängige Desktop-Konfiguration und Netzwerkfreigaben",
        width="stretch"
    )

with col11:
    show_image(
        SCREENSHOTS_DIR,
        "Beispiel_Desktop_Verwaltung.png",
        caption="Verwaltung – rollenabhängige Desktop-Konfiguration und Netzwerkfreigaben",
        width="stretch"
    )


# ---------------------------------------------------------
# Tests und Validierung
# ---------------------------------------------------------

st.markdown("---")

st.header("7. Tests und Validierung", text_alignment="center")

st.markdown(
    """
    Die Umgebung wurde mit unterschiedlichen Benutzerrollen und Client-Zuordnungen getestet. 
    Überprüft wurden Benutzeranmeldung, Gruppenrichtlinien, rollenabhängige Netzwerkfreigaben 
    sowie computerspezifische Einstellungen der jeweiligen Client-OUs.

    Zusätzlich wurden die tatsächlich angewendeten Richtlinien mit `gpresult` kontrolliert.
    """,
    text_alignment="center"
)

st.space("xxsmall")

test_col1, test_col2, test_col3 = st.columns(3)

with test_col1:

    with st.container(border=True, horizontal_alignment="center"):

        st.markdown("**Schüler**")
        st.markdown(
            """
            - Anmeldung am Client erfolgreich
            - Schülerfreigabe verfügbar
            - Klassenfreigabe verfügbar
            - Benutzer-GPO angewendet
            """
        )

with test_col2:

    with st.container(border=True, horizontal_alignment="center"):

        st.markdown("**Lehrkräfte**")
        st.markdown(
            """
            - Anmeldung am Client erfolgreich
            - Lehrerfreigabe verfügbar
            - relevante Klassenfreigaben verfügbar
            - Benutzer-GPO angewendet
            """
        )

with test_col3:

    with st.container(border=True, horizontal_alignment="center"):

        st.markdown("**Verwaltung**")
        st.markdown(
            """
            - Anmeldung am Client erfolgreich
            - Verwaltungsfreigabe verfügbar
            - Verwaltungs-GPO angewendet
            - Zugriff auf nicht vorgesehene Bereiche eingeschränkt
            """
        )

st.space("xxsmall")

st.markdown("### Nachweis der angewendeten Richtlinien", text_alignment="center")

st.markdown(
    """
    Die erzeugten `gpresult`-Auswertungen dokumentieren die auf den jeweiligen Clients bzw. 
    für die jeweiligen Benutzer tatsächlich angewendeten Gruppenrichtlinien.
    """,
    text_alignment="center"
)

st.space("xxsmall")

gp_col1, gp_col2, gp_col3 = st.columns(3)

with gp_col1:
    st.markdown("**Schüler**", text_alignment="center")
    gpresult_download(
        "gpresult-schueler.html",
        "gpresult herunterladen"
    )

with gp_col2:
    st.markdown("**Lehrkräfte**", text_alignment="center")
    gpresult_download(
        "gpresult-lehrkraefte.html",
        "gpresult herunterladen"
    )

with gp_col3:
    st.markdown("**Verwaltung**", text_alignment="center")
    gpresult_download(
        "gpresult-verwaltung.html",
        "gpresult herunterladen"
    )


# ---------------------------------------------------------
# Technologien
# ---------------------------------------------------------

st.markdown("---")

st.header("8. Technologien", text_alignment="center")

st.space("xxsmall")

tech_cols = st.columns(6)

technologies = [
    ("Virtualisierung", "Hyper-V"),
    ("Server", "Windows Server 2025"),
    ("Clients", "Windows 11 Education"),
    ("Verzeichnisdienst", "Active Directory"),
    ("Automatisierung", "PowerShell"),
    ("Dokumentation", "Visio / Streamlit / Markdown"),
]

for col, (label, value) in zip(tech_cols, technologies):
    with col:
        st.markdown(f"**{label}**")
        st.write(value)


# ---------------------------------------------------------
# GitHub-Repository
# ---------------------------------------------------------

st.space("xxsmall")

st.markdown("---")

with st.container(horizontal_alignment="center"):

    st.markdown(
        """
        **Projekt auf GitHub**
    
        Das vollständige Projekt mit PowerShell-Skripten, Beispieldaten,
        technischen Diagrammen und Dokumentation ist auf GitHub verfügbar.
        """,
        text_alignment="center"
    )

    st.link_button(
        "Zum GitHub-Repository",
        "https://github.com/publiusTacitus/active_directory_kantgym",
        use_container_width=False
    )