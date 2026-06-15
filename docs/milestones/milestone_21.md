# Milestone 21 - Accessibilita, Performance e Asset Pipeline

## Stato

Completata come primo pass configurabile e misurabile.

## Obiettivo

Rendere il visual pass adattabile senza modificare collisioni, danno, velocita
o timing gameplay, e preparare la sostituzione progressiva dei placeholder con
asset tracciabili.

## Implementato

- `VisualSettingsManager` con notifica ai soli consumer presentazionali;
- preset `default`, `reduced_motion` e `high_contrast`;
- intensita regolabile per flash, glow, trail e camera shake;
- scala testo HUD da 0,80 a 1,20;
- pagina menu dedicata con slider, toggle e preset;
- save v4 con sezione `settings.visual`;
- marker geometrici circle/triangle/square/diamond per gli slot player;
- pickup distinti da icone e silhouette, non solo dal colore;
- bordi, warning e HUD rinforzati in high contrast;
- riduzione di bob, pulse, scale UI e shake;
- camera shake visuale event-driven per impatti importanti;
- convenzioni asset, import, fallback e registro attribuzioni;
- nearest filtering 2D come default di progetto.

## Isolamento Gameplay

- Le impostazioni vengono consegnate tramite `apply_visual_settings()`.
- Nessun consumer scrive in health, collision layer, velocita o danno.
- Il proiettile conserva damage e velocity quando glow e trail sono a zero.
- La camera usa solo `Camera2D.offset`.
- Reduced motion ferma solo clock e interpolazioni presentazionali.

## Profiling

Scenario headless verificato:

```text
4 player locali
28 nemici misti
Rift Architect con lane telegraph
120 physics frame
media rilevata: 16,58 ms
budget smoke: meno di 35 ms
```

Il numero e un riferimento ripetibile sulla macchina di sviluppo, non una
garanzia per ogni hardware.

## Verifica

```text
godot --headless --path . --script res://tests/milestone_21_visual_settings_performance_smoke_test.gd
godot --path . --rendering-method gl_compatibility --script res://tests/visual_accessibility_qa.gd
```

Output QA:

```text
build/qa/milestone_21_visual_settings_menu.png
build/qa/milestone_21_profile_default.png
build/qa/milestone_21_profile_reduced_motion.png
build/qa/milestone_21_profile_high_contrast.png
```

## Checklist manuale

- Cambiare ogni slider e verificare l'aggiornamento immediato.
- Riavviare e verificare il ripristino dal save v4.
- Con glow/trail a zero, confermare collisioni e danno invariati.
- Controllare i quattro marker geometrici senza usare il colore.
- Identificare tutti i pickup dalla forma in high contrast.
- Verificare testo HUD al minimo e al massimo.
- Verificare assenza di shake e pulsazioni nel preset Comfort.
- Ripetere il profilo affollato e registrare frame time e hardware.
- Registrare origine e licenza prima di importare asset esterni.

