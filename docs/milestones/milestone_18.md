# Milestone 18 - Audio Mix e SFX Sostituibili

## Stato

Completata come infrastruttura audio modulare.

## Obiettivo

Preparare il progetto per SFX licenziati mantenendo fallback procedurali,
controllo del mix e priorita per gli eventi critici.

## Implementato

- bus `Music`, `SFX`, `UI`, `Weapons`, `Enemies`, `Boss`, `Environment`;
- `AudioCueData` con stream opzionale e fallback procedurale;
- `AudioVoicePool` con limite voci e sostituzione per priorita;
- `AudioEventRouter` separato dal manager del mix;
- SFX fallback distinti per Starter Pistol, Blaster e Wave Cannon;
- cue per archetipi nemico, shooter telegraph, boss, wave, downed, revive e risultati;
- variazione leggera di pitch;
- slider Master, Music e SFX nel menu;
- introduzione della persistenza audio in save v3, ora inclusa nello schema
  corrente v4 e compatibile con v1/v2.

## Contratto

- Un cue senza asset usa sempre il fallback e non genera errori.
- Un `optional_stream` valido sostituisce il fallback senza cambiare il chiamante.
- I bus di categoria inviano al bus `SFX`.
- Gli eventi critici usano priorita maggiore degli spari ripetuti.
- Il voice pool non supera il limite configurato.
- Volume Master, Music e SFX viene serializzato in `settings.audio`.

## Verifica

```text
godot --headless --path . --script res://tests/milestone_18_audio_mix_smoke_test.gd
godot --headless --path . --script res://tests/milestone_9_smoke_test.gd
godot --headless --path . --script res://tests/combat_smoke_test.gd
godot --headless --path . --script res://tests/milestone_16_downed_revive_smoke_test.gd
godot --path . --rendering-method gl_compatibility --script res://tests/audio_mix_visual_qa.gd
```

Output QA:

```text
build/qa/milestone_18_audio_mix_menu.png
```

## Checklist manuale

- Regolare Master, Music e SFX e riavviare il progetto.
- Verificare focus e conferma a volume basso.
- Confrontare i tre SFX arma fallback.
- Ascoltare shooter warning, downed, revive e risultati.
- Stressare una boss wave con quattro player e verificare gli eventi critici.
- Assegnare temporaneamente uno stream a un cue e confermare il fallback al suo
  successivo scollegamento.
