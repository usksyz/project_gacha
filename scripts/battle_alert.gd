class_name BattleAlert
extends RefCounted
## La vigilance des monstres (étape E, demande du porteur du projet ; ajout du projet).
##
## Avant l'étape E, les monstres savaient toujours où étaient les héros et fonçaient sur eux (la « horde »). Désormais,
## sauf en survie, en défense et en duel, ils n'attaquent que s'ils voient ou entendent les héros (perception en
## bâtonnets de C3), et leur disposition change selon la mission (GameData.ENEMY_DISPOSITIONS) : pillage du village,
## camp gardé par des guetteurs, camp endormi, poste fortifié sur une hauteur, patrouilles, embuscade. Un monstre ne
## repère pas un héros d'un coup : sa jauge de détection monte tant qu'il le voit ou l'entend (recensement
## « Techniques de programmation pour le combat », point 1, comme Splinter Cell Blacklist ; voir _watch) ; il devient
## méfiant, va voir, puis crie ; une fausse alerte le laisse sur ses gardes (vigilance accrue, « wary ») jusqu'à la
## fin du combat. Un guetteur donne l'alarme à tout le camp ; les bruits de combat attirent les curieux. C'est ce qui rend possibles l'infiltration et l'assassinat :
## un monstre qui ne voit pas venir le coup est surpris (Battle._surprise).
##
## Ce qu'un monstre garde (voir Battle._make_fighter) : « state » (son état, voir GameData, tower.gd, « Vigilance des
## monstres »), « home_state », « home_pos », « home_facing » (sa place et son état de départ), « route » et « route_i »
## (sa ronde), « search » et « search_until » (le bruit qu'il va voir), « detect » (sa jauge, 0 à 1), « detect_pos »
## (là où il a cru voir quelqu'un), « wary » (vigilance accrue).
## Aucun tirage au hasard pendant le combat : la disposition est tirée d'un générateur à part, à partir de la graine de
## la carte (même étage, même disposition ; même graine, même combat).

var battle  # Battle (pas de type : les deux classes se connaissent)
## La disposition des ennemis dans ce combat (voir GameData.ENEMY_DISPOSITIONS) ; "horde" : comme avant l'étape E.
var disposition := "horde"
## Vrai une fois l'alarme générale donnée (toujours vrai en horde) : tous les monstres chassent les héros.
var alarm := true
## Le centre du camp (ou le sommet du poste) : les renforts en sortent tant que l'alarme n'est pas donnée.
var home := Vector2(-1, -1)
var _rng := RandomNumberGenerator.new()
## Jauge de détection (point 1 du recensement « Techniques ») : les héros qui n'ont pas bougé au dernier pas
## ({numéro: vrai}) et leur place à ce pas-là. Compteurs pour les mesures (sim_tower) : monstres devenus méfiants,
## revenus au calme sans avoir repéré personne (« fausse_alerte », après méfiance ou fouille), héros qui se sont
## figés à temps, corps découverts, compagnons disparus remarqués.
var _still := {}
var _last_pos := {}
var counts := {"mefiant": 0, "fausse_alerte": 0, "fige": 0, "cadavres": 0, "disparus": 0}
## Point 2 : les corps des monstres tombés avant l'alarme ({"pos", "name", "squad", "t", "found", "missed"} ; voir
## on_death, _look_for_corpses, _notice_missing).
var corpses: Array[Dictionary] = []
## Point 8 : le feu du camp (Vector2i(-1, -1) : aucun) et les tentes (cases devenues des obstacles bas), pour la vue.
var fire := Vector2i(-1, -1)
var tents: Array[Vector2i] = []


func _init(owner) -> void:
	battle = owner


## La disposition d'un étage : tirée de sa graine parmi celles de son type de quête (survie, défense, duel : horde).
static func disposition_for(quest: Dictionary, map_seed: int) -> String:
	if quest.get("duel", false):
		return "horde"
	var options: Array = GameData.ENEMY_DISPOSITIONS.get(quest.get("type", ""), [])
	if options.is_empty():
		return "horde"
	return options[absi(hash([map_seed, "disposition"])) % options.size()]


## Au début du combat (après le placement) : choisit la disposition et place les monstres.
func setup() -> void:
	disposition = battle.forced_disposition if battle.forced_disposition != "" \
		else disposition_for(battle.quest, int(battle.map_data.get("seed", 0)))
	if not battle.perception_on or not battle.tactical_ai or battle.quest.get("duel", false):
		disposition = "horde"  # (sans perception, tout le monde sait tout : la vigilance n'a plus de sens)
	alarm = disposition == "horde"
	for enemy in battle.enemies:
		enemy["state"] = "alerte"
	if alarm:
		return
	_rng.seed = hash([battle.map_data.get("seed", 0), disposition])
	var present: Array = battle.enemies.filter(func(e): return e["present"])
	match disposition:
		"camp":
			_arrange_camp(present, false)
		"endormis":
			_arrange_camp(present, true)
		"poste":
			_arrange_post(present)
		"patrouilles":
			_arrange_patrols(present)
		"embuscade":
			_arrange_ambush(present)
		"pillage":
			_arrange_pillage(present)


# ---------------------------------------------------------------------------
# Dispositions
# ---------------------------------------------------------------------------

