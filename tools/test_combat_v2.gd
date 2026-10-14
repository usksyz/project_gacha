extends Node
## Banc de test du combat v2 (cahier, onglet « Combat v2 », étape C1) : la grille 3D (passages, chemins, ligne
## de vue), la verticalité (chutes, avantage de hauteur, pousser, couvert).
## Lancer (la scène charge GameData : dans une copie du projet avec un override.cfg, voir CLAUDE.md) :
##   Godot --headless --path . res://tools/test_combat_v2.tscn
## Affiche « ok » ou « ÉCHEC » pour chaque contrôle, puis le bilan.

const K := BattleMap.Kind
const L := BattleMap.Link

var problems := 0


func _ready() -> void:
	seed(5)
	Settings.dev_mode = false
	GameData.roster.clear()
	GameData.warehouse = {}
	_check_links()
	_check_paths()
	_check_sight()
	_check_verticality()
	_check_generator()
	print("BILAN : %s" % ("tout est bon" if problems == 0 else "%d problème(s)" % problems))
	get_tree().quit()


func _ok(cond: bool, text: String) -> void:
	print(("  ok   " if cond else "  ÉCHEC ") + text)
	if not cond:
		problems += 1


## Une petite carte de test : du sol, une maison (toit à 2 niveaux) avec une échelle, un muret, un escalier.
##   x : 0 1 2 3 4 5 6 7
##   y=2 : maison (toit, hauteur 2) de x=2 à x=4, lignes 2 et 3 ; échelle en (1, 2), hauteur 0
##   (5, 5) : muret (1) ; (6, 1) : escalier (1) menant à (7, 1) : rocher (2) ; (0, 6) : rocher (1)
func _test_map() -> BattleMap:
	var map := BattleMap.new(8, 8)
	map.fill(Rect2i(2, 2, 3, 2), K.ROOF, 2)
	map.fill(Rect2i(1, 2, 1, 1), K.LADDER, 0)
	map.fill(Rect2i(5, 5, 1, 1), K.LOW_WALL, 1)
	map.fill(Rect2i(6, 1, 1, 1), K.STAIRS, 1)
	map.fill(Rect2i(7, 1, 1, 1), K.ROCK, 2)
	map.fill(Rect2i(0, 6, 1, 1), K.ROCK, 1)
	map.build_graph()
	return map


func _check_links() -> void:
	print("Passages entre cases (section 2)")
	var map := _test_map()
	_ok(map.link(Vector2i(0, 0), Vector2i(1, 0)) == L.WALK, "même hauteur : marcher")
	_ok(map.link(Vector2i(0, 5), Vector2i(0, 6)) == L.CLIMB and map.link(Vector2i(0, 6), Vector2i(0, 5)) == L.DROP,
		"un niveau : escalade pour monter, saut sans risque pour descendre")
	_ok(map.link(Vector2i(2, 4), Vector2i(2, 3)) == L.NONE, "deux niveaux sans échelle : on ne monte pas")
	_ok(map.link(Vector2i(2, 3), Vector2i(2, 4)) == L.JUMP, "deux niveaux vers le bas : saut (dégâts légers)")
	_ok(map.link(Vector2i(1, 2), Vector2i(2, 2)) == L.LADDER and map.link(Vector2i(2, 2), Vector2i(1, 2)) == L.LADDER,
		"échelle : on monte et on descend deux niveaux")
	_ok(map.link(Vector2i(5, 1), Vector2i(6, 1)) == L.STAIRS and map.link(Vector2i(6, 1), Vector2i(7, 1)) == L.STAIRS,
		"escalier : un niveau à chaque marche")
	_ok(map.step_link(Vector2i(1, 1), Vector2i(2, 2)) == L.NONE, "pas de diagonale qui change de hauteur")


func _check_paths() -> void:
	print("Chemins sur la grille 3D (section 3)")
	var map := _test_map()
	var path := map.find_path(Vector2i(0, 0), Vector2i(3, 2))
	var cells := Array(path).map(func(p): return map.cell_of(p))
	_ok(not path.is_empty() and cells.back() == Vector2i(3, 2) and Vector2i(1, 2) in cells, "pour monter sur le toit, on passe par l'échelle")
	var down := map.find_path(Vector2i(3, 3), Vector2i(3, 6))
	_ok(not down.is_empty() and map.cell_of(down[down.size() - 1]) == Vector2i(3, 6), "du toit, on redescend (saut ou échelle)")
	_ok(map.connected(Vector2i(0, 0), Vector2i(7, 1)), "le rocher de 2 niveaux s'atteint par l'escalier")


