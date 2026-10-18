class_name BattleTactics
extends RefCounted
## L'IA tactique des héros (cahier, onglet « Combat v2 », section « L'IA tactique des héros » ; étape C3).
##
## Avant : tous les héros fonçaient sur l'ennemi le plus proche dès qu'il était à moins de 7 cases. Maintenant,
## toutes les TacticsData.PLAN_SECONDS secondes, chaque héros libre (sans ordre du Maître, ni secours, ni repos, ni
## panique) fait un plan : une attitude, une case où être, une cible. Il ne planifie que contre les ennemis qu'il
## connaît (perception, BattlePerception) : un ennemi qu'on ne voit pas ne compte pas.
##
## Attitudes (cahier) :
## - attendre : se placer à la meilleure case proche et laisser l'ennemi venir (embuscade, tenir la ruelle, tirer
##   d'en haut) ; il frappe ce qui entre à sa portée ;
## - engager : aller frapper la cible quand c'est avantageux (cible affaiblie, à portée d'engagement, allié au
##   contact à aider, attente trop longue, ou un ennemi qui a blessé un ami pour un Colérique) ;
## - garder ses distances : un tireur recule quand un ennemi au corps à corps approche, puis tire à nouveau ;
## - se couvrir : sous le feu, aller derrière un muret ou un coin de mur ;
## - concentrer : le choix de la cible (celle que frappent les alliés, la plus blessée, le tireur qui fait mal) ;
## - protéger : se placer entre un allié faible et l'ennemi ;
## - décrocher : blessé et entouré, reculer vers les alliés ;
## - peur : chercher la position la plus sûre (même mauvaise pour l'équipe).
## La case : on note les cases autour de lui (TacticsData.CRITERIA, avec ses poids). L'Intelligence fixe combien de
## critères il voit et combien de cases il étudie ; la personnalité a réglé ses poids et ses seuils de départ
## (TacticsData.PERSONALITY), rangés sur le héros par contexte (profile : hero["tactics"], sauvegardé). Sans aucun
## tirage au hasard (mêmes combats à graine égale, avec ou sans écran).
## Le plan, gardé dans fighter["tactic"] : {"attitude", "cell" (centre de la case, ou null), "target" (numéro, ou
## -1), "reasons" (les 3 plus fortes, pour le mode dev), "t"}.

const D := preload("res://scripts/game_data/tactics_data.gd")

var battle  # Battle


func _init(owner) -> void:
	battle = owner


# ---------------------------------------------------------------------------
# Les habitudes du héros (par contexte, sauvegardées)
# ---------------------------------------------------------------------------

## Le contexte d'un combat : « type de quête | famille d'ennemis | gabarit de terrain » (ex. « survival|gobelins|ville »).
static func context_of(quest: Dictionary, foes: Array, map_data: Dictionary) -> String:
	var counts := {}
	for foe in foes:
		var family := family_of(foe.get("base_name", foe.get("name", "")))
		counts[family] = counts.get(family, 0) + 1
	var family := "divers"
	var best := 0
	for name in counts:
		if counts[name] > best:
			best = counts[name]
			family = name
	return "%s|%s|%s" % [quest.get("type", "extermination"), family, map_data.get("template", "inconnu")]


## La famille d'un ennemi (TacticsData.FAMILIES), d'après son nom de base.
static func family_of(base_name: String) -> String:
	var lower := base_name.to_lower()
	for word in D.FAMILIES:
		if lower.contains(word):
			return D.FAMILIES[word]
	return "divers"


