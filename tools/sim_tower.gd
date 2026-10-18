extends Node
## Simulateur de la Tour (mesures d'équilibre de CLAUDE.md), sans potions (sauf « potions=N »).
## Lancer (la scène charge GameData, donc la sauvegarde locale : en faire une copie avant, et la remettre
## après, car GameData peut la réécrire au lancement) :
##   Godot --headless --path . res://tools/sim_tower.tscn -- etages=1,2,3,4 combats=200 equipe=brute graine=1
## « equipe » : brute (équipe du tutoriel, 3★ + 2★ + 3 x 1★, au niveau des monstres de l'étage) ou preparee
## (2 niveaux de plus, épée et bouclier de grade D, arc D pour les archers).
## « niveau » : niveau imposé à toute l'équipe (sinon celui des monstres, +2 pour la préparée).
## « meneur » : libre (traits du tirage), avec (un héros de l'équipe est Meneur, les autres non) ou sans
## (aucun Meneur) : pour comparer à équipe égale ce que fait le Meneur.
## « maitre » : non (aucun ordre) ou oui (Maître simulé, simpliste : au début, chaque tireur monte sur la
## hauteur la plus proche à moins de MASTER_HEIGHT_RANGE cases s'il y en a ; pendant le combat, un héros au
## contact à moins de MASTER_TIRED de son endurance échange sa place, au plus toutes les MASTER_SWAP_COOLDOWN s).
## « potions » : potions de soin dans l'entrepôt (0 par défaut).
## « carte » : graine de carte imposée à tous les combats (sinon une carte par combat, tirée de la graine).
## « dispo » (étape E) : disposition des ennemis imposée (horde = comme avant l'étape E ; camp, endormis, poste,
## patrouilles, embuscade, pillage) ; sans, celle de l'étage. Victoires et durée affichées par disposition.
## Chaque lancement relit et réécrit user://sauvegarde.cfg : le lancer dans une copie du projet avec un
## override.cfg (dossier de sauvegarde à part), voir CLAUDE.md, section P1a-bis.
## Affiche, par étage : victoires (%), morts, peurs et ruptures par combat, temps de calcul moyen d'un combat (ms), unités
## bloquées (plus de BLOCK_SECONDS sans avancer alors qu'elles veulent avancer : « sans raison » si aucun
## combattant ne leur barre la route, « foule » sinon, « escalade » quand elles grimpent lentement), et les
## anciens traits présents dans les équipes.
## Marche aussi avec le code d'avant C1 (pas de MapGenerator : la carte est alors tirée par le combat).

const TRAIT_NAMES := ["Courageux", "Lâche", "Loyal", "Paresseux", "Querelleur", "Protecteur", "Ambitieux", "Mauvais", "Meneur"]
const MASTER_HEIGHT_RANGE := 7.0
const MASTER_TIRED := 0.25
const MASTER_SWAP_COOLDOWN := 4.0
## Une unité « bloquée » : elle veut avancer (elle cherche son chemin à chaque pas) pendant BLOCK_SECONDS
## sans s'éloigner de plus de BLOCK_DISTANCE cases de là où elle était.
const BLOCK_SECONDS := 2.0
## « cobaye » : la place du héros testé dans l'équipe (0 : 3 étoiles, 1 : 2 étoiles, 2 à 4 : 1 étoile).
const COBAYE_SLOT := 2
const BLOCK_DISTANCE := 0.3

var _args := {}
var _generator = null  # MapGenerator (code C1 et après), sinon null
## Numéro → dernier moment où il attendait derrière quelqu'un d'immobile (code C1 et après).
var _waited := {}
## « diag=oui » : pas passés dans chaque attitude de l'IA tactique (héros debout), tous combats d'un étage.
var _diag := {}


