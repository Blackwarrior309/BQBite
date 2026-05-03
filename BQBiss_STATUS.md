# BQBiss aktueller Stand

Stand: 2026-05-03

## Addon-Ziel

BQBiss ist ein WoW-3.3.5-Addon für Blood-Queen Lana'thel. Es verwaltet eine Prioritätsliste für Vampirbisse, berechnet live die nächste Biss-Zuordnung und kann diese lokal oder in Chatkanäle ansagen.

## Dateien

- `BQBiss.toc` lädt `Core.lua`, `Announce.lua`, `Auto.lua`, `UI.lua`, `Slash.lua`.
- `Core.lua` enthält State, Spielerstatus, Raidmetadaten, Rollen, Prioritätsliste, Bissberechnung, Raidmarker, Debug-Simulation und Timer-Logik.
- `Announce.lua` enthält Ansagekanal und chat-sichere Ausgabe.
- `Auto.lua` enthält Combat-Log-Erkennung für Essence und Frenzied Bloodthirst.
- `UI.lua` enthält Hauptfenster, Minimap-Button und Debug-Fenster.
- `Slash.lua` enthält `/bq` Commands.

## Implementiert

- Spieler manuell hinzufügen, entfernen und sortieren.
- Spieler per Drag-and-drop in der Prioritätsliste verschieben.
- Rechte Scrollbar und Mausrad für die Prioritätsliste.
- Raidmitglieder manuell importieren über UI oder `/bq import`.
- Raid-Import liest Name, Klasse und Gruppe; nicht mehr im Raid vorhandene Spieler werden entfernt.
- Status manuell setzen: `PRIO`, `VAMPIRE`, `DEAD`, `MC`.
- Rolle manuell setzen: `DD`, `HEAL`, `TANK`, `UNKNOWN`.
- Rollen-Sortierung: `DD`, dann `UNKNOWN`, dann `HEAL`, dann `TANK`.
- Dynamische Bissberechnung:
  - Beißer sind Spieler mit Status `VAMPIRE`.
  - Ziele sind die nächsten Spieler mit Status `PRIO`.
  - `DEAD` und `MC` werden nicht als Ziel oder Beißer genutzt, weil sie nicht `PRIO`/`VAMPIRE` sind.
- Ansageformat:
  - `Biss: SpielerA -> SpielerB G5`
  - Rundenansagen mit Marker-Namen wie `Stern: SpielerA -> SpielerB G5`
  - mehrere Bisse werden einzeln untereinander gesendet.
- Falschbiss-Ansage:
  - `SpielerX G4 wurde gebissen, SpielerY G5 noch frei`
- Ansagekanäle: `LOCAL`, `RAID`, `PARTY`, `SAY`.
- Lokaler Testmodus ist standardmäßig aktiv und blockiert Chatansagen in Raid/Party/Say.
- Chat-Ausgabe wird sanitized, damit WoW keine Invalid-Escape-Fehler durch `|` bekommt.
- `Pull-Test` bereitet den HC-Test vor: nur lokal, Auto AN, Planung gestartet, keine Chatansage.
- `Start+Ansage` ist per Slash weiterhin verfügbar und startet Planung mit Ansage.
- `Nächste Ansage` wiederholt die aktuelle Berechnung.
- `Raid Import` importiert aktuelle Raidmitglieder.
- `Marker AN/AUS` schaltet automatische Raidmarker für nächste Bissziele.
- `Nur Lokal` schaltet den lokalen Testmodus.
- Rollenbuttons `DD`, `HEAL`, `TANK`, `UNK` setzen die Rolle der Auswahl.
- Minimap-Icon:
  - Linksklick öffnet/schließt BQBiss.
  - Ziehen verschiebt das Icon.
  - Rechtsklick blendet es aus.
  - `/bq minimap` zeigt es wieder.
