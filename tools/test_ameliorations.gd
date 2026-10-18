extends SceneTree
## Vérification des améliorations d'octobre 2026 (analyse du projet, ajouts du projet) en mode normal, sur une
## partie neuve : missions du jour et gemmes d'expédition, reconversion (instructeur, administrateur), cohésion de
## l'équipe en combat, compétences de l'œuvre (Mouvement secret, Trouver les faiblesses, Sauvagerie), phase 1.3
## (chef et nom d'équipe, suggestion de formation, volontaire, écart de niveau), arrivée déboussolée et motivation.
## Il RECOMMENCE la partie : le lancer dans une COPIE du projet (worktree + override.cfg, voir CLAUDE.md) :
##   Godot --headless --path <copie> -s res://tools/test_ameliorations.gd

var failures := 0
var started := false
var game: Node
var notices := []


func _process(_delta: float) -> bool:
	if started:
		return false
	started = true
	_run.call_deferred()
	return false


func _run() -> void:
	game = root.get_node("GameData")
	root.get_node("Settings").dev_mode = false
	game.system_notice.connect(func(title, lines): notices.append([title, lines]))
	seed(5)
	game.reset_game()
	_check_daily_missions()
	_check_expedition_gems()
	_check_reconversion()
	_check_cohesion()
	_check_work_skills()
	_check_team_leaders()
	_check_arrival()
	await process_frame  # (les fenêtres du Système partent en différé)
	_check(notices.any(func(n): return n[0] == "Mission du jour"), "une fenêtre du Système annonce les missions du jour")
	print("")
	print("RÉSULTAT : %s" % ("tout est bon" if failures == 0 else "%d problème(s)" % failures))
	quit(1 if failures > 0 else 0)


func _check_daily_missions() -> void:
	print("Missions du jour")
	var gems: int = game.gems
	game.complete_daily_mission("combat")
	_check(game.gems == gems and game.daily_missions["done"].is_empty(), "rien pendant le tutoriel")
	game.tutorial_step = ""
	game.complete_daily_mission("combat")
	_check(game.gems == gems + 60, "combat : 60 gemmes (%d)" % (game.gems - gems))
	game.complete_daily_mission("combat")
	_check(game.gems == gems + 60, "une seule fois par jour")
	game.complete_daily_mission("invocation")
	game.complete_daily_mission("entrainement")
	_check(game.gems == gems + 60 * 3 + game.DAILY_MISSIONS_BONUS, "les trois et le bonus : %d gemmes" % (game.gems - gems))
	_check(game.daily_mission_list().all(func(m): return m["done"]), "liste : toutes faites")
	game.save_game()
	game.daily_missions = {"day": "", "done": []}
	game.load_game()
	_check(game.daily_missions["done"].size() == 3, "relues dans la sauvegarde")
	game.daily_missions["day"] = "2000-01-01"
	_check(game.daily_mission_list().all(func(m): return not m["done"]), "un autre jour : à refaire")
	# Ancienne sauvegarde sans la clé : missions à faire.
	game.save_game()
	var file := ConfigFile.new()
	file.load(game.SAVE_PATH)
	file.erase_section_key("partie", "missions_du_jour")
	file.save(game.SAVE_PATH)
	game.load_game()
	_check(game.daily_missions == {"day": "", "done": []}, "ancienne sauvegarde : missions à faire")
	# Branchements : tirage d'armes, invocation, entraînement.
	game.dev_reset_daily_missions()
	game.real_gold = game.WEAPON_DRAW_COST
	game.draw_weapons(1)
	_check("invocation" in game.daily_missions["done"], "tirer une arme compte")
	game.dev_reset_daily_missions()
	game.real_gold = game.SUMMON_TYPES["normal"]["cost"]
	game.summon("normal", 1)
	_check("invocation" in game.daily_missions["done"], "invoquer compte")


func _check_expedition_gems() -> void:
	print("Gemmes d'expédition")
	var gems: int = game.gems
	var report: Dictionary = game._finish_expedition({"team": [], "team_index": 0, "dungeon": "mine", "log": []})
	_check(game.gems == gems + game.EXPEDITION_GEMS, "+%d gemmes au retour" % game.EXPEDITION_GEMS)
	_check(report["lines"].any(func(line): return "Gemmes" in line), "le rapport le dit")


