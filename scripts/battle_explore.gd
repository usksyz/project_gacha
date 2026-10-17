class_name BattleExplore
extends RefCounted
## L'exploration des héros (étape E, demande du porteur du projet : « on ne place pas les personnages, ils explorent,
## découvrent le terrain, jouent en équipe ou se séparent » ; ajout du projet).
##
## Le Maître ne place plus ses héros avant le combat. Tant qu'un héros ne connaît aucun ennemi (perception de C3), il
## explore : les cases que les bâtonnets des héros ont parcourues sont « explorées » (« explored ») ; l'équipe suit
## un meneur (un Meneur debout, sinon le plus audacieux) vers la case inexplorée la plus proche, en préférant le côté
## ennemi. Chacun selon son caractère (« role », lu une fois par combat par PersonalityEngine) :
## - « meneur » : il choisit où aller ;
## - « eclaireur » (Curieux ou Assassin) : il part devant, jamais à plus de SCOUT_AHEAD cases du meneur ;
## - « solitaire » (pas loyal, ou très audacieux et sans empathie) : il explore de son côté ;
## - « prudent » (peu audacieux) : il ferme la marche ;
## - « suit » : il marche à quelques pas derrière le meneur (les tireurs un peu plus loin).
## Dès qu'il connaît un ennemi, l'IA tactique (BattleTactics) reprend la main. Un héros posté par le Maître (ordre
## « aller ») garde son poste. Aucun tirage au hasard. En horde (survie, défense), les héros gardent leur ligne de
## départ comme avant.

var battle  # Battle (pas de type : les deux classes se connaissent)
## Le moment où chaque case a été vue pour la dernière fois par un héros (indice : BattleMap.index ; -1 : jamais).
## Une case est « explorée » pendant EXPLORE_FORGET secondes : ensuite, les héros y repassent (un monstre qui rôde a pu
## y revenir).
var explored := PackedFloat32Array()
## Le meneur de l'exploration (numéro du pion, -1 : aucun), la case visée par l'équipe.
var leader_id := -1
var goal := Vector2(-1, -1)
var _goal_t := 0.0  # moment où ce but a été choisi (au bout de GOAL_MAX, on le laisse : un toit qu'on ne voit pas d'en bas...)
## Le rôle de chaque héros ({numéro: rôle}) et le but de chaque solitaire ({numéro: case visée}).
var roles := {}
var _solo := {}
var _due := 0.0
var _announced := false
## Ralliement (« se place en position, puis attaque ») : le point où l'équipe se rassemble après avoir repéré des
## monstres qui ne l'ont pas vue, depuis quand, et si l'assaut est lancé.
var rally := Vector2(-1, -1)
var rally_t := -1.0
var assault := false


func _init(owner) -> void:
	battle = owner


func setup() -> void:
	explored.resize(battle.GRID_W * battle.GRID_H)
	explored.fill(-1000.0)
	for hero in battle.heroes:
		roles[hero["id"]] = _role_of(hero)


## Une case vue par un héros (appelé par BattlePerception._cast).
func mark(cell: Vector2i) -> void:
	if battle.map.in_bounds(cell):
		explored[battle.map.index(cell)] = battle.time


