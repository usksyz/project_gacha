extends SceneTree
## Vérification du prompt 3 (préparer et comprendre un combat) en mode normal : aperçu d'un étage déjà visité,
## placement des héros par le Maître, bilan d'une défaite. Il RECOMMENCE la partie : le lancer dans une COPIE du
## projet (worktree + override.cfg, voir CLAUDE.md) :
##   Godot --path <copie> -s res://tools/test_prompt3.gd [-- captures=<dossier>]
## Avec une fenêtre et « captures=<dossier> » : images de l'aperçu, du placement (vue de dessus et 3D) et du bilan.

var failures := 0
var started := false
var captures := ""
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
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("captures="):
			captures = arg.get_slice("=", 1)
	seed(5)
	game.reset_game()
	game.tutorial_step = ""
	for rarity in [3, 3, 2, 1, 1]:
		var hero: Dictionary = game.dev_create_hero(rarity)
		while hero["level"] < 5 and not game.is_max_level(hero):
			game.gain_xp(hero, game.xp_to_next(hero["level"]) - hero["xp"])
	await _check_preview()
	await _check_placement()
	await _check_debrief()
	print("")
	print("RÉSULTAT : %s" % ("tout est bon" if failures == 0 else "%d problème(s)" % failures))
	quit(1 if failures > 0 else 0)


## Point 1 : première visite (rien), puis après un combat (carte et ennemis vus).
func _check_preview() -> void:
	print("Point 1 : aperçu de l'étage")
	var before: Dictionary = game.floor_knowledge(1)
	_check(not before["visited"], "première visite : rien de connu")
	var layout: Dictionary = game.floor_layout(1)
	var team: Array = game.alive_heroes()
	game.start_tower_battle(team, layout["enemies"].duplicate(true), game.floor_quest(1), 1, layout["map"])
	var battle = load("res://scripts/battle.gd").new(team, layout["enemies"].duplicate(true), game.floor_quest(1))
	battle.map_data = layout["map"]
	battle.run()
	game.finish_tower_battle(battle)
	var after: Dictionary = game.floor_knowledge(1)
	_check(after["visited"] and not after["witnesses"].is_empty(), "après un combat : %s s'en souviennent" % [after["witnesses"]])
	_check(not after["seen"].is_empty(), "ennemis vus : %s" % [after["seen"].keys()])
	var screen = await _open_screen(load("res://scripts/dungeons_screen.gd").new())
	screen._open_tower(1)
	for i in 5:
		await process_frame
	var texts := _texts(screen.announce_box)
	_check(texts.any(func(t): return t.contains("CE QUE TES HÉROS SAVENT")), "fenêtre « Ce que tes héros savent »")
	_check(_find(screen.announce_box, "FloorPreview") != null, "carte de l'étage dessinée")
	await _capture("apercu")
	screen.get_parent().queue_free()


## Point 2 : le placement par le Maître (prompt 3) est retiré à l'étape E (les héros explorent) : le combat avance tout
## de suite dans les deux vues, sans « Commencer » ; le Meneur organise toujours la défense en survie.
func _check_placement() -> void:
	print("Point 2 : plus de placement (étape E)")
	var settings: Node = root.get_node("Settings")
	for use_3d in [false, true]:
		settings.new_visuals = use_3d
		var layout: Dictionary = game.floor_layout(1)
		var team: Array = game.alive_heroes()
		var battle = load("res://scripts/battle.gd").new(team, layout["enemies"].duplicate(true), game.floor_quest(1))
		battle.map_data = layout["map"]
		battle.start()
		var view = await _open_screen(load("res://scripts/battle_view.gd").new())
		view.play(battle, "Exploration")
		# (octobre 2026, bancs sur GitHub) sur une machine rapide, 10 images peuvent durer moins d'un pas du combat :
		# on attend aussi un peu de vrai temps.
		for i in 10:
			await process_frame
		await create_timer(0.5).timeout
		_check(view.pause_button.visible and battle.time > 0.0, "le combat avance tout de suite (%s)" % ("3D" if use_3d else "dessus"))
		await _capture("exploration_" + ("3d" if use_3d else "dessus"))
		view.get_parent().queue_free()
	settings.new_visuals = true
	# Le Meneur organise la défense (survie, étage 5, deux boucliers et un Meneur).
	var team := []
	for rarity in [3, 3, 2, 1, 1]:
		var member: Dictionary = game._create_hero(rarity)
		member["class"] = "Guerrier" if team.size() < 3 else "Archer"
		team.append(member)
	game.arsenal = []
	for i in 3:
		game.arsenal.append({"id": 100 + i, "type": "Épée", "grade": "D", "owner": team[i]["id"]})
		game.arsenal.append({"id": 200 + i, "type": "Bouclier", "grade": "D", "owner": team[i]["id"]})
	team[0]["persona"]["legacy_traits"].append("Meneur")
	var quest: Dictionary = game.floor_quest(5)
	var floor5: Dictionary = load("res://scripts/map_generator.gd").generate(5, quest, 31)  # (pas le class_name : -s)
	var survival = load("res://scripts/battle.gd").new(team, floor5["enemies"], quest)
	survival.map_data = floor5["map"]
	survival.start()
	survival.step()
	_check(survival.alert.disposition == "horde", "survie : la horde (pas d'exploration)")
	_check(survival.formations_used.any(func(f): return f.begins_with("défense du Meneur")), "le Meneur organise la défense")
	_check(survival.heroes[1]["order"].get("by", "") == "meneur", "un bouclier est placé par le Meneur")