func _ready() -> void:
	var args := {"etages": "1,2,3,4,5", "combats": "200", "equipe": "brute", "graine": "1", "meneur": "libre", "meneur_toit": "",
		"maitre": "non", "potions": "0", "carte": "", "perception": "", "ia": "", "personnalite": "", "dispo": ""}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=")
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	_args = args
	if ResourceLoader.exists("res://scripts/map_generator.gd"):
		_generator = load("res://scripts/map_generator.gd")
	seed(int(args["graine"]))
	# « personnalite=non » (étape B) : les effets de P2 neutres (PersonalityEngine.effects_on), pour mesurer leur part.
	if args["personnalite"] == "non":
		PersonalityEngine.effects_on = false
	Settings.dev_mode = false  # (pas enregistré)
	GameData.roster.clear()    # lobby vide : le tirage diversifiant ne compare pas les héros à ceux de la sauvegarde
	var prepared: bool = args["equipe"] == "preparee"
	var master: bool = args["maitre"] == "oui"
	for floor_text in args["etages"].split(","):
		var floor_number := int(floor_text)
		var count := int(args["combats"])
		var wins := 0
		var deaths := 0
		var usec := 0
		var blocked := {"sans raison": 0, "foule": 0, "escalade": 0}
		var fears := 0     # héros qui ont eu peur (une fois par combat au plus)
		var ruptures := 0  # héros dont la santé mentale est tombée à 0 en combat
		var blocked_examples := []
		var trait_counts := {}
		var with_trait := {}  # {trait: [combats où l'équipe l'a, victoires]}
		var surprised := [0, 0]  # attaques surprises subies par les héros, par les ennemis (C3)
		var cobaye := [0, 0, 0.0]  # le héros testé : morts, mis à terre (agonie, mort), part de vie à la fin (total)
		var by_dispo := {}  # (étape E) {disposition: [combats, victoires, alarmes générales, durée totale]}
		var stealth := [0, 0, 0]  # (étape E, point 3) assassinats, pièges posés, pièges déclenchés
		var ties := {"couvert": 0, "appat": 0, "abandon": 0, "revers": 0}  # (étape E, point 4)
		for i in count:
			GameData.arsenal = []
			GameData.warehouse = {}
			if int(args["potions"]) > 0:
				GameData.warehouse[GameData.POTION] = {"F": int(args["potions"])}
			var team := _make_team(floor_number, prepared, args["meneur"])
			var present := {}
			for hero in team:
				for trait_name in TRAIT_NAMES:
					if GameData.has_trait(hero, trait_name):
						trait_counts[trait_name] = trait_counts.get(trait_name, 0) + 1
						present[trait_name] = true
			var quest := GameData.floor_quest(floor_number)
			var started := Time.get_ticks_usec()
			var battle: Battle
			if _generator != null:
				var map_seed := int(args["carte"]) if args["carte"] != "" else randi()
				if _generator.get_script_method_list().any(func(m): return m["name"] == "generate"):
					var layout: Dictionary = _generator.generate(floor_number, quest, map_seed)
					battle = Battle.new(team, layout["enemies"], quest)
					battle.set("map_data", layout["map"])
				else:
					battle = Battle.new(team, GameData.tower_enemies(floor_number), quest)
					battle.set("map_data", _generator.generate_map(floor_number, quest, map_seed))
			else:
				battle = Battle.new(team, GameData.tower_enemies(floor_number), quest)
			if args["meneur_toit"] != "":
				battle.set("leader_roof_shooters", args["meneur_toit"] == "oui")  # (essai du point 6 de C1)
			# C3 : « perception=non » (tout le monde sait tout, comme avant C3), « ia=fonce » (ancien comportement des
			# héros : tous foncent) ou « ia=tactique » (IA tactique, par défaut quand elle existe).
			if args["perception"] != "":
				battle.set("perception_on", args["perception"] != "non")
			if args["ia"] != "":
				battle.set("tactical_ai", args["ia"] != "fonce")
			# Étape E : « dispo=horde » (comme avant : les monstres savent où sont les héros), ou une disposition imposée
			# (camp, endormis, poste, patrouilles, embuscade, pillage) ; sans : celle de l'étage (tirée de la carte).
			if args["dispo"] != "":
				battle.set("forced_disposition", args["dispo"])
			var result := _play(battle, master, i)
			if battle.get("alert") != null:
				var dispo: String = battle.alert.disposition
				var entry: Array = by_dispo.get(dispo, [0, 0, 0, 0.0])
				entry[0] += 1
				entry[1] += 1 if battle.victory else 0
				entry[2] += 1 if battle.alert.alarm and dispo != "horde" else 0
				entry[3] += battle.duration
				by_dispo[dispo] = entry
			if battle.get("traps_placed") != null:
				stealth[0] += battle.assassinations
				stealth[1] += battle.traps_placed
				stealth[2] += battle.traps_sprung
			if battle.get("ties") != null:
				for kind in ties:
					ties[kind] += battle.ties.counts[kind]
			usec += Time.get_ticks_usec() - started
			for kind in blocked:
				blocked[kind] += result["blocked"][kind]
			if blocked_examples.size() < 5:
				blocked_examples.append_array(result["examples"].slice(0, 5 - blocked_examples.size()))
			if battle.victory:
				wins += 1
			for trait_name in present:
				var entry: Array = with_trait.get(trait_name, [0, 0])
				entry[0] += 1
				entry[1] += 1 if battle.victory else 0
				with_trait[trait_name] = entry
			deaths += battle.heroes.filter(func(f): return _is_dead(f)).size()
			fears += battle.heroes.filter(func(f): return f.get("scared", false)).size()
			ruptures += battle.heroes.filter(func(f): return f.get("ruptured", false)).size()
			for fighter in battle.heroes:
				if fighter["source"].get("cobaye", false):
					cobaye[0] += 1 if _is_dead(fighter) else 0
					cobaye[1] += 1 if fighter.get("agony", false) or fighter.get("stabilized", false) or _is_dead(fighter) else 0
					cobaye[2] += maxf(0.0, float(fighter["hp"]) / fighter["max_hp"])
			var counts = battle.get("surprises")
			if counts != null:
				surprised[0] += counts["heroes"]
				surprised[1] += counts["enemies"]
		var trait_parts := []
		for trait_name in TRAIT_NAMES:
			trait_parts.append("%s %.2f" % [trait_name, trait_counts.get(trait_name, 0) / float(count)])
		print("RESULTAT equipe=%s maitre=%s etage=%d combats=%d victoires=%.1f%% morts=%.2f peurs=%.2f ruptures=%.2f temps_ms=%.0f bloques_sans_raison=%d bloques_foule=%d bloques_escalade=%d traits_par_equipe: %s" \
			% [args["equipe"], args["maitre"], floor_number, count, 100.0 * wins / count, float(deaths) / count,
			float(fears) / count, float(ruptures) / count, usec / 1000.0 / count, blocked["sans raison"], blocked["foule"],
			blocked["escalade"], ", ".join(trait_parts)])
		print("  surprises par combat : subies par les héros %.1f, par les ennemis %.1f" % [surprised[0] / float(count), surprised[1] / float(count)])
		print("  par combat : assassinats %.2f, pièges posés %.2f, déclenchés %.2f" % [stealth[0] / float(count), stealth[1] / float(count),
			stealth[2] / float(count)])
		print("  liens par combat : ami couvert %.2f, appât %.2f, abandon %.2f, coups à revers %.2f" % [ties["couvert"] / float(count),
			ties["appat"] / float(count), ties["abandon"] / float(count), ties["revers"] / float(count)])
		for dispo in by_dispo:
			var entry: Array = by_dispo[dispo]
			print("  disposition %s : %d combats, victoires %.1f%%, alarme générale %.0f%%, durée moyenne %.0f s" % [dispo, entry[0],
				100.0 * entry[1] / entry[0], 100.0 * entry[2] / entry[0], entry[3] / entry[0]])
		if _args.get("cobaye", "") != "":
			print("  cobaye %s : mort %.1f %%, à terre %.1f %%, vie restante moyenne %.0f %%" % [_args["cobaye"],
				100.0 * cobaye[0] / count, 100.0 * cobaye[1] / count, 100.0 * cobaye[2] / count])
		if not _diag.is_empty():
			var total := 0
			for key in _diag:
				total += _diag[key]
			var parts := []
			for key in _diag:
				parts.append("%s %.0f%%" % [key, 100.0 * _diag[key] / total])
			print("  attitudes : ", ", ".join(parts))
			_diag.clear()
		for example in blocked_examples:
			print("  bloqué : ", example)
		# Victoires selon que l'équipe a le trait ou non (pour trouver ce qui pèse sur l'équilibre).
		var split_parts := []
		for trait_name in TRAIT_NAMES:
			var entry: Array = with_trait.get(trait_name, [0, 0])
			var without: int = count - entry[0]
			split_parts.append("%s avec %.0f%% (%d) sans %.0f%%" % [trait_name, 100.0 * entry[1] / maxf(1, entry[0]), entry[0],
				100.0 * (wins - entry[1]) / maxf(1, without)])
		print("  victoires selon le trait : ", ", ".join(split_parts))
	get_tree().quit()


