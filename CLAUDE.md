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
- `scripts/game_data.gd` : autoload `GameData`, données et règles (taux, pity, catalogue, héros possédés).
- `scenes/` + `scripts/` : une scène par écran ; l'interface est construite dans le script.

## Feuille de route
1. Gacha (écran d'invocation) : fait
2. Collection : fiche de chaque héros
3. Donjon : combat automatique, mort permanente
4. Base : bâtiments, production, améliorations
5. Sauvegarde