func _check_reconversion() -> void:
	print("Reconversion")
	game.weapon_draws = 0
	var teacher: Dictionary = game.dev_create_hero(1, "")
	var pupil: Dictionary = game.dev_create_hero(1, "")
	_check(not game.post_open("instructeur") and not game.set_post(teacher, "instructeur"),
		"instructeur fermé tant que le terrain d'entraînement ne l'est pas")
	game.weapon_draws = game.TRAINING_UNLOCK_DRAWS
	_check(game.post_open("instructeur") and game.post_open("administrateur"), "postes ouverts")
	var placed: bool = game.set_post(teacher, "instructeur")
	_check(placed or game.last_refusal != "", "affecté (ou refus de caractère : %s)" % game.last_refusal)
	if not placed:
		teacher["post"] = "instructeur"  # (un Paresseux refuse : on le force pour la suite)
	_check(game.activity_text(teacher).begins_with("Instructeur"), "activité : %s" % game.activity_text(teacher))
	var program := "Maîtrise de l'épée"
	_check(is_equal_approx(game.instructor_factor(pupil, program), 1.0 + game.INSTRUCTOR_BONUS), "instructeur : +15 %")
	teacher["skills"].append({"name": program, "rank": "Débutant", "level": 3})
	_check(is_equal_approx(game.instructor_factor(pupil, program), 1.0 + game.INSTRUCTOR_BONUS + game.INSTRUCTOR_MASTER_BONUS),
		"il maîtrise mieux l'épée que l'élève : +30 %")
	var admin: Dictionary = game.dev_create_hero(3, "")
	admin["stats"]["int"] = 10
	admin["post"] = "administrateur"
	_check(is_equal_approx(game.admin_gold_factor(), 1.1), "administrateur (Intelligence 10) : +10 %% d'or (%.2f)" % game.admin_gold_factor())
	_check(game.post_slots("administrateur") == 1 and not game.set_post(pupil, "administrateur"), "un seul administrateur")
	game.set_post(teacher, "")
	admin["post"] = ""
	_check(game.instructor_factor(pupil, program) == 1.0 and game.admin_gold_factor() == 1.0, "libérés : plus d'effet")


## Cohésion en combat : un héros libre, loin d'un allié qui se bat seul, va l'aider ; un héros égaré rejoint l'équipe ;
## un héros à l'agonie est secouru de plus loin qu'avant (AGONY_HELP_RANGE).
func _check_cohesion() -> void:
	print("Cohésion de l'équipe")
	_check(game.AGONY_HELP_RANGE > 8.0, "secours de plus loin (%.0f cases)" % game.AGONY_HELP_RANGE)
	var heroes := []
	for i in 3:
		var hero: Dictionary = game.dev_create_hero(2, "Guerrier")
		heroes.append(hero)
	var foe: Dictionary = game._create_enemy(game.ENEMY_TYPES[0], 3)
	var battle = load("res://scripts/battle.gd").new(heroes, [foe], game.floor_quest(1))
	battle.start()
	var a: Dictionary = battle.heroes[0]
	var b: Dictionary = battle.heroes[1]
	var c: Dictionary = battle.heroes[2]
	var monster: Dictionary = battle.enemies[0]
	for hero in battle.heroes:
		battle.explore.roles[hero["id"]] = "suit"
	a["pos"] = Vector2(3.5, 5.5)
	monster["pos"] = Vector2(4.5, 5.5)
	b["pos"] = Vector2(12.5, 12.5)
	c["pos"] = Vector2(12.5, 13.5)
	var known := [monster]
	var allies: Array = battle._alive(battle.heroes)
	var lonely: Dictionary = battle.tactics._lonely_fight(b, known, allies)
	_check(not lonely.is_empty() and lonely["ally"]["id"] == a["id"], "un allié seul au contact, à %.0f cases : on va l'aider"
		% a["pos"].distance_to(b["pos"]))
	c["pos"] = Vector2(4.5, 6.5)
	var helped: Dictionary = battle.tactics._lonely_fight(b, known, allies)
	_check(not helped.is_empty() and not helped["alone"], "il n'est plus seul : on va quand même l'aider (moins pressé)")
	battle.explore.roles[b["id"]] = "solitaire"
	c["pos"] = Vector2(12.5, 13.5)
	_check(battle.tactics._lonely_fight(b, known, allies).is_empty(), "un solitaire n'y va pas")
	battle.explore.roles[b["id"]] = "suit"
	b["pos"] = Vector2(14.5, 2.5)
	c["pos"] = Vector2(4.5, 13.5)
	_check(battle.tactics._strayed(b, allies), "à plus de %.0f cases de tous : il rejoint l'équipe" % game.COHESION_LEASH)
	b["pos"] = Vector2(5.5, 7.5)
	_check(not battle.tactics._strayed(b, allies), "près d'un allié : il reste")