## Joue le combat pas à pas (comme Battle.run), avec le Maître simulé s'il est demandé, et compte les
## unités bloquées. Renvoie {"blocked": {"sans raison", "foule", "escalade"}, "examples": [textes]}.
func _play(battle: Battle, master: bool, number := 0) -> Dictionary:
	battle.start()
	var steps := int(round(BLOCK_SECONDS / Battle.TICK))
	var history := {}   # numéro → [positions des derniers pas où il voulait avancer]
	var stuck := {}     # numéro → vrai pendant un blocage déjà compté
	var swapped := {}   # numéro → moment du dernier échange ordonné
	_waited.clear()
	var result := {"blocked": {"sans raison": 0, "foule": 0, "escalade": 0}, "examples": []}
	if master:
		_master_heights(battle)
	while not battle.finished:
		if master:
			_master_rotation(battle, swapped)
		var timers := {}
		for unit in battle.units:
			timers[unit["id"]] = unit["path_timer"]
		battle.step()
		_trace(battle, number)
		# « diag=oui » (C3) : part du temps de chaque attitude de l'IA tactique, pour les héros debout.
		if _args.get("diag", "") == "oui":
			for hero in battle.heroes:
				if hero["present"] and hero["hp"] > 0:
					var plan: Dictionary = hero.get("tactic", {})
					var attitude: String = plan.get("attitude", "aucune") if not plan.is_empty() else "aucune"
					if not hero["order"].is_empty():
						attitude = "ordre"
					_diag[attitude] = _diag.get(attitude, 0) + 1
		for unit in battle.units:
			var id: int = unit["id"]
			var wants: bool = unit["present"] and unit["hp"] > 0 and unit["path_timer"] != timers[id]
			if not wants:
				history.erase(id)
				stuck.erase(id)
				continue
			if unit.get("blocked", 0.0) > 0.0:
				_waited[id] = battle.time  # (quelqu'un d'immobile lui barre la route, voir Battle._blocked)
			var trail: Array = history.get(id, [])
			trail.append(unit["pos"])
			if trail.size() > steps:
				trail.pop_front()
			history[id] = trail
			var moved := 0.0
			for pos in trail:
				moved = maxf(moved, pos.distance_to(trail[0]))
			if trail.size() == steps and moved < BLOCK_DISTANCE:
				if not stuck.has(id):
					stuck[id] = true
					var crowded := _crowded(battle, unit)
					var kind := "foule" if crowded else ("escalade" if _climbing(battle, unit) else "sans raison")
					result["blocked"][kind] += 1
					if kind == "sans raison" and result["examples"].size() < 5:
						result["examples"].append("combat %d, %s à %s, t=%.1f s, chemin %s%s" % [number, unit["name"], unit["pos"], battle.time,
							Array(unit["path"]).slice(0, 3), _details(battle, unit)])
			elif moved >= BLOCK_DISTANCE:
				stuck.erase(id)
	return result


