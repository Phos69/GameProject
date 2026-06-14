# Sistema Input

`InputManager` registra a runtime le azioni per 4 slot locali.

Player 1 ha fallback tastiera:

- movimento: `WASD`;
- mira: frecce;
- fire action: `Spazio`.

Joypad:

- stick sinistro: movimento;
- stick destro: mira;
- spalla/trigger destro: fire action.

Join/leave multiplayer locale:

- `Start` su joypad attiva lo slot associato al controller;
- `Back/Select` su joypad disattiva lo slot associato, tranne player 1;
- `F2`, `F3`, `F4` sono fallback debug tastiera per attivare/disattivare player 2, 3 e 4.

Le azioni seguono il formato:

```text
p{slot}_{action}
```

Esempi:

- `p1_move_left`
- `p1_aim_right`
- `p1_fire`
