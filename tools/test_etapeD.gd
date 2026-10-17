extends SceneTree
## Vérification de l'étape D (les héros s'entraînent à ce qu'ils veulent, selon ce qu'ils vivent) en mode normal :
## les exemples du porteur du projet (archer pris au contact, épéiste comme Han touché par les tirs, équipe avec un mage
## élémentaire), la répétition qui fait progresser, l'écran du terrain. Il RECOMMENCE la partie : dans une COPIE du
## projet (override.cfg) :
##   Godot --path <copie> -s res://tools/test_etapeD.gd [-- captures=<dossier>]

var failures := 0
var started := false
var captures := ""
var game: Node
var digits := RegEx.create_from_string("\\d")


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
	seed(6)
	game.reset_game()
	game.tutorial_step = ""
	game.seen_tips = game.TIP_IDS.duplicate()
	game.daily_report_day = Time.get_date_string_from_system()
	game.weapon_draws = game.TRAINING_UNLOCK_DRAWS
	_check_examples()
	_check_real_battles()
	await _check_screen()
	print("")
	print("RÉSULTAT : %s" % ("tout est bon" if failures == 0 else "%d problème(s)" % failures))
	quit(1 if failures > 0 else 0)


## Un faux combat qui ne sert qu'à merge_practice : un combattant avec ce qu'il a vécu.
func _fake_battle(hero: Dictionary, practice: Dictionary, allies := []):
	var battle = load("res://scripts/battle.gd").new([hero] + allies, [], {"type": "extermination", "lasting": false, "seconds": 90, "hidden_level": false, "walls": 0, "warnings": 0})
	battle.heroes[0]["practice"] = practice
	return battle


func _check_examples() -> void:
	print("Exemples du porteur du projet")
	# 1. Un archer pris au contact veut apprendre le corps à corps.
	var archer: Dictionary = game.dev_create_hero(3, "Archer")
	var b1 = _fake_battle(archer, {"pris_au_contact": 6})
	game.merge_practice(archer, b1.heroes[0], b1)
	var wish: Dictionary = game.training_wish(archer)
	_check(wish["skill"] == "Maîtrise de la dague", "un archer pris au contact veut le corps à corps : « %s »" % wish["reason"])
	_check(digits.search(wish["reason"]) == null, "sans chiffres")
	# 2. Un épéiste (Han) touché par les tirs veut apprendre à les parer.
	var han: Dictionary = game.redeem_code("HAN")
	if han.is_empty():
		han = game.dev_create_hero(3, "Guerrier")
	var b2 = _fake_battle(han, {"tirs_subis": 5})
	game.merge_practice(han, b2.heroes[0], b2)
	wish = game.training_wish(han)
	_check(wish["skill"] == "Parade des projectiles", "%s touché par les tirs veut les parer : « %s »" % [han["name"], wish["reason"]])
	# 3. Une équipe avec un mage élémentaire : on veut pouvoir se battre à côté de lui.
	var mage: Dictionary = game.dev_create_hero(4, "Mage")
	mage["element"] = "Vent"
	var knight: Dictionary = game.dev_create_hero(3, "Chevalier")
	var b3 = _fake_battle(knight, {"mage:Vent": 3}, [mage])
	game.merge_practice(knight, b3.heroes[0], b3)
	wish = game.training_wish(knight)
	_check(wish["skill"] == "Résistance au vent" and wish["reason"].contains("mage"), "à côté d'un mage de vent : « %s »" % wish["reason"])
	# Les envies s'estompent : après des combats sans tirs subis, Han revient à son arme.
	for i in 8:
		var calm = _fake_battle(han, {})
		game.merge_practice(han, calm.heroes[0], calm)
	_check(game.training_wish(han)["skill"] != "Parade des projectiles", "une envie s'estompe sans nouveau vécu (%s)" % game.training_wish(han)["skill"])
	# Au terrain : il travaille ce qu'il veut, et change quand son envie change.
	game.pending_requests = []
	_check(game.send_to_training(archer) and archer["training"] == "Maîtrise de la dague", "envoyé au terrain : il travaille la dague")
	var b4 = _fake_battle(archer, {"pris_au_contact": 0, "esquives": 0})
	for skill in ["Maîtrise de la dague"]:
		archer["practice_needs"][skill] = 0.0
	archer["practice_needs"]["Maîtrise de l'arc"] = 9.0
	archer["training_since"] = Time.get_unix_time_from_system() - game.TRAINING_SESSION_SECONDS - 1
	game.update_training()
	_check(archer["training"] == "Maîtrise de l'arc", "son envie change : il passe à l'arc à la séance suivante")


## De vrais combats : ce qu'ils vivent est compté, le mage allié éclabousse, la dague de secours progresse.
func _check_real_battles() -> void:
	print("Vrais combats")
	var team := []
	var mage: Dictionary = game.dev_create_hero(4, "Mage")
	mage["element"] = "Froid"
	team.append(mage)
	for entry in [[3, "Chevalier"], [3, "Archer"], [2, ""], [1, ""]]:
		team.append(game.dev_create_hero(entry[0], entry[1]))
	for hero in team:
		while hero["level"] < 9 and not game.is_max_level(hero):
			game.gain_xp(hero, game.xp_to_next(hero["level"]) - hero["xp"])
	var splashed := 0
	var contact := 0
	var dagger_before: int = team[2].get("skill_progress", {}).get("Maîtrise de la dague", 0)
	for i in 6:
		var layout: Dictionary = load("res://scripts/map_generator.gd").generate(3, game.floor_quest(3), 40 + i)
		game.pending_battle = {"floor": 3}
		var battle = load("res://scripts/battle.gd").new(team.filter(func(h): return h["alive"]), layout["enemies"], game.floor_quest(3))
		battle.map_data = layout["map"]
		battle.run()
		for fighter in battle.heroes:
			splashed += fighter["practice"].get("mage:Froid", 0)
			contact += fighter["practice"].get("pris_au_contact", 0)
		game.finish_tower_battle(battle)
	print("    éclaboussures du mage : %d ; pris au contact : %d" % [splashed, contact])
	_check(splashed > 0, "le mage de froid éclabousse ses alliés trop proches")
	_check(team.all(func(h): return not h["alive"] or h.has("practice_needs")), "chacun garde ce qu'il a vécu")
	var anyone_wants_cold := team.any(func(h): return h["alive"] and h["practice_needs"].get("Résistance au froid", 0.0) > 0.0)
	_check(anyone_wants_cold, "certains veulent résister au froid")
	print("    envies : %s" % ", ".join(team.filter(func(h): return h["alive"]).map(func(h): return game.training_wish(h)["reason"])))


func _check_screen() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 20:
		await process_frame
	for window_name in main.WINDOW_NAMES:
		if main.has_node(window_name):
			main._close_window(main.get_node(window_name))
	game.auto_fill_training()
	main.show_screen("training")
	for i in 6:
		await process_frame
	if captures != "" and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(captures.path_join("terrain_envies.png"))


func _check(ok: bool, text: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "ÉCHEC", text])
	if not ok:
		failures += 1