## Maître simulé, au début : chaque tireur monte sur la hauteur libre la plus proche (s'il y en a une assez près).
func _master_heights(battle: Battle) -> void:
	var cells: Array = battle.height_cells()
	var taken := {}
	for hero in battle.heroes:
		if not hero["ranged"]:
			continue
		var best = null
		for cell in cells:
			if taken.has(cell) or hero["pos"].distance_to(cell) > MASTER_HEIGHT_RANGE:
				continue
			if best == null or hero["pos"].distance_to(cell) < hero["pos"].distance_to(best):
				best = cell
		if best != null:
			taken[best] = true
			battle.order_move(hero, best)


## Maître simulé, pendant le combat : un héros fatigué au contact échange sa place.
func _master_rotation(battle: Battle, swapped: Dictionary) -> void:
	for hero in battle.heroes:
		if not battle.can_swap(hero) or battle.time - swapped.get(hero["id"], -100.0) < MASTER_SWAP_COOLDOWN:
			continue
		if hero["stamina"] > hero["max_stamina"] * MASTER_TIRED:
			continue
		var contact := battle.enemies.any(func(e): return e["present"] and e["hp"] > 0 \
			and e["pos"].distance_to(hero["pos"]) <= GameData.STAMINA_CONTACT_RANGE)
		if contact:
			swapped[hero["id"]] = battle.time
			battle.order_swap(hero)


