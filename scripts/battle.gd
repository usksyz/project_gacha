class_name Battle
extends RefCounted
## Combat automatique entre l'équipe du joueur et des ennemis.
##
## Le combat est calculé en entier, d'un seul coup, par run() : chaque action est notée
## dans « events ». L'écran de combat (BattleView) rejoue ensuite ces événements
## un par un pour que le joueur puisse suivre.
##
## Règles :
## - à chaque tour, tous les combattants vivants agissent, du plus rapide au plus lent ;
## - dégâts = attaque - la moitié de la défense de la cible (au moins 1) ;
## - la dextérité donne une petite chance de coup critique (dégâts x1.5) ;
## - un héros immortel (héros secret) tombé à 0 est seulement « à terre » ;
## - chaque classe a sa particularité :
##     Novice    : attaque simple
##     Guerrier  : frappe fort (dégâts x1.2)
##     Chevalier : attire les coups (les ennemis le visent 3 fois plus souvent)
##     Mage      : frappe tous les ennemis à la fois (dégâts x0.6 sur chacun)
##     Archer    : +25 % de chances de coup critique, et ses critiques font x2
##     Assassin  : vise toujours l'ennemi qui a le moins de points de vie
##     Soigneur  : soigne l'allié le plus blessé (attaque si personne n'est blessé)

## Au-delà de ce nombre de tours, l'équipe abandonne (le combat compte comme perdu).
const MAX_ROUNDS := 30

var heroes: Array[Dictionary] = []
var enemies: Array[Dictionary] = []

## Chaque événement : {"text": ce qui s'est passé, "hp": points de vie de tout le monde après}.
## L'ordre des points de vie est : les héros, puis les ennemis.
var events: Array[Dictionary] = []

var victory := false


func _init(team: Array, foes: Array) -> void:
	for hero in team:
		heroes.append(_make_fighter(hero, true))
	for enemy in foes:
		enemies.append(_make_fighter(enemy, false))


## Joue tout le combat.
func run() -> void:
	for round_number in range(1, MAX_ROUNDS + 1):
		_log("— Tour %d —" % round_number)
		for fighter in _turn_order():
			if fighter["hp"] <= 0:
				continue  # mis K.O. plus tôt dans ce tour
			_act(fighter)
			if _alive(enemies).is_empty():
				victory = true
				_log("Victoire !")
				return
			if _alive(heroes).is_empty():
				_log("Défaite... toute l'équipe est tombée.")
				return
	_log("Le combat s'éternise : ton équipe bat en retraite.")


## Le héros qui a le plus contribué (dégâts + soins), ou "" s'il n'y a aucun héros.
func mvp() -> String:
	var best: Dictionary = {}
	for fighter in heroes:
		if best.is_empty() or fighter["contribution"] > best["contribution"]:
			best = fighter
	return "" if best.is_empty() else best["name"]


## Un « combattant » : ses valeurs de combat et ses points de vie actuels.
## « source » garde le héros (ou l'ennemi) d'origine, pour le marquer mort après le combat.
func _make_fighter(source: Dictionary, is_hero: bool) -> Dictionary:
	var stats := GameData.combat_stats(source)
	return {
		"name": source["name"],
		"class": source["class"],
		"level": source["level"],
		"is_hero": is_hero,
		"immortal": source.get("immortal", false),
		"source": source,
		"hp": stats["hp"],
		"max_hp": stats["hp"],
		"atk": stats["atk"],
		"def": stats["def"],
		"spd": stats["spd"],
		"crit": stats["crit"],
		"contribution": 0,  # dégâts infligés + soins donnés, pour désigner le MVP
		"killer": "",       # cause de la mort, s'il tombe
	}


## Ordre d'action du tour : du plus rapide au plus lent.
## On ajoute un petit nombre au hasard pour départager les égalités.
func _turn_order() -> Array:
	var order := _alive(heroes) + _alive(enemies)
	for fighter in order:
		fighter["initiative"] = fighter["spd"] + randf()
	order.sort_custom(func(a, b): return a["initiative"] > b["initiative"])
	return order


