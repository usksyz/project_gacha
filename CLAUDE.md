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
  ennemis et récompenses de la Tour). Il gère aussi la sauvegarde de la partie (`user://sauvegarde.cfg`) :
  relue au lancement, réécrite par `save_game()` après chaque changement (toute nouvelle fonction qui
  modifie la partie doit l'appeler), effacée par « Recommencer la partie ».
- `scripts/settings.gd` : autoload `Settings`, paramètres du joueur (volumes, vibrations, plein écran),
  enregistrés dans `user://parametres.cfg`.
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
  `summon_screen.gd`, `collection_screen.gd`, `dungeons_screen.gd` (liste des donjons, annonce de la
  quête de l'étage, choix de l'équipe, combat).
- `scripts/battle.gd` : classe `Battle`, combat en temps réel vu du dessus, joué en direct par pas
  de 0,1 s (`start()` puis `step()`) : grille avec décor, recherche de chemin `AStarGrid2D`, ligne de
  vue pour les tirs, particularités de chaque classe, saignement, éveil, renforts, remparts, ordres
  du joueur (`order_move`, `order_attack`). `run()` joue tout d'un coup sans ordres.
  `scripts/battle_view.gd` : classe `BattleView`, affiche le combat en direct (pions, coups,
  chiffres) ; on touche un héros puis un endroit ou un ennemi pour lui donner un ordre ; pause.
  Le combat continue si on change d'onglet. Il est noté dans la sauvegarde dès le début
  (`GameData.pending_battle`) : si le jeu est fermé en plein combat, il est terminé sans ordres au
  lancement suivant, et `main.gd` annonce le résultat (« Pendant ton absence »).
- Choix du porteur du projet pour le combat : du temps réel (pas du tour par tour) où l'on voit les
  personnages bouger, utiliser le décor, et les ennemis leur foncer dessus. On vit le combat :
  jamais de bouton « passer » ni d'accélération. Le joueur soutient ses héros en les guidant
  pendant le combat (ce qui peut changer le résultat) ou les laisse se débrouiller ; plus tard, les
  consignes de la salle d'opération seront apprises peu à peu par les héros qui participent au
  combat. Vue du dessus pour l'instant, vue isométrique 3D plus tard.
- Un écran peut définir `on_shown()`, appelée à chaque fois qu'il s'affiche.

## Avancement (phases du cahier des charges)
- Phase 1 (héros et combat) : fiche à 4 stats, classe Novice, niveaux/XP, plafond par étoile,
  croissance cachée et talents cachés des 1 étoile, combat auto, mort définitive avec cause : fait.
  Saignement/hémorragie, éveil des compétences en situation critique, premières compétences
  (Résistance à la douleur, Mouvement souple, Calme, Berserk ; Calme et Berserk incompatibles sauf
  pour Han) : fait, chiffres provisoires dans `battle.gd` et `GameData.SKILLS`.
  Reste : fusion de compétences, rangs de compétence, compétences d'arme et d'entraînement,
  Berserk affiché sur la fiche, mana, consignes en combat.
- Phase 2 (Tour) : étages, équipes de 5, boss tous les 5 étages, or/gemmes/XP, MVP : fait.
  Quêtes d'étage (`GameData.floor_quest`) : extermination (1), subjugation (2), annihilation avec
  renforts, survie à la horde tous les 5 étages (niveau caché), défense de la cité tous les 10 étages
  (remparts, triple avertissement), limite de tours, annonce du donjon journalier après l'étage 5 : fait.
  Au combat, 6 ennemis au plus à la fois, les autres arrivent en renfort.
  Paliers : tous les 5 étages (étage de boss), les ennemis gagnent 2 niveaux de plus
  (`TIER_BONUS_LEVELS`), et les étages suivants restent à ce cran : il faut y arriver préparé.
  Difficulté voulue par le porteur du projet : la défense de l'étage 10 reste très dure (presque
  impossible au niveau de départ). C'est un palier réservé aux héros équipés, avec des compétences
  et de l'expérience : ne pas l'adoucir sans lui demander.
  Reste : matériaux gradés, glisser-déposer, équipes de 3 et quêtes à deux équipes,
  autres types de quêtes (escorte, invasion...).
- Phase 3 (gacha) : invocation de héros faite (mages rares). Reste : tirage d'armes, arsenal.
- Phases 4 à 6 (lobby, artisanat, fin de jeu) : à faire. Sauvegarde de la partie : faite
  (reste l'équilibrage de la phase 6).
