extends SceneTree
## Vérification de l'étape E (vigilance des monstres, exploration, infiltration, assassinat, pièges) en mode normal,
## sans écran. GameData démarre (il relit et réécrit la sauvegarde) : dans une COPIE du projet (override.cfg) :
##   Godot --headless --path <copie> -s res://tools/test_etapeE.gd

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
	seed(3)
	_check_dispositions()
	_check_assassination()
	_check_trap()
	_check_stealth()
	_check_exploration()
	_check_ties()
	print("")
	print("RÉSULTAT : %s" % ("tout est bon" if failures == 0 else "%d problème(s)" % failures))
	quit(1 if failures > 0 else 0)


func _team(level: int, classes := ["Guerrier", "Archer", "", "", ""]) -> Array:
	var team := []
	for i in classes.size():
		var hero: Dictionary = game.dev_create_hero(3 if i < 2 else 1, classes[i])
		while hero["level"] < level and not game.is_max_level(hero):
			game.gain_xp(hero, game.xp_to_next(hero["level"]) - hero["xp"])
		team.append(hero)
	return team


func _battle(floor_number: int, dispo: String, map_seed := 21, team := []):
	if team.is_empty():
		team = _team(game.floor_enemy_level(floor_number) + 2)
	var quest: Dictionary = game.floor_quest(floor_number)
	var layout: Dictionary = load("res://scripts/map_generator.gd").generate(floor_number, quest, map_seed)
	var battle = load("res://scripts/battle.gd").new(team, layout["enemies"], quest)
	battle.map_data = layout["map"]
	battle.forced_disposition = dispo
	battle.start()
	return battle


func _check_dispositions() -> void:
	print("Dispositions selon la mission")
	var script = load("res://scripts/battle_alert.gd")
	_check(script.disposition_for(game.floor_quest(1), 5) == "pillage", "étage 1 : pillage")
	_check(script.disposition_for(game.floor_quest(5), 5) == "horde", "survie : horde")
	_check(script.disposition_for(game.floor_quest(10), 5) == "horde", "défense : horde")
	var seen := {}
	for map_seed in 40:
		seen[script.disposition_for(game.floor_quest(3), map_seed)] = true
	_check(seen.size() == 4, "annihilation : quatre dispositions possibles (%s)" % ", ".join(seen.keys()))
	var camp = _battle(3, "camp")
	var states := {}
	for enemy in camp.enemies:
		if enemy["present"]:
			states[enemy["state"]] = states.get(enemy["state"], 0) + 1
	_check(states.get("guet", 0) >= 1 and states.get("repos", 0) >= 1, "camp : guetteurs et monstres au repos %s" % states)
	_check(camp.clock_start < 0.0, "camp : le compte à rebours attend le premier contact")
	var horde = _battle(5, "")
	_check(horde.alert.alarm and horde.enemies.all(func(e): return e["state"] == "alerte"), "survie : tous en alerte, comme avant")
	# L'embuscade : un embusqué ne se voit que de près.
	var ambush = _battle(2, "embuscade")
	# (sur la ligne de départ des héros, plate et dégagée : seul le fait d'être caché compte)
	var hidden: Dictionary = ambush.enemies.filter(func(e): return e["present"])[0]
	var hero: Dictionary = ambush.heroes[0]
	for other in ambush.heroes:
		other["pos"] = Vector2(1.5, 18.5) if other != hero else Vector2(4.5, 14.5)
	hero["facing"] = Vector2(1, 0)
	hero["acuity"] = 0  # (Acuité neutre)
	hero["glancer"] = false
	hidden["pos"] = Vector2(9.0, 14.5)
	ambush.perception.update()
	_check(not ambush.perception.knows(hero, hidden), "embusqué à 4,5 cases : pas vu")
	hidden["pos"] = Vector2(6.5, 14.5)
	ambush.perception.update()
	_check(ambush.perception.knows(hero, hidden), "embusqué à 2 cases : vu")


