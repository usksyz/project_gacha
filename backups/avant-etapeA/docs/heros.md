# Héros

Les renvois « voir … » peuvent désigner une autre partie de `docs/` ou `CLAUDE.md` (le fichier d'origine a été découpé au prompt 5, sans rien réécrire).

- Poids de la mort : `UI.make_death_window(hero, memorial)` (portrait `FramedHeroCard.HeroPortrait`, nom,
  étoiles, classe et niveau, cause, traits révélés, liens, puis « Y a perdu un ami / un frère d'armes » pour
  chaque ami ou frère d'armes vivant) remplace l'ancienne fenêtre « Un héros est tombé » des rapports de combat,
  et s'affiche pour chaque sacrifié de la synthèse. Collection > Tombés : fiche figée (`_show_memorial` de
  `collection_screen.gd` : « En mémoire », combats dans la Tour `hero["fights"]`, qui compte aussi le combat
  fatal, stats et compétences ; « Ressusciter » en mode dev).
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
- Progrès des compétences : `hero["skill_progress"]` (points par compétence) et `GameData.add_skill_progress()`
  (au seuil : apprise ou niveau suivant). Sert à l'entraînement (10 + croissance par séance, 100 par niveau)
  et à Maîtrise de l'arc (1 point par flèche tirée, 50 par niveau). Chiffres dans `GameData`.

## Avancement : phase 1 (héros et combat)
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
  Mesures (rage d'éveil) : copiées dans `docs/mesures.md` (« Héros »).