## Un camp autour d'un feu (haut de la carte) : guetteurs tournés vers les héros (les tireurs d'abord), une patrouille
## qui en fait le tour, les autres au repos autour du feu. Endormi : tout le monde dort, sans guetteur ni patrouille.
func _arrange_camp(units: Array, sleeping: bool) -> void:
	var center := _pick_cell(Vector2i(5, _y(2)), Vector2i(battle.GRID_W - 6, _y(3)))
	home = BattleMap.center(center)
	var rest := units.duplicate()
	if not sleeping:
		var shooters := rest.filter(func(u): return u["ranged"])
		var others := rest.filter(func(u): return not u["ranged"])
		rest = shooters + others
		for i in mini(GameData.GUARDS_PER_CAMP, rest.size() - 1):
			var guard: Dictionary = rest.pop_front()
			var side := -3 if i == 0 else 3
			_put(guard, _best_lookout(center + Vector2i(side, 2), 1), "guet", Vector2(0, 1))
		if rest.size() >= 3:
			var walker: Dictionary = rest.pop_back()
			var route := _loop_around(center, GameData.PATROL_RADIUS)
			_put(walker, _cell_of(route[0]), "ronde", Vector2(0, 1))
			walker["route"] = route
	for i in rest.size():
		var angle := TAU * i / maxf(1.0, rest.size())
		var cell := center + Vector2i(roundi(cos(angle) * 2.0), roundi(sin(angle) * 1.6))
		var unit: Dictionary = rest[i]
		_put(unit, cell, "sommeil" if sleeping else "repos", (home - BattleMap.center(cell)).normalized())
	for unit in units:
		unit["squad"] = 0  # (point 2 : un seul groupe, le camp)
	_pitch_tents(center, units)


## (Recensement « Techniques », point 8 : morceaux faits main pour les camps ; ajout du projet.) Le feu au centre du camp
## (« fire », dessiné par la vue) et TENTS_PER_CAMP tentes autour, à TENT_RADIUS cases : de vrais obstacles bas (on
## s'abrite derrière, ils cachent un héros accroupi), posés sur le sol libre, loin des places des monstres et de la ronde.
## La carte du combat change (pas celle de l'étage, gardée dans la sauvegarde) : les chemins et l'annotation sont refaits.
func _pitch_tents(center: Vector2i, units: Array) -> void:
	fire = center
	var avoid := {}
	for unit in units:
		avoid[_cell_of(unit["pos"])] = true
		for point in unit.get("route", []):
			avoid[_cell_of(point)] = true
	var start := _rng.randf_range(0.0, TAU)
	for i in GameData.TENTS_PER_CAMP:
		var angle := start + TAU * i / GameData.TENTS_PER_CAMP
		var cell := center + Vector2i(roundi(cos(angle) * GameData.TENT_RADIUS), roundi(sin(angle) * GameData.TENT_RADIUS * 0.8))
		if not battle.map.in_bounds(cell) or not _standable(cell) or battle.map.height_at(cell) != 0 or avoid.has(cell):
			continue
		if battle.map.kind_at(cell) == BattleMap.Kind.LADDER or (cell - center).length() < 2.0:
			continue
		battle.map.kinds[battle.map.index(cell)] = BattleMap.Kind.BLOCK
		battle.map.heights[battle.map.index(cell)] = 1
		tents.append(cell)
	if not tents.is_empty():
		battle.map.build_graph()
		battle.terrain = BattleTerrain.new(battle.map)


## Un poste fortifié : la hauteur la plus haute de la moitié ennemie ; les tireurs en haut, les autres au pied.
func _arrange_post(units: Array) -> void:
	var top := Vector2i(battle.GRID_W / 2, 4)
	var best := -1
	for y in range(_y(2), _y(9)):
		for x in range(1, battle.GRID_W - 1):
			var cell := Vector2i(x, y)
			if not _standable(cell):
				continue
			var h: int = battle.map.height_at(cell)
			if h > best or (h == best and absi(x - battle.GRID_W / 2) < absi(top.x - battle.GRID_W / 2)):
				best = h
				top = cell
	home = BattleMap.center(top)
	var foot := [Vector2i(-2, 2), Vector2i(2, 2), Vector2i(0, 3), Vector2i(-3, 0), Vector2i(3, 0), Vector2i(0, -2)]
	var shooters := units.filter(func(u): return u["ranged"])
	var others := units.filter(func(u): return not u["ranged"])
	for i in shooters.size():
		_put(shooters[i], _best_lookout(top + Vector2i(i - shooters.size() / 2, 0), 1), "poste", Vector2(0, 1))
	for i in others.size():
		_put(others[i], top + foot[i % foot.size()], "poste", Vector2(0, 1))
	for unit in units:
		unit["squad"] = 0  # (point 2 : un seul groupe, le poste)


