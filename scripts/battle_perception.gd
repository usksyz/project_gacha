class_name BattlePerception
extends RefCounted
## La perception en bâtonnets (cahier, onglet « Combat v2 », section 4 ; étape C3).
##
## Chaque combattant « voit » par un éventail de bâtonnets (rayons) partant de ses yeux, vers l'avant. Un
## bâtonnet s'arrête sur un obstacle ou un relief plus haut que ses yeux ; un combattant touché par un bâtonnet,
## et dont le corps dépasse du décor (ligne de vue 3D de C1, BattleMap.line_of_sight), est vu. Tout autour, il
## entend (un petit cercle ; plus grand pour les bêtes, qui ont l'odorat). Ce qu'il a vu ou entendu, il s'en
## souvient quelques secondes (sa dernière position). Les alliés à portée de voix partagent ce qu'ils voient ;
## un Meneur le partage avec toute l'équipe.
##
## Ce que le combat en fait (battle.gd) : on ne cible que ce que l'on connaît ; un coup venu d'un ennemi qui
## n'est pas dans ses bâtonnets est une attaque surprise (voir Battle._surprise).
## Mise à jour toutes les GameData.PERCEPTION_INTERVAL secondes, sans aucun tirage au hasard (le combat reste le
## même à graine égale, avec ou sans écran). Chiffres dans GameData (tower.gd, « Perception en bâtonnets »).
## L'Acuité des sens, la Maîtrise de soi, la Prudence et la Méfiance, le Rythme sont lus par PersonalityEngine
## (jamais dans le profil directement).
##
## Ce qu'un combattant garde (dans son dictionnaire, voir Battle._make_fighter) :
## - « facing » : la direction où il regarde (vers sa cible, sinon là où il va) ;
## - « rays » : le bout de chacun de ses bâtonnets (pour l'affichage « lidar ») ;
## - « sees » : {numéro: vrai} les ennemis touchés par ses bâtonnets à la dernière mise à jour ;
## - « hears » : {numéro: vrai} ceux qu'il entend ;
## - « knows » : {numéro: {"pos", "t"}} ce qu'il sait de chaque ennemi (vu, entendu ou appris d'un allié) :
##   sa dernière position connue et le moment ; oublié après sa mémoire (memory).

var battle  # Battle (pas de type : les deux classes se connaissent)
## Prochain moment de mise à jour.
var _due := 0.0
## Moment de la dernière mise à jour (ce qui y a été vu est « vu maintenant »).
var updated_at := -1.0
## Les ennemis qu'au moins un héros voit ou entend en ce moment ({numéro: vrai}) : les autres sont grisés à l'écran.
var seen_by_heroes := {}


func _init(owner) -> void:
	battle = owner


## À chaque pas : met la perception à jour toutes les PERCEPTION_INTERVAL secondes.
func tick() -> void:
	if battle.time < _due:
		return
	_due = battle.time + GameData.PERCEPTION_INTERVAL - 0.0001
	update()


## Met à jour ce que chacun voit, entend, et sait (partage compris).
func update() -> void:
	updated_at = battle.time
	_alive_heroes = battle._alive(battle.heroes)
	_alive_enemies = battle._alive(battle.enemies)
	var present: Array = _alive_heroes + _alive_enemies
	_hero_leader = _alive_heroes.any(func(hero): return _leads(hero))
	for unit in present:
		_turn_head(unit)
		_look(unit)
	for unit in present:
		_learn(unit)
	seen_by_heroes.clear()
	for hero in battle._alive(battle.heroes):
		for id in hero["sees"]:
			seen_by_heroes[id] = true
		for id in hero["hears"]:
			seen_by_heroes[id] = true


# ---------------------------------------------------------------------------
# Regarder
# ---------------------------------------------------------------------------

## La direction où il regarde : vers la menace connue la plus proche si elle est tout près (WATCH_RANGE), sinon
## vers sa cible (connue), sinon dans le sens où il marche.
const WATCH_RANGE := 3.0


func _turn_head(unit: Dictionary) -> void:
	var closest = null
	var best := WATCH_RANGE
	for foe in _foes(unit):
		var pos = known_pos(unit, foe)
		if pos != null and pos.distance_to(unit["pos"]) < best and pos.distance_to(unit["pos"]) > 0.05:
			best = pos.distance_to(unit["pos"])
			closest = pos
	if closest != null:
		unit["facing"] = (closest - unit["pos"]).normalized()
		return
	var target_id: int = unit.get("target_id", -1)
	if target_id >= 0 and target_id < battle.units.size():
		var target: Dictionary = battle.units[target_id]
		if target["hp"] > 0 and target["present"] and target["is_hero"] != unit["is_hero"]:
			var known = known_pos(unit, target)
			if known != null and known.distance_to(unit["pos"]) > 0.05:
				unit["facing"] = (known - unit["pos"]).normalized()
				return
	var moved: Vector2 = unit["pos"] - unit["prev_pos"]
	if moved.length() > 0.02:
		unit["facing"] = moved.normalized()