## Point 3 : bilan après une défaite (ou une mort), 3 à 5 phrases sans chiffres, racontées par un survivant.
func _check_debrief() -> void:
	print("Point 3 : bilan")
	var shown := false
	var digits := RegEx.create_from_string("\\d")
	for attempt in 30:
		var team := []
		for rarity in [2, 1, 1, 1, 1]:
			var member: Dictionary = game.dev_create_hero(rarity)
			team.append(member)
		var quest: Dictionary = game.floor_quest(4)
		var layout: Dictionary = load("res://scripts/map_generator.gd").generate(4, quest, 900 + attempt)
		game.pending_battle = {"floor": 4, "team": [], "enemies": [], "quest": quest}
		var battle = load("res://scripts/battle.gd").new(team, layout["enemies"], quest)
		battle.map_data = layout["map"]
		battle.run()
		var report: Dictionary = game.finish_tower_battle(battle)
		var expected: bool = not battle.victory or not report["dead"].is_empty()
		_check(report.has("debrief") == expected, "essai %d : bilan %s" % [attempt + 1, "montré" if expected else "absent (victoire sans mort)"])
		if not report.has("debrief"):
			continue
		var lines: Array = report["debrief"]["lines"]
		print("    récit de %s : %s" % [report["debrief"]["narrator"], " / ".join(lines)])
		var narrator: String = report["debrief"]["narrator"]
		_check(narrator == "" or battle.heroes.any(func(f): return f["name"] == narrator and (f["hp"] > 0 or f.get("stabilized", false))), "narrateur survivant")
		_check(narrator == "" or (lines.size() >= 3 and lines.size() <= 5), "3 à 5 moments (%d)" % lines.size())
		_check(not lines.any(func(line): return digits.search(line) != null), "aucun chiffre")
		if not shown and narrator != "":
			shown = true
			var screen = await _open_screen(VBoxContainer.new())
			for window in load("res://scripts/ui.gd").make_battle_report_windows(report):
				screen.add_child(window)
			for i in 5:
				await process_frame
			await _capture("bilan")
			screen.get_parent().queue_free()
		if shown and attempt >= 4:
			break
	_check(shown, "au moins un bilan raconté")


## Ouvre un écran par-dessus tout (dans un calque), attend qu'il soit prêt.
func _open_screen(screen: Control):
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = 50
	root.add_child(layer)
	var back := ColorRect.new()
	back.color = Color("1b1d29")
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(back)
	layer.add_child(screen)
	await process_frame
	return screen


func _capture(image_name: String) -> void:
	if captures == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(captures.path_join(image_name + ".png"))


## Tous les textes des labels sous un nœud.
func _texts(node: Node) -> Array:
	var result := []
	if node is Label:
		result.append(node.text)
	for child in node.get_children():
		result.append_array(_texts(child))
	return result


## Le premier nœud dont le script porte ce nom de classe.
func _find(node: Node, class_title: String) -> Node:
	var script: Script = node.get_script()
	if script != null and script.get_global_name() == class_title:
		return node
	for child in node.get_children():
		var found := _find(child, class_title)
		if found != null:
			return found
	return null


func _check(ok: bool, text: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "ÉCHEC", text])
	if not ok:
		failures += 1
