# TODO

## Prossima iterazione biomi zombie survival

- QA manuale mini-eventi bioma.
  - Obiettivo: verificare ritmo, reward e leggibilita di `toxic_leak`, `fire_breakout`, `whiteout` e `marsh_emergence` con gameplay reale.
  - Milestone collegata: evoluzione post-roadmap del motore biomi zombie survival.
  - File/sistemi coinvolti: `RandomEncounterSystem`, `HazardSystem`, `ResourceCrateSystem`, HUD annunci e debug overlay.
  - Criterio di accettazione: ogni mini-evento resta evitabile, non blocca passaggi/casse, assegna reward proporzionata e resta leggibile in high contrast/reduced motion.
  - Test richiesto: QA manuale 10 wave con seed fisso e acquisizione screenshot/video dei quattro eventi.

## Megamappa persistente isometrica - completato

- Roadmap megamappa persistente isometrica completata come primo pass stabile.
  - Obiettivo: trasformare la generazione a biomi/portali in una megamappa seed-based persistente con territori `200x200`, grafo connesso, passaggi fisici aperti, fall boundary, mappa esplorazione e dodge/roll.
  - Milestone collegata: `roadmap_megamappa_persistente_isometrica.md` Milestone 1-10.
  - File/sistemi coinvolti: `game/world/`, `BiomeMapGenerator`, `BiomeWorldGenerator`, `BiomeManager`, `BiomeTransitionSystem`, `BiomeEnvironmentLayout`, `MapValidationSystem`, `SaveManager`, `HUDManager`, `InputManager`, `PlayerController`, `PlayerDodgeComponent`.
  - Criterio di accettazione: stesso seed produce la stessa megamappa, tutte le regioni sono raggiungibili, i passaggi sono fisici e non ostruiti, i lati esterni sono fall boundary, lo stato esplorazione salva/carica e dodge/gap traversal rispetta landing e ostacoli.
  - Test richiesto: `tests/world_graph_connectivity_smoke_test.gd`, `tests/persistent_world_generation_smoke_test.gd`, `tests/open_passage_transition_smoke_test.gd`, `tests/isometric_biome_terrain_coverage_smoke_test.gd`, `tests/fall_boundary_visual_logic_smoke_test.gd`, `tests/player_dodge_gap_smoke_test.gd`, `tests/exploration_map_smoke_test.gd` e regressioni survival/dungeon/tower/RPG.

## Megamappa persistente isometrica - follow-up

- QA manuale di attraversamento continuo e leggibilita isometrica.
  - Obiettivo: validare su schermo reale passaggi aperti, fall boundary, mappa esplorazione e dodge/gap con party da 1-4 player.
  - Milestone collegata: polish post `roadmap_megamappa_persistente_isometrica.md`.
  - File/sistemi coinvolti: `WorldRuntime`, `BiomeTransitionSystem`, `TerrainGenerator`, `ExplorationMapPanel`, `PlayerDodgeComponent`, `HazardSystem`.
  - Criterio di accettazione: i player attraversano almeno otto regioni con seed fisso senza teletrasporti percepiti, senza passaggi ostruiti e con stato mappa leggibile in default/high contrast.
  - Test richiesto: checklist manuale 20 minuti survival con seed fisso, screenshot mappa e verifica dodge su gap piccolo.

- Streaming visuale delle regioni lontane.
  - Obiettivo: rendere `WorldRuntime` proprietario dell'istanza corrente e delle regioni N/E/S/W precaricate, lasciando le regioni lontane solo come dati.
  - Milestone collegata: performance post megamappa.
  - File/sistemi coinvolti: `WorldRuntime`, `ZombieModeController`, `TerrainGenerator`, `ObstacleSystem`, `ResourceCrateSystem`, `HazardSystem`.
  - Criterio di accettazione: le regioni lontane non restano istanziate, la regione corrente e i vicini vengono caricati/rilasciati senza ricreare casse gia aperte o encounter completati.
  - Test richiesto: smoke headless di load/unload regioni e profiling manuale con griglia almeno `7x7`.

- Pass asset isometrici ambiente.
  - Obiettivo: sostituire progressivamente placeholder di case, muretti, auto, casse, barili, rocce, tubi, cisterne, ponti e scarpate usando il manifest isometrico.
  - Milestone collegata: asset pipeline post megamappa.
  - File/sistemi coinvolti: `assets/environment/isometric/`, `ObstacleLayoutGenerator`, `ObstacleSystem`, `TerrainGenerator`, `BiomeFallZone`.
  - Criterio di accettazione: ogni oggetto convertito ha visual scene, collision shape, shadow, sort offset, footprint tiles e flag di blocco coerenti.
  - Test richiesto: QA visuale a 1280x720 e smoke collisioni/footprint per ogni categoria convertita.

## Motore generazione mappe e biomi - completato