## Lance ses bâtonnets (et son ouïe) : ce qu'il voit et entend maintenant.
func _look(unit: Dictionary) -> void:
	var source: Dictionary = unit["source"]
	var person: bool = unit["person"]
	if not unit.has("acuity"):  # (lus une fois par combat)
		unit["acuity"] = PersonalityEngine.axis(source, "ACU") / 10 if person else 0  # (palier, -10 à +10)
		unit["glancer"] = person and _glances(unit)
	var acuity: int = unit["acuity"]
	# (étape E) Un guetteur balaie du regard ; un dormeur ne voit rien, un monstre au repos moins, un guetteur plus.
	var sweep: Vector2 = battle.alert.facing_for(unit) if battle.alert != null else Vector2.ZERO
	if sweep != Vector2.ZERO:
		unit["facing"] = sweep
	var sight: float = battle.alert.sight_factor(unit) if battle.alert != null else 1.0
	# (étape E) Un embusqué ne se voit que de près (plus loin pour qui a l'œil vif).
	unit["spot_hidden"] = GameData.HIDDEN_SIGHT * (1.0 + maxi(0, acuity) * GameData.HIDDEN_ACUITY)
	var facing: Vector2 = unit["facing"]
	# Un regard en arrière (Prudence, Méfiance) : ce tour-ci, il regarde derrière lui.
	if unit["glancer"] and battle.time >= unit["glance_at"]:
		unit["glance_at"] = battle.time + GameData.GLANCE_SECONDS
		facing = -facing
	var count := maxi(GameData.SIGHT_MIN_RAYS, GameData.SIGHT_RAYS + int(acuity / GameData.SIGHT_ACUITY_TIERS_PER_RAY))
	var angle := GameData.SIGHT_ANGLE
	var length := GameData.SIGHT_LENGTH * (1.0 + acuity * GameData.SIGHT_ACUITY_LENGTH)
	if not person:
		length *= GameData.SIGHT_MONSTER_FACTOR
	length += battle.height_of(unit) * GameData.SIGHT_HEIGHT_BONUS
	if battle.quest.get("night", false) and not (person and PersonalityEngine.axis(source, "RYT") >= GameData.NOCTURNE_MIN):
		length *= GameData.SIGHT_NIGHT_FACTOR
	if unit["is_hero"] and (battle.afraid(unit) or battle.panicking(unit)) or unit["berserk"]:
		angle *= GameData.SIGHT_TUNNEL_FACTOR  # vision en tunnel
	if hawk_eye_active(unit):
		length *= GameData.HAWK_EYE_LENGTH_FACTOR
		angle *= GameData.HAWK_EYE_ANGLE_FACTOR
	length *= sight
	if sight <= 0.0:
		count = 0  # (il dort : aucun bâtonnet)
	var rays := PackedVector2Array()
	var sees := {}
	var foes := _foes(unit)
	# Les ennemis qu'un bâtonnet peut atteindre (assez près) : [ennemi, position relative].
	var reach := maxf(length, GameData.SIXTH_SENSE_LENGTH) + 0.5
	var candidates := []
	for foe in foes:
		var rel: Vector2 = foe["pos"] - unit["pos"]
		if rel.length() <= reach:
			candidates.append([foe, rel])
	var half := angle / 2.0
	for i in count:
		var a := -half + angle * i / maxf(1.0, count - 1.0)
		var side := absf(a) / half if half > 0.0 else 0.0
		var ray_length := length * lerpf(1.0, GameData.SIGHT_SIDE_FACTOR, side)
		_cast(unit, facing.rotated(deg_to_rad(a)), ray_length, rays, sees, candidates)
	# Sixième sens : quelques bâtonnets courts vers l'arrière.
	if person and GameData.skill_level(unit["skills"], "Sixième sens") > 0:
		var back := -facing
		var spread := GameData.SIXTH_SENSE_ANGLE
		for i in GameData.SIXTH_SENSE_RAYS:
			var a := -spread / 2.0 + spread * i / maxf(1.0, GameData.SIXTH_SENSE_RAYS - 1.0)
			_cast(unit, back.rotated(deg_to_rad(a)), GameData.SIXTH_SENSE_LENGTH, rays, sees, candidates)
	unit["rays"] = rays
	unit["sees"] = sees
	# L'ouïe : tout autour, sans voir (à peu près à la même hauteur).
	var hearing := GameData.HEARING_RADIUS
	if not person and unit["base_name"] in GameData.EMBED_BEASTS:
		hearing = GameData.HEARING_BEAST_RADIUS
	hearing *= 1.0 + acuity * GameData.SIGHT_ACUITY_LENGTH
	if battle.alert != null:
		hearing *= battle.alert.hearing_factor(unit)
	var hears := {}
	for entry in candidates:
		var foe: Dictionary = entry[0]
		if battle.alert != null and battle.alert.hidden(foe) and entry[1].length() > unit["spot_hidden"]:
			continue  # (un embusqué immobile ne fait pas de bruit)
		if entry[1].length() <= hearing and absi(battle.height_of(foe) - battle.height_of(unit)) <= 1:
			hears[foe["id"]] = true
	unit["hears"] = hears