## Les habitudes tactiques d'un héros pour un contexte : {"weights", "thresholds", "start_weights",
## "start_thresholds", "fights"}. Créées au premier combat dans ce contexte, depuis les valeurs de base réglées par
## sa personnalité, puis gardées sur le héros (hero["tactics"], sauvegardé). Elles ne changent pas encore (C3b).
static func profile(hero: Dictionary, context: String) -> Dictionary:
	if not hero.has("tactics") or int(hero["tactics"].get("version", 0)) != D.VERSION:
		hero["tactics"] = {"version": D.VERSION, "contexts": {}}
	var contexts: Dictionary = hero["tactics"]["contexts"]
	if not contexts.has(context):
		var weights: Dictionary = D.BASE_WEIGHTS.duplicate()
		var thresholds: Dictionary = D.BASE_THRESHOLDS.duplicate()
		for line in D.PERSONALITY:
			var value: int = PersonalityEngine.composite(hero, line["composite"]) if line.has("composite") \
				else PersonalityEngine.axis(hero, line["axis"])
			var factor := clampf(1.0 + line["k"] * value / 100.0, D.PERSONALITY_MIN, D.PERSONALITY_MAX)
			var what: String = line["what"]
			if weights.has(what):
				weights[what] = weights[what] * factor
			elif thresholds.has(what):
				thresholds[what] = thresholds[what] * factor
		contexts[context] = {"weights": weights, "thresholds": thresholds,
			"start_weights": weights.duplicate(), "start_thresholds": thresholds.duplicate(), "fights": 0}
	return contexts[context]


## Nombre de critères qu'il voit (Intelligence, Lucidité, Acuité).
static func criteria_count(hero: Dictionary) -> int:
	var n := D.CRITERIA_BASE + floori((hero["stats"]["int"] - D.INT_BASE) / D.INT_PER_CRITERION) + _lucid_steps(hero)
	return clampi(n, D.CRITERIA_BASE, D.CRITERIA.size())


## Nombre de cases qu'il étudie (Intelligence, Lucidité, Acuité).
static func cells_count(hero: Dictionary) -> int:
	var n := D.CELLS_BASE + roundi((hero["stats"]["int"] - D.INT_BASE) * D.CELLS_PER_INT) + _lucid_steps(hero) * D.LUCID_CELLS
	return clampi(n, D.CELLS_MIN, D.CELLS_MAX)


## Lucidité (Foi négative) et Acuité aiguë : des crans de mieux (ou de moins), tous les LUCID_TIERS paliers.
static func _lucid_steps(hero: Dictionary) -> int:
	var lucid := -PersonalityEngine.axis(hero, "FOI") / 10 + PersonalityEngine.axis(hero, "ACU") / 10
	return int(lucid / D.LUCID_TIERS)


# ---------------------------------------------------------------------------
# Penser (chaque pas) : refaire le plan si besoin, puis agir
# ---------------------------------------------------------------------------

## Le héros libre agit selon son plan. Renvoie faux s'il ne connaît aucun ennemi (le combat garde son
## comportement d'attente, voir Battle._unaware).
func think(unit: Dictionary, known: Array, foes: Array, allies: Array) -> bool:
	if known.is_empty():
		unit["tactic"] = {}
		return false
	# Placé par le Meneur (survie) : il garde ce placement tant qu'aucun ennemi connu n'est à moins de
	# ENGAGE_DISTANCE cases (le combat le laisse à son poste) ; ensuite, l'IA.
	if unit.get("leader_post", false):
		if not known.any(func(foe): return _foe_pos(unit, foe).distance_to(unit["pos"]) <= Battle.ENGAGE_DISTANCE):
			return false
		unit["leader_post"] = false
	if unit["engaged_t"] < 0.0:
		unit["engaged_t"] = battle.time  # (le moment où il a connu son premier ennemi)
	var plan: Dictionary = unit["tactic"]
	var target_gone: bool = not plan.is_empty() and plan["target"] >= 0 and battle.units[plan["target"]]["hp"] <= 0
	if plan.is_empty() or target_gone or battle.time >= unit["tactic_due"]:
		unit["tactic_due"] = battle.time + D.PLAN_SECONDS
		plan = _plan(unit, known, allies)
		unit["tactic"] = plan
	_act(unit, plan, known, foes)
	return true


