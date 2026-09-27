extends Node
## Données et règles du gacha.
## Ce script est chargé automatiquement au lancement (« autoload ») :
## n'importe quel autre script peut y accéder en écrivant GameData.

signal gems_changed(new_amount: int)

## Prix d'une invocation, en gemmes.
const SUMMON_COST := 100

## Pity : un héros 5 étoiles est garanti au bout de ce nombre d'invocations sans 5 étoiles.
const PITY_LIMIT := 50

## Probabilité d'obtenir chaque rareté (le total fait 1.0, soit 100 %).
const RARITY_RATES := {
	5: 0.02,
	4: 0.08,
	3: 0.20,
	2: 0.30,
	1: 0.40,
}

## Couleur associée à chaque rareté.
const RARITY_COLORS := {
	5: Color("f5b82e"),
	4: Color("a35ce0"),
	3: Color("3d8fe0"),
	2: Color("4caf6a"),
	1: Color("8a8f98"),
}

## Niveau maximum que peut atteindre un héros, selon sa rareté.
const MAX_LEVEL := {
	5: 60,
	4: 50,
	3: 40,
	2: 30,
	1: 20,
}

## Statistiques de base de chaque classe, pour un héros 1 étoile de niveau 1.
## hp = points de vie, atk = attaque, def = défense, spd = vitesse.
const CLASS_STATS := {
	"Guerrier": {"hp": 120, "atk": 20, "def": 12, "spd": 10},
	"Chevalier": {"hp": 160, "atk": 12, "def": 20, "spd": 7},
	"Mage": {"hp": 80, "atk": 26, "def": 6, "spd": 9},
	"Archer": {"hp": 90, "atk": 22, "def": 8, "spd": 12},
	"Assassin": {"hp": 85, "atk": 24, "def": 7, "spd": 15},
	"Soigneur": {"hp": 95, "atk": 10, "def": 10, "spd": 11},
}

## Bonus de statistiques par étoile au-dessus de 1 (0.3 = +30 % par étoile).
const STATS_BONUS_PER_STAR := 0.3

## Catalogue des héros qu'on peut invoquer.
const HERO_POOL := [
	{"name": "Aldric", "rarity": 5, "class": "Guerrier"},
	{"name": "Séléné", "rarity": 5, "class": "Mage"},
	{"name": "Kaelen", "rarity": 5, "class": "Archer"},
	{"name": "Brunhild", "rarity": 4, "class": "Chevalier"},
	{"name": "Oriane", "rarity": 4, "class": "Soigneur"},
	{"name": "Vesper", "rarity": 4, "class": "Assassin"},
	{"name": "Garrick", "rarity": 3, "class": "Chevalier"},
	{"name": "Lysa", "rarity": 3, "class": "Archer"},
	{"name": "Tobias", "rarity": 3, "class": "Mage"},
	{"name": "Mira", "rarity": 2, "class": "Soigneur"},
	{"name": "Doran", "rarity": 2, "class": "Guerrier"},
	{"name": "Pip", "rarity": 2, "class": "Assassin"},
	{"name": "Hugo", "rarity": 1, "class": "Guerrier"},
	{"name": "Léna", "rarity": 1, "class": "Mage"},
	{"name": "Bram", "rarity": 1, "class": "Chevalier"},
]

var gems := 3000
var pity_counter := 0

## Tous les héros invoqués. Chaque invocation crée un héros unique :
## deux « Aldric » sont deux individus différents, avec leurs propres statistiques
## (ils pourront mourir séparément).
var roster: Array[Dictionary] = []

## Numéro donné au prochain héros invoqué (chaque héros a un numéro unique).
var next_hero_id := 1


func can_afford(count: int) -> bool:
	return gems >= SUMMON_COST * count


## Invoque « count » héros et renvoie la liste des héros obtenus
## (liste vide si on n'a pas assez de gemmes).
func summon(count: int) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not can_afford(count):
		return results

	gems -= SUMMON_COST * count
	for i in count:
		var hero := _create_hero(_roll_rarity())
		roster.append(hero)
		results.append(hero)
	gems_changed.emit(gems)
	return results


func add_gems(amount: int) -> void:
	gems += amount
	gems_changed.emit(gems)


func summons_before_pity() -> int:
	return PITY_LIMIT - pity_counter


## Tire une rareté au hasard selon RARITY_RATES, en tenant compte du pity.
func _roll_rarity() -> int:
	pity_counter += 1
	if pity_counter >= PITY_LIMIT:
		pity_counter = 0
		return 5

	var roll := randf()
	var cumulative := 0.0
	for rarity in RARITY_RATES:
		cumulative += RARITY_RATES[rarity]
		if roll < cumulative:
			if rarity == 5:
				pity_counter = 0
			return rarity
	return 1


## Crée un nouveau héros de la rareté donnée, choisi au hasard dans le catalogue.
func _create_hero(rarity: int) -> Dictionary:
	var candidates := HERO_POOL.filter(func(h): return h["rarity"] == rarity)
	var template: Dictionary = candidates.pick_random()
	var hero := {
		"id": next_hero_id,
		"name": template["name"],
		"rarity": rarity,
		"class": template["class"],
		"level": 1,
		"alive": true,
		"stats": _roll_stats(template["class"], rarity),
	}
	next_hero_id += 1
	return hero


## Calcule les statistiques d'un nouveau héros : base de sa classe, bonus de rareté,
## et une petite variation au hasard (±10 %) pour que chaque individu soit unique.
func _roll_stats(hero_class: String, rarity: int) -> Dictionary:
	var multiplier := 1.0 + (rarity - 1) * STATS_BONUS_PER_STAR
	var stats := {}
	for stat in CLASS_STATS[hero_class]:
		var base: int = CLASS_STATS[hero_class][stat]
		stats[stat] = roundi(base * multiplier * randf_range(0.9, 1.1))
	return stats
