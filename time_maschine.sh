#!/bin/bash
#
# Time Machine
# (c) google gemini & pheek 2025

## -- 1 --
# Vorausetzung:
# Setze Master-To, wohin soll gebackupt werden? Wo ist genau die Time-Machine?
# Es wird gepüft, ob das aktuelle Skript (time_machin.sh) sich in der Time_Machine/ befindet.
#

SCRIPT_PATH=$(readlink -f "$0")
TIME_MACHINE_DIR=$(dirname "${SCRIPT_PATH}")

## -- 2 --
# Finde nun den Master. Woher soll gebackupt werden?
# dies wird später in die Variable FROM_DIR geschieben
#

# Definiere das globale Array zur Speicherung der Kandidaten
declare -g POSSIBLE_MASTER_DIRECTORIES=()

# 2.1 Routine: Findet alle gültigen Master-Mount-Punkte und füllt die globale Variable.
# Diese Funktion führt die Datengewinnung, Filterung und die Fehlerprüfung "kein Laufwerk gefunden" durch.
find_master_candidates() {
    local line
    POSSIBLE_MASTER_DIRECTORIES=() # Array zurücksetzen

    # 1. Populate array with mount points under /media/, excluding TIME_MACHINE_DIR
    while IFS= read -r line; do
        if [[ "$line" != "$TIME_MACHINE_DIR" ]]; then
            POSSIBLE_MASTER_DIRECTORIES+=("$line")
        fi
    done < <(mount | grep '/media/' | awk '{print $3}')

    # 2. Fehlerprüfung
    if [ ${#POSSIBLE_MASTER_DIRECTORIES[@]} -eq 0 ]; then
        echo "FEHLER: Keine externen Laufwerke unter /media/ gefunden." >&2
        return 1
    fi
    return 0
}

# 2.2 Routine: Zeigt die Kandidaten und lässt den Benutzer wählen. (Rein funktionale Routine)
select_master_dir() {
    # 1. Statusmeldungen
    {
        echo "--------------------------------------------------------" 
        echo "Bitte wähle das Quellverzeichnis (Master) für das Backup:" 
        echo "--------------------------------------------------------"
    } >&2
    
    # 2. Interaktives Menü mittels 'select' auf das globale Array
    PS3="Gib die Nummer des Master-Verzeichnisses ein: " >&2
    select DIR in "${POSSIBLE_MASTER_DIRECTORIES[@]}"; do
        if [[ -n "$DIR" ]]; then
            echo "Du hast das folgende Master-Verzeichnis gewählt: ${DIR}" >&2
            echo "--------------------------------------------------------" >&2
            echo "${DIR}" # Gibt den Pfad über stdout zurück
            return 0
        else
            echo "Ungültige Eingabe. Bitte eine Nummer aus der Liste wählen." >&2
        fi
    done
}

# Zuerst Kandidaten finden und bei Fehler abbrechen
find_master_candidates 
if [ $? -ne 0 ]; then
    exit 1 # Beendet das Skript, wenn find_master_candidates fehlschlägt
fi

# Dann Auswahl durchführen
FROM_DIR=$(select_master_dir)
if [ $? -ne 0 ]; then
    echo "Skript abgebrochen."
    exit 1
fi


## -- 3 --
# Wie soll das neue Backup heißen? YYYY_MM_DD

NEW_DATE=$(date +%Y_%m_%d)
NEW_DATE_DIR="${TIME_MACHINE_DIR}/${NEW_DATE}"

## -- 4 --
# Finde neusten Snapshot unter den bisherigen
# Sucht alle Verzeichnisse im Format YYYY_MM_DD, sortiert absteigend und nimmt das Neueste
LATEST_SNAPSHOT=$(find "${TIME_MACHINE_DIR}" -maxdepth 1 -type d -regextype egrep -regex '.*/[0-9]{4}_[0-9]{2}_[0-9]{2}' | sort -r | head -n 1)

## -- 5 --
# PRÜFUNG: Muss mindestens einen alten Snapshot finden ---
if [ -z "${LATEST_SNAPSHOT}" ]; then
    echo "--------------------------------------------------------"
    echo "FEHLER: Noch kein Snapshot im Verzeichnis '${TIME_MACHINE_DIR}' gefunden."
    echo "Stehst Du im korrekten Laufwerk/Verzeichnis?"
    echo "Bitte den ersten Snapshot manuell erstellen oder das Verzeichnis prüfen."
    echo "--------------------------------------------------------"
    exit 1 # Skript mit Fehler beenden
fi

## -- 6 --
# Setze die Variablen für den alten Snapshot
OLD_DATE=$(basename "${LATEST_SNAPSHOT}")
OLD_DATE_DIR="${TIME_MACHINE_DIR}/${OLD_DATE}"


if [ "${OLD_DATE_DIR}" == "${NEW_DATE_DIR}" ]; then
    echo "--------------------------------------------------------"
    echo "ACHTUNG: Snapshot für den heutigen Tag (${NEW_DATE}) existiert bereits (OLD_DATE == NEW_DATE)!"
    echo "Bitte warte bis morgen für einen neuen inkrementellen Snapshot."
    echo "--------------------------------------------------------"
    exit 1 # Erfolgreich beenden, da keine Aktion erforderlich ist.
fi


## -- 7 --
# Cross-check: User soll sehen, was geschieht, und die Möglichkeit haben, dies noch abzubrechen
echo "Alter Snapshot  : ${OLD_DATE_DIR}"
echo "Neuer Snapshot  : ${NEW_DATE_DIR}"
echo "MASTER Directory: ${FROM_DIR}"

read -r -p "Willst Du das Backup nun starten? Das kann mehrere Minuten daurern? (J/n) " RESPONSE

if [[ ! "$RESPONSE" =~ ^([jJ][aA]|[jJ]|"")$ ]]; then
    echo "Prozess vom Benutzer abgebrochen."
    exit 0
fi

## -- 8 --
# Hauptroutine
# a) erstelle Verzeichnis
# b) Kopiere via Hard Link
# c) Synce aus Master

## a) Erstelle neues Verzeichnis
mkdir ${NEW_DATE_DIR}

## b) Kopiere via Hardlinks alles vom alten ins neue directory
cp -al ${OLD_DATE_DIR}/* ${NEW_DATE_DIR}

## c) sync alle Hauptverzeichnisse
MAIN_DIRECTORIES=("fotos" "audio" "scans" "bilder" "video")

for MAIN_DIR in "${MAIN_DIRECTORIES[@]}"; do
		echo "  -- sync ${MAIN_DIR}"
		rsync -a --delete \
          --link-dest="${OLD_DATE_DIR}/${MAIN_DIR}" \
          "${FROM_DIR}/${MAIN_DIR}/" \
          "${NEW_DATE_DIR}/${MAIN_DIR}/"
		
		if [ $? -ne 0 ]; then
        echo "FEHLER: rsync für ${MAIN_DIR} fehlgeschlagen!"
        exit 1
    fi
done
