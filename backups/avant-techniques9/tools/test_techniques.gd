extends SceneTree
## Vérification du recensement « Techniques de programmation pour le combat » (jauge de détection, niveaux d'alerte,
## cadavres et alliés disparus, son qui suit les passages) en mode normal, sans écran. GameData démarre (il relit et
## réécrit la sauvegarde) : dans une COPIE du projet (override.cfg) :
##   Godot --headless --path <copie> -s res://tools/test_techniques.gd

var failures := 0
var started := false
var game: Node


func _process(_delta: float) -> bool:
	if started:
		return false
	started = true
	_run.call_deferred()
	return false


func _run() -> void:
	game = root.get_node("GameData")
	root.get_node("Settings").dev_mode = false
	seed(3)
	_check_gauge()
	_check_wary()
	_check_freeze()
	_check_corpses()
	_check_sound()
	_check_sneak()
	_check_terrain()
	_check_search()
	_check_coordination()
	_check_formation()
	_check_camp()
	print("")
	print("RÉSULTAT : %s" % ("tout est bon" if failures == 0 else "%d problème(s)" % failures))
	quit(1 if failures > 0 else 0)


func _team(level: int) -> Array:
	var team := []
	for i in 3:
		var hero: Dictionary = game.dev_create_hero(3, "Guerrier" if i == 0 else "")
		while hero["level"] < level and not game.is_max_level(hero):
			game.gain_xp(hero, game.xp_to_next(hero["level"]) - hero["xp"])
		team.append(hero)
	return team


## Une scène réglée à la main : un terrain plat, un seul monstre (de garde, tourné vers le bas) et un seul héros, à
## « distance » cases devant lui. Les autres sont retirés du terrain.
func _scene(distance: float, state := "poste") -> Dictionary:
	var quest: Dictionary = game.floor_quest(3)
	var layout: Dictionary = load("res://scripts/map_generator.gd").generate(3, quest, 21)
	var battle = load("res://scripts/battle.gd").new(_team(game.floor_enemy_level(3) + 2), layout["enemies"], quest)
	battle.map_data = layout["map"]
	battle.forced_disposition = "poste"
	battle.start()
	battle.map.setup(battle.GRID_W, battle.GRID_H)  # (tout plat, sans obstacle)
	battle.map.build_graph()
	var monster: Dictionary = battle.enemies[0]
	var hero: Dictionary = battle.heroes[0]
	for unit in battle.units:
		if unit != monster and unit != hero:
			unit["present"] = false
	monster["present"] = true
	monster["pos"] = Vector2(6.5, 4.5)
	monster["prev_pos"] = monster["pos"]  # (sinon il regarderait dans le sens de ce « déplacement »)
	monster["home_pos"] = monster["pos"]
	monster["facing"] = Vector2(0, 1)
	monster["home_facing"] = Vector2(0, 1)
	monster["state"] = state
	monster["home_state"] = state
	monster["detect"] = 0.0
	hero["pos"] = monster["pos"] + Vector2(0, distance)
	hero["stealth"] = 1.0
	return {"battle": battle, "monster": monster, "hero": hero}


## Un pas de temps, seulement pour ce monstre (le héros bouge un peu s'il « marche »).
func _tick(scene: Dictionary, walking: bool) -> void:
	var battle = scene["battle"]
	var hero: Dictionary = scene["hero"]
	if walking:
		hero["pos"] += Vector2(0.03 if int(battle.time * 10) % 2 == 0 else -0.03, 0)
	battle.time += battle.TICK
	battle.perception.update()
	battle.alert.tick()
	battle.alert.think(scene["monster"], [])