## Ce que fait le héros pendant ce pas, selon son plan.
func _act(unit: Dictionary, plan: Dictionary, known: Array, foes: Array) -> void:
	var target: Dictionary = battle.units[plan["target"]] if plan["target"] >= 0 else {}
	if plan["attitude"] == "engager" and not target.is_empty():
		unit["target_id"] = target["id"]
		if battle._in_reach(unit, target, unit["reach"]):
			battle._try_attack(unit, target, foes)
			return
		var where = battle.perception.known_pos(unit, target) if battle.perception_on else target["pos"]
		if battle.perception_on and not battle.perception.knows_now(unit, target):
			# (connue de mémoire seulement : il va voir à sa dernière place)
			if where == null or unit["pos"].distance_to(where) <= 1.0:
				unit["knows"].erase(target["id"])
				unit["tactic_due"] = 0.0
			else:
				battle._move_towards(unit, where)
			return
		battle._approach(unit, target)
		return
	# Les autres attitudes : aller à sa case ; en chemin et sur place, frapper ce qui est à sa portée (sauf en
	# reculant : décrocher, garder ses distances, peur).
	var retreating: bool = plan["attitude"] in ["decrocher", "distance", "peur"]
	var cell = plan["cell"]
	var arrived: bool = cell == null or unit["pos"].distance_to(cell) <= 0.2
	if arrived or not retreating:
		var victim := _in_reach_target(unit, known, target)
		if not victim.is_empty():
			# Un ennemi à sa portée : il se bat là (il ne frappe pas en marchant).
			unit["target_id"] = victim["id"]
			battle._try_attack(unit, victim, foes)
			return
	if not arrived:
		battle._move_towards(unit, cell)


## L'ennemi connu à sa portée à frapper : sa cible si elle y est, sinon le plus proche ; {} s'il n'y en a pas.
func _in_reach_target(unit: Dictionary, known: Array, target: Dictionary) -> Dictionary:
	if not target.is_empty() and battle._in_reach(unit, target, unit["reach"]):
		return target
	var near := known.filter(func(foe): return battle._in_reach(unit, foe, unit["reach"]))
	return battle._nearest(unit, near) if not near.is_empty() else {}


# ---------------------------------------------------------------------------
# Le plan : attitude, cible, case
# ---------------------------------------------------------------------------

func _plan(unit: Dictionary, known: Array, allies: Array) -> Dictionary:
	var th: Dictionary = unit["tt"]
	var smart: bool = unit["t_criteria"] >= 4  # assez de jugeote pour concentrer les coups
	var target := _pick_target(unit, known, allies, smart)
	var hp_ratio: float = float(unit["hp"]) / unit["max_hp"]
	var contacts := known.filter(func(foe): return _foe_pos(unit, foe).distance_to(unit["pos"]) <= D.CONTACT_RANGE)
	var reasons: Array = []
	var attitude := "attendre"
	var protect_ward: Dictionary = {}
	# Sous le feu : depuis quand. Le compte ne repart de zéro que quand ce tireur n'est plus là (tombé, ou plus
	# connu) : se cacher ne remet pas le compte à zéro, on se couvre pour avancer.
	var shooter := _shooter_on(unit, known)
	if unit["cover_from"] >= 0:
		var old: Dictionary = battle.units[unit["cover_from"]]
		if old["hp"] <= 0 or not known.has(old):
			unit["cover_from"] = -1
			unit["cover_since"] = -1.0
	if not shooter.is_empty() and unit["cover_from"] < 0:
		unit["cover_from"] = shooter["id"]
		unit["cover_since"] = battle.time
	if hp_ratio < th["retreat_hp"] and contacts.size() >= th["retreat_foes"]:
		attitude = "decrocher"
	elif unit["ranged"] and known.any(func(foe): return not foe["ranged"] and _foe_pos(unit, foe).distance_to(unit["pos"]) <= th["shooter_range"]):
		attitude = "distance"
	else:
		var angry := _anger_target(unit, known)
		if not angry.is_empty():
			attitude = "engager"
			target = angry
			reasons.append({"why": "colère : %s a blessé un allié" % angry["name"], "weight": 9.0})
		elif not shooter.is_empty() and unit["t_criteria"] > D.CRITERIA.find("couvert") \
				and not battle._in_reach(unit, shooter, unit["reach"]) and battle.time - unit["cover_since"] <= th["cover_max"]:
			# Sous le feu : se couvrir d'abord, cover_max secondes au plus ; ensuite (ou un tireur à sa propre
			# portée), il va le chercher (plus bas : engager).
			attitude = "couvrir"
		elif not shooter.is_empty() and unit["t_criteria"] > D.CRITERIA.find("couvert"):
			attitude = "engager"
			target = shooter
			reasons.append({"why": "aller chercher le tireur %s" % shooter["name"], "weight": 6.0})
		else:
			protect_ward = _ward(unit, known, allies)
			if not protect_ward.is_empty():
				attitude = "proteger"
			elif _should_engage(unit, target, known, allies, reasons):
				attitude = "engager"
	var plan := {"attitude": attitude, "cell": null, "target": target["id"] if not target.is_empty() else -1,
		"reasons": [], "t": battle.time}
	if attitude != "engager":
		var best := _best_cell(unit, known, allies, attitude, protect_ward, shooter)
		plan["cell"] = best["cell"]
		reasons.append_array(best["reasons"])
		# Se couvrir : seulement s'il y a un abri qui le rapproche du tireur ; sinon, il va droit sur lui.
		if attitude == "couvrir" and _exposed_to(shooter, best["cell"], battle.map.height_at(battle._cell_of(best["cell"]))):
			plan["attitude"] = "engager"
			plan["cell"] = null
			plan["target"] = shooter["id"]
			reasons = [{"why": "pas d'abri : aller chercher le tireur %s" % shooter["name"], "weight": 6.0}]
		# Attendre : seulement si la case choisie vaut nettement mieux que se battre là où il est ; sinon, à quoi bon
		# attendre ? Il engage (cahier : « si l'ennemi vient vers lui et qu'une bonne position est proche »).
		if attitude == "attendre" and not target.is_empty() and best["gain"] < D.WAIT_ADVANTAGE \
				and _foe_pos(unit, target).distance_to(unit["pos"]) <= Battle.ENGAGE_DISTANCE:
			plan["attitude"] = "engager"
			plan["cell"] = null
			reasons = [{"why": "pas de meilleure place proche", "weight": 2.0}]
	reasons.sort_custom(func(a, b): return absf(a["weight"]) > absf(b["weight"]))
	plan["reasons"] = reasons.slice(0, 3)
	unit["t_last_dist"] = _foe_pos(unit, target).distance_to(unit["pos"]) if not target.is_empty() else -1.0
	return plan


