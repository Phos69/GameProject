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

Le azioni seguono il formato:

```text
p{slot}_{action}
```

Esempi:

- `p1_move_left`
- `p1_aim_right`
- `p1_fire`

