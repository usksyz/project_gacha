# Économie, armes et gacha

Les renvois « voir … » peuvent désigner une autre partie de `docs/` ou `CLAUDE.md` (le fichier d'origine a été découpé au prompt 5, sans rien réécrire).

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

## Avancement : phase 3 (gacha) et économie
- Phase 3 (gacha) : invocation normale (or) et spéciale (gemmes, meilleurs taux, seule à donner des
  mages, garantie) dans `GameData.SUMMON_TYPES`, tirage d'armes, arsenal et équipement : fait.
  L'« invocation gratuite » du cahier est l'invocation normale en or (l'or est la monnaie gagnée
  en jeu, précision du porteur du projet). Raretés (choix du porteur du projet, aligné sur l'œuvre ; onglet
  « Invocations et classes » du cahier) : invocation en or de 1 à 3 étoiles, les 2 et 3 étoiles très très rares,
  sauf la première x10 du tutoriel (un 3 étoiles garanti), invocation en gemmes de 3 à 5 étoiles. Ancien réglage :
  or de 1 à 4 étoiles, gemmes de 1 à 5. Taux et économie : voir « Économie (prompt 1) » plus bas.
  Limite de héros (choix du porteur du projet) : `GameData.HERO_LIMIT` (50, provisoire, grandira avec le
  niveau des résidences) héros vivants pour invoquer ; les héros secrets s'obtiennent même plein.
  Dans chaque rareté d'étoiles, une rareté de classe (`CLASS_RATES`) : 1-2 étoiles tous Novice (ils
  changent de classe ensuite, voir « Changement de classe ») ;
  mages seulement en invocation spéciale, tirés à part du rang (`MAGE_CHANCE`, voir « Économie »).
  Bouton « Détail des taux » sur l'écran d'invocation (étoiles possibles, garantie, taux et classes).
  Les mages sont puissants mais fragiles (comme la magicienne du manhwa : Intelligence ~31, le reste 7-8 ;
  `_roll_stats`, `MAGE_STAT_MALUS`). Avoir un mage vivant permet de construire les bâtiments de magie
  (`GameData.BUILDINGS` : atelier de magie, laboratoire d'alchimie, bibliothèque ; les trois fusionnent en
  Hall de magie) : bouton « Construction » du hub (`scripts/construction_panel.gd`). Choix du porteur du
  projet : le premier, l'atelier de magie, se construit tout seul et gratuitement dès qu'un mage vivant
  rejoint les héros (`"auto": "mage"`, `GameData.check_auto_buildings()`, appelée par `save_game()`),
  avec la fenêtre « Construction terminée » et l'animation du hub 3D. Les deux autres : en gemmes, après
  l'ouverture du terrain d'entraînement. Leurs fonctions (Recherche, synthèse, savoir des mages) restent à faire.
  Reste : grades au-delà de C+, compétences de lance, dague et fouet.
