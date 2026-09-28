# Projet Gacha

Jeu mobile (format portrait 720x1280) fait avec **Godot 4** en **GDScript**.
Inspiré du gacha du manhwa « Pick Me Up » : invocation de héros de 1 à 5 étoiles,
héros uniques qui peuvent mourir définitivement, Tour à étages, gestion de base.

## Cahier des charges
Le cahier des charges est un document Claude Docs que le porteur du projet complète au fil du temps :
https://claude.ai/artifact/Tq9kGm18rz2nY8Lkyy2nxE (« Jeu inspiré de Pick Me Up — Feuille de route »).
C'est la référence pour les règles du jeu et l'ordre de développement (6 phases) : relire la section
concernée avant de coder, et signaler les écarts plutôt que trancher seul.

Noms : les mécaniques peuvent copier Pick Me Up, mais les noms et l'univers restent originaux.
Seule exception : les héros secrets (Han, Hansen, Zid, Shei, Jenna, Aaron...), clins d'œil au manhwa.
Ils sont immortels ; Han est présent dès le début, les autres s'obtiennent par code secret
(Paramètres > Codes secrets, ou la Place publique du hub). Ils sont définis dans `SECRET_HEROES` (`game_data.gd`).

## Contexte
- Le porteur du projet débute en programmation de jeux (bases de Python au lycée) :
  répondre en français, expliquer simplement, garder un code lisible et commenté en français.
- Le projet est travaillé depuis un PC et depuis un téléphone (sessions Claude Code dans le cloud).
- Chaque push sur `main` publie la version web sur GitHub Pages (`.github/workflows/deploy-web.yml`).
  La publication réécrit `scripts/build_info.gd` (commit + date), affiché en bas des paramètres :
  pratique pour vérifier que le téléphone n'affiche pas une ancienne version (cache d'environ 10 min).

## Structure
- `scenes/main.tscn` + `scripts/main.gd` : scène de départ ; barre du haut (or, gemmes),
  écran actif, barre de menus en bas (Hub, Invocation, Collection, Donjons).
- `scripts/game_data.gd` : autoload `GameData`, données et règles (invocation, fiche de héros :
  force/intelligence/santé/dextérité, niveaux et expérience, croissance cachée, héros secrets,
  ennemis et récompenses de la Tour).
- `scripts/settings.gd` : autoload `Settings`, paramètres du joueur (volumes, vibrations, plein écran,
  vitesse de combat), enregistrés dans `user://parametres.cfg`.
- `scripts/settings_panel.gd` : fenêtre des paramètres (roue dentée en haut à droite), avec les codes
  secrets et « Recommencer la partie » ; `scripts/code_pad.gd` : saisie des codes secrets (aussi sur la
  Place publique du hub).
- `scripts/drag_scroll.gd` : autoload `DragScroll`, défilement au doigt (ou clic maintenu) partout dans
  les `ScrollContainer` et `RichTextLabel`, même en commençant sur un bouton, avec élan. Créer les zones
  qui défilent avec `UI.make_scroll()` (barres cachées).
- Saisie de texte : toujours un `LineEdit` avec le clavier de l'appareil (téléphone ou PC), jamais un
  clavier refait dans le jeu ; `html/experimental_virtual_keyboard=true` dans `export_presets.cfg`
  fait apparaître le clavier du téléphone dans la version web.
- `scripts/ui.gd` : classe `UI`, fonctions communes (labels, boutons, cartes de héros, fenêtres système).
- Un script par écran (`class_name`), dont l'interface est construite par le code :
  `hub_screen.gd` (+ `hub_map.gd`, la cité circulaire dessinée ; clavier des codes secrets),
  `summon_screen.gd`, `collection_screen.gd`, `dungeons_screen.gd` (liste des donjons, choix de l'équipe, combat).
- `scripts/battle.gd` : classe `Battle`, combat automatique calculé d'un coup (règles et
  particularités de chaque classe) ; `scripts/battle_view.gd` : classe `BattleView`, rejoue le combat.
- Un écran peut définir `on_shown()`, appelée à chaque fois qu'il s'affiche.

## Avancement (phases du cahier des charges)
- Phase 1 (héros et combat) : fiche à 4 stats, classe Novice, niveaux/XP, plafond par étoile,
  croissance cachée et talents cachés des 1 étoile, combat auto, mort définitive avec cause : fait.
  Reste : compétences (gain en combat, fusion, conditions de déblocage), états (saignement),
  éveil, mana.
- Phase 2 (Tour) : étages, équipes de 5, boss tous les 5 étages, or/gemmes/XP, MVP : fait.
  Reste : quêtes d'étage (types, limite de temps, survie), matériaux gradés, glisser-déposer.
- Phase 3 (gacha) : invocation de héros faite (mages rares). Reste : tirage d'armes, arsenal.
- Phases 4 à 6 (lobby, artisanat, fin de jeu, sauvegarde) : à faire.