## Des groupes de 2 ou 3 qui font des rondes au milieu de la carte (chacun dans sa bande de colonnes).
func _arrange_patrols(units: Array) -> void:
	var groups := []
	var group := []
	for unit in units:
		group.append(unit)
		if group.size() == 3 or (group.size() == 2 and units.size() % 3 == 1 and groups.size() == 0):
			groups.append(group)
			group = []
	if not group.is_empty():
		groups.append(group)
	var band := float(battle.GRID_W - 2) / maxf(1.0, groups.size())
	home = Vector2(battle.GRID_W / 2.0, _y(3) + 0.5)
	for g in groups.size():
		var x0 := 1 + roundi(band * g)
		var x1 := 1 + roundi(band * (g + 1)) - 1
		var route := []
		for corner in [Vector2i(x0, _y(2)), Vector2i(x1, _y(3)), Vector2i(x1, _y(8)), Vector2i(x0, _y(7))]:
			route.append(BattleMap.center(_pick_cell(corner - Vector2i(1, 1), corner + Vector2i(1, 1))))
		for i in groups[g].size():
			var unit: Dictionary = groups[g][i]
			_put(unit, _cell_of(route[0]) + Vector2i(i, 0), "ronde", Vector2(0, 1))
			unit["route"] = route
			unit["route_i"] = 1
			unit["squad"] = g + 1  # (point 2 : chaque patrouille est un groupe)


## Une embuscade : cachés dans les herbes hautes, ou juste derrière un rocher, un muret ou un bloc (vu des héros).
func _arrange_ambush(units: Array) -> void:
	var spots := []
	for y in range(_y(4), _y(11)):
		for x in range(1, battle.GRID_W - 1):
			var cell := Vector2i(x, y)
			if not _standable(cell) or battle.map.height_at(cell) > 0:
				continue
			var below := cell + Vector2i(0, 1)
			var kind: int = battle.map.kind_at(cell)
			var cover: bool = battle.map.in_bounds(below) and battle.map.kind_at(below) in [BattleMap.Kind.ROCK, BattleMap.Kind.LOW_WALL, BattleMap.Kind.BLOCK]
			if kind == BattleMap.Kind.GRASS or cover:
				spots.append(cell)
	home = Vector2(battle.GRID_W / 2.0, _y(7) + 0.5)
	for unit in units:
		var cell := _pick_cell(Vector2i(2, _y(5)), Vector2i(battle.GRID_W - 3, _y(9)))
		if not spots.is_empty():
			cell = spots.pop_at(_rng.randi_range(0, spots.size() - 1))
			spots = spots.filter(func(c): return c.distance_to(cell) >= 2.0)  # (pas tous dans le même buisson)
		_put(unit, cell, "embusque", Vector2(0, 1))


## Le village envahi : les monstres sont dispersés et rôdent chacun autour de sa place (les bêtes plus loin).
func _arrange_pillage(units: Array) -> void:
	var taken := []
	home = Vector2(battle.GRID_W / 2.0, _y(4) + 0.5)
	for unit in units:
		var cell := _pick_cell(Vector2i(2, _y(1)), Vector2i(battle.GRID_W - 3, _y(7)))
		for attempt in 12:
			if taken.all(func(c): return c.distance_to(cell) >= 3.0):
				break
			cell = _pick_cell(Vector2i(2, _y(1)), Vector2i(battle.GRID_W - 3, _y(7)))
		taken.append(cell)
		var radius := 5.0 if unit["base_name"] in GameData.EMBED_BEASTS else 3.0
		var route := [BattleMap.center(cell)]
		for i in 2:
			# (des points bien écartés : sinon il ferait des allers-retours sur place)
			var point := cell
			for attempt in 8:
				var angle := _rng.randf_range(0.0, TAU)
				point = _nearest_standable(cell + Vector2i(roundi(cos(angle) * radius), roundi(sin(angle) * radius)))
				if BattleMap.center(point).distance_to(route[route.size() - 1]) >= 2.5:
					break
			route.append(BattleMap.center(point))
		_put(unit, cell, "ronde", Vector2(0, 1))
		unit["route"] = route
		unit["route_i"] = 1


## Pose un monstre à sa place de départ, dans son état.
func _put(unit: Dictionary, cell: Vector2i, state: String, facing: Vector2) -> void:
	unit["present"] = false  # (pour qu'il ne se gêne pas lui-même en cherchant une case libre)
	unit["pos"] = battle._free_cell_near(_nearest_standable(cell))
	unit["prev_pos"] = unit["pos"]
	unit["present"] = true
	battle._settle(unit)
	unit["state"] = state
	unit["home_state"] = state
	unit["home_pos"] = unit["pos"]
	unit["facing"] = facing if facing.length() > 0.01 else Vector2(0, 1)
	unit["home_facing"] = unit["facing"]


## Un renfort entre sur le terrain (voir Battle._call_reinforcements). Après l'alarme (ou en horde), il arrive en
## courant. Sinon il sort du camp (ou du poste) dans l'état de ses compagnons ; en patrouille ou au village, il fait
## une ronde ; une embuscade n'a plus de surprise : il accourt.
func on_spawn(enemy: Dictionary) -> void:
	if alarm or disposition == "embuscade":
		enemy["state"] = "alerte"
		return
	match disposition:
		"camp", "endormis", "poste":
			_put(enemy, _cell_of(home), {"camp": "repos", "endormis": "sommeil", "poste": "poste"}[disposition], Vector2(0, 1))
			enemy["squad"] = 0
		_:
			var route := [enemy["pos"]]
			for i in 2:
				route.append(BattleMap.center(_pick_cell(Vector2i(2, _y(3)), Vector2i(battle.GRID_W - 3, _y(9)))))
			_put(enemy, _cell_of(enemy["pos"]), "ronde", Vector2(0, 1))
			enemy["route"] = route
			enemy["route_i"] = 1