## Faut-il aller chercher la cible plutôt que l'attendre ? (Avec la raison dans « reasons ».) On attend quand la
## cible vient vers soi ; on engage quand elle est à portée, affaiblie, tout près (l'Impulsif la trouve « tout
## près » de plus loin), qu'un allié au contact a besoin d'aide, qu'elle ne vient pas, ou qu'il ne fait rien
## depuis trop longtemps (wait_max).
func _should_engage(unit: Dictionary, target: Dictionary, known: Array, allies: Array, reasons: Array) -> bool:
	if target.is_empty():
		return false
	var th: Dictionary = unit["tt"]
	var distance := _foe_pos(unit, target).distance_to(unit["pos"])
	if battle._in_reach(unit, target, unit["reach"]):
		reasons.append({"why": "%s est à sa portée" % target["name"], "weight": 5.0})
		return true
	if distance > Battle.ENGAGE_DISTANCE:
		return false  # trop loin : il attend qu'elle vienne
	# Un héros qui pense à l'encerclement (critère « encercle ») ne va pas seul au milieu de plusieurs ennemis : il
	# les attend (plutôt à une bonne place). L'Audacieux en accepte plus (engage_crowd).
	if unit["t_criteria"] > D.CRITERIA.find("encercle"):
		var crowd := _crowd_around(unit, target, known)
		if crowd >= th["engage_crowd"]:
			reasons.append({"why": "trop d'ennemis autour de %s (%d)" % [target["name"], crowd], "weight": 4.0})
			return false
	if float(target["hp"]) / target["max_hp"] < th["engage_hp"]:
		reasons.append({"why": "%s est affaibli" % target["name"], "weight": 6.0})
		return true
	if distance <= th["engage_range"]:
		reasons.append({"why": "%s est tout près" % target["name"], "weight": 4.0})
		return true
	# Un allié est au contact d'un ennemi pas loin : il va l'aider.
	for ally in allies:
		if ally["id"] == unit["id"] or ally["pos"].distance_to(unit["pos"]) > th["help_range"]:
			continue
		for foe in known:
			if foe["pos"].distance_to(ally["pos"]) <= D.CONTACT_RANGE:
				reasons.append({"why": "aider %s, au contact" % ally["name"], "weight": 5.0})
				return true
	# La cible ne vient pas vers lui (elle ne s'est pas rapprochée depuis le dernier plan) : attendre ne sert à rien.
	if unit["t_last_dist"] >= 0.0 and distance >= unit["t_last_dist"] - 0.05:
		reasons.append({"why": "%s ne vient pas" % target["name"], "weight": 3.0})
		return true
	# Il ne fait rien depuis trop longtemps (aucun coup porté).
	if battle.time - unit["last_attack_t"] > th["wait_max"] and battle.time - unit["engaged_t"] > th["wait_max"]:
		reasons.append({"why": "attendre ne sert à rien (%d s)" % roundi(th["wait_max"]), "weight": 3.0})
		return true
	return false


