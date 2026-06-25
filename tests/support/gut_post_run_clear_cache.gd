extends GutHookScript
## Post-run hook GUT: svuota la WorldDataCache a fine suite.
##
## La cache e un singleton di processo (static): senza questo cleanup i mondi
## costruiti dalle ultime suite resterebbero referenziati fino all'uscita del
## processo, gonfiando il warning "resources still in use at exit". Azzerarla qui
## non toglie nulla al riuso cross-suite (avviene gia durante il run).

func run() -> void:
	WorldDataCache.clear()