## Compétences de l'œuvre : effets en combat, enseignement par un instructeur, Jenna, Han qui perd Mouvement secret.
func _check_work_skills() -> void:
	print("Compétences de l'œuvre")
	var heroes := []
	for i in 3:
		heroes.append(game.dev_create_hero(2, "Guerrier"))
	heroes[0]["skills"].append(game.new_skill("Mouvement secret"))
	heroes[1]["skills"].append(game.new_skill("Trouver les faiblesses"))
	heroes[2]["skills"].append(game.new_skill("Sauvagerie"))
	var foe: Dictionary = game._create_enemy(game.ENEMY_TYPES[0], 3)
	var battle = load("res://scripts/battle.gd").new(heroes, [foe], game.floor_quest(1))
	battle.start()
	var mover: Dictionary = battle.heroes[0]
	var seer: Dictionary = battle.heroes[1]
	var savage: Dictionary = battle.heroes[2]
	var monster: Dictionary = battle.enemies[0]
	# Trouver les faiblesses
	_check(battle._weakness_crit(seer, monster) == 0.0, "faiblesses : rien avant d'avoir frappé")
	seer["studied"][monster["id"]] = game.WEAKNESS_HITS
	_check(is_equal_approx(battle._weakness_crit(seer, monster), game.WEAKNESS_CRIT), "après 2 coups : +15 % de critiques")
	mover["studied"][monster["id"]] = 5
	_check(battle._weakness_crit(mover, monster) == 0.0, "sans la compétence : rien")
	# Sauvagerie
	savage["hp"] = savage["max_hp"]
	_check(battle._savagery(savage) == 0.0, "sauvagerie : rien en pleine forme")
	savage["hp"] = roundi(savage["max_hp"] * 0.25)
	_check(absf(battle._savagery(savage) - game.SAVAGERY_MAX * 0.5) < 0.02, "au quart de sa vie : +%d %%" % roundi(battle._savagery(savage) * 100))
	savage["bleed"]["ticks"] = 3
	_check(absf(battle._savagery(savage) - game.SAVAGERY_MAX * 0.5 - game.SAVAGERY_BLEED) < 0.02, "et s'il saigne : +10 % de plus")
	# Mouvement secret
	var hurt: Dictionary = savage
	hurt["pos"] = Vector2(6.5, 6.5)
	monster["pos"] = Vector2(7.5, 6.5)
	mover["pos"] = Vector2(5.5, 7.5)
	seer["pos"] = Vector2(14.5, 14.5)
	hurt["hp"] = roundi(hurt["max_hp"] * 0.2)
	battle._secret_move_think(mover)
	_check(mover["secret_move_until"] > battle.time, "Mouvement secret : il attire les ennemis pour couvrir un allié en danger")
	_check(battle._choose_target(monster, battle._alive(battle.heroes), [monster])["id"] == mover["id"], "le monstre le vise")
	var until: float = mover["secret_move_until"]
	battle._secret_move_think(mover)
	_check(mover["secret_move_until"] == until and mover["secret_move_ready"] > battle.time, "pas deux fois de suite (20 s)")
	# Enseignement par un instructeur
	game.weapon_draws = game.TRAINING_UNLOCK_DRAWS
	var teacher: Dictionary = game.dev_create_hero(1, "")
	teacher["skills"].append(game.new_skill("Trouver les faiblesses"))
	teacher["post"] = "instructeur"
	var pupil: Dictionary = game.dev_create_hero(1, "")
	PersonalityEngine.set_tier(pupil, "ACU", 3)
	PersonalityEngine.set_tier(pupil, "EMP", -3)
	PersonalityEngine.set_tier(pupil, "LOY", -3)
	PersonalityEngine.set_tier(pupil, "SEN", -3)
	_check("Trouver les faiblesses" in game.teachable_from_instructors(pupil), "un instructeur peut enseigner Trouver les faiblesses")
	PersonalityEngine.set_tier(pupil, "ACU", 0)
	PersonalityEngine.set_tier(pupil, "FOI", 0)
	_check(not "Trouver les faiblesses" in game.teachable_from_instructors(pupil), "pas à un élève sans l'affinité")
	teacher["post"] = ""
	# Jenna et Han
	_check(game.SECRET_HEROES["Jenna"]["skills"].any(func(s): return s["name"] == "Trouver les faiblesses"), "Jenna arrive avec Trouver les faiblesses")
	_check("Mouvement secret" in game.CLASS_LOST_SKILLS["Guerrier"], "un Guerrier perd Mouvement secret (comme Han)")
	_check(game.SKILLS.has("Mouvement secret") and game.SKILLS.has("Trouver les faiblesses") and game.SKILLS.has("Sauvagerie"),
		"les trois compétences ont leur description")