func _check_assassination() -> void:
	print("Assassinat")
	var battle = _battle(3, "endormis", 22, _team(5, ["Assassin", "Guerrier"]))
	var sleeper: Dictionary = battle.enemies.filter(func(e): return e["present"] and e["state"] == "sommeil")[0]
	var assassin: Dictionary = battle.heroes[0]
	assassin["pos"] = sleeper["pos"] + Vector2(0, 0.9)
	battle.perception.update()
	var before: int = battle.assassinations
	battle._hit(assassin, sleeper, 1.0, false, "hit")
	_check(sleeper["hp"] <= 0 and battle.assassinations == before + 1, "un dormeur égorgé par un Assassin meurt")
	var states: Array = battle.enemies.filter(func(e): return e["present"] and e["hp"] > 0).map(func(e): return e["state"])
	_check(states.all(func(s): return s == "sommeil"), "sans un bruit : les autres dorment encore %s" % [states])

	var awake: Dictionary = battle.enemies.filter(func(e): return e["present"] and e["hp"] > 0)[0]
	awake["state"] = "alerte"
	_check(battle._assassination(assassin, awake, "hit", true) == 1.0, "un monstre en alerte : pas d'assassinat")
	var guard = _battle(3, "camp", 23, _team(5, ["Guerrier", "Archer"]))
	var resting: Dictionary = guard.enemies.filter(func(e): return e["present"] and e["state"] == "repos")[0]
	var warrior: Dictionary = guard.heroes[0]
	warrior["pos"] = resting["pos"] - resting["facing"] * 0.9  # (dans son dos)
	guard.perception.update()
	var hp_before: int = resting["hp"]
	guard._hit(warrior, resting, 1.0, false, "hit")
	_check(hp_before - maxi(0, resting["hp"]) >= roundi(resting["max_hp"] * 0.5) or resting["hp"] <= 0, "un coup d'épée surprise retire au moins la moitié de sa vie")
	_check(resting["hp"] <= 0 or resting["state"] == "alerte", "blessé sans mourir, il passe en alerte")


func _check_trap() -> void:
	print("Pièges")
	var battle = _battle(3, "camp", 24)
	var monster: Dictionary = battle.enemies.filter(func(e): return e["present"] and not e["boss"])[0]
	var trapper: Dictionary = battle.heroes[1]
	var cell: Vector2i = battle.map.cell_of(monster["pos"])
	var hp_before: int = monster["hp"]
	battle.place_trap(trapper, cell)
	battle._check_traps()
	_check(battle.traps.is_empty() and battle.traps_sprung == 1, "le monstre sur la case déclenche le piège")
	_check(monster["hp"] < hp_before, "il perd de la vie (%d → %d)" % [hp_before, monster["hp"]])
	_check(monster["hp"] <= 0 or battle._move_speed(monster) == 0.0, "il est immobilisé")
	_check(battle.clock_start >= 0.0, "le piège est un contact : le compte à rebours démarre")


func _check_stealth() -> void:
	print("Discrétion")
	var battle = _battle(3, "camp", 25)
	battle.map.setup(battle.GRID_W, battle.GRID_H)  # (terrain plat : la case devant le guetteur peut être un arbre)
	battle.map.build_graph()
	var guard: Dictionary = battle.enemies.filter(func(e): return e["present"] and e["state"] == "guet")[0]
	var hero: Dictionary = battle.heroes[0]
	guard["facing"] = Vector2(0, 1)
	guard["home_facing"] = Vector2(0, 1)
	hero["pos"] = guard["pos"] + Vector2(0, 5.0)
	hero["stealth"] = 1.0
	battle.perception.update()
	var seen_open: bool = battle.perception.sees(guard, hero)
	hero["stealth"] = game.STEALTH_MIN
	battle.perception.update()
	var seen_sneaking: bool = battle.perception.sees(guard, hero)
	_check(seen_open and not seen_sneaking, "à 5 cases du guetteur : vu à découvert, pas en se faufilant")


