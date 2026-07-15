# Checklist visuale RPG Zombie Survival

Usare questa checklist per verificare il pass 1 dei personaggi RPG a 1280x720, senza leggere il testo della UI.

## Stato asset (Milestone 6)

- `base_complete`: set asset completo e coerente, cablato nei campi
  `RpgCharacterData` e validato da
  `tests/suites/assets/character_asset_test.gd` (portrait full/hud, gameplay
  sprite, sprite sheet, weapon, icone passive/super). Tutti i 7 personaggi sono a
  questo livello; `PlayerVisual` carica il pittogramma gameplay e conserva il
  render procedurale solo come fallback tecnico.
- `final_quality`: arte definitiva rifinita a mano per personaggio (follow-up
  artistico, uno alla volta, partendo da `ranger_final_quality_pass`).
- `portrait_hud_path` punta sempre al portrait HUD dedicato; `portrait_full_path`
  al portrait grande (PNG dove esiste, altrimenti SVG). Nessun asset esterno
  obbligatorio (pipeline mista SVG testuale + PNG in-repo).
- `gameplay_sprite_path` punta per tutti i sette profili al pittogramma PNG
  top-down con alpha e anchor `bottom_center`, consumato sia dalle preview sia
  dal corpo world-space;
  gli SVG precedenti restano sorgenti/fallback in-repo.
- QA visuale a 1280x720, 1024x768 e 960x540 in default/reduced motion/high
  contrast resta manuale (screenshot nel playtest end-to-end Milestone 11).

## Character Select

- [ ] La schermata mostra titolo, quattro slot player, card RPG per il roster e
  pulsante `Start Zombie Survival` leggibile da divano/joypad.
- [ ] La card in focus mostra highlight/hover, stat bar HP/ATK/DEF/SPD/RNG,
  icona classe/arma e indicatori degli slot player assegnati.
- [ ] Ogni card usa `portrait_hud_path` o `portrait_full_path` quando il
  portrait dedicato esiste; se manca, usa `gameplay_sprite_path`; se anche
  quello manca, usa il fallback procedurale coerente con palette e arma.
- [ ] Il dossier laterale mostra descrizione di stile, range arma e preview
  gameplay top-down caricata da `gameplay_sprite_path`, con fallback
  procedurale coerente se l'asset non e disponibile.
- [ ] A 1280x720, 1024x768 e 960x540 il pannello resta dentro la safe-area; se
  lo spazio non basta, lo scroll mostra il contenuto senza tagli.
- [ ] Ogni slot player attivo mostra portrait, nome, classe/arma, statistiche, passiva e super dopo la scelta.
- [ ] Gli slot inattivi restano distinguibili dagli slot attivi senza occupare il focus della selezione.

- [ ] `ranger`: la card mostra `Mira Vento` sopra `Ranger · Arco` e usa la palette `ranger_forest`.
- [ ] `pistoliere`: la card mostra `Dante Ferraglia` sopra `Pistoliere · Pistola` e usa la palette `gunslinger_dust`.
- [ ] `berserker`: la card mostra `Bruna Spaccaferro` sopra `Berserker · Ascia` e usa la palette `berserker_rust`.
- [ ] `spadaccino`: la card mostra `Kael Guardia` sopra `Spadaccino · Spada` e usa la palette `blade_night`.
- [ ] `mago`: la card mostra `Elio Braciastella` sopra `Mago · Bastone arcano` e usa la palette `arcane_violet`.
- [ ] `domatrice`: la card mostra `Nina Bullone` sopra `Domatrice · Fionda magnetica` e usa la palette `teal_copper`.
- [ ] `licantropo`: la card mostra `Rocco Lunastorta` sopra `Licantropo · Artigli` e usa la palette `moon_fury`.

## Gameplay

- [ ] Ranger riconoscibile da cappuccio appuntito, arco lungo e accenti verde/oro.
- [ ] Pistoliere riconoscibile da giacca corta, pistola luminosa e accenti giallo/arancio.
- [ ] Berserker riconoscibile da corpo largo, ascia enorme e accenti rossi.
- [ ] Spadaccino riconoscibile da mantello corto, lama chiara e accenti azzurro/bianco.
- [ ] Mago riconoscibile da cappotto/poncho, bastone verticale, globo e rune viola/blu.
- [ ] Domatrice riconoscibile da fionda, zaino tecnico e Briciola sempre vicino.
- [ ] Licantropo riconoscibile da postura curva/artigli in forma umana e scala maggiore durante Notte Bestiale.
- [ ] Le armi restano su layer/visual separato dal corpo e seguono la mira.
- [ ] Gli effetti di sparo/reload/super restano leggibili tra zombie, pickup e ostacoli.
- [ ] Le super starter hanno silhouette VFX distinte: cono, burst, radiale e dash.
- [ ] Le super avanzate hanno VFX distinti: Stella Cadente radiale viola,
  Branco di Rottami burst teal e Notte Bestiale dash rosso.

## HUD

- [ ] La scheda player mostra nome proprio, classe e arma base nella forma `Nome  Classe · Arma`.
- [ ] Il ritratto procedurale usa il colore accent della palette del personaggio.
- [ ] L'icona super usa lo stesso accent e indica chiaramente lo stato pronto/non pronto.
- [ ] Le passiva attive restano leggibili senza coprire HP, ammo e XP.
- [ ] Briciola non blocca il player, non resta bloccato lontano e torna vicino a Nina.
- [ ] Briciola in frenzy resta riconoscibile come supporto e non sostituisce Nina.
- [ ] Rocco torna sempre alla forma umana dopo la super e mostra recovery breve
  con marker/anello visibile.

## Sostituzione asset definitivi

I placeholder procedurali possono essere sostituiti popolando i path data-driven nei profili `RpgCharacterData`:

- `portrait_full_path` e `portrait_hud_path` per menu/HUD.
- `style_description` e `gameplay_sprite_path` per dossier, preview e corpo
  world-space.
- `sprite_sheet_path` e `animation_profile_id` per il corpo animato.
- `weapon_sprite_path` per il visual arma separato.
- `passive_icon_path` e `super_icon_path` per le icone UI.
- `gameplay_palette_id`, `palette_primary`, `palette_secondary` e `palette_accent` per mantenere coerenza cromatica durante la transizione.
