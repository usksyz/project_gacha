extends SceneTree
## Vérification du prompt 5, point 1 (encart « Prochain palier » de l'écran Donjons), en mode normal.
## Il RECOMMENCE la partie : le lancer dans une COPIE du projet (worktree + override.cfg, voir CLAUDE.md) :
##   Godot --path <copie> -s res://tools/test_prompt5.gd [-- captures=<dossier>]

var failures := 0
var started := false
var captures := ""


func _process(_delta: float) -> bool:
	if started:
		return false
	started = true
	_run.call_deferred()
	return false


func _run() -> void:
	var game: Node = root.get_node("GameData")
	root.get_node("Settings").dev_mode = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("captures="):
			captures = arg.get_slice("=", 1)
	seed(9)
	game.reset_game()
	game.tutorial_step = ""
	var digits := RegEx.create_from_string("\\d")
	var info: Dictionary = game.next_milestone()
	_check(info["floor"] == 5 and info["verdict"].contains("pas encore de héros"), "partie neuve : étage 5, pas de héros")
	_check(info["unlocks"][0] == "le donjon journalier", "l'étage 5 débloque le donjon journalier")
	for rarity in [3, 2, 1, 1, 1]:
		game.dev_create_hero(rarity)
	info = game.next_milestone()
	_check(info["verdict"] == "Tes héros ne sont pas prêts.", "héros de niveau 1 : « %s »" % info["verdict"])
	_check(info["advice"].any(func(a): return a.contains("armurerie")), "conseil : des armes")
	_check(info["advice"].any(func(a): return a.contains("potions")), "conseil : des potions (survie)")
	_check(not ([info["verdict"]] + info["advice"]).any(func(t): return digits.search(t) != null), "avis sans chiffres")
	for hero in game.alive_heroes():
		while hero["level"] < game.floor_enemy_level(5) + 2 and not game.is_max_level(hero):
			game.gain_xp(hero, game.xp_to_next(hero["level"]) - hero["xp"])
	info = game.next_milestone()
	print("    au niveau des monstres + 2 : %s" % info["verdict"])
	_check(info["verdict"] != "Tes héros ne sont pas prêts.", "plus forts : l'avis change")
	game.tower_floor = 6
	info = game.next_milestone()
	_check(info["floor"] == 10 and info["unlocks"].size() == 2, "après l'étage 5 : étage 10 (%s)" % info["quest"])
	_check(info["advice"].any(func(a): return a.contains("défense de la cité")), "étage 10 : avertissement de la défense")
	game.tower_floor = 5
	game.seen_tips = game.TIP_IDS.duplicate()  # (pas de conseil ni de rapport par-dessus l'image)
	game.daily_report_day = Time.get_date_string_from_system()
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 20:
		await process_frame
	main.show_screen("dungeons")
	for i in 5:
		await process_frame
	var texts := _texts(main.screens["dungeons"])
	_check(texts.has("Prochain palier"), "encart « Prochain palier » sur l'écran Donjons")
	if captures != "" and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(captures.path_join("palier.png"))
	print("")
	print("RÉSULTAT : %s" % ("tout est bon" if failures == 0 else "%d problème(s)" % failures))
	quit(1 if failures > 0 else 0)


func _texts(node: Node) -> Array:
	var result := []
	if node is Label:
		result.append(node.text)
	for child in node.get_children():
		result.append_array(_texts(child))
	return result


func _check(ok: bool, text: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "ÉCHEC", text])
	if not ok:
		failures += 1