# ---------------------------------------------------------------------------
# Ce que fait un monstre qui ne chasse pas encore
# ---------------------------------------------------------------------------

## Un monstre pas encore en alerte : sa jauge de détection monte ou descend (voir _watch) ; selon elle, il continue,
## devient méfiant, va voir, ou repère le héros. Sinon il fait sa ronde, va voir un bruit, ou garde sa place. Renvoie
## faux s'il chasse (alerte) : le combat normal reprend la main (voir Battle._think).
func think(unit: Dictionary, known: Array) -> bool:
	if alarm or unit["state"] == "alerte":
		return false
	if unit["state"] == "embusque":
		# Embusqué : il attend que sa proie passe tout près (pas de jauge : il guette déjà).
		if not known.is_empty():
			var prey: Dictionary = battle._nearest(unit, known)
			if unit["pos"].distance_to(prey["pos"]) <= GameData.AMBUSH_TRIGGER:
				raise(unit, prey)
				return false
			return true
	else:
		var noticed := _watch(unit)
		if unit["detect"] >= 1.0:
			raise(unit, noticed)
			return false
		if unit["detect"] >= GameData.DETECT_INVESTIGATE and not noticed.is_empty():
			# Il en est presque sûr : il va voir (et suit ce qu'il entrevoit).
			if unit["state"] != "fouille":
				_note_suspicion(unit, true)
			unit["state"] = "fouille"
			unit["search"] = unit["detect_pos"]
			unit["search_until"] = -1.0
		elif unit["detect"] >= GameData.DETECT_SUSPECT and not unit["state"] in ["mefiant", "fouille"]:
			_note_suspicion(unit, false)
			unit["state"] = "mefiant"
	match unit["state"]:
		"mefiant":
			# Il s'arrête et regarde par là ; la jauge retombée, il reprend sa place, sur ses gardes.
			var toward: Vector2 = unit["detect_pos"] - unit["pos"]
			if toward.length() > 0.05:
				unit["facing"] = toward.normalized()
			if unit["detect"] <= 0.0:
				_calm_down(unit)
				if _seen(unit):
					battle._log("%s reprend sa place, mais reste sur ses gardes." % unit["name"], "reinforce")
		"ronde":
			var route: Array = unit["route"]
			if route.is_empty():
				return true
			var goal: Vector2 = route[unit["route_i"] % route.size()]
			if unit["pos"].distance_to(goal) <= 0.6:
				unit["route_i"] = (unit["route_i"] + 1) % route.size()
				goal = route[unit["route_i"]]
			unit["pace"] = GameData.PATROL_PACE
			battle._move_towards(unit, goal)
		"fouille":
			if unit["search_until"] < 0.0:
				if unit["pos"].distance_to(unit["search"]) > 0.8:
					unit["pace"] = GameData.SEARCH_PACE
					battle._move_towards(unit, unit["search"])
				else:
					unit["search_until"] = battle.time + GameData.SEARCH_SECONDS
			elif battle.time >= unit["search_until"]:
				# Rien trouvé : il reprend sa place, sur ses gardes.
				_calm_down(unit)
			else:
				unit["facing"] = unit["facing"].rotated(0.35)  # il regarde autour de lui
		_:
			# À sa place (repos, sommeil, guet, poste, embuscade) ; poussé ou revenu d'une fouille : il y retourne.
			if unit["pos"].distance_to(unit["home_pos"]) > 0.6:
				unit["pace"] = GameData.PATROL_PACE
				battle._move_towards(unit, unit["home_pos"])
			else:
				unit["facing"] = unit["home_facing"]
	return true


## La jauge de détection (voir GameData, tower.gd, « Jauge de détection ») : elle monte selon le héros qu'il remarque
## le plus (de ses propres yeux ou oreilles), sinon elle redescend. Renvoie ce héros ({} : aucun) ; retient où il l'a
## entrevu (« detect_pos »).
func _watch(unit: Dictionary) -> Dictionary:
	# (méfiant : à la vitesse de son état de départ ; c'est sa vigilance accrue qui le rendra plus vif ensuite)
	var state: String = unit["home_state"] if unit["state"] == "mefiant" else unit["state"]
	var rate: float = 1.0 / maxf(0.05, GameData.REACTION_SECONDS.get(state, 0.5))
	if unit["wary"]:
		rate *= GameData.WARY_RATE
	var half: float = deg_to_rad(GameData.SIGHT_ANGLE / 2.0)
	var best: Dictionary = {}
	var best_gain := 0.0
	for hero in battle._alive(battle.heroes):
		var seen: bool = unit["sees"].has(hero["id"])
		if not seen and not unit["hears"].has(hero["id"]):
			continue
		var rel: Vector2 = hero["pos"] - unit["pos"]
		var distance := rel.length()
		if seen and distance <= GameData.DETECT_INSTANT:
			best = hero
			best_gain = INF  # (tout près : aucun doute)
			break
		var gain: float = rate * clampf(GameData.DETECT_REF_DIST / maxf(0.1, distance), GameData.DETECT_PROX_MIN, GameData.DETECT_PROX_MAX)
		if seen:
			var side := clampf(absf(unit["facing"].angle_to(rel)) / half, 0.0, 1.0) if half > 0.0 else 0.0
			gain *= lerpf(1.0, GameData.DETECT_SIDE, side)
		else:
			gain *= GameData.DETECT_HEARD
		if _still.get(hero["id"], false):
			gain *= GameData.DETECT_STILL
		if gain > best_gain:
			best_gain = gain
			best = hero
	if best_gain == INF:
		unit["detect"] = 1.0
	else:
		unit["detect"] = clampf(unit["detect"] + (best_gain - GameData.DETECT_DECAY) * battle.TICK, 0.0, 1.0)
	if not best.is_empty():
		unit["detect_pos"] = best["pos"]
	return best


