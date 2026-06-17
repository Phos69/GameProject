# Sistema Input

`InputManager` registra a runtime le azioni per 4 slot locali.

Player 1 ha fallback tastiera:

- movimento: `WASD`;
- mira: frecce;
- fire action: `Spazio`.
- pausa: `P`.

Joypad:

- stick sinistro: movimento;
- stick destro: mira;
- spalla/trigger destro: fire action;
- `A`: conferma menu e interazione gameplay;
- `Start`: pausa durante una run;
- D-pad/stick: navigazione menu circolare con cooldown anti-repeat rapido.
- `B`/`Back`: ritorno al menu precedente quando il pannello corrente lo
  supporta.
- `LB`/`RB`: tab Settings precedente/successiva con wrapping.

`InputManager` aggiunge joypad `A` all'azione globale `ui_accept` con device wildcard. Questo rende la conferma menu indipendente dallo slot locale assegnato.
Le azioni globali `ui_up`, `ui_down`, `ui_left` e `ui_right` includono frecce,
D-pad e stick sinistro, mentre i menu principali usano
`MenuNavigationController` per applicare wrapping, Back e debounce in modo
coerente.

Join/leave multiplayer locale:

- `Start` su joypad attiva lo slot associato al controller nel menu; durante
  una run viene intercettato dal `PauseMenu`;
- `Back/Select` su joypad disattiva lo slot associato, tranne player 1;
- `F2`, `F3`, `F4` sono fallback debug tastiera per attivare/disattivare player 2, 3 e 4.

La pagina Settings > Controls permette di riassegnare i binding joypad di
movimento, mira, fire, reload, super, interact, pause, join e leave. Le azioni
gameplay sono salvate come layout device-agnostic e riapplicate a tutti gli slot
locali con il device corretto.

Le azioni seguono il formato:

```text
p{slot}_{action}
```

Esempi:

- `p1_move_left`
- `p1_aim_right`
- `p1_fire`