func _check_gauge() -> void:
	print("Jauge de détection")
	var scene := _scene(4.0)
	var monster: Dictionary = scene["monster"]
	_tick(scene, true)
	_tick(scene, true)
	_check(monster["detect"] > 0.0 and monster["detect"] < 1.0 and monster["state"] != "alerte",
		"à 4 cases, il ne repère pas le héros d'un coup (jauge %.2f)" % monster["detect"])
	var states := []
	for i in 60:
		_tick(scene, true)
		if states.is_empty() or states[states.size() - 1] != monster["state"]:
			states.append(monster["state"])
		if monster["state"] == "alerte":
			break
	_check(states.size() >= 2 and states[states.size() - 1] == "alerte" and ("mefiant" in states or "fouille" in states),
		"il devient méfiant, puis le repère (%s)" % " → ".join(states))
	# Immobile, la jauge monte moins vite.
	var walking := _scene(4.0)
	var still := _scene(4.0)
	for i in 5:
		_tick(walking, true)
		_tick(still, false)
	_check(still["monster"]["detect"] < walking["monster"]["detect"],
		"immobile, on se remarque moins vite (%.2f contre %.2f)" % [still["monster"]["detect"], walking["monster"]["detect"]])
	# Tout près : aucun doute.
	var near := _scene(1.0)
	_tick(near, false)
	_tick(near, false)
	_check(near["monster"]["state"] == "alerte", "à une case : repéré tout de suite")
	# Un dormeur ne voit rien : sa jauge ne monte pas à 4 cases.
	var sleeper := _scene(4.0, "sommeil")
	for i in 20:
		_tick(sleeper, true)
	_check(sleeper["monster"]["detect"] == 0.0 and sleeper["monster"]["state"] == "sommeil", "un dormeur ne voit pas un héros à 4 cases")


func _check_wary() -> void:
	print("Vigilance accrue")
	var scene := _scene(4.0)
	var monster: Dictionary = scene["monster"]
	var hero: Dictionary = scene["hero"]
	for i in 30:
		_tick(scene, true)
		if monster["detect"] >= game.DETECT_SUSPECT:
			break
	# Le héros s'en va avant d'être repéré.
	var peak: float = monster["detect"]
	hero["pos"] = Vector2(1.5, 14.5)
	for i in 30:
		_tick(scene, false)
	if monster["state"] == "fouille":
		monster["search_until"] = 0.0  # (on abrège sa fouille)
		_tick(scene, false)
	_check(peak >= game.DETECT_SUSPECT and monster["state"] == "poste" and monster["wary"],
		"le héros parti, il reprend sa place, sur ses gardes (jauge montée à %.2f)" % peak)
	var calm := _scene(4.0)
	_check(scene["battle"].alert.sight_factor(monster) > calm["battle"].alert.sight_factor(calm["monster"]), "sur ses gardes, il voit plus loin")
	_check(scene["battle"].alert.state_tag(monster)[0] == "sur ses gardes", "l'écran l'affiche (« sur ses gardes »)")


func _check_freeze() -> void:
	print("Se figer à temps")
	var scene := _scene(4.0)
	var monster: Dictionary = scene["monster"]
	var hero: Dictionary = scene["hero"]
	var battle = scene["battle"]
	for i in 30:
		_tick(scene, true)
		if monster["state"] == "mefiant":
			break
	_check(monster["state"] == "mefiant", "le monstre est méfiant")
	_check(battle.alert.watching(hero) == monster, "le héros voit qu'il regarde vers lui")
	# Figé, à cette distance, la jauge peut redescendre (loin et immobile) : à 4,6 cases, oui.
	hero["pos"] = monster["pos"] + Vector2(0, 4.6)
	var before: float = monster["detect"]
	for i in 20:
		_tick(scene, false)
	_check(monster["detect"] < before, "loin et immobile, la jauge redescend (%.2f → %.2f)" % [before, monster["detect"]])


## Point 2 : un corps devant un monstre (le héros est loin derrière lui, ni vu ni entendu).
func _corpse_scene(state: String, corpse_at: Vector2, squad := -1) -> Dictionary:
	var scene := _scene(4.0, state)
	scene["hero"]["pos"] = Vector2(6.5, 0.5)
	scene["monster"]["squad"] = squad
	scene["battle"].alert.corpses.append({"pos": corpse_at, "name": "Gobelin mort", "squad": squad, "t": 0.0,
		"found": false, "missed": false})
	return scene


