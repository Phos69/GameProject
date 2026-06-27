extends GutHookScript
## Pre-run hook GUT: spegne i TIER SU DISCO (WorldDataCache + TileBakeCache) per
## l'intera suite.
##
## In gioco i tier disco sono attivi (il mondo golden e il bake del terreno si
## persistono su user:// e il gameplay li riusa). Sotto test invece vanno spenti di
## default: i test devono essere deterministici e non devono scrivere snapshot su
## user:// ne' farsi servire hit da file lasciati da sessioni precedenti.
##
## L'UNICA suite che produce volutamente lo snapshot golden per il gameplay
## (golden_snapshot_bake_test) li riaccende nel suo before_all e li rispegne
## nell'after_all, lasciando i file su disco.

func run() -> void:
	WorldDataCache.set_disk_enabled(false)
	TileBakeCache.set_enabled(false)