func _check_sight() -> void:
	print("Ligne de vue en 3D (section 2)")
	var map := _test_map()
	var c := func(x, y): return BattleMap.center(Vector2i(x, y))
	_ok(not map.line_of_sight(c.call(3, 0), 0, c.call(3, 5), 0), "au sol, la maison cache ce qui est derrière")
	_ok(map.line_of_sight(c.call(2, 2), 2, c.call(4, 7), 0), "depuis le toit, on voit par-dessus")
	_ok(not map.line_of_sight(c.call(0, 5), 0, c.call(0, 7), 0), "au sol, un rocher d'un niveau cache")
	_ok(map.line_of_sight(c.call(5, 0), 0, c.call(5, 4), 0), "rien entre les deux : on se voit")


## Un combat de test sur la petite carte : un héros et un gobelin, placés à la main.
func _test_battle() -> Battle:
	var hero: Dictionary = GameData._create_hero(3)
	var goblin: Dictionary = GameData._create_enemy(GameData.ENEMY_TYPES[0], 3)
	var battle := Battle.new([hero], [goblin], GameData.floor_quest(1))
	battle.start()
	battle.map = _test_map()
	for unit in battle.units:
		unit["present"] = true
	return battle


func _put(battle: Battle, unit: Dictionary, cell: Vector2i) -> void:
	unit["pos"] = BattleMap.center(cell)
	battle._settle(unit)


func _check_verticality() -> void:
	print("Verticalité (section 2)")
	var battle := _test_battle()
	var hero: Dictionary = battle.heroes[0]
	var goblin: Dictionary = battle.enemies[0]
	# Chutes.
	_put(battle, hero, Vector2i(3, 3))
	var hp: int = hero["hp"]
	hero["pos"] = BattleMap.center(Vector2i(3, 4))
	battle._land()
	_ok(hp - hero["hp"] == roundi(hero["max_hp"] * GameData.fall_damage(2)) and hero["z"] == 0,
		"sauter de deux niveaux : %d dégâts (%d %%)" % [hp - hero["hp"], roundi(GameData.fall_damage(2) * 100)])
	_put(battle, hero, Vector2i(2, 2))
	hp = hero["hp"]
	hero["pos"] = BattleMap.center(Vector2i(1, 2))
	battle._land()
	_ok(hero["hp"] == hp, "descendre par l'échelle : aucun dégât")
	_ok(GameData.fall_damage(1) == 0.0 and GameData.fall_damage(3) > GameData.fall_damage(2) * 3, "un niveau : rien ; trois : blessure grave")
	# Avantage de hauteur : par niveau, +10 % de dégâts infligés et -10 % subis (plafond 3 niveaux).
	var ratio := func(attacker_z: int, target_z: int) -> float:
		var a := {"z": attacker_z}
		var b := {"z": target_z}
		var above := clampi(battle.height_of(a) - battle.height_of(b), -GameData.HEIGHT_MAX_LEVELS, GameData.HEIGHT_MAX_LEVELS)
		return (1.0 + above * GameData.HEIGHT_DAMAGE_PER_LEVEL) if above > 0 else (1.0 + above * GameData.HEIGHT_DEFENSE_PER_LEVEL)
	_ok(is_equal_approx(ratio.call(2, 0), 1.2) and is_equal_approx(ratio.call(0, 2), 0.8) and is_equal_approx(ratio.call(4, 0), 1.3),
		"hauteur : x1,2 deux niveaux au-dessus, x0,8 deux en dessous, plafond à 3 niveaux (x1,3)")
	_ok(_mean_damage(battle, hero, goblin, 2, 0) > _mean_damage(battle, hero, goblin, 0, 0) * 1.12,
		"dans le combat : frapper d'en haut fait plus mal")
	# Corps à corps entre deux niveaux, portée des tireurs.
	_put(battle, hero, Vector2i(2, 3))
	_put(battle, goblin, Vector2i(2, 4))
	_ok(not battle._in_reach(hero, goblin, Battle.MELEE_RANGE), "au corps à corps, on ne frappe pas deux niveaux plus bas")
	_put(battle, hero, Vector2i(3, 2))
	_put(battle, goblin, Vector2i(3, 7))
	_ok(battle._in_reach(hero, goblin, 3.5) and not battle._in_reach(goblin, hero, 3.5),
		"un tireur sur le toit porte plus loin (+1 case par niveau) que d'en bas")
	# Pousser du toit.
	var pushed := 0
	for i in 400:
		_put(battle, hero, Vector2i(3, 2))
		_put(battle, goblin, Vector2i(3, 3))
		goblin["hp"] = goblin["max_hp"]
		battle._push(hero, goblin, 999, true)
		if battle._cell_of(goblin["pos"]) == Vector2i(3, 4):
			pushed += 1
	_ok(absf(pushed / 400.0 - GameData.PUSH_CHANCE) < 0.07, "un coup puissant au bord du toit fait tomber (%d %% des coups)" % roundi(pushed / 4.0))
	_put(battle, goblin, Vector2i(6, 5))
	_put(battle, hero, Vector2i(6, 4))
	battle._push(hero, goblin, 999, true)
	_ok(battle._cell_of(goblin["pos"]) == Vector2i(6, 5), "sur le plat, un coup ne fait pas tomber")
	# Couvert.
	_put(battle, goblin, Vector2i(5, 6))
	_put(battle, hero, Vector2i(5, 0))
	_ok(battle._covered(goblin, hero), "derrière un muret, à couvert des tirs")
	hero["z"] = 1 + GameData.COVER_IGNORE_LEVELS  # (en haut d'une tour)
	_ok(not battle._covered(goblin, hero), "un tireur bien plus haut tire par-dessus le muret")


