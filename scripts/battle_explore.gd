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
## Étape E, point 3 : les infiltrateurs ({numéro: vrai}) et les poseurs de pièges ({numéro: pièges qu'il lui reste}),
## lus une fois par combat ; le monstre que vise chaque infiltrateur ({héros: monstre}) ; le piège en cours de pose
## ({héros: {"cell", "t"}}).
var infiltrators := {}
var trappers := {}
var _infiltrating := {}
var _trap_work := {}
## Le monstre méfiant devant lequel chaque héros s'est figé ({héros: monstre} ; voir _hide).
var _frozen := {}
## Recensement « Techniques », point 6 : l'équipier de chaque infiltrateur ({équipier: infiltrateur}, et l'inverse dans
## « mates »), lus une fois par combat ; depuis quand chacun est à portée de sa proie et l'attend ({héros: {"since",
## "seen"}}) ; les assassinats synchronisés (mesures).
var partners := {}
var mates := {}
var _ready := {}
var _synced := {}
var counts := {"synchronises": 0, "formations": 0, "bonds_abri": 0}
## (point 7) La formation de l'équipe qui explore (« coin » ou « colonne »), le prochain message, l'abri visé par le
## meneur et la fin de sa pause.
var formation := "coin"
var _formation_logged := 0.0
var _bound_target := Vector2(-1, -1)
var _bound_wait := 0.0


func _init(owner) -> void:
	battle = owner


func setup() -> void:
	explored.resize(battle.GRID_W * battle.GRID_H)
	explored.fill(-1000.0)
	for hero in battle.heroes:
		roles[hero["id"]] = _role_of(hero)
		if hero["person"] and _is_infiltrator(hero):
			infiltrators[hero["id"]] = true
		if hero["person"] and _is_trapper(hero):
			trappers[hero["id"]] = GameData.TRAPS_PER_HERO
	setup_partners()


## (point 6) Un héros lié à un infiltrateur (au moins ami) et assez audacieux s'infiltre avec lui (un équipier par
## infiltrateur, le plus lié).
func setup_partners() -> void:
	var ids: Array = infiltrators.keys()
	ids.sort()
	for infiltrator_id in ids:
		var infiltrator: Dictionary = battle.units[infiltrator_id]
		var best := -1
		var best_level := 0
		for hero in battle.heroes:
			var level: int = infiltrator["bonds"].get(hero["id"], 0)
			if infiltrators.has(hero["id"]) or partners.has(hero["id"]) or not hero["person"] or level < GameData.BOND_FRIEND:
				continue
			if hero["class"] in ["Mage", "Soigneur"] or PersonalityEngine.axis(hero["source"], "AUD") < -GameData.PRUDENT_AUD:
				continue
			if level > best_level:
				best = hero["id"]
				best_level = level
		if best >= 0:
			partners[best] = infiltrator_id
			mates[infiltrator_id] = best


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
	if hero["held"] or not hero["order"].is_empty():
		return false
	if battle.alert.disposition == "horde":
		return false  # (en horde, il garde son poste comme avant ; pas de piège : la horde arrive trop vite)
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
			target = _bound(hero)  # (point 7) d'abri en abri vers le but
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
			# Derrière le meneur, à sa place dans la formation (point 7 : en coin à découvert, en file dans un passage
			# étroit), contre un abri tout proche s'il y en a un.
			target = _formation_slot(hero, leader, role)
	hero["post"] = hero["pos"]  # (il n'a plus de ligne de départ à tenir)
	_mark_around(battle.map.cell_of(hero["pos"]), 1)
	hero["stealth"] = stealth_of(hero)
	if hero["pos"].distance_to(target) > 0.7:
		hero["pace"] = GameData.EXPLORE_PACE
		battle._move_towards(hero, target)
	return true


