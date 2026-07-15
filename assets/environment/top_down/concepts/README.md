# Prop raster legacy migration

Le cinque tavole raster che alimentavano i prop dei biomi sono state rimosse
dal runtime durante la migrazione al contratto top-down cardinale v11. Il
contratto operativo corrente e v12. I loro
ritagli `AtlasTexture` incorporavano ancora geometria isometrica e non erano
compatibili con una griglia ortogonale.

I 23 ID coinvolti sono ora asset SVG individuali in
`objects/generated_props/`, prodotti da
`tools/generate_top_down_environment_assets.gd` con questi vincoli:

- impronta rettangolare vista dall'alto e allineata agli assi dello schermo;
- nessuna griglia diamond o asse inclinato;
- orientamento dritto a rotazione zero; nessun asset viene inclinato al runtime;
- profondità esclusivamente visuale, resa con una facciata sud controllata;
- collisione, footprint e Y-sort governati dal manifest, non dalla silhouette;
- sorgente `project_svg_generator` e attribution
  `environment_top_down_internal`.

La cartella resta come registro della migrazione e come guardrail: nuove tavole
concept non devono essere usate direttamente come atlanti runtime. Ogni nuovo
prop va esportato come asset individuale con il proprio contratto nel manifest.
