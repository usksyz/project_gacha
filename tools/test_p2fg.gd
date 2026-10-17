extends SceneTree
## Banc de P2f (armes de prédilection) et P2g (compétences exclusives), en mode normal.
## GameData démarre (il relit et réécrit la sauvegarde) : le lancer dans une COPIE du projet (override.cfg) :
##   Godot --headless --path <copie> -s res://tools/test_p2fg.gd [-- combats=60]

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
	root.get_node("Settings").dev_mode = false
	seed(11)
	game.roster.clear()
	game.arsenal = []
	_check_preference(game)
	_check_exclusives(game)
	print("")
	print("RÉSULTAT : %s" % ("tout est bon" if failures == 0 else "%d problème(s)" % failures))
	quit(1 if failures > 0 else 0)


func _check_preference(game: Node) -> void:
	print("P2f : armes de prédilection")
	var hero: Dictionary = game._create_hero(1)  # Novice : épée, lance, dague, fouet
	var aptitudes: Dictionary = hero["persona"]["aptitudes"]
	for domain in ["epee", "lance", "dague", "fouet", "arc", "bouclier"]:
		aptitudes[domain] = 2
	_check(PersonalityEngine.favorite_weapon(hero, game.CLASS_WEAPONS["Novice"]) == "", "aptitudes égales : pas de prédilection")
	aptitudes["lance"] = 5
	_check(PersonalityEngine.favorite_weapon(hero, game.CLASS_WEAPONS["Novice"]) == "Lance", "aptitude 5 à la lance : la lance")
	aptitudes["dague"] = 5
	_check(PersonalityEngine.favorite_weapon(hero, game.CLASS_WEAPONS["Novice"]) == "", "égalité au sommet : aucune")
	aptitudes["dague"] = 2
	aptitudes["lance"] = 3
	_check(PersonalityEngine.favorite_weapon(hero, game.CLASS_WEAPONS["Novice"]) == "", "aptitude 3 : pas assez")
	aptitudes["lance"] = 4
	game.roster.append(hero)
	for mission in 3:
		game.arsenal = [
			{"id": 1, "type": "Épée", "grade": "D", "owner": 0},
			{"id": 2, "type": "Lance", "grade": "E", "owner": 0},
			{"id": 3, "type": "Lance", "grade": "D-", "owner": 0},  # un cran sous l'épée D
		]
		game.gear_up([hero])
		_check(game.fighting_weapon(hero)["type"] == "Lance", "mission %d : il prend la lance [D-] plutôt que l'épée [D]" % (mission + 1))
		_check((mission < 2) == (game.weapon_preference_text(hero) == ""), "remarquée au bout de 3 missions seulement")
	_check(game.weapon_preference_text(hero).ends_with("revient toujours à la lance."), "« %s »" % game.weapon_preference_text(hero))
	# Trop loin en grade : il prend la meilleure.
	game.arsenal = [
		{"id": 4, "type": "Épée", "grade": "C", "owner": 0},
		{"id": 5, "type": "Lance", "grade": "F", "owner": 0},
	]
	game.gear_up([hero])
	_check(game.fighting_weapon(hero)["type"] == "Épée", "une lance [F] contre une épée [C] : l'épée")
	# Sans prédilection : la meilleure, comme avant.
	var plain: Dictionary = game._create_hero(1)
	for domain in plain["persona"]["aptitudes"]:
		plain["persona"]["aptitudes"][domain] = 2
	game.roster.append(plain)
	game.arsenal = [
		{"id": 6, "type": "Épée", "grade": "D", "owner": 0},
		{"id": 7, "type": "Lance", "grade": "D-", "owner": 0},
	]
	game.gear_up([plain])
	_check(game.fighting_weapon(plain)["type"] == "Épée", "sans prédilection : la meilleure arme")
	game.arsenal = []


func _check_exclusives(game: Node) -> void:
	print("P2g : compétences exclusives")
	var hero: Dictionary = game._create_hero(3)
	for axis in ["ACU", "LOY", "EMP", "MAI"]:
		PersonalityEngine.set_tier(hero, axis, 0)
	PersonalityEngine.refresh_accesses(hero)
	_check(PersonalityEngine.exclusives_for_event(hero, "surprised").is_empty(), "sans accès : rien")
	_check(not PersonalityEngine.has_affinity(hero, "Sixième sens"), "Sixième sens : pas d'affinité à Acuité 0")
	PersonalityEngine.set_tier(hero, "ACU", 6)
	PersonalityEngine.set_tier(hero, "LOY", -6)
	PersonalityEngine.set_tier(hero, "EMP", 6)
	PersonalityEngine.set_tier(hero, "MAI", -6)
	PersonalityEngine.refresh_accesses(hero)
	var names: Array = PersonalityEngine.exclusives_for_event(hero, "surprised").map(func(e): return e["skill"])
	_check("Sixième sens" in names and "Vigilance" in names, "surpris : Sixième sens et Vigilance possibles")
	_check(PersonalityEngine.exclusives_for_event(hero, "rescue")[0]["skill"] == "Premiers soins", "secours : Premiers soins")
	_check(PersonalityEngine.exclusives_for_event(hero, "first_blood")[0]["skill"] == "Premier sang", "premier coup : Premier sang")
	# Effets.
	var skills := [{"name": "Vigilance", "rank": "Débutant", "level": 3}, {"name": "Premier sang", "rank": "Débutant", "level": 1}]
	_check(is_equal_approx(game.exclusive_effect(skills, "Vigilance"), 0.4), "Vigilance niv. 3 : 40 %")
	_check(is_equal_approx(game.exclusive_effect(skills, "Premier sang"), 0.25), "Premier sang niv. 1 : +25 %")
	_check(game.exclusive_effect(skills, "Premiers soins") == 0.0, "sans la compétence : 0")
	# En combat : des équipes dont chaque héros a les quatre accès, étage 3 ; les exclusives doivent s'éveiller.
	var combats := 40
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("combats="):
			combats = int(arg.get_slice("=", 1))
	var learned := {}
	var events := {}
	for i in combats:
		var team := []
		for rarity in [3, 2, 1, 1, 1]:
			var member: Dictionary = game._create_hero(rarity)
			while member["level"] < game.floor_enemy_level(3) and not game.is_max_level(member):
				game.gain_xp(member, game.xp_to_next(member["level"]) - member["xp"])
			PersonalityEngine.set_tier(member, "ACU", 6)
			PersonalityEngine.set_tier(member, "LOY", -6)
			PersonalityEngine.set_tier(member, "EMP", 6)
			PersonalityEngine.set_tier(member, "MAI", -6)
			PersonalityEngine.refresh_accesses(member)
			team.append(member)
		# (chargé ici : avec -s, ce script est compilé avant les autoloads, donc sans la classe Battle)
		var battle = load("res://scripts/battle.gd").new(team, game.tower_enemies(3), game.floor_quest(3))
		battle.run()
		for fighter in battle.heroes:
			for event in fighter["exclusive_events"]:
				events[event] = events.get(event, 0) + 1
			for skill in fighter["skills"]:
				if skill["name"] in ["Sixième sens", "Vigilance", "Premiers soins", "Premier sang"]:
					learned[skill["name"]] = learned.get(skill["name"], 0) + 1
	print("  %d combats : événements %s ; compétences éveillées %s" % [combats, events, learned])
	_check(events.get("surprised", 0) > 0 and events.get("first_blood", 0) > 0, "les événements arrivent en combat")
	_check(learned.size() >= 3, "au moins trois exclusives éveillées")


func _check(ok: bool, text: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "ÉCHEC", text])
	if not ok:
		failures += 1
