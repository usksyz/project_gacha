class_name BattleMoves
extends BattleFormations
## Combat (voir battle.gd) : déplacements (portée, vitesse, endurance, chemins, flux, foule, chutes, pousser).


## Assez près (et, pour un tir, sans décor entre les deux) ?
func _in_reach(unit: Dictionary, target: Dictionary, reach: float) -> bool:
	var distance: float = unit["pos"].distance_to(target["pos"])
	var above := height_of(unit) - height_of(target)
	if reach <= MELEE_REACH_MAX:
		# Au corps à corps, on ne frappe pas plus d'un niveau au-dessus ou en dessous (il faut monter, ou descendre).
		if absi(above) > GameData.MELEE_MAX_LEVELS:
			return false
		if unit["weapon"] == "Lance" and _behind_shield(unit, target):
			reach += GameData.SPEAR_WALL_REACH  # par-dessus le mur de boucliers
		return distance <= reach + 0.05
	# Un tireur au-dessus de sa cible voit et tire plus loin (par niveau, HEIGHT_MAX_LEVELS au plus).
	reach += clampi(above, 0, GameData.HEIGHT_MAX_LEVELS) * GameData.HEIGHT_REACH_PER_LEVEL
	if distance > reach + 0.05:
		return false
	return _sees(unit, target)


## Temps entre deux attaques : plus court avec de la dextérité, et selon l'arme (dague rapide, lance lente).
func _attack_time(unit: Dictionary) -> float:
	# Vivacité (compétence de promotion) : des coups plus rapides.
	var quick := 1.0 - GameData.skill_level(unit["skills"], "Vivacité") * GameData.QUICKNESS_PER_LEVEL
	return maxf(0.4, BASE_ATTACK_TIME * 15.0 / maxf(5.0, unit["spd"] * _fear(unit)) * unit["weapon_speed"] * quick)


func _move_speed(unit: Dictionary) -> float:
	if time < unit["trapped_until"]:
		return 0.0  # (étape E) pris dans un piège : il ne peut plus bouger un moment
	var speed: float = BASE_SPEED + unit["spd"] * _fear(unit) * SPEED_PER_DEX
	if unit["exhausted"]:
		speed *= GameData.STAMINA_EXHAUSTED_SPEED
	# (étape E) « pace » : au pas (ronde, exploration prudente), remis à 1 à chaque décision (voir Battle._think)
	return speed * (0.8 if unit["boss"] else 1.0) * unit["pace"]


## Endurance : se déplacer et frapper la vident (deux fois plus vite pour un novice). À 0 : épuisé.
func _spend_stamina(unit: Dictionary, amount: float) -> void:
	if not unit["person"] or amount <= 0.0:
		return
	unit["stamina"] = maxf(minf(unit["stamina_floor"], unit["stamina"]), unit["stamina"] - amount * unit["stamina_cost"])
	if unit["stamina"] <= 0.0 and not unit["exhausted"]:
		unit["exhausted"] = true
		_log("%s est épuisé." % _name_with_stars(unit), "disobey")


## Endurance : elle remonte quand le héros n'est au contact d'aucun ennemi. Épuisé, il reprend ses
## forces à STAMINA_RECOVERED.
func _stamina_tick(unit: Dictionary) -> void:
	var foes := _alive(enemies if unit["is_hero"] else heroes)
	if foes.any(func(foe): return unit["pos"].distance_to(foe["pos"]) <= GameData.STAMINA_CONTACT_RANGE):
		return
	# Au repos à l'arrière (rotation, arrivé à son poste de repos) : trois fois plus vite.
	var rate: float = unit["stamina_regen"]
	if unit["resting"] and unit["order"].is_empty():
		rate *= GameData.ROTATION_REST_FACTOR
	unit["stamina"] = minf(unit["max_stamina"], unit["stamina"] + rate * TICK)
	if unit["exhausted"] and unit["stamina"] >= GameData.STAMINA_RECOVERED:
		unit["exhausted"] = false
	if unit["resting"] and unit["stamina"] >= unit["max_stamina"]:
		unit["resting"] = false  # reposé : il retourne au combat
		_log("%s a repris son souffle." % unit["name"])