## (Recensement « Techniques », point 7) La formation de l'équipe qui explore, revue à chaque plan : « colonne » (en
## file, l'un derrière l'autre) quand le passage autour du meneur est étroit (moins de FORMATION_NARROW cases libres sur
## les 9 autour de lui), sinon « coin » (en éventail derrière lui, les tireurs et les prudents plus loin).
func _formation_slot(hero: Dictionary, leader: Dictionary, role: String) -> Vector2:
	var heading: Vector2 = (goal - leader["pos"]).normalized() if goal.distance_to(leader["pos"]) > 0.1 else Vector2(0, -1)
	var target: Vector2
	if formation == "colonne":
		var rank: int = maxi(0, _followers().find(hero["id"])) + 1
		target = leader["pos"] - heading * GameData.COLUMN_SPACING * rank
	else:
		var back := 2.4 if hero["ranged"] or role == "prudent" else 1.3
		var side: float = (hero["id"] % 3 - 1) * 1.2
		target = leader["pos"] - heading * back + heading.orthogonal() * side
	var cell: Vector2i = battle.map.cell_of(target)
	if not battle.map.walkable(cell):
		return leader["pos"]
	# Un abri (herbes hautes, pied d'un mur) tout près de sa place : il s'y met.
	if battle.terrain != null:
		var cover: Vector2i = battle.terrain.nearest("hide", BattleMap.center(cell), 1.0)
		if cover.x >= 0:
			cell = cover
	return BattleMap.center(cell)


## Les héros qui suivent le meneur (dans l'ordre de leur numéro) : leur rang dans la colonne.
func _followers() -> Array:
	var ids := []
	for hero in battle._alive(battle.heroes):
		if hero["id"] != leader_id and roles.get(hero["id"], "suit") in ["suit", "prudent"]:
			ids.append(hero["id"])
	ids.sort()
	return ids


## La formation selon le passage autour du meneur (voir _formation_slot).
func _pick_formation(leader: Dictionary) -> void:
	var open := 0
	var here: Vector2i = battle.map.cell_of(leader["pos"])
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if battle.map.walkable(here + Vector2i(dx, dy)):
				open += 1
	var wanted := "colonne" if open < GameData.FORMATION_NARROW else "coin"
	if wanted != formation:
		formation = wanted
		counts["formations"] += 1
		if battle.time >= _formation_logged:
			_formation_logged = battle.time + GameData.FORMATION_LOG
			battle._log("L'équipe passe en file indienne." if wanted == "colonne" else "L'équipe se déploie en éventail.")


## (Point 7) D'abri en abri : le meneur ne marche pas droit vers son but ; il va à l'abri le plus proche qui l'en
## rapproche (à moins de BOUND_STEP cases, au moins une case plus près du but), y marque une pause (BOUND_PAUSE s), puis
## repart. Sans abri sur le chemin : droit vers le but.
func _bound(hero: Dictionary) -> Vector2:
	if battle.time < _bound_wait:
		return hero["pos"]
	if _bound_target.x >= 0.0 and hero["pos"].distance_to(_bound_target) > 0.6 \
			and _bound_target.distance_to(goal) < hero["pos"].distance_to(goal):
		return _bound_target
	if _bound_target.x >= 0.0 and hero["pos"].distance_to(_bound_target) <= 0.6:
		_bound_target = Vector2(-1, -1)
		_bound_wait = battle.time + GameData.BOUND_PAUSE
		counts["bonds_abri"] += 1
		return hero["pos"]
	if battle.terrain == null:
		return goal
	var away: float = hero["pos"].distance_to(goal)
	var cover: Vector2i = battle.terrain.nearest("hide", hero["pos"].move_toward(goal, GameData.BOUND_STEP / 2.0),
		GameData.BOUND_STEP, func(c): return BattleMap.center(c).distance_to(goal) <= away - 1.0 \
			and BattleMap.center(c).distance_to(hero["pos"]) >= 1.0)
	if cover.x < 0:
		return goal
	_bound_target = BattleMap.center(cover)
	return _bound_target


