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
- Conseils du Système (accueil d'un nouveau joueur, demande du porteur du projet ; aucune nouvelle mécanique) :
  fenêtre « Conseil » la première fois que le Maître fait quelque chose. Ids dans `GameData.TIP_IDS`
  (`game_state.gd`) : bienvenue (partie neuve, appelée par `main.gd` au lancement), invocation (`summon_screen.gd`,
  cartes retournées), equipe (« Composer les équipes » ou « Former l'équipe »), etage (annonce de l'étage),
  blessure et mort (`report["tips"]` de `finish_tower_battle`, montrés après « Continuer » ou le rapport
  d'absence ; mort aussi après une synthèse), batiment (`build`, `check_auto_buildings`, terrain d'entraînement).
  `GameData.show_tip(id)` émet `tip_requested` si le conseil n'est pas vu et `Settings.tips` actif ; `main.gd`
  les met en file et en montre un à la fois, après ses autres fenêtres (`WINDOW_NAMES`) ; vu = noté à la
  fermeture (`seen_tips`, sauvegardé « conseils_vus » ; une ancienne sauvegarde les compte tous comme vus).
  Textes dans `scripts/system_tips.gd` (`SystemTips`). Paramètres : « Conseils du Système » (activé / désactivé,
  `parametres.cfg`) et « Réafficher les conseils » (`reset_tips`). Nouveau conseil : un id dans `TIP_IDS`, son
  texte dans `SystemTips`, un `show_tip` là où ça arrive. Les ids « tuto_... » et « bienvenue » sont ceux du
  tutoriel (`is_tutorial_tip`) : obligatoires, le réglage ne les coupe pas, « Réafficher » ne les rejoue pas.
- Tutoriel obligatoire d'une partie neuve (demande du porteur du projet ; cahier, « Tutoriel et interface » :
  premier combat puis la synthèse, « dont la porte s'ouvre à ce moment ») : `GameData.tutorial_step`
  (`game_state.gd`, sauvegardé « tutoriel » ; absent d'une ancienne sauvegarde = pas de tutoriel), étapes
  `TUTORIAL_STEPS` : invocation, armes, equipe, etage, synthese, puis "" (fini). On commence avec exactement l'or
  d'une invocation normale x`TUTORIAL_SUMMON_COUNT` (50 000 or ; gemmes 3000 comme avant). 1. Seule la normale x10
  est permise (`summon_allowed`) ; elle donne un 3 étoiles garanti, un 2 étoiles une fois sur deux
  (`FIRST_SUMMON_TWO_STAR_CHANCE`), le reste en 1 étoile (`_first_summon_rarities`). 2. Armes (étape T1, demande
  du porteur du projet) : fenêtre « tuto_armes » (les héros partent avec les armes de l'arsenal, il faut en
  invoquer) ; en la fermant, le hub, où une flèche « Touche ici » montre l'armurerie (`HubCity3D.TUTORIAL_POINTS`,
  `HubScreen.TUTORIAL_PLACES` : seul ce lieu s'ouvre) ; à l'armurerie, seul le tirage x10 est permis
  (`weapon_draw_allowed`), et il est offert (`weapon_draw_cost` = 0 ; choisi plutôt que 50 000 or de plus au
  départ : rien en trop, et une partie déjà en cours n'a pas besoin d'or). Il donne au moins une épée, un bouclier
  et un arc (`TUTORIAL_WEAPON_TYPES`, `items.gd`), compte pour le terrain d'entraînement (10 armes : fenêtre
  « Construction terminée », pas d'étape en plus ; son animation dans la cité passe avant celle de la chambre de
  synthèse, à l'étape 5). Puis fenêtre « tuto_arsenal » (les héros prennent eux-mêmes une arme en partant,
  bouton « Auto ») et celle de l'étape suivante. Forge fermée pendant le tutoriel. 3. Composer une équipe
  (« Terminé » avec au moins un héros ; « Entrer dans la Tour » fermé avant). 4. Gagner l'étage 1 (défaite :
  on recommence). La chambre de synthèse est alors construite gratuitement (`finish_tower_battle`). 5. Retour à
  la cité (« Continuer » : `DungeonsScreen.navigate`) : la chambre se construit sous les yeux du Maître
  (demande du porteur du projet : `HubCity3D` la laisse hors de la cité tant que « tuto_synthese » n'est pas vu,
  puis joue l'animation ; signal `construction_finished` → fenêtre de l'étape, `hub_screen.gd`), une flèche
  « Touche ici » la montre (`_place_tutorial_pointer`) et il faut la toucher (les autres lieux, les boutons du
  hub et les héros ne répondent pas). Ancien plan 2D : la fenêtre tout de suite. Puis une synthèse ; moins de
  2 héros vivants : le tutoriel s'arrête (`end_tutorial`).
  Passage d'étape : `advance_tutorial(étape)` (signal `tutorial_changed`). `main.gd` : bandeau en haut
  (`SystemTips.tutorial_goal`), seul l'onglet de l'étape est permis (`TUTORIAL_SCREENS` ; armes et synthèse : le
  hub), reprise à l'écran de l'étape au lancement, fenêtre de chaque étape (`show_tutorial_tip`), hub en fermant
  « tuto_armes » et « tuto_fin ». Mode dev : « Passer le tutoriel » (`dev_skip_tutorial` : rien n'est donné, ni
  le tirage offert). Sauvegarde version 7 : une partie arrêtée à l'étape « equipe » sans équipe composée revient
  à l'étape « armes » ; une équipe composée, ou une étape plus loin : l'étape est sautée (`load_game`).
  Vérification : `tools/test_tutoriel.tscn` (avec une fenêtre ; voir son en-tête) joue une partie neuve en mode
  normal à travers les écrans (invocation, flèche et armurerie touchées dans la cité 3D, tirage, équipe, étage 1
  jusqu'à la victoire avec les héros armés, synthèse), la reprise au lancement et les anciennes sauvegardes, avec
  des captures ; il recommence la partie (voir « Tests et sauvegarde locale »).
- Police : la police de Godot n'a pas ★ ← → ♥ ♡ ◆ ▶ ∞ ✓, et sur le web aucune police de l'appareil ne prend
  le relais (carrés vides sur le téléphone). `main.gd` (`_add_symbol_font`) ajoute DejaVu Sans
  (`assets/fonts`, licence libre) en secours de la police par défaut. Un nouveau symbole : vérifier qu'il
  est dans DejaVu Sans. Textes longs : toujours `autowrap_mode` (un texte sur une ligne trop large élargit
  tout l'écran sur le téléphone, dont les lettres sont un peu plus larges que sur PC).
- Poids de la mort : `UI.make_death_window(hero, memorial)` (portrait `FramedHeroCard.HeroPortrait`, nom,
  étoiles, classe et niveau, cause, traits révélés, liens, puis « Y a perdu un ami / un frère d'armes » pour
  chaque ami ou frère d'armes vivant) remplace l'ancienne fenêtre « Un héros est tombé » des rapports de combat,
  et s'affiche pour chaque sacrifié de la synthèse. Collection > Tombés : fiche figée (`_show_memorial` de
  `collection_screen.gd` : « En mémoire », combats dans la Tour `hero["fights"]`, qui compte aussi le combat
  fatal, stats et compétences ; « Ressusciter » en mode dev).
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
- Favoris (cahier : « le Maître peut mettre des héros en favoris ») : `hero["favorite"]`, 20 au plus
  (`GameData.FAVORITES_MAX`, choix du porteur du projet ; seuls les vivants comptent). Bouton sur la fiche
  du héros, cœur ♥ sur les cartes, bouton ♥ dans `HeroFilter` pour ne garder que les favoris.
  Un favori ne peut pas être sacrifié en synthèse.
- Changement de classe (cahier, onglet « Invocations et classes », section « Classes et changements de
  classe » ; demande du porteur du projet : la voie du 1 étoile « déchet à trésor ») : `heroes.gd`, section
  « Changement de classe », chiffres provisoires. 1er changement : un Novice au niveau
  `FIRST_CLASS_CHANGE_LEVEL` (10) devient Apprenti guerrier (Maîtrise de l'épée ou Utilisation du bouclier)
  ou Apprenti voleur (Maîtrise de la dague ou de l'arc ; l'« épée courte » du cahier est comptée dans
  Maîtrise de l'épée), au choix s'il a les deux (`CLASS_PATHS`) ; sans compétence d'arme, il reste Novice et
  la fiche explique pourquoi (`class_change_problem`). 2e changement : apprenti au niveau
  `SECOND_CLASS_CHANGE_LEVEL` (20) avec une compétence d'arme de sa voie au niveau 5 → une des deux classes
  de sa voie, au choix (`CLASS_FINALS` : Guerrier / Chevalier, Archer / Assassin) ; ses compétences de rang
  Débutant passent Intermédiaire (rang affiché, mêmes effets) ou disparaissent (`CLASS_LOST_SKILLS` :
  Mouvement souple pour Guerrier et Chevalier, comme Han qui perd Mouvement secret). Mages et soigneurs :
  jamais par changement de classe (`INVOCATION_ONLY_CLASSES`). Les statistiques ne changent pas ; la classe
  change la stat favorisée (`CLASS_MAIN_STAT`) et les armes prises dans l'arsenal (`CLASS_WEAPONS`, bouclier
  pour l'apprenti guerrier). Fiche du héros : bouton « Changer de classe » (visible seulement quand c'est
  possible, pas pour un héros parti), fenêtre de choix, puis fenêtre système qui annonce la nouvelle classe.
  Rien de neuf dans la sauvegarde (la classe était déjà enregistrée). Reste : classes supérieures (Grand
  chevalier...), Maîtrise de la dague (pas encore apprenable : la voie du voleur passe par l'arc).
- Personnalité (cahier, onglet « Personnalité », sections 1 à 4 ; `personality.gd`, chiffres provisoires).
  Santé mentale `hero["mental"]` (0 à `MENTAL_MAX` 100, départ 100, nombre à virgule). En combat de la Tour,
  battle.gd la suit en direct (`fighter["mental"]`, `Battle._stress`) : blessures (`MENTAL_LOSS_WOUNDS` pour
  une vie entière perdue, à chaque coup), premier saignement, arrivée d'un boss, quête à avertissements (au
  début), allié tombé, Berserk (chaque seconde en rage) ; à la fin (`mental_after_battle`), défaite et victoire. Baisse aussi pour tous
  les vivants à chaque synthèse (`MENTAL_LOSS_SYNTHESIS` par sacrifié) ; remonte à la cité par heure de temps
  réel (repos `MENTAL_REST_PER_HOUR`, travail = poste ou entraînement `MENTAL_WORK_PER_HOUR`, rien si parti :
  `update_mental()`, appelée toutes les 5 s et avant chaque sauvegarde, `mental_updated_at` sauvegardé).
  Calme réduit les pertes (5 % par niveau, `mental_guard`). Sous `MENTAL_MALUS_START` (60), attaque et
  défense baissent en combat jusqu'à -30 % à 0 (`mental_factor`, appliqué à chaque coup : `Battle._mind`).
  Barre sur la fiche, les cartes d'équipe (`UI.add_mental_bar`, `TeamSlots` et grilles de l'écran Donjons)
  et l'encart de l'équipe en combat ; fenêtre « Personnalité » en fin de combat (`fighter["mind_news"]`).
  Traits (`TRAITS` : Courageux, Lâche, Loyal, Paresseux, Querelleur, Protecteur, Ambitieux, Mauvais, Meneur) :
  lus sur les paliers de la personnalité v2 depuis P1a-bis (`has_trait` → `PersonalityEngine.has_old_trait`,
  voir plus bas ; avant : 1 ou 2 tirés à l'invocation), `GameData.hero_traits(hero)` ([{"name", "known"}]),
  « ? » tant qu'ils sont cachés (`hero["revealed_traits"]`, par nom) ; révélés quand ils agissent ou tous les `TRAIT_REVEAL_FIGHTS`
  (5) combats (`hero["fights"]`). Effets branchés : Courageux (moitié) / Lâche (double) face aux boss,
  Protecteur (double) à la mort d'un allié, Ambitieux stresse quand un héros plus faible (niveau × étoiles)
  part dans la Tour à sa place (jamais sous 40), Loyal, Paresseux, Courageux et Lâche pour la rupture,
  Querelleur, Mauvais et Protecteur en combat (plus bas), Meneur en combat (rotation, voir « Phase 1.1 ») : les neuf traits ont leurs effets.
  Peur selon la menace (feuille de route v2, phase 0 ; avant : seulement les 1 étoile novices ; demandes
  antérieures gardées : « les forts survivent, les faibles meurent », pas de message pour la fuite, certains
  se battent contre leur peur). N'importe quel héros (secrets compris) peut avoir peur, seulement s'il y a
  une menace (`Battle._fear_threats`) : ennemi `FEAR_STRONGER_LEVELS` (5) niveaux au-dessus ou boss à portée
  d'engagement, horde (survie, défense), santé mentale sous `FEAR_LOW_MENTAL` (35), ou novice (1 étoile dans
  ses `NOVICE_FIGHTS` 3 premiers combats, `is_combat_novice` : le plus exposé). Moments : vue du premier ennemi à
  portée (`FEAR_SIGHT_ENEMY_CHANCE` 25 %, la menace « novice » ne compte pas), première blessure (30 %), chute
  d'un allié à moins de `FEAR_SIGHT` cases (50 %), arrivée d'un boss (50 %). `fear_chance` : chance du moment
  x `FEAR_RARITY_FACTOR` (1 étoile 1, 3 étoiles 0,45, 5 étoiles 0,2) x 1 / (1 + combats / 5) x (+25 % par
  menace en plus) ; Lâche x2, Courageux /2. Une fois par combat (`Battle._scare` → `_frighten`,
  -`FEAR_MENTAL_LOSS`). Effet : toutes les stats x`FEAR_STAT_FACTOR` (0,7 : attaque et défense dans `_mind`,
  vitesse, cadence, critiques ; `_fear`) pendant `FEAR_MAX_SECONDS` (20 s) au plus. Il fuit d'abord
  (`FEAR_FLEE_CHANCE` 45 %) `FEAR_SECONDS` (5 s), sourd aux ordres, ou se bat contre sa peur (il obéit).
  Tout fuyard (peur ou effondrement) encaisse x`FLEEING_DAMAGE_TAKEN` (2) et les monstres le préfèrent
  (`PREY_BONUS`). Levée (`_fear_tick`) : un allié à moins de `FEAR_LIFT_RANGE` (2,5) cases, ami ou frère
  d'armes, ou Courageux (trait révélé), pas lui-même effrayé, le rassure `FEAR_LIFT_SECONDS` (3 s) : fuite
  arrêtée, fenêtre « X n'est plus effrayé. » (`Battle.alerts`) et journal. Retour : une fois la peur passée,
  un coup grave (qui fait saigner) la ramène à `FEAR_RETURN_CHANCE` (50 %, traits compris). Seuls signes de
  la peur : « PEUR » sous son portrait (`Battle.afraid`) et « X a peur. » dans le journal ; rien n'annonce
  la fuite ni la fin naturelle ; une ligne dans « Personnalité » en fin de combat.
  Simulation (sans ordres, équipe 3★ + 2★ + 3 x 1★ au niveau de l'étage, 150 combats) : peurs par 1 étoile
  novice ~0,5 par combat comme avant ; 3 étoiles ~0 sauf horde et boss de l'étage 5 (0,4, 0,2 avec 10 combats
  d'expérience) ; victoires étage 1 : 99 % ; étages 2 à 4 : 19-30 % (avant ce changement : 24-34 %).
  Cette difficulté est gardée (choix du porteur du projet, qui la teste en jeu) : ne pas l'adoucir sans lui.
  Protecteur en combat (`Battle._ward_of`, `_guardian_for`, `_cover`) : un allié à moins de `PROTECT_RANGE`
  (5) cases sous `PROTECT_HP` (30 %) de vie → il va à son côté ; à moins de `PROTECT_GUARD_RANGE` (1,6), il
  encaisse `PROTECT_SHARE` (30 %) de ses coups, quitte à tomber (« tombé en protégeant X »).
  Désobéissance : sous `DISOBEY_START` (60), un ordre du Maître en combat peut être refusé (jusqu'à
  `DISOBEY_MAX` 50 % à 0, `disobey_chance`, bulle « Non ! »), puis le héros boude `DISOBEY_SULK` (3 s) ; Loyal
  divise le risque par deux et se révèle quand il fait obéir (`Battle._obeys`).
  Rupture (section 2 du cahier) : santé mentale à 0 pendant un combat, une fois par combat (`Battle._rupture`).
  Effondrement (85 %) : panique `PANIC_SECONDS` (6 s) sans écouter les ordres, fuite vers le bas de la carte
  (`PANIC_FLEE_CHANCE`, Lâche `COWARD_FLEE_CHANCE`) ou frénésie (frappe au hasard parmi les 3 plus proches,
  alliés compris) ; les alliés à `PANIC_RADIUS` perdent `PANIC_SPREAD_LOSS`. Éveil (15 %, Courageux 25 %) :
  `_awaken` de battle.gd, santé mentale à `RUPTURE_AWAKEN_MENTAL` (30). Fenêtre système pendant le combat
  (`Battle.alerts`, affichée 4 s par `BattleView` sans bloquer). État « En rupture » (`hero["broken"]`) : fin
  de combat à 0 → `break_hero` (quitte poste et entraînement) jusqu'à `BROKEN_RECOVERY` (50, `change_mental`) ;
  refuse l'entraînement et les affectations (`accepts_work`, raison dans `last_refusal` ; Paresseux refuse
  `LAZY_REFUSAL_CHANCE` 20 % même sans rupture) ; fenêtre d'avertissement avant la Tour ; s'il retombe à 0 en
  combat, mort de stress `STRESS_DEATH_CHANCE` (30 %, pas un immortel du mode dev).
  Liens (section 4 du cahier ; `personality.gd`, section « Liens ») : points par paire de héros dans
  `GameData.bonds` (sauvegardé, clé « 3-7 », plus petit numéro d'abord ; absent = inconnus), paliers
  `BOND_LEVELS` (inconnus, connaissance, ami, frère d'armes) à `BOND_THRESHOLDS` (0, 5, 25, 60). Fin d'un combat
  de la Tour (`bonds_after_battle`, appelée par `finish_tower_battle`) : chaque paire de survivants gagne
  `BOND_POINTS_FIGHT` + `BOND_POINTS_VICTORY` si victoire, x`HARD_VICTORY_FACTOR` si difficile (étage de boss,
  allié tombé ou survivants sous `HARD_VICTORY_HP` de leur vie) ; fenêtre « Liens » de fin (`report["bonds"]`).
  En combat (`fighter["bonds"]`, `Battle._bond`) : +5 % / +10 % attaque et défense (`BOND_FIGHT_BONUS`) à moins
  de `BOND_RANGE` cases d'un ami / frère d'armes ; à sa mort, perte de santé mentale x2 / x3 (`BOND_DEATH_FACTOR`).
  Groupes liés : une invocation de plusieurs héros a `LINKED_GROUP_CHANCE` (20 %) de donner 2 ou 3 héros qui
  se connaissent (`roll_linked_group`, noms inventés `LINKED_GROUP_NAMES`, `hero["group"]`), amis d'emblée,
  annoncés par une fenêtre « Groupe lié » sur l'écran d'invocation (`last_linked_group`). Fiche : groupe et
  liste des liens ; cartes du groupe (`TeamSlots`) : anneaux entrelacés (`UI.add_bond_badge`) quand un ami
  (vert) ou un frère d'armes (doré) est dans le même groupe.
  Hostilités (onglet principal du cahier, « Relations entre héros, groupes et duels ») : palier
  `BOND_HOSTILE` (-1, points négatifs, `bond_name`), sous « inconnus ». Chaque heure réelle à la cité, un
  Querelleur présent a `QUARREL_CHANCE_PER_HOUR` (10 %) de se brouiller avec un autre héros présent
  (`update_quarrels`, toutes les 5 s, `quarrels_checked_at` sauvegardé, 24 h au plus d'un coup) ; annonces
  dans `relation_news` (sauvegardé), fenêtre « Hostilité » de `main.gd` (signal `relations_changed`).
  Hostiles : plus de points de lien, aucun bonus, -`MENTAL_LOSS_HOSTILE` (5) chacun au début d'un combat
  ensemble (avertissement dans « Formation de groupe »). Pas de bagarre à la cité : duel, fenêtre
  `DuelPanel` (`scripts/duel_panel.gd`, par-dessus l'écran qui l'ouvre) : défi, pari, duel en direct dans un
  `BattleView` (`play(..., on_finish)`), fin. Quête « duel » de battle.gd (`duel_quest` : adversaire héros
  dans le camp ennemi, pas d'ordres, ni éveil, ni stress), arrêt à `DUEL_STOP_HP` (10 %) de vie, jamais de
  mort ; `finish_duel` : gagnant +`DUEL_WIN_MENTAL`, perdant -`DUEL_LOSE_MENTAL`, lien remis à « connaissance ».
  Deux façons : le Maître l'organise depuis la fiche (« Organiser un duel », `duel_problem`) ; ou un héros
  hostile Querelleur ou Ambitieux défie lui-même son rival (`CHALLENGE_CHANCE_PER_HOUR` 5 % par heure à la
  cité, `_roll_challenges` dans `update_quarrels`, `pending_challenges` sauvegardé, un par paire) : `main.gd`
  ouvre `DuelPanel` en mode défi (« Autoriser le duel » / « Refuser » ; refus : -`CHALLENGE_REFUSED_MENTAL`
  pour celui qui a défié, `refuse_challenge`) ; un défi attend si l'un est en mission, disparaît si l'un
  meurt. Paris (cahier : « avec l'accord des deux parties ») : si les deux ont plus de `BET_MIN_MENTAL` (40)
  de santé mentale (`bet_refusals`), le Maître mise `BET_STAKES` (100, 500, 1000 or) sur l'un des deux
  (`place_bet`, payé au départ) ; s'il gagne, `BET_PAYOUT` (x2), sinon rien.
  Mauvais : chaque Mauvais présent à la cité retire `MAUVAIS_EFFICIENCY_LOSS` (5 %) à `lobby_efficiency()`
  (points d'entraînement, chance de la forge, progrès des artisans ; `MAUVAIS_EFFICIENCY_MIN` 50 %) ; ceux
  qui travaillent au même endroit (même poste, ou terrain) regagnent `MAUVAIS_COWORKER_LOSS_PER_HOUR` de
  moins par heure ; trait révélé quand l'effet est remarqué (`notice_bad_heroes`).
  Les parties existantes : santé mentale à 100 au chargement (`load_game`) ; leurs traits : voir P1a-bis. Mode dev (fiche) :
  -20 santé mentale, santé mentale 100, mettre en rupture, « Lien +1 cran » et « Rendre hostile » avec un
  héros cherché par son nom (`dev_raise_bond`, `dev_make_hostile`). Reste : hostilité entre groupes, liens hors de la Tour (donjon journalier, lobby), repas de la cafétéria, perte au donjon
  journalier, héros en rupture au donjon journalier.
- Personnalité v2, étape P1a (cahier : Sommaire, « Personnalité : document de référence » sections 1 à 5
  et 7, sous-onglets « 1. Paliers », « 2. Axes », « 5. Facettes ») : le noyau seulement. Ses seuls effets en jeu
  passent par les anciens traits (P1a-bis, plus bas) ; le reste sera branché en P2. Deux classes hors de la pile de GameData : `PersonalityData`
  (`game_data/personality_data.gd`, données seulement) et `PersonalityEngine` (`personality_engine.gd`,
  fonctions `static`). Contrat : aucune mécanique ne lit `hero["persona"]` directement, tout passe par le moteur.
  Données : `AXES` (18 axes, identifiants AUD, CUR, SEN, COL, PER, MAI, EMP, HON, AMB, LOY, FOI, STA, OPT, VIT,
  CON, DOU, ACU, RYT ; + = premier pôle ; Rythme + = Nocturne), `FAMILIES` (4 familles, vitesse d'évolution
  x0,1 / x1 / x2 / x1), `TIER_DISTRIBUTION`, `RARITY_TAIL`, `CORRELATIONS`, `RARITY_BIAS`, `BACKGROUND_BIAS`,
  `TIER_LADDER`, `POLE_ACCESS` (par pôle « AUD+ » / « AUD- » : 5 = exclusive(s) par id, 7 = trait majeur et
  faiblesse, 9 = signature et compulsion, 10 = éveil ; textes et ids, effets en P2), `SYNERGIES`, `TENSIONS`,
  `COMPOSITES`, `EVOLUTION_COST`, `BEHAVIOURS` (les 7 comportements de l'onglet Facettes, 18 poids non nuls),
  `TICS` (2 par pôle), `METIERS` (poids par étoiles : 1★ métiers pauvres, 2 % liés au combat ; 5★ passés liés
  au combat à 80 % ; artisans experts rares), `LAYERS` (valeur, besoin, peur profonde, attachement, tirés selon
  les axes), `APTITUDE_DOMAINS` (talent : aptitudes 1 à 5 ; la croissance reste `hero["growth"]`), effort.
  Profil `hero["persona"]` (enregistré avec le héros, `PROFILE_VERSION` 1) : paliers -10 à +10, points
  d'évolution, poids personnels (x0,85 à x1,15), tics, couches, aptitudes, effort, métier, accès ouverts, graine.
  `generate(rarity, background, roster, seed, secret)` : tirage corrélé (loi normale, convertie en paliers sans
  déformer la répartition), queue de la rareté, biais du passé (x`BACKGROUND_BIAS_SCALE` 0,6), relief (un axe à
  ±60, trois à ±50), au plus deux à ±90, 8 candidats dont on garde celui qui ressemble le moins aux héros vivants,
  3 à 6 tics. `new_persona(nom, rarity, roster, secret)`, appelé par `_new_hero` (`summon.gd`) pour toute
  invocation et tout code secret : un héros secret prend son profil écrit à la main (`secret_persona`, voir P1a-bis) ;
  sans profil, il serait tiré avec la queue `SECRET_TAIL`, sans plafond. Pas de métier pour les héros secrets.
  Lecture : `tier`, `axis(hero, id, target)` (-100 à +100 ; le cercle de la cible décalera les paliers en P3,
  `_circle_shift` neutre), `pole`, `composite` (arrondi à 10), `score` (comportement, -100 à +100),
  `accesses` (recalculés par `refresh_accesses` à chaque changement de palier), `tensions`, `metier_name`.
  Évolution : `gain_evolution(hero, axe, points, worked)` (vitesse de la famille, acharnement x1,05 par palier
  de Persévérance si l'axe est travaillé, coûts `EVOLUTION_COST`, revenir vers zéro 10 ; renvoie les paliers
  franchis et les accès ouverts ou fermés), `add_effort`, `set_tier`. Effets : `effect_add`, `effect_mul`,
  `effect_div`, `effect_cross`, `effect_ratio` (bornes facultatives). Pour la suite, neutres : `modifier()`
  renvoie 1,0, `decide()` l'option par défaut, `notify()` et `perceived()` laissent tout passer (message et
  valeur inchangés), `can_learn()` renvoie la règle actuelle (`GameData.can_learn_skill`, cherché dans l'arbre
  de scène pour que le banc de test tourne sans le jeu).
  Métier à la place de « Novice » : `GameData.class_label(hero)` (`heroes.gd`) sur les cartes, la fiche, le hub,
  l'armurerie, les affectations, l'entraînement ; dans les règles la classe reste « Novice ».
  Sauvegarde version 3 : au chargement, les héros sans profil en reçoivent un (`PersonalityEngine.migrate`).
  Mode dev (fiche du héros, « PERSONNALITÉ (mode dev) ») : métier, couches, talent, effort, tics, les 18 curseurs
  par famille (− / + : palier ; évo− / évo+ : 10 points d'évolution, `dev_set_axis_tier`, `dev_add_evolution`),
  composites, comportements, accès ouverts, tensions, « Nouveau tirage » (`dev_reroll_personality`).
  Banc de test : `Godot --headless --path <copie> -s res://tools/test_personality.gd`, dans une copie du projet
  avec un `override.cfg` (voir P1a-bis) : même lancé avec -s, il démarre `GameData`, qui relit et réécrit la
  sauvegarde (constaté pendant C2 ; la sauvegarde réelle n'avait rien perdu). Il vérifie le tableau de la section 1 des
  Paliers sur 40 000 héros par rareté à ±10 %, aucun héros plat, exemples Varek / Sorn / Ilda, évolution 60 à
  100 = 225 points, fonctions d'effet, tirage diversifiant. Écarts signalés : 3★ facteur de queue 1,03 au lieu
  de 1 (sinon 1 héros sur 9 à ±90, pas 1 sur 8) ; la ligne « Secret (si généré) » ne peut pas être atteinte
  entière (à 90 : 1 sur 2,4 au lieu de 2) ; Rythme : l'onglet Axes met Aube au pôle haut, sa règle dit + = nuit
  (gardé : + Nocturne, exclusive Veilleur). Après l'ajout d'un fichier `class_name`, lancer une fois
  `Godot --headless --path . --import` (cache des classes ; la publication web le fait toute seule).
- Personnalité v2, étape P1a-bis (cahier, « 1. Paliers », sections 11 et 12) : les anciens traits deviennent
  des lectures de paliers, sans changer leurs effets. `PersonalityData.OLD_TRAITS` : Courageux = composite Courage
  >= +40, Lâche <= -40 (choix du porteur du projet, étape 0 avant P1b ; le cahier disait ±50), Loyal = Loyauté >= +50, Paresseux = Persévérance <= -50, Querelleur = Colère >= +50 et
  Empathie <= +20, Protecteur = Empathie >= +50 et Audace >= +30, Ambitieux = Ambition >= +50, Mauvais =
  Empathie <= -50 et Honnêteté <= -30, Meneur = synergie Meneur. `has_trait` → `PersonalityEngine.has_old_trait`
  (ou `persona["legacy_traits"]`) ; `roll_traits` supprimé ; drapeaux « révélé » par nom dans
  `hero["revealed_traits"]` (`reveal_trait`, `hero_traits`, `traits_text`). Un héros peut n'avoir aucun trait.
  Sauvegarde version 4 (`migrate`, `_adopt_old_traits`) : chaque héros garde ses anciens traits (`hero["traits"]`,
  effacé ensuite) : `push_old_trait` pousse les axes juste au seuil (Audace d'abord pour le Courage) ; deux
  traits impossibles ensemble (Protecteur avec Querelleur ou Mauvais, Meneur avec Querelleur ou Mauvais) : celui
  que le profil ne donne pas va dans `legacy_traits` (environ 7 % des héros) ; un trait que le profil donne en
  plus apparaît, caché. Banc : 1,8 axe poussé par héros, de 6 paliers en moyenne (un Loyal à Loyauté -50 passe à +50).
  Héros secrets (`SECRET_PROFILES`, `secret_persona`, `new_persona`) : profils de la section 11 (paliers, couches,
  talent `TALENT_LEVELS` en aptitudes, effort `EFFORT_LEVELS`, pas de métier ; notes du cahier dans `layer_notes`
  et `notes`, visibles en mode dev), à la création (code, menu SECRET_HERO) et à la migration des secrets déjà
  possédés (leurs anciens traits tirés au hasard ne comptent plus, drapeaux gardés). Couches interprétées quand
  le cahier ne nomme pas une option de `LAYERS` (Han : valeur Réussite, peur Le déshonneur ; besoins). Leur
  croissance (`SECRET_HEROES`) ne change pas. Traits obtenus : Han Courageux (Courage +40 tout juste) et Ambitieux ; Jenna Courageuse et Loyale ;
  Aaron, Hansen, Zid Loyaux ; Shei Courageuse et Loyale ; Yvolka Paresseuse et Ambitieuse ; Edith Protectrice et Meneuse.
  Fréquence des traits (banc, 40 000 héros par rareté, seuils ±40 du Courage), avant → après : chaque trait
  15-16 % → Courageux 4,9 / 5,6 / 6,9 / 8,7 / 10 % (1★ → 5★ ; à ±50 : 1-4 %), Lâche 4,8-5,7 % (à ±50 : 1-2 %),
  Loyal 10-15 %, Paresseux 9-14 %, Querelleur 7-9 %, Protecteur 3-6 %, Ambitieux 9-15 %, Mauvais 5-7 %, Meneur
  2-4 % ; traits par héros 1,4 → 0,54 (1★) à 0,87 (5★) ; héros sans trait 40 (5★) à 56 % (1★).
  Simulateur de la Tour : `tools/sim_tower.tscn` (voir l'en-tête de `tools/sim_tower.gd`), victoires selon chaque
  trait présent dans l'équipe ; options `niveau=` (niveau imposé) et `meneur=avec|sans|libre` (étape 0 avant P1b).
  Chaque lancement relit et réécrit `user://sauvegarde.cfg` : le lancer dans une copie du projet (worktree git)
  avec un `override.cfg` (`[application]` `config/use_custom_user_dir=true`, `config/custom_user_dir_name="..."`),
  jamais dans le dépôt.
  Combats (sans ordres ni potions, 1 000 par étage, graine 7 ; « brute » : 3★ + 2★ + 3 x 1★ au niveau des
  monstres ; « préparée » : 2 niveaux de plus, épée et bouclier ou arc D), avant (a113856) → après : brute étages
  1 à 5 : 99,9 / 64,6 / 53,7 / 54 / 26,3 % → 99,7 / 68,9 / 53,8 / 54,1 / 27 % ; préparée : 100 / 98,6 / 94,9 /
  95,6 / 44,1 % → 100 / 98,7 / 96 / 95,3 / 66,8 %. Écart : préparée étage 5, +23 points. Cause : l'ancien
  Meneur en survie (avec Meneur 18-20 %, sans 73-74 %) ; avant, 55 % des équipes avaient un Meneur, maintenant
  12 %. Avec `_organize_defense` coupé : 73 % avant, 73,6 % après. Corrigé à l'étape 0 (voir « Meneur en survie »).
- Personnalité v2, étape P1b (cahier, « Personnalité : document de référence », section 3 bis et section 7
  « Découpage de P1 » ; « 3. Moteur » ; « 4. Interactions », sections 2, 2 bis, 5 à 7 ; « Compétences : registre
  et recherche », section 10) : toutes les STRUCTURES sur lesquelles P2 à P5 se brancheront, AUCUN effet en jeu.
  Sauvegarde version 5, profil version 3 (`PROFILE_VERSION`), migration au chargement (`PersonalityEngine.migrate` ;
  bibliothèque et mémorial absents = vides).
  1. Les 8 briques (`persona["mind"]`, `new_mind`, données `NEEDS`, `EXPECTATIONS`, `COPING_STRATEGIES`, `DESIRES`) :
  besoins (0 à 100, `NEED_START` 100 = satisfait ; `need_weight` : axes et couche « besoin »), pensées, attentes (rang
  attendu : 20 par étoile), dissonance, souvenirs, opinions (`opinion`, `add_opinion`, -100 à +100 ; `GameData.bonds`
  reste la source des liens), confiance envers le Maître (`trust`), adaptation (`coping`), désirs. Vides ou neutres.
  2. Cercles (`CIRCLES`, `CIRCLE_SHIFTS`, `HIERARCHY_STANCES`, `RANK_FACTORS`) : rapport à la hiérarchie tiré à la
  création selon les paliers (`roll_stance` ; 3★ : Égalitaire 15 %, Déférent 17 %, Courtisan 19 %, Dominateur 16 %,
  Rebelle 16 %, Protecteur 16 %), dettes de vie (`debts`, `add_debt`), `circle(hero, cible)` (intime : frère d'armes,
  opinion >= 60 ou sauveur ; rival : hostiles ou <= -60 ; groupe : ami ou même groupe ; nouveau : moins de 3 combats ;
  plus fort / plus faible : rang perçu à 15 points d'écart ; « maitre »), `social_rank` (calculé à la demande ; le
  cache viendra avec les événements), `is_watched` / `set_watched` (faux tant que les écrans ne le branchent pas, P3).
  `axis()` et `score()` appliquent le décalage du cercle de la cible (`_circle_shift`, `circle_shift_for`,
  `circle_face`) ; aucune mécanique ne passe encore de cible. Exemple du cahier vérifié : un Courtisan à Empathie 0
  est à +40 envers un plus fort (et le Maître), -50 envers un faible.
  3. Sujets (`SUBJECTS` : monstres de la Tour avec leur famille, synthèse, lobby, lieux, missions, vue du sang ;
  `KNOWLEDGE_LEVELS`, `KNOWLEDGE_CAP`, `BACKGROUND_SUBJECTS`, constantes d'apprentissage) : `persona["subjects"]`
  (appréhension, connaissance, progression, dernière rencontre, peur éteinte, cadres réussis, cicatrice, haine, connu
  avant l'invocation) et `pending_report`. `apprehension` (absence de 7 jours : 30 % de la peur perdue revient ; cadre
  nouveau : +10, moins chez un Curieux), `knowledge`, `after_encounter` (peur qui baisse de 30 % de l'écart, monte de
  50 % ; Stabilité ; cicatrice 30 % chez un Vulnérable, haine chez un Colérique ou Persévérant ; connaissance : combat
  niveau 4, regard 3, récit 1), `share_knowledge` (Empathie explique, Méfiance n'écoute pas, niveau 2 au plus),
  `learn_subject`, `subject_for_enemy`. Métier : chasseur loups niveau 3, berger loups connus et craints (70), soldat
  humanoïdes et sang... Han : synthèse niveau 4, appréhension 0 (`SECRET_PROFILES`, « subjects »). Rien ne lit ces
  valeurs en combat (P2).
  4. `scripts/game_data/library.gd` (`Library`, `GameData.library`, sauvegardé « bibliotheque ») : bestiaire, carnets
  d'étage, formations, stratégies, registre des compétences (`SKILL_STATES` : inconnue, rumeur, piste, hypothèse, en
  test, méthode vérifiée, améliorée ; `set_skill_state`). `deposit(library, hero)` consigne le rapport du héros, filtré
  par sa personnalité (Curiosité ou Acuité : fiche plus détaillée ; Pessimisme : danger surestimé ; Ruse : omission
  possible ; Ambition : rôle exagéré ; illettré : fiche racontée, `LITERATE_METIERS`), vérifiée au 2e auteur.
  `study` : niveau 2 (3 avec un bibliothécaire), jamais plus que la fiche ; la lecture rassure (-3), un récit d'horreur
  inquiète un Vulnérable (+3). Niveaux de la salle `LEVELS`. Pas encore de salle (P5).
  5. `scripts/game_data/memorial.gd` (`Memorial`, `GameData.memorial`, sauvegardé « memorial ») : places (`CAPACITY`
  2 à 12) et mémoire (`MEMORY`, niveaux 1 à 5 du cahier) améliorées séparément ; `record(memorial, héros)` sans
  ramener le corps ; on garde tout et la mémoire filtre à la lecture (`view` : monter la mémoire améliore les souvenirs
  déjà là) ; `remove` renvoie « [Nom] sera oublié à jamais. » ; `relive` (connaissance du mort ; stress, x2 pour un
  intime, 0 pour un Détaché, et réaction calculés, appliqués en P4) ; `replay` (le dernier combat vu par le mort).
  6. Journal de combat (`battle.gd`, section « Journal de combat ») : par héros, `fighter["journal"]` (premier
  contact avec chaque ennemi, blessure grave, agonie, secours, mort, ennemi achevé, formation ; 60 au plus) et
  `journal_counts` (coups portés, reçus, esquives, ennemis achevés) ; `Battle.formations_used` (trois portées, mur de
  boucliers, défense du Meneur). Aucun tirage au hasard : mêmes combats à graine égale (vérifié : `sim_tower`,
  étages 1 à 5, 300 combats, graine 7, brute et préparée, sorties identiques octet pour octet avant et après ;
  brute 100 / 69,3 / 49 / 57,3 / 27,3 %, préparée 100 / 98 / 95,3 / 95 / 74 %).
  `finish_tower_battle` → `_keep_battle_journals` (`tower.gd`) : `hero["recent_battles"]` (3 derniers combats,
  morts compris) ; les survivants ajoutent le carnet de l'étage à leur `pending_report`.
  7. Le « pourquoi » : `decide()` garde ses 3 plus fortes raisons dans `persona["decisions"]` (10 dernières,
  `decisions()`), visibles en mode dev ; il choisit toujours l'option par défaut (P3).
  8. Mode dev : fiche du héros, sous « PERSONNALITÉ » : briques, cercles et visage cercle par cercle, place des autres
  héros dans ses cercles, sujets, rapport à consigner, dernières décisions, dernier combat ; boutons « Combat facile /
  dur (gobelins) », « Consigner à la bibliothèque », « Étudier le bestiaire » (`dev_subject_encounter`, `dev_deposit`,
  `dev_study`). Outils du mode dev > « Bibliothèque et mémorial » : voir la bibliothèque, voir le mémorial (« Retirer »,
  fenêtre « Retirer [Nom] du mémorial ? », puis « [Nom] sera oublié à jamais. »), enregistrer les morts, +1 niveau
  de places ou de mémoire.
  Banc : `test_personality.gd` (« -- p1b » : seulement les contrôles P1b, quelques secondes ; complet : 125 contrôles).
  Vérifié aussi en mode normal, sur une copie d'une vraie sauvegarde version 2 : migration sans rien perdre, combat
  de la Tour complet (journal, carnet d'étage, bibliothèque, mémorial), enregistrer puis relire à l'identique (les
  nombres à virgule relus se comparent à 0,0001 près : arrondi connu de la sauvegarde). P1b est terminée : P2
  branchera les effets (sujets et appréhension en combat, besoins, opinions) sur ces structures.
- Personnalité v2, étape P2 : commencée puis mise en attente (le porteur du projet a fait passer C2 avant), sur la
  branche `p2-personnalite`, pas encore dans `main` : P2a table MODIFIERS et vrai `modifier()`, P2b stress revu
  (sensibilité, type, accoutumance), P2c effets des sujets en combat, P2d `can_learn` et affinités (conditions du
  catalogue réécrites sur les paliers, choix « recréer et adapter »), P2e Berserk et éveils selon le caractère. Reste
  P2f armes de prédilection et plafonds, P2g exclusives. Coefficients du cahier suivis à la lettre (choix du porteur
  du projet). À reprendre après le réglage de la difficulté des étages 5 et 10 (fusionner `main` dans la branche).
- Longues listes de héros (200 et plus) : barre `HeroFilter` (`scripts/hero_filter.gd` : recherche par nom,
  classe, étoiles, tri ; `apply()` renvoie la liste filtrée) dans la collection, l'armurerie et la fenêtre
  « Ajouter un héros » du terrain d'entraînement, qui n'affiche plus que les héros inscrits. Au-delà de
  `MAX_ROWS` résultats, on demande d'affiner la recherche. La collection cache les héros morts (bouton « Tombés »).
- Hub 3D (demande du porteur du projet, d'après le plan de la cité du manhwa) : `scripts/hub_city_3d.gd`
  (`HubCity3D`, une `SubViewport` 3D faite de formes simples), affiché avec les nouveaux visuels ; les
  anciens gardent le plan 2D `HubMap`. Disposition d'après le plan du manhwa (`PLACES`, rues `CROSSINGS` /
  `STREETS`) : rempart à 12 pans, résidences à l'ouest, combat au nord, place en roue au nord-est face à
  la faille (arche dans le rempart). Demandes du porteur du projet : la cité vole dans le néant (ciel
  étoilé en shader, rocher sous la cité, rochers et cristaux en suspension, courants cyan), style
  médiéval sombre et détaillé (modèles et textures dessinées par le code dans `scripts/city_models.gd`,
  `CityModels` : briques, pavés, tuiles, colombages, fenêtres éclairées). Arbres, créneaux, lanternes en
  `MultiMesh` (téléphone). Un bâtiment pas construit n'apparaît pas dans la cité : on le voit en
  hologramme qui tourne dans le menu Construction (`scripts/holo_preview.gd`). Une fois construit (payé,
  ou condition remplie : terrain d'entraînement, annoncé par `GameData.facility_completed` et une fenêtre
  de `main.gd`), la caméra va vers lui et il monte du sol en hologramme cyan, des pixels scintillent
  (l'hologramme n'est que l'animation de construction). L'animation attend qu'aucune fenêtre ne couvre
  la cité (`HubCity3D.paused`, `hold`).
  Les héros y vivent en suivant les rues (`AStar3D`) : terrain d'entraînement s'ils s'entraînent, devant
  leur bâtiment s'ils sont assistants, sinon promenade (place, rues des résidences) ; départ en mission
  par la faille, retour par la zone de débarquement,
  nouveaux héros par la salle d'invocation. Un doigt : déplacer ; deux doigts / molette : zoom ;
  toucher un lieu (même fonctionnement que `HubMap`) ou un héros (ce qu'il fait). Noms en texte 2D
  par-dessus la 3D. Reste : vrais modèles, temps du lobby x3, héros qui choisissent d'eux-mêmes.
- Un script par écran (`class_name`), dont l'interface est construite par le code :
  `hub_screen.gd` (+ `hub_map.gd`, la cité circulaire dessinée ; clavier des codes secrets),
  `summon_screen.gd`, `collection_screen.gd`, `dungeons_screen.gd` (liste des donjons, composition des
  équipes à l'avance, annonce de la quête de l'étage, choix de l'équipe, combat).
- Équipes composées à l'avance : `GameData.teams` (`TEAM_COUNT` = 3 équipes, sauvegardées ; un héros
  mort les quitte). Taille d'une équipe de combat, choix du porteur du projet : 1 héros au minimum,
  5 au maximum (`TEAM_SIZE`), même si le cahier montre des équipes de 3. Donjons > « Composer les
  équipes » pour les modifier ; avant un étage, un bouton par équipe la sélectionne d'un toucher.
  Glisser-déposer (cahier : « Formation de groupe ») : `TeamSlots` (`scripts/team_slots.gd`), les cases
  du groupe ; maintenir une carte 0,3 s puis la glisser sur une case (ajout, remplacement, échange),
  la relâcher sur la liste pour la retirer ; toucher marche toujours. `DragScroll` ne défile pas pendant
  un glisser. Avant l'étage, une fenêtre « Formation de groupe » confirme le groupe.
- `scripts/battle.gd` : classe `Battle`, combat en temps réel vu du dessus, joué en direct par pas
  de 0,1 s (`start()` puis `step()`) : grille « 3D » avec hauteurs (voir « Combat v2, étape C1 »), recherche de
  chemin, ligne de vue 3D pour les tirs, particularités de chaque classe, saignement, éveil, renforts, remparts, ordres
  du joueur (`order_move`, `order_attack`). `run()` joue tout d'un coup sans ordres (il rappelle `start()` :
  ne pas l'appeler sur un combat déjà démarré).
  `scripts/battle_view.gd` : classe `BattleView`, affiche le combat en direct (pions, coups,
  chiffres) ; on touche un héros puis un endroit ou un ennemi pour lui donner un ordre ; pause
  (aucun ordre pendant la pause, choix du porteur du projet). La carte : vue de dessus (`arena`) ou vue
  isométrique 3D (`arena3d`, voir « Combat v2, étape C2 ») ; le reste de l'écran est commun aux deux.
  Le combat continue si on change d'onglet. Il est noté dans la sauvegarde dès le début
  (`GameData.pending_battle`) : si le jeu est fermé en plein combat, il est terminé sans ordres au
  lancement suivant, et `main.gd` annonce le résultat (« Pendant ton absence »).
- Combat v2, étape C1 (cahier, onglet « Combat v2 », sections 0, 2, 3, 8, 8 bis, 9) : la simulation devient
  « 3D sur grille » ; la vue isométrique, c'est C2 (plus bas). Chiffres provisoires.
  1. `scripts/battle_map.gd` (`BattleMap`) : hauteur de chaque case (0 à 4 niveaux) et type (`Kind` : sol,
  obstacle, toit, échelle, escalier ou pente, muret, rempart, porte, herbes hautes, tour, rocher). `Battle.map`.
  2. Verticalité (`tower.gd`, section « Verticalité ») : passages d'une case à l'autre (`BattleMap.Link` : marche,
  escalier `STAIRS_SPEED` 0,8, escalade d'un niveau `CLIMB_SPEED` 0,25 selon la Dextérité, échelle `LADDER_SPEED`
  0,45 jusqu'à 3 niveaux, saut d'un niveau sans risque, de deux niveaux (sens unique) ; deux niveaux sans échelle :
  impossible) ; chute (`fall_damage` : 2 niveaux 5 % de la vie, 3 niveaux 25 %, +10 % par niveau en plus ; jamais
  par une échelle) ; avantage de hauteur par niveau (+`HEIGHT_DAMAGE_PER_LEVEL` 10 % de dégâts, -10 % subis,
  plafond 3 niveaux, tireurs +1 case par niveau ; remplace +20 % / -25 %) ; au corps à corps, pas plus d'un niveau
  d'écart (`MELEE_MAX_LEVELS`) ; ligne de vue 3D (`BattleMap.line_of_sight` : des yeux, 0,8 niveau au-dessus de la
  case, au corps de la cible ; un mur cache ce qui est derrière sauf pour qui est plus haut) ; pousser (`_push` : un
  coup au contact critique ou d'au moins 20 % de la vie fait tomber d'un bord à 35 %, jamais un boss) ; couvert
  (`_covered` : derrière un muret, une clôture ou un rocher, 35 % des tirs s'y arrêtent, « couvert ! », sauf tireur
  2 niveaux au-dessus). Chacun a sa case et sa hauteur (`fighter["z"]`, `Battle.height_of`, `_land`) ; les
  bousculades ne font pas changer de niveau.
  3. Cartes (`scripts/map_generator.gd`, `MapGenerator.generate_map(étage, quête, graine)`, même graine même carte,
  gabarits de la section 8 bis, `template_for`) : village envahi (étage 1), prairie (étage 2), relief (autres étages
  ordinaires, ajout du projet en attendant les lieux des étages 3, 4, 6...), ville en ruine (survie : la rangée de
  maisons percée de 3 ruelles d'une case, toits à 2 niveaux, deux échelles côté héros, une côté ennemis, un clocher à
  4 niveaux ; un pâté sans échelle reste une maison fermée), cité (défense : rempart à 2 niveaux, chemin de ronde
  `WALL_ROW` 17, escaliers à l'intérieur, porte fermée ; les tireurs partent du chemin de ronde, les monstres frappent
  le rempart à son pied), arène (duel). Vérifications après chaque carte (`check` : zones de départ plates, chemin
  dans les deux sens, aucune poche hors d'atteinte des héros (hors défense : ni des ennemis), point haut accessible,
  ruelles ouvertes) ; sinon on recommence (40 essais, puis carte plate). Banc : toutes jouables, 3 à 7 ms par carte.
  4. Déplacements (`battle.gd`, section « Déplacements » ; constantes après `PERSONAL_SPACE`) : un graphe AStar3D par
  camp (`BattleMap.find_path`), coûts des cases (`TERRAIN_COSTS` : pente 1,15, échelle 2, muret 3, rocher 2 ; foule
  `CROWD_STILL_COST` 3 / `CROWD_MOVING_COST` 0,5 ; pour les héros, danger `DANGER_COST` 1 par tireur ennemi à portée,
  2 au plus ; `_refresh_costs` toutes les 0,5 s) ; champ de flux des monstres (`BattleMap.flow_field`, `_flow_for`,
  `_follow_flow` : une carte des distances par cible pour toute la horde, recalculée au plus toutes les 0,5 s si la
  cible a bougé, toutes les 2 s sinon ; près de la cible en marchant, `FLOW_NEAR` 3 et `NEAR_MARGIN` 2, chemin à soi) ;
  réservation des cases d'attaque (`_attack_slot` : une case de corps à corps autour de la cible par attaquant) ;
  évitement local (`_sidestep` : contourner qui se tient immobile) ; bloqué plus de `REPATH_BLOCKED` (1 s) : nouveau
  chemin qui évite le passage, un monstre quitte le flux `DETOUR_SECONDS` (3 s) et essaie une autre ruelle
  (`_blocked`). Défense : un monstre au corps à corps à qui un héros barre la route l'attaque (avant, il hésitait).
  5. Vue de dessus (`battle_view.gd`, `_draw_cells`) : chaque case dans la couleur de son type, plus claire en
  hauteur, avec sa hauteur écrite dans le coin ; échelles, escaliers, toits, clocher, rempart, murets, rochers,
  herbes ; trait sombre sur chaque bord qui tombe ; pastille de hauteur sur un combattant en hauteur.
  6. Meneur en survie : voir « Meneur en survie » (P5 gardée, et les tireurs sur les toits).
  8. Carte et ennemis en donnée, étages figés (section 8 bis, tranché par le porteur du projet) :
  `MapGenerator.generate(étage, quête, graine)` renvoie {"version", "seed", "map", "enemies"} : les ennemis de
  `tower_enemies` (qui accepte un tirage à suivre) avec « start » (case de départ, vague 0) et « entry » (colonne
  d'entrée des renforts), « elite » toujours faux (élites : C5). `GameData.floor_layout(étage)` : à la première
  visite, l'étage est généré (graine au hasard) et enregistré (`GameData.floors`, « etages ») ; ensuite il n'est plus
  jamais modifié et se rejoue à l'identique, perdu ou gagné ; la quête suit toujours `floor_quest`. L'écran Donjons
  s'en sert ; `pending_battle["map"]` : un combat repris au lancement se joue sur la même carte. Sauvegarde version 6
  (absents d'une ancienne sauvegarde : générés au prochain passage). Une carte sans donnée (duel, combat en cours
  d'avant C1) est fabriquée avec une graine au hasard (`Battle.map_data` vide).
  7. Tests. Banc `tools/test_combat_v2.tscn` (scène : dans une copie du projet, voir plus bas) : passages, chemins,
  ligne de vue, chutes, hauteur, pousser, couvert, flux, réservation, autre passage, Meneur, cartes (« cartes=N »,
  « voir=oui » les dessine en lettres), étages figés. `tools/sim_tower.gd` : options `maitre=oui` (Maître simulé :
  tireurs sur la hauteur la plus proche à moins de 7 cases au début, échange de place des fatigués au contact),
  `potions=N`, `carte=graine`, `meneur_toit=oui|non`, `suivre=combat:Nom de=t a=t` (trace pas à pas) ; il compte le
  temps de calcul et les unités bloquées (plus de 2 s sans s'éloigner de 0,3 case alors qu'elles veulent avancer :
  « foule » si quelqu'un leur barre la route, « escalade », sinon « sans raison »).
  Mesures avant / après C1 (pas de rééquilibrage : les cibles du Sommaire seront réglées après C2). Commande, dans une
  copie du projet (worktree + `override.cfg`, voir P1a-bis) : `Godot --headless --path <copie> res://tools/sim_tower.tscn
  -- etages=N combats=300 equipe=brute|preparee [maitre=oui] graine=7`, un étage par lancement, 18 lancements en
  parallèle ; avant = commit db57bdb (même simulateur), après = 7a39c6a. Victoires % (morts par combat) :
  brute étages 1 / 2 / 3 / 4 / 5 / 10 : 100 (0,30) / 67 (2,16) / 51 (2,91) / 56,3 (2,70) / 26 (3,34) / 20,7 (4,15) →
  100 (0,28) / 63,3 (2,38) / 52,7 (2,96) / 49 (3,04) / 23,3 (3,35) / 12 (4,40) ;
  préparée : 100 (0) / 97,7 (0,39) / 95,3 (0,68) / 96 (0,59) / 76,3 (2,10) / 34 (3,76) →
  100 (0) / 97,3 (0,44) / 96 (0,58) / 94 (0,72) / 60,7 (2,64) / 28 (3,93) ;
  préparée avec Maître simulé : 100 (0) / 97,7 (0,31) / 96,3 (0,65) / 92 (0,76) / 66,3 (2,43) / 27,7 (3,96) →
  100 (0) / 96 (0,49) / 92,3 (0,76) / 94 (0,78) / 65,7 (2,35) / 21,7 (4,03).
  Le plus gros écart : étage 5, préparée sans ordres, -16 points (les toits à échelle de la horde, le flux et les
  encerclements : à vérifier en C2 avant de régler) ; avec le Maître (tireurs sur les toits), l'étage 5 ne bouge pas.
  Étage 10 : -6 à -9 points (les monstres frappent le héros qui leur barre la route). Temps de calcul d'un combat (18
  lancements en même temps, donc plus lent que seul) : étage 1 80-109 → 288-383 ms, étages 2 à 4 130-170 → 415-510 ms,
  étage 5 557-620 → 1 030-1 146 ms, étage 10 250-269 → 561-612 ms. Unités bloquées sans raison : 0 sur 5 400 combats
  avant comme après (« foule » : 10 à 226 par série de 300, surtout la queue dans les ruelles de l'étage 5).
- Combat v2, étape C2 (cahier, onglet « Combat v2 », sections 0, 1, 2, 8) : la vue isométrique semi-3D. Aucun
  changement de la simulation : `scripts/battle_view_3d.gd` (`BattleView3D`) ne fait que montrer `Battle`.
  1. Carte : une colonne de blocs par case (`LEVEL` 0,8 case par niveau, socle `BASE_DEPTH`), couleur selon le type de
  case et le gabarit (`PALETTES` : village, prairie, relief, ville, cité, arène), en MultiMesh (4 formes : boîte, sphère,
  prisme, cylindre ; une opaque et une transparente par forme : `_fill_multimeshes`). Les décors nommés par
  MapGenerator (`map_data["structures"]`) ont leur forme : arbres, maisons fermées à toit à deux pans, puits, rochers,
  clocher (cloche et toit pointu), créneaux du rempart (côté ennemis), porte, marches, échelles (contre la case voisine
  la plus haute), herbes hautes, murets. Caméra orthographique (`PITCH_DEG` 35°, `YAW_DEG` 45°, zoom = largeur vue en
  cases). Personnages : corps (capsule, couleur de la classe, `CLASS_COLORS`), tête et anneau au sol couleur du camp
  (vert, rouge, boss violet et plus grand), ombre au sol à la hauteur de la case ; la hauteur affichée glisse
  (`CLIMB_DISPLAY_SPEED`) : on le voit grimper. Berserk : corps rougi ; agonie : couché, rouge qui bat ; tombé : gris.
  2. Gestes (comme le hub 3D) : un doigt déplace la caméra, deux doigts (ou la molette) zooment, bouton « Tourner »
  (90°, glisse en un quart de seconde). Murs et toits devant le héros choisi transparents (`_update_fade`, toutes les
  0,15 s : colonnes plus hautes que lui, devant lui, dont l'image recouvre la sienne ; leur socle reste opaque).
  3. Ordres : `tap` → combattant le plus proche à l'écran (`unit_at_screen`), sinon lancer de rayon sur la carte en
  hauteur (`pick_cell` : la première colonne touchée, son dessus ou son flanc) → signal `tapped` → `BattleView._arena_tap`,
  commun aux deux vues (mêmes ordres, mêmes boutons, pause sans ordres).
  4. Par-dessus la 3D (overlay 2D, aux points projetés) : barres de vie, d'endurance, de mana ; étiquettes (PEUR,
  PANIQUE, BERSERK, REFUS DE MOURIR, REPOS, MIGRAINE, AGONIE et secondes, arme plantée, tombé) ; noms ; traits des
  coups, tirs, sorts et soins ; chiffres ; bulles « Non ! » (`BattleView.draw_bubble_on`) ; ordres en cours. Le reste de
  l'écran (chrono et vagues, barre du boss, encart de l'équipe, journal, fenêtres système, boutons) est celui de
  `BattleView`, inchangé.
  5. Choix de la vue : `BattleView.use_3d` = `Settings.new_visuals` au début du combat (duels compris) ; mode dev : bouton
  « Vue de dessus » / « Vue 3D » en haut, en plein combat.
  6. Performance : rendu Compatibility ; réglages en constantes de `battle_view_3d.gd` (`SHADOWS`, `MSAA`,
  `RENDER_SHRINK` : écran 3D rendu plus petit) ; mode dev : compteur d'images par seconde en haut à gauche de la vue.
  Mesuré sur PC (Radeon RX 6700 XT, synchro écran coupée), étage 5 : vue 3D 1 680 images/s, 1,4 ms de calcul par
  image, 94 appels de dessin ; vue de dessus 340 images/s, 3,8 ms, 247 appels (elle redessine chaque case à chaque
  image). Pas encore mesuré sur téléphone.
  7. Vérifications : `tools/capture_c2.tscn` (dans une copie du projet, avec une fenêtre ; voir son en-tête) :
  « mode=capture » (images, « rot », « choisi », « archer_toit », « cache » : héros posé derrière un bâtiment),
  « mode=ordres » (héros, toit, rue, montée par l'échelle : étages 1 et 5), « mode=identique » (le même combat sans
  écran et à travers l'écran 3D : 10 combats des étages 1, 2, 3, 5 et 10, identiques au caractère près).
- Phase 1.1 de la feuille de route v2 (cahier, « Améliorations combat... », lot A ; chiffres dans `tower.gd`,
  section « Combat ») :
  Endurance : `fighter["stamina"]` (`STAMINA_MAX` 100), héros seulement (l'adversaire d'un duel aussi). Se
  déplacer (`STAMINA_MOVE_COST` 1,5 par case parcourue) et frapper (`STAMINA_ATTACK_COST` 5 par coup, tir,
  sort ou soin) la vident (`_spend_stamina`) ; elle remonte de `STAMINA_REGEN_PER_SECOND` (8) quand aucun
  ennemi n'est à moins de `STAMINA_CONTACT_RANGE` (1,8) cases (`_stamina_tick`). À 0 : épuisé (journal
  « X est épuisé. »), attaque et défense x`STAMINA_EXHAUSTED_FACTOR` (0,6, `_tired`, dans `_mind`),
  déplacements x`STAMINA_EXHAUSTED_SPEED` (0,6), jusqu'à `STAMINA_RECOVERED` (30). Novice du combat
  (`is_combat_novice`, `heroes.gd` : 1 étoile dans ses `NOVICE_FIGHTS` 3 premiers combats, aussi utilisé par
  la peur) : coûts x`STAMINA_NOVICE_FACTOR` (2). Écran : barre jaune sous la vie (portrait et pion), grise
  si épuisé. Simulation : 0,3 à 0,5 épuisement par combat aux étages 1 à 5, victoires inchangées (à la
  marge) ; elle compte surtout dans les combats longs.
  Rotation : bouton « Échanger de place » de `BattleView` pour le héros choisi (`order_swap`, `can_swap`,
  refus possible). `_rotate` : il part à `ROTATION_REAR_DISTANCE` (3) cases derrière lui et se repose
  (`fighter["resting"]`, « REPOS » sous le portrait) : il ne combat que si un ennemi vient au contact, son
  endurance remonte x`ROTATION_REST_FACTOR` (3), il revient quand elle est pleine (« X a repris son
  souffle. ») ; un ordre du Maître met fin au repos. L'allié le plus frais (`_find_relief` : au moins
  `ROTATION_FRESH_STAMINA` 50 %, corps à corps de préférence) prend son poste. Pendant
  `ROTATION_VULNERABLE_SECONDS` (1 s, `swap_until`), les deux ne frappent pas et encaissent
  x`ROTATION_DAMAGE_TAKEN` (1,5). Trait Meneur (`TRAITS`, synergie Meneur des paliers depuis P1a-bis) : `_lead`
  fait tourner un allié au contact sous `LEADER_TIRED_STAMINA` (20 %) s'il y a un remplaçant, au plus toutes
  les `LEADER_COOLDOWN` (8) s ; fenêtre « X fait tourner la première ligne. » ; le trait se révèle.
  Meneur en survie (demande du porteur du projet, après la phase 1.2 ; `Battle._organize_defense`) : au début
  d'un combat sur le terrain à ruelles, un Meneur (ni effrayé ni en panique) forme lui-même l'équipe : les
  porteurs de bouclier côte à côte (mur de boucliers) au milieu, `DEFENSE_LINE_GAP` (2) rangs sous la sortie des
  ruelles, les autres au corps à corps juste derrière (un lancier d'abord), les tireurs derrière eux (moins de
  deux porteurs de bouclier : pas de mur, il ne déplace personne) ; fenêtre
  « X organise la défense. », trait révélé. Ce sont des postes de départ, pas une consigne : quand l'ennemi
  arrive, chacun se bat librement. Un héros qui a déjà un ordre du Maître le garde. Sans Meneur, les héros
  restent sur leur ligne de départ et attendent les ordres du Maître.
  Revu à l'étape 0 avant P1b (demande du porteur du projet : avec Meneur ≥ sans Meneur). L'ancienne version
  (un bouclier seul par ruelle, tireurs en hauteur, consigne « tenir le poste » `fighter["hold"]`, supprimée)
  faisait perdre l'étage 5. Simulation, étage 5, équipe préparée, sans ordres, 1 000 combats par essai :
  sans Meneur 74,6 / 74,3 / 73 % (3 graines) ; P1 ancienne version 21,6 % ; P2 mur au centre, postes tenus
  21,7 % ; P3 mur à la sortie d'une ruelle, tenus 24,6 % ; P4 mur au centre, libres, tireurs en hauteur (tenue)
  70,6 % ; P5 (gardée) mur au centre, tous libres, tireurs derrière 74,1 / 75,1 / 72,1 % ; P6 comme P5 sur la
  ligne de départ 72,1 % ; P7 « Meneur adaptable » (P5 avec postes tenus, consigne levée dès qu'un tireur
  ennemi est à 7 cases, reposte à la vague suivante sans tireurs) 54,1 / 58,2 %. Tenir un poste coûte cher
  face aux archers squelettes. P5 : 73,8 % contre 74 % sans Meneur sur 3 000 combats (égalité aux aléas près).
  Équipe brute (sans armes, donc sans boucliers) : P5 la serrait au centre, 22,4 % contre 25,8 % sans Meneur ;
  d'où la règle « moins de deux boucliers : il ne déplace personne » (après : 24,8 % contre 25,8 %, aléas).
  C1 (point 6) : P5 gardée, et les tireurs vont sur les toits à 2 niveaux les plus proches de la sortie des
  ruelles, parmi ceux qu'on atteint de son côté (`leader_roof_shooters`, interrupteur pour comparer ; ils y
  restent et tirent). Simulation sur les cartes de C1, étage 5, préparée, sans ordres, graines 31 à 33, 3 x 300
  combats (`sim_tower ... etages=5 combats=300 equipe=preparee meneur=sans|avec meneur_toit=non|oui graine=31`) :
  sans Meneur 64,7 / 67,0 / 66,3 % (2,60 morts par combat) ; P5 65,3 / 67,3 / 64,7 % (2,46) ; P5 + toits
  69,3 / 71,0 / 74,3 % (2,15). Plus haut que les anciennes hauteurs (2 niveaux contre 1), les tireurs y gagnent.
  Agonie (rendue plus exigeante comme au ch. 11, demande du porteur du projet) : à 0 point de vie, un héros
  ne meurt pas tout de suite (`_announce_fall` → `_start_agony`) : il
  agonise `AGONY_SECONDS` (8 s ; avant 10), fenêtre rouge « X est dans un état critique, sa vie est en danger ! » ;
  pion rouge qui bat avec les secondes restantes, « AGONIE 7 s » sur le portrait. `_assign_helpers` envoie
  l'allié libre le plus proche (moins de `AGONY_HELP_RANGE` 8 cases, pas au contact d'un ennemi, sans ordre
  du Maître, ni effrayé ni en panique, `_can_rescue` ; une fois en route il continue) ; un allié libre (pas
  au contact d'un ennemi, pas effrayé) à moins de `AGONY_ALLY_RANGE` (1,5)
  pendant `AGONY_RESCUE_SECONDS` (3 s ; avant 2) le stabilise (`_agony_tick`, `_stabilize`) : il sort du combat
  (`present` faux, « à l'abri ») avec `AGONY_STABILIZED_HP` (10 %) de vie ; fenêtre « Stabilisé ». Potion de
  soin (`POTION`, matériau de l'entrepôt, grade F ; pas encore fabriquée, mode dev > Matériaux) : l'équipe en
  emporte `POTIONS_PER_MISSION` (3) au plus (`mission_potions`), bue tout de suite par un héros qui tombe à
  l'agonie ; les potions bues sont retirées de l'entrepôt (`finish_tower_battle`, ligne dans le résultat).
  Sinon, à la fin des 8 s, mort définitive (`_die` : stress des alliés, peur). Fin du combat (`_after_fight`) :
  sauvé si un allié debout peut le rejoindre avant la fin de son agonie, sinon il meurt. Mort de stress :
  sans agonie (`instant`). Immortel du mode dev : même agonie, puis « à terre » au lieu de mourir.
  Arme plantée (œuvre, ch. 11 : Jenna laisse la lame dans la plaie de Zid, qui se viderait de son sang) : le coup
  qui met à l'agonie peut laisser l'arme dans la plaie (`fighter["embedded"]`, `GameData.embed_chance`) :
  lance, monstre Guerrier armé ou boss `EMBED_HEAVY_CHANCE` (45 %), autre lame `EMBED_BLADE_CHANCE` (25 %),
  flèche `EMBED_ARROW_CHANCE` (25 %) ; jamais les bêtes (`EMBED_BEASTS` : loup, golem), la magie, le saignement
  ni Berserk (provisoire ; en moyenne 20 à 26 % des agonies). Aucun allié ne peut alors le stabiliser, même à la
  fin du combat : seule une potion (plus tard un soigneur) le sauve. Fenêtre « Une arme est plantée dans X : la
  retirer le tuerait. », « arme plantée » sous le portrait.
  Simulation après ces réglages (200 à 600 combats, sans ordres) : équipe neuve étage 1 : 96 % de victoires,
  1,15 mort par combat (cible du porteur du projet : 0,5 à 1 ; 0,36 arme plantée et 0,45 stabilisé par
  combat) ; étages 2 à 4 : 19 / 7 / 8 %, 4,1-4,6 morts. « Préparée » étages 1 à 4 : 100 / 95 / 84 / 83 %, morts
  0 / 0,9 / 1,7 / 1,8.
  Simulation (équipe neuve « brute ») : morts à l'étage 1 de 1,5 à 0,1 par combat ; étages 2 à 4 de 4,4-4,8 à
  2,5-3 ; victoires à peu près inchangées (étage 1 : 98 %, étages 2 à 4 : 14-23 %). « Préparée » : morts de
  1-2 à 0,4-0,9 aux étages 2 à 4, victoires 90-98 %.
  Soin d'urgence : un héros en hémorragie (`_needs_help`) reçoit, après les héros à l'agonie, l'allié libre
  le plus proche (moins de `CARE_HELP_RANGE` 6 cases, même règle que l'agonie, `_assign_helpers`) ; l'aidant
  cesse de combattre et le suit (`_help`) ; à son côté pendant `CARE_SECONDS` (3 s, `_care_tick`),
  l'hémorragie s'arrête : journal et fenêtre « X a arrêté le saignement de Y. ».
  Simulation des quatre points (200 combats par étage, sans ordres, étages 1 à 5) — avant → après :
  équipe neuve (« brute ») victoires 99 / 22 / 9 / 11 / 0 % → 96 / 23 / 13 / 9 / 0 %, morts par combat
  1,45 / 4,39 / 4,81 / 4,75 / 5 → 0,19 / 2,6 / 2,97 / 3,1 / 3,9 ; « préparée » (2 niveaux de plus, épée et
  bouclier ou arc D) victoires 100 / 100 / 97 / 96 / 6 % → 100 / 96 / 89 / 90 / 7 %, morts 0 / 1 / 1,8 / 1,6 /
  4,9 → 0 / 0,4 / 0,7 / 0,9 / 2,9. L'agonie divise les morts par deux environ (étage 1 : presque plus de morts).
- Phase 1.2 de la feuille de route v2 (cahier, « Améliorations combat... », lot A ; chiffres dans `tower.gd`,
  section « Combat », sauf mention). Rage d'éveil : voir Berserk ; survie par vagues et terrain : voir « Tour ».
  Portées et formations (ch. 5 et 9) : chaque arme a une portée (`WEAPON_TYPES[...]["band"]`, affichée à
  l'armurerie) : courte (épée, dague, bouclier, sans arme), moyenne (lance ; le fouet aussi, ajout du projet),
  longue (arc, et la magie des mages et soigneurs) ; `Battle.range_band`. Les héros debout couvrent les trois
  portées : +`RANGE_COVER_BONUS` (10 %) en attaque et en défense (`ranges_covered`, `_update_formations`,
  annoncé dans le journal). Mur de boucliers : un porteur de bouclier avec un autre côte à côte (à moins de
  `SHIELD_WALL_RANGE` 1,5 case, même ligne) gagne +`SHIELD_WALL_DEFENSE_PER_ALLY` (15 %) de défense par
  voisin, 2 au plus (`_wall_allies`, `_formation_defense` ; fenêtre « Mur de boucliers » la première fois).
  Lancier juste derrière un bouclier (à moins de `SPEAR_WALL_RANGE` 1,6 case de lui, le bouclier plus près de
  l'ennemi) : portée +`SPEAR_WALL_REACH` (0,6, donc 2,4 cases), il frappe sans être au contact
  (`_behind_shield`, dans `_in_reach`) et son endurance remonte (hors du contact).
  Usure (ch. 10) : chaque coup au contact émousse l'arme du héros (pas l'arc) : force x(1 - coups x
  `WEAR_PER_HIT` 0,004), jamais sous `WEAR_MIN_FACTOR` (0,6) ; journal « L'arme de X s'émousse » sous
  `WEAR_NOTICE` (0,85), « Arme 80 % » sur le portrait (`_wear`, `wear_factor`). Réparée au retour : l'usure ne
  dure que le combat (ligne « Armes émoussées, réparées au retour » du résultat, `report["repairs"]`).
  Flèches : un héros à l'arc a `QUIVER_SIZE` (25) flèches (`fighter["arrows"]`, « Flèches 12 / 25 » sur le
  portrait). À court : dague de secours au contact (`OUT_OF_ARROWS_POWER` 0,5, `_use_arrows`). Sans ennemi à
  moins de `ARROW_PICKUP_CALM` (4) cases, il ramasse `ARROW_PICKUP_PER_SECOND` (1) flèche par seconde, jusqu'à
  `ARROW_RECOVER_SHARE` (50 %) de celles tirées (`_arrow_tick`), et reprend son arc. Ordre « Tir de barrage »
  (bouton de `BattleView`, `order_barrage`, `can_barrage`, refus possible) : toutes ses flèches d'un coup au
  hasard sur les ennemis à sa portée, chacune à `BARRAGE_POWER` (0,6) d'un tir, -`BARRAGE_STAMINA_COST` (10)
  d'endurance. Les monstres ne s'usent pas et ne manquent pas de flèches. Boutons d'ordre : texte à la ligne.
  Expérience méritée (ch. 2 et 4) : `fighter["engaged"]` devient vrai quand le héros porte, reçoit ou esquive
  un coup (`_hit`), soigne (`_try_heal`) ou protège (`_cover`). Un survivant qui n'a rien fait ne gagne pas
  d'expérience (`finish_tower_battle`, `report["idle"]`) ; le résultat dit « +15 expérience pour chaque
  survivant qui a combattu » et « Pas d'expérience pour X : il n'a rien fait pendant le combat. ».
- Choix du porteur du projet pour le combat : du temps réel (pas du tour par tour) où l'on voit les
  personnages bouger, utiliser le décor, et les ennemis leur foncer dessus. On vit le combat :
  jamais de bouton « passer » ni d'accélération. Le joueur soutient ses héros en les guidant
  pendant le combat (ce qui peut changer le résultat) ou les laisse se débrouiller ; plus tard, les
  consignes de la salle d'opération seront apprises peu à peu par les héros qui participent au
  combat. Vue isométrique 3D depuis C2 (avec les nouveaux visuels), la vue du dessus reste disponible.
- `scripts/training_screen.gd` : terrain d'entraînement (ouvert depuis le hub, bouton « Retour à la cité ») ;
  `main.gd` range les écrans du hub sans onglet dans `HUB_SCREENS`. Un héros y travaille une compétence
  (`hero["training"]`) ; une séance toutes les `TRAINING_SESSION_SECONDS` de temps réel, même jeu fermé
  (`GameData.update_training()`, appelée au lancement puis toutes les 5 s). Choix du porteur du projet :
  un héros qui monte dans la Tour quitte le terrain le temps de l'étage (il garde sa place et son
  programme, le temps dans la Tour ne compte pas) et reprend l'entraînement après.
  À terme (pas encore fait) : le temps du lobby ira 3 fois plus vite que le temps réel, et les héros se
  baladeront et feront des choses d'eux-mêmes, comme aller au terrain d'entraînement.
- `scripts/armory_screen.gd` : Armurerie (ouverte depuis le hub). Tirage d'armes x1 / x10 payé en or
  (`WEAPON_DRAW_COST`), grades F à C+ (`WEAPON_GRADES`), arsenal (`GameData.arsenal`, une arme porte le
  numéro de son héros dans `owner`, 0 = rangée). Types : Épée, Lance, Dague, Fouet, Arc, Bouclier
  (`WEAPON_TYPES` : portée, force, vitesse). Deux emplacements : arme + bouclier (pas de bouclier avec un arc).
  Sans arme : vieille épée de fer [F] (vieil arc de chasse [F] pour les archers). Les mages et soigneurs
  n'ont pas d'arme. Choix du porteur du projet : un héros ne prend une arme de l'arsenal qu'en partant
  en mission (Tour ou donjon journalier, `gear_up()`) et la repose au retour (`tidy_arsenal()`, appelée
  après chaque changement de l'arsenal ou des héros) ; si le Maître choisit (`hero["manual_gear"]`),
  le héros garde ses armes en permanence jusqu'au bouton « Auto ».
  Choix du porteur du projet : quand un héros meurt, ses armes sont perdues avec lui.
  Le terrain d'entraînement ne s'ouvre qu'après 10 armes tirées (`TRAINING_UNLOCK_DRAWS`, `weapon_draws`) :
  dans une partie neuve, c'est le tirage x10 offert du tutoriel (étape « armes »).
  En combat, l'arme d'un héros décide de sa portée (un héros avec un arc tire), le grade ajoute de
  l'attaque, le bouclier de la défense ; les maîtrises d'arme ne comptent qu'avec l'arme qui va avec.
- Progrès des compétences : `hero["skill_progress"]` (points par compétence) et `GameData.add_skill_progress()`
  (au seuil : apprise ou niveau suivant). Sert à l'entraînement (10 + croissance par séance, 100 par niveau)
  et à Maîtrise de l'arc (1 point par flèche tirée, 50 par niveau). Chiffres dans `GameData`.
- Tour : on peut refaire un étage déjà conquis (Donjons > « Refaire un étage ») pour entraîner une
  nouvelle équipe ou l'équipe principale : récompenses baissées à la demande du porteur du projet
  (`REPLAY_XP_RATE` = moitié de l'expérience, `REPLAY_GOLD_RATE` = 20 % de l'or), pas de gemmes,
  la Tour ne monte pas. `start_tower_battle` reçoit l'étage joué. Phase 1.2 (cahier, lot A) : après le choix
  de l'étage, fenêtre « Défier de nouveau ? » avec la récompense réduite, Oui / Non (`_confirm_replay` de
  `dungeons_screen.gd`). Règle vérifiée : 20 % de l'or, aucun matériau (ni pierre d'attribut), pas de gemmes.
- Affectations (bouton du hub, `scripts/assignment_panel.gd`) : `POSTS_PER_BUILDING` = 2 postes
  d'assistant par bâtiment construit (`hero["post"]`) ; un poste et l'entraînement s'excluent.
  Un héros parti (Tour ou donjon journalier, `GameData.is_away`) ne s'entraîne pas et ne compte pas à son poste.
- Donjon journalier (carte de l'écran Donjons, `lobby.gd`) : calendrier selon le jour réel de l'appareil
  (`DAILY_DUNGEONS`, `open_daily_dungeons()`) : lundi-mardi Mine d'Isralta, mercredi-jeudi Forêt Kenout,
  vendredi-samedi Plateau Sinmiel, dimanche tous (on choisit le donjon). Chacun a ses trois matériaux
  (provisoires : la mine garde fer, charbon, cristal ; forêt bois, peau de bête, herbe médicinale ;
  plateau pierre de taille, plume, lin — pas encore utilisés par la forge). Quatre cartes de calendrier à cadre
  argenté, celle du jour dorée. Choix du porteur du projet : autant d'expéditions qu'on veut, plusieurs groupes
  à la fois (`GameData.expeditions`, liste ; plus de limite par jour ; les anciennes sauvegardes à une seule
  expédition sont reprises). Une équipe composée part récolter `EXPEDITION_SECONDS` en temps réel (même jeu
  fermé), avec ses héros libres ; fenêtre système à l'entrée (« Le groupe X est entré dans le donjon journalier,
  [nom] ([difficulté]). Ils reviendront après avoir acquis des matériaux ! ») ; ramassages tirés au départ et
  annoncés au fil du temps (`expedition["log"]`), matériaux gradés, déchets, plans de forge rares ; retour dans
  l'entrepôt (`GameData.warehouse`, rapports dans `expedition_reports`). Monstres rares : un par donjon
  (Reine de la forêt du cahier ; Taupe de cristal et Aigle d'argent inventés), `RARE_MONSTER_CHANCE` (10 %)
  par expédition, `RARE_MONSTER_STONES` (2) pierres d'attribut pour la promotion. Mode dev : terminer les
  expéditions, monstre rare garanti, jour simulé (« jour suivant »). Reste : héros qui y vont d'eux-mêmes
  (avec les héros autonomes du lobby), fermeture du donjon du jour (les « 10 heures » du cahier), chasse.
- Forge (annexe de l'armurerie, `scripts/forge_screen.gd`, construite 500 gemmes) : recettes
  `FORGE_RECIPES`, rang de base = grade du minerai (+1 avec un plan), malus infrastructures / artisan / plan,
  chance affichée (Certaine... Infime) avec Oui / Non, production automatique ou puzzle
  (`scripts/forge_puzzle.gd`, 5 difficultés du cahier, 3 minutes, succès / grand / phénoménal).
  Les assistants de la forge deviennent artisans (compétence « Forge ») en travaillant.
- Chambre de synthèse (`scripts/synthesis_screen.gd`, ouverte depuis le hub, construite 500 gemmes sans
  attendre le terrain d'entraînement) : on choisit le héros à renforcer, puis 1 à `SYNTHESIS_MAX_SACRIFICES`
  (5) héros à sacrifier, de n'importe quel rang (recherche `HeroFilter`) ; fenêtre rouge de confirmation.
  Les sacrifiés meurent pour toujours (cause gardée, armes perdues). Le héros renforcé gagne l'expérience de
  chaque sacrifié et toujours au moins un niveau (cahier : « monte de niveau ») ; pour chaque sacrifié,
  `SYNTHESIS_SKILL_CHANCE` (80 %, feuille de route v2 ; avant 20 %) d'apprendre une de ses compétences qu'il
  n'a pas encore, au niveau 1 (pas une fusion ; incompatibilités respectées). Fenêtre « Synthèse terminée » :
  « X monte en niveau ! La compétence Y a été apprise ! », puis l'expérience et d'où vient chaque compétence ; Œil de faucon (30 %, archers, mages, soigneurs : portée et précision des
  tirs) ; Analyse froide (1 %). Règles et chiffres provisoires dans `game_data/synthesis.gd`.
  Les héros secrets peuvent être sacrifiés (seuls les favoris sont protégés). Chaque synthèse fait baisser la santé mentale des héros
  vivants (voir « Personnalité »). Reste :
  glisser-déposer du cahier (on touche les cartes pour l'instant), salle de promotion dans la chambre.
- Un écran peut définir `on_shown()`, appelée à chaque fois qu'il s'affiche.

## Avancement (phases du cahier des charges)
- Phase 1 (héros et combat) : fiche à 4 stats, classe Novice, niveaux/XP, plafond par étoile,
  croissance cachée et talents cachés des 1 étoile, combat auto, mort définitive avec cause : fait.
  Croissance selon l'activité (feuille de route v2, phase 0 ; `heroes.gd`, `_level_up`) : le total de points
  par niveau reste la valeur de croissance, réparti (au plus fort reste) selon ce que le héros a fait depuis
  son dernier niveau (`hero["growth_log"]`, remis à zéro à chaque montée ; `add_activity`) : coups portés →
  Force, esquives et tirs → Dextérité, coups encaissés → Santé, sorts et soins → Intelligence (combat :
  `fighter["acts"]`, `Battle.ACT_STAT`, ajoutés par `finish_tower_battle` ; terrain d'entraînement :
  `TRAINING_STATS`, `TRAINING_ACTIVITY_PER_SESSION` 3 par séance ; l'« étude » viendra avec la bibliothèque).
  Une stat sous `STAT_DECAY_SHARE` (10 %) de l'activité peut perdre 1 point (`STAT_DECAY_CHANCE` 30 %, une par
  niveau, jamais sous 1) au profit de la plus utilisée. Sans activité (mode dev, ancienne sauvegarde) :
  l'ancienne répartition au hasard. Détail dans la fenêtre de fin de combat (« X passe au niveau 4 ! (Force +2,
  Santé +1) », `GameData.last_growth`, `growth_text`) et dans le résultat de la synthèse.
  Saignement/hémorragie, éveil des compétences en situation critique, premières compétences
  (Résistance à la douleur, Mouvement souple, Calme, Berserk ; Calme et Berserk incompatibles sauf
  pour Han) : fait, chiffres provisoires dans `battle.gd` et `GameData.SKILLS`.
  Lot de test (onglet « Compétences » du cahier) : Maîtrise de l'épée et Utilisation du bouclier au
  terrain d'entraînement, Maîtrise de l'arc par l'usage : fait.
  Fusions (`GameData.SKILL_FUSIONS`) : deux compétences au niveau `FUSION_LEVEL` (10, choix du porteur du
  projet ; le cahier disait 5) + un déclencheur en combat. Surpassement = Calme + Berserk, quand Berserk se
  s'active (Han seulement) ; Épée et bouclier = les deux maîtrises, en finissant un combat de la Tour debout
  épée et bouclier en main. La compétence fusionnée remplace les deux et garde leurs effets (`skill_level`).
  Han apprend Berserk plus facilement (choix du porteur du projet) : 80 % de chances d'éveil
  (`HAN_AWAKENING_CHANCE`), Berserk dès 25 % de vie et en priorité.
  Les autres héros : chance à part « aux portes de la mort » (`DEATH_DOOR_CHANCE`, 30 %) la première fois
  qu'ils passent sous 15 % de vie dans un combat. (Avant, Berserk n'était tiré qu'à l'éveil, vers 20-25 % de
  vie : presque impossible, aucun héros ne l'avait gardé en 900 essais simulés.)
  Berserk rare (demande du porteur du projet, après la phase 1.2 ; dans l'œuvre, seul Han l'éveille) : la
  chance des portes de la mort (`DEATH_DOOR_CHANCE`) et l'éveil sont réservés à Han ; les autres héros ne
  l'éveillent que s'ils sont Courageux ou Ambitieux (`BERSERK_AWAKEN_TRAITS`, `heroes.gd`), avec
  `BERSERK_AWAKEN_CHANCE` (10 %), une seule fois dans leur vie (la chance est tentée la première fois qu'ils
  passent sous 15 % de vie, puis plus jamais : `hero["berserk_door_tried"]`, enregistré) ; le trait se révèle
  (`Battle._berserk_door`). Avant ce changement : environ 0,5 éveil par combat à l'étage 1 pour une équipe
  neuve (10 % des héros), 1,1 aux étages 2 à 4 (22 % des héros, à chaque combat), 0,35 à 0,6 pour une préparée.
  Utilisation de Berserk (feuille de route v2, phase 0 ; avant : rage automatique sous 30 % de vie) :
  compétence active à bascule (`heroes.gd`, section « Berserk » ; `battle.gd`, `_berserk_think`). Le héros
  l'active de lui-même quand le combat est difficile (`_in_danger` : duel, boss ou horde à portée
  d'engagement, allié ou lui-même sous `BERSERK_DANGER_HP` 30 % à moins de 5 cases), sauf en pleine peur ou
  panique, en migraine, sous les seuils de coupure ou `BERSERK_ORDER_HOLD` (15 s) après un ordre de la
  couper ; il la coupe quand le danger est passé (après `BERSERK_MIN_SECONDS`, 5 s). Coupure automatique
  (ajout du projet, validé par le porteur du projet) : sous `BERSERK_STOP_MENTAL` (25) de santé mentale, sous
  `BERSERK_STOP_HP` (15 %) de vie, ou en Surpassement sous `SURPASS_STOP_HP` (25 %) ; plus tard, ces seuils
  dépendront du caractère (Maîtrise de soi, axe caché de la phase 5). Le Maître l'ordonne : bouton
  « Berserk ! » / « Sortir du Berserk » de `BattleView` quand le héros choisi l'a (`order_berserk`, peut être
  refusé comme tout ordre) ; une rage ordonnée n'est coupée que sur ordre ou à la fin du combat. Effet :
  Force, Santé, Dextérité +`BERSERK_BONUS` (5, +1 par niveau suivant), Intelligence -`BERSERK_INT_MALUS` (10)
  (`berserk_stat_changes` ; l'œuvre dit Force, Endurance, Agilité), traduits en attaque, défense, vitesse,
  critiques (la vie maximum ne bouge pas) ; coût par seconde : -`BERSERK_DRAIN_PER_SECOND` (1 %) de la vie
  maximum (dans l'œuvre, la compétence coûte de la vie ; mort possible : « épuisé par Berserk ») et
  -`MENTAL_BERSERK_PER_SECOND` (0,4) de santé mentale.
  Fenêtres (`Battle.alerts`) « X est entré en mode Berserk ! » et « X est sorti de son état Berserk. » ;
  fin du combat : une ligne dans « Personnalité ». Puis Migraine `MIGRAINE_SECONDS` (3 min de temps réel,
  `hero["migraine_until"]`, continue après le combat) : dégâts x`MIGRAINE_DAMAGE_FACTOR` (0,9). Surpassement :
  même bascule, bonus x2, plus de saignement, -2 % de vie par seconde (au lieu de 1 %), santé mentale x2,
  migraine x2.
  Rage d'éveil (phase 1.2, interprétation du ch. 12, demande du porteur du projet ; `heroes.gd`,
  `AWAKENING_RAGE_SECONDS` ; `battle.gd`, `_awakening_rage`, `_hold_on`) : quand Berserk s'éveille en combat
  (portes de la mort ou éveil), le héros entre aussitôt en rage (fenêtre « Rage d'éveil : il refuse de
  mourir ! »). Pendant `AWAKENING_RAGE_SECONDS` (8 s), pas de coupure automatique et il ne peut pas tomber
  sous 1 point de vie (coups, part d'un Protecteur, saignement, coût de la rage) ; « REFUS DE MOURIR » sous le
  portrait. Ensuite, règles normales (sous 15 % de vie, il la coupe) ; la migraine de cette première rage dure
  x`AWAKENING_MIGRAINE_FACTOR` (2, donc 6 min). Simulation (200 combats par étage, sans ordres) : héros qui
  survivent au combat où ils apprennent Berserk, avant → après : équipe neuve étage 1 : 42 → 92-95 %, étages
  2 à 4 : 6-10 → 25-36 % ; préparée étages 2 à 4 : 34-46 → 56-78 %. Effet de bord : la rage d'éveil fait
  aussi gagner l'équipe (équipe neuve, étages 2 à 4 : 7-17 → 20-37 % de victoires).
  Écran de combat : « BERSERK » / « MIGRAINE » sous le portrait. Fiche : statistiques en Berserk
  « valeur actuelle / valeur de base (+5) » (`berserk_preview`) et migraine restante.
  Résistance aux flammes (feu subi, ou 3 combats avec un mage de feu ; les mages ont un élément
  `hero["element"]`), Indomptable (éveil en saignant), Tueur de gobelins (coup fatal au boss de l'étage 5,
  ou 50 gobelins), Esprit combatif (évolution de Résistance à la douleur au niveau 10, `SKILL_EVOLUTIONS`) : fait.
  Mana (mages et soigneurs, héros et ennemis) : réserve = Intelligence x `MANA_PER_INT`, recharge
  `MANA_REGEN_PER_INT` par seconde ; sort de zone et soin coûtent du mana, à sec le mage lance un petit
  trait gratuit et le soigneur ne soigne plus (compte surtout dans les longs combats). Écran de combat :
  encart de l'équipe sous la carte, demandé par le porteur du projet (héros côte à côte, PV actuels / max
  et pourcentage, mana chiffrée, toucher = choisir le héros) et barre de vie du boss en haut : fait. Phase 1 terminée, y compris les compétences liées à la synthèse
  (compétence héritée, Analyse froide, Œil de faucon : voir la chambre de synthèse).
  Reste plus tard : autres fusions (Âme de l'épée...), rangs de compétence, formations entraînées par une
  IA dans la salle d'opération.
- Phase 2 (Tour) : étages, équipes de 5, boss tous les 5 étages, or/gemmes/XP, MVP : fait.
  Quêtes d'étage (`GameData.floor_quest`) : extermination (1), subjugation (2), annihilation avec
  renforts, survie à la horde tous les 5 étages (niveau caché, ruelles, compte à rebours lancé au premier
  coup échangé : `quest["wait_contact"]`, `Battle.clock_time()`), défense de la cité tous les 10 étages
  (remparts, triple avertissement), limite de tours, annonce du donjon journalier après l'étage 5 : fait.
  Au combat, 6 ennemis au plus à la fois, les autres arrivent en renfort.
  Tension à chaque étage, préparation nécessaire (demandes du porteur du projet ; l'étage 1 « écrème ») :
  `EARLY_FLOOR_ENEMIES` donne pour les étages 1 à 4 un minimum de monstres et de sortes de monstres (étage 1 :
  5, gobelins et loups noirs ; étages 2 à 4 : 6, archers squelettes compris) ; avant : 2 gobelins à l'étage 1.
  Étages 5 et plus : formule inchangée. Simulation, sans ordres, équipe du tutoriel au niveau de l'étage
  (« brute ») ou 2 niveaux de plus avec épée et bouclier, ou arc, de grade D (« préparée ») :
  étage 1 brute 99 % de victoires, ~1 mort ; étages 2 à 4 brute 44-57 % (~3,5 morts), préparée 94-97 %
  (~1 mort), 2 niveaux de plus sans armes 72-81 % ; étages 6 et 8 brute 34-40 %, préparée 90 % ; étage 5
  (survie, boss) brute 5 %, préparée 47 % ; étage 10 (défense) brute 28 %, préparée 49 %. À refaire après
  tout changement d'équilibre.
  Survie par vagues (phase 1.2, demande du porteur du projet ; œuvre : l'étage 5, 30 minutes, « broyeur de
  héros ») : la difficulté vient de la durée et de l'usure, pas d'un seul choc de 25 s (l'ancienne horde
  unique : 8 monstres, réduite à 5 au réglage précédent par `SURVIVAL_HORDE_EXTRA`, supprimé). `tower.gd` :
  `SURVIVAL_SECONDS` (210 s) à tenir (la défense garde `DEFENSE_SECONDS`, 60 s), `SURVIVAL_WAVES` (6) vagues,
  une toutes les `SURVIVAL_WAVE_SECONDS` (35 s) du compte à rebours, de `SURVIVAL_WAVE_MONSTERS` (1) + étage / 5
  monstres chacune (étage 5 : 6 x 2 = 12 monstres et le chef gobelin ; `enemy["wave"]`, `tower_enemies`) ; le
  boss vient avec la dernière. `battle.gd` : `current_wave()`, seule la
  vague 0 est placée au départ, les suivantes entrent par `_call_reinforcements` (6 ennemis au plus à la
  fois), chaque vague annoncée (journal, fenêtre « Vague N »). Écran : « Vague 2/5 » à côté du compte à
  rebours (affiché en permanence, « 3:30 au premier contact » tant qu'il attend) ; annonce de l'étage.
  Quête sans `waves` (ancienne sauvegarde en plein combat) : tous les ennemis en vague 0, comme avant.
  Terrain de survie (phase 1.2 ; ch. 9 et 11 ; depuis C1 : gabarit « ville » de `MapGenerator`) : une rangée de
  maisons d'un bord à l'autre (lignes `ALLEY_ROW` 8 à 10) percée de `SURVIVAL_ALLEYS` (3) ruelles larges d'une
  case ; quelques rochers et débris côté ennemis. Phase 1.2 : 2 hauteurs de 2 x 2 (1 niveau, +20 % / -25 %) à la
  sortie des ruelles ; remplacées en C1 par les toits à 2 niveaux, les échelles et le clocher (voir « Combat v2,
  étape C1 »). Le Maître y envoie un héros par un ordre (toucher le toit) ; un héros dont le poste est en hauteur
  la tient (il ne descend pas courir après les ennemis, il frappe ce qui est à sa portée). Les héros n'y vont pas
  d'eux-mêmes, sauf les tireurs qu'un Meneur y poste.
  Simulation de la phase 1.2 (200 combats par réglage, 150 à 420 pour l'étage 5 ; équipe du tutoriel ;
  « préparée » : 2 niveaux de plus, épée et bouclier D, arc D ; Maître simulé : rotation des fatigués et
  tireurs sur les hauteurs) — victoires avant → après (morts par combat) :
  neuve étages 1 à 4 : 96 / 17 / 7 / 7 % → 98 / 37 / 20 / 28 % (morts 1,2 / 4,3 / 4,6 / 4,5 → 0,8 / 3,4 / 4 /
  3,8 : surtout la rage d'éveil) ; préparée sans ordres étages 1 à 4 : 100 / 95 / 88 / 83 % → 100 / 97 / 93 / 88 %
  (mur de boucliers) ; avec Maître et 3 potions : 100 / 97 / 92 / 93 % → 100 / 97 / 94 / 95 %, morts 0,1 à 0,3.
  Étage 5, réglages essayés (préparée, Maître) : 5 vagues de 4 : 0 % ; 5 x 3 : 8 % ; 6 x 2 : 28 à 36 % selon les
  séries (environ 33 %), 39 % avec 3 potions ; sans Maître 23-24 %, rotation sans hauteurs 20 %. Avant (une seule
  horde de 5) : préparée 21 %, Maître 15 %, Maître et potions 30 %. Équipe neuve : 0 %. Un combat de l'étage 5
  dure maintenant 3 min environ (190 s) au lieu de 25 s. Ce Maître simulé est simpliste : un joueur qui tient
  la sortie des ruelles et fait tourner ses héros devrait faire mieux.
  Écart avec `tools/sim_tower` (étape 0 avant P1b ; pas de rééquilibrage) : ces 23-36 % venaient d'un autre
  simulateur (session de la phase 1.2, pas dans le dépôt) dont l'équipe « préparée » était au niveau 7 (étage + 2)
  et faite de 5 Novices (le 3★ compris), alors que les monstres de l'étage 5 sont au niveau 9 (5 + 2 + palier 2).
  `sim_tower` met la « préparée » 2 niveaux au-dessus des monstres (niveau 11 ; les 1★ s'arrêtent à 10) avec de
  vraies classes. Même code (après l'étape 0), sans Meneur ni ordres ni potions : `sim_tower` niveau 11 : 74 % ;
  niveau 9 : 60 % ; niveau 7 : 40 % ; niveau 5 : 22 %. Ancien simulateur relancé tel quel (niveau 7, Novices,
  500 combats) : sans Maître 16 % (24 % avec 3 potions), avec son Maître simulé 24 % (26 %). L'ancien 33 % était
  mesuré sur 60 à 420 combats, avant le Berserk rare. Le jeu n'a donc pas changé : c'est l'équipe simulée. Pour
  viser environ 33 % avec un Maître qui joue, il faut d'abord dire quelle équipe est « préparée » à l'étage 5
  (au niveau des monstres ou en dessous, avec quelles classes) ; à décider avec le porteur du projet.
  Paliers : tous les 5 étages (étage de boss), les ennemis gagnent 2 niveaux de plus
  (`TIER_BONUS_LEVELS`), et les étages suivants restent à ce cran : il faut y arriver préparé.
  Difficulté voulue par le porteur du projet : la défense de l'étage 10 reste très dure (presque
  impossible au niveau de départ). C'est un palier réservé aux héros équipés, avec des compétences
  et de l'expérience : ne pas l'adoucir sans lui demander.
  Écran de fin : or, gemmes, matériaux gradés de la Tour (`tower_materials`, grade selon le palier
  `TOWER_MATERIAL_GRADES`, provisoire : le cahier montre du C dès l'étage 1 ; le charbon remplace le cuir,
  qui n'existe pas encore ; rien en rejouant un étage), pierres d'attribut des boss, une case par objet
  (`UI.make_reward_items`), armes perdues avec les morts (`report["lost_weapons"]`), niveaux, MVP : fait.
  Glisser-déposer des héros dans le groupe : fait. Reste : équipes de 3 et quêtes à deux équipes,
  autres types de quêtes (escorte, invasion...).
- Phase 3 (gacha) : invocation normale (or) et spéciale (gemmes, meilleurs taux, seule à donner des
  mages, pity de 50) dans `GameData.SUMMON_TYPES`, tirage d'armes, arsenal et équipement : fait.
  L'« invocation gratuite » du cahier est l'invocation normale en or (l'or est la monnaie gagnée
  en jeu, précision du porteur du projet). Raretés (choix du porteur du projet, aligné sur l'œuvre ; onglet
  « Invocations et classes » du cahier) : invocation en or de 1 à 3 étoiles, les 2 et 3 étoiles très très rares
  (demande du porteur du projet ; provisoire : 1 étoile 97,5 %, 2 étoiles 2 %, 3 étoiles 0,5 % ; avant : 60 / 30 /
  10 %), sauf la première x10 du tutoriel (un 3 étoiles garanti), invocation en gemmes de 3 à 5 étoiles (provisoire : 3 étoiles 75 %,
  4 étoiles 21 %, 5 étoiles 4 %, pity de 50). Ancien réglage : or de 1 à 4 étoiles, gemmes de 1 à 5.
  Limite de héros (choix du porteur du projet) : `GameData.HERO_LIMIT` (50, provisoire, grandira avec le
  niveau des résidences) héros vivants pour invoquer ; les héros secrets s'obtiennent même plein.
  Dans chaque rareté d'étoiles, une rareté de classe (`CLASS_RATES`) : 1-2 étoiles tous Novice (ils
  changent de classe ensuite, voir « Changement de classe ») ;
  mages seulement en invocation spéciale, 1 % des 3 étoiles et plus (donc 1 % des invocations spéciales).
  Bouton « Détail des taux » sur l'écran d'invocation (étoiles possibles, pity, taux et classes).
  Les mages sont puissants mais fragiles (comme la magicienne du manhwa : Intelligence ~31, le reste 7-8 ;
  `_roll_stats`, `MAGE_STAT_MALUS`). Avoir un mage vivant permet de construire les bâtiments de magie
  (`GameData.BUILDINGS` : atelier de magie, laboratoire d'alchimie, bibliothèque ; les trois fusionnent en
  Hall de magie) : bouton « Construction » du hub (`scripts/construction_panel.gd`). Choix du porteur du
  projet : le premier, l'atelier de magie, se construit tout seul et gratuitement dès qu'un mage vivant
  rejoint les héros (`"auto": "mage"`, `GameData.check_auto_buildings()`, appelée par `save_game()`),
  avec la fenêtre « Construction terminée » et l'animation du hub 3D. Les deux autres : en gemmes, après
  l'ouverture du terrain d'entraînement. Leurs fonctions (Recherche, synthèse, savoir des mages) restent à faire.
  Reste : grades au-delà de C+, compétences de lance, dague et fouet.
- Phases 4 à 6 (lobby, artisanat, fin de jeu) : construction, affectations, donjon journalier, entrepôt
  et forge : premières versions faites ; donjon journalier complet (calendrier, trois donjons, monstres rares,
  fenêtre d'entrée). Reste : niveaux de bâtiment, recettes avec les nouveaux matériaux (bois, peau de bête...),
  fonctions des bâtiments de magie, cafétéria, etc. Sauvegarde de la partie : faite
  (reste l'équilibrage de la phase 6).