## Un bâtonnet : il avance de case en case (toutes les cases qu'il traverse) jusqu'à « length » ; un relief plus
## haut que ses yeux (ou un obstacle) l'arrête ; les herbes hautes, vues du sol, le raccourcissent. Son bout est
## ajouté à « rays » ; les ennemis de « candidates » qu'il touche (et qu'on voit vraiment, en 3D) vont dans « sees ».
func _cast(unit: Dictionary, direction: Vector2, length: float, rays: PackedVector2Array, sees: Dictionary,
		candidates: Array) -> void:
	var map: BattleMap = battle.map
	var origin: Vector2 = unit["pos"]
	var z: int = battle.height_of(unit)
	var eye := z + BattleMap.EYE_HEIGHT
	var cell := map.cell_of(origin)
	var start := cell
	# Parcours des cases traversées (pas à pas d'une limite de case à la suivante).
	var step_x := 1 if direction.x > 0.0 else -1
	var step_y := 1 if direction.y > 0.0 else -1
	var delta_x := absf(1.0 / direction.x) if absf(direction.x) > 0.00001 else INF
	var delta_y := absf(1.0 / direction.y) if absf(direction.y) > 0.00001 else INF
	var next_x := ((cell.x + 1 - origin.x) if step_x > 0 else (origin.x - cell.x)) * delta_x
	var next_y := ((cell.y + 1 - origin.y) if step_y > 0 else (origin.y - cell.y)) * delta_y
	var stop := length
	while true:
		var t := minf(next_x, next_y)
		if t >= stop:
			break
		if next_x < next_y:
			cell.x += step_x
			next_x += delta_x
		else:
			cell.y += step_y
			next_y += delta_y
		if not map.in_bounds(cell):
			stop = t
			break
		if unit["is_hero"] and battle.explore != null:
			battle.explore.mark(cell)  # (étape E) une case vue : explorée
		var top := map.height_at(cell)
		var kind := map.kind_at(cell)
		if kind == BattleMap.Kind.BLOCK:
			top = maxi(top, 1)
		if top > eye:
			stop = t
			break
		if z == 0 and kind == BattleMap.Kind.GRASS and cell != start:
			stop -= GameData.SIGHT_GRASS_COST - 1.0
	stop = maxf(0.0, minf(stop, length))
	rays.append(origin + direction * stop)
	# Qui ce bâtonnet touche-t-il ? Un corps à moins d'une demi-case de lui, avant son bout.
	for entry in candidates:
		var foe: Dictionary = entry[0]
		if sees.has(foe["id"]):
			continue
		var rel: Vector2 = entry[1]
		var along := rel.dot(direction)
		if along <= 0.0 or along > stop + 0.5:
			continue
		if absf(rel.cross(direction)) > 0.5:
			continue
		if battle.alert != null and battle.alert.hidden(foe) and along > unit["spot_hidden"]:
			continue  # (étape E) embusqué : trop loin pour le remarquer
		if map.line_of_sight(origin, z, foe["pos"], battle.height_of(foe)):
			sees[foe["id"]] = true


## Les adversaires sur le terrain et debout (calculés une fois par mise à jour).
var _alive_heroes: Array = []
var _alive_enemies: Array = []
## Un Meneur debout chez les héros (à cette mise à jour) : il partage avec toute l'équipe.
var _hero_leader := false


func _foes(unit: Dictionary) -> Array:
	return _alive_enemies if unit["is_hero"] else _alive_heroes


## Prudence ou Méfiance : il regarde régulièrement derrière lui.
func _glances(unit: Dictionary) -> bool:
	var source: Dictionary = unit["source"]
	return PersonalityEngine.axis(source, "AUD") <= -GameData.GLANCE_AXIS \
		or PersonalityEngine.axis(source, "LOY") <= -GameData.GLANCE_AXIS


# ---------------------------------------------------------------------------
# Savoir et partager
# ---------------------------------------------------------------------------