## Il connaît des monstres qui ne l'ont pas repéré (aucun n'est en alerte, ni tout près de lui) : il ne charge pas
## seul. Le premier qui les voit fixe le point de ralliement ; chacun l'y attend, sans avancer vers l'ennemi, jusqu'à
## ce que l'équipe soit rassemblée (à moins de GATHER_RADIUS cases), ou au plus GATHER_MAX secondes ; alors l'équipe
## passe à l'attaque (l'IA tactique reprend la main). Un solitaire n'attend personne. Renvoie vrai s'il attend.
func stalk(hero: Dictionary, known: Array) -> bool:
	if battle.alert.alarm or assault or known.is_empty() or hero["held"] or not hero["order"].is_empty():
		_infiltrating.erase(hero["id"])
		_trap_work.erase(hero["id"])  # (un piège pas fini est abandonné)
		return false
	# (point 6) L'équipier d'un infiltrateur encore à l'œuvre s'infiltre avec lui.
	var infiltrator: bool = infiltrators.has(hero["id"]) or _partnering(hero)
	if roles.get(hero["id"], "") == "solitaire" and not infiltrator:
		return false
	for foe in known:
		# (on l'a repéré, ou il est au contact : plus de discrétion ; un infiltrateur, lui, s'approche exprès)
		if foe["state"] == "alerte" or (not infiltrator and hero["pos"].distance_to(foe["pos"]) <= GameData.STAMINA_CONTACT_RANGE):
			_launch("")
			return false
	var standing: Array = battle._alive(battle.heroes).filter(func(h): return not battle.panicking(h) \
		and roles.get(h["id"], "") != "solitaire" and not infiltrators.has(h["id"]) and not _partnering(h))
	if rally.x < 0.0:
		rally = _rally_spot(hero, known)
		rally_t = battle.time
		if standing.size() > 1:
			battle._log("%s a repéré des ennemis qui ne l'ont pas vu : l'équipe se rassemble." % hero["name"])
	# Un infiltrateur n'attend pas : il se glisse vers un monstre pour l'assassiner.
	if infiltrator:
		return _infiltrate(hero, known)
	# Pendant qu'un infiltrateur agit sans être vu, l'équipe lui laisse un peu plus de temps.
	var wait: float = GameData.GATHER_MAX + (GameData.INFILTRATE_EXTRA if not _infiltrating.is_empty() else 0.0)
	var gathered: bool = standing.all(func(h): return h["pos"].distance_to(rally) <= GameData.GATHER_RADIUS)
	if (gathered and _infiltrating.is_empty() and _trap_work.is_empty()) or battle.time - rally_t >= wait:
		_launch("L'équipe est en position : elle passe à l'attaque !" if standing.size() > 1 else "")
		return false
	hero["target_id"] = -1
	hero["post"] = hero["pos"]
	hero["stealth"] = stealth_of(hero)
	if _hide(hero):
		return true
	# Un poseur de pièges en pose un entre le point de ralliement et l'ennemi.
	# (une fois commencé, il garde sa case même si le monstre bouge)
	var trap_cell: Vector2i = _trap_work[hero["id"]]["cell"] if _trap_work.has(hero["id"]) else Vector2i(-1, -1)
	if trappers.get(hero["id"], 0) > 0 and _work_trap(hero, trap_cell if trap_cell.x >= 0 else _trap_cell(hero, known)):
		return true
	if hero["pos"].distance_to(rally) > GameData.GATHER_RADIUS * 0.6:
		hero["pace"] = GameData.EXPLORE_PACE
		battle._move_towards(hero, rally)
	return true


