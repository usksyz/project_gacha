extends Node
## Vérifications de l'étape C2 (vue isométrique) : captures d'écran, ordres sur un toit et sur la rue, et
## combats identiques avec ou sans la vue 3D. À lancer AVEC une fenêtre (pas --headless : il faut le rendu),
## dans une copie du projet avec un override.cfg (dossier de sauvegarde à part, voir CLAUDE.md, P1a-bis) :
##   Godot --path <copie> res://tools/capture_c2.tscn -- mode=capture etage=5 graine=31 avance=6 rot=0 out=C:/.../e5.png
## Modes :
##   capture : image de l'écran de combat. Options : etage, graine (carte), avance (secondes de combat avant
##     (point 8 : « dispo=camp|endormis|... » impose la disposition des monstres)
##     la capture), rot (quarts de tour de la caméra, 0 à 3), choisi (numéro du héros choisi : murs et toits
##     transparents devant lui), archer_toit=oui (un héros tireur posé d'office sur un toit, pour l'image), zoom.
##   ordres : touche un héros, puis un toit, puis la rue, comme un doigt (lancer de rayon), et vérifie la case
##     visée et que le héros monte bien sur le toit.
##   identique : le même combat joué deux fois (graine du hasard égale), sans écran puis à travers l'écran 3D :
##     tout doit être pareil (vainqueur, temps, vie de chacun, journal). (Le placement du prompt 3 n'existe plus
##     depuis l'étape E.)
## Affiche « C2 ... OK » ou « C2 ... ÉCHEC » et quitte.

var _args := {}


func _ready() -> void:
	_args = {"mode": "capture", "etage": "1", "graine": "7", "avance": "5", "rot": "0", "choisi": "-1",
		"archer_toit": "non", "zoom": "", "out": "user://capture_c2.png", "combats": "3", "dispo": "", "calque": ""}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=")
		if parts.size() == 2:
			_args[parts[0]] = parts[1]
	Settings.new_visuals = true  # (pas enregistré)
	Settings.dev_mode = true     # compteur d'images par seconde visible sur la capture
	GameData.roster.clear()
	seed(int(_args["graine"]))
	match _args["mode"]:
		"ordres":
			await _check_orders()
		"identique":
			await _check_identical()
		_:
			await _capture()
	get_tree().quit()


## Un combat prêt (équipe préparée de sim_tower : 3★ + 2★ + 3 x 1★, 2 niveaux au-dessus des monstres).
func _make_battle(floor_number: int, map_seed: int) -> Battle:
	GameData.arsenal = []
	var quest := GameData.floor_quest(floor_number)
	var layout: Dictionary = MapGenerator.generate(floor_number, quest, map_seed)
	var battle := Battle.new(_make_team(floor_number), layout["enemies"], quest)
	battle.map_data = layout["map"]
	battle.forced_disposition = _args.get("dispo", "")  # (point 8 : « dispo=endormis », un camp la nuit)
	battle.start()
	return battle


func _make_team(floor_number: int) -> Array:
	var team := []
	var level := GameData.floor_enemy_level(floor_number) + 2
	for slot in 5:
		var hero: Dictionary = GameData._create_hero([3, 2, 1, 1, 1][slot])
		while hero["level"] < level and not GameData.is_max_level(hero):
			GameData.gain_xp(hero, GameData.xp_to_next(hero["level"]) - hero["xp"])
		if not GameData.uses_magic(hero):
			var kit: Array = ["Arc"] if hero["class"] == "Archer" or slot == 4 else ["Épée", "Bouclier"]
			for type in kit:
				GameData.arsenal.append({"id": GameData.arsenal.size() + 1, "type": type, "grade": "D", "owner": hero["id"]})
		team.append(hero)
	return team


func _make_view(battle: Battle, title: String) -> BattleView:
	var view := BattleView.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(view)
	view.play(battle, title)
	return view


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


