extends SceneTree
## Vérification de l'étape C en mode normal. Point 1 : pendant un combat de la Tour, les fenêtres de la cité (demande,
## rapport du jour, construction terminée) attendent la fin du combat, puis s'ouvrent. Il RECOMMENCE la partie :
## dans une COPIE du projet (override.cfg) :
##   Godot --path <copie> -s res://tools/test_etapeC.gd

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
	seed(8)
	game.reset_game()
	game.tutorial_step = ""
	game.seen_tips = game.TIP_IDS.duplicate()
	game.daily_report_day = Time.get_date_string_from_system()
	for rarity in [3, 2, 1, 1]:
		game.dev_create_hero(rarity)
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(20)
	for window_name in main.WINDOW_NAMES:
		if main.has_node(window_name):
			main._close_window(main.get_node(window_name))
	await _frames(5)
	print("Point 1 : pas de fenêtre de la cité par-dessus un combat")
	game.pending_battle = {"floor": 1, "team": [], "enemies": [], "quest": {}}  # un combat en cours
	var hero: Dictionary = game.alive_heroes()[1]
	PersonalityEngine.set_tier(hero, "AMB", 6)
	game.teams = game._empty_teams()
	game.pending_requests = [{"kind": "join", "hero": hero["id"], "team": 0, "reason": "test"}]
	game.requests_changed.emit()
	game.daily_report_day = ""
	game.facility_completed.emit("Construction terminée", ["Test."])
	main._check_held_windows()
	await _frames(5)
	_check(not main.has_node("Request") and not main.has_node("DailyReport") and not main.has_node("Facility"), "pendant le combat : rien ne s'ouvre")
	game.pending_battle = {}  # le combat est fini
	main._check_held_windows()
	await _frames(3)
	_check(main.has_node("Facility"), "après : la construction terminée d'abord")
	main._close_window(main.get_node("Facility"))
	await _frames(2)
	main._check_held_windows()
	await _frames(3)
	_check(main.has_node("DailyReport"), "puis le rapport du jour")
	main._close_window(main.get_node("DailyReport"))
	await _frames(2)
	main._check_held_windows()
	await _frames(3)
	_check(main.has_node("Request"), "puis la demande")
	main._close_window(main.get_node("Request"))
	game.pending_requests = []
	print("Point 3 : affectations automatiques")
	for building in ["forge", "synthese"]:
		if not building in game.buildings:
			game.buildings.append(building)
	for rarity in [1, 1, 2]:
		game.dev_create_hero(rarity)
	for h in game.alive_heroes():
		h["post"] = ""
		h["training"] = ""
	var lines: Array = game.auto_fill_posts()
	print("    %s" % " ; ".join(lines))
	_check(game.posted_heroes("forge").size() == 2 and game.posted_heroes("synthese").size() == 2, "4 postes remplis")
	# Personne de libre (ou à la synthèse) n'est plus doué pour la forge que ceux qui y sont (un Paresseux peut refuser).
	var forge_min := 1000.0
	for h in game.posted_heroes("forge"):
		forge_min = minf(forge_min, game.post_score(h, "forge"))
	var better: Array = game.alive_heroes().filter(func(h): return h.get("post", "") == "synthese" and game.post_score(h, "forge") > forge_min)
	_check(better.is_empty(), "les plus doués pour les métiers sont à la forge")
	print("")
	print("RÉSULTAT : %s" % ("tout est bon" if failures == 0 else "%d problème(s)" % failures))
	quit(1 if failures > 0 else 0)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _check(ok: bool, text: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "ÉCHEC", text])
	if not ok:
		failures += 1
