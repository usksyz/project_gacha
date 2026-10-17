# Projet Gacha

Jeu mobile (format portrait 720x1280) fait avec **Godot 4** en **GDScript**.
Inspiré du gacha du manhwa « Pick Me Up » : invocation de héros de 1 à 5 étoiles,
héros uniques qui peuvent mourir définitivement, Tour à étages, gestion de base.

## Principes
- Vue du Maître : le joueur est le Maître derrière son téléphone. Il ne voit que les fenêtres système,
  des notifications filtrées, ce que les héros font et des fiches qui se révèlent peu à peu. Les héros
  agissent seuls et lui font des suggestions.
- Fidélité à l'œuvre d'abord ; les ajouts du projet sont signalés comme tels (dans le code et ici).
- Chaque compétence a deux histoires séparées : comment elle s'acquiert (une seule fois) et comment elle
  s'utilise (passive, conditionnelle, réflexe, active ponctuelle ou active à bascule). Ne jamais confondre
  les deux (exemple : Berserk s'acquiert une fois aux portes de la mort, puis s'active et se désactive).
- Tous les chiffres sont provisoires et rangés dans `scripts/game_data/`.
- Chaque étape : un commit par point, sauvegarde compatible avec les parties existantes, tests en mode
  normal (pas seulement en mode dev), CLAUDE.md mis à jour, liste de ce qu'il faut tester.
- Tests et sauvegarde locale (règle du porteur du projet, pour toutes les sessions ; remplace l'ancienne règle
  « ne jamais modifier la vraie sauvegarde ») : Claude peut modifier ou réinitialiser la sauvegarde locale
  (`user://sauvegarde.cfg`, sur le PC : `%APPDATA%\Godot\app_userdata\Projet Gacha`) si c'est utile pour tester.
  Avant la première modification d'une session, une copie datée de l'ancienne (sauvegarde et paramètres) dans un
  dossier à part (`%APPDATA%\Godot\app_userdata\Projet Gacha - copies\<date>_<étape>`). Les simulations
  (`sim_tower`, bancs de mesure) restent dans une copie du projet (worktree + `override.cfg`, voir P1a-bis), pour
  ne pas fausser les mesures.
- Copies d'avant chaque prompt (demande du porteur du projet) : avant de modifier, les fichiers concernés sont copiés
  dans `backups/avant-promptN/` (mêmes chemins), poussés avec le reste ; `backups/.gdignore` empêche Godot de les
  lire (sinon les `class_name` seraient en double).

- Règles de travail pour les simulations (copies du projet) : voir aussi `docs/mesures.md` (outils et mesures).
  Copies du projet pour les simulations : `override.cfg` en UTF-8 SANS BOM (PowerShell `Set-Content -Encoding utf8`
  en ajoute un : Godot ignore alors le fichier et les simulations écrivent dans la vraie sauvegarde, constaté en C3 ;
  écrire avec `[IO.File]::WriteAllText(..., (New-Object Text.UTF8Encoding $false))`).

## Cahier des charges
Le cahier des charges est un document Claude Docs que le porteur du projet complète au fil du temps :
https://claude.ai/artifact/Tq9kGm18rz2nY8Lkyy2nxE (« Jeu inspiré de Pick Me Up — Feuille de route »).
La référence est l'onglet « Feuille de route v2 » : sa section 2 liste les règles confirmées par l'œuvre
(chapitres 1 à 20), sa section 3 l'état du code et les écarts, sa section 4 le plan par phases (0 à 8),
avec un prompt par étape. Le travail suit ces phases dans l'ordre. Les autres onglets (« Suivi
entraînement et compétences », « Améliorations combat, classes, personnalité »...) donnent les détails.
Relire la section concernée avant de coder, et signaler les écarts plutôt que trancher seul.