## Les cases autour d'une case (à « radius » cases), d'un coup : là où l'on se tient, on a tout vu.
func _mark_around(cell: Vector2i, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			mark(cell + Vector2i(dx, dy))


func is_explored(cell: Vector2i) -> bool:
	return battle.map.in_bounds(cell) and battle.time - explored[battle.map.index(cell)] < GameData.EXPLORE_FORGET


## Un héros qui ne connaît aucun ennemi : il explore (selon son rôle). Renvoie faux s'il ne le fait pas (posté par le
## Maître, ou en horde : il garde son poste comme avant).
func think(hero: Dictionary) -> bool:
	if battle.alert.disposition == "horde" or hero["held"] or not hero["order"].is_empty():
		return false
	if battle.time >= _due:
		_due = battle.time + GameData.EXPLORE_REPLAN - 0.0001
		_replan()
	var leader: Dictionary = battle.units[leader_id] if leader_id >= 0 else {}
	if leader.is_empty():
		return false
	var role: String = "meneur" if hero["id"] == leader_id else roles.get(hero["id"], "suit")
	var target: Vector2
	if rally.x >= 0.0 and not assault and role != "solitaire":
		role = "ralliement"  # (un allié a repéré l'ennemi : il le rejoint)
	match role:
		"ralliement":
			target = rally
		"meneur":
			target = goal
			# Arrivé près du but (ou trop longtemps dessus) : il est exploré, on en choisit un autre.
			if hero["pos"].distance_to(goal) <= 1.5 or battle.time - _goal_t > GameData.EXPLORE_GOAL_MAX:
				_mark_around(battle.map.cell_of(goal), 1)
				_due = 0.0
		"solitaire":
			target = _solo.get(hero["id"], goal)
		"eclaireur":
			target = goal
			# Pas trop loin devant : il attend que le meneur le rattrape.
			if hero["pos"].distance_to(leader["pos"]) > GameData.SCOUT_AHEAD and hero["pos"].distance_to(goal) < leader["pos"].distance_to(goal):
				target = hero["pos"]
		_:
			# Derrière le meneur, à quelques pas (les tireurs et les prudents plus loin), un peu de côté.
			var heading: Vector2 = (goal - leader["pos"]).normalized() if goal.distance_to(leader["pos"]) > 0.1 else Vector2(0, -1)
			var back := 2.4 if hero["ranged"] or role == "prudent" else 1.3
			var side: float = (hero["id"] % 3 - 1) * 1.2
			target = leader["pos"] - heading * back + heading.orthogonal() * side
			target = BattleMap.center(battle.map.cell_of(target))
			if not battle.map.walkable(battle.map.cell_of(target)):
				target = leader["pos"]
	hero["post"] = hero["pos"]  # (il n'a plus de ligne de départ à tenir)
	_mark_around(battle.map.cell_of(hero["pos"]), 1)
	if hero["pos"].distance_to(target) > 0.7:
		hero["pace"] = GameData.EXPLORE_PACE
		battle._move_towards(hero, target)
	return true


## Il connaît des monstres qui ne l'ont pas repéré (aucun n'est en alerte, ni tout près de lui) : il ne charge pas
## seul. Le premier qui les voit fixe le point de ralliement ; chacun l'y attend, sans avancer vers l'ennemi, jusqu'à
## ce que l'équipe soit rassemblée (à moins de GATHER_RADIUS cases), ou au plus GATHER_MAX secondes ; alors l'équipe
## passe à l'attaque (l'IA tactique reprend la main). Un solitaire n'attend personne. Renvoie vrai s'il attend.
func stalk(hero: Dictionary, known: Array) -> bool:
	if battle.alert.alarm or assault or known.is_empty() or hero["held"] or not hero["order"].is_empty():
		return false
	if roles.get(hero["id"], "") == "solitaire":
		return false
	for foe in known:
		if foe["state"] == "alerte" or hero["pos"].distance_to(foe["pos"]) <= GameData.STAMINA_CONTACT_RANGE:
			_launch("")  # (on l'a repéré, ou il est au contact : plus de discrétion)
			return false
	var standing: Array = battle._alive(battle.heroes).filter(func(h): return not battle.panicking(h) \
		and roles.get(h["id"], "") != "solitaire")
	if rally.x < 0.0:
		rally = hero["pos"]
		rally_t = battle.time
		if standing.size() > 1:
			battle._log("%s a repéré des ennemis qui ne l'ont pas vu : l'équipe se rassemble." % hero["name"])
	if standing.all(func(h): return h["pos"].distance_to(rally) <= GameData.GATHER_RADIUS) \
			or battle.time - rally_t >= GameData.GATHER_MAX:
		_launch("L'équipe est en position : elle passe à l'attaque !" if standing.size() > 1 else "")
		return false
	hero["target_id"] = -1
	hero["post"] = hero["pos"]
	if hero["pos"].distance_to(rally) > GameData.GATHER_RADIUS * 0.6:
		hero["pace"] = GameData.EXPLORE_PACE
		battle._move_towards(hero, rally)
	return true


func _launch(text: String) -> void:
	if assault:
		return
	assault = true
	if text != "":
		battle._log(text)


## Le texte du mode dev : son rôle dans l'exploration.
func role_text(hero: Dictionary) -> String:
	var role: String = "meneur" if hero["id"] == leader_id else roles.get(hero["id"], "suit")
	if rally.x >= 0.0 and not assault and role != "solitaire":
		return "rejoint le point de ralliement"
	return {"meneur": "mène l'exploration", "eclaireur": "éclaireur", "solitaire": "explore seul", "prudent": "ferme la marche",
		"suit": "suit le meneur"}.get(role, role)


# ---------------------------------------------------------------------------
# Plan de l'équipe
# ---------------------------------------------------------------------------

func _replan() -> void:
	var standing: Array = battle._alive(battle.heroes).filter(func(h): return not battle.panicking(h))
	if standing.is_empty():
		leader_id = -1
		return
	# Le meneur : un Meneur d'abord, sinon le plus audacieux (le plus haut niveau à égalité).
	var best: Dictionary = {}
	var best_score := -INF
	for hero in standing:
		var score: float = PersonalityEngine.axis(hero["source"], "AUD") + hero["level"] * 0.1
		if GameData.has_trait(hero["source"], "Meneur"):
			score += 1000.0
		if roles.get(hero["id"], "") == "solitaire":
			score -= 500.0
		if score > best_score:
			best_score = score
			best = hero
	# Plus personne ne connaît d'ennemi après un assaut : l'équipe repart en exploration (et se ralliera au prochain
	# groupe repéré).
	if assault and standing.all(func(h): return h["knows"].is_empty()):
		assault = false
		rally = Vector2(-1, -1)
	# Un ralliement sans suite (les monstres repérés se sont éloignés, plus personne ne les voit) : on repart.
	if rally.x >= 0.0 and not assault and battle.time - rally_t > GameData.GATHER_MAX \
			and standing.all(func(h): return h["knows"].is_empty()):
		rally = Vector2(-1, -1)
	var new_leader: int = best["id"]
	if not _announced:
		_announced = true
		battle._log("L'équipe part explorer le terrain, menée par %s." % best["name"])
		for hero in standing:
			if hero["id"] == new_leader:
				continue
			match roles.get(hero["id"], ""):
				"eclaireur":
					battle._log("%s part en éclaireur." % hero["name"])
				"solitaire":
					battle._log("%s s'éloigne pour explorer de son côté." % hero["name"])
	elif new_leader != leader_id:
		battle._log("%s mène maintenant l'exploration." % best["name"])
	leader_id = new_leader
	# Le but de l'équipe : on le garde tant qu'il reste à découvrir.
	if goal.x < 0.0 or is_explored(battle.map.cell_of(goal)):
		goal = _frontier(best["pos"])
		_goal_t = battle.time
	for hero in standing:
		if roles.get(hero["id"], "") == "solitaire":
			var mine: Vector2 = _solo.get(hero["id"], Vector2(-1, -1))
			if mine.x < 0.0 or is_explored(battle.map.cell_of(mine)):
				_solo[hero["id"]] = _frontier(hero["pos"])


## La case inexplorée la plus proche (où l'on peut se tenir), en préférant le côté ennemi (le haut de la carte). Tout
## est exploré : le camp ennemi (le haut de la carte), où ils finiront bien par trouver quelqu'un.
func _frontier(from: Vector2) -> Vector2:
	var best := Vector2(battle.GRID_W / 2.0, 2.5)
	var best_score := INF
	for i in explored.size():
		var cell: Vector2i = battle.map.cell_at(i)
		if is_explored(cell):
			continue
		if not battle.map.walkable(cell) or battle.map.kind_at(cell) == BattleMap.Kind.LADDER:
			continue
		var center := BattleMap.center(cell)
		var score := from.distance_to(center) + cell.y * GameData.EXPLORE_FORWARD
		if score < best_score:
			best_score = score
			best = center
	return best


## Son rôle, selon son caractère (lu une fois par combat).
func _role_of(hero: Dictionary) -> String:
	if not hero["person"]:
		return "suit"
	var source: Dictionary = hero["source"]
	var audacity: int = PersonalityEngine.axis(source, "AUD")
	if PersonalityEngine.axis(source, "LOY") <= -GameData.LONER_LOY \
			or (audacity >= GameData.LONER_AUD and PersonalityEngine.axis(source, "EMP") <= 0):
		return "solitaire"
	if hero["class"] == "Assassin" or PersonalityEngine.axis(source, "CUR") >= GameData.SCOUT_CUR:
		return "eclaireur"
	if audacity <= -GameData.PRUDENT_AUD:
		return "prudent"
	return "suit"