## Les gabarits (section 8 bis, « Tests ») : N cartes par gabarit (« cartes=N » en argument, 1 000 par
## défaut ; le cahier en demande 10 000), toutes jouables (vérifications de MapGenerator.check, sans passer
## à la carte plate de secours), même graine même carte, temps de fabrication. « voir=oui » dessine une
## carte de chaque gabarit en lettres.
func _check_generator() -> void:
	print("Cartes (section 8 bis)")
	var args := {"cartes": "1000", "voir": "non"}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=")
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	var count := int(args["cartes"])
	var cases := {"village": [1, GameData.floor_quest(1)], "prairie": [2, GameData.floor_quest(2)],
		"relief": [3, GameData.floor_quest(3)], "ville": [5, GameData.floor_quest(5)], "cite": [10, GameData.floor_quest(10)],
		"arene": [0, GameData.duel_quest()]}
	for template in cases:
		var floor_number: int = cases[template][0]
		var quest: Dictionary = cases[template][1]
		var fallback := 0
		var usec := 0
		var heights_seen := {}
		for i in count:
			var started := Time.get_ticks_usec()
			var data := MapGenerator.generate_map(floor_number, quest, i * 7919 + 13)
			usec += Time.get_ticks_usec() - started
			if data["template"] != template or MapGenerator.check(data) != "":
				fallback += 1
			for h in data["heights"]:
				heights_seen[h] = true
		_ok(fallback == 0, "%s : %d cartes jouables sur %d (%.2f ms par carte), hauteurs %s" % [template, count - fallback, count,
			usec / 1000.0 / count, heights_seen.keys()])
		var a := MapGenerator.generate_map(floor_number, quest, 42)
		var b := MapGenerator.generate_map(floor_number, quest, 42)
		_ok(var_to_str(a) == var_to_str(b), "%s : même graine, même carte" % template)
		if args["voir"] == "oui":
			print(draw(a))


## Une carte en lettres (pour la regarder dans la console) : chiffre = hauteur du sol ; # obstacle ; H échelle ;
## T toit ; ^ tour ; = rempart ; / escalier ou pente ; m muret ; " herbes hautes ; R rocher.
static func draw(data: Dictionary) -> String:
	var map := BattleMap.new()
	map.size = data["size"]
	map.heights = PackedInt32Array(data["heights"])
	map.kinds = PackedInt32Array(data["kinds"])
	var signs := {K.BLOCK: "#", K.LADDER: "H", K.ROOF: "T", K.TOWER: "^", K.RAMPART: "=", K.STAIRS: "/",
		K.LOW_WALL: "m", K.GRASS: "\"", K.ROCK: "R"}
	var lines := ["%s (graine %d)" % [data["template"], data.get("seed", 0)]]
	for y in map.size.y:
		var line := ""
		for x in map.size.x:
			var cell := Vector2i(x, y)
			var kind := map.kind_at(cell)
			line += (signs[kind] if signs.has(kind) else ".") + str(map.height_at(cell))
		lines.append(line)
	return "\n".join(lines)


## Dégâts moyens d'un coup du héros (à la hauteur « az ») sur le gobelin (à « tz »).
func _mean_damage(battle: Battle, hero: Dictionary, goblin: Dictionary, az: int, tz: int) -> float:
	var total := 0.0
	hero["z"] = az
	goblin["z"] = tz
	for i in 2000:
		goblin["hp"] = 99999
		total += maxi(0, battle._damage(hero, goblin, 1.0))
	return total / 2000.0
