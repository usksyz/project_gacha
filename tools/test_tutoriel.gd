extends Node
## Vérification du tutoriel d'une partie neuve (étape T1 : tirage d'armes offert), en mode normal (pas le mode
## dev), à travers les vrais écrans : on touche les boutons et les lieux de la cité comme un doigt, on ferme les
## fenêtres comme le joueur. À lancer AVEC une fenêtre (captures) :
##   Godot --path . res://tools/test_tutoriel.tscn -- out=C:/chemin/des/captures vitesse=6
## « vitesse » : Engine.time_scale pendant le combat (le combat reste le même, seulement plus vite à l'écran).
## ATTENTION : recommence la partie (user://sauvegarde.cfg est effacée puis réécrite). Copier la sauvegarde avant
## (voir CLAUDE.md, « Tests et sauvegarde locale »).
## Vérifie aussi les anciennes sauvegardes en plein tutoriel (version 6) et la reprise au lancement.
## Affiche « T1 ... OK » ou « T1 ... ÉCHEC » à chaque contrôle, puis « T1 : n échec(s) » et quitte.

var _args := {}
var _main: Control
var _failures := 0
var _shot := 0


func _ready() -> void:
	_args = {"out": "user://captures_tutoriel", "vitesse": "6"}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=")
		if parts.size() == 2:
			_args[parts[0]] = parts[1]
	DirAccess.make_dir_recursive_absolute(_args["out"])
	Settings.dev_mode = false  # mode normal (pas enregistré)
	Settings.tips = true
	Settings.new_visuals = true
	GameData.reset_game()
	await _check_old_saves()
	GameData.reset_game()
	await _play()
	print("T1 : %d échec(s)" % _failures)
	get_tree().quit()