Noms : les mécaniques peuvent copier Pick Me Up, mais les noms et l'univers restent originaux.
Exceptions : les héros secrets (Han, Hansen, Zid, Shei, Jenna, Aaron, la magicienne Yvolka, la voleuse
Edith...), clins d'œil au manhwa (stats du tableau du cahier quand on les connaît : clé « stats ») ; et les
trois donjons journaliers (Mine d'Isralta, Forêt Kenout, Plateau Sinmiel, choix du porteur du projet).
Ils sont mortels comme les autres (feuille de route v2 ; avant, ils étaient immortels) et s'obtiennent tous
par code secret, Han compris (code « HAN », choix du porteur du
projet ; avant, Han était donné au début), dans Paramètres > Codes secrets ou sur la Place publique du hub.
Une partie neuve commence sans héros. Un héros secret déjà possédé ne peut pas être obtenu deux fois, même
tombé (la mort est définitive). Ils sont définis dans `SECRET_HEROES` (`game_data/heroes.gd`). Ils peuvent
être sacrifiés en synthèse comme les autres (choix du porteur du projet) : seul un favori est protégé.
Immortalité : seulement en mode dev, case « Immortel (mode dev) » des outils de la fiche (`hero["immortal"]`,
`dev_set_immortal`) ; `GameData.is_immortal(hero)` = mode dev actif et case cochée (hors du mode dev, la case
ne fait rien). Sauvegarde version 2 (`SAVE_VERSION`) : au chargement d'une version 1, les héros secrets
perdent leur immortalité.
Le code « SECRET_HERO » (`GameData.SECRET_MENU_CODE`, réutilisable) ouvre `SecretHeroMenu` (`scripts/secret_hero_menu.gd`) :
la fiche de chaque héros secret (stats tirées à l'ouverture : ce sont celles qu'il aura), on en choisit un
ou plusieurs, puis « Invoquer ». Les codes individuels (HAN, JENNA...) marchent toujours.

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
- `scripts/game_data.gd` : autoload `GameData`, données et règles du jeu. Le code est rangé par thème
  dans `scripts/game_data/`, en une pile de classes : chaque fichier `extends` le précédent et
  `game_data.gd` est en haut, donc on écrit toujours `GameData.xxx` partout. De bas en haut :
  `game_state.gd` (`GameState` : variables enregistrées, or et gemmes, signaux, conseils du Système, tutoriel), `heroes.gd` (`GameHeroes` :
  fiche, stats, héros secrets, compétences, expérience, changement de classe, équipes, favoris, `is_away`),
  `personality.gd` (`GamePersonality` : santé mentale, traits de caractère), `training.gd`
  (`GameTraining` : terrain d'entraînement), `items.gd` (`GameItems` : armes, arsenal, équipement,
  matériaux de l'entrepôt), `summon.gd` (`GameSummon` : invocation, codes secrets), `lobby.gd`
  (`GameLobby` : construction, postes d'assistant, donjon journalier, forge), `synthesis.gd`
  (`GameSynthesis` : promotion, synthèse), `tower.gd` (`GameTower` : Tour, quêtes, ennemis, combat et
  récompenses), `save.gd` (`GameSave` : sauvegarde, partie neuve), puis `game_data.gd` (lancement et
  outils du mode dev). Un fichier ne peut utiliser que ce qui est en dessous de lui dans la pile : une
  nouvelle fonction va dans le fichier de son thème, ou plus haut si elle a besoin d'un thème du dessus.
  Sauvegarde de la partie (`user://sauvegarde.cfg`) : relue au lancement, réécrite par `save_game()` après
  chaque changement (toute nouvelle fonction qui modifie la partie doit l'appeler), effacée par
  « Recommencer la partie ». `save_game()` est déclarée vide dans `game_state.gd` (pour que tous les
  fichiers puissent l'appeler) et remplacée par la vraie dans `save.gd`. Une nouvelle variable enregistrée
  va dans `game_state.gd`, et dans `save_game()` / `load_game()` / `_new_game()` (`save.gd`).
- `scripts/settings.gd` : autoload `Settings`, paramètres du joueur (volumes, vibrations, plein écran),
  enregistrés dans `user://parametres.cfg`.
- `scripts/settings_panel.gd` : fenêtre des paramètres (roue dentée en haut à droite), avec les codes
  secrets et « Recommencer la partie » ; `scripts/code_pad.gd` : saisie des codes secrets (aussi sur la
  Place publique du hub).
- Police : la police de Godot n'a pas ★ ← → ♥ ♡ ◆ ▶ ∞ ✓, et sur le web aucune police de l'appareil ne prend
  le relais (carrés vides sur le téléphone). `main.gd` (`_add_symbol_font`) ajoute DejaVu Sans
  (`assets/fonts`, licence libre) en secours de la police par défaut. Un nouveau symbole : vérifier qu'il
  est dans DejaVu Sans. Textes longs : toujours `autowrap_mode` (un texte sur une ligne trop large élargit
  tout l'écran sur le téléphone, dont les lettres sont un peu plus larges que sur PC).
- Mode dev (pour tester), demandé par le porteur du projet à la place des anciens boutons « (test) » :
  le code secret `Settings.DEV_CODE` (« MODEDEV ») l'active, `Settings.dev_mode` est enregistré sur
  l'appareil (il survit à « Recommencer la partie »). Or et gemmes infinis : `GameData.gold` / `gems` sont
  des propriétés qui valent `DEV_MONEY` en mode dev et ignorent les dépenses et les gains ; les vraies
  réserves (`real_gold`, `real_gems`) sont celles de la sauvegarde. Outils : fenêtre `DevPanel`
  (Paramètres > « Outils du mode dev » : créer un héros, étage de la Tour, lieux, bâtiments, matériaux,
  plans, quitter le mode dev) et section « Outils du mode dev » sur la fiche d'un héros (niveaux, XP,
  étoile gratuite, stats, donner / régler / retirer une compétence, ressusciter). Fonctions `dev_*` à la fin
  de `game_data.gd`. Ne plus ajouter de boutons de test : ajouter l'outil au mode dev.
- `scripts/drag_scroll.gd` : autoload `DragScroll`, défilement au doigt (ou clic maintenu) partout dans
  les `ScrollContainer` et `RichTextLabel`, même en commençant sur un bouton, avec élan. Créer les zones
  qui défilent avec `UI.make_scroll()` (barres cachées).
- Saisie de texte : toujours un `LineEdit` avec le clavier de l'appareil (téléphone ou PC), jamais un
  clavier refait dans le jeu ; `html/experimental_virtual_keyboard=true` dans `export_presets.cfg`
  fait apparaître le clavier du téléphone dans la version web.
- `scripts/ui.gd` : classe `UI`, fonctions communes (labels, boutons, cartes de héros, fenêtres système).
- Visuels (onglet « Piste graphique » du cahier) : images de test d'environ 512 px dans `assets/ui/`.
  Réglage `Settings.new_visuals` (Paramètres > « Nouveaux visuels », signal `visuals_changed`) : les
  anciens visuels restent disponibles pour comparer, tout nouveau visuel doit les garder.
  Écran d'invocation : portail en fond plein écran + voile de 40 %, boutons `SummonButton`
  (`shaders/summon_button.gdshader` : détourage, plaques sur les textes anglais, teinte du vortex,
  halo et glitch au toucher). Cartes `FramedHeroCard` (`shaders/hero_frame.gdshader` : cadre teinté
  selon la rareté, fenêtre percée, portrait provisoire `HeroPortrait` dessous) sur la fiche du héros et
  les cartes d'équipe. Gemmes : `GemIcon` (cristal détouré `icone-gemme.png`, fait par
  `tools/detour_gemme.gd`, qui lévite) via `UI.make_gem_amount()`. Les positions dans les images
  (CROP, rectangles) sont en pixels de l'image source, dans le script ET le shader : à refaire si une
  image est remplacée par une version plus grande.
- `scripts/battle.gd` (`Battle`, le combat) : en haut d'une pile de classes rangées par thème dans `scripts/battle/`
  (comme `GameData` ; voir `docs/combat.md`, « Fichiers de `Battle` »). `tools/check_scripts.gd` compile tous les
  scripts avec les autoloads (dans une copie du projet).
- Un script par écran (`class_name`), dont l'interface est construite par le code :
  `hub_screen.gd` (+ `hub_map.gd`, la cité circulaire dessinée ; clavier des codes secrets),
  `summon_screen.gd`, `collection_screen.gd`, `dungeons_screen.gd` (liste des donjons, composition des
  équipes à l'avance, annonce de la quête de l'étage, choix de l'équipe, combat).
- Un écran peut définir `on_shown()`, appelée à chaque fois qu'il s'affiche.

## Documentation par système (dossier `docs/`)
Le détail de chaque système est dans son fichier ; le lire avant d'y toucher, et le mettre à jour avec le code.
- `docs/tutoriel.md` : conseils du Système, tutoriel obligatoire d'une partie neuve.
- `docs/heros.md` : héros (poids de la mort, favoris, changement de classe, longues listes, progrès des compétences, phase 1 : stats, croissance, compétences, Berserk, fusions).
- `docs/personnalite.md` : personnalité (santé mentale, traits, peur, liens, hostilités, duels), personnalité v2 (P1a, P1a-bis, P1b, P2) et la vie de la cité (prompt 4).
- `docs/combat.md` : équipes, `battle.gd`, Combat v2 (C1, C2, C3), phases 1.1 et 1.2, préparer et comprendre un combat (prompt 3), la Tour (phase 2).
- `docs/economie.md` : armurerie et armes, gacha (phase 3), économie (prompt 1).
- `docs/lobby.md` : hub 3D, terrain d'entraînement, affectations, donjon journalier, forge, chambre de synthèse (phases 4 à 6).
- `docs/mesures.md` : outils de simulation et toutes les mesures (avant / après de chaque étape).

## Avancement (phases du cahier des charges)
- Phase 1 (héros et combat) : faite (`docs/heros.md`, `docs/combat.md`).
- Phase 2 (Tour) : faite (`docs/combat.md`, « Phase 2 »).
- Phase 3 (gacha) et économie (prompt 1) : faites (`docs/economie.md`).
- Phases 4 à 6 (lobby, artisanat, fin de jeu) : premières versions (`docs/lobby.md`).
- Personnalité v2 : P1a, P1a-bis, P1b, P2 faites, première tranche de P3 (prompt 4) (`docs/personnalite.md`).
- Combat v2 : C1, C2 faites ; C3 en cours (`docs/combat.md`).
