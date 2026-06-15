# Milestone 14 - Polish Finale e Presentabilita

## Stato

Completata come chiusura del visual gameplay pass.

## Obiettivo

Portare la zombie survival a una presentazione coerente dall'inizio della wave
alla sconfitta del boss, eliminando gli ultimi elementi principali da
prototipo tecnico senza cambiare regole o bilanciamento.

## Implementato

- `WaveWardenVisual` procedurale e sostituibile;
- silhouette segmentata con piastre, nucleo, occhio direzionale e nodi orbitanti;
- palette e geometria piu aggressiva in fase 2;
- feedback sul corpo per spawn, hit e carica dei pattern;
- profili distinti per proiettili aimed e radial del boss;
- glow e trail sui proiettili ostili;
- effetto world-space dedicato alla morte del boss;
- pannello boss centrato e responsive;
- `CombatAnnouncement` per intermissione, wave start, wave clear, boss,
  overdrive, sconfitta boss e fine run;
- precedenza degli annunci importanti per evitare sovrascritture di un frame;
- smoke test M14 e QA completa con quattro player a 1280x720.

## Linguaggio visuale del Wave Warden

### Fase 1

- piastre viola separate da un corpo centrale scuro;
- nucleo ciano pulsante;
- marker arancio orientato verso il target;
- anelli e satelliti energetici in rotazione lenta.

### Fase 2

- piastre rosso-magenta;
- spine esterne piu aggressive;
- nucleo arancio;
- rotazione e pulsazione piu rapide;
- annuncio `OVERDRIVE` coordinato con HUD e telegraph.

### Attacchi

- aimed: carica magenta e proiettili viola con trail;
- radial: carica arancio e proiettili corallo;
- il corpo comunica il pattern, mentre `BossTelegraphVisual` continua a
  mostrare area e timing del pericolo.

## Contratto tecnico

- `BasicBoss` resta autoritativo per target, movimento, fase, pattern e danno.
- `WaveWardenVisual` riceve solo direzione, fase, hit e stato di carica.
- `CombatAnnouncement` non legge o modifica lo stato gameplay.
- `HUDManager` traduce segnali pubblici in messaggi temporanei.
- I profili proiettile usano `WeaponVisualData` senza cambiare collisioni.
- `GameplayEffects` genera l'effetto morte dopo il danno letale senza
  ritardare drop, segnali o completamento della wave.

## Verifica automatica

```text
godot --headless --path . --script res://tests/milestone_14_final_polish_smoke_test.gd
godot --headless --path . --script res://tests/boss_smoke_test.gd
godot --headless --path . --script res://tests/survival_wave_smoke_test.gd
godot --headless --path . --script res://tests/dungeon_smoke_test.gd
godot --headless --path . --script res://tests/tower_defense_smoke_test.gd
```

QA visuale:

```text
godot --path . --rendering-method gl_compatibility --script res://tests/final_survival_visual_qa.gd
```

Output:

```text
build/qa/milestone_14_wave_presentation.png
build/qa/milestone_14_boss_phase_one.png
build/qa/milestone_14_boss_phase_two.png
build/qa/milestone_14_boss_defeat.png
```

## Checklist manuale

- Avviare survival con 1-4 player e verificare `GET READY` e `WAVE`.
- Controllare che gli annunci non coprano permanentemente attori o HUD.
- Raggiungere la boss wave e identificare il `Wave Warden` dalla silhouette.
- Verificare orientamento dell'occhio verso il target.
- Confrontare aimed e radial per colore, carica, trail e telegraph.
- Danneggiare il boss e verificare il flash breve.
- Portarlo sotto il 50% e verificare palette, spine e annuncio `OVERDRIVE`.
- Ucciderlo e verificare effetto morte, `WARDEN DOWN` e drop speciale.
- Confermare che wave clear non venga sostituito subito da `GET READY`.
- Passare a dungeon e tower defense e verificare il boss condiviso.

## Fuori scope

- sprite e animazioni disegnate definitive;
- camera shake e freeze frame;
- impostazioni accessibilita per intensita effetti;
- mix audio con asset registrati;
- nuovi boss, nuovi pattern o nuove armi;
- schermate victory/game over dedicate.
