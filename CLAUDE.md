# Projet Gacha

Jeu mobile (format portrait 720x1280) fait avec **Godot 4** en **GDScript**.
Inspiré du gacha du manhwa « Pick Me Up » : invocation de héros de 1 à 5 étoiles,
héros uniques qui peuvent mourir définitivement, donjon à étages, gestion de base.
Les noms et l'univers doivent rester originaux (pas de noms issus de l'œuvre).

## Contexte
- Le porteur du projet débute en programmation de jeux (bases de Python au lycée) :
  répondre en français, expliquer simplement, garder un code lisible et commenté en français.
- Le projet est travaillé depuis un PC et depuis un téléphone (sessions Claude Code dans le cloud).
- Chaque push sur `main` publie la version web sur GitHub Pages (`.github/workflows/deploy-web.yml`).

## Structure
- `scenes/main.tscn` + `scripts/main.gd` : scène de départ ; barre du haut (gemmes),
  écran actif, barre de menus en bas (Hub, Invocation, Collection, Donjons).
- `scripts/game_data.gd` : autoload `GameData`, données et règles (taux, pity, catalogue,
  classes et statistiques, héros possédés).
- `scripts/ui.gd` : classe `UI`, fonctions communes pour créer labels, boutons, cartes de héros.
- Un script par écran (`class_name`), dont l'interface est construite par le code :
  `hub_screen.gd` (+ `hub_map.gd`, la cité circulaire dessinée), `summon_screen.gd`,
  `collection_screen.gd`, `dungeons_screen.gd`.
- Un écran peut définir `on_shown()`, appelée à chaque fois qu'il s'affiche.

## Feuille de route
1. Gacha (écran d'invocation) : fait
2. Hub (cité circulaire) + barre de menus : fait
3. Collection + fiche de héros : fait
4. Donjons : la Tour (étages), donjons journaliers (XP, ressources, or) ; combat auto, mort permanente
5. Quartiers de la cité : terrain d'entraînement, armurerie, laboratoire, synthèse...
6. Sauvegarde