- Roadmap motore generazione mappe e biomi completata come primo pass procedurale integrato.
  - Obiettivo: generare una mappa globale seed-based con celle bioma `200x200`, passaggi, fall zone, layout interni e validazione giocabilita.
  - Milestone collegata: `roadmap_motore_generazione_mappe_biomi.md` Milestone 1-12.
  - File/sistemi coinvolti: `game/procedural/world_generation/`, `BiomeManager`, `BiomeTransitionSystem`, `ZombieSpawner`, `BiomeDefinition`, `BiomeEnvironmentLayout`.
  - Criterio di accettazione: stesso seed produce la stessa mappa, seed diverso cambia la firma, ogni cella ha bordi coerenti, passaggi raggiungibili, fall boundary sui lati esterni e layout validato.
  - Test richiesto: `tests/biome_world_generation_smoke_test.gd`, regressioni `zombie_revamp_foundation_smoke_test.gd`, `zombie_environment_milestone_smoke_test.gd`, `zombie_biome_transition_smoke_test.gd`, `zombie_spawner_edge_smoke_test.gd` e `survival_wave_smoke_test.gd`.

## Revamp modalita zombie - completato

- Roadmap Z1-Z12 completata.
  - Obiettivo: trasformare la survival statica in una run a cinque biomi con spawn camera-edge, wave contestuali, loot, hazard, varianti nemiche e HUD.
  - Milestone collegata: intera `roadmap_revamp_modalita_zombie.md`.
  - File/sistemi coinvolti: `game/modes/zombie/`, `WaveManager`, `EnemySystem`, `HUDManager`, audio, effetti e risorse bioma.
  - Criterio di accettazione: Definition of Done della roadmap coperta dai sistemi e dai test dedicati.
  - Test richiesto: smoke Z1-Z5, transizioni, nemici tematici, dieci wave, soak dieci minuti e QA visuale cinque biomi.

## Completati recenti

- Menu pausa e Settings condivisi.
  - Obiettivo: aprire una pausa con `Start` durante una run e centralizzare audio, video e controlli in una pagina Settings disponibile anche dal main menu.
  - Milestone collegata: UI/polish post-roadmap M21.
  - File/sistemi coinvolti: `PauseMenu`, `SettingsPanel`, `MainMenu`, `InputManager`, `LocalMultiplayerManager`, `VideoSettingsManager`, `SaveManager`.
  - Criterio di accettazione: `Start` pausa/riprende senza join involontario, Audio contiene il mix, Video contiene fullscreen/borderless/risoluzione/VSync/framerate e Controls rimappa i controlli joypad persistenti.
  - Test richiesto: `tests/pause_settings_smoke_test.gd`, regressioni `milestone_9_smoke_test.gd`, `milestone_18_audio_mix_smoke_test.gd` e `milestone_21_visual_settings_performance_smoke_test.gd`; QA manuale a 1280x720 con joypad reale.

- Roadmap Revamp Modalita Zombie, Milestone Z6-Z12: espansione completa.
  - Obiettivo: completare transizioni, quattro biomi avanzati, loot, hazard, zombie specifici, HUD e bilanciamento.
  - Milestone collegata: `roadmap_revamp_modalita_zombie.md` Milestone 6-12.
  - File/sistemi coinvolti: `BiomeTransitionSystem`, layout bioma, `HazardSystem`, `BiomeEnemyProfile`, `ResourceCrateSystem`, `WaveDirector`, HUD/audio/effetti.
  - Criterio di accettazione: cinque biomi attraversabili e distinguibili, almeno due zombie tematici per bioma avanzato, wave contestuali e run stabile.
  - Test richiesto: `zombie_biome_transition_smoke_test.gd`, `zombie_biome_enemy_smoke_test.gd`, `zombie_revamp_ten_wave_smoke_test.gd`, `zombie_revamp_ten_minute_soak_test.gd` e `zombie_biome_visual_qa.gd`.

- Roadmap Revamp Modalita Zombie, Milestone Z5: zone di caduta e danno ambientale.
  - Obiettivo: introdurre una `fall_zone` fisica con danno certo, recupero sicuro e feedback leggibile.
  - Milestone collegata: `roadmap_revamp_modalita_zombie.md` Milestone 5.
  - File/sistemi coinvolti: `BiomeFallZone`, `HazardSystem`, `HealthSystem`, `HealthComponent`, `ZombieSpawner`, `GameplayEffects`, `AudioManager`.
  - Criterio di accettazione: la caduta sottrae 20 HP, riporta il player all'ultima posizione sicura, preserva altre invulnerabilita e non accetta spawn zombie.
  - Test richiesto: `tests/zombie_fall_hazard_smoke_test.gd`, regressioni foundation/survival/RPG e QA `arena_variants_visual_qa.gd`.
- Roadmap Revamp Modalita Zombie, Milestone Z4: terreno, casse e ostacoli.
  - Obiettivo: popolare la Pianura Infetta con terreno leggibile, risorse esplorabili e impedimenti fisici senza chiudere le corsie principali.
  - Milestone collegata: `roadmap_revamp_modalita_zombie.md` Milestone 4, 6 e 7.
  - File/sistemi coinvolti: `BiomeEnvironmentLayout`, `TerrainGenerator`, `BiomeTerrainPatch`, `ObstacleSystem`, `BiomeObstacle`, `ResourceCrateSystem`, `SupplyCrate`, `DropSystem`.
  - Criterio di accettazione: layout deterministico, casse comuni/mediche raggiungibili, rocce/recinti/barriere/rudere/confine fisici e corridoio centrale attraversabile.
  - Test richiesto: `tests/zombie_environment_milestone_smoke_test.gd`, regressione spawn/survival/arena e QA `arena_variants_visual_qa.gd`.
