# BQBiss / BQBite

WoW 3.3.5a Addon für Blood-Queen Lana'thel. Das Addon plant Vampirbisse, zeigt aktive Beißer und Timer an, unterstützt Raid-Import, Rollen-Priorisierung und automatische Combat-Log-Erkennung.

## Funktionen

- Prioritätsliste für Bissziele
- Drag-and-drop zum Verschieben von Spielern in der Prioritätsliste
- Scrollbar rechts und Mausrad zum Scrollen durch die Liste
- Status pro Spieler: `PRIO`, `VAMPIRE`, `MC`, `DEAD`
- Rollen pro Spieler: `DD`, `HEAL`, `TANK`, `UNKNOWN`
- Keine Auto-Priorität nach Damage oder festen Klassenregeln
- Heiler und Tanks werden in der Priorität nach unten geschoben
- manueller Raid-Import über UI oder `/bq import`
- Anzeige von Klasse, Rolle und Raidgruppe
- Ansagen mit Zielgruppe, z.B. `Biss: SpielerA -> SpielerB G5`
- automatische Raidmarker für nächste Bissziele
- Erkennung von Essence, Frenzied Bloodthirst, Mind Control, Tod und Vampiric Bite
- Falschbiss-Ansage, z.B. `SpielerX G4 wurde gebissen, SpielerY G5 noch frei`
- simulierte und echte Biss-Timer in Debugfenster und Hauptliste

## Installation

Den Ordner `BQBiss` in den WoW-Addon-Ordner kopieren:

```text
Interface\AddOns\BQBiss
```

Danach im Spiel `/reload` ausführen oder den Client neu starten.

## Bedienung

- `/bq` öffnet oder schließt das Hauptfenster
- `/bq pull` bereitet den Pull-Test vor: nur lokal, Auto AN, keine Raidchat-Ansage
- `/bq start` startet Planung und Auto-Erkennung
- `/bq reset` setzt Status zurück
- `/bq next` sagt die nächste Bissplanung an
- `/bq import` importiert aktuelle Raidmitglieder
- `/bq role NAME dd|heal|tank|unknown` setzt eine Rolle
- `/bq markers on|off` schaltet Raidmarker
- `/bq local on|off` sperrt oder erlaubt Chatansagen
- `/bq channel local|raid|party|say` setzt den Ansagekanal
- `/bq debug` öffnet das Debugfenster

## Hinweise

Standardmäßig ist der lokale Testmodus aktiv. Dadurch werden alle Ansagen nur dir lokal im Chatfenster angezeigt und nicht in Raid, Party oder Say gesendet. Für den Raidtest vor dem Pull `Pull-Test` drücken oder `/bq pull` nutzen. Die erste echte Essenz setzt den ersten Vampir und startet seinen 60s-Timer.

Für Raidmarker werden im Raid passende Rechte benötigt. Wenn keine Rechte vorhanden sind, läuft das Addon weiter, setzt aber keine Marker.

Nach Änderungen am Addon immer `/reload` im WoW-Client ausführen.
