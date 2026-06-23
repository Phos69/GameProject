extends Node2D
## Stub minimale di player per i test di PlayerQuery: un Node2D nel gruppo
## "players" con un `player_slot` e un HealthComponent figlio. È un file-risorsa
## reale (non uno script generato a runtime) così GUT può tracciarlo senza che
## inst_to_dict() fallisca su uno script "not based on a resource file".

@export var player_slot: int = 0