- Roadmap Revamp Modalita Zombie, Milestone Z3: biomi dati e ondate contestuali.
  - Obiettivo: verificare definizioni bioma complete e wave modificate dal bioma corrente.
  - Milestone collegata: `roadmap_revamp_modalita_zombie.md` Milestone 3 e 8.
  - File/sistemi coinvolti: `BiomeDefinition`, `BiomeManager`, `WaveDirector`, `WaveManager`, test smoke dedicato.
  - Criterio di accettazione: i cinque biomi espongono terreno, ostacoli, casse, zombie, palette, difficolta e risorse; il bioma tossico modifica size, ritmo, scaling e roster.
  - Test richiesto: `tests/zombie_biome_wave_director_smoke_test.gd`.
- Roadmap Revamp Modalita Zombie, Milestone Z2: spawn dinamico dai bordi camera.
  - Obiettivo: generare zombie fuori o appena oltre il rettangolo visibile invece che da punti fissi arena.
  - Milestone collegata: `roadmap_revamp_modalita_zombie.md` Milestone 2.
  - File/sistemi coinvolti: `ZombieSpawner`, `ObstacleSystem`, `HazardSystem`, test smoke dedicato.
  - Criterio di accettazione: lo spawner supporta bordi nord/sud/est/ovest, distanza minima dal player, rifiuto fall zone/spawn blocker e fallback configurato.
  - Test richiesto: `tests/zombie_spawner_edge_smoke_test.gd`, regressione `tests/zombie_revamp_foundation_smoke_test.gd` e `tests/survival_wave_smoke_test.gd`.
- Roadmap Revamp Modalita Zombie, Milestone Z1: fondamenta modulari.
  - Obiettivo: separare la logica zombie in componenti dedicati mantenendo avviabile la survival esistente.
  - Milestone collegata: `roadmap_revamp_modalita_zombie.md` Milestone 1.
  - File/sistemi coinvolti: `ZombieModeController`, `BiomeManager`, `BiomeDefinition`, `WaveDirector`, `ZombieSpawner`, `TerrainGenerator`, `ResourceCrateSystem`, `ObstacleSystem`, `HazardSystem`, `SurvivalMode`, `WaveManager`, `SurvivalArenaManager`.
  - Criterio di accettazione: la run parte dalla `Pianura Infetta`, `WaveManager` delega roster/spawn ai nuovi componenti e conserva fallback verso i profili arena.
  - Test richiesto: `tests/zombie_revamp_foundation_smoke_test.gd`, `tests/survival_wave_smoke_test.gd`, `tests/milestone_20_arena_environment_smoke_test.gd`.
- Roadmap RPG Mode, Milestone 12: polish grafico e feedback.
  - Obiettivo: dare feedback visivo/audio dedicato agli eventi RPG importanti senza cambiare gameplay.
  - Milestone collegata: `roadmap_rpg_mode.md` Milestone 12.
  - File/sistemi coinvolti: `GameplayEffects`, `GameplayEffect`, `AudioEventRouter`, `AudioManager`.
  - Criterio di accettazione: level-up e super generano effetti world-space e cue procedurali dedicati.
  - Test richiesto: `tests/milestone_rpg_12_feedback_smoke_test.gd`; verifica manuale level-up/super in survival.
- Roadmap RPG Mode, Milestone 11: configurazione data-driven.
  - Obiettivo: spostare i profili classe fuori dal dizionario hardcoded mantenendo un registry unico.
  - Milestone collegata: `roadmap_rpg_mode.md` Milestone 11.
  - File/sistemi coinvolti: `RpgCharacterData`, `RpgCharacterRegistry`, risorse `game/rpg/characters/*.tres`.
  - Criterio di accettazione: aggiungere una classe richiede una nuova risorsa e una voce path nel registry, senza modificare menu/player/HUD.
  - Test richiesto: `tests/milestone_rpg_11_data_driven_smoke_test.gd`; verifica manuale Character Select.
- Roadmap RPG Mode, Milestone 10: bilanciamento prima versione.
  - Obiettivo: rendere le quattro classi iniziali chiaramente diverse senza cercare ancora la perfezione.
  - Milestone collegata: `roadmap_rpg_mode.md` Milestone 10.
  - File/sistemi coinvolti: `RpgCharacterRegistry`, risorse `game/weapons/rpg_*`, smoke test RPG esistenti.
  - Criterio di accettazione: Ranger ha payoff a distanza, Pistoliere resta accessibile ma non fuori scala, Berserker e piu rischioso/pesante e Spadaccino piu difensivo.
  - Test richiesto: `tests/milestone_rpg_10_balance_smoke_test.gd`; playtest survival manuale con tutte le classi.
