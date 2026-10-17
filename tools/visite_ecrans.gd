extends SceneTree
## Étape C (réanalyse) : monte une partie de milieu de jeu en mode normal (tutoriel fini, 12 héros de niveaux variés,
## armes, bâtiments, matériaux, Tour à l'étage 6) et fait une capture de chaque écran, pour relire l'interface.
## Il RECOMMENCE la partie : dans une COPIE du projet (override.cfg), AVEC une fenêtre :
##   Godot --path <copie> -s res://tools/visite_ecrans.gd -- captures=<dossier>

var started := false
var captures := ""
var game: Node
var main: Control


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
	seed(21)
	game.reset_game()
	game.tutorial_step = ""
	game.seen_tips = game.TIP_IDS.duplicate()
	game.daily_report_day = Time.get_date_string_from_system()
	game.weapon_draws = 30
	game.real_gold = 120000
	game.real_gems = 1400
	game.tower_floor = 6
	for entry in [[3, "Chevalier", 12], [3, "Archer", 11], [4, "Soigneur", 10], [2, "", 9], [1, "", 8], [1, "", 8],
			[1, "", 5], [1, "", 4], [2, "", 6], [3, "Assassin", 9], [1, "", 3], [5, "Mage", 7]]:
		var hero: Dictionary = game.dev_create_hero(entry[0], entry[1])
		while hero["level"] < entry[2] and not game.is_max_level(hero):
			game.gain_xp(hero, game.xp_to_next(hero["level"]) - hero["xp"])
	for i in 20:
		game.arsenal.append({"id": game.next_weapon_id, "type": game.WEAPON_TYPES.keys().pick_random(), "grade": ["F", "E", "D-", "D"].pick_random(), "owner": 0})
		game.next_weapon_id += 1
	for building in ["synthese", "forge"]:
		game.buildings.append(building)
	game.add_material("Minerai de fer", "E", 12)
	game.add_material("Charbon", "F", 6)
	game.add_material("Herbe médicinale", "F", 4)
	var heroes: Array = game.alive_heroes()
	game.teams[0] = heroes.slice(0, 5).map(func(h): return h["id"])
	game.auto_fill_training()
	game.save_game()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(30)
	for window_name in main.WINDOW_NAMES:  # (la fenêtre « Construction terminée » de l'atelier de magie, etc.)
		if main.has_node(window_name):
			main._close_window(main.get_node(window_name))
	await _frames(5)
	for screen in ["hub", "summon", "collection", "dungeons", "training", "armory", "forge", "synthesis"]:
		main.show_screen(screen)
		await _frames(20)
		await _capture("ecran_" + screen)
	# La fiche d'un héros (Collection), haut et bas.
	main.show_screen("collection")
	await _frames(5)
	var collection: Node = main.screens["collection"]
	collection._show_detail(heroes[0])
	await _frames(10)
	await _capture("fiche_haut")
	# Le choix de l'équipe d'un étage, puis le combat (exploration, étape E), puis quelques secondes de combat.
	main.show_screen("dungeons")
	await _frames(5)
	var dungeons: Node = main.screens["dungeons"]
	dungeons._open_tower(6)
	await _frames(20)
	await _capture("annonce_etage")
	dungeons._show_page(dungeons.team_page)
	dungeons._use_team(0)
	await _frames(10)
	await _capture("choix_equipe")
	dungeons._start_fight()
	await _frames(20)
	await _capture("exploration")
	for i in 240:
		await process_frame
	await _capture("combat")
	print("visite terminée")
	quit()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _capture(image_name: String) -> void:
	if captures == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(captures.path_join(image_name + ".png"))
