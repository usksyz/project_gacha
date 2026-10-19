extends SceneTree
## Vérification des cartes (cartes, étape 2 : générateur ; étape 4 : brouillard) en mode normal, sans écran. GameData
## démarre (il relit et réécrit la sauvegarde) : dans une COPIE du projet (override.cfg) :
##   Godot --headless --path <copie> -s res://tools/test_cartes.gd

var failures := 0
var started := false
var game: Node
var gen


func _process(_delta: float) -> bool:
	if started:
		return false
	started = true
	_run.call_deferred()
	return false


func _run() -> void:
	game = root.get_node("GameData")
	root.get_node("Settings").dev_mode = false
	gen = load("res://scripts/map_generator.gd")
	_check_templates()
	_check_shape()
	_check_places()
	_check_seed()
	_check_save()
	print("")
	print("RÉSULTAT : %s" % ("tout est bon" if failures == 0 else "%d problème(s)" % failures))
	quit(1 if failures > 0 else 0)


func _check_templates() -> void:
	print("Chaque lieu donne des cartes valides")
	for floor_number in [1, 2, 3, 4, 5, 10]:
		var quest: Dictionary = game.floor_quest(floor_number)
		var flat := 0
		var templates := {}
		for s in 40:
			var data: Dictionary = gen.generate_map(floor_number, quest, s)
			templates[data["template"]] = true
			if data["template"] == "arene" or gen.check(data) != "":
				flat += 1
		_check(flat == 0, "étage %d : 40 cartes valides, aucune carte plate de secours (%s)" % [floor_number, ", ".join(templates.keys())])
	var seen := {}
	for s in 40:
		seen[gen.template_for(3, game.floor_quest(3), s)] = true
	_check(seen.has("foret") and seen.has("relief"), "étages ordinaires : forêt ou relief selon la graine")


func _check_shape() -> void:
	print("Une carte ronde, plus grande")
	var data: Dictionary = gen.generate_map(3, game.floor_quest(3), 4)
	var map := BattleMap.new()
	map.from_data(data)
	_check(map.size == Vector2i(24, 26), "24 x 26 cases (avant : 18 x 20)")
	var outside_walkable := 0
	var outside := 0
	for i in map.kinds.size():
		var cell := map.cell_at(i)
		if not gen.inside(cell):
			outside += 1
			if map.walkable(cell):
				outside_walkable += 1
	_check(outside > 60 and outside_walkable == 0, "hors du disque (%d cases) : la lisière, infranchissable" % outside)
	_check(not gen.inside(Vector2i(0, 0)) and gen.inside(Vector2i(12, 13)), "les coins sont dehors, le centre dedans")
	var heights := {}
	for h in map.heights:
		heights[h] = true
	_check(heights.size() >= 3, "du relief (hauteurs %s)" % ", ".join(heights.keys().map(func(h): return str(h))))


func _check_places() -> void:
	print("Un village ressemble à un village, une forêt à une forêt")
	var houses := 0
	var roads := 0
	for s in 20:
		var data: Dictionary = gen.generate_map(1, game.floor_quest(1), s)
		houses += data["structures"].filter(func(st): return st["kind"] == "house").size()
		roads += data["roads"].size()
	_check(houses / 20.0 >= 4.0, "village : %.1f maisons en moyenne le long de la route" % (houses / 20.0))
	_check(roads / 20.0 >= 30.0, "village : une route de terre (%.0f cases)" % (roads / 20.0))
	var trees := 0
	var count := 0
	for s in 40:
		if gen.template_for(3, game.floor_quest(3), s) != "foret":
			continue
		var data: Dictionary = gen.generate_map(3, game.floor_quest(3), s)
		trees += data["structures"].filter(func(st): return st["kind"] == "trees").size()
		count += 1
	_check(count > 0 and trees / float(count) >= 50.0, "forêt : %.0f arbres en moyenne" % (trees / maxf(1.0, count)))


func _check_seed() -> void:
	print("Même graine, même carte")
	var a: Dictionary = gen.generate_map(2, game.floor_quest(2), 99)
	var b: Dictionary = gen.generate_map(2, game.floor_quest(2), 99)
	_check(a["heights"] == b["heights"] and a["kinds"] == b["kinds"] and a["structures"].size() == b["structures"].size(),
		"deux fois la graine 99 : la même prairie")


func _check_save() -> void:
	print("Sauvegarde : les anciennes cartes sont refaites")
	var old_layout := {"version": 1, "seed": 5, "map": {"version": 1}, "enemies": []}
	game.floors = {3: old_layout, 4: game.floor_layout(4)}
	game.save_game()
	game.load_game()
	_check(not game.floors.has(3) and game.floors.has(4), "un étage figé sur l'ancienne carte est oublié, un étage neuf reste")
	var layout: Dictionary = game.floor_layout(3)
	_check(layout["version"] == gen.MAP_VERSION and layout["map"]["size"] == Vector2i(24, 26), "il est refait sur la nouvelle carte")


func _check(ok: bool, text: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "ÉCHEC", text])
	if not ok:
		failures += 1