## Il devient méfiant (ou va voir) : compté, et dit dans le journal si un héros le voit.
func _note_suspicion(unit: Dictionary, going: bool) -> void:
	if unit["state"] != "mefiant":
		counts["mefiant"] += 1
	if not _seen(unit):
		return
	if going:
		battle._log("%s a cru voir quelque chose : il s'approche pour vérifier." % unit["name"], "reinforce")
	elif unit["state"] == "sommeil":
		battle._log("%s ouvre un œil..." % unit["name"], "reinforce")
	else:
		battle._log("%s s'arrête et regarde dans votre direction..." % unit["name"], "reinforce")


## Fausse alerte (ou fouille sans rien trouver) : il reprend sa place et son état, mais garde une vigilance accrue
## jusqu'à la fin du combat (un dormeur réveillé ne se rendort pas).
func _calm_down(unit: Dictionary) -> void:
	counts["fausse_alerte"] += 1
	unit["state"] = "repos" if unit["home_state"] == "sommeil" else unit["home_state"]
	unit["search_until"] = -1.0
	unit["wary"] = true


## Un héros qui voit un monstre méfiant (ou qui vient voir) tourné vers lui : ce monstre ({} : aucun).
func watching(hero: Dictionary) -> Dictionary:
	if alarm:
		return {}
	var best: Dictionary = {}
	for unit in battle._alive(battle.enemies):
		if not unit["state"] in ["mefiant", "fouille"] or unit["detect"] < GameData.DETECT_SUSPECT:
			continue
		if not unit["sees"].has(hero["id"]) and not unit["hears"].has(hero["id"]):
			continue
		if not battle.perception.knows_now(hero, unit):
			continue
		if best.is_empty() or unit["detect"] > best["detect"]:
			best = unit
	return best


## Il a repéré un héros (ou il est attaqué) : il passe en alerte et crie. Un guetteur donne l'alarme générale ; un
## embusqué fait bondir toute l'embuscade ; sinon les monstres à portée de cri passent en alerte avec lui.
func raise(unit: Dictionary, hero: Dictionary) -> void:
	if unit["state"] == "alerte" or unit["hp"] <= 0 or not unit["present"]:
		return
	var was: String = unit["state"]
	_wake(unit, hero)
	if alarm:
		return
	if unit["home_state"] == "guet":
		general_alarm("%s, le guetteur, a repéré %s : il donne l'alarme !" % [unit["name"], _who(hero)])
		return
	if was == "embusque":
		_spring(hero)
		return
	var heard := false
	for other in battle._alive(battle.enemies):
		if other["state"] != "alerte" and other["state"] != "embusque" and other["pos"].distance_to(unit["pos"]) <= GameData.SHOUT_RANGE:
			_wake(other, hero)
			heard = true
	if _seen(unit):
		battle._log("%s a repéré %s et pousse un cri !" % [unit["name"], _who(hero)], "reinforce")
	elif heard:
		battle._log("Des cris retentissent plus loin : des monstres ont été alertés.", "reinforce")


func _wake(unit: Dictionary, hero: Dictionary) -> void:
	if unit["state"] == "sommeil" and _seen(unit):
		battle._log("%s se réveille en sursaut !" % unit["name"], "reinforce")
	unit["state"] = "alerte"
	unit["alert_t"] = battle.time
	unit["detect"] = 1.0
	if not hero.is_empty():
		unit["knows"][hero["id"]] = {"pos": hero["pos"], "t": battle.time}


## L'embuscade bondit : tous les embusqués passent en alerte d'un coup.
func _spring(hero: Dictionary) -> void:
	for other in battle._alive(battle.enemies):
		if other["state"] == "embusque":
			_wake(other, hero)
	var text := "Embuscade ! Des monstres jaillissent de leur cachette autour de %s !" % _who(hero)
	battle._log(text, "reinforce")
	battle._alert("Embuscade !", [text], true)


## L'alarme générale : tout le camp chasse les héros (les renforts arrivent en courant).
func general_alarm(text: String) -> void:
	if alarm:
		return
	alarm = true
	for enemy in battle.enemies:
		if enemy["hp"] > 0:
			if enemy["state"] == "sommeil" and enemy["present"] and _seen(enemy):
				battle._log("%s se réveille en sursaut !" % enemy["name"], "reinforce")
			enemy["state"] = "alerte"
			enemy["alert_t"] = battle.time
	battle._log(text, "reinforce")
	battle._alert("Alarme !", [text], false)
	battle._start_clock()


