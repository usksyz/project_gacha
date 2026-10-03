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
Exceptions : les héros secrets (Han, Hansen, Zid, Shei, Jenna, Aaron, la magicienne Yvolka, la voleuse
Edith...), clins d'œil au manhwa (stats du tableau du cahier quand on les connaît : clé « stats ») ; et les
trois donjons journaliers (Mine d'Isralta, Forêt Kenout, Plateau Sinmiel, choix du porteur du projet).
Ils sont immortels et s'obtiennent tous par code secret, Han compris (code « HAN », choix du porteur du
projet ; avant, Han était donné au début), dans Paramètres > Codes secrets ou sur la Place publique du hub.
Une partie neuve commence sans héros. Un héros secret déjà possédé ne peut pas être obtenu deux fois. Ils sont définis dans `SECRET_HEROES` (`game_data/heroes.gd`).
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
  `game_state.gd` (`GameState` : variables enregistrées, or et gemmes, signaux), `heroes.gd` (`GameHeroes` :
  fiche, stats, héros secrets, compétences, expérience, changement de classe, équipes, favoris, `is_away`), `training.gd`
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
  de 0,1 s (`start()` puis `step()`) : grille avec décor, recherche de chemin `AStarGrid2D`, ligne de
  vue pour les tirs, particularités de chaque classe, saignement, éveil, renforts, remparts, ordres
  du joueur (`order_move`, `order_attack`). `run()` joue tout d'un coup sans ordres.
  `scripts/battle_view.gd` : classe `BattleView`, affiche le combat en direct (pions, coups,
  chiffres) ; on touche un héros puis un endroit ou un ennemi pour lui donner un ordre ; pause
  (aucun ordre pendant la pause, choix du porteur du projet).
  Le combat continue si on change d'onglet. Il est noté dans la sauvegarde dès le début
  (`GameData.pending_battle`) : si le jeu est fermé en plein combat, il est terminé sans ordres au
  lancement suivant, et `main.gd` annonce le résultat (« Pendant ton absence »).
- Choix du porteur du projet pour le combat : du temps réel (pas du tour par tour) où l'on voit les
  personnages bouger, utiliser le décor, et les ennemis leur foncer dessus. On vit le combat :
  jamais de bouton « passer » ni d'accélération. Le joueur soutient ses héros en les guidant
  pendant le combat (ce qui peut changer le résultat) ou les laisse se débrouiller ; plus tard, les
  consignes de la salle d'opération seront apprises peu à peu par les héros qui participent au
  combat. Vue du dessus pour l'instant, vue isométrique 3D plus tard.
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
  Le terrain d'entraînement ne s'ouvre qu'après 10 armes tirées (`TRAINING_UNLOCK_DRAWS`, `weapon_draws`).
  En combat, l'arme d'un héros décide de sa portée (un héros avec un arc tire), le grade ajoute de
  l'attaque, le bouclier de la défense ; les maîtrises d'arme ne comptent qu'avec l'arme qui va avec.
- Progrès des compétences : `hero["skill_progress"]` (points par compétence) et `GameData.add_skill_progress()`
  (au seuil : apprise ou niveau suivant). Sert à l'entraînement (10 + croissance par séance, 100 par niveau)
  et à Maîtrise de l'arc (1 point par flèche tirée, 50 par niveau). Chiffres dans `GameData`.
- Tour : on peut refaire un étage déjà conquis (Donjons > « Refaire un étage ») pour entraîner une
  nouvelle équipe ou l'équipe principale : récompenses baissées à la demande du porteur du projet
  (`REPLAY_XP_RATE` = moitié de l'expérience, `REPLAY_GOLD_RATE` = 20 % de l'or), pas de gemmes,
  la Tour ne monte pas. `start_tower_battle` reçoit l'étage joué.
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
  chaque sacrifié et au moins un niveau (cahier : « monte de niveau ») ; 20 % par sacrifié de récupérer une
  de ses compétences au niveau 1 ; Œil de faucon (30 %, archers, mages, soigneurs : portée et précision des
  tirs) ; Analyse froide (1 %). Règles et chiffres provisoires dans `game_data/synthesis.gd`.
  Les héros secrets ne peuvent pas être sacrifiés. Reste : perte de moral (avec le moral, phase 5),
  glisser-déposer du cahier (on touche les cartes pour l'instant), salle de promotion dans la chambre.
- Un écran peut définir `on_shown()`, appelée à chaque fois qu'il s'affiche.

## Avancement (phases du cahier des charges)
- Phase 1 (héros et combat) : fiche à 4 stats, classe Novice, niveaux/XP, plafond par étoile,
  croissance cachée et talents cachés des 1 étoile, combat auto, mort définitive avec cause : fait.
  Saignement/hémorragie, éveil des compétences en situation critique, premières compétences
  (Résistance à la douleur, Mouvement souple, Calme, Berserk ; Calme et Berserk incompatibles sauf
  pour Han) : fait, chiffres provisoires dans `battle.gd` et `GameData.SKILLS`.
  Lot de test (onglet « Compétences » du cahier) : Maîtrise de l'épée et Utilisation du bouclier au
  terrain d'entraînement, Maîtrise de l'arc par l'usage : fait.
  Fusions (`GameData.SKILL_FUSIONS`) : deux compétences au niveau `FUSION_LEVEL` (10, choix du porteur du
  projet ; le cahier disait 5) + un déclencheur en combat. Surpassement = Calme + Berserk, quand Berserk se
  déclenche (Han seulement) ; Épée et bouclier = les deux maîtrises, en finissant un combat de la Tour debout
  épée et bouclier en main. La compétence fusionnée remplace les deux et garde leurs effets (`skill_level`).
  Han apprend Berserk plus facilement (choix du porteur du projet) : 80 % de chances d'éveil
  (`HAN_AWAKENING_CHANCE`), Berserk dès 25 % de vie et en priorité.
  Les autres héros : chance à part « aux portes de la mort » (`DEATH_DOOR_CHANCE`, 30 %) la première fois
  qu'ils passent sous 15 % de vie dans un combat. (Avant, Berserk n'était tiré qu'à l'éveil, vers 20-25 % de
  vie : presque impossible, aucun héros ne l'avait gardé en 900 essais simulés.)
  Résistance aux flammes (feu subi, ou 3 combats avec un mage de feu ; les mages ont un élément
  `hero["element"]`), Indomptable (éveil en saignant), Tueur de gobelins (coup fatal au boss de l'étage 5,
  ou 50 gobelins), Esprit combatif (évolution de Résistance à la douleur au niveau 10, `SKILL_EVOLUTIONS`),
  Berserk affiché sur la fiche (`berserk_preview`) : fait.
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
  « Invocations et classes » du cahier) : invocation en or de 1 à 3 étoiles (provisoire : 1 étoile 60 %,
  2 étoiles 30 %, 3 étoiles 10 %), invocation en gemmes de 3 à 5 étoiles (provisoire : 3 étoiles 75 %,
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
