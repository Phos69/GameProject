# Checklist visuale RPG Zombie Survival

Usare questa checklist per verificare il pass 1 dei personaggi RPG a 1280x720, senza leggere il testo della UI.

## Character Select

- [ ] La schermata mostra titolo, quattro slot player, card RPG per il roster e
  pulsante `Start Zombie Survival` leggibile da divano/joypad.
- [ ] La card in focus mostra highlight/hover, stat bar HP/ATK/DEF/SPD/RNG,
  icona classe/arma e indicatori degli slot player assegnati.
- [ ] Il dossier laterale mostra descrizione di stile, range arma e preview
  gameplay isometrica caricata da `gameplay_sprite_path`, con fallback
  procedurale coerente se l'asset non e disponibile.
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

## HUD

- [ ] La scheda player mostra nome proprio, classe e arma base nella forma `Nome  Classe · Arma`.
- [ ] Il ritratto procedurale usa il colore accent della palette del personaggio.
- [ ] L'icona super usa lo stesso accent e indica chiaramente lo stato pronto/non pronto.
- [ ] Le passiva attive restano leggibili senza coprire HP, ammo e XP.
- [ ] Briciola non blocca il player, non resta bloccato lontano e torna vicino a Nina.
- [ ] Rocco torna sempre alla forma umana dopo la super e mostra recovery breve.

## Sostituzione asset definitivi

I placeholder procedurali possono essere sostituiti popolando i path data-driven nei profili `RpgCharacterData`:

- `portrait_full_path` e `portrait_hud_path` per menu/HUD.
- `style_description` e `gameplay_sprite_path` per dossier e preview future.
- `sprite_sheet_path` e `animation_profile_id` per il corpo animato.
- `weapon_sprite_path` per il visual arma separato.
- `passive_icon_path` e `super_icon_path` per le icone UI.
- `gameplay_palette_id`, `palette_primary`, `palette_secondary` e `palette_accent` per mantenere coerenza cromatica durante la transizione.