func _check_exploration() -> void:
	print("Exploration et combat complet")
	var wins := 0
	var assassinations := 0
	var explored_at_end := 0
	for map_seed in 12:
		var battle = _battle(3, ["camp", "endormis", "poste", "patrouilles"][map_seed % 4], 30 + map_seed)
		while not battle.finished:
			battle.step()
		wins += 1 if battle.victory else 0
		assassinations += battle.assassinations
		if battle.events.any(func(e): return e["text"].begins_with("L'équipe part explorer")):
			explored_at_end += 1
	print("    victoires %d / 12, assassinats %d" % [wins, assassinations])
	_check(explored_at_end >= 8, "l'équipe part explorer (%d combats sur 12 ; sinon elle voit l'ennemi dès le départ)" % explored_at_end)
	_check(wins >= 6, "une équipe préparée gagne la plupart des combats (%d / 12)" % wins)


## Point 4 : protéger un ami, à revers (l'appât), abandonner un allié ; et ce que ça change aux liens.
func _check_ties() -> void:
	print("Liens et caractère")
	var battle = _battle(3, "camp", 26)
	var guardian: Dictionary = battle.heroes[0]
	var ward: Dictionary = battle.heroes[1]
	var monster: Dictionary = battle.enemies.filter(func(e): return e["present"])[0]
	battle.ties.traits[guardian["id"]]["guard"] = true
	guardian["bonds"][ward["id"]] = game.BOND_FRIEND
	ward["hp"] = int(ward["max_hp"] * 0.2)
	ward["pos"] = Vector2(9.5, 14.5)
	guardian["pos"] = Vector2(10.5, 14.5)
	monster["pos"] = Vector2(9.5, 13.5)
	_check(battle.ties.ward_of(guardian) == ward, "un ami en danger : il va le couvrir")
	var guard_hp: int = guardian["hp"]
	battle._damage(monster, ward, 1.0, false, "hit", true)
	_check(guardian["hp"] < guard_hp and battle.ties.counts["couvert"] == 1, "il prend une part du coup à sa place")
	# À revers : le monstre s'acharne sur l'allié, un autre héros frappe de l'autre côté.
	var flanker: Dictionary = battle.heroes[2]
	monster["target_id"] = ward["id"]
	flanker["pos"] = monster["pos"] + (monster["pos"] - ward["pos"]).normalized()
	_check(battle.ties.rear_factor(flanker, monster) == game.REAR_ATTACK_BONUS, "frapper à revers : plus fort")
	flanker["pos"] = ward["pos"] + Vector2(0.5, 0)
	_check(battle.ties.rear_factor(flanker, monster) == 1.0, "du même côté que l'allié : pas de bonus")
	# Abandon : un égoïste lâche en danger pousse l'allié vers le monstre et se replie.
	var coward: Dictionary = battle.heroes[3]
	var victim: Dictionary = battle.heroes[4]
	battle.ties.traits[coward["id"]]["abandoner"] = true
	coward["hp"] = int(coward["max_hp"] * 0.2)
	coward["pos"] = Vector2(5.5, 14.5)
	victim["pos"] = Vector2(6.5, 14.5)
	monster["pos"] = Vector2(5.5, 13.5)
	var mental_before: float = victim["mental"]
	_check(battle.ties.abandon(coward, [monster]), "il abandonne son allié")
	_check(victim["mental"] < mental_before and monster["target_id"] == victim["id"], "l'allié perd de la santé mentale, le monstre s'en prend à lui")
	_check(not battle.ties.abandon(coward, [monster]) or coward["abandon_until"] > battle.time, "une seule fois (puis il se replie)")
	var news: Array = game.ties_after_battle(battle)
	print("    ", " / ".join(news))
	_check(game.bond_level(victim["source"], coward["source"]) == game.BOND_HOSTILE, "après le combat : ils sont hostiles")
	_check(game.bond_points(guardian["source"], ward["source"]) >= game.BOND_POINTS_COVERED, "et le lien de l'ami qui a couvert se renforce")


func _check(ok: bool, text: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "ÉCHEC", text])
	if not ok:
		failures += 1
