extends SceneTree
## Vérification de l'étape A (notes du porteur du projet) en mode normal : un héros stabilisé reprend le combat, un
## héros encore à l'agonie à la fin de l'étage est soigné, l'entraînement automatique (suggestions, à plusieurs,
## nouveaux programmes). Il RECOMMENCE la partie : le lancer dans une COPIE du projet (override.cfg) :
##   Godot --path <copie> -s res://tools/test_etapeA.gd [-- captures=<dossier>]

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
	seed(4)
	game.reset_game()
	game.tutorial_step = ""
	game.seen_tips = game.TIP_IDS.duplicate()
	game.daily_report_day = Time.get_date_string_from_system()
	_check_agony()
	await _check_training()
	print("")
	print("RÉSULTAT : %s" % ("tout est bon" if failures == 0 else "%d problème(s)" % failures))
	quit(1 if failures > 0 else 0)


func _battle(team: Array):
	var layout: Dictionary = load("res://scripts/map_generator.gd").generate(1, game.floor_quest(1), 12)
	var battle = load("res://scripts/battle.gd").new(team, layout["enemies"], game.floor_quest(1))
	battle.map_data = layout["map"]
	battle.start()
	return battle


func _team() -> Array:
	var team := []
	for rarity in [3, 2, 1]:
		team.append(game._create_hero(rarity))
	return team


func _check_agony() -> void:
	print("Notes 1 et 3 : agonie et stabilisation")
	var battle = _battle(_team())
	var fallen: Dictionary = battle.heroes[0]
	var helper: Dictionary = battle.heroes[1]
	battle._start_agony(fallen, "test")
	fallen["embedded"] = false
	helper["pos"] = fallen["pos"] + Vector2(0.6, 0)
	helper["order"] = {}
	for i in 40:  # 4 s (il en faut 3 à son côté)
		helper["pos"] = fallen["pos"] + Vector2(0.6, 0)
		battle._agony_tick(fallen)
		battle.time += battle.TICK
	_check(fallen["stabilized"] and not fallen["agony"] and fallen["hp"] > 0, "stabilisé par un allié")
	_check(fallen["present"], "note 1 : il reste sur le terrain et reprend le combat")
	_check(battle._alive(battle.heroes).has(fallen), "il compte parmi les combattants debout")
	# Note 3 : à la fin de l'étage, ceux qui sont encore à l'agonie sont soignés (s'il reste un héros debout).
	var end = _battle(_team())
	var dying: Dictionary = end.heroes[0]
	end._start_agony(dying, "test")
	dying["embedded"] = true  # même une arme plantée
	end.victory = true
	end._finish()
	_check(not dying["agony"] and dying["killer"] == "" and dying["hp"] > 0, "note 3 : soigné à la fin de l'étage (arme plantée comprise)")
	var wipe = _battle(_team())
	for hero in wipe.heroes:
		wipe._start_agony(hero, "test")
		hero["embedded"] = false
	wipe._finish()
	_check(wipe.heroes.all(func(h): return h["killer"] != ""), "toute l'équipe à terre : personne ne les ramène")


func _check_training() -> void:
	print("Note 2 : entraînement automatique")
	game.weapon_draws = game.TRAINING_UNLOCK_DRAWS
	var archer: Dictionary = game.dev_create_hero(3, "Archer")
	var knight: Dictionary = game.dev_create_hero(3, "Chevalier")
	for rarity in [2, 1, 1, 1, 1]:
		game.dev_create_hero(rarity)
	_check(game.TRAINING_SKILLS.size() >= 7, "programmes : %s" % ", ".join(game.TRAINING_SKILLS))
	_check(game.training_suggestion(archer) == "Maîtrise de l'arc", "suggestion pour un archer : %s" % game.training_suggestion(archer))
	var knight_order: Array = game.training_order(knight)
	_check(knight_order.slice(0, 2).has("Utilisation du bouclier"), "un chevalier : le bouclier tôt (%s)" % ", ".join(knight_order))
	var result: Dictionary = game.auto_fill_training()
	print("    inscrits : %s ; refus : %s" % [result["enrolled"], result["refusals"]])
	_check(game.trainees().size() == mini(game.TRAINING_SLOTS, 7) or not result["refusals"].is_empty(), "à plusieurs : %d places remplies" % game.trainees().size())
	_check(game.trainees().all(func(h): return h["training_auto"] and h["training"] == game.training_suggestion(h)), "chacun en auto sur sa suggestion")
	# Programme fini : il passe au suivant tout seul.
	if game.trainees().has(archer):
		for skill in archer["skills"]:
			if skill["name"] == "Maîtrise de l'arc":
				skill["level"] = game.SKILL_MAX_LEVEL
		if game.skill_level(archer["skills"], "Maîtrise de l'arc") == 0:
			archer["skills"].append({"name": "Maîtrise de l'arc", "rank": "Débutant", "level": game.SKILL_MAX_LEVEL})
		archer["training_since"] = Time.get_unix_time_from_system() - game.TRAINING_SESSION_SECONDS - 1
		game.update_training()
		_check(archer["training"] != "Maîtrise de l'arc" and archer["training"] != "", "arc au maximum : il passe à %s" % archer["training"])
	# Les points d'un programme compté autrement (l'arc, par flèche) : autant de séances par niveau que les autres.
	var lancer: Dictionary = game.dev_create_hero(1, "Novice")
	game.set_training(lancer, "Maîtrise de la lance") if game.trainees().size() < game.TRAINING_SLOTS else null
	# L'écran du terrain.
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 20:
		await process_frame
	main.show_screen("training")
	for i in 5:
		await process_frame
	var texts := _texts(main.screens["training"])
	_check(texts.any(func(t): return t.begins_with("Suggestion du Système")), "suggestions affichées sur l'écran")
	if captures != "" and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(captures.path_join("terrain.png"))


func _texts(node: Node) -> Array:
	var result := []
	if node is Label or node is Button:
		result.append(node.text)
	for child in node.get_children():
		result.append_array(_texts(child))
	return result


func _check(ok: bool, text: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "ÉCHEC", text])
	if not ok:
		failures += 1
