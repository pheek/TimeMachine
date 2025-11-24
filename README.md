Generationenbackup
==================

1. Ertelle ein neues Verzeichnis mit aktuellem Datum im Format

   2025_11_22  (JJJJ_MM_DD)

2. Kopiere alles vom letzten Backup mit Hardlinks ins neue Verzeichnis:
   cp -al 2025_11_21 2025_11_22

3. backupe den Master ins neue Verzeichnis. Dabei werden auch Dateien auf dem
   Master gelöscht, Verzeichnsse verschoben etc.	

