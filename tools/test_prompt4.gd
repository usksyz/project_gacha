extends SceneTree
## Vérification du prompt 4 (une personnalité qu'on voit) en mode normal : bulles de la cité 3D, demandes Oui / Non
## et confiance, rapport du jour de la fée, indice avant une synthèse. Il RECOMMENCE la partie : le lancer dans une
## COPIE du projet (worktree + override.cfg, voir CLAUDE.md) :
##   Godot --path <copie> -s res://tools/test_prompt4.gd [-- captures=<dossier>]
## Avec une fenêtre et « captures=<dossier> » : images des bulles, d'une demande, du rapport, de l'indice.

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
	var settings: Node = root.get_node("Settings")
	settings.dev_mode = false
	settings.new_visuals = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("captures="):
			captures = arg.get_slice("=", 1)
	seed(3)
	game.reset_game()
	game.tutorial_step = ""
	game.seen_tips = game.TIP_IDS.duplicate()  # (pas de conseils par-dessus les images)
	game.daily_report_day = Time.get_date_string_from_system()  # (le rapport : plus bas)
	for rarity in [3, 3, 2, 1, 1, 1]:
		game.dev_create_hero(rarity)
	var heroes: Array = game.alive_heroes()
	_check_chatter(heroes)
	_check_requests(heroes)
	_check_report()
	_check_hints(heroes)
	await _check_screens(heroes)
	print("")
	print("RÉSULTAT : %s" % ("tout est bon" if failures == 0 else "%d problème(s)" % failures))
	quit(1 if failures > 0 else 0)


func _check_chatter(heroes: Array) -> void:
	print("Point 1 : bulles")
	var a: Dictionary = heroes[0]
	var b: Dictionary = heroes[1]
	var c: Dictionary = heroes[2]
	game.make_hostile(a, b)
	game.set_bond_level(a, c, game.BOND_FRIEND)
	var kinds := {}
	var clean := true
	for i in 300:
		var said: Dictionary = game.chatter(a, [b, c])
		kinds[said["kind"]] = kinds.get(said["kind"], 0) + 1
		clean = clean and digits.search(said["text"]) == null and said["reason"] != ""
	print("    sortes sur 300 : %s" % kinds)
	_check(kinds.get("avoid", 0) > 0 and kinds.get("encourage", 0) > 0 and kinds.get("complain", 0) > 0, "il évite son rival, encourage son ami, se plaint")
	_check(clean, "jamais de chiffres dans une bulle ; une raison pour le mode dev")
	var alone: Dictionary = game.chatter(a, [])
	_check(alone["kind"] != "avoid" and alone["kind"] != "encourage", "seul : ni éviter ni encourager")


func _check_requests(heroes: Array) -> void:
	print("Point 2 : demandes")
	var hero: Dictionary = heroes[3]
	for other in heroes:
		PersonalityEngine.set_tier(other, "AMB", 0)
		PersonalityEngine.set_tier(other, "LOY", 0)
		PersonalityEngine.set_tier(other, "PER", 0)
		PersonalityEngine.set_tier(other, "VIT", 0)
		other["training"] = ""
		other["post"] = ""
	PersonalityEngine.set_tier(hero, "AMB", 6)
	var request: Dictionary = game.roll_request()
	_check(request.get("kind", "") == "join" and request["hero"] == hero["id"], "un ambitieux sans équipe veut rejoindre une équipe")
	game.pending_requests = [request]
	var shown: Dictionary = game.next_request()
	_check(shown["text"].contains("souhaite rejoindre l'équipe") and digits.search(shown["text"].replace(game.team_name(request["team"]), "")) == null, "« %s »" % shown["text"])
	var trust_before: float = PersonalityEngine.trust(hero)
	var result: Array = game.answer_request(shown, true)
	_check(hero["id"] in game.teams[request["team"]], "Oui : il rejoint l'équipe")
	_check(PersonalityEngine.trust(hero) > trust_before, "Oui : sa confiance monte")
	_check(not result.is_empty() and digits.search(result[0].replace(str(request["team"] + 1), "")) == null, "réaction : « %s »" % result[0])
	# Repos : un héros fatigué au travail.
	var worker: Dictionary = heroes[4]
	worker["training"] = "Maîtrise de l'épée"
	worker["mental"] = 40.0
	game.pending_requests = []
	var rest: Dictionary = game.roll_request()
	_check(rest.get("kind", "") == "rest" and rest["hero"] == worker["id"], "un héros fatigué au travail demande du repos")
	game.pending_requests = [rest]
	var card: Dictionary = game.next_request()
	trust_before = PersonalityEngine.trust(worker)
	game.answer_request(card, false)
	_check(PersonalityEngine.trust(worker) < trust_before and not game.is_resting(worker), "Non : confiance en baisse, pas de repos")
	game.pending_requests = [rest]
	game.answer_request(game.next_request(), true)
	_check(game.is_resting(worker), "Oui : jour de repos")
	var progress: int = worker.get("skill_progress", {}).get("Maîtrise de l'épée", 0)
	worker["training_since"] = Time.get_unix_time_from_system() - 3600.0
	game.update_training()
	_check(worker.get("skill_progress", {}).get("Maîtrise de l'épée", 0) == progress, "au repos, pas de séance d'entraînement")
	game.pending_requests = []


