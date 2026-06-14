# Milestone 2 - Multiplayer locale

## Stato

Completata come prototipo minimo.

## Deliverable

- Supporto 1-4 player locali.
- Player 1 sempre attivo.
- Join/leave per slot 2-4.
- Spawn/despawn dinamico tramite `PlayerManager`.
- Mapping controller deterministico: `device joypad + 1 = player_slot`.
- Camera condivisa sul gruppo `players` con zoom dinamico.
- HUD con conteggio player e slot attivi.
- Fallback debug tastiera con `F2`, `F3`, `F4`.

## Verifica manuale

1. Aprire il progetto in Godot 4.x.
2. Avviare `res://game/main/main.tscn`.
3. Verificare che player 1 appaia sulla griglia.
4. Premere `F2`, `F3` e `F4` per attivare player 2, 3 e 4.
5. Premere di nuovo gli stessi tasti per rimuovere gli slot secondari.
6. Collegare joypad multipli e usare `Start` per entrare.
7. Usare `Back/Select` per lasciare con slot secondari.
8. Verificare che HUD e camera si aggiornino quando cambia il gruppo.
9. Verificare che il movimento del player 1 e il fire action restino funzionanti.

## Limiti noti

- Il mapping controller e fisso e non prevede ancora riassegnazione manuale.
- Non esiste ancora un menu di join dedicato.
- Vita, ammo e HUD per-player saranno completati nelle milestone combat e survival.