func _check_corpses() -> void:
	print("Corps et compagnons disparus")
	var scene := _corpse_scene("poste", Vector2(6.5, 7.5))
	var monster: Dictionary = scene["monster"]
	_tick(scene, false)
	var alert = scene["battle"].alert
	_check(alert.corpses[0]["found"] and monster["state"] == "fouille" and monster["wary"],
		"un corps à 3 cases devant lui : découvert, il va fouiller, sur ses gardes (%s)" % monster["state"])
	_check(not alert.alarm, "pas d'alarme générale (ce n'est pas un guetteur)")
	var behind := _corpse_scene("poste", Vector2(6.5, 1.5))
	_tick(behind, false)
	_check(not behind["battle"].alert.corpses[0]["found"], "un corps dans son dos : pas vu")
	var guard := _corpse_scene("guet", Vector2(6.5, 7.5))
	guard["monster"]["home_facing"] = Vector2(0, 1)
	_tick(guard, false)
	_check(guard["battle"].alert.alarm, "un guetteur qui découvre un corps donne l'alarme")
	# Un compagnon de patrouille tombé sans bruit, hors de sa vue : au bout de MISSING_SECONDS, il part le chercher.
	var missing := _corpse_scene("ronde", Vector2(6.5, 1.5), 1)
	missing["monster"]["route"] = [missing["monster"]["pos"]]
	var steps := int(game.MISSING_SECONDS / missing["battle"].TICK) - 3
	for i in steps:
		_tick(missing, false)
	var early: String = missing["monster"]["state"]
	for i in 6:
		_tick(missing, false)
	_check(early == "ronde" and missing["monster"]["state"] == "fouille" and missing["battle"].alert.counts["disparus"] == 1,
		"un compagnon disparu : au bout de %d s, il part le chercher (%s → %s)" % [game.MISSING_SECONDS, early, missing["monster"]["state"]])


func _check_sound() -> void:
	print("Son qui suit les passages")
	var open := _scene(4.0)
	open["hero"]["pos"] = Vector2(1.5, 0.5)
	open["battle"].alert.noise(Vector2(6.5, 8.5), game.NOISE_FIGHT)
	_check(open["monster"]["state"] == "fouille", "un coup à 4 cases, à découvert : entendu")
	var walled := _scene(4.0)
	walled["hero"]["pos"] = Vector2(1.5, 0.5)
	var battle = walled["battle"]
	battle.map.fill(Rect2i(0, 6, battle.GRID_W - 1, 1), BattleMap.Kind.BLOCK, 2)  # (un mur, ouvert tout au bout)
	battle.map.build_graph()
	battle.alert.noise(Vector2(6.5, 8.5), game.NOISE_FIGHT)
	_check(walled["monster"]["state"] == "poste", "le même coup derrière un long mur : pas entendu (%s)" % walled["monster"]["state"])


func _check_sneak() -> void:
	print("Chemins discrets")
	var scene := _scene(4.0)
	var battle = scene["battle"]
	var monster: Dictionary = scene["monster"]
	var hero: Dictionary = scene["hero"]
	var alert = battle.alert
	var map = battle.map
	var unknown: PackedFloat32Array = alert.exposure()
	hero["knows"][monster["id"]] = {"pos": monster["pos"], "t": battle.time}
	var seen: PackedFloat32Array = alert.exposure()
	var front: float = seen[map.index(Vector2i(6, 7))]
	var back: float = seen[map.index(Vector2i(6, 2))]
	_check(unknown[map.index(Vector2i(6, 7))] == 0.0, "un monstre que les héros ne connaissent pas : rien à éviter")
	_check(front >= 1.0 and back == 0.0, "la case devant lui est vue, celle derrière lui non (%.1f, %.1f)" % [front, back])
	# Un héros qui se faufile contourne son regard ; à découvert, il va tout droit.
	monster["ranged"] = false  # (un tireur ajoute un coût de danger : on ne mesure ici que son regard)
	battle._costs_due = 0.0
	battle._refresh_costs()
	var straight: PackedVector2Array = map.find_path(Vector2i(1, 6), Vector2i(12, 6), BattleMap.SIDE_HEROES)
	var sneaky: PackedVector2Array = map.find_path(Vector2i(1, 6), Vector2i(12, 6), BattleMap.SIDE_SNEAK)
	var exposed := func(path: PackedVector2Array) -> float:
		var total := 0.0
		for point in path:
			total += seen[map.index(map.cell_of(point))]
		return total
	_check(exposed.call(sneaky) < exposed.call(straight), "le chemin discret passe moins sous son regard (%.1f contre %.1f)" \
		% [exposed.call(sneaky), exposed.call(straight)])
	hero["stealth"] = 0.5
	_check(battle._side(hero) == BattleMap.SIDE_SNEAK, "un héros qui se faufile prend les chemins discrets")
	hero["stealth"] = 1.0
	_check(battle._side(hero) == BattleMap.SIDE_HEROES, "à découvert : les chemins de toujours")


