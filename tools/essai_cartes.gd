extends SceneTree
## Essai des cartes (cartes, étape 2) : pour chaque lieu, combien de graines donnent une carte valide du premier coup,
## combien retombent sur la carte plate, et une carte en lettres. Dans une copie du projet :
##   Godot --headless --path <copie> -s res://tools/essai_cartes.gd
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = root.get_node("GameData")
	var gen = load("res://scripts/map_generator.gd")
	var cases := [[1, game.floor_quest(1)], [2, game.floor_quest(2)], [3, game.floor_quest(3)], [4, game.floor_quest(4)],
		[5, game.floor_quest(5)], [10, game.floor_quest(10)]]
	for entry in cases:
		var counts := {}
		var reasons := {}
		for s in 60:
			var data: Dictionary = gen.generate_map(entry[0], entry[1], s)
			counts[data["template"]] = counts.get(data["template"], 0) + 1
		print("étage %d : %s" % [entry[0], counts])
		# Les raisons d'échec d'un premier essai.
		var rng := RandomNumberGenerator.new()
		for s in 40:
			rng.seed = s
			var t: String = gen.template_for(entry[0], entry[1], s)
			var reason: String = gen.check(gen._build(t, rng))
			if reason != "":
				var key := reason.split(" (")[0]
				reasons[key] = reasons.get(key, 0) + 1
		print("   échecs au premier essai (sur 40) : %s" % reasons)
	for t in [[1, 7], [3, 2], [3, 3], [2, 5], [5, 4], [10, 4]]:
		var data: Dictionary = gen.generate_map(t[0], game.floor_quest(t[0]), t[1])
		print("\n%s (étage %d, graine %d)" % [data["template"], t[0], t[1]])
		var map := BattleMap.new()
		map.from_data(data)
		for y in map.size.y:
			var line := ""
			for x in map.size.x:
				var c := Vector2i(x, y)
				var k := map.kind_at(c)
				var ch := "."
				if not gen.inside(c):
					ch = " "
				elif c in data.get("hero_zone", []):
					ch = "h"
				elif c in data.get("enemy_zone", []):
					ch = "e"
				elif k == BattleMap.Kind.BLOCK:
					ch = "#"
				elif k == BattleMap.Kind.STAIRS:
					ch = "/"
				elif k == BattleMap.Kind.GRASS:
					ch = "\""
				elif k == BattleMap.Kind.ROCK:
					ch = "o"
				elif k == BattleMap.Kind.LOW_WALL:
					ch = "="
				elif k == BattleMap.Kind.ROOF or k == BattleMap.Kind.TOWER:
					ch = "R"
				elif k == BattleMap.Kind.LADDER:
					ch = "H"
				elif k == BattleMap.Kind.RAMPART:
					ch = "W"
				elif map.height_at(c) > 0:
					ch = str(map.height_at(c))
				line += ch
			print(line)
	quit()