- Économie (prompt 1, demande du porteur du projet : sur le modèle des gachas existants, Genshin Impact ; chiffres
  provisoires dans `summon.gd`, `tower.gd`, `lobby.gd`, `game_state.gd`). Sauvegarde version 9.
  1. Invocation normale (5 000 or) : 3 étoiles 0,7 %, 2 étoiles 2,3 %, 1 étoile 97 % (avant : 0,5 / 2 / 97,5 %), sans
  garantie ; la première x10 du tutoriel ne change pas (`_first_summon_rarities`).
  2. Invocation spéciale : 500 gemmes (cahier ; avant 100). Taux de base 5 étoiles 0,6 %, 4 étoiles 5,1 %, 3 étoiles
  94,3 % (avant 4 / 21 / 75 %). Garantie (`_roll_special_rarity`, à la place du pity de 50) : `pity_counter` = tirages
  sans 5 étoiles ; à partir du `PITY5_SOFT_START` (74e), la chance monte de `PITY5_SOFT_STEP` (6 points) par tirage
  (`five_star_chance`), sûr au `PITY5_LIMIT` (90e) ; `pity4_counter` = sans 4 étoiles ou mieux, sûr au `PITY4_LIMIT`
  (10e). Les deux sont sauvegardés (« pity », « pity4 ») et continuent d'une x1 à une x10. Mages : `MAGE_CHANCE`
  (0,5 %) des tirages spéciaux, tirés à part du rang (`_roll_class`), jamais forcés par la garantie ; ils ne sont
  plus dans `CLASS_RATES` (les lignes sont remises à 100 %, donc l'invocation normale ne change pas). Ancienne
  sauvegarde : son pity est gardé, borné à 89 ; le compteur des 4 étoiles part de 0.
  3. « Détail des taux » : taux de base, règle de la garantie, taux réel du 5 étoiles (`five_star_real_rate`, calculé :
  1,6 %, un tous les 62 tirages), compteurs du joueur ; en haut de l'écran : « 5 étoiles garanti dans N tirages ».
  4. Banc `tools/test_summon.gd` : résultats dans `docs/mesures.md` (« Économie »).
  5. Gemmes : partie neuve `START_GEMS` (500, une invocation spéciale ; avant 3 000 ; une partie en cours garde les
  siennes). Étage conquis la première fois : `TOWER_GEMS_BASE` + `TOWER_GEMS_PER_FLOOR` x étage (100 + 20 x étage,
  étage 1 : 120), x3 sur un étage de boss (étage 5 : 600) ; rien en rejouant (avant : 30 + 5 x étage).
  Attention : la forge coûte aussi 500 gemmes : avec 500 gemmes au départ, le Maître choisit.
  6. Invocation gratuite quotidienne : une invocation normale x1 par jour de l'appareil (`free_summon`,
  `free_summon_available`, `today_date` ; date dans `free_summon_day`, sauvegardée « invocation_gratuite »), bouton
  « Invocation gratuite (une par jour) » de l'écran d'invocation tant qu'elle n'est pas prise ; pas pendant le
  tutoriel ; limite de héros respectée. Mode dev : Outils > « Rendre l'invocation gratuite » (`dev_reset_free_summon`).
  7. Potion de soin : forge, « Préparer une potion de soin » (`POTION_RECIPE` : 3 herbes médicinales de la Forêt
  Kenout, de n'importe quel grade, les plus faibles d'abord ; `brew_potion`), sans puzzle ni tirage, grade F.
  8. Vente (`lobby.gd`, section « Vente ») : les poubelles (`JUNK_NAME`) vont maintenant dans l'entrepôt (avant :
  jetées) ; bouton « Vendre » (`UI.make_sale_section`, fenêtre de confirmation Oui / Non) dans l'armurerie et sous
  l'entrepôt de la forge : `JUNK_SELL_PRICE` (200 or) par poubelle, `WEAPON_F_SELL_PRICE` (500 or) par arme F rangée
  (jamais une arme portée) ; pas pendant le tutoriel (`can_sell`).
  Vérification en mode normal : `tools/test_economie.gd` (copie du projet ; il recommence la partie ; avec une
  fenêtre, `-- captures=<dossier>` : détail des taux, armurerie, forge). `tools/check_scripts.gd` : compile tous les
  scripts avec les autoloads (`--check-only` ne les connaît pas).
- Étape B, forge à 500 gemmes avec 500 gemmes au départ : gardé (prix du cahier, et 500 gemmes de départ demandées au
  prompt 1). Les étages 1 à 4 rapportent 600 gemmes : la forge vient après quelques étages, ou une invocation spéciale
  avant ; c'est un choix du Maître (à revoir avec le porteur du projet s'il le trouve frustrant).
- Gemmes hors de la Tour (octobre 2026, analyse du projet : avant, presque toutes les gemmes venaient des étages, et un
  joueur bloqué à un étage n'avait plus rien pour invoquer). Ajouts du projet, chiffres provisoires :
  - Missions du jour (`game_state.gd`, section « Missions du jour » : `DAILY_MISSIONS`, `complete_daily_mission`) :
    faire un combat dans la Tour (victoire ou défaite), une invocation (ou un tirage d'armes), envoyer un héros
    s'entraîner ; 60 gemmes chacune, 120 de plus quand les trois sont faites. Une fois par jour (date de l'appareil,
    `daily_missions` enregistré sous « missions_du_jour »), rien pendant le tutoriel. Fenêtre du Système à chaque
    mission (signal `system_notice`, affiché par `main.gd`) ; liste sur l'écran d'invocation. Mode dev : « Missions du
    jour à refaire ».
  - Expéditions (`lobby.gd`) : chaque expédition rapporte `EXPEDITION_GEMS` (40) gemmes, dites dans le rapport.
  Au plus 300 gemmes par jour par les missions (une invocation simple coûte 100 gemmes).