## Le combattant fait son action, selon sa classe.
func _act(fighter: Dictionary) -> void:
	var allies: Array[Dictionary] = heroes if fighter["is_hero"] else enemies
	var foes: Array[Dictionary] = enemies if fighter["is_hero"] else heroes

	match fighter["class"]:
		"Guerrier":
			_attack(fighter, _random_target(foes), 1.2)
		"Mage":
			var targets := _alive(foes)
			var hits := []
			for target in targets:
				hits.append("%s -%d" % [target["name"], _damage(fighter, target, 0.6)])
			_log("%s lance un sort de zone : %s" % [fighter["name"], ", ".join(hits)])
			_check_deaths(targets, fighter)
		"Archer":
			var critical: bool = randf() < fighter["crit"] + 0.25
			_attack(fighter, _random_target(foes), 2.0 if critical else 1.0, critical)
		"Assassin":
			_attack(fighter, _weakest(foes))
		"Soigneur":
			var wounded := _most_wounded(allies)
			if wounded.is_empty():
				_attack(fighter, _random_target(foes))
			else:
				_heal(fighter, wounded)
		_:
			var critical: bool = randf() < fighter["crit"]
			_attack(fighter, _random_target(foes), 1.5 if critical else 1.0, critical)


func _attack(attacker: Dictionary, target: Dictionary, power := 1.0, critical := false) -> void:
	var amount := _damage(attacker, target, power)
	var text := "%s frappe %s : -%d" % [attacker["name"], target["name"], amount]
	if critical:
		text = "Coup critique ! " + text
	_log(text)
	_check_deaths([target], attacker)


## Retire des points de vie à la cible et renvoie les dégâts infligés.
func _damage(attacker: Dictionary, target: Dictionary, power: float) -> int:
	var raw: float = attacker["atk"] * power * randf_range(0.9, 1.1) - target["def"] * 0.5
	var amount := mini(maxi(1, roundi(raw)), target["hp"])
	target["hp"] -= amount
	attacker["contribution"] += amount
	return amount


func _heal(healer: Dictionary, target: Dictionary) -> void:
	var amount := roundi(healer["atk"] * 2.0 * randf_range(0.9, 1.1))
	amount = mini(amount, target["max_hp"] - target["hp"])
	target["hp"] += amount
	healer["contribution"] += amount
	_log("%s soigne %s : +%d" % [healer["name"], target["name"], amount])


## Annonce les combattants qui viennent de tomber à 0 point de vie,
## et note la cause de la mort des héros.
func _check_deaths(targets: Array, attacker: Dictionary) -> void:
	for target in targets:
		if target["hp"] > 0:
			continue
		if not target["is_hero"]:
			_log("%s est vaincu." % target["name"])
		elif target["immortal"]:
			_log("%s est à terre, mais se relèvera." % target["name"])
		else:
			target["killer"] = "tué par %s (niv. %d)" % [attacker["name"], attacker["level"]]
			_log("%s tombe au combat !" % target["name"])


## Choisit une cible au hasard. Un Chevalier compte pour 3 : il est visé 3 fois plus souvent.
func _random_target(foes: Array) -> Dictionary:
	var targets := _alive(foes)
	var total := 0
	for target in targets:
		total += _threat(target)
	var roll := randi() % total
	for target in targets:
		roll -= _threat(target)
		if roll < 0:
			return target
	return targets[-1]


func _threat(fighter: Dictionary) -> int:
	return 3 if fighter["class"] == "Chevalier" else 1


## L'adversaire vivant qui a le moins de points de vie.
func _weakest(foes: Array) -> Dictionary:
	var result: Dictionary = {}
	for target in _alive(foes):
		if result.is_empty() or target["hp"] < result["hp"]:
			result = target
	return result


## L'allié vivant le plus blessé (en proportion), ou {} si personne n'est blessé.
func _most_wounded(allies: Array) -> Dictionary:
	var result: Dictionary = {}
	var lowest_ratio := 1.0
	for ally in _alive(allies):
		var ratio: float = float(ally["hp"]) / ally["max_hp"]
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			result = ally
	return result


func _alive(fighters: Array) -> Array:
	return fighters.filter(func(f): return f["hp"] > 0)


## Note un événement, avec les points de vie de tout le monde à ce moment-là.
func _log(text: String) -> void:
	var hp := []
	for fighter in heroes + enemies:
		hp.append(fighter["hp"])
	events.append({"text": text, "hp": hp})