## Pose un combattant d'office sur une case (seulement pour l'image ou le test : pas une règle du jeu).
func _place(unit: Dictionary, battle: Battle, cell: Vector2i) -> void:
	unit["pos"] = Vector2(cell) + Vector2(0.5, 0.5)
	unit["prev_pos"] = unit["pos"]
	unit["cell"] = cell
	unit["z"] = battle.map.height_at(cell)
	unit["order"] = {"kind": "move", "pos": unit["pos"]}  # il y reste (son poste)


## Une case de toit (ROOF), la plus proche du bas de la carte (côté héros) ; Vector2i(-1, -1) s'il n'y en a pas.
func _roof_cell(battle: Battle) -> Vector2i:
	var best := Vector2i(-1, -1)
	for i in battle.map.kinds.size():
		if battle.map.kinds[i] == BattleMap.Kind.ROOF:
			var cell := battle.map.cell_at(i)
			if best.x < 0 or cell.y > best.y:
				best = cell
	return best


func _capture() -> void:
	var battle := _make_battle(int(_args["etage"]), int(_args["graine"]))
	var shooter: Dictionary = battle.heroes.filter(func(h): return h["ranged"])[0] if battle.heroes.any(func(h): return h["ranged"]) else battle.heroes[0]
	if _args["archer_toit"] == "oui":
		var roof := _roof_cell(battle)
		if roof.x >= 0:
			_place(shooter, battle, roof)
	if _args["choisi"] == "archer":
		_args["choisi"] = str(battle.heroes.find(shooter))
	var view := _make_view(battle, "Étage %s" % _args["etage"])
	view.paused = true  # le combat n'avance que par les pas ci-dessous (l'image tombe pile au bon moment)
	for i in int(float(_args["avance"]) / Battle.TICK):
		battle.step()
	view._advance()
	var view3d := view.arena3d
	view3d.turn = int(_args["rot"]) % 4
	view3d.yaw = BattleView3D.YAW_DEG + view3d.turn * 90.0
	if _args["zoom"] != "":
		view3d.zoom = float(_args["zoom"])
	view3d._update_camera()
	var chosen := int(_args["choisi"])
	if chosen >= 0 and chosen < battle.heroes.size():
		view.selected_id = battle.heroes[chosen]["id"]
		view._update_hint()
	view3d.fade_timer = 0.0
	view3d.fog_timer = 0.0  # (cartes, étape 4 : le brouillard recalculé pour l'image)
	if _args.get("calque", "") != "":  # (point 9 : « calque=regards|recherche|terrain », en mode dev)
		Settings.dev_mode = true
		view3d.debug_layer = _args["calque"]
	# « cache=oui » : le héros choisi est posé d'office là où un bâtiment le cache à la caméra (pour voir les murs
	# et toits devenir transparents).
	await _frames(5)  # (l'écran 3D doit avoir pris sa taille avant de projeter quoi que ce soit)
	if _args.get("cache", "non") == "oui" and view.selected_id >= 0:
		var hero: Dictionary = battle.units[view.selected_id]
		var best_cell := Vector2i(-1, -1)
		var best_count := 0
		for i in battle.map.kinds.size():
			var cell := battle.map.cell_at(i)
			if battle.map.height_at(cell) != 0 or not battle.map.walkable(cell):
				continue
			_place(hero, battle, cell)
			view3d.fade_timer = 0.0
			view3d._update_fade(0.0)
			if view3d.faded_cells.size() > best_count:
				best_count = view3d.faded_cells.size()
				best_cell = cell
		if best_cell.x >= 0:
			_place(hero, battle, best_cell)
			view3d.fade_timer = 0.0
			view3d._update_fade(0.0)
	await _frames(20)
	var image := get_viewport().get_texture().get_image()
	image.save_png(_args["out"])
	# Images par seconde : 3 secondes de combat en direct, après la capture (les premières images, où les
	# shaders se compilent, ne comptent pas).
	view.paused = false
	await _frames(30)
	var start := Time.get_ticks_usec()
	var frames := 0
	while Time.get_ticks_usec() - start < 3000000:
		await get_tree().process_frame
		frames += 1
	var fps := frames / ((Time.get_ticks_usec() - start) / 1000000.0)
	print("    temps de calcul d'une image %.1f ms, appels de dessin %d, objets %d" % [
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	print("C2 capture OK : %s (étage %s, carte %s, rot %s) — %.0f images/s sur ce PC (synchro écran : %s), %d pièces de décor, %d cases transparentes" % [
		_args["out"], _args["etage"], battle.map_data.get("template", "?"), _args["rot"], fps,
		"oui" if DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED else "non", view3d.parts.size(),
		view3d.faded_cells.size()])


## Ordres par toucher dans la vue 3D : un héros, puis un toit (on doit viser le toit, pas la rue cachée), puis
## la rue devant (on doit viser la rue). Puis le combat avance : le héros doit être monté sur le toit.
func _check_orders() -> void:
	var battle := _make_battle(int(_args["etage"]), int(_args["graine"]))
	var view := _make_view(battle, "Ordres")
	view.paused = true
	await _frames(5)
	var view3d := view.arena3d
	var ok := true
	var roof := _roof_cell(battle)
	if roof.x < 0:
		print("C2 ordres ÉCHEC : pas de toit sur cette carte")
		return
	# Le toucher passe par le même chemin qu'un doigt (BattleView3D.tap → signal → BattleView._arena_tap).
	view.paused = false
	var hero: Dictionary = battle.heroes[0]
	view3d.tap(view3d.project(view3d.unit_feet(hero) + Vector3(0, BattleView3D.BODY_HEIGHT * 0.6, 0)))
	ok = _report(view.selected_id == hero["id"], "toucher un héros le choisit") and ok
	var roof_point := view3d.project(Vector3(roof.x + 0.5, battle.map.height_at(roof) * BattleView3D.LEVEL, roof.y + 0.5))
	var picked: Dictionary = view3d.pick_cell(roof_point)
	ok = _report(picked["cell"] == roof, "lancer de rayon sur le toit %s : case %s (hauteur %d)" % [roof, picked["cell"],
		battle.map.height_at(picked["cell"])]) and ok
	view3d.tap(roof_point)
	var order_cell: Vector2i = battle.map.cell_of(hero["order"].get("pos", Vector2(-1, -1)))
	ok = _report(hero["order"].get("kind", "") == "move" and order_cell == roof, "ordre « aller sur le toit » : case %s" % order_cell) and ok
	# La rue juste devant le toit (côté héros) : visible, au sol.
	var street := roof + Vector2i(0, 1)
	while battle.map.in_bounds(street) and battle.map.height_at(street) > 0:
		street += Vector2i(0, 1)
	var street_point := view3d.project(Vector3(street.x + 0.5, 0.0, street.y + 0.5))
	var street_pick: Dictionary = view3d.pick_cell(street_point)
	ok = _report(street_pick["cell"] == street, "lancer de rayon sur la rue %s : case %s (hauteur %d)" % [street, street_pick["cell"],
		battle.map.height_at(street_pick["cell"])]) and ok
	# La rue cachée derrière le toit (vue de la caméra) : le toucher tombe sur le toit, pas dessous.
	var hidden := roof - Vector2i(0, 1)
	if battle.map.in_bounds(hidden) and battle.map.height_at(hidden) == 0:
		var behind := view3d.project(Vector3(hidden.x + 0.5, 0.0, hidden.y + 0.5))
		var behind_pick: Dictionary = view3d.pick_cell(behind)
		print("    rue derrière le toit %s : le toucher vise %s (hauteur %d)" % [hidden, behind_pick["cell"], battle.map.height_at(behind_pick["cell"])])
	# Le combat avance : il doit monter (par l'échelle) jusqu'au toit.
	view.paused = true
	var reached := false
	for i in int(40.0 / Battle.TICK):
		battle.step()
		if battle.height_of(hero) == battle.map.height_at(roof) and battle.map.cell_of(hero["pos"]) == roof:
			reached = true
			print("    sur le toit après %.1f s (hauteur %d)" % [battle.time, battle.height_of(hero)])
			break
		if battle.finished or hero["hp"] <= 0:
			break
	ok = _report(reached, "le héros monte sur le toit") and ok
	# Ordre « rue » : il redescend, vers une case de rue libre (sans personne dessus, sinon on le choisirait).
	for y in range(roof.y + 1, mini(roof.y + 5, Battle.GRID_H)):
		for x in Battle.GRID_W:
			var candidate := Vector2i(x, y)
			if battle.map.height_at(candidate) == 0 and battle.map.walkable(candidate) \
					and not battle.units.any(func(u): return u["present"] and u["hp"] > 0 and u["pos"].distance_to(Vector2(candidate) + Vector2(0.5, 0.5)) < 1.5) \
					and view3d.pick_cell(view3d.project(Vector3(x + 0.5, 0.0, y + 0.5)))["cell"] == candidate:
				street = candidate
				break
		if street != roof + Vector2i(0, 1):
			break
	view.paused = false
	view3d.tap(view3d.project(view3d.unit_feet(hero) + Vector3(0, BattleView3D.BODY_HEIGHT * 0.6, 0)))
	var street_tap := view3d.project(Vector3(street.x + 0.5, 0.0, street.y + 0.5))
	print("    choisi : %s ; sous le doigt dans la rue : %s ; case visée %s" % [view.selected_id == hero["id"],
		view3d.unit_at_screen(street_tap).get("name", "personne"), view3d.pick_cell(street_tap)["cell"]])
	view3d.tap(street_tap)
	print("    ordre : %s" % hero["order"])
	ok = _report(battle.map.cell_of(hero["order"].get("pos", Vector2(-1, -1))) == street, "ordre « aller dans la rue » : case %s" % street) and ok
	print("C2 ordres %s" % ("OK" if ok else "ÉCHEC"))


func _report(good: bool, text: String) -> bool:
	print(("  ok    " if good else "  ÉCHEC ") + text)
	return good


## Le même combat joué deux fois : sans écran (Battle.run), puis à travers BattleView avec la vue 3D (le
## combat avance par l'écran, image par image). La vue ne doit rien changer.
func _check_identical() -> void:
	var all_ok := true
	for n in int(_args["combats"]):
		var floor_number: int = [1, 5, 10, 2, 3][n % 5]
		var map_seed := 100 + n
		seed(500 + n)
		var a := _make_battle(floor_number, map_seed)
		while not a.finished:  # (pas a.run() : il rappellerait start())
			a.step()
		var summary_a := _summary(a)
		seed(500 + n)
		var b := _make_battle(floor_number, map_seed)

		var view := _make_view(b, "Identique")
		while not b.finished:
			view._process(Battle.TICK)
			if b.time > 600.0:
				break
		var summary_b := _summary(b)
		view.queue_free()
		var same := summary_a == summary_b
		all_ok = all_ok and same
		print("  %s étage %d, carte %d : %s" % ["ok   " if same else "ÉCHEC", floor_number, map_seed, summary_a.substr(0, 90)])
		if not same:
			print("    sans écran : ", summary_a)
			print("    avec écran : ", summary_b)
		await _frames(1)
	print("C2 identique %s" % ("OK" if all_ok else "ÉCHEC"))


func _summary(battle: Battle) -> String:
	var parts := ["victoire" if battle.victory else "défaite", "%.1f s" % battle.time]
	for unit in battle.units:
		parts.append("%s:%d" % [unit["name"], unit["hp"]])
	parts.append("journal %d" % battle.events.size())
	parts.append(str(battle.events.map(func(e): return e["text"]).hash()))
	return " ".join(parts)