## Combien d'ennemis de plus l'attendraient autour de la cible (à moins de CROWD_RANGE cases d'elle), moins les
## alliés déjà là pour partager les coups.
func _crowd_around(unit: Dictionary, target: Dictionary, known: Array) -> int:
	var where := _foe_pos(unit, target)
	var crowd := 0
	for foe in known:
		if foe["id"] != target["id"] and _foe_pos(unit, foe).distance_to(where) <= D.CROWD_RANGE:
			crowd += 1
	var allies: Array = battle.perception._alive_heroes if battle.perception_on else battle._alive(battle.heroes)
	for ally in allies:
		if ally["id"] != unit["id"] and ally["pos"].distance_to(where) <= D.CROWD_RANGE:
			crowd -= 1
	return crowd


## Concentrer : la cible. Peu de jugeote : la plus proche connue (comme avant). Sinon : celle que frappent déjà les
## alliés, la plus blessée, le tireur qui fait mal ; et la règle de sa classe (l'Assassin vise le plus faible).
func _pick_target(unit: Dictionary, known: Array, allies: Array, smart: bool) -> Dictionary:
	if unit["class"] == "Assassin":
		return battle._weakest(known)
	if not smart:
		return battle._choose_target(unit, known, allies)
	var best: Dictionary = {}
	var best_score := INF
	for foe in known:
		var score := _foe_pos(unit, foe).distance_to(unit["pos"])
		for ally in allies:
			if ally["id"] != unit["id"] and ally.get("target_id", -1) == foe["id"] \
					and ally["pos"].distance_to(foe["pos"]) <= ally["reach"] + 0.5:
				score -= 1.0  # un allié le frappe déjà : on concentre
		score -= (1.0 - float(foe["hp"]) / foe["max_hp"]) * 3.0  # achever un blessé
		if foe["ranged"] and battle.time - foe["hurt_hero_at"] <= D.ANGER_SECONDS:
			score -= 2.0  # le tireur qui fait mal
		if score < best_score:
			best_score = score
			best = foe
	return best


## Colère : un Colérique charge l'ennemi qui vient de blesser un allié (même si c'est une erreur).
func _anger_target(unit: Dictionary, known: Array) -> Dictionary:
	if PersonalityEngine.axis(unit["source"], "COL") < D.ANGER_AXIS:
		return {}
	for foe in known:
		if battle.time - foe["hurt_hero_at"] <= D.ANGER_SECONDS and foe["hurt_hero_id"] != unit["id"]:
			return foe
	return {}


