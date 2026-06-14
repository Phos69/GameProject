# Sistema Multiplayer Locale

## Responsabilita

`LocalMultiplayerManager` e l'autorita sugli slot locali attivi. Non spawna player direttamente: emette `active_slots_changed`, poi `PlayerManager` sincronizza le istanze player nella scena.

## Slot

- Slot supportati: 1-4.
- Player 1 e sempre attivo.
- Player 2-4 possono entrare e uscire durante la scena.
- Lo stato pubblico si legge con `get_active_slots()`.

## Input join/leave

- Joypad `Start`: attiva lo slot associato al device.
- Joypad `Back/Select`: disattiva lo slot associato se non e player 1.
- Tastiera debug `F2`, `F3`, `F4`: toggle per player 2, 3 e 4.

## Mapping controller

Il prototipo usa una regola deterministica:

```text
player_slot = joypad_device + 1
```

Questo evita una schermata di assegnazione controller durante le prime milestone. Una riassegnazione esplicita potra essere introdotta in una milestone di polish o menu.

## Integrazione

- `InputManager` registra le azioni per tutti e quattro gli slot.
- `PlayerManager` ascolta `active_slots_changed`.
- `PlayerController` legge solo le azioni del proprio `player_slot`.
- `IsometricCameraController` segue tutti i nodi nel gruppo `players`.
- `HUDManager` legge gli slot attivi per mostrare lo stato locale.
