# Repo Fix Milestone 10 - Asset Fallback Policy

Data: 2026-06-21

Questa nota chiude la Milestone 10 del pass repo-fix: asset, terrain,
ostacoli, void/cliff e fallback hanno ora un contratto verificabile senza
dipendere da asset esterni obbligatori.

## Classificazione fallback

Fallback tecnici necessari:

- `BiomeRegionGround`: fallback del terreno intero, ammesso solo fuori dal
  percorso standard asset-driven.
- `BiomeTerrainPatch`: fallback per tile/route/passaggi legacy o test isolati.
- `BiomeObstacle`: fallback procedurale esplicito per ostacoli e muri.
- `BiomeFallZone`: fallback tecnico per void/fall zone.
- `BiomeTileLayer`: fallback tecnico per le transizioni cliff/void risolte dal
  tile layer.
- `SupplyCrate`: fallback tecnico della crate runtime.

Fallback temporanei:

- Nessun contratto standard del manifest corrente usa `needs_asset`,
  `procedural_fallback` o `deprecated`.
- Se uno di questi status viene reintrodotto, deve avere `fallback_path`
  esplicito, asset target documentato e backlog collegato in `TODO.md`.

Fallback rimovibili/vietati nel percorso standard:

- Path o draw mode `placeholder`/`generic` non documentati.
- `generic_barrier` implicito sugli oggetti generati.
- `BiomeRegionGround`, `BiomeTerrainPatch`, `MultiRegionRenderer`,
  `NeighborGround_*` o `BiomeTransitionGate` nella survival standard.

## Contratto standard

La survival standard usa `WorldRegionStreamer` con contenuto `FULL` per regione
corrente e vicini connessi. Il terreno passa da `BiomeTileLayer`, gli ostacoli
da `IsometricEnvironmentObject` asset-backed, i void/cliff dai contratti
`void_tiles` e i passaggi da tile asset-driven. Il percorso standard deve avere
`get_missing_asset_count() == 0` e `uses_procedural_fallback() == false` sul
tile layer corrente.

Il manifest `assets/environment/isometric/manifest.json` resta la fonte unica:
ogni contratto standard deve avere `asset_path`, `status`, `biome_ids`,
footprint/collisione, source/licenza/attribution e `fallback_path` tecnico.

## Verifica

Comandi mirati:

```text
godot --headless --path . --script res://tools/generate_isometric_environment_assets.gd -- --check
godot --headless --path . --script res://tests/milestone_10_asset_fallback_policy_smoke_test.gd
godot --headless --path . --script res://tests/milestone_10_asset_manifest_v7_smoke_test.gd
godot --headless --path . --script res://tests/milestone_10_legacy_cleanup_smoke_test.gd
godot --headless --path . --script res://tests/milestone_10_object_asset_smoke_test.gd
godot --headless --path . --script res://tests/obstacle_rendering_contract_smoke_test.gd
godot --headless --path . --script res://tests/milestone_10_void_cliff_asset_smoke_test.gd
godot --headless --path . --script res://tests/forest_isometric_texture_transition_smoke_test.gd
godot --headless --path . --script res://tests/milestone_10_tile_layer_smoke_test.gd
godot --path . --rendering-method gl_compatibility --script res://tests/milestone_10_isometric_final_visual_qa.gd
```

La QA visuale finale resta separata dagli smoke headless perche richiede
rendering reale e produce screenshot in `build/qa/`. Nella validazione locale
del 2026-06-21 il renderer `vm3dgl` non era disponibile e Godot ha usato
LLVMPipe; il test visuale ha comunque completato i controlli screenshot con
exit code `0`.
