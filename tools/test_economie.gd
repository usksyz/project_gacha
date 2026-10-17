extends SceneTree
## Vérification de l'économie (prompt 1) en mode normal, sur une partie neuve : gemmes de départ, invocation
## gratuite du jour, garantie sauvegardée, ancienne sauvegarde, gemmes de la Tour, potion de soin, vente.
## Ouvre aussi les écrans touchés (invocation, armurerie, forge) pour vérifier qu'ils se construisent.
## Il RECOMMENCE la partie : le lancer dans une COPIE du projet (worktree + override.cfg, voir CLAUDE.md) :
##   Godot --path <copie> -s res://tools/test_economie.gd [-- captures=<dossier>]
## Sans --headless, « captures=<dossier> » enregistre des images du détail des taux, de l'armurerie et de la forge.

var failures := 0
var started := false


func _process(_delta: float) -> bool:
	if started:
		return false
	started = true
	_run.call_deferred()
	return false


func _run() -> void:
	var game: Node = root.get_node("GameData")
	var settings: Node = root.get_node("Settings")
	settings.dev_mode = false
	var captures := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("captures="):
			captures = arg.get_slice("=", 1)

	print("Partie neuve")
	game.reset_game()
	_check(game.gems == 500, "500 gemmes au départ (%d)" % game.gems)
	_check(game.SUMMON_TYPES["special"]["cost"] == 500, "invocation spéciale à 500 gemmes")
	_check(not game.free_summon_available(), "pas d'invocation gratuite pendant le tutoriel")
	_check(game.free_summon().is_empty(), "free_summon refusée pendant le tutoriel")
	_check(not game.can_sell(), "pas de vente pendant le tutoriel")

	print("Invocation gratuite")
	game.tutorial_step = ""
	_check(game.free_summon_available(), "disponible après le tutoriel")
	var got: Array = game.free_summon()
	_check(got.size() == 1 and game.roster.size() == 1, "elle donne un héros")
	_check(got[0]["rarity"] <= 3 and got[0]["class"] != "Mage", "un héros de l'invocation normale")
	_check(not game.free_summon_available() and game.free_summon().is_empty(), "une seule par jour")
	_check(game.gold == game.SUMMON_TYPES["normal"]["cost"] * game.TUTORIAL_SUMMON_COUNT, "elle ne coûte rien")
	game.free_summon_day = "2000-01-01"
	_check(game.free_summon_available(), "un autre jour : de nouveau disponible")
	game.dev_reset_free_summon()
	_check(game.free_summon_available(), "mode dev : rendue")

	print("Garantie sauvegardée")
	game.real_gems = 500 * 20
	var before: int = game.roster.size()
	game.summon("special", 10)
	game.summon("special", 1)
	_check(game.roster.size() == before + 11, "x10 puis x1 : 11 héros")
	_check(game.real_gems == 500 * 9, "11 x 500 gemmes dépensées")
	var p5: int = game.pity_counter
	var p4: int = game.pity4_counter
	_check(p4 < game.PITY4_LIMIT, "compteur des 4★ sous 10 (%d)" % p4)
	game.free_summon()  # (prise aujourd'hui : sa date doit être relue)
	game.save_game()
	game.pity_counter = 0
	game.pity4_counter = 0
	game.free_summon_day = ""
	game.load_game()
	_check(game.pity_counter == p5 and game.pity4_counter == p4, "compteurs relus (%d, %d)" % [p5, p4])
	_check(game.free_summon_day == game.today_date(), "date de l'invocation gratuite relue")

	print("Ancienne sauvegarde (version 8)")
	var file := ConfigFile.new()
	file.load(game.SAVE_PATH)
	file.set_value("partie", "version", 8)
	file.set_value("partie", "pity", 49)
	file.set_value("partie", "gemmes", 3000)
	file.erase_section_key("partie", "pity4")
	file.erase_section_key("partie", "invocation_gratuite")
	file.save(game.SAVE_PATH)
	game.load_game()
	_check(game.pity_counter == 49 and game.pity4_counter == 0, "ancien pity gardé (49), 4★ à 0")
	_check(game.real_gems == 3000, "gemmes gardées (3000)")
	_check(game.free_summon_available(), "invocation gratuite à prendre")
	file.set_value("partie", "pity", 120)
	file.save(game.SAVE_PATH)
	game.load_game()
	_check(game.pity_counter == 89, "pity borné à 89")

	print("Gemmes de la Tour")
	_check(game.tower_rewards(1)["gems"] == 120, "étage 1 : 120")
	_check(game.tower_rewards(4)["gems"] == 180, "étage 4 : 180")
	_check(game.tower_rewards(5)["gems"] == 600, "étage 5 (boss) : 600")
	_check(game.tower_rewards(10)["gems"] == 900, "étage 10 (boss) : 900")

	print("Potion de soin")
	game.buildings.append("forge")
	game.add_material("Herbe médicinale", "E", 2)
	_check(not game.brew_potion(), "2 herbes : pas assez")
	game.add_material("Herbe médicinale", "F", 2)
	var potions: int = game.material_count(game.POTION)
	_check(game.brew_potion(), "3 herbes : potion préparée")
	_check(game.material_count(game.POTION) == potions + 1 and game.material_count("Herbe médicinale") == 1, "potion +1, herbes -3 (F d'abord)")
	_check(game.mission_potions() >= 1, "l'équipe peut l'emporter dans la Tour")

	print("Vente")
	game.add_material(game.JUNK_NAME, "F", 2)
	game.arsenal.append({"id": 9001, "type": "Épée", "grade": "F", "owner": 0})
	game.arsenal.append({"id": 9002, "type": "Arc", "grade": "E", "owner": 0})
	game.arsenal.append({"id": 9003, "type": "Dague", "grade": "F", "owner": game.roster[0]["id"]})
	var gold_before: int = game.gold
	var value: Dictionary = game.sale_value()
	_check(value["junk"] == 2 and value["weapons"] >= 1, "2 poubelles et les armes F rangées")
	var gained: int = game.sell_all()
	_check(gained == value["gold"] and game.gold == gold_before + gained, "or reçu (%d)" % gained)
	_check(game.material_count(game.JUNK_NAME) == 0, "poubelles vendues")
	var ids: Array = game.arsenal.map(func(weapon): return weapon["id"])
	_check(not 9001 in ids and 9002 in ids and 9003 in ids, "arme F rangée vendue ; E et arme portée gardées")
	_check(game.sell_all() == 0, "plus rien à vendre")

	print("Écrans")
	game.add_material(game.JUNK_NAME, "F", 1)
	# (chargés ici et pas par leur class_name : avec -s, ce script est compilé avant les autoloads)
	await _screen(load("res://scripts/summon_screen.gd").new(), captures, "invocation", func(screen): screen._show_rates("special"))
	await _screen(load("res://scripts/armory_screen.gd").new(), captures, "armurerie", func(screen): screen.on_shown())
	await _screen(load("res://scripts/forge_screen.gd").new(), captures, "forge", func(screen): screen.on_shown())

	print("")
	print("RÉSULTAT : %s" % ("tout est bon" if failures == 0 else "%d problème(s)" % failures))
	quit(1 if failures > 0 else 0)


## Ouvre un écran par-dessus tout, appelle « action », attend deux images (capture si demandé), puis le ferme.
func _screen(screen: Control, captures: String, image_name: String, action: Callable) -> void:
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
	action.call(screen)
	for i in 3:
		await process_frame
	if captures != "" and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(captures.path_join(image_name + ".png"))
	_check(is_instance_valid(screen) and screen.get_child_count() > 0, "écran « %s » construit" % image_name)
	layer.queue_free()


func _check(ok: bool, text: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "ÉCHEC", text])
	if not ok:
		failures += 1
