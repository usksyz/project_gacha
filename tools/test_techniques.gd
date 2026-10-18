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


func _check(ok: bool, text: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "ÉCHEC", text])
	if not ok:
		failures += 1
