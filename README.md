Generationenbackup
==================

# (c) pheek, Google Gemini (2025) - 2025_11_24
# Gemini (2025) basiert auf der Grundlagenforschung von Google/DeepMind

Nachdem Master und Zielverzeichnis ermittelt sind, werden die folgenden drei Schritte ausgeführt:

a) Ertelle ein neues Verzeichnis mit aktuellem Datum im Format

   2025_11_22  (JJJJ_MM_DD)

b) Kopiere alles vom letzten Backup mit Hardlinks ins neue Verzeichnis:
   cp -al 2025_11_21 2025_11_22

c) backupe den Master ins neue Verzeichnis. Dabei werden auch Dateien auf dem
   Master gelöscht, Verzeichnsse verschoben etc.	
   dies geschieht via "rsync". Details im Skript selbst.
