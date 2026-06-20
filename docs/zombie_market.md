# Mercato ricorrente zombie survival

## Apertura e avanzamento wave

La zombie survival apre il mercato dopo il completamento integrale delle boss
wave 5, 10, 15 e successive. `WaveManager` resta in stato `REWARD` con la
prossima wave bloccata: durante questa fase non vengono programmati spawn. Il
mercato viene processato una sola volta per indice wave e viene annullato,
insieme alle offerte, quando la run termina o viene riavviata.

Ogni player vivo deve segnarsi `READY`. La wave successiva parte soltanto
quando tutti i player vivi sono ready; un singolo player non puo chiudere il
mercato per il party. Durante la fase mercato il combat input e disabilitato e
i player ricevono una sorgente di invulnerabilita temporanea.

## Wallet comune

Il mercato usa il denaro party gia gestito da `ProgressionManager`. Il saldo e
unico, sempre visibile e ogni acquisto lo scala tramite
`try_spend_money()`. Un saldo insufficiente nega l'acquisto senza applicare
l'oggetto. Questa scelta mantiene una sola autorita per la valuta condivisa e
resta coerente con reward wave e pickup denaro esistenti.

## Acquisti per-player

- Cura rapida: 25 HP, costo 8.
- Cura completa: 55 HP, costo 14.
- Refill arma equipaggiata: costo 10; ripristina caricatore e riserva iniziale.
- Refill di tutte le armi: costo 22.
- Armi casuali: aggiunte all'inventario del player che compra senza sostituire
  o resettare le altre `WeaponInstance`.

Una cura a HP pieni e un refill senza ammo mancanti vengono negati senza
spendere denaro. L'inventario corrente non impone una capacita massima; gli ID
gia posseduti vengono rifiutati esplicitamente dal mercato.

## Offerta casuale

Ogni apertura genera quattro ID unici dal `WeaponCatalog`. L'estrazione usa i
pesi di rarita configurabili del controller (`common`, `uncommon`, `rare`,
`epic`) e i prezzi sono raccolti in `weapon_cost_by_rarity`. La UI mostra nome,
categoria, rarita, costo, danno, fire rate, range e caricatore. La selezione
successiva non puo essere identica, nello stesso ordine, a quella precedente.

## Estensioni future

`SurvivalMarketController` mantiene stato, offerte e ready;
`SurvivalMarketPurchaseService` applica e rende atomici gli acquisti;
`SurvivalMarketUI` possiede rendering e input per slot. Nuove opzioni possono
quindi aggiungere perk, armor, revive, upgrade o reroll senza spostare
responsabilita nel `WaveManager`. Costi e quantita sono export configurabili e
possono essere migrati a `Resource` di bilanciamento se il catalogo servizi
cresce.

## Verifica

```text
godot --headless --path . --script res://tests/zombie_market_smoke_test.gd
```

Checklist manuale: `docs/testing/manual_checklist.md`, sezione
"Regressione mercato zombie".