func _check_report() -> void:
	print("Point 3 : rapport du jour")
	game.daily_report_day = ""
	_check(game.daily_report_due(), "un rapport par jour")
	var lines: Array = game.take_daily_report()
	print("    %s" % " / ".join(lines))
	_check(lines.size() >= 3 and lines.size() <= 5, "3 à 5 lignes (%d)" % lines.size())
	_check(not lines.any(func(line): return digits.search(line) != null), "aucun chiffre")
	_check(not game.daily_report_due(), "vu pour aujourd'hui")


func _check_hints(heroes: Array) -> void:
	print("Point 4 : indice avant la synthèse")
	var talented: Dictionary = heroes[5]
	talented["growth"] = game.GROWTH[1] + 3
	var hints: Array = game.synthesis_hints([talented, heroes[4]])
	_check(hints.any(func(h): return h["text"] == "%s s'entraîne seul tous les soirs." % talented["name"]), "talent caché : « %s s'entraîne seul tous les soirs. »" % talented["name"])
	_check(not hints.any(func(h): return digits.search(h["text"]) != null), "aucun chiffre")


## Les écrans en vrai : la cité 3D avec des bulles, la carte d'une demande, le rapport, l'indice de la synthèse.
func _check_screens(heroes: Array) -> void:
	print("Écrans")
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame
	main.show_screen("hub")
	for i in 30:
		await process_frame
	var city: Node = _find(main, "HubCity3D")
	_check(city != null, "cité 3D")
	if city != null:
		for walker in city.walkers:
			if walker["state"] == "wait" and city.bubbles.size() < 3:
				for attempt in 20:
					city._maybe_chatter(walker)
					if city.bubbles.any(func(entry): return entry[0] == walker):
						break
		city.cam_distance = 30.0
		city._update_camera()
		for i in 5:
			await process_frame
		_check(not city.bubbles.is_empty(), "des bulles au-dessus des héros (%d)" % city.bubbles.size())
		await _capture("bulles")
	# Une demande (carte Oui / Non), puis le rapport du jour.
	PersonalityEngine.set_tier(heroes[2], "AMB", 6)
	for team in game.teams:
		team.erase(heroes[2]["id"])
	game.pending_requests = [game.roll_request()]
	main._show_city_life()
	await process_frame
	_check(main.has_node("Request"), "carte de demande affichée")
	await _capture("demande")
	main._close_window(main.get_node("Request"))
	game.pending_requests = []
	game.daily_report_day = ""
	await process_frame
	main._show_city_life()
	await process_frame
	_check(main.has_node("DailyReport"), "rapport de la fée affiché")
	await _capture("rapport")
	main._close_window(main.get_node("DailyReport"))
	# L'indice de la synthèse.
	game.buildings.append("synthese")
	main.show_screen("synthesis")
	await process_frame
	var synthesis: Node = main.screens["synthesis"]
	synthesis.target = heroes[0]
	synthesis.sacrifices = [heroes[5]]
	synthesis._on_action()
	await process_frame
	_check(_texts(synthesis.overlay).any(func(t): return t.contains("s'entraîne seul tous les soirs")), "fenêtre « Un détail » avant la fenêtre rouge")
	await _capture("indice")


func _capture(image_name: String) -> void:
	if captures == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(captures.path_join(image_name + ".png"))


func _texts(node: Node) -> Array:
	var result := []
	if node is Label:
		result.append(node.text)
	for child in node.get_children():
		result.append_array(_texts(child))
	return result


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
