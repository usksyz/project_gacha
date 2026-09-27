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

## Catalogue des héros qu'on peut invoquer.
const HERO_POOL := [
	{"name": "Aldric", "rarity": 5, "role": "Épéiste"},
	{"name": "Séléné", "rarity": 5, "role": "Mage"},
	{"name": "Kaelen", "rarity": 5, "role": "Archer"},
	{"name": "Brunhild", "rarity": 4, "role": "Guerrière"},
	{"name": "Oriane", "rarity": 4, "role": "Prêtresse"},
	{"name": "Vesper", "rarity": 4, "role": "Assassin"},
	{"name": "Garrick", "rarity": 3, "role": "Chevalier"},
	{"name": "Lysa", "rarity": 3, "role": "Archère"},
	{"name": "Tobias", "rarity": 3, "role": "Mage"},
	{"name": "Mira", "rarity": 2, "role": "Soigneuse"},
	{"name": "Doran", "rarity": 2, "role": "Lancier"},
	{"name": "Pip", "rarity": 2, "role": "Éclaireur"},
	{"name": "Hugo", "rarity": 1, "role": "Milicien"},
	{"name": "Léna", "rarity": 1, "role": "Apprentie"},
	{"name": "Bram", "rarity": 1, "role": "Porteur"},
]

var gems := 3000
var pity_counter := 0

## Tous les héros invoqués. Chaque invocation crée un héros unique :
## deux « Aldric » sont deux individus différents (ils pourront mourir séparément).
var roster: Array[Dictionary] = []


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
	return {
		"name": template["name"],
		"rarity": rarity,
		"role": template["role"],
		"level": 1,
		"alive": true,
	}