## Mort pour de bon à la fin du combat (Battle._die note « killer » ; un immortel est seulement à terre).
func _is_dead(fighter: Dictionary) -> bool:
	return fighter.get("killer", "") != "" and not fighter["immortal"]


func _make_team(floor_number: int, prepared: bool, leader := "libre") -> Array:
	var team := []
	var level := GameData.floor_enemy_level(floor_number) + (2 if prepared else 0)
	if _args.get("niveau", "") != "":
		level = int(_args["niveau"])  # niveau imposé (les 1 étoile s'arrêtent au niveau 10)
	var leader_slot := randi() % 5  # « avec » : la place du Meneur dans l'équipe, au hasard
	for slot in 5:
		var rarity: int = [3, 2, 1, 1, 1][slot]
		var hero: Dictionary = GameData._create_hero(rarity)
		if leader != "libre":
			while GameData.has_trait(hero, "Meneur"):
				hero = GameData._create_hero(rarity)
			if leader == "avec" and slot == leader_slot:
				hero["persona"]["legacy_traits"].append("Meneur")
		while hero["level"] < level and not GameData.is_max_level(hero):
			GameData.gain_xp(hero, GameData.xp_to_next(hero["level"]) - hero["xp"])
		# « cobaye=malin|fonceur » (C3) : le héros de la place COBAYE_SLOT (un 1 étoile) devient intelligent et prudent
		# (Intelligence 22, Audace -60, Maîtrise de soi +60) ou peu intelligent et impulsif (8, +60, -60) ; le reste de
		# sa personnalité et de l'équipe ne change pas (mêmes tirages à graine égale).
		if slot == COBAYE_SLOT and _args.get("cobaye", "") in ["malin", "fonceur"]:
			var smart: bool = _args["cobaye"] == "malin"
			hero["stats"]["int"] = 22 if smart else 8
			PersonalityEngine.set_tier(hero, "AUD", -6 if smart else 6)
			PersonalityEngine.set_tier(hero, "MAI", 6 if smart else -6)
			hero["cobaye"] = true
		if prepared and not GameData.uses_magic(hero):
			if hero["class"] == "Archer":
				_give(hero, "Arc")
			else:
				_give(hero, "Épée")
				_give(hero, "Bouclier")
		team.append(hero)
	return team


func _give(hero: Dictionary, type: String) -> void:
	GameData.arsenal.append({"id": GameData.arsenal.size() + 1, "type": type, "grade": "D", "owner": hero["id"]})


## Il escalade (un muret, un rocher, une échelle) : il avance, mais lentement (code C1 et après seulement).
func _climbing(battle: Battle, unit: Dictionary) -> bool:
	var map = battle.get("map")
	if map == null or unit["path"].is_empty():
		return false
	var links: Dictionary = map.get_script().get_script_constant_map()["Link"]  # (BattleMap n'existe pas avant C1)
	var passage: int = map.step_link(map.cell_of(unit["pos"]), map.cell_of(unit["path"][0]))
	return passage == links["CLIMB"] or passage == links["LADDER"]