func _check_terrain() -> void:
	print("Annotation tactique des cartes")
	var map := BattleMap.new(12, 12)
	map.fill(Rect2i(0, 5, 5, 1), BattleMap.Kind.BLOCK, 2)  # un mur percé d'un passage d'une case (x = 5)
	map.fill(Rect2i(6, 5, 6, 1), BattleMap.Kind.BLOCK, 2)
	map.fill(Rect2i(9, 9, 1, 1), BattleMap.Kind.ROOF, 1)  # une petite hauteur
	map.fill(Rect2i(1, 10, 2, 1), BattleMap.Kind.GRASS, 0)
	map.build_graph()
	var terrain = load("res://scripts/battle_terrain.gd").new(map)  # (pas le nom de la classe : GameData pas encore là à la compilation)
	_check(terrain.is_choke(Vector2i(5, 5)) and not terrain.is_choke(Vector2i(5, 8)), "le passage dans le mur est un goulet, pas le champ")
	_check(terrain.is_high(Vector2i(9, 9)), "la petite hauteur est un point haut")
	_check(terrain.is_hide(Vector2i(1, 10)) and terrain.is_hide(Vector2i(2, 4)) and not terrain.is_hide(Vector2i(8, 8)),
		"herbes hautes et pied du mur : cachettes ; le champ : non")
	_check(terrain.nearest("choke", Vector2(5.5, 7.5), 3.0) == Vector2i(5, 5), "le goulet le plus proche est trouvé")
	# Sur une vraie carte : des annotations, et un piège posé dans un goulet quand il y en a un tout près.
	var scene := _scene(4.0)
	var counts: Dictionary = scene["battle"].terrain.summary()
	print("    étage 3, graine 21 : %s" % counts)
	_check(counts["cachettes"] > 0, "une carte générée a des cachettes")


func _check_search() -> void:
	print("Recherche intelligente et carte de fuite")
	var scene := _scene(3.0, "alerte")
	var battle = scene["battle"]
	var monster: Dictionary = scene["monster"]
	var hero: Dictionary = scene["hero"]
	var map = battle.map
	monster["state"] = "alerte"
	battle.alert.alarm = false
	# Le monstre voit le héros : la carte se resserre sur lui.
	battle.perception.update()
	battle.search._due = 0.0
	battle.search.tick()
	var at: int = map.index(map.cell_of(hero["pos"]))
	_check(is_equal_approx(battle.search.heat[at], 1.0), "un héros vu : toute la chaleur sur sa case")
	# Le héros disparaît (loin, dans un coin) et le monstre regarde ailleurs : la chaleur se répand ; ce qu'il regarde est
	# effacé.
	hero["pos"] = Vector2(16.5, 18.5)
	monster["facing"] = Vector2(0, -1)
	monster["knows"].clear()
	battle.perception.update()
	for i in 6:
		battle.time += 0.5
		battle.search._due = 0.0
		battle.search.tick()
	var spread := 0
	for value in battle.search.heat:
		spread += 1 if value > 0.0 else 0
	_check(spread > 4 and battle.search.heat[map.index(Vector2i(6, 2))] == 0.0, "la chaleur s'est répandue (%d cases) et le monstre a effacé ce qu'il voit" % spread)
	_check(battle.search.think(monster) and battle.search.claims.has(monster["id"]), "il part fouiller la case la plus probable")
	# Deux chercheurs ne visent pas la même case.
	var other: Dictionary = battle.enemies[1]
	other["present"] = true
	other["hp"] = maxi(1, other["hp"])
	other["state"] = "alerte"
	other["pos"] = monster["pos"] + Vector2(1, 0)
	battle.search.think(other)
	var a: Vector2 = BattleMap.center(map.cell_at(battle.search.claims[monster["id"]]))
	var b: Vector2 = BattleMap.center(map.cell_at(battle.search.claims[other["id"]]))
	_check(a.distance_to(b) >= game.SEARCH_CLAIM_RADIUS or battle.search.heat.count(0.0) > battle.search.heat.size() - 3,
		"deux chercheurs fouillent deux endroits (%.1f cases d'écart)" % a.distance_to(b))
	# Carte de fuite : loin du monstre connu.
	hero["pos"] = monster["pos"] + Vector2(0, 2)
	hero["knows"][monster["id"]] = {"pos": monster["pos"], "t": battle.time}
	var flee: Vector2 = battle.search.flee_target(hero)
	_check(flee.distance_to(monster["pos"]) > hero["pos"].distance_to(monster["pos"]) + 2.0,
		"un héros qui s'enfuit court loin du monstre (%.1f cases de lui)" % flee.distance_to(monster["pos"]))


