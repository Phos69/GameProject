# Sistema Multiplayer Locale

## Responsabilita

`LocalMultiplayerManager` e l'autorita sugli slot locali attivi. Non spawna player direttamente: emette `active_slots_changed`, poi `PlayerManager` sincronizza le istanze player nella scena.

## Slot

- Slot supportati: 1-4.
- Player 1 e sempre attivo.
- Player 2-4 possono entrare e uscire dalla scena; durante una run `Start`
  apre la pausa invece di fare join.
- Lo stato pubblico si legge con `get_active_slots()`.

## Input join/leave

- Joypad `Start`: attiva lo slot associato al device quando il gameplay non e
  in pausa/run attiva.
- Joypad `Back/Select`: disattiva lo slot associato se non e player 1.
- Tastiera debug `F2`, `F3`, `F4`: toggle per player 2, 3 e 4.
- I pulsanti joypad di join e leave sono riassegnabili da Settings > Controls.

## Mapping controller

Il prototipo usa una regola deterministica:

```text
player_slot = joypad_device + 1
```

Questo evita una schermata di assegnazione controller durante le prime milestone. La rimappatura attuale cambia il layout dei pulsanti joypad, non il rapporto device/slot.

## Integrazione

- `InputManager` registra le azioni per tutti e quattro gli slot.
- `PlayerManager` ascolta `active_slots_changed`.
- `PlayerController` legge solo le azioni del proprio `player_slot`.
- `IsometricCameraController` segue tutti i nodi nel gruppo `players`.
- `HUDManager` legge gli slot attivi per mostrare lo stato locale.
