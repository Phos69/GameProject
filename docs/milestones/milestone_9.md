# Milestone 9 - Progressione, menu e packaging

## Stato

Completata come prototipo minimo.

## Implementato

- stato iniziale `menu`;
- menu principale con `Continue` e selezione delle tre modalita;
- ritorno al menu con `Esc`;
- sospensione dell'input gameplay nel menu;
- save JSON versionato per livello, XP, denaro e ultima modalita;
- autosave su progressione e selezione modalita;
- validazione di file e versione;
- feedback audio UI procedurale;
- preset export Windows;
- build Windows release verificata;
- mapping menu joypad `A` esplicito;
- build smoke e QA visuale;
- smoke test headless dedicato.
- save v2 con migrazione dei save v1;
- unlock persistente `Field Kit` al livello party 2;
- bonus di 20 HP applicato senza accumulo a ogni nuova run;
- feedback audio procedurale per sparo, impatto valido e pickup;
- primo pass di bilanciamento delle armi base;
- stato unlock mostrato nel menu.

## Verifica

```text
godot --headless --path . --script res://tests/milestone_9_smoke_test.gd
godot --headless --path . --export-release "Windows Desktop" build/iso_local_sandbox.exe
godot --headless --path . --export-pack "Windows Desktop" build/iso_local_sandbox.pck
godot --path . --rendering-method gl_compatibility --script res://tests/menu_visual_qa.gd
build/iso_local_sandbox.exe --rendering-method gl_compatibility -- --build-smoke
```

I template ufficiali sono installati in `4.6.3.stable` e verificati tramite SHA-512. EXE e PCK vengono generati; lo smoke test della build termina con exit code `0`. Il QA non-headless rileva GPU OpenGL, audio WASAPI e un controller XInput.

## Evoluzioni post-roadmap

- sostituire o mixare i placeholder audio;
- completare telegraph e polish visuale avanzato;
- aggiungere ulteriori unlock e pass di bilanciamento;
- firmare digitalmente l'eseguibile per distribuzione pubblica.