func _check_coordination() -> void:
	print("Coordination")
	# Contournement : un second monstre prend la place à l'opposé du premier autour du héros.
	var scene := _scene(3.0)
	var battle = scene["battle"]
	var hero: Dictionary = scene["hero"]
	var first: Dictionary = scene["monster"]
	var second: Dictionary = battle.enemies[1]
	for m in [first, second]:
		m["present"] = true
		m["hp"] = maxi(1, m["hp"])
		m["ranged"] = false
		m["state"] = "alerte"
		m["slot"] = -1
	hero["pos"] = Vector2(10.5, 10.5)
	first["pos"] = Vector2(10.5, 8.5)
	second["pos"] = Vector2(10.5, 7.5)
	var a: int = battle._attack_slot(first, hero)
	var b: int = battle._attack_slot(second, hero)
	var da: Vector2 = Vector2(battle.map.cell_at(a) - battle.map.cell_of(hero["pos"]))
	var db: Vector2 = Vector2(battle.map.cell_at(b) - battle.map.cell_of(hero["pos"]))
	_check(da.normalized().dot(db.normalized()) < 0.0, "deux monstres : le second contourne le héros (places %s et %s)" % [da, db])
	# Assassinat synchronisé : un héros ami d'un infiltrateur devient son équipier ; à portée, ils s'attendent.
	var team := _team(game.floor_enemy_level(3) + 2)
	var assassin: Dictionary = game.dev_create_hero(3, "Assassin")
	team[0] = assassin
	var layout: Dictionary = load("res://scripts/map_generator.gd").generate(3, game.floor_quest(3), 21)
	var fight = load("res://scripts/battle.gd").new(team, layout["enemies"], game.floor_quest(3))
	fight.map_data = layout["map"]
	fight.forced_disposition = "camp"
	fight.start()
	var lead: Dictionary = fight.heroes[0]
	var explore = fight.explore
	# (un équipier possible : au corps à corps ou tireur, assez audacieux ; on le fait ami de l'Assassin)
	var engine = load("res://scripts/game_data/personality_engine.gd")
	var mate: Dictionary = {}
	for h in fight.heroes.slice(1):
		if mate.is_empty() and not h["class"] in ["Mage", "Soigneur"] and engine.axis(h["source"], "AUD") >= -game.PRUDENT_AUD:
			mate = h
	if mate.is_empty():
		mate = fight.heroes[1]
		mate["class"] = "Guerrier"
	for h in fight.heroes:
		h["bonds"].clear()
	lead["bonds"][mate["id"]] = game.BOND_FRIEND
	mate["bonds"][lead["id"]] = game.BOND_FRIEND
	explore.infiltrators.clear()
	explore.infiltrators[lead["id"]] = true
	explore.partners.clear()
	explore.mates.clear()
	explore.setup_partners()
	_check(explore.partners.get(mate["id"], -1) == lead["id"], "l'ami de l'Assassin devient son équipier")
	# À portée chacun de sa proie : le premier attend l'autre, puis ils frappent ensemble.
	explore._infiltrating[lead["id"]] = fight.enemies[0]["id"]
	explore._infiltrating[mate["id"]] = fight.enemies[1]["id"]
	var waits: bool = not explore._strike_now(lead)
	var together: bool = explore._strike_now(mate)
	var after: bool = explore._strike_now(lead)
	_check(waits and together and after and explore.counts["synchronises"] == 1,
		"à portée, l'Assassin attend son équipier, puis ils frappent au même pas")
	fight.time += game.SYNC_WAIT + 0.5
	explore._ready.clear()
	explore._strike_now(lead)
	fight.time += game.SYNC_WAIT + 0.1
	_check(explore._strike_now(lead), "sans nouvelles de l'équipier, il frappe seul au bout de %.0f s" % game.SYNC_WAIT)


