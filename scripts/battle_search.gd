class_name BattleSearch
extends RefCounted
## La recherche intelligente des monstres (recensement « Techniques de programmation pour le combat », point 5, technique
## de Dishonored 2 ; ajout du projet).
##
## Avant, un monstre en alerte qui ne voyait aucun héros allait droit sur le plus proche (il savait toujours où il
## était). Hors horde, il cherche maintenant : une carte de probabilité (« heat », une valeur par case, partagée par
## tous les monstres) dit où les héros peuvent être. Quand un monstre voit (ou entend) un héros, la carte se resserre
## sur la place de chaque héros repéré. Sinon, toutes les SEARCH_SPREAD_INTERVAL secondes, elle se répand le long des
## passages (là où ils ont pu aller), et les cases que les monstres regardent sont effacées (on y verrait quelqu'un).
## Chaque chercheur va vers la case la plus probable (moins la distance), en laissant aux autres celles qu'ils ont déjà
## prises (fouille partagée : trois monstres fouillent trois ruelles). Carte vide (personne n'a jamais été vu : les
## monstres ont seulement flairé l'équipe) : ils vont vers le héros le plus proche, comme avant. En horde (survie,
## défense, duel) : comme avant.
##
## Carte de fuite : un héros qui s'enfuit (peur, rupture) court vers la case la plus loin des monstres qu'il connaît,
## à pied, sans trop s'éloigner de lui (flee_target), au lieu du bas de la carte. Aucun tirage au hasard.

var battle  # Battle (pas de type : les deux classes se connaissent)
var heat := PackedFloat32Array()
var _due := 0.0
## Les cases visées par chaque chercheur ({numéro du monstre: indice de case}).
var claims := {}
var _goal_due := {}
## Compteurs pour les mesures : resserrements (un héros vu), cases fouillées par les chercheurs.
var counts := {"vus": 0, "fouilles": 0}


func _init(owner) -> void:
	battle = owner
	heat.resize(battle.map.heights.size())
	heat.fill(0.0)


## Hors horde, une fois l'alerte donnée.
func active() -> bool:
	return battle.alert != null and battle.alert.disposition != "horde" and battle.perception_on


## À chaque pas : resserre la carte sur les héros que les monstres repèrent, sinon la répand et efface ce qu'ils voient.
func tick() -> void:
	if not active() or battle.time < _due:
		return
	_due = battle.time + GameData.SEARCH_SPREAD_INTERVAL - 0.0001
	var map: BattleMap = battle.map
	var spotted := []
	for hero in battle._alive(battle.heroes):
		for monster in battle._alive(battle.enemies):
			if monster["state"] == "alerte" and battle.perception.knows_now(monster, hero):
				spotted.append(hero)
				break
	if not spotted.is_empty():
		heat.fill(0.0)
		for hero in spotted:
			heat[map.index(map.nearest_walkable(map.cell_of(hero["pos"])))] += 1.0
		counts["vus"] += 1
		return
	if _total() <= 0.0:
		return
	_spread()
	_clear_seen()
	var total := _total()
	if total > 0.0:
		for i in heat.size():
			heat[i] /= total


## La chaleur se répand d'une case vers ses voisines (le long des passages, dans les deux sens).
func _spread() -> void:
	var map: BattleMap = battle.map
	var next := PackedFloat32Array()
	next.resize(heat.size())
	next.fill(0.0)
	for i in heat.size():
		if heat[i] <= 0.0:
			continue
		var links: PackedInt32Array = map.out_links[i]
		var keep := 1.0 - GameData.SEARCH_SPREAD_SHARE if links.size() > 0 else 1.0
		next[i] += heat[i] * keep
		for j in links:
			next[j] += heat[i] * GameData.SEARCH_SPREAD_SHARE / links.size()
	heat = next


