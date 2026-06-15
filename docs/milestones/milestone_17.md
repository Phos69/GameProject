# Milestone 17 - Fine Run, Risultati e Menu

## Stato

Completata come primo flusso UI condiviso.

## Obiettivo

Presentare vittoria, sconfitta e risultati reali della sessione con azioni
leggibili da tastiera e joypad.

## Implementato

- `RunSessionTracker` per durata, XP, denaro e unlock ottenuti;
- `RunResultsScreen` condivisa per tutte le modalita;
- titoli `RUN OVER`, `DUNGEON COMPLETE` e `DEFENSE FAILED`;
- riepilogo progressione e tempo reale della run;
- pulsanti grandi per retry, cambio modalita e menu;
- focus iniziale su retry;
- gameplay disattivato dietro l'overlay;
- retry sullo stesso nodo modalita e con ultimo context;
- salvataggio sincrono prima del ritorno al menu.

## Contratto

- Le modalita emettono i propri segnali di fine run.
- `RunSessionTracker` traduce i segnali in un dizionario risultato.
- `GameModeManager.finish_run()` arresta il runtime e conserva l'ID attivo.
- `retry_active_mode()` riusa il nodo registrato e ripristina i player.
- `change_to_next_mode()` segue survival, dungeon, tower defense.
- `return_to_menu()` salva prima di cambiare stato.
- `is_gameplay_active()` restituisce false mentre i risultati sono visibili.

## Verifica

```text
godot --headless --path . --script res://tests/milestone_17_run_results_smoke_test.gd
godot --headless --path . --script res://tests/milestone_9_smoke_test.gd
godot --headless --path . --script res://tests/dungeon_smoke_test.gd
godot --headless --path . --script res://tests/tower_defense_smoke_test.gd
godot --path . --rendering-method gl_compatibility --script res://tests/run_results_visual_qa.gd
```

Output QA:

```text
build/qa/milestone_17_run_results.png
```

## Checklist manuale

- Perdere una run survival e verificare wave, tempo e progressione.
- Usare retry da tastiera e joypad e controllare che non compaiano duplicati.
- Completare il dungeon e verificare il titolo di vittoria.
- Fallire tower defense e verificare il riepilogo.
- Usare cambio modalita e controllare il focus del nuovo flusso.
- Tornare al menu e verificare che il save contenga la progressione.
