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

## Nombre maximum de héros dans une équipe de combat.
const TEAM_SIZE := 4

## Un boss garde tous les étages de la Tour multiples de ce nombre (10, 20, 30...).
const BOSS_EVERY := 10

## Les ennemis deviennent plus forts à chaque étage (0.1 = +10 % par étage).
const ENEMY_BONUS_PER_FLOOR := 0.1

## Monstres ordinaires de la Tour (statistiques à l'étage 1).
## Leur « classe » décide de leur façon de combattre, exactement comme pour les héros.
const ENEMY_TYPES := [
	{"name": "Gobelin", "class": "Assassin", "hp": 55, "atk": 14, "def": 4, "spd": 13},
	{"name": "Loup noir", "class": "Guerrier", "hp": 70, "atk": 15, "def": 5, "spd": 11},
	{"name": "Squelette archer", "class": "Archer", "hp": 50, "atk": 16, "def": 4, "spd": 10},
	{"name": "Golem de pierre", "class": "Chevalier", "hp": 110, "atk": 10, "def": 12, "spd": 5},
	{"name": "Sorcier gobelin", "class": "Mage", "hp": 45, "atk": 18, "def": 3, "spd": 8},
	{"name": "Chaman", "class": "Soigneur", "hp": 60, "atk": 9, "def": 5, "spd": 9},
]

## Boss qui gardent les étages multiples de BOSS_EVERY.
const BOSS_TYPES := [
	{"name": "Minotaure", "class": "Guerrier", "hp": 300, "atk": 28, "def": 12, "spd": 9},
	{"name": "Liche", "class": "Mage", "hp": 220, "atk": 32, "def": 8, "spd": 10},
	{"name": "Hydre", "class": "Chevalier", "hp": 400, "atk": 22, "def": 16, "spd": 6},
]

var gems := 3000
var pity_counter := 0

## Prochain étage de la Tour à conquérir.
var tower_floor := 1

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


## Héros encore en vie (ceux qui peuvent combattre).
func alive_heroes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hero in roster:
		if hero["alive"]:
			result.append(hero)
	return result


func is_boss_floor(floor_number: int) -> bool:
	return floor_number % BOSS_EVERY == 0


## Gemmes gagnées en conquérant un étage (le triple pour un étage de boss).
func tower_reward(floor_number: int) -> int:
	var reward := 50 + floor_number * 10
	if is_boss_floor(floor_number):
		reward *= 3
	return reward


## Crée les ennemis d'un étage de la Tour : de plus en plus nombreux (4 au maximum)
## et de plus en plus forts. Un étage de boss contient le boss et 2 monstres.
func tower_enemies(floor_number: int) -> Array[Dictionary]:
	var enemies: Array[Dictionary] = []
	var monster_count := mini(1 + ceili(floor_number / 3.0), 4)
	if is_boss_floor(floor_number):
		enemies.append(_create_enemy(BOSS_TYPES.pick_random(), floor_number))
		monster_count = 2
	for i in monster_count:
		enemies.append(_create_enemy(ENEMY_TYPES.pick_random(), floor_number))
	return enemies


## Applique le résultat d'un combat de la Tour :
## les héros tombés meurent pour toujours ; en cas de victoire, on gagne des gemmes
## et on passe à l'étage suivant. Renvoie le nombre de gemmes gagnées.
func finish_tower_battle(battle: Battle) -> int:
	for fighter in battle.heroes:
		if fighter["hp"] <= 0:
			fighter["source"]["alive"] = false
	if not battle.victory:
		return 0
	var reward := tower_reward(tower_floor)
	tower_floor += 1
	add_gems(reward)
	return reward


## Crée un ennemi à partir d'un modèle, renforcé selon l'étage.
## La vitesse ne change pas, pour que l'ordre d'action reste lisible.
func _create_enemy(template: Dictionary, floor_number: int) -> Dictionary:
	var multiplier := 1.0 + (floor_number - 1) * ENEMY_BONUS_PER_FLOOR
	var stats := {}
	for stat in ["hp", "atk", "def", "spd"]:
		var value: float = template[stat]
		if stat != "spd":
			value *= multiplier
		stats[stat] = roundi(value * randf_range(0.9, 1.1))
	return {"name": template["name"], "class": template["class"], "stats": stats}


## Calcule les statistiques d'un nouveau héros : base de sa classe, bonus de rareté,
## et une petite variation au hasard (±10 %) pour que chaque individu soit unique.
func _roll_stats(hero_class: String, rarity: int) -> Dictionary:
	var multiplier := 1.0 + (rarity - 1) * STATS_BONUS_PER_STAR
	var stats := {}
	for stat in CLASS_STATS[hero_class]:
		var base: int = CLASS_STATS[hero_class][stat]
		stats[stat] = roundi(base * multiplier * randf_range(0.9, 1.1))
	return stats