## Phase 1.3 : chef et nom d'équipe, suggestion de formation, volontaire accepté, écart de niveau.
func _check_team_leaders() -> void:
	print("Équipes : chefs, formations, volontaires")
	for team in game.teams:
		team.clear()
	game.pending_requests.clear()
	var heroes := []
	for i in 3:
		heroes.append(game.dev_create_hero(2, "Guerrier"))
	game.set_team(0, [heroes[0]["id"], heroes[1]["id"]])
	_check(game.team_name(0) == "Équipe 1", "nom par défaut : %s" % game.team_name(0))
	game.rename_team(0, "  Les Loups  ")
	_check(game.team_name(0) == "Les Loups", "renommée : « %s »" % game.team_name(0))
	_check(game.set_team_leader(0, heroes[2]["id"]) == "", "le chef doit être dans l'équipe")
	var notice: String = game.set_team_leader(0, heroes[0]["id"])
	_check(notice == "%s a été sélectionné comme chef d'équipe." % heroes[0]["name"], "fenêtre : %s" % notice)
	game.save_game()
	game.team_info = game._empty_team_info()
	game.load_game()
	_check(game.team_name(0) == "Les Loups" and game.team_leader(0).get("id", -1) == heroes[0]["id"], "relus dans la sauvegarde")
	heroes = heroes.map(func(h): return game.hero_by_id(h["id"]))  # (la sauvegarde relue a recréé les fiches)
	var battle = load("res://scripts/battle.gd").new([heroes[0], heroes[1]], [game._create_enemy(game.ENEMY_TYPES[0], 3)],
		game.floor_quest(1))
	battle.start()
	battle.step()
	_check(battle.team_index == 0 and battle.team_leader_id == battle.heroes[0]["id"], "en combat, l'équipe et son chef sont reconnus")
	_check(battle.explore.leader_id == battle.heroes[0]["id"], "le chef mène l'exploration")
	game.set_team(0, [heroes[1]["id"]])
	_check(game.team_leader(0).is_empty(), "sorti de l'équipe : plus chef")
	# Suggestion de formation : pas avant FORMATION_MIN_FIGHTS combats.
	game.set_team(0, [heroes[0]["id"], heroes[1]["id"]])
	game.set_team_leader(0, heroes[0]["id"])
	_check(game._formation_request().is_empty(), "un chef sans expérience ne suggère rien")
	heroes[0]["fights"] = game.FORMATION_MIN_FIGHTS
	var formation: Array = game._formation_request()
	_check(not formation.is_empty() and formation[1]["hero"] == heroes[0]["id"] and formation[1]["team"] == 0
		and formation[1]["ids"][0] == heroes[0]["id"] and formation[1]["ids"].size() == game.TEAM_SIZE,
		"un chef expérimenté suggère une équipe complète pour son équipe, lui en tête")
	game.pending_requests.append(formation[1])
	var request: Dictionary = game.next_request()
	_check(request.get("text", "").begins_with("Le héros %s vous suggère une formation !" % heroes[0]["name"])
		and request.get("members", []).size() == formation[1]["ids"].size(), "carte : %s" % request.get("text", ""))
	var trust: float = PersonalityEngine.trust(heroes[0])
	game.answer_request(request, true)
	_check(game.teams[0].size() == formation[1]["ids"].size() and PersonalityEngine.trust(heroes[0]) > trust,
		"acceptée : l'équipe change, la confiance monte")
	game.pending_requests.append(formation[1])
	trust = PersonalityEngine.trust(heroes[0])
	game.answer_request(game.next_request(), false)
	_check(PersonalityEngine.trust(heroes[0]) < trust and trust - PersonalityEngine.trust(heroes[0]) < game.REQUEST_TRUST,
		"refusée : la confiance baisse un peu")
	# Volontaire accepté : bonus de combat dans cette équipe.
	var volunteer: Dictionary = game.dev_create_hero(2, "Guerrier")
	game.set_team(1, [])
	game.pending_requests = [{"kind": "join", "hero": volunteer["id"], "team": 1, "reason": "test"}]
	game.answer_request(game.next_request(), true)
	_check(volunteer.get("volunteer_team", -1) == 1, "volontaire accepté dans l'équipe 2")
	battle = load("res://scripts/battle.gd").new([volunteer], [game._create_enemy(game.ENEMY_TYPES[0], 3)], game.floor_quest(1))
	battle.start()
	_check(battle.heroes[0]["volunteer"] and is_equal_approx(battle._formation_attack(battle.heroes[0]),
		1.0 + game.VOLUNTEER_BONUS), "il se bat mieux avec elle (+5 %)")
	# Écart de niveau : le plus faible est stressé.
	heroes[1]["level"] = 1
	heroes[0]["level"] = 1 + game.LEVEL_GAP_STRESS
	battle = load("res://scripts/battle.gd").new([heroes[0], heroes[1]], [game._create_enemy(game.ENEMY_TYPES[0], 3)],
		game.floor_quest(1))
	var before: float = battle.heroes[1]["mental"]
	battle.start()
	_check(battle.heroes[1]["mental"] < before and battle.heroes[0]["mental"] == before,
		"écart de %d niveaux : le plus faible perd de la santé mentale (%.1f → %.1f)" % [game.LEVEL_GAP_STRESS, before,
			battle.heroes[1]["mental"]])