## Les cases que regardent les monstres en alerte (le long de leurs bâtonnets, et tout autour d'eux) : personne là.
func _clear_seen() -> void:
	var map: BattleMap = battle.map
	for monster in battle._alive(battle.enemies):
		if monster["state"] != "alerte":
			continue
		var origin: Vector2 = monster["pos"]
		_clear(map.cell_of(origin))
		for d in BattleMap.DIRECTIONS:
			_clear(map.cell_of(origin) + d)
		for end in monster["rays"]:
			var length: float = origin.distance_to(end)
			var steps := int(length)
			for k in range(1, steps + 1):
				_clear(map.cell_of(origin.lerp(end, k / maxf(1.0, length))))
	for monster_id in claims.keys():
		var monster: Dictionary = battle.units[monster_id]
		if monster["hp"] <= 0:
			claims.erase(monster_id)


func _clear(cell: Vector2i) -> void:
	if battle.map.in_bounds(cell):
		heat[battle.map.index(cell)] = 0.0


func _total() -> float:
	var total := 0.0
	for value in heat:
		total += value
	return total


## Un monstre en alerte qui ne connaît aucun héros : il fouille la case la plus probable. Renvoie faux si la carte est
## vide (il fait alors comme avant).
func think(monster: Dictionary) -> bool:
	if not active() or _total() <= 0.0:
		claims.erase(monster["id"])
		return false
	var map: BattleMap = battle.map
	var goal: int = claims.get(monster["id"], -1)
	if goal < 0 or heat[goal] <= 0.0 or battle.time >= _goal_due.get(monster["id"], 0.0):
		goal = _pick(monster)
		if goal < 0:
			return false
		if claims.get(monster["id"], -1) != goal:
			counts["fouilles"] += 1
		claims[monster["id"]] = goal
		_goal_due[monster["id"]] = battle.time + GameData.SEARCH_REPICK
	monster["target_id"] = -1
	battle._move_towards(monster, BattleMap.center(map.cell_at(goal)))
	return true


## La case la plus probable pour lui (moins la distance), pas déjà prise par un autre chercheur (ni tout près d'elle).
func _pick(monster: Dictionary) -> int:
	var map: BattleMap = battle.map
	var taken := []
	for other_id in claims:
		if other_id != monster["id"]:
			taken.append(BattleMap.center(map.cell_at(claims[other_id])))
	var best := -1
	var best_score := 0.0
	for i in heat.size():
		if heat[i] <= 0.0:
			continue
		var center := BattleMap.center(map.cell_at(i))
		if taken.any(func(p): return p.distance_to(center) < GameData.SEARCH_CLAIM_RADIUS):
			continue
		var score: float = heat[i] / (1.0 + monster["pos"].distance_to(center) * GameData.SEARCH_DISTANCE_WEIGHT)
		if score > best_score:
			best_score = score
			best = i
	if best < 0:
		# (toutes les cases chaudes sont prises : il aide là où c'est le plus chaud)
		for i in heat.size():
			if heat[i] > best_score:
				best_score = heat[i]
				best = i
	return best


## La carte de fuite : la case où courir pour un héros qui s'enfuit, la plus loin (à pied) des monstres qu'il connaît,
## à au plus FLEE_RADIUS pas de lui. Sans monstre connu : le bas de la carte, comme avant.
func flee_target(hero: Dictionary) -> Vector2:
	var map: BattleMap = battle.map
	var fallback: Vector2 = battle.retreat_point(hero["pos"])
	var goals := []
	for id in hero["knows"]:
		var foe: Dictionary = battle.units[id]
		if foe["hp"] > 0 and foe["present"]:
			goals.append(map.cell_of(foe["pos"]))
	if goals.is_empty():
		return fallback
	var danger: PackedFloat32Array = map.flow_field(goals, BattleMap.SIDE_ENEMIES)
	var own: PackedFloat32Array = map.flow_field([map.nearest_walkable(map.cell_of(hero["pos"]))], BattleMap.SIDE_HEROES)
	var best := fallback
	var best_score := -INF  # (best : le centre de la case)
	for i in danger.size():
		if own[i] > GameData.FLEE_RADIUS or danger[i] == INF or map.kind_at(map.cell_at(i)) == BattleMap.Kind.LADDER:
			continue
		var score: float = danger[i] - own[i] * GameData.FLEE_EFFORT
		if score > best_score:
			best_score = score
			best = BattleMap.center(map.cell_at(i))
	return best