func _check_formation() -> void:
	print("Formations et bonds d'abri en abri")
	var scene := _scene(4.0)
	var battle = scene["battle"]
	var hero: Dictionary = scene["hero"]
	var explore = battle.explore
	var map = battle.map
	# À découvert : en éventail.
	hero["pos"] = Vector2(10.5, 12.5)
	explore._pick_formation(hero)
	var open_formation: String = explore.formation
	# Dans un passage d'une case entre deux murs : en file.
	map.fill(Rect2i(0, 12, 10, 1), BattleMap.Kind.BLOCK, 2)
	map.fill(Rect2i(11, 12, 13, 1), BattleMap.Kind.BLOCK, 2)
	map.fill(Rect2i(0, 13, 10, 1), BattleMap.Kind.BLOCK, 2)
	map.fill(Rect2i(11, 13, 13, 1), BattleMap.Kind.BLOCK, 2)
	map.build_graph()
	explore._pick_formation(hero)
	_check(open_formation == "coin" and explore.formation == "colonne", "à découvert en éventail, dans un passage étroit en file (%s, %s)" \
		% [open_formation, explore.formation])
	# D'abri en abri : des herbes hautes sur le chemin du but, le meneur y va d'abord.
	var flat := _scene(4.0)
	var leader: Dictionary = flat["hero"]
	var fexplore = flat["battle"].explore
	var fmap = flat["battle"].map
	leader["pos"] = Vector2(10.5, 18.5)
	fexplore.goal = Vector2(10.5, 10.5)
	fmap.fill(Rect2i(10, 16, 1, 1), BattleMap.Kind.GRASS, 0)
	fmap.build_graph()
	flat["battle"].terrain = load("res://scripts/battle_terrain.gd").new(fmap)
	var first: Vector2 = fexplore._bound(leader)
	_check(first == BattleMap.center(Vector2i(10, 16)), "le meneur va d'abord à l'abri sur son chemin (%s)" % first)
	leader["pos"] = first
	var pause: Vector2 = fexplore._bound(leader)
	_check(pause == leader["pos"] and fexplore.counts["bonds_abri"] == 1, "arrivé à l'abri, il marque une pause")


func _check_camp() -> void:
	print("Camps et nuit")
	var quest: Dictionary = game.floor_quest(3)
	var results := {}
	for dispo in ["camp", "endormis", "patrouilles"]:
		var layout: Dictionary = load("res://scripts/map_generator.gd").generate(3, quest, 21)
		var battle = load("res://scripts/battle.gd").new(_team(game.floor_enemy_level(3) + 2), layout["enemies"], quest)
		battle.map_data = layout["map"]
		battle.forced_disposition = dispo
		battle.start()
		results[dispo] = battle
	var camp = results["camp"]
	var blocked: bool = camp.alert.tents.all(func(c): return camp.map.kind_at(c) == BattleMap.Kind.BLOCK)
	_check(camp.alert.tents.size() >= 2 and blocked and camp.alert.fire.x >= 0,
		"un camp : un feu et %d tentes (des obstacles)" % camp.alert.tents.size())
	_check(not camp.is_night() and results["endormis"].is_night() and not results["patrouilles"].is_night(),
		"le camp endormi se passe la nuit, les autres de jour")
	_check(results["patrouilles"].alert.tents.is_empty(), "des patrouilles : pas de camp")


func _check(ok: bool, text: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "ÉCHEC", text])
	if not ok:
		failures += 1
