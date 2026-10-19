# Mesures et outils de simulation

Les mesures de chaque étape (avant / après), recopiées de l'ancien `CLAUDE.md` sans changement. Commandes : dans une copie du projet (worktree + `override.cfg` sans BOM, voir `CLAUDE.md`). Les règles et réglages eux-mêmes sont dans les fichiers de chaque système.

## Outils
- Simulateur de la Tour (étape P1a-bis) :
  Simulateur de la Tour : `tools/sim_tower.tscn` (voir l'en-tête de `tools/sim_tower.gd`), victoires selon chaque
  trait présent dans l'équipe ; options `niveau=` (niveau imposé) et `meneur=avec|sans|libre` (étape 0 avant P1b).
  Chaque lancement relit et réécrit `user://sauvegarde.cfg` : le lancer dans une copie du projet (worktree git)
  avec un `override.cfg` (`[application]` `config/use_custom_user_dir=true`, `config/custom_user_dir_name="..."`),
  jamais dans le dépôt.

## Personnalité
- Peur selon la menace (feuille de route v2, phase 0) :
  Simulation (sans ordres, équipe 3★ + 2★ + 3 x 1★ au niveau de l'étage, 150 combats) : peurs par 1 étoile
  novice ~0,5 par combat comme avant ; 3 étoiles ~0 sauf horde et boss de l'étage 5 (0,4, 0,2 avec 10 combats
  d'expérience) ; victoires étage 1 : 99 % ; étages 2 à 4 : 19-30 % (avant ce changement : 24-34 %).
- Fréquence des traits (P1a-bis) :
  Fréquence des traits (banc, 40 000 héros par rareté, seuils ±40 du Courage), avant → après : chaque trait
  15-16 % → Courageux 4,9 / 5,6 / 6,9 / 8,7 / 10 % (1★ → 5★ ; à ±50 : 1-4 %), Lâche 4,8-5,7 % (à ±50 : 1-2 %),
  Loyal 10-15 %, Paresseux 9-14 %, Querelleur 7-9 %, Protecteur 3-6 %, Ambitieux 9-15 %, Mauvais 5-7 %, Meneur
  2-4 % ; traits par héros 1,4 → 0,54 (1★) à 0,87 (5★) ; héros sans trait 40 (5★) à 56 % (1★).
- Combats avant / après P1a-bis :
  Combats (sans ordres ni potions, 1 000 par étage, graine 7 ; « brute » : 3★ + 2★ + 3 x 1★ au niveau des
  monstres ; « préparée » : 2 niveaux de plus, épée et bouclier ou arc D), avant (a113856) → après : brute étages
  1 à 5 : 99,9 / 64,6 / 53,7 / 54 / 26,3 % → 99,7 / 68,9 / 53,8 / 54,1 / 27 % ; préparée : 100 / 98,6 / 94,9 /
  95,6 / 44,1 % → 100 / 98,7 / 96 / 95,3 / 66,8 %. Écart : préparée étage 5, +23 points. Cause : l'ancien
  Meneur en survie (avec Meneur 18-20 %, sans 73-74 %) ; avant, 55 % des équipes avaient un Meneur, maintenant
  12 %. Avec `_organize_defense` coupé : 73 % avant, 73,6 % après. Corrigé à l'étape 0 (voir « Meneur en survie »).
- Fusion de P2 (prompt 2) :
  Mesures avant / après la fusion (prompt 2 ; avant = `main` 23934d8, après = c976f47 : P2a à P2e et la correction ;
  P2f et P2g ne jouent pas dans `sim_tower`, qui donne les armes à la main et refait ses héros à chaque combat). Bancs :
  `test_personality` 125 contrôles bons → 162 bons (contrôles P2 en plus), `test_combat_v2` bon avant et après.
  `sim_tower ... combats=300 equipe=brute|preparee graine=7`, un étage par lancement, 12 en parallèle. Victoires %
  (morts par combat) avant → après ; après : peurs et ruptures par combat :
  brute étages 1 / 2 / 3 / 4 / 5 / 10 : 99,7 (0,17) / 49,3 (2,83) / 36 (3,35) / 38,3 (3,28) / 28 (2,76) / 19 (3,77) →
  100 (0,11) / 52 (2,63) / 42,3 (3,12) / 40 (3,18) / 31 (2,61) / 18 (3,48) ; peurs 0,78 / 1,05 / 1,15 / 1,09 / 2,78 /
  3,37, ruptures 0 à 0,17 ;
  préparée : 100 (0) / 90,7 (0,66) / 89,7 (0,94) / 87,3 (1,05) / 59,7 (1,82) / 35 (2,97) → 100 (0,01) / 91,7 (0,64) /
  83 (1,06) / 79,3 (1,31) / 59,3 (1,76) / 35,3 (3,24) ; peurs 0,79 / 0,93 / 1 / 1,02 / 2,83 / 3,44.
  Plus gros écarts : préparée étages 3 et 4, -6,7 et -8 points (environ 3 écarts-types sur 300 combats : réel) ; brute
  étage 3, +6,3. Pas de rééquilibrage (coefficients du cahier gardés, choix du porteur du projet). Temps de calcul :
  +2 à +5 %.

## Combat v2
- C1 :
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
- C2, performance :
  Mesuré sur PC (Radeon RX 6700 XT, synchro écran coupée), étage 5 : vue 3D 1 680 images/s, 1,4 ms de calcul par
  image, 94 appels de dessin ; vue de dessus 340 images/s, 3,8 ms, 247 appels (elle redessine chaque case à chaque
  image). Pas encore mesuré sur téléphone.

## Phase 1.1
- Meneur en survie (étape 0 avant P1b) :
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
- Meneur en survie, toits de C1 (copie ; la règle reste dans `docs/combat.md`) :
  restent et tirent). Simulation sur les cartes de C1, étage 5, préparée, sans ordres, graines 31 à 33, 3 x 300
  combats (`sim_tower ... etages=5 combats=300 equipe=preparee meneur=sans|avec meneur_toit=non|oui graine=31`) :
  sans Meneur 64,7 / 67,0 / 66,3 % (2,60 morts par combat) ; P5 65,3 / 67,3 / 64,7 % (2,46) ; P5 + toits
  69,3 / 71,0 / 74,3 % (2,15). Plus haut que les anciennes hauteurs (2 niveaux contre 1), les tireurs y gagnent.
- Agonie :
  Simulation après ces réglages (200 à 600 combats, sans ordres) : équipe neuve étage 1 : 96 % de victoires,
  1,15 mort par combat (cible du porteur du projet : 0,5 à 1 ; 0,36 arme plantée et 0,45 stabilisé par
  combat) ; étages 2 à 4 : 19 / 7 / 8 %, 4,1-4,6 morts. « Préparée » étages 1 à 4 : 100 / 95 / 84 / 83 %, morts
  0 / 0,9 / 1,7 / 1,8.
  Simulation (équipe neuve « brute ») : morts à l'étage 1 de 1,5 à 0,1 par combat ; étages 2 à 4 de 4,4-4,8 à
  2,5-3 ; victoires à peu près inchangées (étage 1 : 98 %, étages 2 à 4 : 14-23 %). « Préparée » : morts de
  1-2 à 0,4-0,9 aux étages 2 à 4, victoires 90-98 %.
- Les quatre points de la phase 1.1 :
  Simulation des quatre points (200 combats par étage, sans ordres, étages 1 à 5) — avant → après :
  équipe neuve (« brute ») victoires 99 / 22 / 9 / 11 / 0 % → 96 / 23 / 13 / 9 / 0 %, morts par combat
  1,45 / 4,39 / 4,81 / 4,75 / 5 → 0,19 / 2,6 / 2,97 / 3,1 / 3,9 ; « préparée » (2 niveaux de plus, épée et
  bouclier ou arc D) victoires 100 / 100 / 97 / 96 / 6 % → 100 / 96 / 89 / 90 / 7 %, morts 0 / 1 / 1,8 / 1,6 /
  4,9 → 0 / 0,4 / 0,7 / 0,9 / 2,9. L'agonie divise les morts par deux environ (étage 1 : presque plus de morts).

## Héros
- Rage d'éveil (copie ; la règle reste dans `docs/heros.md`) :
  x`AWAKENING_MIGRAINE_FACTOR` (2, donc 6 min). Simulation (200 combats par étage, sans ordres) : héros qui
  survivent au combat où ils apprennent Berserk, avant → après : équipe neuve étage 1 : 42 → 92-95 %, étages
  2 à 4 : 6-10 → 25-36 % ; préparée étages 2 à 4 : 34-46 → 56-78 %. Effet de bord : la rage d'éveil fait
  aussi gagner l'équipe (équipe neuve, étages 2 à 4 : 7-17 → 20-37 % de victoires).

## Tour
- Tension à chaque étage (copie ; la règle reste dans `docs/combat.md`) :
  Étages 5 et plus : formule inchangée. Simulation, sans ordres, équipe du tutoriel au niveau de l'étage
  (« brute ») ou 2 niveaux de plus avec épée et bouclier, ou arc, de grade D (« préparée ») :
  étage 1 brute 99 % de victoires, ~1 mort ; étages 2 à 4 brute 44-57 % (~3,5 morts), préparée 94-97 %
  (~1 mort), 2 niveaux de plus sans armes 72-81 % ; étages 6 et 8 brute 34-40 %, préparée 90 % ; étage 5
  (survie, boss) brute 5 %, préparée 47 % ; étage 10 (défense) brute 28 %, préparée 49 %. À refaire après
  tout changement d'équilibre.
- Phase 1.2 et écart avec `sim_tower` :
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

## Économie
- Banc `tools/test_summon.gd` (prompt 1) :
  4. Banc `tools/test_summon.gd` (dans une copie, `-s`) : 1 000 000 de tirages par sorte. Résultat : normale 0,699 /
  2,277 / 97,02 % ; spéciale 5★ 1,60 %, 4★ 11,8 % (13,4 % « 4★ ou mieux »), 3★ 86,6 %, 62,5 tirages par 5★, mages
  0,49 %, séries au plus 86 sans 5★ et 10 sans 4★.

## Étape A (notes du porteur du projet : stabilisé qui reprend le combat, agonie soignée en fin d'étage)
- `sim_tower ... combats=300 graine=7` avant (5c623c0) → après (2f53f35), victoires % (morts par combat) :
  brute étages 1 / 2 / 3 / 4 / 5 / 10 : 99,7 (0,18) / 48,7 (2,79) / 38 (3,29) / 41,3 (3,19) / 30,7 (2,66) / 18 (3,76) →
  100 (0,09) / 54,3 (2,60) / 42,7 (3,23) / 35,3 (3,49) / 34,7 (3,54) / 20,7 (3,77) ;
  préparée : 100 (0) / 90,7 (0,76) / 81,3 (1,13) / 85,3 (0,98) / 63 (1,68) / 40 (2,87) →
  100 (0) / 90 (0,75) / 86 (1,02) / 84,7 (1,07) / 64 (2,20) / 40,7 (2,97).
  Victoires : dans le bruit (±4 points sur 300 combats). Morts à l'étage 5 en hausse (brute +0,9, préparée +0,5) :
  un héros stabilisé reprend le combat avec 10 % de sa vie et peut retomber (avant, il était à l'abri).
- Tutoriel, étage 1 (`tools/sim_tutoriel.gd`, vrai déroulé, 150 parties) : 100 % de victoires avant comme après.

## Étape B : baisse des équipes préparées aux étages 3 et 4 après P2
- `sim_tower ... etages=3|4 combats=600 equipe=preparee graine=7|8 personnalite=oui|non` (`personnalite=non` : effets de P2 neutres,
  `PersonalityEngine.effects_on`), 1 200 combats par cas : avec les effets 86,3 / 85,3 % (étage 3) et 85,2 / 85,3 % (étage 4) ;
  sans 83,7 / 85,5 % et 85,3 / 80,7 %. Les effets de la personnalité ne font pas baisser l'équipe préparée (plutôt +1,5
  point). Avant P2 (prompt 2, 300 combats) : 89,7 / 87,3 % ; l'écart restant (environ 3 points) est proche du bruit des
  séries de 300 combats (±3,5) ; les « -7 / -8 points » du prompt 2 en étaient en partie. Pas de rééquilibrage.

## Étape E, points 1 et 2 (vigilance des monstres, dispositions selon la mission, exploration des héros)
- `sim_tower ... combats=300 graine=7` avant (eee5e49) → après, victoires % (morts par combat) :
  brute étages 1 / 2 / 3 / 4 / 5 / 10 : 100 (0,09) / 54,3 (2,60) / 42,7 (3,23) / 35,3 (3,49) / 34,7 (3,54) / 20,7 (3,77) →
  100 (0,21) / 54,3 (2,70) / 34,3 (3,61) / 37 (3,54) / 34,7 (3,54) / 20,7 (3,77) ;
  préparée : 100 (0) / 90 (0,75) / 86 (1,02) / 84,7 (1,07) / 64 (2,20) / 40,7 (2,97) →
  100 (0,03) / 90,3 (0,75) / 79,3 (1,41) / 81 (1,26) / 64 (2,20) / 40,7 (2,97).
  Étages 5 (survie) et 10 (défense) : identiques au combat près (horde, rien ne change). Par disposition (après) :
  étage 2 brute patrouilles 58,3 %, embuscade 50 % ; préparée 90,7 / 90 %. Étages 3 et 4 brute : patrouilles 43-48 %,
  endormis 38-41 %, camp 31-38 % (alarme générale dans 46 % des combats), poste 21-24 % ; préparée : 75 à 84 % partout
  (camp le plus dur). Durée moyenne : 19 à 37 s (avant : le combat commençait par l'attente des monstres).
  Cause de la baisse de l'étage 3 : les héros attaquent maintenant des monstres groupés (camp, poste en hauteur),
  alors qu'avant les monstres arrivaient en file sur leur ligne. Le ralliement (« se placer, puis attaquer ») a déjà
  repris 3 à 4 points ; l'infiltration et l'assassinat (point 3) doivent rendre l'avantage à une équipe discrète.
  Pas de rééquilibrage des monstres.
- Défauts trouvés pendant les mesures et corrigés avant le commit : rondes à deux points trop proches (allers-retours sur
  place : 80 « bloqués sans raison » à l'étage 1) ; compte à rebours forcé juste avant l'alarme (qui ne sonnait jamais) ;
  ralliement qui restait en place quand les monstres repérés s'éloignaient ; but d'exploration sur un toit jamais « vu »
  d'en bas (l'équipe l'attendait : 3 défaites au temps sur 80 à l'étage 1). Après : 0 défaite sur 150 (`trace_e`).
- Tutoriel, étage 1 (`tools/sim_tutoriel.gd`, vrai déroulé, 200 parties) : 98,5 % de victoires (avant : 100 % sur 150),
  0,33 mort par combat ; jamais 6 défaites de suite. `test_tutoriel` : victoire au premier essai.

## Étape E, point 3 (infiltration, assassinat, pièges)
- `sim_tower ... combats=300 graine=7`, après les points 1 et 2 → après le point 3, victoires % (morts par combat) :
  brute étages 1 / 2 / 3 / 4 / 5 : 100 (0,21) / 54,3 (2,70) / 34,3 (3,61) / 37 (3,54) / 34,7 (3,54) →
  98,7 (0,29) / 53,7 (2,69) / 37,3 (3,49) / 37,3 (3,49) / 34,7 (3,54) ;
  préparée : 100 (0,03) / 90,3 (0,75) / 79,3 (1,41) / 81 (1,26) / 64 (2,20) → 100 (0,05) / 90 (0,85) / 83 (1,15) /
  83,7 (1,16) / 64 (2,20). Avant l'étape E (préparée) : 100 / 90 / 86 / 84,7 / 64. Étage 5 identique (horde).
  Par combat : assassinats 0,07 à 0,17 (étages 1 et 2), 0,43 à 0,49 (étages 3 et 4) ; pièges posés 0,05 à 0,11,
  déclenchés 0,00 à 0,03 (rares : il faut un poseur, un ralliement assez long, et que le monstre passe dessus).
  Étage 1 brute : 4 défaites sur 300 (équipes balayées, pas de blocage : `trace_e pertes=200`, 0 défaite).
- Essai de pièges en survie (retiré) : étage 5, 300 combats, brute 34,7 → 27,7 %, préparée 64 → 62,3 %, 0 piège posé.
- Tutoriel, étage 1 (`sim_tutoriel`, 200 parties) : 98 % (points 1 et 2 : 98,5 %).

## Étape E, point 4 (liens et caractère en combat)
- `sim_tower ... combats=300 graine=7`, après le point 3 → après le point 4, victoires % (morts par combat) :
  brute étages 1 / 2 / 3 / 4 / 5 / 10 : 98,7 (0,29) / 53,7 (2,69) / 37,3 (3,49) / 37,3 (3,49) / 34,7 (3,54) / 20,7 (3,77) →
  99,7 (0,21) / 59 (2,47) / 42,3 (3,22) / 42,3 (3,25) / 31,3 (3,67) / 14,7 (3,86) ;
  préparée : 100 (0,05) / 90 (0,85) / 83 (1,15) / 83,7 (1,16) / 64 (2,20) / 40,7 (2,97) →
  99,7 (0,03) / 90,3 (0,75) / 84,7 (1,11) / 77,7 (1,43) / 67,7 (2,10) / 39 (3,12).
  Par combat : coups à revers 2,4 à 7,8 ; appât (un opportuniste, une fois par paire) 0,6 à 1,1 ; ami couvert 0,01 à
  0,22 ; abandon 0,01 à 0,16 (plus aux étages 5 et 10, où l'on est souvent en danger). Les écarts restent près du bruit
  des séries de 300 combats (environ ±4 points) ; le plus grand : étage 10 brute -6, préparée étage 4 -6 (les
  abandons et les opportunistes qui quittent leur place coûtent, les coups à revers rapportent). Pas de rééquilibrage.
- Tutoriel, étage 1 (`sim_tutoriel`, 200 parties) : 97,5 % (point 3 : 98 %) ; `test_tutoriel` : victoire au premier essai.
- Bilan de l'étape E, préparée, étages 1 à 5 et 10 : avant (eee5e49) 100 / 90 / 86 / 84,7 / 64 / 40,7 → après
  99,7 / 90,3 / 84,7 / 77,7 / 67,7 / 39 ; brute 100 / 54,3 / 42,7 / 35,3 / 34,7 / 20,7 → 99,7 / 59 / 42,3 / 42,3 / 31,3 / 14,7.
## Techniques (recensement « Techniques de programmation pour le combat »), points 1 à 3
- `sim_tower ... combats=300 graine=7`, étages 1 à 4 (5 et 10 : horde, rien ne change), victoires % (morts par combat).
  Avant (d73cf63, identique aux mesures du point 4 de l'étape E : le simulateur est bien déterministe) → après le point 1
  (jauge de détection) → point 2 (corps, disparus, son) → point 3 (chemins discrets) :
  brute : 99,7 (0,21) / 59 (2,47) / 42,3 (3,22) / 42,3 (3,25) → 99,7 (0,19) / 55 (2,63) / 44 (3,14) / 41,3 (3,23) →
  99,7 (0,19) / 56 (2,59) / 43,3 (3,16) / 42,7 (3,25) → 99,7 (0,16) / 56,7 (2,47) / 40,3 (3,24) / 42,7 (3,14) ;
  préparée : 99,7 (0,03) / 90,3 (0,75) / 84,7 (1,11) / 77,7 (1,43) → 100 (0,03) / 92,7 (0,60) / 86,7 (0,99) / 85,7 (1,07) →
  100 (0,04) / 93 (0,61) / 86 (1,01) / 84,3 (1,14) → 100 (0,03) / 93 (0,57) / 82,7 (1,14) / 84,3 (1,10).
  Écarts dans le bruit des séries de 300 combats (environ ±4 points), sauf préparée étage 4 : +6,6 (la jauge laisse le
  temps de se figer et de finir le ralliement). Pas de rééquilibrage.
- Par combat (après le point 3) : monstres méfiants 0,65 à 1,66 ; héros figés à temps 0,16 à 0,58 ; fausses alertes
  0,01 à 0,04 (un monstre méfiant finit presque toujours par voir l'équipe : elle avance encore) ; corps découverts 0,19
  à 0,35 (étages 1 et 2), 0,69 à 0,90 (étages 3 et 4) ; compagnons disparus remarqués 0 à 0,06 ; assassinats 0,14 à 0,56
  (avant : 0,11 à 0,53).
- Unités « bloquées sans raison » : 0 à 4 par série avant, jusqu'à 7 (étage 2 brute) au point 1, 0 à 2 au point 3 (des
  loups qui hésitent entre deux cases, pas de blocage durable).
- Tutoriel, étage 1 (`sim_tutoriel`, 200 parties) : 99 % (avant : 97,5 %). `capture_c2 mode=identique` : identique.
- Point 4 (annotation tactique : pièges dans un goulet, ralliement à couvert), après le point 3 → après le point 4 :
  brute 99,7 / 56,7 / 40,3 / 42,7 → 99,7 (0,17) / 56 (2,51) / 38 (3,40) / 45,3 (3,04) ; préparée 100 / 93 / 82,7 / 84,3 →
  100 (0,04) / 92,7 (0,63) / 84,7 (1,09) / 83,7 (1,08). Dans le bruit. Pièges posés 0,06 à 0,15 par combat, déclenchés
  0,00 à 0,05 (avant : 0,08 à 0,14 et 0,01 à 0,04). Étage 3, graine 21 : 3 goulets, 18 points hauts, 44 cachettes.
  Tutoriel (`sim_tutoriel`, 200 parties) : 99 %.
- Point 5 (recherche intelligente, carte de fuite), après le point 4 → après le point 5 (étages 5 et 10 : avant = d73cf63,
  le point 5 est le premier à les toucher, par la carte de fuite) :
  brute 99,7 / 56 / 38 / 45,3 / 31,3 / 14,7 → 99,3 (0,18) / 51,7 (2,70) / 40,3 (3,24) / 47,7 (2,99) / 39,3 (3,34) / 20,7 (3,69) ;
  préparée 100 / 92,7 / 84,7 / 83,7 / 67,7 / 39 → 100 (0,04) / 91,7 (0,68) / 86,7 (0,97) / 84,7 (1,09) / 73 (1,84) / 39,7 (2,99).
  Étages 1 à 4 dans le bruit. Étage 5 : +8 (brute) et +5,3 (préparée), « bloqués sans raison » 32 → 0 (brute) : les
  héros en fuite ne s'entassent plus au bas de la carte, ils s'éloignent des monstres. Par combat : la carte se resserre
  sur un héros vu 20 à 46 fois, 0,1 à 4,7 cases fouillées. Tutoriel (`sim_tutoriel`, 200 parties) : 99,5 %.

## Cartes, étapes 2 et 3 (cartes rondes 24 x 26, nouveau générateur)
- `sim_tower ... combats=300 graine=7`, après le point 5 du recensement « Techniques » (cartes 18 x 20) → nouvelles cartes,
  victoires % (morts par combat), étages 1 / 2 / 3 / 4 / 5 / 10 :
  brute 99,3 / 51,7 / 40,3 / 47,7 / 39,3 / 20,7 → 100 (0,31) / 58,3 (2,54) / 40,3 (3,30) / 42,3 (3,18) / 38,7 (3,38) / 19,3 (3,93) ;
  préparée 100 / 91,7 / 86,7 / 84,7 / 73 / 39,7 → 100 (0,06) / 92 (0,67) / 85,3 (1,06) / 83,3 (1,20) / 69,3 (1,92) / 48,3 (3,11).
  Pas d'isolement des héros (la crainte d'un essai précédent) : tout reste dans le bruit (±4 points), sauf la défense
  préparée, +8,6 (la horde vient de plus loin). Durée moyenne : 27 à 44 s hors survie (avant : 19 à 37 s). Par lieu,
  étages 3 et 4 : camp 33 à 81 % (alarme générale 74 à 87 %), endormis 34 à 91 %, poste 33 à 81 %, patrouilles 50 à 88 %.
  « Bloqués sans raison » : 0 à 2 par série, sauf l'étage 5 brute (25, tous dans un même combat : une héroïne qui hésite
  entre deux chemins pendant quelques secondes).
- Génération : 40 graines par lieu, toutes valides du premier coup (aucune carte plate de secours) ; 13 à 22 ms par carte ;
  village : 6,2 maisons en moyenne ; forêt : 95 arbres en moyenne (`test_cartes`, `essai_cartes`).
- Tutoriel (`sim_tutoriel`, 200 parties) : 98,5 % (avant : 99,5 %). `capture_c2 mode=identique` : identique ;
  `test_prompt3` : tout est bon.

## Techniques, points 6 à 10 (sur les nouvelles cartes)
- `sim_tower ... combats=300 graine=7`, victoires % (morts par combat), étages 1 / 2 / 3 / 4 (et 5 / 10 quand ils changent).
  Cartes, étape 2 (référence) : brute 100 / 58,3 / 40,3 / 42,3 ; préparée 100 / 92 / 85,3 / 83,3 ; étages 5 / 10 : brute
  38,7 / 19,3, préparée 69,3 / 48,3.
- Point 6 (contournement, assassinats synchronisés) : brute 100 (0,29) / 56 (2,66) / 39,3 (3,29) / 36,7 (3,47) ; préparée
  100 (0,07) / 93,7 (0,71) / 83 (1,15) / 81,3 (1,33). Étage 4 brute -5,6, un peu au-delà du bruit (les monstres qui
  contournent frappent à revers) ; le reste dans le bruit. Assassinats synchronisés : 0 (les équipes du simulateur sont
  neuves, sans amis ; le banc vérifie la mécanique).
- Point 7, première version (formations + bond d'abri en abri + place contre un abri) : brute 86,3 (0,59) / 50,7 / 29,3 /
  35 ; préparée 90,7 (0,18) / 85,7 / 72,7 / 71,3 ; combats de 40 à 60 s ; tutoriel 83 %. Variantes, étages 1 et 3, 150
  combats : sans le bond, brute 98,7 / 30,7, préparée 100 / 78 ; sans le bond ni la place contre un abri, brute 98,7 /
  42, préparée 99,3 / 80,7. Retenu : les formations seules (bond et place coupés, `BOUND_ON`, `COVER_SNAP`).
- Points 7 (corrigé) et 8 (camps et nuit) : brute 99,3 (0,33) / 52,7 (2,82) / 43,3 (3,07) / 43 (3,09) / 38,7 / 19,3 ;
  préparée 99,7 (0,09) / 92,3 (0,72) / 87 (0,99) / 83,7 (1,14) / 69,3 / 48,3. Étages 5 et 10 identiques à la référence
  (horde : rien ne change). Tutoriel : 99 %.
- Point 9 (le combat a sa propre graine, re-semée à chaque pas : les tirages changent, pas les règles) : brute 99 (0,29) /
  59 (2,51) / 42 (3,20) / 45,3 (3,00) / 36,7 (3,43) / 25,7 (3,93) ; préparée 100 (0,05) / 92,3 (0,69) / 81 (1,27) / 82
  (1,18) / 67,7 (2,06) / 49,7 (2,92). Dans le bruit. Tutoriel : 99 %. `capture_c2 mode=identique` : identique.
- Point 10 (la tension, mesurée) : ne tire aucun dé, ne change rien (mêmes combats qu'au point 9).