func _check(label: String, ok: bool, detail := "") -> void:
	print("T1 %s : %s%s" % [label, "OK" if ok else "ÉCHEC", "" if detail == "" else " (%s)" % detail])
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	_shot += 1
	var path := "%s/%02d_%s.png" % [_args["out"], _shot, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("T1 capture : ", path)


## Un bouton visible dont le texte commence par « text », sous « node ».
func _find_button(node: Node, text: String) -> Button:
	for child in node.find_children("*", "Button", true, false):
		var button := child as Button
		if button.is_visible_in_tree() and button.text.begins_with(text):
			return button
	return null


func _press(node: Node, text: String) -> bool:
	var button := _find_button(node, text)
	if button == null or button.disabled:
		return false
	button.pressed.emit()
	await _frames(3)
	return true


## Ferme les fenêtres de main.gd (conseils, bâtiment construit) une par une ; renvoie les titres vus.
func _close_windows(capture_ids := []) -> Array:
	var seen := []
	for i in 20:
		await _frames(4)
		if _main.has_node("Facility"):
			seen.append("Facility")
			await _press(_main.get_node("Facility"), "Plus tard")
			continue
		if not _main.has_node("Tip"):
			break
		var tip: Node = _main.get_node("Tip")
		var title := ""
		for label in tip.find_children("*", "Label", true, false):
			title = (label as Label).text.to_upper()
			break
		seen.append(title)
		if title in capture_ids:
			await _capture(title.validate_filename().replace(" ", "_"))
		await _press(tip, "Compris")
	return seen


func _start_main() -> void:
	if _main:
		_main.queue_free()
		await _frames(2)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await _frames(10)


## Les anciennes sauvegardes (version 6) arrêtées en plein tutoriel, relues par le jeu.
func _check_old_saves() -> void:
	GameData.summon("normal", GameData.TUTORIAL_SUMMON_COUNT)
	for case in [["equipe", false, "armes"], ["equipe", true, "equipe"], ["etage", true, "etage"],
			["synthese", true, "synthese"]]:
		GameData.tutorial_step = case[0]
		GameData.teams = GameData._empty_teams()
		if case[1]:
			GameData.teams[0] = [GameData.roster[0]["id"]]
		GameData.save_game()
		var file := ConfigFile.new()
		file.load(GameData.SAVE_PATH)
		file.set_value("partie", "version", 6)
		file.save(GameData.SAVE_PATH)
		GameData.load_game()
		_check("ancienne sauvegarde à « %s »%s" % [case[0], ", équipe composée" if case[1] else ""],
			GameData.tutorial_step == case[2], "étape relue : " + GameData.tutorial_step)


func _play() -> void:
	await _start_main()
	# 1. Invocation x10.
	var seen := await _close_windows()
	_check("bienvenue et étape 1", "BIENVENUE, MAÎTRE" in seen and "TUTORIEL — ÉTAPE 1 / 5" in seen, str(seen))
	_check("bandeau étape 1", _main.tutorial_label.text.begins_with("Tutoriel 1/5"), _main.tutorial_label.text)
	var summon: Control = _main.screens["summon"]
	summon._on_summon("normal", GameData.TUTORIAL_SUMMON_COUNT)
	_check("10 héros invoqués", GameData.alive_heroes().size() == 10)
	_check("étape « armes »", GameData.tutorial_step == "armes", GameData.tutorial_step)
	await _seconds(5.0)
	await _capture("invocation")
	seen = await _close_windows(["TUTORIEL — ÉTAPE 2 / 5"])
	_check("fenêtre de l'étape 2", "TUTORIEL — ÉTAPE 2 / 5" in seen, str(seen))
	_check("le hub s'affiche", _main.screens["hub"].visible)
	_check("bandeau étape 2", _main.tutorial_label.text.begins_with("Tutoriel 2/5 : touche l'Armurerie"), _main.tutorial_label.text)
	_check("seul l'onglet Hub", not _main.nav_buttons["hub"].disabled and _main.nav_buttons["summon"].disabled
		and _main.nav_buttons["dungeons"].disabled and _main.nav_buttons["collection"].disabled)

	# Reprise au lancement : le jeu est fermé pendant l'étape.
	await _start_main()
	await _close_windows()
	_check("reprise : hub et bandeau", _main.screens["hub"].visible and _main.tutorial_label.text.begins_with("Tutoriel 2/5"))

	var hub: Control = _main.screens["hub"]
	var city: HubCity3D = hub.map
	await _seconds(1.5)
	_check("flèche « Touche ici » sur l'armurerie", city.tutorial_pointer != null and city.tutorial_pointer.visible)
	await _capture("hub_fleche_armurerie")
	# Un autre lieu ne s'ouvre pas.
	hub._on_zone_pressed({"name": "Faille spatio-temporelle", "target": "dungeons", "info": ""})
	await _frames(3)
	_check("autre lieu fermé", hub.visible and hub.info_label.text.begins_with("Tutoriel : touche l'Armurerie"), hub.info_label.text)
	# On touche l'armurerie dans la cité, comme un doigt.
	city._tap(city.camera.unproject_position(city._pos3("armory") + Vector3(0, 1, 0)))
	await _frames(5)
	var armory: Control = _main.screens["armory"]
	_check("l'armurerie s'ouvre", armory.visible)
	_check("tirage x1 fermé, x10 offert", armory.draw_buttons[1].disabled and not armory.draw_buttons[10].disabled
		and armory.draw_buttons[10].text.ends_with("Offert"), armory.draw_buttons[10].text)
	_check("forge fermée", armory.forge_button.disabled)
	await _capture("armurerie_offert")
	var gold_before := GameData.gold
	armory.draw_buttons[10].pressed.emit()
	await _frames(5)
	_check("tirage offert (or inchangé)", GameData.gold == gold_before, "%d → %d" % [gold_before, GameData.gold])
	var types := GameData.arsenal.map(func(weapon): return weapon["type"])
	_check("10 armes, épée, bouclier et arc", types.size() == 10 and "Épée" in types and "Bouclier" in types and "Arc" in types, str(types))
	_check("terrain d'entraînement ouvert", GameData.training_unlocked() and _main.has_node("Facility"))
	_check("étape « equipe »", GameData.tutorial_step == "equipe", GameData.tutorial_step)
	await _capture("tirage_terrain_debloque")
	seen = await _close_windows(["TUTORIEL — ÉTAPE 2 / 5", "TUTORIEL — ÉTAPE 3 / 5"])
	_check("fenêtres après le tirage", seen.size() >= 3 and seen[0] == "Facility" and "TUTORIEL — ÉTAPE 2 / 5" in seen
		and "TUTORIEL — ÉTAPE 3 / 5" in seen, str(seen))
	_check("seul l'onglet Donjons", not _main.nav_buttons["dungeons"].disabled and _main.nav_buttons["hub"].disabled)

	# 3. Composer l'équipe.
	_main.nav_buttons["dungeons"].pressed.emit()
	await _frames(3)
	var dungeons: Control = _main.screens["dungeons"]
	dungeons._open_teams()
	await _close_windows()
	for hero in dungeons._sorted_heroes().slice(0, GameData.TEAM_SIZE):
		dungeons._toggle_team_member(hero["id"])
		await _frames(2)
	await _capture("equipe")
	await _press(dungeons.teams_page, "Terminé")
	seen = await _close_windows()
	_check("étape « etage »", GameData.tutorial_step == "etage", GameData.tutorial_step)

	# 4. Étage 1, jusqu'à la victoire (une défaite : on recommence, comme le joueur).
	for attempt in 6:
		dungeons._open_tower(1)
		await _close_windows()
		await _seconds(2.0)
		dungeons._use_team(0)
		await _frames(3)
		dungeons._confirm_group()
		await _frames(3)
		await _press(dungeons, "Confirmer")
		var armed := []
		for hero in GameData.team_members(0):
			# (un mage ou un soigneur n'a pas d'arme : fighting_weapon renvoie {})
			armed.append("%s %s%s" % [hero["name"], GameData.fighting_weapon(hero).get("name", "magie"),
				"" if GameData.equipped(hero, "shield").is_empty() else " + " + GameData.weapon_name(GameData.equipped(hero, "shield"))])
		var from_arsenal := GameData.team_members(0).filter(func(hero): return not GameData.equipped(hero, "weapon").is_empty())
		var fighters := GameData.team_members(0).filter(func(hero): return not GameData.uses_magic(hero))
		_check("héros armés depuis l'arsenal (essai %d)" % (attempt + 1), from_arsenal.size() >= mini(3, fighters.size()), "; ".join(armed))
		# (prompt 3) placement des héros : le combat attend « Commencer »
		_check("placement avant le combat (essai %d)" % (attempt + 1), dungeons.battle_view.placing, "")
		await _press(dungeons.battle_view, "Commencer")
		Engine.time_scale = float(_args["vitesse"])
		await _seconds(1.0)  # (temps réel : environ 6 s de combat)
		Engine.time_scale = 1.0
		if attempt == 0:
			await _capture("combat")
		Engine.time_scale = float(_args["vitesse"])
		while not dungeons.battle_view.battle.finished:
			await _frames(10)
		Engine.time_scale = 1.0
		await _frames(10)
		var won: bool = dungeons.battle_view.battle.victory
		print("T1 combat essai %d : %s" % [attempt + 1, "victoire" if won else "défaite"])
		await _capture("fin_combat_%d" % (attempt + 1))
		await _press(dungeons.battle_view, "Continuer")
		await _close_windows()
		if won:
			break
	_check("étape « synthese »", GameData.tutorial_step == "synthese", GameData.tutorial_step)

	# 5. La chambre de synthèse se construit sous les yeux du Maître, puis une synthèse.
	await _seconds(20.0)
	seen = await _close_windows(["TUTORIEL — ÉTAPE 5 / 5"])
	_check("fenêtre de l'étape 5", "TUTORIEL — ÉTAPE 5 / 5" in seen, str(seen))
	await _seconds(1.0)
	await _capture("hub_synthese")
	city._tap(city.camera.unproject_position(city._pos3("synthese") + Vector3(0, 1, 0)))
	await _frames(5)
	var synthesis: Control = _main.screens["synthesis"]
	_check("la chambre de synthèse s'ouvre", synthesis.visible)
	var heroes := GameData.alive_heroes()
	heroes.sort_custom(func(a, b): return a["rarity"] > b["rarity"])
	synthesis._choose_target(heroes[0])
	synthesis._toggle_sacrifice(heroes[-1])
	synthesis._refresh()
	synthesis._confirm()
	await _frames(3)
	synthesis._do_synthesis()
	await _frames(3)
	await _capture("synthese")
	await _press(synthesis.overlay, "Compris")
	seen = await _close_windows(["TUTORIEL TERMINÉ"])
	_check("tutoriel terminé", GameData.tutorial_step == "" and "TUTORIEL TERMINÉ" in seen, str(seen))
	_check("tous les onglets ouverts", _main.nav_buttons.values().all(func(button): return not button.disabled))