- Roadmap RPG Mode, Milestone 9: HUD grafica RPG.
  - Obiettivo: rendere leggibili graficamente classe, arma, HP, ammo, XP, adrenalina, super e passive.
  - Milestone collegata: `roadmap_rpg_mode.md` Milestone 9.
  - File/sistemi coinvolti: `PlayerHudCard`, `RpgHudIcon`, `HUDManager`.
  - Criterio di accettazione: la scheda mostra ritratto classe, icona arma, pips ammo, barre XP/adrenalina e icona super ready senza dipendere solo da testo piccolo.
  - Test richiesto: `tests/milestone_rpg_9_hud_smoke_test.gd`; verifica manuale survival a quattro slot.
- Roadmap RPG Mode, Milestone 8: adrenalina e super.
  - Obiettivo: caricare una risorsa super da combat e spenderla in abilita diverse per classe.
  - Milestone collegata: `roadmap_rpg_mode.md` Milestone 8.
  - File/sistemi coinvolti: `RpgPlayerComponent`, `RpgSuperResolver`, `HealthSystem`, `WaveManager`, `InputManager`, `PlayerHudCard`.
  - Criterio di accettazione: adrenalina arriva da hit, danno subito, kill e fine ondata; a 100 la super parte con input dedicato e torna a 0.
  - Test richiesto: `tests/milestone_rpg_8_adrenaline_super_smoke_test.gd`; verifica manuale super con `Q`/joypad `Y`.
- Roadmap RPG Mode, Milestone 7: passive skill per personaggio.
  - Obiettivo: rendere automatica e visibile una passiva distinta per ogni classe iniziale.
  - Milestone collegata: `roadmap_rpg_mode.md` Milestone 7.
  - File/sistemi coinvolti: `RpgPlayerComponent`, `WeaponSystem`, `PlayerController`, `PlayerHudCard`.
  - Criterio di accettazione: Ranger scala il danno a distanza, Pistoliere ottiene fire rate dopo reload, Berserker aumenta danno a bassa vita e Spadaccino riduce il danno dopo un colpo.
  - Test richiesto: `tests/milestone_rpg_7_passives_smoke_test.gd`; verifica manuale HUD passive in survival.
- Roadmap RPG Mode, Milestone 6: esperienza e level up.
  - Obiettivo: assegnare XP al killer e bonus XP a fine ondata senza drop XP dagli zombie.
  - Milestone collegata: `roadmap_rpg_mode.md` Milestone 6.
  - File/sistemi coinvolti: `HealthSystem`, `BasicEnemy`, `BasicBoss`, `WaveManager`, loot table zombie, HUD reward.
  - Criterio di accettazione: il last-hit riceve XP, la wave assegna XP uguale ai player RPG vivi e gli zombie non generano pickup XP.
  - Test richiesto: `tests/milestone_rpg_6_xp_level_smoke_test.gd`; regressione varianti enemy M12/M15.
- Roadmap RPG Mode, Milestone 5: sistema ammo e reload per arma.
  - Obiettivo: mostrare munizioni e ricarica in modo leggibile per ciascuna arma base.
  - Milestone collegata: `roadmap_rpg_mode.md` Milestone 5.
  - File/sistemi coinvolti: `WeaponSystem`, `PlayerHudCard`, `HUDManager`, profili RPG.
  - Criterio di accettazione: il caricatore usa pips grafici, il reload ha una barra di progresso e `reload_speed` modifica la durata.
  - Test richiesto: `tests/milestone_rpg_5_ammo_reload_smoke_test.gd`; verifica manuale con arco e pistola.
- Roadmap RPG Mode, Milestone 4: hitbox proiettili e colpi melee.
  - Obiettivo: separare collisione e sprite per armi ranged/melee.
  - Milestone collegata: `roadmap_rpg_mode.md` Milestone 4.
  - File/sistemi coinvolti: `WeaponData`, `WeaponSystem`, `ProjectileSystem`, `Projectile`, risorse `rpg_*`.
  - Criterio di accettazione: pistola circle, arco capsule, ascia arc multi-hit e spada rectangle multi-hit configurati da dati.
  - Test richiesto: `tests/milestone_rpg_4_hitbox_smoke_test.gd`; QA manuale in survival con Berserker e Spadaccino.
- Roadmap RPG Mode, Milestone 3: armi base differenziate.
  - Obiettivo: dare a Ranger, Pistoliere, Berserker e Spadaccino armi base con profili gameplay diversi.
  - Milestone collegata: `roadmap_rpg_mode.md` Milestone 3.
  - File/sistemi coinvolti: `WeaponData`, `WeaponSystem`, `Projectile`, `RpgCharacterRegistry`, profili `game/weapons/rpg_*`, `PlayerVisual`, `WeaponIcon`.
  - Criterio di accettazione: ogni profilo equipaggia la propria arma e le armi differiscono per danno, range, scatter, caricatore e reload.
  - Test richiesto: `tests/milestone_rpg_3_weapons_smoke_test.gd`; regressione combat e survival con character select.
- Roadmap RPG Mode, Milestone 2: sistema classi e statistiche RPG.
  - Obiettivo: rendere HP, attacco, difesa, velocita e level-up propri del personaggio scelto.
  - Milestone collegata: `roadmap_rpg_mode.md` Milestone 2.
  - File/sistemi coinvolti: `RpgPlayerComponent`, `PlayerController`, `HealthSystem`, `Projectile`, `BasicEnemy`, `PlayerHudCard`.
  - Criterio di accettazione: il profilo modifica HP/velocita, il level-up aumenta HP/ATK/DEF e le formule danno usano attacco/difesa.
  - Test richiesto: `tests/milestone_rpg_2_stats_smoke_test.gd`; regressione combat/survival.