## Arrivée déboussolée (1-2 étoiles), motivation cachée.
func _check_arrival() -> void:
	print("Arrivée déboussolée, motivation cachée")
	var novice: Dictionary = game.dev_create_hero(1, "")
	var veteran: Dictionary = game.dev_create_hero(3, "")
	_check(game.is_disoriented(novice) and not game.is_disoriented(veteran), "un 1 étoile arrive déboussolé, pas un 3 étoiles")
	_check(novice["motivation"] in game.MOTIVATIONS and game.motivation_text(novice) == "?", "motivation tirée, cachée (« ? »)")
	game.weapon_draws = game.TRAINING_UNLOCK_DRAWS
	_check(not game.set_training(novice, "Maîtrise de l'épée") and game.last_refusal.contains("sortie"),
		"il refuse l'entraînement : %s" % game.last_refusal)
	_check(game.activity_text(novice).contains("déboussolé"), "activité : %s" % game.activity_text(novice))
	var battle = load("res://scripts/battle.gd").new([novice], [game._create_enemy(game.ENEMY_TYPES[0], 1)], game.floor_quest(1))
	battle.start()
	_check(battle.explore.roles.get(battle.heroes[0]["id"], "") == "prudent", "en combat, il reste en retrait")
	var lines: Array = game.end_disorientation(novice, " : il a survécu à un combat")
	_check(not game.is_disoriented(novice) and lines.size() == 2 and novice["motivation_known"]
		and game.motivation_text(novice) != "?", "survit à un combat : il en sort et parle de sa motivation (%s)" % " ".join(lines))
	var late: Dictionary = game.dev_create_hero(2, "")
	late["arrived_at"] = Time.get_unix_time_from_system() - game.DISORIENTED_HOURS_MAX * 3600.0
	game.update_arrivals()
	_check(not game.is_disoriented(late), "au bout de %.0f h au plus, il s'en remet seul (lui : %.0f h)" % [game.DISORIENTED_HOURS_MAX,
		game.disoriented_hours(late)])
	var witness: Dictionary = game.dev_create_hero(1, "")
	game.mental_after_synthesis(1)
	_check(not game.is_disoriented(witness), "voir une synthèse le décide à survivre")
	var aaron: Dictionary = game._create_secret_hero("Aaron")
	var han: Dictionary = game._create_secret_hero("Han")
	_check(game.is_disoriented(aaron) and not game.is_disoriented(han) and aaron["motivation"] == "famille",
		"Aaron arrive déboussolé (la famille), Han non")
	_check(is_equal_approx(game.motivation_factor(han), game.MOTIVATION_STRESS_FACTOR), "une motivation aide à tenir")
	# Ancienne sauvegarde : motivation tirée au chargement, pas d'arrivée déboussolée.
	novice.erase("motivation")
	novice.erase("arc")
	game.save_game()
	game.load_game()
	var reloaded: Dictionary = game.hero_by_id(novice["id"])
	_check(reloaded.has("motivation") and not game.is_disoriented(reloaded), "ancienne fiche : motivation tirée, pas déboussolé")
	game.roster.erase(aaron)
	game.roster.erase(han)


func _check(ok: bool, text: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "ÉCHEC", text])
	if not ok:
		failures += 1