## Un bruit (un coup, un cri de douleur) entendu à « radius » cases (un dormeur : moitié) : les monstres qui ne
## chassent pas viennent voir ; un guetteur donne l'alarme.
func noise(pos: Vector2, radius: float) -> void:
	if alarm:
		return
	# (point 2 du recensement « Techniques ») Le bruit suit les passages : il contourne une maison ; à travers un mur, il
	# ne porte qu'à 1 / SOUND_WALL_FACTOR de sa portée.
	var field: PackedFloat32Array = battle.map.sound_field(battle.map.cell_of(pos), radius)
	for unit in battle._alive(battle.enemies):
		var state: String = unit["state"]
		if state in ["alerte", "embusque"]:
			continue
		var reach := radius * (GameData.SLEEP_HEARING_FACTOR if state == "sommeil" else 1.0)
		var heard_at: float = minf(field[battle.map.index(battle.map.cell_of(unit["pos"]))],
			unit["pos"].distance_to(pos) * GameData.SOUND_WALL_FACTOR)
		if heard_at > reach:
			continue
		if unit["home_state"] == "guet" and state in ["guet", "mefiant"]:
			general_alarm("%s, le guetteur, entend des bruits de combat : il donne l'alarme !" % unit["name"])
			return
		if state == "sommeil" and _seen(unit):
			battle._log("%s se réveille en sursaut !" % unit["name"], "reinforce")
		unit["state"] = "fouille"
		unit["search"] = pos
		unit["search_until"] = -1.0
		unit["detect"] = maxf(unit["detect"], GameData.DETECT_INVESTIGATE)


## Un coup porté (voir Battle._hit) : il s'entend ; un monstre frappé passe en alerte (s'il est encore debout).
func on_hit(attacker: Dictionary, target: Dictionary) -> void:
	if alarm:
		return
	if not target["is_hero"] and target["hp"] > 0:
		raise(target, attacker if attacker["is_hero"] else {})
	noise(target["pos"], GameData.NOISE_FIGHT)


## Toutes les secondes du combat : sans aucun contact au bout de ALARM_SECONDS, les monstres flairent l'équipe.
## Note aussi, à chaque pas, quels héros n'ont pas bougé depuis le pas d'avant (jauge de détection).
func tick() -> void:
	for hero in battle.heroes:
		var last = _last_pos.get(hero["id"])
		_still[hero["id"]] = last != null and last.distance_to(hero["pos"]) < 0.005
		_last_pos[hero["id"]] = hero["pos"]
	if not alarm and not corpses.is_empty():
		_look_for_corpses()
		_notice_missing()
	if not alarm and battle.clock_start < 0.0 and battle.time >= GameData.ALARM_SECONDS:
		general_alarm("Les monstres ont flairé ton équipe : ils se lancent à sa recherche !")


# ---------------------------------------------------------------------------
# Indices dans le décor : corps et compagnons disparus (point 2 du recensement « Techniques »)
# ---------------------------------------------------------------------------

## Un monstre tombe avant l'alarme (voir Battle._announce_fall) : son corps reste là.
func on_death(monster: Dictionary) -> void:
	if alarm or monster["is_hero"]:
		return
	corpses.append({"pos": monster["pos"], "name": monster["name"], "squad": monster["squad"], "t": battle.time,
		"found": false, "missed": false})


## Les monstres calmes et éveillés regardent autour d'eux : un corps dans leur regard (ou tout près), à portée de vue
## et sans obstacle, est découvert.
func _look_for_corpses() -> void:
	var half := deg_to_rad(GameData.SIGHT_ANGLE / 2.0)
	for corpse in corpses:
		if corpse["found"]:
			continue
		var cell: Vector2i = battle.map.cell_of(corpse["pos"])
		for unit in battle._alive(battle.enemies):
			if unit["state"] in ["alerte", "sommeil", "embusque"]:
				continue
			var rel: Vector2 = corpse["pos"] - unit["pos"]
			var distance := rel.length()
			if distance > GameData.SIGHT_LENGTH * GameData.SIGHT_MONSTER_FACTOR * sight_factor(unit):
				continue
			if distance > GameData.CORPSE_NEAR and absf(unit["facing"].angle_to(rel)) > half:
				continue
			if not battle.map.line_of_sight(unit["pos"], battle.height_of(unit), corpse["pos"], battle.map.height_at(cell)):
				continue
			_discover(unit, corpse)
			if alarm:
				return
			break


## Il découvre un corps : il crie. Un guetteur (ou un guetteur qui l'entend) donne l'alarme générale ; sinon, lui et
## les monstres à portée de cri deviennent vigilants et viennent fouiller autour du corps.
func _discover(unit: Dictionary, corpse: Dictionary) -> void:
	corpse["found"] = true
	counts["cadavres"] += 1
	if unit["home_state"] == "guet":
		general_alarm("%s, le guetteur, découvre le corps de %s : il donne l'alarme !" % [unit["name"], corpse["name"]])
		return
	if _seen(unit):
		battle._log("%s découvre le corps de %s et pousse un cri !" % [unit["name"], corpse["name"]], "reinforce")
	else:
		battle._log("Un cri retentit plus loin : un corps a été découvert.", "reinforce")
	_search_around(unit, corpse["pos"], 0)
	var k := 1
	for other in battle._alive(battle.enemies):
		if other["id"] == unit["id"] or other["state"] in ["alerte", "embusque"]:
			continue
		if other["pos"].distance_to(unit["pos"]) > GameData.SHOUT_RANGE:
			continue
		if other["home_state"] == "guet":
			general_alarm("%s, le guetteur, entend crier qu'un corps a été trouvé : il donne l'alarme !" % other["name"])
			return
		if other["state"] == "sommeil" and _seen(other):
			battle._log("%s se réveille en sursaut !" % other["name"], "reinforce")
		_search_around(other, corpse["pos"], k)
		k += 1