## Le point de ralliement : là où il a repéré l'ennemi, ou (recensement « Techniques », point 4) une cachette toute
## proche (herbes hautes, contre un mur) qui n'est pas plus près de l'ennemi.
func _rally_spot(hero: Dictionary, known: Array) -> Vector2:
	var nearest: Dictionary = battle._nearest(hero, known)
	if battle.terrain == null or nearest.is_empty():
		return hero["pos"]
	var away: float = hero["pos"].distance_to(nearest["pos"])
	var hide: Vector2i = battle.terrain.nearest("hide", hero["pos"], GameData.RALLY_HIDE_RADIUS,
		func(c): return BattleMap.center(c).distance_to(nearest["pos"]) >= away and battle.map.height_at(c) == battle.height_of(hero))
	return BattleMap.center(hide) if hide.x >= 0 else hero["pos"]


## L'infiltrateur se glisse vers un monstre qui ne se doute de rien (un guetteur d'abord, puis le plus isolé, puis le
## plus proche) et le frappe (assassinat, voir Battle._assassination). Renvoie faux s'il n'y a plus de proie (il se
## bat alors comme les autres).
func _infiltrate(hero: Dictionary, known: Array) -> bool:
	var prey: Array = known.filter(func(f): return f["state"] != "alerte")
	# (point 6) L'équipier d'un infiltrateur prend un autre monstre, tout près de la proie de l'infiltrateur
	# (répartition des cibles) ; tant que l'infiltrateur n'a pas choisi, il attend au point de ralliement.
	var partner_of: int = partners.get(hero["id"], -1)
	if partner_of >= 0:
		var lead_prey: int = _infiltrating.get(partner_of, -1)
		if lead_prey < 0:
			hero["stealth"] = stealth_of(hero)
			if hero["pos"].distance_to(rally) > GameData.GATHER_RADIUS * 0.6:
				hero["pace"] = GameData.EXPLORE_PACE
				battle._move_towards(hero, rally)
			return true
		var lead: Dictionary = battle.units[lead_prey]
		prey = prey.filter(func(f): return f["id"] != lead_prey and f["pos"].distance_to(lead["pos"]) <= GameData.SYNC_RANGE)
	if prey.is_empty():
		_infiltrating.erase(hero["id"])
		_ready.erase(hero["id"])
		return false
	var target: Dictionary = {}
	var current: int = _infiltrating.get(hero["id"], -1)
	for foe in prey:
		if foe["id"] == current:
			target = foe
	if target.is_empty():
		var best := INF
		for foe in prey:
			var crowd := 0
			for other in battle._alive(battle.enemies):
				if other["id"] != foe["id"] and other["pos"].distance_to(foe["pos"]) <= 3.0:
					crowd += 1
			var score: float = hero["pos"].distance_to(foe["pos"]) + crowd * 2.0 - (6.0 if foe["home_state"] == "guet" else 0.0)
			if partner_of >= 0:
				score = foe["pos"].distance_to(battle.units[_infiltrating[partner_of]]["pos"])  # (au plus près de l'autre proie)
			if score < best:
				best = score
				target = foe
		_infiltrating[hero["id"]] = target["id"]
		if partner_of >= 0:
			battle._log("%s se glisse avec %s vers %s." % [hero["name"], battle.units[partner_of]["name"], target["name"]])
		else:
			battle._log("%s se glisse vers %s." % [hero["name"], target["name"]])
	hero["target_id"] = target["id"]
	hero["post"] = hero["pos"]
	hero["stealth"] = stealth_of(hero)
	if battle._in_reach(hero, target, hero["reach"]):
		if not _strike_now(hero):
			return true  # (à portée : il attend son équipier, immobile)
		battle._try_attack(hero, target, battle._alive(battle.enemies))
	else:
		_ready.erase(hero["id"])
		if not _hide(hero):
			hero["pace"] = GameData.EXPLORE_PACE
			battle._approach(hero, target)
	return true


## (point 6) L'équipier de cet infiltrateur, ou l'infiltrateur de cet équipier, s'il est encore à l'œuvre (-1 : aucun).
func _mate_of(hero: Dictionary) -> int:
	var other: int = partners.get(hero["id"], mates.get(hero["id"], -1))
	if other < 0:
		return -1
	var unit: Dictionary = battle.units[other]
	if unit["hp"] <= 0 or not unit["present"] or battle.panicking(unit) or not _infiltrating.has(other):
		return -1
	return other


