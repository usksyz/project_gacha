extends SceneTree
## Mesure (étape B) : combien de fois l'équipe du tutoriel gagne l'étage 1, en rejouant le vrai déroulé (partie neuve,
## invocation normale x10 du tutoriel, tirage d'armes x10 offert, équipe des 5 meilleurs, armes prises à l'arsenal,
## étage 1 figé, combat sans ordres). Il RECOMMENCE la partie : dans une COPIE du projet (override.cfg) :
##   Godot --headless --path <copie> -s res://tools/sim_tutoriel.gd -- parties=200 graine=1

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
	var args := {"parties": "200", "graine": "1"}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=")
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	seed(int(args["graine"]))
	var games := int(args["parties"])
	var wins := 0
	var deaths := 0
	for i in games:
		game.reset_game()
		game.summon("normal", game.TUTORIAL_SUMMON_COUNT)
		game.draw_weapons(game.TUTORIAL_WEAPON_COUNT)
		var team: Array = game.alive_heroes()
		team.sort_custom(func(a, b): return a["rarity"] > b["rarity"])
		team = team.slice(0, game.TEAM_SIZE)
		game.teams[0] = team.map(func(h): return h["id"])
		game.tutorial_step = "etage"
		var layout: Dictionary = game.floor_layout(1)
		var enemies: Array = layout["enemies"].duplicate(true)
		game.start_tower_battle(team, enemies, game.floor_quest(1), 1, layout["map"])
		var battle = load("res://scripts/battle.gd").new(team, enemies, game.floor_quest(1))
		battle.map_data = layout["map"]
		battle.potions = game.mission_potions()
		battle.run()
		var report: Dictionary = game.finish_tower_battle(battle)
		wins += 1 if battle.victory else 0
		deaths += report["dead"].size()
	var rate := wins / float(games)
	print("RESULTAT tutoriel étage 1 : %d parties, victoires %.1f %%, morts %.2f par combat, 6 défaites de suite : %.2f %%" % [
		games, rate * 100.0, deaths / float(games), pow(1.0 - rate, 6) * 100.0])
	quit()
