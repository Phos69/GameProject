# Milestone 11 - Boss Telegraph e Combat Danger Feedback

## Stato

Completata come primo pass di telegraph modulare.

## Obiettivo

Rendere anticipabili i pattern del `Wave Warden` senza cambiare danno,
collisioni, targeting o integrazione con survival, dungeon e tower defense.

## Implementato

- telegraph world-space modulare per `aimed_volley`;
- telegraph world-space modulare per `radial_burst`;
- countdown visuale prima della generazione dei proiettili;
- direzione della raffica mirata bloccata al momento del preavviso;
- corsie e area radiale leggibili senza collisioni gameplay;
- segnale pubblico di inizio e fine telegraph;
- avviso HUD distinto per raffica mirata, radiale e cambio fase;
- cue audio procedurali per spawn boss, telegraph e fase 2;
- impulso world-space al passaggio in fase 2;
- smoke test dedicato e due catture QA a 1280x720.

## Contratto tecnico

- `BasicBoss` resta autoritativo per scelta e timing del pattern.
- `BossTelegraphVisual` riceve pattern, durata, direzione e conteggio corsie.
- Il visual non applica danno, non possiede collisioni e non seleziona target.
- I proiettili vengono creati solo al termine del warning.
- La raffica mirata usa la direzione annunciata anche se il target si sposta.
- Le API immediate `perform_aimed_volley()` e `perform_radial_burst()` restano
  disponibili per test e chiamanti esistenti.
- Il boss tower defense su percorso mantiene il comportamento precedente e
  non avvia pattern action.

## Verifica automatica

```text
godot --headless --path . --script res://tests/milestone_11_boss_telegraph_smoke_test.gd
godot --headless --path . --script res://tests/boss_smoke_test.gd
godot --headless --path . --script res://tests/survival_wave_smoke_test.gd
godot --headless --path . --script res://tests/dungeon_smoke_test.gd
godot --headless --path . --script res://tests/tower_defense_smoke_test.gd
```

QA visuale:

```text
godot --path . --rendering-method gl_compatibility --script res://tests/boss_telegraph_visual_qa.gd
```

Output:

```text
build/qa/milestone_11_boss_aimed.png
build/qa/milestone_11_boss_radial.png
```

## Checklist manuale

- Avviare una boss wave survival con 1-4 player.
- Verificare che `AIMED VOLLEY` mostri direzione e tre corsie prima del fuoco.
- Spostarsi dopo l'apparizione del cono e verificare che la raffica mantenga
  la direzione annunciata.
- Verificare che `RADIAL BURST` mostri tutti i raggi e lasci varchi leggibili.
- Confermare che nessun proiettile infligga danno durante il countdown.
- Portare il boss sotto il 50% e verificare impulso, HUD e cue audio di fase 2.
- Controllare che il warning resti leggibile con quattro schede player.
- Verificare il boss condiviso nel dungeon.
- Verificare che il boss tower defense continui a seguire il percorso.

## Fuori scope

- restyling completo della silhouette del `Wave Warden`;
- nuovi pattern o nuovi boss;
- varianti runner e tank;
- camera shake e freeze frame;
- sostituzione dei cue procedurali con asset audio definitivi.