## Un équipier d'infiltrateur, quand l'infiltrateur est encore debout et à l'œuvre (pas en alerte, pas d'assaut).
func _partnering(hero: Dictionary) -> bool:
	if not partners.has(hero["id"]):
		return false
	var lead: Dictionary = battle.units[partners[hero["id"]]]
	return lead["hp"] > 0 and lead["present"] and not battle.panicking(lead)


## (point 6) Assassinat synchronisé : à portée de sa proie, il attend que son équipier soit aussi à portée de la sienne
## (au plus SYNC_WAIT secondes), puis ils frappent au même pas. Sans équipier : tout de suite.
func _strike_now(hero: Dictionary) -> bool:
	var mate := _mate_of(hero)
	if mate < 0:
		return true
	var mine: Dictionary = _ready.get(hero["id"], {})
	if mine.is_empty():
		mine = {"since": battle.time}
		_ready[hero["id"]] = mine
	mine["seen"] = battle.time
	var theirs: Dictionary = _ready.get(mate, {})
	var both: bool = not theirs.is_empty() and battle.time - theirs["seen"] <= battle.TICK * 1.5
	if both:
		if not _synced.has(mini(hero["id"], mate)):
			_synced[mini(hero["id"], mate)] = true
			counts["synchronises"] += 1
			battle._log("%s et %s frappent ensemble, d'un même geste." % [hero["name"], battle.units[mate]["name"]], "awaken")
		return true
	return battle.time - mine["since"] >= GameData.SYNC_WAIT


## Jauge de détection (recensement « Techniques », point 1) : un monstre méfiant regarde vers lui (voir
## BattleAlert.watching). Il se fige (immobile, il se remarque moins : la jauge du monstre peut redescendre) ; si le
## monstre vient voir, il recule hors de sa vue. Renvoie vrai s'il se cache ainsi ce pas-ci.
func _hide(hero: Dictionary) -> bool:
	var watcher: Dictionary = battle.alert.watching(hero)
	if watcher.is_empty():
		_frozen.erase(hero["id"])
		return false
	if _frozen.get(hero["id"], -1) != watcher["id"]:
		_frozen[hero["id"]] = watcher["id"]
		battle.alert.counts["fige"] += 1
		battle._log("%s se fige : %s regarde dans sa direction." % [hero["name"], watcher["name"]])
	if watcher["state"] == "fouille":
		var away: Vector2 = (hero["pos"] - watcher["pos"]).normalized()
		var cell: Vector2i = battle.map.nearest_walkable(battle.map.cell_of(hero["pos"] + away * 2.0))
		hero["pace"] = GameData.EXPLORE_PACE
		battle._move_towards(hero, BattleMap.center(cell))
	return true


## La case du piège : TRAP_DISTANCE cases devant le point de ralliement, vers le monstre connu le plus proche (chaque
## poseur un peu de côté : tout droit, à gauche, à droite) ; une case où l'on se tient, sans piège déjà posé.
## Vector2i(-1, -1) s'il n'y en a pas.
func _trap_cell(hero: Dictionary, known: Array) -> Vector2i:
	var nearest: Dictionary = battle._nearest({"pos": rally}, known)
	if nearest.is_empty():
		return Vector2i(-1, -1)
	var order: Array = trappers.keys()
	order.sort()
	var toward: Vector2 = (nearest["pos"] - rally).normalized().rotated([0.0, 0.7, -0.7][order.find(hero["id"]) % 3])
	var spot: Vector2 = rally + toward * GameData.TRAP_DISTANCE
	var free := func(c: Vector2i) -> bool:
		return battle.map.walkable(c) and battle.map.kind_at(c) != BattleMap.Kind.LADDER \
			and not battle.traps.any(func(trap): return trap["cell"] == c)
	# (recensement « Techniques », point 4) Un goulet tout près, entre le ralliement et l'ennemi : imparable.
	if battle.terrain != null:
		var to_foe: float = rally.distance_to(nearest["pos"])
		var choke: Vector2i = battle.terrain.nearest("choke", spot, GameData.TRAP_CHOKE_RADIUS,
			func(c): return free.call(c) and BattleMap.center(c).distance_to(nearest["pos"]) < to_foe \
				and BattleMap.center(c).distance_to(rally) >= 1.5)
		if choke.x >= 0:
			return choke
	var cell: Vector2i = battle.map.cell_of(spot)
	if not free.call(cell):
		return Vector2i(-1, -1)
	return cell


