# Milestone 19 - Secondo Boss e Registro Boss

## Stato

Completata come primo registro boss configurabile.

## Obiettivo

Dimostrare che le modalita possono richiedere boss diversi per ID senza
dipendere direttamente dalla scena del `Wave Warden`.

## Implementato

- registro scene e compatibilita in `BossSystem`;
- API `request_boss_by_id()` e selezione tramite `config.boss_id`;
- rifiuto tipizzato per boss sconosciuto o modalita incompatibile;
- `Rift Architect` come secondo boss del dungeon;
- fase 1 con `lane_sweep` e varco sicuro;
- fase 2 con `cross_burst` alternato;
- visual quadrato/tecnologico e palette ciano-verde;
- proiettili e telegraph dedicati;
- drop garantito `Rift Repeater`;
- HUD e annunci boss resi generici.

## Compatibilita

- `wave_warden`: survival, dungeon e tower defense;
- `rift_architect`: survival e dungeon;
- il dungeon usa `rift_architect`;
- survival e tower defense continuano a usare `wave_warden`.

## Contratto

- Il chiamante usa sempre `GameModeManager.request_boss()`.
- `BossSystem` risolve `boss_id`, scena e compatibilita.
- Un boss incompatibile restituisce `null` ed emette `boss_request_rejected`.
- `BasicBoss` espone dispatch del pattern e contratto visuale condiviso.
- Ogni visual implementa fase, facing, hit, spawn e charge senza gameplay.
- I segnali legacy di sconfitta restano compatibili.

## Verifica

```text
godot --headless --path . --script res://tests/milestone_19_boss_registry_smoke_test.gd
godot --headless --path . --script res://tests/boss_smoke_test.gd
godot --headless --path . --script res://tests/dungeon_smoke_test.gd
godot --headless --path . --script res://tests/tower_defense_smoke_test.gd
godot --path . --rendering-method gl_compatibility --script res://tests/rift_architect_visual_qa.gd
```

Output QA:

```text
build/qa/milestone_19_rift_lane.png
build/qa/milestone_19_rift_cross.png
```

## Checklist manuale

- Verificare il Warden nella quinta wave survival.
- Raggiungere la boss room dungeon e identificare il Rift Architect.
- Leggere il varco sicuro del lane sweep prima del fuoco.
- Leggere gli assi del cross burst in fase 2.
- Controllare nome, fase e vita nell'HUD condiviso.
- Uccidere il boss e raccogliere il Rift Repeater.
- Confermare che tower defense continui a usare il Warden.