- Roadmap RPG Mode, Milestone 1: selezione personaggio pre-partita.
  - Obiettivo: obbligare la zombie survival a passare da una scelta classe prima della run.
  - Milestone collegata: `roadmap_rpg_mode.md` Milestone 1.
  - File/sistemi coinvolti: `MainMenu`, `SurvivalMode`, `RpgCharacterRegistry`, `RpgPlayerComponent`, player scene e HUD futuro.
  - Criterio di accettazione: il menu apre `Character Select`, la survival non parte prima della scelta e il `character_id` scelto viene applicato al player.
  - Test richiesto: `tests/milestone_rpg_1_character_select_smoke_test.gd`; verifica manuale menu con tastiera/joypad.
- Milestone 21: accessibilita, performance e asset pipeline.
  - Obiettivo: configurare la presentazione senza alterare il gameplay.
  - Milestone collegata: chiusura di `ROADMAP_VISUAL_GAMEPLAY.md`.
  - File/sistemi coinvolti: `VisualSettingsManager`, save, menu, HUD, visual, camera e `assets/`.
  - Criterio di accettazione: preset persistenti, identificatori non solo cromatici e profiling stabile.
  - Test richiesto: smoke M21 e `tests/visual_accessibility_qa.gd`.
- Milestone 20: arena, biomi e props interattivi.
  - Obiettivo: variare la survival senza duplicare controller o bloccare l'AI.
  - Milestone collegata: evoluzione ambientale delle Milestone 5 e 10.
  - File/sistemi coinvolti: `SurvivalArenaManager`, profili, palette, `WaveManager`, projectile, health ed effetti.
  - Criterio di accettazione: due layout, gate leggibili e barile con warning obbligatorio.
  - Test richiesto: smoke M20, stress roster e `tests/arena_variants_visual_qa.gd`.
- Milestone 19: secondo boss e registro boss.
  - Obiettivo: richiedere boss diversi per ID senza cambiare i chiamanti.
  - Milestone collegata: evoluzione boss delle Milestone 6-8 e 11.
  - File/sistemi coinvolti: `BossSystem`, `RiftArchitect`, telegraph, loot, HUD e modalita.
  - Criterio di accettazione: due boss configurabili con pattern, compatibilita e drop distinti.
  - Test richiesto: `tests/milestone_19_boss_registry_smoke_test.gd` e QA Rift.
- Milestone 18: audio mix e SFX sostituibili.
  - Obiettivo: preparare asset licenziati mantenendo fallback e controllo del mix.
  - Milestone collegata: evoluzione audio delle Milestone 9, 11, 15-17.
  - File/sistemi coinvolti: `AudioManager`, cue, voice pool, router, save e menu.
  - Criterio di accettazione: bus, priorita, fallback e volumi persistenti.
  - Test richiesto: `tests/milestone_18_audio_mix_smoke_test.gd` e `tests/audio_mix_visual_qa.gd`.
- Milestone 17: fine run, risultati e menu.
  - Obiettivo: presentare risultati reali e azioni esplicite dopo ogni run.
  - Milestone collegata: evoluzione UI e lifecycle delle tre modalita.
  - File/sistemi coinvolti: `RunSessionTracker`, `RunResultsScreen`, `GameModeManager`, save e modalita.
  - Criterio di accettazione: retry senza duplicati, cambio modalita e save prima del menu.
  - Test richiesto: `tests/milestone_17_run_results_smoke_test.gd` e `tests/run_results_visual_qa.gd`.
- Milestone 16: downed e revive multiplayer.
  - Obiettivo: mantenere coinvolti gli slot locali con recupero cooperativo leggibile.
  - Milestone collegata: evoluzione health e modalita a ondate.
  - File/sistemi coinvolti: `HealthComponent`, `ReviveSystem`, player, HUD e modalita.
  - Criterio di accettazione: revive interrompibile, join/leave sicuri e Field Kit non cumulativo.
  - Test richiesto: `tests/milestone_16_downed_revive_smoke_test.gd` e `tests/downed_revive_visual_qa.gd`.
- Milestone 15: zombie ranged e pressione a distanza.
  - Obiettivo: aggiungere pressione ranged con windup e colpo schivabile.
  - Milestone collegata: evoluzione gameplay delle Milestone 4, 5 e 12.
  - File/sistemi coinvolti: `RangedEnemy`, `EnemySystem`, `WaveManager`, `ZombieVisual`, projectile e loot.
  - Criterio di accettazione: lo shooter e riconoscibile, non spara durante il warning e usa i sistemi condivisi.
  - Test richiesto: `tests/milestone_15_ranged_enemy_smoke_test.gd` e `tests/ranged_enemy_visual_qa.gd`.