## Poser un piège sur « cell » : il y va, puis il lui faut TRAP_SECONDS sur place. Renvoie vrai tant qu'il y travaille.
func _work_trap(hero: Dictionary, cell: Vector2i) -> bool:
	if cell == Vector2i(-1, -1):
		return false
	var work: Dictionary = _trap_work.get(hero["id"], {})
	if work.is_empty() or work["cell"] != cell:
		work = {"cell": cell, "t": 0.0}
	_trap_work[hero["id"]] = work
	if hero["pos"].distance_to(BattleMap.center(cell)) > 0.5:
		hero["pace"] = GameData.EXPLORE_PACE
		battle._move_towards(hero, BattleMap.center(cell))
		return true
	work["t"] += battle.TICK
	if work["t"] >= GameData.TRAP_SECONDS:
		battle.place_trap(hero, cell)
		trappers[hero["id"]] -= 1
		_trap_work.erase(hero["id"])
		return false
	return true


## Sa discrétion (voir GameData.STEALTH_FACTOR) : moins on le remarque, plus elle est basse.
func stealth_of(hero: Dictionary) -> float:
	var factor: float = GameData.INFILTRATOR_STEALTH if infiltrators.has(hero["id"]) else GameData.STEALTH_FACTOR
	factor -= GameData.skill_level(hero["skills"], "Mouvement souple") * GameData.STEALTH_PER_DODGE
	return maxf(GameData.STEALTH_MIN, factor)


## Infiltrateur : Assassin, dague en main, accès « Éclaireur », ou rusé et pas craintif ; toujours au corps à corps (un
## tireur ou un mage ne s'infiltre pas : il tirerait de loin, et sa cible crierait).
func _is_infiltrator(hero: Dictionary) -> bool:
	var source: Dictionary = hero["source"]
	if hero["ranged"] or hero["class"] in ["Mage", "Soigneur"]:
		return false
	return hero["class"] == "Assassin" or hero["weapon"] == "Dague" or "eclaireur" in PersonalityEngine.accesses(source) \
		or (PersonalityEngine.axis(source, "HON") <= -GameData.INFILTRATOR_HON and PersonalityEngine.axis(source, "AUD") >= 0)


## Poseur de pièges : accès « Tacticien », ou l'œil aux embuscades et aux pièges (composite Vigilance).
func _is_trapper(hero: Dictionary) -> bool:
	var source: Dictionary = hero["source"]
	return "tacticien" in PersonalityEngine.accesses(source) \
		or PersonalityEngine.composite(source, "vigilance") >= GameData.TRAPPER_VIGILANCE


func _launch(text: String) -> void:
	if assault:
		return
	assault = true
	if text != "":
		battle._log(text)


## Le texte du mode dev : son rôle dans l'exploration.
func role_text(hero: Dictionary) -> String:
	var role: String = "meneur" if hero["id"] == leader_id else roles.get(hero["id"], "suit")
	if _infiltrating.has(hero["id"]):
		return "s'infiltre vers %s" % battle.units[_infiltrating[hero["id"]]]["name"]
	if _trap_work.has(hero["id"]):
		return "pose un piège"
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
	_pick_formation(best)  # (point 7)
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