## Au bout de MISSING_SECONDS, un groupe s'aperçoit qu'un compagnon tombé sans bruit ne revient pas : tous deviennent
## vigilants, le plus proche (pas un guetteur) part le chercher là où il était.
func _notice_missing() -> void:
	for corpse in corpses:
		if corpse["missed"] or corpse["found"] or corpse["squad"] < 0 or battle.time - corpse["t"] < GameData.MISSING_SECONDS:
			continue
		corpse["missed"] = true
		var seeker: Dictionary = {}
		var noticed := false
		for mate in battle._alive(battle.enemies):
			if mate["squad"] != corpse["squad"] or mate["state"] in ["alerte", "embusque", "sommeil"]:
				continue
			noticed = true
			mate["wary"] = true
			if mate["home_state"] != "guet" and (seeker.is_empty() \
					or mate["pos"].distance_to(corpse["pos"]) < seeker["pos"].distance_to(corpse["pos"])):
				seeker = mate
		if not noticed:
			continue
		counts["disparus"] += 1
		if seeker.is_empty():
			continue
		_search_around(seeker, corpse["pos"], 0)
		if _seen(seeker):
			battle._log("%s ne voit pas revenir %s : il part à sa recherche." % [seeker["name"], corpse["name"]], "reinforce")


## Il va fouiller près de « pos » (le k-ième un peu à côté : ils ne vont pas tous sur la même case), sur ses gardes.
func _search_around(unit: Dictionary, pos: Vector2, k: int) -> void:
	var offset := Vector2.ZERO if k == 0 else Vector2(GameData.CORPSE_SEARCH_SPREAD, 0).rotated(k * 2.1)
	unit["state"] = "fouille"
	unit["search"] = BattleMap.center(_nearest_standable(battle.map.cell_of(pos + offset)))
	unit["search_until"] = -1.0
	unit["wary"] = true
	unit["detect"] = maxf(unit["detect"], GameData.DETECT_INVESTIGATE)


# ---------------------------------------------------------------------------
# Lectures (perception, écran)
# ---------------------------------------------------------------------------

## Caché (embusqué) : on ne le voit que de près (voir BattlePerception._cast).
func hidden(unit: Dictionary) -> bool:
	return not alarm and unit.get("state", "") == "embusque"


## La vue d'un monstre selon son état (sommeil : 0, aucun bâtonnet ; repos : moins ; guet : plus).
func sight_factor(unit: Dictionary) -> float:
	if unit["is_hero"] or alarm:
		return 1.0
	return GameData.STATE_SIGHT.get(unit["state"], 1.0) * (GameData.WARY_SIGHT if unit["wary"] else 1.0)


func hearing_factor(unit: Dictionary) -> float:
	if unit["is_hero"] or alarm or unit["state"] != "sommeil":
		return 1.0
	return GameData.SLEEP_HEARING_FACTOR


## Un guetteur balaie du regard autour de sa direction (Vector2.ZERO : rien de spécial).
func facing_for(unit: Dictionary) -> Vector2:
	if unit["is_hero"] or alarm or unit["state"] != "guet" or unit["pos"].distance_to(unit["home_pos"]) > 0.6:
		return Vector2.ZERO
	return unit["home_facing"].rotated(sin(battle.time * 0.7 + unit["id"]) * 0.9 * (GameData.WARY_SWEEP if unit["wary"] else 1.0))


## Ce que l'écran écrit au-dessus d'un monstre (texte et couleur ; texte vide : rien). « ! » quelques secondes après
## qu'il a donné de la voix.
func state_tag(unit: Dictionary) -> Array:
	if unit["is_hero"] or unit["hp"] <= 0:
		return ["", Color.WHITE]
	if unit["state"] == "alerte":
		if battle.time - unit["alert_t"] < 2.0 and disposition != "horde":
			return ["!", Color("ff5040")]
		return ["", Color.WHITE]
	match unit["state"]:
		"sommeil":
			return ["Zzz", Color("9ab8ff")]
		"repos":
			return ["aux aguets" if unit["wary"] else "au repos", Color("c8c8c8")]
		"guet":
			return ["guetteur", Color("ffd060")]
		"mefiant":
			return ["?", Color("fff070")]
		"fouille":
			return ["?", Color("ffb060")]
		"embusque":
			return ["embusqué", Color("b0e080")]
	if unit["wary"]:
		return ["sur ses gardes", Color("e0c890")]
	return ["", Color.WHITE]