- Milestone 14: polish finale e presentabilita.
  - Obiettivo: completare identita del `Wave Warden` e coerenza della run survival.
  - Milestone collegata: chiusura del visual gameplay pass delle Milestone 10-13.
  - File/sistemi coinvolti: `WaveWardenVisual`, boss projectile, `CombatAnnouncement`, HUD ed effetti.
  - Criterio di accettazione: una run a quattro player resta leggibile da wave start a boss defeat.
  - Test richiesto: `tests/milestone_14_final_polish_smoke_test.gd` e `tests/final_survival_visual_qa.gd`.
- Milestone 13: identita grafica di armi e torri.
  - Obiettivo: differenziare armi speciali, proiettili e torre senza duplicare logica condivisa.
  - Milestone collegata: evoluzione visuale delle Milestone 3, 8 e 10.
  - File/sistemi coinvolti: `WeaponVisualData`, armi, `Projectile`, `PlayerVisual`, HUD e `DefenseTowerVisual`.
  - Criterio di accettazione: arma attiva e torre sono riconoscibili dalla silhouette anche in multiplayer locale.
  - Test richiesto: `tests/milestone_13_weapon_tower_visual_smoke_test.gd` e `tests/weapon_tower_visual_qa.gd`.
- Milestone 12: varianti zombie runner e tank.
  - Obiettivo: introdurre ruoli nemico leggibili senza duplicare AI condivisa.
  - Milestone collegata: evoluzione visuale e gameplay delle Milestone 4, 5 e 10.
  - File/sistemi coinvolti: `BasicEnemy`, `EnemySystem`, `WaveManager`, `ZombieVisual`, scene e loot.
  - Criterio di accettazione: runner e tank hanno silhouette, ritmo, resistenza e ricompense distinguibili.
  - Test richiesto: `tests/milestone_12_enemy_variants_smoke_test.gd` e `tests/enemy_variants_visual_qa.gd`.
- Milestone 11: telegraph boss e feedback del pericolo.
  - Obiettivo: rendere anticipabili i pattern del `Wave Warden` e il cambio fase.
  - Milestone collegata: evoluzione visuale delle Milestone 6, 9 e 10.
  - File/sistemi coinvolti: `BasicBoss`, `BossTelegraphVisual`, HUD, audio e QA.
  - Criterio di accettazione: aimed e radial mostrano direzione, area e durata prima di generare proiettili.
  - Test richiesto: `tests/milestone_11_boss_telegraph_smoke_test.gd` e `tests/boss_telegraph_visual_qa.gd`.
- Milestone 10: visual readability foundation della zombie survival.
  - Obiettivo: rendere arena, survivor, zombie, pickup e HUD leggibili come un gioco arcade isometrico.
  - Milestone collegata: Milestone 10 post-roadmap.
  - File/sistemi coinvolti: `game/visuals/`, player, nemici, drop, projectile, arena principale, HUD e QA.
  - Criterio di accettazione: attori riconoscibili, sfondo desaturato, pickup senza label, schede HUD e feedback visuali senza cambiare gameplay.
  - Test richiesto: `tests/milestone_10_visual_smoke_test.gd`, `tests/survival_visual_qa.gd` e regressione completa Milestone 3-9.
- Evoluzione post-roadmap: ammo survival anti-frustrazione.
  - Obiettivo: garantire sempre una risposta di fuoco mantenendo tensione sulle armi speciali.
  - Milestone collegata: evoluzione post-roadmap delle Milestone 3, 4, 5 e 9.
  - File/sistemi coinvolti: `WeaponSystem`, `DropSystem`, `SupplyCrate`, `SurvivalAmmoDirector`, HUD, audio, survival e smoke test.
  - Criterio di accettazione: fallback infinita con reload, speciali finite, ammo condivisa, supporto low-ammo e fonte garantita boss.
  - Test richiesto: smoke test combat, enemy/drop, survival e boss, piu regressione dungeon/tower defense.
- Milestone 9, completamento prototipo minimo.
  - Obiettivo: aggiungere un unlock persistente, feedback audio gameplay e primo bilanciamento.
  - Milestone collegata: Milestone 9.
  - File/sistemi coinvolti: `ProgressionManager`, `SaveManager`, player/health, `AudioManager`, proiettili, drop, armi e menu.
  - Criterio di accettazione: `Field Kit` persistente applicato a ogni nuova run, save v1 migrati, audio sparo/impatto/pickup attivo e valori arma documentati.
  - Test richiesto: `tests/milestone_9_smoke_test.gd`, regressione combat/drop e suite headless completa.
- Milestone 9, packaging e QA Windows.
  - Obiettivo: installare i template, produrre una release e verificare menu, joypad e audio.
  - Milestone collegata: Milestone 9.
  - File/sistemi coinvolti: `export_presets.cfg`, `InputManager`, `AudioManager`, `BuildRuntimeSmoke`, menu e checklist.
  - Criterio di accettazione: EXE/PCK generati, build smoke exit `0`, controller XInput rilevato e audio WASAPI alimentato.
  - Test richiesto: suite headless Milestone 3-9, `--build-smoke` e QA visuale.