- Debug-Fenster:
  - `/bq debug` oder Button `Debug`.
  - `BQ Menü` öffnet das Hauptfenster.
  - Name kann eingegeben oder per `Auswahl` vom selektierten Spieler übernommen werden.
  - `Essenz` simuliert Essence, setzt Spieler auf `VAMPIRE` und startet 60s-Testtimer.
  - `Blutdurst` simuliert Frenzied Bloodthirst und sagt `Biss: Name -> Ziel` an.
  - `Timer 10s` und `Timer 60s` setzen Testtimer.
  - Timer-Anzeige zeigt live den nächsten fälligen Beißer, sein Ziel und weitere laufende Beißer-Timer.
  - Hauptliste zeigt laufende simulierte und echte Biss-Timer direkt in der Timer-Spalte.
  - `Nächster fällig` übernimmt den nächsten Timer-Spieler ins Debug-Eingabefeld.
  - `Timer weg` löscht den Timer des ausgewählten/eingetragenen Spielers.
  - `Alle Bisse OK` markiert alle aktuell zugewiesenen Ziele als `VAMPIRE`, startet für alle beteiligten Beißer und neuen Vampire jeweils einen neuen 60s-Timer und trägt das letzte Ziel ins Debug-Eingabefeld ein.

## Auto-Erkennung

`Auto.lua` registriert `COMBAT_LOG_EVENT_UNFILTERED`.

Wenn `BQBissDB.started == true` und `BQBissDB.auto == true`:

- `SPELL_AURA_APPLIED` mit Essence-IDs setzt `destName` auf `VAMPIRE`.
- `SPELL_AURA_APPLIED` mit Bloodthirst-IDs setzt `destName` auf `VAMPIRE` und sagt genau diesen Biss an.
- Vampiric-Bite-Events setzen Quelle und Ziel auf `VAMPIRE` und starten für beide jeweils 60s-Timer neu.
- Vampiric-Bite-Events werden gegen die geplante Zuordnung geprüft; falsche Ziele werden angesagt.
- `SPELL_AURA_APPLIED` mit Mind-Control-ID setzt `destName` auf `MC`; `UNIT_DIED` setzt bekannte Spieler auf `DEAD`. Beides entfernt laufende Timer.
- Bloodthirst hat einen 2s-Anti-Spam pro Spieler.

Spell-IDs:

- Essence: `70867`, `70879`, `71473`, `71525`, `71530`, `71531`, `71532`, `71533`
- Bloodthirst: `70877`, `71474`
- MC vorbereitet im Core: `70923`
- Vampiric Bite vorbereitet im Core: `71726`, `71727`, `71728`, `71729`, `71475`, `71476`, `71477`, `70946`

## Slash Commands

- `/bq` UI öffnen/schließen
- `/bq pull` Pull-Test vorbereiten, nur lokal und Auto AN
- `/bq start` starten und ansagen
- `/bq reset` Status auf `PRIO` zurücksetzen
- `/bq next` nächste Ansage
- `/bq wrong NAME` falschen Biss als Vampir markieren
- `/bq import` Raidmitglieder importieren
- `/bq role NAME dd|heal|tank|unknown` Rolle setzen
- `/bq markers on|off` Raidmarker schalten
- `/bq local on|off` Chatansagen sperren oder erlauben
- `/bq channel local|raid|party|say` Ansagekanal setzen
- `/bq minimap` Minimap-Icon anzeigen
- `/bq debug` Debug-Fenster öffnen

## Bekannte Hinweise

- Nach Änderungen im Addon immer `/reload` im WoW-Client ausführen.
- Lua-5.1-Syntaxcheck wurde zuletzt erfolgreich ausgeführt mit:
  `C:\Program Files (x86)\Lua\5.1\luac.exe -p Core.lua Announce.lua Auto.lua UI.lua Slash.lua`
- Lua 5.1 ist installiert unter:
  `C:\Program Files (x86)\Lua\5.1\lua.exe`
- Das aktuelle PowerShell-Fenster sieht `lua` evtl. nicht automatisch im PATH; bei Bedarf vollen Pfad nutzen.

## Nächste sinnvolle Schritte

- Wiederbelebung/Status-Rückkehr implementieren: Raid-Roster oder Unit-Events, Status `DEAD`/`MC` zurück zu `PRIO` bzw. `VAMPIRE`.
- Optional: Raid-Spieler automatisch importieren.
- Optional: Klassenfarben und bessere Scrollliste.

