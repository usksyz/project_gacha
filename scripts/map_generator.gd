class_name MapGenerator
extends RefCounted
## Fabrique la carte d'un combat (cahier, onglet « Combat v2 », section 8 bis ; étape C1) : la carte est une
## DONNÉE, produite par generate_map(étage, quête, graine) : hauteurs et types des cases (BattleMap),
## structures à dessiner, zones de départ, sortie des ruelles, rempart, point haut. Même graine, même carte.
## En C1, les cartes sont faites à la main par des gabarits (lieux de l'œuvre, section 8 bis) ; en C6, le
## bruit de Perlin variera le relief à l'intérieur de ces lieux, sans rien changer au reste du combat.
## Gabarits :
## - village (étage 1, « les gobelins ont envahi le village ») : presque plat, ondulations douces, maisons
##   basses éparses (fermées), une grange (toit et échelle : le point haut), clôtures, puits, champs ;
## - prairie (étage 2) : collines douces, une butte (point haut), bosquets, rochers isolés, herbes hautes ;
## - relief (autres étages ordinaires ; ajout du projet en attendant les lieux des étages 3, 4, 6...) : une
##   butte, des rochers, des blocs, des ruines (murets et pans de mur) ;
## - ville (survie, « ville en ruine » de l'étage 5) : la rangée de maisons percée de ruelles d'une case ;
##   les maisons sont des toits (2 niveaux), quelques-uns accessibles par des échelles (côté héros, et une
##   côté ennemis : la horde peut monter), un clocher (4 niveaux, le point haut) ; débris côté ennemis ;
## - cite (défense) : un rempart à 2 niveaux (chemin de ronde, escaliers à l'intérieur, porte fermée), plat
##   devant, quelques barricades ;
## - arene (duel) : plat, quelques rochers.
## Après chaque carte, des vérifications (check) ; si elles échouent, on recommence avec la suite de la graine.

const K := BattleMap.Kind

## Version du format de la carte (pour les cartes enregistrées dans la sauvegarde).
const MAP_VERSION := 1

const WIDTH := 18
const LENGTH := 20
## Zones de départ : héros en bas (première ligne, et deuxième ligne pour les tireurs), ennemis en haut
## (lignes ENEMY_ROWS ; les renforts entrent par ENTRY_ROW).
const HERO_FRONT_ROW := 14
const HERO_BACK_ROW := 16
const ENEMY_ROWS := Vector2i(1, 3)
const ENTRY_ROW := 0
## Les décors des étages ordinaires se posent entre ces lignes (le milieu de la carte).
const MIDDLE_ROWS := Vector2i(5, 12)
## Terrain de survie : première ligne des maisons et profondeur (longueur des ruelles).
const ALLEY_ROW := 8
const ALLEY_LENGTH := 3
## Défense : ligne du chemin de ronde du rempart (hauteur 2) ; les héros au corps à corps sont devant.
const WALL_ROW := 17
const DEFENSE_FRONT_ROW := 15
## Nombre d'essais avant de prendre une carte plate.
const ATTEMPTS := 40


## Le gabarit d'un étage (voir l'en-tête).
static func template_for(floor_number: int, quest: Dictionary) -> String:
	if quest.get("duel", false):
		return "arene"
	match quest.get("type", ""):
		"defense":
			return "cite"
		"survival":
			return "ville"
	if floor_number == 1:
		return "village"
	if floor_number == 2:
		return "prairie"
	return "relief"