## Détails d'un blocage (code C1 et après) : sa case, la suivante, le passage, qui se tient autour.
func _details(battle: Battle, unit: Dictionary) -> String:
	var map = battle.get("map")
	if map == null:
		return ""
	var here: Vector2i = map.cell_of(unit["pos"])
	var next: Vector2i = map.cell_of(unit["path"][0]) if not unit["path"].is_empty() else here
	var around := []
	for other in battle.units:
		if other["id"] != unit["id"] and other["present"] and other["pos"].distance_to(unit["pos"]) < 2.5:
			around.append("%s %s hp %d%s" % [other["name"], map.cell_of(other["pos"]), other["hp"], " immobile" if other.get("still", false) else ""])
	return " ; case %s (h %d) → %s (h %d), passage %d, cible %d, bloqué %.1f, détour %s ; autour : %s" % [here, map.height_at(here),
		next, map.height_at(next), map.step_link(here, next), unit.get("target_id", -1), unit.get("blocked", 0.0),
		unit.get("detour_until", 0.0) > battle.time, around]


## Quelqu'un (debout) lui barre-t-il la route ? Tout près (moins de 1,6 case), ou dans la case suivante de son
## chemin (une ruelle d'une case où l'on fait la queue) ; ou il a attendu derrière quelqu'un pendant ces BLOCK_SECONDS
## secondes, ou fait un détour.
func _crowded(battle: Battle, unit: Dictionary) -> bool:
	if battle.time - _waited.get(unit["id"], -100.0) <= BLOCK_SECONDS or unit.get("detour_until", 0.0) > battle.time:
		return true
	var next: Vector2 = unit["path"][0] if not unit["path"].is_empty() else unit["pos"]
	return battle.units.any(func(other): return other["id"] != unit["id"] and other["present"] and other["hp"] > 0 \
		and (other["pos"].distance_to(unit["pos"]) < 1.6 or Vector2i(other["pos"].floor()) == Vector2i(next.floor())))


## « suivre=12:Gobelin_C de=15 a=20 » : à chaque pas du combat 12 entre 15 et 20 s, l'état de Gobelin C (pour
## comprendre un blocage).
func _trace(battle: Battle, number: int) -> void:
	var wanted: String = _args.get("suivre", "")
	if wanted == "" or not wanted.begins_with("%d:" % number):
		return
	if battle.time < float(_args.get("de", "0")) or battle.time > float(_args.get("a", "9999")):
		return
	# « suivre=12:* » : tous les héros, une fois par seconde (attitude de l'IA tactique, case visée, raisons).
	if wanted.split(":")[1] == "*":
		if absf(battle.time - roundf(battle.time)) > 0.05:
			return
		var foes := battle.enemies.filter(func(e): return e["present"] and e["hp"] > 0)
		print("t=%.0f ennemis %s" % [battle.time, foes.map(func(e): return "%s%s pv%d" % [e["name"], e["pos"].snapped(Vector2(0.1, 0.1)), e["hp"]])])
		for unit in battle.heroes:
			var plan: Dictionary = unit.get("tactic", {})
			print("   %s pv%d pos%s %s case%s cible%d sait%d voit%d %s" % [unit["name"], unit["hp"], unit["pos"].snapped(Vector2(0.1, 0.1)),
				plan.get("attitude", "-"), plan.get("cell", null), plan.get("target", -1), unit.get("knows", {}).size(), unit.get("sees", {}).size(),
				plan.get("reasons", []).map(func(r): return r["why"])])
		return
	for unit in battle.units:
		if unit["name"] == wanted.split(":")[1].replace("_", " "):
			print("t=%.1f pos=%s chemin=%s but=%s case_attaque=%d cible=%d ordre=%s bloqué=%.1f détour=%s pv=%d%s" % [battle.time,
				unit["pos"], Array(unit["path"]).slice(0, 2), unit.get("path_goal", ""), unit.get("slot", -1), unit.get("target_id", -1),
				unit["order"], unit.get("blocked", 0.0), unit.get("detour_until", 0.0) > battle.time, unit["hp"], _details(battle, unit)])