## La carte de visibilité (recensement « Techniques », point 3) : pour chaque case (indice BattleMap.index), combien
## de monstres la regardent, parmi ceux que les héros connaissent (on ne fuit pas le regard d'un monstre dont on ignore
## tout) et qui ne chassent ni ne dorment : dans leur regard (un guetteur balaie plus large), à portée de leur vue,
## sans obstacle ; dans les herbes hautes, moitié moins. Vide après l'alarme (ou en horde). Sert aux chemins discrets
## des héros (BattleMap.SIDE_SNEAK, voir Battle._refresh_costs).
func exposure() -> PackedFloat32Array:
	var seen := PackedFloat32Array()
	if alarm:
		return seen
	var map: BattleMap = battle.map
	seen.resize(map.heights.size())
	seen.fill(0.0)
	for unit in battle._alive(battle.enemies):
		if unit["state"] in ["alerte", "sommeil"]:
			continue
		if not battle.heroes.any(func(h): return h["hp"] > 0 and h["knows"].has(unit["id"])):
			continue
		var sight: float = (GameData.SIGHT_LENGTH * GameData.SIGHT_MONSTER_FACTOR + battle.height_of(unit) * GameData.SIGHT_HEIGHT_BONUS) \
			* sight_factor(unit)
		if sight <= 0.0:
			continue
		var guard: bool = unit["state"] == "guet"
		var facing: Vector2 = unit["home_facing"] if guard else unit["facing"]
		var half := deg_to_rad(GameData.SIGHT_ANGLE / 2.0) + (0.9 * (GameData.WARY_SWEEP if unit["wary"] else 1.0) if guard else 0.0)
		var z: int = battle.height_of(unit)
		var here: Vector2i = map.cell_of(unit["pos"])
		var r := ceili(sight)
		for y in range(maxi(0, here.y - r), mini(battle.GRID_H, here.y + r + 1)):
			for x in range(maxi(0, here.x - r), mini(battle.GRID_W, here.x + r + 1)):
				var cell := Vector2i(x, y)
				if not map.walkable(cell):
					continue
				var rel: Vector2 = BattleMap.center(cell) - unit["pos"]
				var distance := rel.length()
				if distance > sight or (distance > 1.0 and absf(facing.angle_to(rel)) > half):
					continue
				if not map.line_of_sight(unit["pos"], z, BattleMap.center(cell), map.height_at(cell)):
					continue
				seen[map.index(cell)] += 0.5 if map.kind_at(cell) == BattleMap.Kind.GRASS else 1.0
	return seen


## La jauge de détection à afficher au-dessus d'un monstre (0 à 1 ; 0 : rien), tant qu'il ne chasse pas.
func detect_level(unit: Dictionary) -> float:
	if unit["is_hero"] or alarm or unit["hp"] <= 0 or unit["state"] in ["alerte", "embusque"]:
		return 0.0
	return unit["detect"]


# ---------------------------------------------------------------------------
# Outils
# ---------------------------------------------------------------------------

func _seen(unit: Dictionary) -> bool:
	return battle.perception != null and battle.perception.seen_by_heroes.has(unit["id"])


func _who(hero: Dictionary) -> String:
	return hero["name"] if not hero.is_empty() else "l'équipe"


func _cell_of(pos: Vector2) -> Vector2i:
	return battle.map.cell_of(pos)


## Une case où l'on peut se tenir debout (pas une échelle, un muret, un rocher ni une porte).
func _standable(cell: Vector2i) -> bool:
	return battle.map.walkable(cell) and not battle.map.kind_at(cell) in [BattleMap.Kind.LADDER, BattleMap.Kind.LOW_WALL,
		BattleMap.Kind.ROCK, BattleMap.Kind.GATE]


func _nearest_standable(cell: Vector2i) -> Vector2i:
	cell = Vector2i(clampi(cell.x, 0, battle.GRID_W - 1), clampi(cell.y, 0, battle.GRID_H - 1))
	for radius in range(0, 6):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var other := cell + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == radius and battle.map.in_bounds(other) and _standable(other):
					return other
	return cell


## Une case au hasard (au sol si possible) dans le rectangle [from, to].
func _pick_cell(from: Vector2i, to: Vector2i) -> Vector2i:
	for attempt in 30:
		var cell := Vector2i(_rng.randi_range(from.x, to.x), _rng.randi_range(from.y, to.y))
		if _standable(cell) and battle.map.height_at(cell) == 0:
			return cell
	return _nearest_standable((from + to) / 2)


## La case la plus haute à moins de « radius » cases (la plus proche à hauteur égale).
func _best_lookout(around: Vector2i, radius: int) -> Vector2i:
	var best := _nearest_standable(around)
	var best_height: int = battle.map.height_at(best)
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var cell := around + Vector2i(dx, dy)
			if not battle.map.in_bounds(cell) or not _standable(cell):
				continue
			var h: int = battle.map.height_at(cell)
			if h > best_height or (h == best_height and cell.distance_to(around) < best.distance_to(around)):
				best = cell
				best_height = h
	return best


## Les quatre coins d'une ronde autour d'une case.
func _loop_around(center: Vector2i, radius: float) -> Array:
	var route := []
	for i in 4:
		var angle := TAU * i / 4.0 + PI / 4.0
		route.append(BattleMap.center(_nearest_standable(center + Vector2i(roundi(cos(angle) * radius), roundi(sin(angle) * radius)))))
	return route


## Une ligne de la carte, donnée pour l'ancienne carte de 20 lignes (avant les cartes de l'étape 2) : la même place,
## à l'échelle de la carte du combat.
func _y(old_row: int) -> int:
	return roundi(old_row * battle.GRID_H / 20.0)