- Milestone 9, prima iterazione: menu e progressione persistente.
  - Obiettivo: avviare il progetto da menu e conservare la progressione party.
  - Milestone collegata: Milestone 9.
  - File/sistemi coinvolti: `MainMenu`, `GameModeManager`, `SaveManager`, `ProgressionManager`, `AudioManager`, HUD, export preset.
  - Criterio di accettazione: il menu seleziona tutte le modalita, il save round-trip ripristina dati validi e il preset Windows viene riconosciuto da Godot.
  - Test richiesto: `tests/milestone_9_smoke_test.gd`, suite headless completa e checklist manuale Milestone 9.
- Milestone 8: tower defense giocabile.
  - Obiettivo: difendere un core con torri piazzabili, crediti e ondate su percorso.
  - Milestone collegata: Milestone 8.
  - File/sistemi coinvolti: `TowerDefenseMode`, `TowerDefenseWaveController`, `TowerDefenseManager`, `TowerDefenseArena`, `TowerDefenseEnemy`, `TowerBuildSlot`, `DefenseTower`, `EnemySystem`, `BossSystem`, `HUDManager`.
  - Criterio di accettazione: i nemici seguono il path e danneggiano il core, una torre acquistata li attacca e le boss wave usano il sistema condiviso.
  - Test richiesto: `tests/tower_defense_smoke_test.gd` e checklist manuale tower defense.
- Milestone 7: dungeon procedurale giocabile.
  - Obiettivo: generare e attraversare start room, combat room, loot room e boss room.
  - Milestone collegata: Milestone 7.
  - File/sistemi coinvolti: `DungeonGenerator`, `DungeonMode`, `DungeonRoom`, `EnemySystem`, `BossSystem`, `DropSystem`, `HUDManager`.
  - Criterio di accettazione: una run da seed attraversa tutte le stanze, blocca le uscite durante il combat, genera loot e termina dopo il boss.
  - Test richiesto: `tests/dungeon_smoke_test.gd` e checklist manuale dungeon.
- Milestone 6: boss system modulare.
  - Obiettivo: integrare un boss reale nella quinta ondata survival.
  - Milestone collegata: Milestone 6.
  - File/sistemi coinvolti: `BasicBoss`, `BossSystem`, `WaveManager`, `SurvivalMode`, `ProjectileSystem`, `HUDManager`, `DropSystem`.
  - Criterio di accettazione: il boss usa due pattern, cambia fase, blocca il completamento della wave, muore, genera drop speciale e permette la prosecuzione.
  - Test richiesto: `tests/boss_smoke_test.gd` e checklist manuale boss.
- Milestone 5: zombie survival a ondate.
  - Obiettivo: creare un loop survival con spawn progressivo, scaling e ricompense.
  - Milestone collegata: Milestone 5.
  - File/sistemi coinvolti: `SurvivalMode`, `WaveManager`, `GameModeManager`, `EnemySystem`, `BasicEnemy`, `HUDManager`, `ProgressionManager`.
  - Criterio di accettazione: almeno tre ondate consecutive aumentano conteggio e statistiche, terminano alla morte dei nemici e premiano tutti i player attivi.
  - Test richiesto: `tests/survival_wave_smoke_test.gd` e checklist manuale survival.
- Milestone 4: nemico base e drop system.
  - Obiettivo: introdurre AI chase/attack, morte, spawn e pickup raccoglibili.
  - Milestone collegata: Milestone 4.
  - File/sistemi coinvolti: `BasicEnemy`, `EnemySystem`, `DropEntry`, `LootTable`, `DropSystem`, `DropPickup`, `HealthSystem`, `ProgressionManager`, `WeaponSystem`.
  - Criterio di accettazione: il nemico seleziona un player vivo, attacca, muore per danno e genera ricompense applicate correttamente in multiplayer locale.
  - Test richiesto: `tests/enemy_drop_smoke_test.gd` e checklist manuale enemy/drop.
- Milestone 3: combat system base.
  - Obiettivo: collegare sparo, proiettili, danni, vita e munizioni base.
  - Milestone collegata: Milestone 3.
  - File/sistemi coinvolti: `WeaponData`, `WeaponSystem`, `ProjectileSystem`, `Projectile`, `HealthSystem`, `HealthComponent`, HUD e scena principale.
  - Criterio di accettazione: un proiettile colpisce un bersaglio con vita, applica danno e consuma munizioni senza condividere lo stato tra player.
  - Test richiesto: `tests/combat_smoke_test.gd` e checklist manuale combat.
- Milestone 2: multiplayer locale 1-4 player.
  - Obiettivo: attivare/disattivare slot locali e spawnare player multipli.
  - Milestone collegata: Milestone 2.
  - File/sistemi coinvolti: `LocalMultiplayerManager`, `PlayerManager`, `PlayerController`, `HUDManager`.
  - Criterio di accettazione: player 1 sempre attivo, player 2-4 attivabili con joypad o tastiera debug, camera condivisa sul gruppo.
  - Test richiesto: checklist manuale multiplayer locale in `docs/testing/manual_checklist.md`.

## Priorita alta