## Épuisé (endurance à 0) : attaque et défense x STAMINA_EXHAUSTED_FACTOR.
func _tired(unit: Dictionary) -> float:
	return GameData.STAMINA_EXHAUSTED_FACTOR if unit["exhausted"] else 1.0


## Avance vers un point en suivant un chemin sur la grille 3D (voir BattleMap.find_path) : il contourne le
## décor, prend les escaliers et les échelles, et va moins vite en montant (voir _passage_speed). Le chemin
## est recalculé toutes les PATH_REFRESH secondes, ou tout de suite si le but change de case.
func _move_towards(unit: Dictionary, goal: Vector2) -> void:
	unit["path_timer"] -= TICK
	var goal_cell := _cell_of(goal)
	if unit["path"].is_empty() or unit["path_timer"] <= 0 or unit["path_goal"] != goal_cell:
		unit["path_timer"] = PATH_REFRESH
		unit["path_goal"] = goal_cell
		var path := map.find_path(_cell_of(unit["pos"]), goal_cell, _side(unit))
		if not map.walkable(goal_cell):
			pass  # (on va au plus près)
		elif path.is_empty():
			if _cell_of(unit["pos"]) == goal_cell:
				path.append(goal)  # déjà dans la bonne case : droit au but
		elif _cell_of(path[path.size() - 1]) == goal_cell:
			path[path.size() - 1] = goal
		unit["path"] = path
	_walk_path(unit)


## Le camp d'un combattant pour la recherche de chemin (voir BattleMap.SIDE_HEROES).
func _side(unit: Dictionary) -> int:
	return BattleMap.SIDE_HEROES if unit["is_hero"] else BattleMap.SIDE_ENEMIES


## Avance le long de unit["path"] pendant ce pas. Chaque passage d'une case à l'autre se fait à la vitesse
## qui va avec (marche, escalier, échelle, escalade). Évitement local (cahier, section 3) : si quelqu'un
## d'immobile occupe la case suivante, il le contourne par une case voisine libre ; s'il ne peut pas, il
## attend, et au bout de REPATH_BLOCKED secondes il cherche un autre chemin (voir _blocked). Un passage
## impossible (il a été bousculé hors de son chemin) : il cherchera un nouveau chemin au prochain pas.
func _walk_path(unit: Dictionary) -> void:
	var budget := _move_speed(unit) * TICK
	var start: Vector2 = unit["pos"]
	var path: PackedVector2Array = unit["path"]
	var detours := 0
	while budget > 0.0001 and not path.is_empty():
		var next: Vector2 = path[0]
		var here := _cell_of(unit["pos"])
		var there := _cell_of(next)
		var factor := 1.0
		if here != there:
			if absi(here.x - there.x) > 1 or absi(here.y - there.y) > 1 or map.step_link(here, there) == BattleMap.Link.NONE:
				path = PackedVector2Array()
				unit["path_timer"] = 0.0
				break
			if _stands_in(there, unit) and there != unit["path_goal"]:
				var around := _sidestep(unit, here, there, path[1] if path.size() > 1 else next)
				if around == Vector2i(-1, -1) or detours > 0:
					unit["path"] = path
					_blocked(unit, there)
					return
				detours += 1
				path.insert(0, BattleMap.center(around))
				continue
			factor = _passage_speed(unit, map.step_link(here, there))
		var reach := budget * factor
		var distance: float = unit["pos"].distance_to(next)
		if distance <= reach:
			unit["pos"] = next
			path.remove_at(0)
			budget -= distance / factor
		else:
			unit["pos"] += (next - unit["pos"]).normalized() * reach
			budget = 0.0
	unit["path"] = path
	unit["blocked"] = 0.0
	_spend_stamina(unit, start.distance_to(unit["pos"]) * GameData.STAMINA_MOVE_COST)


## Quelqu'un d'autre se tient-il immobile dans cette case ?
func _stands_in(cell: Vector2i, unit: Dictionary) -> bool:
	var i := map.index(cell)
	return _still_at.has(i) and _still_at[i] != unit["id"]