## Ce qu'il sait maintenant : ce qu'il voit et entend, ce que voient les alliés à portée de voix (toute l'équipe
## s'il y a un Meneur debout), et ce dont il se souvient encore.
func _learn(unit: Dictionary) -> void:
	var knows: Dictionary = unit["knows"]
	var now: float = battle.time
	var sources := [unit]
	if not battle.panicking(unit):
		var allies: Array = _alive_heroes if unit["is_hero"] else _alive_enemies
		var leader: bool = unit["is_hero"] and _hero_leader
		for ally in allies:
			if ally["id"] == unit["id"] or battle.panicking(ally):
				continue
			if leader or ally["pos"].distance_to(unit["pos"]) <= GameData.VOICE_RANGE:
				sources.append(ally)
	for who in sources:
		for id in who["sees"]:
			knows[id] = {"pos": battle.units[id]["pos"], "t": now}
		for id in who["hears"]:
			knows[id] = {"pos": battle.units[id]["pos"], "t": now}
	# Oubli : après sa mémoire, ou si l'ennemi est tombé.
	if not unit.has("memory"):
		unit["memory"] = memory_seconds(unit)
	var memory: float = unit["memory"]
	for id in knows.keys():
		var foe: Dictionary = battle.units[id]
		if foe["hp"] <= 0 or not foe["present"] or now - knows[id]["t"] > memory:
			knows.erase(id)


## Un Meneur debout, qui n'a ni peur ni panique : il partage ce que voit l'équipe.
func _leads(hero: Dictionary) -> bool:
	if not hero.has("leader_trait"):
		hero["leader_trait"] = GameData.has_trait(hero["source"], "Meneur")  # (lu une fois par combat)
	return hero["leader_trait"] and not battle.panicking(hero) and not battle.afraid(hero)


## Sa mémoire, en secondes (Maîtrise de soi, Intelligence).
func memory_seconds(unit: Dictionary) -> float:
	if not unit["person"]:
		return GameData.SIGHT_MEMORY
	var source: Dictionary = unit["source"]
	var seconds: float = GameData.SIGHT_MEMORY + PersonalityEngine.axis(source, "MAI") / 10.0 * GameData.SIGHT_MEMORY_PER_MAI \
		+ (source["stats"]["int"] - 10) * GameData.SIGHT_MEMORY_PER_INT
	return clampf(seconds, GameData.SIGHT_MEMORY_MIN, GameData.SIGHT_MEMORY_MAX)


## Connaît-il cet ennemi (vu, entendu, appris d'un allié, ou encore en mémoire) ?
func knows(unit: Dictionary, foe: Dictionary) -> bool:
	return unit["knows"].has(foe["id"])


## Le sait-il en ce moment (à la dernière mise à jour, pas seulement de mémoire) ?
func knows_now(unit: Dictionary, foe: Dictionary) -> bool:
	var entry: Dictionary = unit["knows"].get(foe["id"], {})
	return not entry.is_empty() and entry["t"] >= updated_at - 0.0001


## Où il croit que se trouve cet ennemi : sa vraie place s'il le sait en ce moment, sinon la dernière place
## connue ; null s'il ne le connaît pas.
func known_pos(unit: Dictionary, foe: Dictionary):
	var entry: Dictionary = unit["knows"].get(foe["id"], {})
	if entry.is_empty():
		return null
	return foe["pos"] if entry["t"] >= updated_at - 0.0001 else entry["pos"]


## Le voit-il de ses propres yeux (ses bâtonnets) ? Sinon, un coup de lui est une surprise.
func sees(unit: Dictionary, foe: Dictionary) -> bool:
	return unit["sees"].has(foe["id"])


# ---------------------------------------------------------------------------
# Œil de faucon (compétence active)
# ---------------------------------------------------------------------------

func hawk_eye_active(unit: Dictionary) -> bool:
	return battle.time < unit.get("hawk_until", 0.0)


## Peut-il activer Œil de faucon maintenant ? (Il l'a, debout, pas déjà actif, temps de recharge écoulé.)
func can_hawk_eye(unit: Dictionary) -> bool:
	return unit["person"] and unit["hp"] > 0 and unit["present"] and GameData.skill_level(unit["skills"], "Œil de faucon") > 0 \
		and not hawk_eye_active(unit) and battle.time >= unit.get("hawk_ready", 0.0)


func activate_hawk_eye(unit: Dictionary) -> void:
	unit["hawk_until"] = battle.time + GameData.HAWK_EYE_SECONDS
	unit["hawk_ready"] = battle.time + GameData.HAWK_EYE_SECONDS + GameData.HAWK_EYE_COOLDOWN
	battle._log("%s plisse les yeux : Œil de faucon, sa vue porte plus loin." % battle._name_with_stars(unit), "awaken")


## De lui-même : un tireur qui a Œil de faucon l'active quand des ennemis sont sur le terrain mais qu'il n'en
## voit aucun de ses propres yeux.
func hawk_eye_think(unit: Dictionary) -> void:
	if not can_hawk_eye(unit) or not unit["ranged"] or not unit["sees"].is_empty():
		return
	if _foes(unit).is_empty():
		return
	activate_hawk_eye(unit)
