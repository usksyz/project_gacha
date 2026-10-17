# Personnalité

Les renvois « voir … » peuvent désigner une autre partie de `docs/` ou `CLAUDE.md` (le fichier d'origine a été découpé au prompt 5, sans rien réécrire).

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
  Mesures de simulation (peur selon la menace) : voir `docs/mesures.md` (« Personnalité »).
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
  Fréquence des traits, simulateur de la Tour et combats avant / après P1a-bis : voir `docs/mesures.md` (« Personnalité », « Outils »).
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
- Personnalité v2, étape P2 (les effets de la personnalité ; faite sur la branche `p2-personnalite`, reprise et
  fusionnée dans `main` au prompt 2). Coefficients du cahier suivis à la lettre (choix du porteur du projet), les
  autres marqués « projet » dans les tables. Contrat inchangé : tout passe par `PersonalityEngine`.
  P2a : table `MODIFIERS` (`personality_data.gd`) et vrai `modifier()` / `modified()` (op « add », « mul », « none »,
  bornes, `with_base`) et `ACCESS_MODIFIERS` (traits majeurs et signatures qui modifient une mécanique) : peur (-3 points
  par palier de Courage), fuite, retour de la peur, désobéissance (Discipline, 50 % au plus), éveil ou effondrement en
  rupture, remontée de la santé mentale (Résilience), endurance (Constitution, Vitalité ; Infatigable, Économe, Sens
  de la limite), planchers (Inébranlable, Esprit d'acier). Remplacent Lâche x2 / Courageux /2, Loyal /2, Courageux 25 %
  d'éveil, Lâche 80 % de fuite (les traits se révèlent toujours). Mode dev : « Effets en jeu (P2) » sur la fiche.
  P2b : stress revu (`STRESS_TYPES`, `PersonalityEngine.stress`) : Stabilité, sensibilité au type d'événement,
  accoutumance (appréhension du sujet / son danger, 0,1 à 2 ; pas pour le deuil d'un ami), Roc, Sang-froid ; toutes
  les pertes de santé mentale y passent (`Battle._stress(fighter, perte, type, contexte)`).
  P2c : sujets en combat : la chance de peur x l'appréhension de l'ennemi le plus redouté à portée (`Battle._dread`) ;
  après chaque combat de la Tour, ce que chaque survivant apprend de chaque sorte de monstre (`learn_from_battle`).
  P2d : qui peut apprendre quoi (`SKILL_CONDITIONS`, conditions du catalogue réécrites sur les paliers, choix
  « recréer et adapter » ; `can_learn`, `has_affinity`) : éveils, portes de la mort, entraînement et usage ; « X stagne »
  annoncé une fois ; la synthèse et la promotion passent outre.
  P2e : Berserk et éveils selon le caractère (seuils lus au début du combat : `berserk_trigger_hp` Colère,
  `berserk_stop_hp` Prudence, `berserk_stop_mental` Maîtrise ; Increvable, Rage maîtrisée, À fleur de peau).
  P2f (prompt 2) : armes de prédilection (`PersonalityEngine.favorite_weapon` : parmi les armes que sa classe prend
  (`CLASS_WEAPONS`), celle dont l'aptitude (`persona["aptitudes"]`, `WEAPON_DOMAINS`) est d'au moins
  `PREFERENCE_MIN_APTITUDE` (4) et plus haute que les autres) : en partant en mission (`gear_up`), il la prend même
  `PREFERENCE_GRADE_TOLERANCE` (2) crans de grade sous la meilleure arme ; après `PREFERENCE_REVEAL_MISSIONS` (3)
  missions avec elle (`hero["weapon_pref_missions"]`, `note_weapon_preference`), le Maître l'a remarqué
  (`hero["weapon_pref_revealed"]`) : la fiche dit « X revient toujours à l'arc. » (`weapon_preference_text`). Mode dev :
  arme de prédilection et compteur. Les plafonds de maîtrise ne sont pas faits : le cahier (onglets Personnalité)
  n'était pas lisible pendant cette étape, à reprendre avec lui (le Persévérant 90 « Indomptable » parle de rangs de
  maîtrise, qui n'existent pas encore).
  P2g (prompt 2) : compétences exclusives (`EXCLUSIVE_SKILLS`) : l'accès du palier 50 d'un pôle (`POLE_ACCESS[...][5]`)
  réserve une compétence (`SKILL_CONDITIONS`) ; elle s'acquiert une fois par un événement de combat (noté dans
  `fighter["exclusive_events"]`, tiré à la fin du combat pour un héros debout qui a l'accès, `exclusives_for_event`,
  « chance » ; la même chance la monte d'un niveau ensuite), puis elle s'utilise (passive). Premier lot (choix tranché :
  celles dont l'événement existe déjà en combat) : Sixième sens (Acuité, après avoir été surpris), Vigilance (Méfiance,
  après avoir été surpris : `VIGILANCE_CHANCE` 30 % de voir venir une surprise), Premiers soins (Empathie, après avoir
  stabilisé un allié ou arrêté une hémorragie : secours `FIRST_AID_SPEEDUP` 30 % plus rapides, `Battle._first_aid`),
  Premier sang (Impulsivité, en portant le premier coup du combat : premier coup +`FIRST_BLOOD_BONUS` 25 %) ; Calme et
  Esprit combatif l'étaient déjà (leur propre éveil). Noms et effets des trois nouvelles : interprétés depuis
  l'identifiant (cahier illisible pendant l'étape), à confronter à l'onglet « Axes ». Les autres exclusives : P4.
  Bancs : `tools/test_p2fg.gd` (copie du projet, `-s`) ; 40 combats de l'étage 3 avec les quatre accès : environ 4
  surprises subies par combat, un premier coup par combat, 18 secours ; 22 exclusives éveillées.
  Fusion (prompt 2) : un seul conflit (`sim_tower.gd`, les deux côtés gardés) ; un bug trouvé et corrigé : le code de
  C1 appelait `PersonalityEngine.modifier("climb")`, que la vraie table ne connaissait pas (ajouté, neutre comme avant).
  Reste à faire à la fusion : rapprocher `TacticsData.PERSONALITY` (IA tactique, C3 : poids et seuils lus par `axis` et
  `composite`, hors de `modifier()`) de la table MODIFIERS (pas fait : cela changerait le comportement de main).
  Mesures avant / après la fusion de P2 (prompt 2) : voir `docs/mesures.md` (« Personnalité »).
- Une personnalité qu'on voit (prompt 4 ; feuille de route v2, phase 5.2 : première tranche de P3, en petit ;
  `personality.gd`, section « Vie de la cité » ; textes et chiffres : projet, provisoires). Le Maître ne voit jamais de
  chiffres ; en mode dev, la raison (avec les chiffres) de chaque bulle et de chaque demande. Tout passe par
  `PersonalityEngine` (`tier`, `tics`, `tic_text`, `aptitude`, `trust`, `add_trust`).
  1. Bulles (`GameData.chatter(héros, voisins)`, `CHATTER_LINES`) : plainte (Pessimisme, Vulnérabilité, santé mentale
  sous 50, rupture), bonne humeur, encouragement d'un ami ou d'un membre de son groupe (Empathie, Optimisme),
  évitement d'un hostile (il s'en va), ou un tic (« (se ronge les ongles) »). `HubCity3D._maybe_chatter` : à chaque
  pause d'un héros qui flâne, `CHATTER_CHANCE` (30 %), `CHATTER_MAX_SHOWN` (3) à la fois, `CHATTER_SECONDS` (4,5 s),
  voisins à `CHATTER_RANGE` ; bulle blanche au-dessus de la tête, gardée dans le cadre.
  2. Demandes (`update_requests`, chaque heure réelle à la cité, `REQUEST_CHANCE_PER_HOUR` 10 %, `REQUESTS_MAX` 3 en
  attente, pas pendant le tutoriel ; `roll_request`, `next_request`, `answer_request`) : « X souhaite rejoindre
  l'équipe N » (sans équipe ; Ambition, Loyauté, ou un ami dans l'équipe N qui a de la place) ; « X demande un jour de
  repos » (au travail : santé mentale sous 60, Abandon, Retenue). Carte « Demande » Oui / Non de `main.gd`
  (`_show_request`) : la confiance envers le Maître monte ou baisse de `REQUEST_TRUST` (5) ; Oui : il rejoint l'équipe,
  ou se repose `REST_SECONDS` (6 h réelles, `hero["rest_until"]`, `is_resting` : pas de séance d'entraînement, pas à la
  forge, il flâne dans la cité) avec +`REST_MENTAL` ; Non au repos : -`REFUSED_REST_MENTAL`. Sauvegardé : « demandes »,
  « demandes_maj ».
  3. Rapport de la fée (`daily_report_due`, `take_daily_report`) : une fois par jour de l'appareil, après le tutoriel,
  `REPORT_LINES_MIN` à `REPORT_LINES_MAX` (3 à 5) effets, jamais de causes (« X s'est entraîné seul toute la nuit »,
  « X et Y ne se sont pas adressé la parole », un tic...), un héros par ligne si possible, mélangés avec la graine du
  jour. Sauvegardé : « rapport_du_jour ». `main.gd._show_city_life` : rapport puis demandes, quand aucune autre
  fenêtre n'est ouverte (appelée au lancement, à la fermeture des autres fenêtres et à chaque nouvelle demande).
  4. Synthèse : avant la fenêtre rouge, fenêtre « Un détail » (« Revoir mon choix » / « Continuer ») pour chaque
  sacrifié au talent caché (`synthesis_hints` : croissance au-dessus de sa rareté → « X s'entraîne seul tous les
  soirs. » ; aptitude 5 → « X manie la lance mieux que personne. »).
  Sauvegarde version 10. Mode dev : Outils > « Vie de la cité » (« Une demande maintenant », « Rapport du jour à
  revoir »). Banc : `tools/test_prompt4.gd` (copie du projet, avec une fenêtre, `-- captures=<dossier>`).
  Reste (P3 complet) : décisions par la personnalité (`decide`), bulles en combat, autres demandes.