## Contourner : une case voisine libre (où personne ne se tient), où l'on passe sans monter (à plat, escalier,
## saut d'un niveau), et qui rapproche de « toward ». Vector2i(-1, -1) s'il n'y en a pas.
func _sidestep(unit: Dictionary, here: Vector2i, blocked: Vector2i, toward: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_distance: float = unit["pos"].distance_to(toward) - 0.05
	for d in BattleMap.DIRECTIONS:
		var cell: Vector2i = here + d
		if cell == blocked or not map.in_bounds(cell) or _taken.has(map.index(cell)):
			continue
		var passage := map.step_link(here, cell)
		if not passage in [BattleMap.Link.WALK, BattleMap.Link.STAIRS, BattleMap.Link.DROP]:
			continue
		var distance := BattleMap.center(cell).distance_to(toward)
		if distance < best_distance:
			best = cell
			best_distance = distance
	return best


## Bloqué devant « cell » (quelqu'un d'immobile, et pas de case pour le contourner) : il attend. Au bout de
## REPATH_BLOCKED secondes, il cherche un chemin qui évite ce passage ; un monstre quitte alors le flux de
## la horde pendant DETOUR_SECONDS (cahier : « si une ruelle est bouchée, la horde essaie une autre ruelle »).
func _blocked(unit: Dictionary, cell: Vector2i) -> void:
	unit["blocked"] += TICK
	if unit["blocked"] < REPATH_BLOCKED:
		return
	unit["blocked"] = 0.0
	var goal: Vector2i = unit["path_goal"]
	if goal == Vector2i(-1, -1):
		return
	var side := _side(unit)
	var i := map.index(cell)
	var cost: float = map.costs[side][i]
	map.set_cost(cell, cost + BLOCKED_PATH_COST, side)
	unit["path"] = map.find_path(_cell_of(unit["pos"]), goal, side)
	map.set_cost(cell, cost, side)
	unit["path_timer"] = PATH_REFRESH * 2
	if not unit["is_hero"]:
		unit["detour_until"] = time + DETOUR_SECONDS


## Aller attaquer « target » : au corps à corps, vers une case d'attaque libre autour d'elle (réservée, voir
## _attack_slot), puis droit sur elle ; un monstre loin de son but suit le champ de flux de la horde
## (_follow_flow), sauf s'il fait un détour.
func _approach(unit: Dictionary, target: Dictionary) -> void:
	var goal: Vector2 = target["pos"]
	if not unit["ranged"]:
		var slot := _attack_slot(unit, target)
		if slot >= 0 and _cell_of(unit["pos"]) != map.cell_at(slot):
			goal = BattleMap.center(map.cell_at(slot))
	if not unit["is_hero"] and not quest.get("duel", false) and time >= unit["detour_until"] and not _near(unit, target):
		_follow_flow(unit, target)
	elif unit["detour_until"] > time and not unit["path"].is_empty() and _cell_of(unit["path"][unit["path"].size() - 1]) == _cell_of(goal):
		unit["path_timer"] -= TICK
		_walk_path(unit)  # (détour en cours : il garde le chemin qui évite le passage bouché)
	else:
		_move_towards(unit, goal)


## Réservation des cases (cahier, section 3) : une case de corps à corps autour de la cible est « prise » par
## un seul attaquant ; les suivants en cherchent une autre, ce qui crée de vrais encerclements. On garde sa
## case tant qu'elle convient ; sinon la plus proche des cases libres (au plus un niveau d'écart avec la
## cible, personne d'autre immobile dessus). Renvoie son indice, ou -1 s'il n'y en a plus (il s'approche
## quand même).
func _attack_slot(unit: Dictionary, target: Dictionary) -> int:
	var center := _cell_of(target["pos"])
	var current: int = unit["slot"]
	if current >= 0 and _slot_free(current, unit, target, center):
		_slots[current] = unit["id"]
		unit["slot_seen"] = time
		return current
	if current >= 0 and _slots.get(current, -1) == unit["id"]:
		_slots.erase(current)
	var best := -1
	var best_distance := INF
	for d in BattleMap.DIRECTIONS:
		var cell: Vector2i = center + d
		if not map.in_bounds(cell):
			continue
		var i := map.index(cell)
		if not _slot_free(i, unit, target, center):
			continue
		var distance: float = unit["pos"].distance_to(BattleMap.center(cell)) + (0.3 if d.x != 0 and d.y != 0 else 0.0)
		if distance < best_distance:
			best = i
			best_distance = distance
	unit["slot"] = best
	if best >= 0:
		_slots[best] = unit["id"]
		unit["slot_seen"] = time
	return best


func _slot_free(i: int, unit: Dictionary, target: Dictionary, center: Vector2i) -> bool:
	var cell := map.cell_at(i)
	if absi(cell.x - center.x) > 1 or absi(cell.y - center.y) > 1 or cell == center or not map.walkable(cell):
		return false
	if absi(map.height_at(cell) - height_of(target)) > GameData.MELEE_MAX_LEVELS:
		return false
	if _slots.get(i, unit["id"]) != unit["id"]:
		return false
	return not _still_at.has(i) or _still_at[i] == unit["id"] or _still_at[i] == target["id"]


## Le champ de flux d'une cible (partagé par toute la horde) : recalculé au plus toutes les FLOW_REFRESH
## secondes si la cible a changé de case, et toutes les FLOW_MAX_AGE secondes (la foule bouge).
func _flow_for(target: Dictionary) -> Dictionary:
	var goal := _cell_of(target["pos"])
	var flow: Dictionary = _flows.get(target["id"], {})
	if flow.is_empty() or (time - flow["time"] >= FLOW_REFRESH and flow["cell"] != goal) or time - flow["time"] >= FLOW_MAX_AGE:
		flow = {"cell": goal, "time": time, "dist": map.flow_field([goal], BattleMap.SIDE_ENEMIES)}
		_flows[target["id"]] = flow
	return flow


## Le monstre est-il assez près de sa cible pour prendre son propre chemin (vers sa case d'attaque) ? Près
## en marchant (distance lue dans le champ de flux, pas à vol d'oiseau : sinon, de part et d'autre d'un
## obstacle, il hésiterait sans fin entre le flux, qui contourne d'un côté, et son chemin, qui contourne de
## l'autre) ; une fois près, il le reste jusqu'à NEAR_MARGIN de plus.
func _near(unit: Dictionary, target: Dictionary) -> bool:
	var dist: float = _flow_for(target)["dist"][map.index(map.nearest_walkable(_cell_of(unit["pos"])))]
	unit["near"] = dist <= FLOW_NEAR + (NEAR_MARGIN if unit["near"] else 0.0)
	return unit["near"]


## Champ de flux (cahier, section 3) : au lieu d'un chemin par monstre, une carte des distances vers chaque
## cible, calculée pour toute la horde (BattleMap.flow_field), que chaque monstre descend case par case en
## contournant ceux qui se tiennent immobiles. Recalculée au plus toutes les FLOW_REFRESH secondes si la
## cible a changé de case, et toutes les FLOW_MAX_AGE secondes (la foule bouge).
func _follow_flow(unit: Dictionary, target: Dictionary) -> void:
	unit["path_timer"] -= TICK
	var goal := _cell_of(target["pos"])
	var flow := _flow_for(target)
	var here := _cell_of(unit["pos"])
	var avoid := {}
	for i in _still_at:
		if _still_at[i] != unit["id"] and _still_at[i] != target["id"]:
			avoid[i] = true
	unit["path_goal"] = goal
	var next := map.flow_step(flow["dist"], here, BattleMap.SIDE_ENEMIES, avoid)
	if next == Vector2i(-1, -1):
		var ahead := map.flow_step(flow["dist"], here, BattleMap.SIDE_ENEMIES)
		if ahead == Vector2i(-1, -1):
			_move_towards(unit, target["pos"])  # (le flux ne mène nulle part d'ici : chemin à lui)
		else:
			unit["path"] = PackedVector2Array([BattleMap.center(ahead)])
			_blocked(unit, ahead)
		return
	unit["path"] = PackedVector2Array([BattleMap.center(next)])
	_walk_path(unit)


## Au début de chaque pas : qui se tient où (cases prises, cases où quelqu'un est immobile), et les cases
## d'attaque encore réservées (celles dont l'attaquant s'est servi au pas précédent).
func _update_crowd() -> void:
	_still_at.clear()
	_taken.clear()
	for unit in units:
		if not unit["present"] or unit["hp"] <= 0:
			continue
		var i := map.index(_cell_of(unit["pos"]))
		_taken[i] = true
		if unit["still"]:
			_still_at[i] = unit["id"]
	for i in _slots.keys():
		var holder: Dictionary = units[_slots[i]]
		if holder["hp"] <= 0 or not holder["present"] or holder["slot"] != i or time - holder["slot_seen"] > TICK * 1.5:
			_slots.erase(i)
			if holder["slot"] == i:
				holder["slot"] = -1


## Coûts des cases pour la recherche de chemin, toutes les PATH_REFRESH secondes (cahier, section 3 : « coût
## selon la pente, les échelles, la foule et le danger ») : terrain (BattleMap.TERRAIN_COSTS), foule (quelqu'un
## d'immobile ou qui passe), et, pour les héros, les cases à portée d'un tireur ennemi.
func _refresh_costs() -> void:
	if time < _costs_due:
		return
	_costs_due = time + PATH_REFRESH
	var crowd := PackedFloat32Array()
	crowd.resize(map.heights.size())
	crowd.fill(0.0)
	for unit in units:
		if unit["present"] and unit["hp"] > 0:
			crowd[map.index(_cell_of(unit["pos"]))] += CROWD_STILL_COST if unit["still"] else CROWD_MOVING_COST
	var danger := PackedFloat32Array()
	danger.resize(map.heights.size())
	danger.fill(0.0)
	for shooter in enemies:
		if not shooter["present"] or shooter["hp"] <= 0 or not shooter["ranged"]:
			continue
		var reach: float = shooter["reach"]
		var c := _cell_of(shooter["pos"])
		var r := ceili(reach)
		for x in range(maxi(0, c.x - r), mini(GRID_W, c.x + r + 1)):
			for y in range(maxi(0, c.y - r), mini(GRID_H, c.y + r + 1)):
				if BattleMap.center(Vector2i(x, y)).distance_to(shooter["pos"]) <= reach:
					var i := map.index(Vector2i(x, y))
					danger[i] = minf(DANGER_MAX_COST, danger[i] + DANGER_COST)
	for i in map.heights.size():
		var cell := map.cell_at(i)
		var base: float = map.base_costs[i]
		map.set_cost(cell, base + crowd[i] + danger[i], BattleMap.SIDE_HEROES)
		map.set_cost(cell, base + crowd[i], BattleMap.SIDE_ENEMIES)


## Vitesse d'un passage d'une case à l'autre (part de sa vitesse de marche ; voir GameData, tower.gd,
## « Verticalité ») : escalier, échelle, escalade d'un niveau (plus vite avec de la Dextérité).
func _passage_speed(unit: Dictionary, passage: int) -> float:
	match passage:
		BattleMap.Link.STAIRS:
			return GameData.STAIRS_SPEED
		BattleMap.Link.LADDER:
			return GameData.LADDER_SPEED
		BattleMap.Link.CLIMB:
			var skill: float = 1.0 + (unit["spd"] - 10) * GameData.CLIMB_DEX_BONUS
			if unit["is_hero"]:
				skill *= PersonalityEngine.modifier("climb", unit["source"])  # l'Audace (neutre pour l'instant)
			return GameData.CLIMB_SPEED * clampf(skill, GameData.CLIMB_SKILL_MIN, GameData.CLIMB_SKILL_MAX)
	return 1.0


## Recule d'un pas, à l'opposé d'une menace, si la place est libre (il peut sauter d'un niveau, pas plus).
func _step_away(unit: Dictionary, threat: Vector2) -> void:
	var direction: Vector2 = (unit["pos"] - threat).normalized()
	var next: Vector2 = unit["pos"] + direction * _move_speed(unit) * TICK
	if _can_shift(unit["pos"], next, true):
		_spend_stamina(unit, _move_speed(unit) * TICK * GameData.STAMINA_MOVE_COST)
		unit["pos"] = next
		unit["path"] = PackedVector2Array()


## Les combattants trop proches (à la même hauteur) se poussent un peu, sans entrer dans le décor ni changer
## de niveau (une bousculade ne fait pas tomber d'un toit : seul un coup puissant le fait, voir _push).
func _separate() -> void:
	var present := _alive(units)
	for i in present.size():
		for j in range(i + 1, present.size()):
			var a: Dictionary = present[i]
			var b: Dictionary = present[j]
			if height_of(a) != height_of(b):
				continue
			var offset: Vector2 = b["pos"] - a["pos"]
			var distance := offset.length()
			if distance >= PERSONAL_SPACE:
				continue
			if distance < 0.01:
				offset = Vector2(randf_range(-1, 1), randf_range(-1, 1))
			var push := offset.normalized() * (PERSONAL_SPACE - distance) * 0.5
			if _can_shift(a["pos"], a["pos"] - push):
				a["pos"] -= push
			if _can_shift(b["pos"], b["pos"] + push):
				b["pos"] += push


## Après les déplacements du pas : chacun prend la hauteur de sa case. Qui descend de deux niveaux ou plus
## sans échelle (un saut, une chute) se blesse (voir GameData.fall_damage).
func _land() -> void:
	for unit in units:
		if not unit["present"] or unit["hp"] <= 0:
			continue
		unit["still"] = unit["pos"].distance_to(unit["prev_pos"]) < 0.02  # (immobile : voir _update_crowd)
		var cell := _cell_of(unit["pos"])
		if cell == unit["cell"]:
			continue
		var levels: int = unit["z"] - map.height_at(cell)
		var by_ladder := map.kind_at(cell) == BattleMap.Kind.LADDER or map.kind_at(unit["cell"]) == BattleMap.Kind.LADDER
		unit["cell"] = cell
		unit["z"] = map.height_at(cell)
		if levels >= 2 and not by_ladder:
			_fall(unit, levels)


## Une chute (ou un saut) de « levels » niveaux : dégâts, et peut-être la mise à terre.
func _fall(unit: Dictionary, levels: int) -> void:
	var amount := roundi(unit["max_hp"] * GameData.fall_damage(levels))
	if amount <= 0:
		return
	amount = _hold_on(unit, mini(amount, unit["hp"]))  # rage d'éveil : il refuse de mourir
	unit["hp"] -= amount
	_effect("bleed", unit, unit, "-%d" % amount, levels >= 3)
	_log("%s tombe de %d niveaux (-%d)." % [_name_with_stars(unit), levels, amount], "bleed" if levels >= 3 else "")
	if unit["hp"] <= 0:
		_announce_fall(unit, "tombé de %d niveaux" % levels)
	else:
		_check_critical_state(unit)


## Un coup puissant au contact près d'un bord peut faire tomber la cible (cahier : « pousser ») : la case
## derrière elle, dans le sens du coup, est plus basse. Jamais un boss.
func _push(attacker: Dictionary, target: Dictionary, amount: int, critical: bool) -> void:
	if target["boss"] or target["hp"] <= 0 or not target["present"] or (not critical and amount < target["max_hp"] * GameData.PUSH_MIN_HIT):
		return
	var direction: Vector2 = (target["pos"] - attacker["pos"]).normalized()
	var behind := Vector2i((target["pos"] + direction).floor())
	var cell := _cell_of(target["pos"])
	if behind == cell or not map.walkable(behind) or absi(behind.x - cell.x) > 1 or absi(behind.y - cell.y) > 1 \
			or map.height_at(behind) >= height_of(target):
		return
	if randf() >= GameData.PUSH_CHANCE:
		return
	target["pos"] = BattleMap.center(behind)
	target["path"] = PackedVector2Array()
	_log("%s est poussé dans le vide par %s !" % [_name_with_stars(target), attacker["name"]], "bleed")