## Sous le feu : le tireur ennemi connu le plus proche qui le voit et l'atteint ({} s'il n'y en a pas).
func _shooter_on(unit: Dictionary, known: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for foe in known:
		if foe["ranged"] and _exposed_to(foe, unit["pos"], battle.height_of(unit)):
			var distance: float = foe["pos"].distance_to(unit["pos"])
			if distance < best_distance:
				best_distance = distance
				best = foe
	return best


## Protéger : un allié faible (sous protect_hp de sa vie), menacé par un ennemi au contact, pas trop loin. Seuls
## les héros au corps à corps avec un bouclier, ou Empathiques, s'y risquent ; {} sinon.
func _ward(unit: Dictionary, known: Array, allies: Array) -> Dictionary:
	if unit["ranged"] or not (unit["shield"] or PersonalityEngine.axis(unit["source"], "EMP") >= 30):
		return {}
	for ally in allies:
		if ally["id"] == unit["id"] or float(ally["hp"]) / ally["max_hp"] >= unit["tt"]["protect_hp"] \
				or ally["pos"].distance_to(unit["pos"]) > D.PROTECT_RANGE:
			continue
		if known.any(func(foe): return foe["pos"].distance_to(ally["pos"]) <= D.CONTACT_RANGE):
			return ally
	return {}


## Où il croit que se trouve cet ennemi.
func _foe_pos(unit: Dictionary, foe: Dictionary) -> Vector2:
	if not battle.perception_on:
		return foe["pos"]
	var pos = battle.perception.known_pos(unit, foe)
	return pos if pos != null else foe["pos"]


# ---------------------------------------------------------------------------
# Noter les cases
# ---------------------------------------------------------------------------

## La meilleure case parmi celles qu'il étudie (les plus proches à pied d'abord, autant que son Intelligence le
## permet), notée selon les critères qu'il voit. Renvoie {"cell": centre, "reasons": [les 3 plus fortes]}.
func _best_cell(unit: Dictionary, known: Array, allies: Array, attitude: String, ward: Dictionary,
		shooter: Dictionary = {}) -> Dictionary:
	var weights: Dictionary = unit["tw"].duplicate()
	if unit["is_hero"] and battle.afraid(unit):
		for key in D.FEAR_WEIGHTS:
			weights[key] = weights[key] * D.FEAR_WEIGHTS[key]
	elif attitude == "couvrir":
		weights["couvert"] = weights["couvert"] * 2.0
		weights["decouvert"] = weights["decouvert"] * 2.0
	var allowed: Array = D.CRITERIA.slice(0, unit["t_criteria"])
	var front := _front(unit, known)
	var mid = null
	if attitude == "couvrir" and not shooter.is_empty():
		mid = shooter["pos"]  # (se couvrir : vers le tireur, voir « avance » dans _score)
	if not ward.is_empty():
		var threat: Dictionary = battle._nearest(ward, known)
		if not threat.is_empty():
			mid = (ward["pos"] + _foe_pos(unit, threat)) / 2.0
	var current = unit["tactic"].get("cell") if not unit["tactic"].is_empty() else null
	var best_score := -INF
	var best_cell = BattleMap.center(battle._cell_of(unit["pos"]))
	var best_parts: Dictionary = {}
	for entry in _candidates(unit):
		var cell: Vector2i = entry[0]
		var parts := _score(unit, cell, entry[1], known, allies, allowed, weights, front, attitude, mid, current)
		var total := 0.0
		for key in parts:
			total += parts[key]
		if total > best_score + 0.0001:
			best_score = total
			best_cell = BattleMap.center(cell)
			best_parts = parts
	var reasons := []
	for key in best_parts:
		if key in ["trajet", "rester"] or absf(best_parts[key]) < 0.05:
			continue
		reasons.append({"why": "%s (%+.1f)" % [D.CRITERIA_NAMES.get(key, key), best_parts[key]], "weight": best_parts[key]})
	if unit["is_hero"] and battle.afraid(unit):
		reasons.append({"why": "a peur : cherche la place la plus sûre", "weight": 2.5})
	# Ce que la case choisie vaut de plus que rester où il est (pour décider s'il vaut la peine d'attendre).
	var here: Vector2i = battle._cell_of(unit["pos"])
	var stay := 0.0
	for value in _score(unit, here, 0.0, known, allies, allowed, weights, front, attitude, mid, null).values():
		stay += value
	return {"cell": best_cell, "reasons": reasons, "gain": best_score - stay}


## Les cases qu'il étudie : à pied depuis sa case (échelles et escaliers compris, sur les coûts du chemin), les
## plus proches d'abord, à moins de SEARCH_RADIUS cases de marche, cells_count au plus ; ni un obstacle, ni une case
## où se tient quelqu'un d'autre. [[case, distance à pied], ...].
func _candidates(unit: Dictionary) -> Array:
	var map: BattleMap = battle.map
	var start := map.index(map.nearest_walkable(battle._cell_of(unit["pos"])))
	var limit: int = unit["t_cells"]
	var dist := {start: 0.0}
	var open := [start]
	var result := []
	var max_distance := D.SEARCH_RADIUS * 1.5
	while not open.is_empty() and result.size() < limit:
		# (la plus proche d'abord ; la liste reste petite)
		var k := 0
		for j in range(1, open.size()):
			if dist[open[j]] < dist[open[k]]:
				k = j
		var i: int = open[k]
		open.remove_at(k)
		var cell := map.cell_at(i)
		if not battle._taken.has(i) or i == start:
			result.append([cell, dist[i]])
		var links: PackedInt32Array = map.out_links[i]
		var lengths: PackedFloat32Array = map.out_lengths[i]
		for n in links.size():
			var j: int = links[n]
			var d: float = dist[i] + lengths[n] * map.base_costs[j]
			if d <= max_distance and d < dist.get(j, INF):
				if not dist.has(j):
					open.append(j)
				dist[j] = d
	return result


## La direction de l'ennemi (moyenne des ennemis connus), ou sa direction de regard.
func _front(unit: Dictionary, known: Array) -> Vector2:
	var sum := Vector2.ZERO
	for foe in known:
		sum += (_foe_pos(unit, foe) - unit["pos"]).normalized()
	return sum.normalized() if sum.length() > 0.01 else unit["facing"]


## Les points d'une case, critère par critère ({critère: points}).
func _score(unit: Dictionary, cell: Vector2i, walk: float, known: Array, allies: Array, allowed: Array,
		weights: Dictionary, front: Vector2, attitude: String, mid, current) -> Dictionary:
	var map: BattleMap = battle.map
	var p := BattleMap.center(cell)
	var h := map.height_at(cell)
	var ranged: bool = unit["ranged"]
	var parts := {}
	parts["trajet"] = walk * weights["trajet"]
	if current != null and battle._cell_of(current) == cell:
		parts["rester"] = weights["rester"]
	if "hauteur" in allowed and h > 0:
		parts["hauteur"] = h * weights["hauteur"] * (D.HEIGHT_RANGED_FACTOR if ranged else 1.0)
	var nearest := INF
	var contact := 0
	for foe in known:
		var fp := _foe_pos(unit, foe)
		var d := fp.distance_to(p)
		nearest = minf(nearest, d)
		if d <= D.CONTACT_RANGE and (not foe["ranged"] or ranged):
			contact += 1
	if "distance" in allowed and ranged and nearest < INF:
		var reach: float = unit["reach"] + clampi(h, 0, GameData.HEIGHT_MAX_LEVELS) * GameData.HEIGHT_REACH_PER_LEVEL
		if nearest < unit["tt"]["shooter_range"]:
			parts["distance"] = -weights["distance"]
		elif nearest <= reach:
			parts["distance"] = weights["distance"]
	if "allies" in allowed or "isole" in allowed:
		var near_allies := 0
		var any_close := false
		for ally in allies:
			if ally["id"] == unit["id"]:
				continue
			var d: float = ally["pos"].distance_to(p)
			if d <= D.ALLY_RANGE:
				near_allies += 1
			if d <= D.ISOLATED_RANGE:
				any_close = true
		if "allies" in allowed and near_allies > 0:
			parts["allies"] = mini(near_allies, D.ALLY_MAX) * weights["allies"]
		if "isole" in allowed and not any_close and not allies.size() <= 1:
			parts["isole"] = weights["isole"]
	if ("decouvert" in allowed or "couvert" in allowed):
		var exposed := 0
		var sheltered := 0
		for foe in known:
			if not foe["ranged"]:
				continue
			if _exposed_to(foe, p, h):
				exposed += 1
			elif foe["pos"].distance_to(p) <= foe["reach"] + 2.0:
				sheltered += 1
		if "decouvert" in allowed and exposed > 0:
			parts["decouvert"] = exposed * weights["decouvert"]
		if "couvert" in allowed and sheltered > 0:
			parts["couvert"] = sheltered * weights["couvert"]
	if "encercle" in allowed:
		var extra := contact if ranged else contact - 1
		if extra > 0:
			parts["encercle"] = extra * weights["encercle"]
	if "bord" in allowed and h >= 2:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + d
			if map.walkable(next) and map.height_at(next) <= h - 2 and map.kind_at(next) != BattleMap.Kind.LADDER:
				parts["bord"] = weights["bord"]
				break
	if not ranged and ("passage" in allowed or "dos" in allowed):
		var ahead := 0
		for angle in [-45.0, 0.0, 45.0]:
			var step := _grid_step(front.rotated(deg_to_rad(angle)))
			if map.step_link(cell, cell + step) in [BattleMap.Link.WALK, BattleMap.Link.STAIRS, BattleMap.Link.CLIMB, BattleMap.Link.DROP]:
				ahead += 1
		if "passage" in allowed and ahead == 1:
			parts["passage"] = weights["passage"]
		elif "passage" in allowed and ahead == 2:
			parts["passage"] = weights["passage"] * 0.5
		if "dos" in allowed:
			var back := cell - _grid_step(front)
			if not map.walkable(back) or absi(map.height_at(back) - h) >= 2:
				parts["dos"] = weights["dos"]
	if attitude in ["decrocher", "peur"] and nearest < INF:
		parts["loin"] = minf(4.0, nearest) * weights["loin"]
	if attitude == "proteger" and mid != null:
		parts["proteger"] = maxf(0.0, 1.5 - p.distance_to(mid)) * weights["proteger"]
	if attitude == "couvrir" and mid != null:
		# Se couvrir pour avancer : les cases qui le rapprochent du tireur.
		parts["avance"] = (unit["pos"].distance_to(mid) - p.distance_to(mid)) * weights["avance"]
	return parts


## Le pas de grille le plus proche d'une direction (une des 8 voisines).
func _grid_step(direction: Vector2) -> Vector2i:
	return Vector2i(roundi(direction.x), roundi(direction.y))


## Un tireur ennemi verrait-il et atteindrait-il ce point (à cette hauteur) sans couvert ?
func _exposed_to(shooter: Dictionary, p: Vector2, h: int) -> bool:
	var reach: float = shooter["reach"] + clampi(battle.height_of(shooter) - h, 0, GameData.HEIGHT_MAX_LEVELS) * GameData.HEIGHT_REACH_PER_LEVEL
	if shooter["pos"].distance_to(p) > reach + 0.5:
		return false
	if not battle.map.line_of_sight(shooter["pos"], battle.height_of(shooter), p, h):
		return false
	return not _covered_at(p, h, shooter)


## Couvert à ce point (même règle que Battle._covered : un muret, un rocher ou un obstacle plus haut, du côté du
## tireur ; un tireur bien plus haut tire par-dessus).
func _covered_at(p: Vector2, h: int, shooter: Dictionary) -> bool:
	var map: BattleMap = battle.map
	var cell := map.cell_of(p)
	var toward: Vector2 = (shooter["pos"] - p).normalized()
	for d in BattleMap.DIRECTIONS:
		var c: Vector2i = cell + d
		if not map.in_bounds(c) or not map.kind_at(c) in [BattleMap.Kind.LOW_WALL, BattleMap.Kind.ROCK, BattleMap.Kind.BLOCK]:
			continue
		var top := maxi(map.height_at(c), 1)
		if top <= h or battle.height_of(shooter) >= top + GameData.COVER_IGNORE_LEVELS:
			continue
		if Vector2(d).normalized().dot(toward) > 0.7:
			return true
	return false


# ---------------------------------------------------------------------------
# Posté par le Maître
# ---------------------------------------------------------------------------

## Un héros posté par un ordre du Maître tient sa position : il frappe ce qui entre à sa portée, revient à son poste
## s'il en a été poussé, et ne bouge pas plus. Un danger grave (sous danger_hp de sa vie, au moins retreat_foes
## ennemis au contact) le libère : l'IA reprend (il décroche). Renvoie faux s'il n'est plus posté.
func hold(unit: Dictionary, known: Array, foes: Array) -> bool:
	var th: Dictionary = unit["tt"]
	var contacts := known.filter(func(foe): return foe["pos"].distance_to(unit["pos"]) <= D.CONTACT_RANGE)
	if float(unit["hp"]) / unit["max_hp"] < th["danger_hp"] and contacts.size() >= th["retreat_foes"]:
		unit["held"] = false
		battle._log("%s, en danger, quitte son poste." % battle._name_with_stars(unit), "disobey")
		return false
	unit["tactic"] = {"attitude": "poste", "cell": unit["post"], "target": -1,
		"reasons": [{"why": "posté par le Maître", "weight": 10.0}], "t": battle.time}
	var victim := _in_reach_target(unit, known, {})
	if not victim.is_empty():
		unit["target_id"] = victim["id"]
		battle._try_attack(unit, victim, foes)
	elif unit["pos"].distance_to(unit["post"]) > 0.3:
		battle._move_towards(unit, unit["post"])
	return true
