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