- Eliminare i warning di cleanup dei test headless.
  - Obiettivo: terminare la suite senza leak report di `ObjectDB` o access
    violation intermittenti di Godot 4.6.3.
  - Milestone collegata: manutenzione trasversale post M21.
  - File/sistemi coinvolti: runner in `tests/` e lifecycle runtime.
  - Criterio di accettazione: 100 avvii e shutdown consecutivi della scena
    principale con exit code `0`; il commit di partenza riproduce il difetto
    circa 1 volta su 40 sulla macchina di sviluppo.
  - Test richiesto: suite headless completa e loop dedicato di shutdown.

## Priorita media

- Espandere il dungeon oltre il percorso lineare.
  - Obiettivo: aggiungere diramazioni, scelta stanza, shop e predisposizione biomi.
  - Milestone collegata: evoluzione Milestone 7.
  - File/sistemi coinvolti: `DungeonGenerator`, `DungeonMode`, scene stanza e UI mappa.
  - Criterio di accettazione: almeno un seed produce una scelta reale tra due stanze senza rompere il percorso al boss.
  - Test richiesto: smoke test su piu seed e checklist manuale delle diramazioni.

## Priorita bassa

- Asset definitivi.
  - Obiettivo: sostituire progressivamente i placeholder senza introdurre dipendenze obbligatorie.
  - Milestone collegata: Milestone 9.
  - File/sistemi coinvolti: `assets/` e scene visuali.
  - Criterio di accettazione: leggibilita gameplay invariata e licenze documentate.
  - Test richiesto: revisione visuale delle scene principali.
- Ampliare i test automatici.
  - Obiettivo: coprire health, multiplayer, wave e generazione oltre al combat smoke test.
  - Milestone collegata: trasversale.
  - File/sistemi coinvolti: `tests/` e sistemi gameplay.
  - Criterio di accettazione: ogni sistema condiviso critico ha almeno uno smoke test headless.
  - Test richiesto: esecuzione completa della suite headless.
- Eliminare i warning di cleanup dei test headless.
  - Obiettivo: chiudere esplicitamente nodi e risorse prima dell'uscita dei runner.
  - Milestone collegata: manutenzione post-roadmap.
  - File/sistemi coinvolti: `tests/` e lifecycle dei nodi runtime.
  - Criterio di accettazione: la suite termina senza `ObjectDB instances leaked at exit`.
  - Test richiesto: suite headless completa con output privo di warning ObjectDB.

- Completato: iterazione survival biome-based status/ostacoli/roster/encounter.
  - Obiettivo: rendere i cinque biomi piu riconoscibili con malus temporanei, ostacoli, nemici tematici e encounter seed-based.
  - Milestone collegata: evoluzione zombie revamp Z12.
  - File/sistemi coinvolti: `BiomeStatusRuntime`, `HazardSystem`, `BiomeEnemyProfile`, `WaveDirector`, `RandomEncounterSystem`, HUD player e smoke test dedicati.
  - Criterio di accettazione: status temporanei visibili, roster tematico per bioma, ostacoli validati e encounter riproducibili.
  - Test richiesto: smoke headless biome status, roster, ostacoli, random encounter e regressioni survival/RPG.
- Follow-up: sostituire placeholder procedurali status/encounter con asset definitivi, playtestare frequenze encounter e tarare durata/danno dei malus con sessioni multiplayer reali.

## Asset definitivi personaggi RPG - futuro

- Obiettivo: rifinire qualitativamente tutti i sette personaggi con VFX separati, pulizia animazioni, eventuale export finale PNG fuori dal flusso PR e pass di leggibilita; Mira Vento, Bruna Spaccaferro, Nina Bullone e Rocco Lunastorta hanno portrait PNG collegati al Character Select, mentre Dante Ferraglia, Kael Guardia ed Elio Braciastella restano su portrait SVG/procedurali in attesa del pass definitivo.
- Milestone collegata: Pass 2-3 character art RPG zombie survival.
- File/sistemi coinvolti: `game/rpg/characters/`, `game/visuals/player_visual.gd`, `game/ui/player_hud_card.gd`, `assets/characters/`.
- Criterio di accettazione: ogni personaggio ha portrait HUD/full, idle/run/attack/reload/hurt/death/super, weapon layer e VFX separati configurati dai campi `RpgCharacterData`; Tutti i sette personaggi restano riferimenti minimi per struttura manifest, sprite sheet e icone arma/abilita; il prossimo ciclo deve migliorare qualita, VFX separati e coerenza animabile.
- Test richiesto: smoke RPG headless, QA visuale a 1280x720 e checklist `docs/rpg_character_visual_checklist.md` completata.

## Polish classi RPG avanzate - futuro

- Obiettivo: rifinire Mago, Domatrice e Licantropo con VFX telegraph definitivi, droni super di Nina e animazioni trasformazione complete.
- Milestone collegata: nuove classi RPG zombie survival Milestone 5-6.
- File/sistemi coinvolti: `RpgPlayerComponent`, `RpgSuperResolver`, `BriciolaCompanion`, `PlayerVisual`, `WeaponData`, `assets/characters/`.
- Criterio di accettazione: le tre classi sono bilanciate contro i quattro starter, Briciola aiuta senza giocare da solo e Notte Bestiale termina sempre con recovery leggibile.
- Test richiesto: `tests/milestone_rpg_13_new_classes_smoke_test.gd`, smoke RPG esistenti e checklist `docs/rpg_character_visual_checklist.md`.
