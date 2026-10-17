# Combat et Tour

Les renvois « voir … » peuvent désigner une autre partie de `docs/` ou `CLAUDE.md` (le fichier d'origine a été découpé au prompt 5, sans rien réécrire).

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
- Fichiers de `Battle` (prompt 5, point 3, sans rien changer au comportement) : une pile de classes, comme `GameData`,
  chaque fichier `extends` le précédent et `scripts/battle.gd` (`Battle`) est en haut ; on écrit toujours `Battle` ou
  `battle.xxx`. De bas en haut, dans `scripts/battle/` : `battle_base.gd` (`BattleBase` : constantes, état du combat,
  champ de bataille et placement, petits outils), `battle_journal.gd` (journal de combat), `battle_formations.gd`
  (formations, Protecteur, liens, rotation, Meneur), `battle_moves.gd` (déplacements, endurance, chemins, flux, chutes),
  `battle_mind.gd` (peur, santé mentale, rupture, désobéissance), `battle_berserk.gd` (situation critique, éveil,
  Berserk), `battle_care.gd` (saignement, agonie, secours, mort) ; `battle.gd` : début et pas du combat, ordres, choix
  des cibles, attaques, fin du combat. Toute variable ou constante va dans `battle_base.gd`. Une fonction appelée plus
  bas que son fichier est déclarée vide en bas de `battle_base.gd` avec la même signature (13 aujourd'hui, comme
  `save_game` dans `GameData`) : en ajouter une si la compilation dit « Function not found in base self ».
  Vérifié : `sim_tower` (8 séries, dont Maître simulé, Meneur, ancienne IA) et une trace pas à pas identiques avant et
  après, au caractère près (hors temps de calcul) ; `capture_c2 mode=identique` (10 combats) identique ; bancs bons.
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
  Mesures avant / après C1 : voir `docs/mesures.md` (« Combat v2 »).
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
  Performance mesurée : voir `docs/mesures.md` (« Combat v2 »).
  7. Vérifications : `tools/capture_c2.tscn` (dans une copie du projet, avec une fenêtre ; voir son en-tête) :
  « mode=capture » (images, « rot », « choisi », « archer_toit », « cache » : héros posé derrière un bâtiment),
  « mode=ordres » (héros, toit, rue, montée par l'échelle : étages 1 et 5), « mode=identique » (le même combat sans
  écran et à travers l'écran 3D : 10 combats des étages 1, 2, 3, 5 et 10, identiques au caractère près).
  Depuis C3 : « vue=dessus » (la capture dans la vue de dessus).
- Combat v2, étape C3 (cahier, onglet « Combat v2 », section 4 « La perception en bâtonnets », section « L'IA
  tactique des héros » ; chiffres provisoires) : perception et IA tactique des héros. Aucun rééquilibrage.
  Partie A, perception (`scripts/battle_perception.gd`, `BattlePerception`, `Battle.perception` ; chiffres dans
  `tower.gd`, section « Perception en bâtonnets ») :
  1. Bâtonnets : chaque combattant lance `SIGHT_RAYS` (9) rayons sur `SIGHT_ANGLE` (120°) vers là où il regarde
  (`fighter["facing"]` : la menace connue la plus proche à moins de 3 cases, sinon sa cible, sinon le sens de sa
  marche), `SIGHT_LENGTH` (6) cases au centre, x`SIGHT_SIDE_FACTOR` (0,6) sur les côtés. Chaque rayon parcourt les
  cases qu'il traverse et s'arrête sur un relief plus haut que ses yeux ou un obstacle ; un ennemi à moins d'une
  demi-case d'un rayon, et que la ligne de vue 3D de C1 laisse voir, est vu (`fighter["sees"]`). Ouïe tout autour :
  `HEARING_RADIUS` (2), `HEARING_BEAST_RADIUS` (3,5) pour les bêtes (`EMBED_BEASTS`) (`fighter["hears"]`). Mémoire :
  dernière position connue de chaque ennemi (`fighter["knows"]`) pendant `SIGHT_MEMORY` (5 s, + Maîtrise de soi et
  Intelligence, 3 à 8 s). Mise à jour toutes les `PERCEPTION_INTERVAL` (0,2 s). Hauteur +1 case par niveau ; herbes
  hautes vues du sol : chaque case coûte `SIGHT_GRASS_COST` (2) ; nuit (quête « night », aucune pour l'instant) :
  x0,5 sauf Nocturne (Rythme >= 50) ; peur, panique, Berserk : cône x0,5 (tunnel) ; Acuité (lue par
  `PersonalityEngine.axis`) : +1 rayon tous les 2 paliers, longueur et ouïe +3 % par palier ; Prudence ou Méfiance
  (Audace ou Loyauté <= -30) : un regard en arrière toutes les 3 s ; monstres : longueur x0,8. Aucun tirage au hasard.
  2. Effets : on ne cible que ce que l'on connaît (`Battle._think` : liste `known` ; les ordres du Maître visent
  n'importe qui). Sans ennemi connu, un héros garde son poste et un monstre avance vers les héros sans frapper
  (`_unaware`). Une cible connue de mémoire seulement : il va voir à sa dernière place, puis l'oublie. Attaque
  surprise (`_surprise`) : l'attaquant n'est pas dans les rayons de la cible (l'entendre ne suffit pas) : ni esquive
  ni parade (Mouvement souple, bouclier), +`SURPRISE_CRIT_BONUS` (15 %) de critique (Guerrier et Assassin, qui n'en
  ont pas d'ordinaire, aussi), « surprise ! » sur le chiffre ; pas en duel ; compté dans `Battle.surprises` et
  `journal_counts["surprised"]`. Partage : ce que voient les alliés à moins de `VOICE_RANGE` (4) cases ; un Meneur
  debout (ni peur ni panique) partage avec toute l'équipe. Les monstres ont la même perception (plus courte) et
  partagent à portée de voix. La « vue de l'ennemi » qui peut faire peur : le voir ou l'entendre soi-même.
  3. Œil de faucon devient aussi actif : rayons x2, cône x0,8 pendant `HAWK_EYE_SECONDS` (15 s), puis
  `HAWK_EYE_COOLDOWN` (30 s) ; un tireur l'active de lui-même quand il ne voit aucun ennemi de ses propres yeux
  (`hawk_eye_think`), ou sur ordre (bouton « Œil de faucon » de `BattleView`, `order_hawk_eye`, peut être refusé).
  Ses effets passifs restent. « Sixième sens » (`GameData.SKILLS`) : 3 rayons de 2,5 cases vers l'arrière ; pas
  encore de moyen de l'apprendre (mode dev > fiche > donner une compétence).
  4. Affichage (`BattleView._draw_rays`, `BattleView3D._draw_rays`) : en touchant un héros, ses rayons en traits fins
  avec un point lumineux au bout (à hauteur des yeux en 3D) ; les ennemis qu'aucun héros ne voit ni n'entend sont
  grisés (`BattleView.unseen`), pas de brouillard total.
  Partie B, IA tactique (`scripts/battle_tactics.gd`, `BattleTactics`, `Battle.tactics` ; données à part dans
  `scripts/game_data/tactics_data.gd`, `TacticsData`) :
  5. Toutes les `PLAN_SECONDS` (0,5 s), chaque héros libre (sans ordre, ni secours, ni repos, ni panique, pas en
  duel) fait un plan (`fighter["tactic"]` : attitude, case, cible, 3 raisons) contre les seuls ennemis qu'il
  connaît. Il étudie les cases à pied autour de lui (`SEARCH_RADIUS` 5, les plus proches d'abord) et les note
  (`CRITERIA`, poids `BASE_WEIGHTS`) : hauteur (x2 pour un tireur), bonne distance de tir, alliés proches, à
  découvert sous les tirs (-), à couvert, trop d'ennemis au contact (-), isolé (-), bord d'une chute (-), passage
  étroit devant, dos au mur ; moins le trajet ; bonus pour garder sa case.
  6. Attitudes (`_plan`) : décrocher (blessé sous `retreat_hp` et au moins 2 ennemis au contact : vers les alliés,
  loin des ennemis) ; garder ses distances (tireur, un ennemi au corps à corps à moins de 2,5 cases) ; colère (un
  Colérique, Colère >= 50, charge l'ennemi qui vient de blesser un allié) ; se couvrir (sous le feu d'un tireur
  connu : une case abritée qui le rapproche du tireur, `cover_max` 3 s au plus ; sans abri, ou ensuite, il va
  chercher le tireur) ; protéger (bouclier ou Empathie >= 30 : entre un allié sous 35 % de vie et l'ennemi) ;
  engager (cible à portée, affaiblie, tout près, allié au contact à aider, cible qui ne vient pas, rien fait depuis
  `wait_max`) ; attendre (sinon, à la meilleure case proche, seulement si elle vaut au moins `WAIT_ADVANTAGE` points
  de plus que rester là ; sinon il engage). Un héros qui pense à l'encerclement ne va pas seul vers une cible
  entourée de `engage_crowd` ennemis : il les attend. Concentrer (`_pick_target`) : la cible que frappent les
  alliés, la plus blessée, le tireur qui fait mal ; l'Assassin vise toujours le plus faible. Un ennemi à sa portée :
  il se bat là. Peur : il se bat (ou fuit, règles d'avant), mais choisit la case la plus sûre (`FEAR_WEIGHTS`).
  7. Intelligence (stat) : nombre de critères vus (dans l'ordre de `CRITERIA` : peu intelligent, hauteur et distance
  seulement, et la cible la plus proche) et de cases étudiées (`criteria_count`, `cells_count` : Intelligence 10 :
  3 critères, 14 cases ; 15 : 6, 29 ; 21 : 10, 47) ; Lucidité (Foi négative) et Acuité : un cran de plus tous les
  4 paliers. Personnalité (`TacticsData.PERSONALITY`, lue par `PersonalityEngine.axis` ou `composite`, sans passer
  par `modifier()` : petite table à part, à rapprocher des MODIFIERS de P2 à la fusion) : Audace / Prudence,
  Impulsivité / Maîtrise de soi (portée d'engagement, attente, ennemis acceptés autour d'une cible), Courage,
  Empathie ; Colère, peur (plus haut). Poids et seuils rangés PAR HÉROS et PAR CONTEXTE (« type de quête | famille
  d'ennemis | gabarit », `BattleTactics.context_of`, `Battle.tactics_context`) dans `hero["tactics"]` (sauvegardé :
  {"version", "contexts": {contexte: {"weights", "thresholds", "start_weights", "start_thresholds", "fights"}}}),
  créés au premier combat dans ce contexte (`BattleTactics.profile`) ; ils ne changent pas encore (C3b : bornés
  entre `LEARN_MIN` et `LEARN_MAX` fois la valeur de départ). Sauvegarde version 8 (rien à adapter).
  8. Ordres du Maître : arrivé là où le Maître l'a envoyé (`order["by"] == "maitre"`), le héros tient sa position
  (`fighter["held"]`, `BattleTactics.hold` : il frappe ce qui entre à sa portée, revient à son poste s'il en est
  poussé) jusqu'à un nouvel ordre ou un danger grave (sous `danger_hp` 30 % de vie avec 2 ennemis au contact). Le
  Meneur garde son placement de départ (P5 + toits) : un tireur posté sur un toit le tient ; les autres gardent leur
  place (`leader_post`) jusqu'à ce qu'un ennemi connu soit à moins de 7 cases, puis l'IA.
  9. Mode dev : en touchant un héros, le bandeau dit son attitude, sa cible et ses 3 raisons (`BattleView.tactic_text`,
  aussi en pause), et sa case choisie est encadrée en rose (carré dans la vue de dessus, losange en 3D).
  `Battle.tactical_ai` faux : l'ancien comportement (tous foncent) ; `Battle.perception_on` faux : tout le monde sait
  tout (avant C3). Simulateur `sim_tower` : options `ia=fonce|tactique`, `perception=non`, `diag=oui` (part du temps
  de chaque attitude), `cobaye=malin|fonceur` (le 1 étoile de la place 2 : Intelligence 22, Audace -60, Maîtrise +60,
  ou 8, +60, -60 ; sa mort, sa mise à terre, sa vie à la fin), `suivre=N:*` (tous les héros, chaque seconde) ;
  surprises par combat.
  Mesures : voir « Mesures C3 » plus bas (complétées en fin d'étape).
  (Copies du projet pour les simulations, `override.cfg` sans BOM : voir `CLAUDE.md`, « Principes ».)
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
  Revu à l'étape 0 avant P1b (Meneur ≥ sans Meneur) : historique et simulations dans `docs/mesures.md` (« Phase 1.1 »).
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
  soin (`POTION`, matériau de l'entrepôt, grade F ; préparée à la forge depuis le prompt 1, voir « Économie ») : l'équipe en
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
  Simulations de l'agonie : voir `docs/mesures.md` (« Phase 1.1 »).
  Soin d'urgence : un héros en hémorragie (`_needs_help`) reçoit, après les héros à l'agonie, l'allié libre
  le plus proche (moins de `CARE_HELP_RANGE` 6 cases, même règle que l'agonie, `_assign_helpers`) ; l'aidant
  cesse de combattre et le suit (`_help`) ; à son côté pendant `CARE_SECONDS` (3 s, `_care_tick`),
  l'hémorragie s'arrête : journal et fenêtre « X a arrêté le saignement de Y. ».
  Simulation des quatre points de la phase 1.1 : voir `docs/mesures.md` (« Phase 1.1 »).
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
- Préparer et comprendre un combat (prompt 3 ; Sommaire du cahier : « une défaite doit pouvoir se comprendre et se
  préparer »).
  1. Aperçu de l'étage : `GameData.floor_knowledge(étage)` (`tower.gd`) : ce que les héros en savent : le carnet de
  l'étage à la bibliothèque (`library["floors"]["tour:N"]`) et la mémoire des héros VIVANTS qui y ont combattu
  (`hero["recent_battles"]`, 3 derniers combats : un souvenir s'efface ; ennemis vus = « contact » de leur journal).
  Étage déjà visité : sur la page d'annonce, fenêtre « Ce que tes héros savent » (qui s'en souvient, la carte figée en
  petit, `scripts/floor_preview.gd` `FloorPreview` : couleurs de la vue de dessus, zone de départ en vert, place de
  départ des ennemis déjà vus en rouge ; puis ces ennemis) ; la liste des ennemis du choix de l'équipe ne montre que
  ceux déjà vus (« Et des ennemis que tes héros n'ont jamais vus. »). Première visite : seulement la quête (avant, la
  liste de tous les ennemis s'affichait toujours).
  2. Placement : après « Formation de groupe », `BattleView.play(..., placement = true)` (`DungeonsScreen._start_fight`) :
  le combat est démarré (`start()`) mais n'avance pas ; zone de départ (`Battle.start_zone()` : les lignes `hero_rows`
  et celles entre elles) encadrée en vert dans les deux vues ; on glisse un pion (vue de dessus : `_placement_input` ;
  vue 3D : appuyer sur un héros le prend au lieu de bouger la caméra, `BattleView3D._gui_input`) ou on touche un héros
  puis une case ; sur un autre héros, ils échangent (`Battle.place_hero`). Boutons « Placement automatique »
  (`auto_place` : les places habituelles) et « Commencer » (`_start_battle`, à la place de « Pause »). Un héros placé
  par le Maître (`fighter["placed"]`) tient ce poste (`held`, comme arrivé là sur son ordre) et le Meneur ne le déplace
  pas (`_organize_defense`). Les places sont notées dans le combat en cours (`pending_battle["placement"]`, par numéro de
  héros) : un combat repris au lancement les garde (`_resolve_pending_battle`). Rien n'est tiré au hasard : vérifié avec
  `capture_c2 mode=identique combats=10` avec et sans `placement=oui` (écran de placement puis « Commencer » sans rien
  bouger) : identiques. Les duels n'ont pas de placement.
  3. Bilan : après une défaite ou une mort, `GameData.battle_debrief(battle)` (`report["debrief"]`) : `DEBRIEF_MIN` à
  `DEBRIEF_MAX` (3 à 5) moments clés des journaux de combat (le premier contact, puis par importance `DEBRIEF_WEIGHTS` :
  morts, agonie, secours, boss abattu, blessures graves, formations), remis dans l'ordre, racontés par le survivant qui
  a le plus vécu (« je » quand c'est lui), sans chiffres (`_plain` enlève les niveaux des causes). Aucun survivant :
  « Personne n'est revenu pour raconter ce qui s'est passé. » Fenêtre « Bilan » après les fenêtres des héros tombés.
  Banc : `tools/test_prompt3.gd` (copie du projet, avec une fenêtre ; `-- captures=<dossier>` : aperçu, placement vue
  de dessus et 3D, bilan) ; `test_tutoriel` touche « Commencer » avant le combat de l'étage 1.
- Choix du porteur du projet pour le combat : du temps réel (pas du tour par tour) où l'on voit les
  personnages bouger, utiliser le décor, et les ennemis leur foncer dessus. On vit le combat :
  jamais de bouton « passer » ni d'accélération. Le joueur soutient ses héros en les guidant
  pendant le combat (ce qui peut changer le résultat) ou les laisse se débrouiller ; plus tard, les
  consignes de la salle d'opération seront apprises peu à peu par les héros qui participent au
  combat. Vue isométrique 3D depuis C2 (avec les nouveaux visuels), la vue du dessus reste disponible.
- Prochain palier (prompt 5, point 1) : encart de l'écran Donjons (`DungeonsScreen._refresh_milestone`,
  `GameData.next_milestone`, `tower.gd`) : le prochain étage de boss et sa quête ; l'avis du Système en mots (niveau
  moyen des `TEAM_SIZE` meilleurs héros, niveau x étoiles, face aux monstres de l'étage, à `MILESTONE_READY_MARGIN` (2)
  niveaux près : « Tes héros ne sont pas prêts. » ... « Tes héros semblent prêts. ») ; des conseils (équipe incomplète,
  armes, potions pour une quête longue, défense de la cité) ; ce qu'il débloque (`MILESTONE_UNLOCKS` : le donjon
  journalier à l'étage 5 ; toujours : récompenses triplées, pierres d'attribut, palier suivant). Jamais de niveau
  chiffré. Banc : `tools/test_prompt5.gd`.
- Tour : on peut refaire un étage déjà conquis (Donjons > « Refaire un étage ») pour entraîner une
  nouvelle équipe ou l'équipe principale : récompenses baissées à la demande du porteur du projet
  (`REPLAY_XP_RATE` = moitié de l'expérience, `REPLAY_GOLD_RATE` = 20 % de l'or), pas de gemmes,
  la Tour ne monte pas. `start_tower_battle` reçoit l'étage joué. Phase 1.2 (cahier, lot A) : après le choix
  de l'étage, fenêtre « Défier de nouveau ? » avec la récompense réduite, Oui / Non (`_confirm_replay` de
  `dungeons_screen.gd`). Règle vérifiée : 20 % de l'or, aucun matériau (ni pierre d'attribut), pas de gemmes.

## Avancement : phase 2 (Tour)
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
  Simulation de la phase 1.2 et écart avec `sim_tower` : voir `docs/mesures.md` (« Tour »).
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