## La carte d'un combat : une donnée (Dictionary) que Battle reprend telle quelle (voir Battle.map_data) :
## {"version", "seed", "template", "size", "heights", "kinds", "structures": [{"kind", "rect", "height"}],
##  "hero_rows": [première ligne, ligne des tireurs], "enemy_rows", "entry_row", "alley_exits": [Vector2],
##  "alley_exit_row", "wall_row" (-1 : pas de rempart), "lookout": [cases hautes de repérage]}.
static func generate_map(floor_number: int, quest: Dictionary, map_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	var template := template_for(floor_number, quest)
	for attempt in ATTEMPTS:
		var data := _build(template, rng)
		if check(data) == "":
			data["seed"] = map_seed
			return data
	var flat := _build("arene", rng)
	flat["seed"] = map_seed
	return flat


## Vérifications obligatoires (cahier, section 8 bis) : renvoie "" si la carte est jouable, sinon la raison.
## - les zones de départ sont plates et assez grandes ;
## - on peut aller des héros aux ennemis, et des ennemis aux héros ;
## - aucune case où l'on se tient n'est hors d'atteinte des héros (pas de poche isolée) ; hors défense, aucune
##   n'est hors d'atteinte des ennemis (pas de position imprenable pour un seul camp) ;
## - il y a un point haut de repérage (2 niveaux ou plus) que les héros peuvent atteindre ;
## - survie : chaque ruelle mène des ennemis aux héros.
static func check(data: Dictionary) -> String:
	var map := BattleMap.new()
	map.size = data["size"]
	map.heights = PackedInt32Array(data["heights"])
	map.kinds = PackedInt32Array(data["kinds"])
	var hero_cells := []
	for row in data["hero_rows"]:
		var row_height := -1
		var free := 0
		for x in range(3, WIDTH - 3):
			var cell := Vector2i(x, row)
			if not map.walkable(cell):
				continue
			if row_height >= 0 and map.height_at(cell) != row_height:
				return "zone des héros pas plate (ligne %d)" % row
			row_height = map.height_at(cell)
			free += 1
			hero_cells.append(cell)
		if free < 8:
			return "zone des héros trop petite (ligne %d)" % row
	var enemy_cells := []
	for row in range(data["enemy_rows"].x, data["enemy_rows"].y + 1):
		var free := 0
		for x in WIDTH:
			if map.walkable(Vector2i(x, row)) and map.height_at(Vector2i(x, row)) == 0:
				free += 1
				enemy_cells.append(Vector2i(x, row))
		if free < 12:
			return "zone des ennemis trop petite (ligne %d)" % row
	var from_heroes := map.reachable(hero_cells)
	var from_enemies := map.reachable(enemy_cells)
	if not from_enemies.has(Vector2i(WIDTH / 2, data["hero_rows"][0])):
		return "les ennemis n'atteignent pas les héros"
	if not from_heroes.has(enemy_cells[enemy_cells.size() / 2]):
		return "les héros n'atteignent pas les ennemis"
	for i in map.kinds.size():
		var cell := map.cell_at(i)
		if not map.walkable(cell):
			continue
		if not from_heroes.has(cell):
			return "case hors d'atteinte des héros (%s)" % cell
		if data["wall_row"] < 0 and not from_enemies.has(cell):
			return "case hors d'atteinte des ennemis (%s)" % cell
	if data["template"] != "arene":
		var lookouts: Array = data["lookout"].filter(func(c): return from_heroes.has(c) and map.height_at(c) >= 2)
		if lookouts.is_empty():
			return "pas de point haut accessible"
	for exit in data["alley_exits"]:
		var alley_top := Vector2i(int(exit.x), ALLEY_ROW)
		if not from_enemies.has(alley_top) or not map.connected(alley_top, Vector2i(int(exit.x), int(exit.y))):
			return "ruelle bouchée (%s)" % exit
	return ""


# ---------------------------------------------------------------------------
# Fabrication
# ---------------------------------------------------------------------------

static func _build(template: String, rng: RandomNumberGenerator) -> Dictionary:
	var map := BattleMap.new(WIDTH, LENGTH)
	var data := {"version": MAP_VERSION, "template": template, "structures": [],
		"hero_rows": [HERO_FRONT_ROW, HERO_BACK_ROW], "enemy_rows": ENEMY_ROWS, "entry_row": ENTRY_ROW,
		"alley_exits": [], "alley_exit_row": -1, "wall_row": -1, "lookout": []}
	var taken := {}  # cases déjà prises par un décor (avec la marge autour des maisons)
	match template:
		"village":
			_village(map, data, taken, rng)
		"prairie":
			_prairie(map, data, taken, rng)
		"relief":
			_relief(map, data, taken, rng)
		"ville":
			_town(map, data, rng)
		"cite":
			_city(map, data, taken, rng)
		_:
			for i in rng.randi_range(2, 4):
				_place(map, data, taken, rng, Vector2i(1, 1), K.ROCK, 1, "rock", 0)
	var cells := map.to_data()
	data["size"] = cells["size"]
	data["heights"] = cells["heights"]
	data["kinds"] = cells["kinds"]
	return data


## Pose un décor rectangulaire au hasard dans le milieu de la carte, sans chevaucher les autres (ni leur
## marge « margin »). Renvoie le rectangle posé (taille nulle si aucune place n'a été trouvée).
static func _place(map: BattleMap, data: Dictionary, taken: Dictionary, rng: RandomNumberGenerator, rect_size: Vector2i,
		kind: int, height: int, structure: String, margin: int, rows := MIDDLE_ROWS) -> Rect2i:
	for attempt in 30:
		var pos := Vector2i(rng.randi_range(0, WIDTH - rect_size.x), rng.randi_range(rows.x, rows.y - rect_size.y + 1))
		var rect := Rect2i(pos, rect_size)
		if _free(taken, rect.grow(margin)):
			_take(taken, rect.grow(margin))
			map.fill(rect, kind, height)
			data["structures"].append({"kind": structure, "rect": rect, "height": height})
			return rect
	return Rect2i()


static func _free(taken: Dictionary, rect: Rect2i) -> bool:
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			if taken.has(Vector2i(x, y)):
				return false
	return true


static func _take(taken: Dictionary, rect: Rect2i) -> void:
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			taken[Vector2i(x, y)] = true


## Une butte : un anneau de pente (STAIRS, 1 niveau) autour d'un sommet (ROCK, 2 niveaux) : un point haut.
static func _mound(map: BattleMap, data: Dictionary, taken: Dictionary, rng: RandomNumberGenerator, top_size: Vector2i) -> void:
	var rect := _place(map, data, taken, rng, top_size + Vector2i(2, 2), K.STAIRS, 1, "mound", 1)
	if rect.size == Vector2i.ZERO:
		return
	var top := Rect2i(rect.position + Vector2i(1, 1), top_size)
	map.fill(top, K.ROCK, 2)
	for x in range(top.position.x, top.end.x):
		for y in range(top.position.y, top.end.y):
			data["lookout"].append(Vector2i(x, y))


static func _village(map: BattleMap, data: Dictionary, taken: Dictionary, rng: RandomNumberGenerator) -> void:
	# La grange : un toit à 2 niveaux, une échelle côté héros (le point haut du village).
	var barn := _place(map, data, taken, rng, Vector2i(3, 2), K.ROOF, 2, "barn", 1)
	if barn.size != Vector2i.ZERO:
		var ladder := Vector2i(barn.position.x + rng.randi_range(0, 2), barn.end.y)
		map.fill(Rect2i(ladder, Vector2i.ONE), K.LADDER, 0)
		for x in range(barn.position.x, barn.end.x):
			for y in range(barn.position.y, barn.end.y):
				data["lookout"].append(Vector2i(x, y))
	# Maisons basses éparses (fermées).
	for i in rng.randi_range(2, 4):
		_place(map, data, taken, rng, Vector2i(rng.randi_range(2, 3), 2), K.BLOCK, 2, "house", 1)
	# Le puits, les clôtures, les champs, les ondulations.
	_place(map, data, taken, rng, Vector2i.ONE, K.BLOCK, 1, "well", 1)
	for i in rng.randi_range(2, 3):
		_place(map, data, taken, rng, Vector2i(rng.randi_range(2, 4), 1), K.LOW_WALL, 1, "fence", 1)
	for i in rng.randi_range(1, 2):
		_place(map, data, taken, rng, Vector2i(3, 2), K.GRASS, 0, "field", 0)
	for i in rng.randi_range(1, 2):
		_place(map, data, taken, rng, Vector2i(rng.randi_range(2, 3), 2), K.STAIRS, 1, "bump", 1)


static func _prairie(map: BattleMap, data: Dictionary, taken: Dictionary, rng: RandomNumberGenerator) -> void:
	_mound(map, data, taken, rng, Vector2i(2, 1))
	for i in 2:
		_place(map, data, taken, rng, Vector2i(rng.randi_range(3, 4), rng.randi_range(2, 3)), K.STAIRS, 1, "hill", 1)
	for i in rng.randi_range(2, 3):
		_place(map, data, taken, rng, Vector2i(rng.randi_range(1, 2), rng.randi_range(1, 2)), K.BLOCK, 3, "trees", 1)
	for i in rng.randi_range(2, 3):
		_place(map, data, taken, rng, Vector2i.ONE, K.ROCK, 1, "rock", 1)
	for i in rng.randi_range(2, 3):
		_place(map, data, taken, rng, Vector2i(rng.randi_range(2, 4), 2), K.GRASS, 0, "grass", 0)


static func _relief(map: BattleMap, data: Dictionary, taken: Dictionary, rng: RandomNumberGenerator) -> void:
	_mound(map, data, taken, rng, Vector2i(2, 1))
	for i in rng.randi_range(3, 4):
		_place(map, data, taken, rng, Vector2i(rng.randi_range(1, 2), 1), K.ROCK, 1, "rock", 1)
	for i in rng.randi_range(1, 2):
		_place(map, data, taken, rng, Vector2i(2, 2), K.BLOCK, 2, "boulder", 1)
	# Ruines : un pan de mur (2 niveaux) prolongé d'un muret.
	for i in rng.randi_range(1, 2):
		var wall := _place(map, data, taken, rng, Vector2i(rng.randi_range(3, 5), 1), K.LOW_WALL, 1, "ruin", 1)
		if wall.size != Vector2i.ZERO:
			map.fill(Rect2i(wall.position, Vector2i(rng.randi_range(1, 2), 1)), K.BLOCK, 2)


## Ville en ruine (survie) : la rangée de maisons percée de ruelles, les toits, les échelles, le clocher.
static func _town(map: BattleMap, data: Dictionary, rng: RandomNumberGenerator) -> void:
	var top := ALLEY_ROW
	var alleys: Array[int] = []
	var span := float(WIDTH) / GameData.SURVIVAL_ALLEYS
	for i in GameData.SURVIVAL_ALLEYS:
		alleys.append(clampi(int(span * (i + 0.5)) + rng.randi_range(-1, 1), 1, WIDTH - 2))
	alleys.sort()
	# Les pâtés de maisons entre les ruelles : des toits (2 niveaux).
	var blocks: Array[Rect2i] = []
	var x := 0
	while x < WIDTH:
		if x in alleys:
			x += 1
			continue
		var start := x
		while x < WIDTH and not x in alleys:
			x += 1
		blocks.append(Rect2i(start, top, x - start, ALLEY_LENGTH))
	for alley in alleys:
		data["alley_exits"].append(Vector2(alley + 0.5, top + ALLEY_LENGTH + 0.5))
	data["alley_exit_row"] = top + ALLEY_LENGTH
	# Les échelles : deux côté héros, une côté ennemis (sur un autre pâté si possible) ; jamais au pied d'une
	# ruelle. Un pâté sans échelle reste fermé (on n'y monte pas : maisons fermées).
	var order := _shuffled(blocks.size(), rng)
	var hero_blocks: Array = order.slice(0, mini(2, blocks.size()))
	var enemy_block: int = order[2] if blocks.size() > 2 else order[0]
	var ladders := []
	for b in hero_blocks:
		ladders.append([blocks[b], top + ALLEY_LENGTH])
	ladders.append([blocks[enemy_block], top - 1])
	var open := {}
	for entry in ladders:
		var rect: Rect2i = entry[0]
		var cell := Vector2i(rng.randi_range(rect.position.x, rect.end.x - 1), entry[1])
		map.fill(Rect2i(cell, Vector2i.ONE), K.LADDER, 0)
		data["structures"].append({"kind": "ladder", "rect": Rect2i(cell, Vector2i.ONE), "height": 2})
		open[rect] = true
	for rect in blocks:
		if open.has(rect):
			map.fill(rect, K.ROOF, 2)
			data["structures"].append({"kind": "roof", "rect": rect, "height": 2})
			for cx in range(rect.position.x, rect.end.x):
				for cy in range(rect.position.y, rect.end.y):
					data["lookout"].append(Vector2i(cx, cy))
		else:
			map.fill(rect, K.BLOCK, 2)
			data["structures"].append({"kind": "house", "rect": rect, "height": 2})
	# Le clocher (le plus haut, 4 niveaux) : sur le plus large des pâtés à échelle côté héros, loin des ruelles ;
	# on y monte depuis le toit par une échelle (la case du toit juste devant).
	var widest: Rect2i = blocks[hero_blocks[0]]
	for b in hero_blocks:
		if blocks[b].size.x > widest.size.x:
			widest = blocks[b]
	if widest.size.x >= 3:
		var tower := Vector2i(widest.position.x + widest.size.x / 2, top + 1)
		map.fill(Rect2i(tower, Vector2i.ONE), K.TOWER, 4)
		map.fill(Rect2i(tower + Vector2i(0, 1), Vector2i.ONE), K.LADDER, 2)
		data["structures"].append({"kind": "bell", "rect": Rect2i(tower, Vector2i.ONE), "height": 4})
		data["lookout"] = [tower]
	# Côté ennemis : quelques rochers et débris, pour que la horde n'arrive pas en ligne droite.
	var taken := {}
	_take(taken, Rect2i(0, top - 1, WIDTH, ALLEY_LENGTH + 2))
	for i in rng.randi_range(2, 4):
		_place(map, data, taken, rng, Vector2i(rng.randi_range(1, 2), 1), K.ROCK if rng.randf() < 0.5 else K.LOW_WALL, 1,
			"debris", 1, Vector2i(ENEMY_ROWS.y + 1, top - 2))


## Mélange les nombres 0 .. count - 1 avec la graine de la carte (même graine, même mélange).
static func _shuffled(count: int, rng: RandomNumberGenerator) -> Array:
	var order := range(count)
	for i in range(count - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: int = order[i]
		order[i] = order[j]
		order[j] = swap
	return order


## Cité à défendre : le rempart à 2 niveaux en bas, la porte fermée, les escaliers à l'intérieur.
static func _city(map: BattleMap, data: Dictionary, taken: Dictionary, rng: RandomNumberGenerator) -> void:
	data["wall_row"] = WALL_ROW
	data["hero_rows"] = [DEFENSE_FRONT_ROW, WALL_ROW]  # les tireurs sur le chemin de ronde
	map.fill(Rect2i(0, WALL_ROW, WIDTH, 1), K.RAMPART, 2)
	data["structures"].append({"kind": "rampart", "rect": Rect2i(0, WALL_ROW, WIDTH, 1), "height": 2})
	var gate := Rect2i(WIDTH / 2 - 1, WALL_ROW, 2, 1)
	map.fill(gate, K.BLOCK, 2)
	data["structures"].append({"kind": "gate", "rect": gate, "height": 2})
	for x in [2, WIDTH / 2 - 3, WIDTH / 2 + 2, WIDTH - 3]:
		map.fill(Rect2i(x, WALL_ROW + 1, 1, 1), K.STAIRS, 1)
		data["structures"].append({"kind": "stairs", "rect": Rect2i(x, WALL_ROW + 1, 1, 1), "height": 1})
	for x in WIDTH:
		if not Rect2i(x, WALL_ROW, 1, 1).intersects(gate):
			data["lookout"].append(Vector2i(x, WALL_ROW))
	# Devant : plat, quelques barricades et rochers.
	for i in rng.randi_range(2, 3):
		_place(map, data, taken, rng, Vector2i(rng.randi_range(2, 3), 1), K.LOW_WALL, 1, "barricade", 1, Vector2i(6, 11))
	for i in rng.randi_range(1, 3):
		_place(map, data, taken, rng, Vector2i.ONE, K.ROCK, 1, "rock", 1, Vector2i(5, 11))
