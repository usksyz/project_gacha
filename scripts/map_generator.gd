class_name MapGenerator
extends RefCounted
## Fabrique la carte d'un combat (cahier, onglet « Combat v2 », section 8 bis ; étape C1) : la carte est une
## DONNÉE, produite par generate_map(étage, quête, graine) : hauteurs et types des cases (BattleMap),
## structures à dessiner, zones de départ, sortie des ruelles, rempart, point haut. Même graine, même carte.
##
## Cartes, étape 2 (demande du porteur du projet : « des cartes plus grandes, rondes, du relief au sol, un village qui
## ressemble à un village, une forêt avec des arbres ; bruit de Perlin et autres méthodes superposées pour des cartes
## belles, fonctionnelles, variées et cohérentes » ; ajout du projet). Méthodes superposées (voir docs/combat.md,
## « Cartes ») :
## - la forme : un disque (une ellipse qui remplit la grille, inside) ; au-delà, une lisière infranchissable (des arbres,
##   des rochers ou des ruines selon le lieu : « edge_style ») ;
## - le relief : un bruit de Perlin fractal (fBm, plusieurs octaves, FastNoiseLite), seuillé en niveaux 0, 1, 2 selon
##   le lieu ; puis lissé (jamais plus d'un niveau d'écart entre deux cases voisines) ; une case plus haute que sa
##   voisine devient une pente douce (STAIRS), ou reste une petite falaise (on l'escalade) en terrain accidenté ;
## - les décors : posés par lieu sur ce relief (une route sinueuse tracée par un bruit 1D, des maisons de part et
##   d'autre ; des arbres par un échantillonnage de Poisson simplifié (jamais trop près l'un de l'autre), modulé par un
##   second bruit (des clairières et des bosquets) ; des herbes hautes par un troisième bruit) ;
## - la jouabilité : les zones de départ restent plates, les poches qu'on ne peut atteindre deviennent des buissons
##   ou des rochers, puis les vérifications de C1 (check) ; si elles échouent, on recommence avec la suite de la graine.
## Gabarits :
## - village (étage 1, « les gobelins ont envahi le village ») : presque plat, une route de terre qui traverse, des
##   maisons fermées le long de la route (toit à deux pans), une grange (toit et échelle : le point haut), un puits,
##   des champs clôturés, quelques arbres ;
## - prairie (étage 2) : collines douces, une butte (point haut), bosquets, rochers isolés, herbes hautes ;
## - foret (autres étages ordinaires, une graine sur deux ; ajout du projet) : des arbres, des clairières, un
##   sentier, du sous-bois (herbes hautes), une butte rocheuse (point haut) ;
## - relief (autres étages ordinaires, l'autre moitié) : collines et petites falaises, une butte, des rochers, des
##   blocs, des ruines (murets et pans de mur) ;
## - ville (survie, « ville en ruine » de l'étage 5) : la rangée de maisons percée de ruelles d'une case ;
##   les maisons sont des toits (2 niveaux), quelques-uns accessibles par des échelles (côté héros, et une
##   côté ennemis : la horde peut monter), un clocher (4 niveaux, le point haut) ; débris côté ennemis ;
## - cite (défense) : un rempart à 2 niveaux (chemin de ronde, escaliers à l'intérieur, porte fermée), plat
##   devant, quelques barricades ;
## - arene (duel) : plat, quelques rochers.

const K := BattleMap.Kind

## Version du format de la carte (pour les cartes enregistrées dans la sauvegarde). 2 : cartes rondes de 24 x 26
## (cartes, étape 2) ; une carte de version 1 (18 x 20) est refaite (voir GameSave).
const MAP_VERSION := 2

const WIDTH := 24
const LENGTH := 26
## Le disque de la carte : son centre et ses demi-axes (en cases).
const CENTER := Vector2(WIDTH / 2.0, LENGTH / 2.0)
const RADII := Vector2(WIDTH / 2.0 - 0.4, LENGTH / 2.0 - 0.4)
## Zones de départ : héros en bas (première ligne, et deuxième ligne pour les tireurs), ennemis en haut
## (lignes ENEMY_ROWS ; les renforts entrent par ENTRY_ROW).
const HERO_FRONT_ROW := 19
const HERO_BACK_ROW := 21
const ENEMY_ROWS := Vector2i(3, 5)
const ENTRY_ROW := 1
## Les décors des étages ordinaires se posent entre ces lignes (le milieu de la carte).
const MIDDLE_ROWS := Vector2i(7, 17)
## Terrain de survie : première ligne des maisons et profondeur (longueur des ruelles).
const ALLEY_ROW := 11
const ALLEY_LENGTH := 3
## Défense : ligne du chemin de ronde du rempart (hauteur 2) ; les héros au corps à corps sont devant.
const WALL_ROW := 22
const DEFENSE_FRONT_ROW := 20
## Nombre d'essais avant de prendre une carte plate.
const ATTEMPTS := 40
## Le relief de chaque lieu : fréquence du bruit, seuils des niveaux 1 et 2 (au-dessus de 1 : jamais), part des bords
## qui restent des falaises (sinon des pentes douces), style de la lisière.
const TERRAIN := {
	"village": {"frequency": 0.07, "levels": [0.42, 2.0], "cliffs": 0.0, "edge": "trees"},
	"prairie": {"frequency": 0.08, "levels": [0.12, 0.62], "cliffs": 0.0, "edge": "trees"},
	"foret": {"frequency": 0.09, "levels": [0.22, 2.0], "cliffs": 0.0, "edge": "trees"},
	"relief": {"frequency": 0.1, "levels": [0.02, 0.42], "cliffs": 0.35, "edge": "rocks"},
	"ville": {"frequency": 0.1, "levels": [2.0, 2.0], "cliffs": 0.0, "edge": "ruins"},
	"cite": {"frequency": 0.1, "levels": [2.0, 2.0], "cliffs": 0.0, "edge": "rocks"},
	"arene": {"frequency": 0.1, "levels": [2.0, 2.0], "cliffs": 0.0, "edge": "rocks"},
}
## Forêt : distance minimale entre deux arbres (échantillonnage de Poisson), seuil du bruit des clairières.
const TREE_SPACING := 1.3
const FOREST_DENSITY := -0.32
## Relief : une case garde son niveau si au moins CA_KEEP de ses 8 voisines sont aussi hautes (automate cellulaire).
const CA_KEEP := 4


## Le gabarit d'un étage (voir l'en-tête). « map_seed » : la forêt ou le relief, selon la graine (étages ordinaires).
static func template_for(floor_number: int, quest: Dictionary, map_seed := 0) -> String:
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
	return "foret" if absi(hash([map_seed, "lieu"])) % 2 == 0 else "relief"


## Vrai si la case est dans le disque de la carte (sinon : la lisière, infranchissable).
static func inside(cell: Vector2i) -> bool:
	var d := (Vector2(cell) + Vector2(0.5, 0.5) - CENTER) / RADII
	return d.length_squared() <= 1.0


## Un étage de la Tour entier, en donnée (cahier, section 8 bis, « Préparation dès C1 ») : la carte
## (generate_map) et la liste des ennemis (GameData.tower_enemies : espèces, nombre, niveaux, chef, vagues),
## avec leur position de départ : « start » (case de départ, pour ceux qui sont sur le terrain dès le début) et
## « entry » (colonne d'entrée par le haut, pour les renforts et les vagues suivantes). « elite » : pas encore
## d'élites (étape C5), toujours faux. Même graine, même étage. Voir GameData.floor_layout : l'étage est figé à
## sa première visite. Renvoie {"version", "seed", "map", "enemies"}.
static func generate(floor_number: int, quest: Dictionary, floor_seed: int) -> Dictionary:
	var map := generate_map(floor_number, quest, floor_seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([floor_seed, "ennemis"])
	var enemies: Array[Dictionary] = GameData.tower_enemies(floor_number, rng)
	var cells := BattleMap.new()
	cells.size = map["size"]
	cells.heights = PackedInt32Array(map["heights"])
	cells.kinds = PackedInt32Array(map["kinds"])
	var starts := []
	for row in range(map["enemy_rows"].x, map["enemy_rows"].y + 1):
		for x in WIDTH:
			if cells.walkable(Vector2i(x, row)) and cells.height_at(Vector2i(x, row)) == 0:
				starts.append(Vector2i(x, row))
	var entries := []
	for x in range(1, WIDTH - 1):
		if cells.walkable(Vector2i(x, map["entry_row"])):
			entries.append(x)
	for enemy in enemies:
		enemy["elite"] = false
		enemy["entry"] = entries[rng.randi_range(0, entries.size() - 1)]
		if enemy.get("wave", 0) == 0 and not starts.is_empty():
			enemy["start"] = starts.pop_at(rng.randi_range(0, starts.size() - 1))
	return {"version": MAP_VERSION, "seed": floor_seed, "map": map, "enemies": enemies}


## La carte d'un combat : une donnée (Dictionary) que Battle reprend telle quelle (voir Battle.map_data) :
## {"version", "seed", "template", "size", "heights", "kinds", "structures": [{"kind", "rect", "height", "base"?,
##  "facing"?}], "roads": [cases de la route ou du sentier], "edge_style", "hero_rows": [première ligne, ligne des
##  tireurs], "enemy_rows", "entry_row", "alley_exits": [Vector2], "alley_exit_row", "wall_row" (-1 : pas de rempart),
##  "lookout": [cases hautes de repérage]}.
static func generate_map(floor_number: int, quest: Dictionary, map_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	var template := template_for(floor_number, quest, map_seed)
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
	var hero_cells := _hero_cells(map, data)
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
		if free < 8:
			return "zone des héros trop petite (ligne %d)" % row
	var enemy_cells := _enemy_cells(map, data)
	for row in range(data["enemy_rows"].x, data["enemy_rows"].y + 1):
		if enemy_cells.filter(func(c): return c.y == row).size() < 10:
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


static func _hero_cells(map: BattleMap, data: Dictionary) -> Array:
	var cells := []
	for row in data["hero_rows"]:
		for x in range(3, WIDTH - 3):
			if map.walkable(Vector2i(x, row)):
				cells.append(Vector2i(x, row))
	return cells


static func _enemy_cells(map: BattleMap, data: Dictionary) -> Array:
	var cells := []
	for row in range(data["enemy_rows"].x, data["enemy_rows"].y + 1):
		for x in WIDTH:
			if map.walkable(Vector2i(x, row)) and map.height_at(Vector2i(x, row)) == 0:
				cells.append(Vector2i(x, row))
	return cells


# ---------------------------------------------------------------------------
# Fabrication
# ---------------------------------------------------------------------------

static func _build(template: String, rng: RandomNumberGenerator) -> Dictionary:
	var map := BattleMap.new(WIDTH, LENGTH)
	var terrain: Dictionary = TERRAIN.get(template, TERRAIN["arene"])
	var data := {"version": MAP_VERSION, "template": template, "structures": [], "roads": [],
		"edge_style": terrain["edge"], "hero_rows": [HERO_FRONT_ROW, HERO_BACK_ROW], "enemy_rows": ENEMY_ROWS,
		"entry_row": ENTRY_ROW, "alley_exits": [], "alley_exit_row": -1, "wall_row": -1, "lookout": []}
	var taken := {}  # cases déjà prises par un décor (avec la marge autour des maisons), la lisière, la route
	for i in map.kinds.size():
		if not inside(map.cell_at(i)):
			taken[map.cell_at(i)] = true
	_relief_heights(map, data, terrain, rng)
	match template:
		"village":
			_village(map, data, taken, rng)
		"prairie":
			_prairie(map, data, taken, rng)
		"foret":
			_forest(map, data, taken, rng)
		"relief":
			_relief(map, data, taken, rng)
		"ville":
			_town(map, data, rng)
		"cite":
			_city(map, data, taken, rng)
		_:
			for i in rng.randi_range(3, 5):
				_place(map, data, taken, rng, Vector2i(1, 1), K.ROCK, 1, "rock", 0)
	_slopes(map, terrain, rng)
	_edge(map)
	_fill_pockets(map, data)
	var cells := map.to_data()
	data["size"] = cells["size"]
	data["heights"] = cells["heights"]
	data["kinds"] = cells["kinds"]
	return data


## Le relief : un bruit de Perlin fractal (fBm, 4 octaves) seuillé en niveaux (selon le lieu), les zones de départ
## (et leurs abords) remises à plat, puis lissé : jamais plus d'un niveau d'écart entre deux cases voisines.
static func _relief_heights(map: BattleMap, data: Dictionary, terrain: Dictionary, rng: RandomNumberGenerator) -> void:
	var noise := _noise(rng, terrain["frequency"])
	var levels: Array = terrain["levels"]
	for i in map.kinds.size():
		var cell := map.cell_at(i)
		if not inside(cell) or _flat_zone(cell, data):
			continue
		var value := noise.get_noise_2d(cell.x, cell.y)
		map.heights[i] = 2 if value >= levels[1] else (1 if value >= levels[0] else 0)
	# Automate cellulaire (deux passes) : une case garde son niveau seulement si au moins CA_KEEP de ses 8 voisines sont
	# aussi hautes ; sinon elle descend d'un niveau. Plus de petits îlots ni de pics isolés : des collines lisibles.
	for repeat in 2:
		var next := map.heights.duplicate()
		for i in map.kinds.size():
			var h := map.heights[i]
			if h == 0:
				continue
			var cell := map.cell_at(i)
			var high := 0
			for d in BattleMap.DIRECTIONS:
				if map.height_at(cell + d) >= h:
					high += 1
			if high < CA_KEEP:
				next[i] = h - 1
		map.heights = next
	_smooth(map)


## Le centre des zones de départ (là où l'on se place) : aucun décor. Les côtés des zones peuvent avoir des arbres, des
## herbes ou des rochers (pas de relief : voir _flat_zone).
static func _open_zone(cell: Vector2i, data: Dictionary) -> bool:
	return _flat_zone(cell, data) and cell.x >= 5 and cell.x < WIDTH - 5


## Les zones de départ (et une ligne autour) restent plates, au sol.
static func _flat_zone(cell: Vector2i, data: Dictionary) -> bool:
	var hero_top: int = mini(data["hero_rows"][0], data["hero_rows"][1]) - 1
	return cell.y >= hero_top or cell.y <= data["enemy_rows"].y + 1


## Jamais plus d'un niveau d'écart entre deux cases voisines au sol (on abaisse la plus haute).
static func _smooth(map: BattleMap) -> void:
	var changed := true
	while changed:
		changed = false
		for i in map.kinds.size():
			var cell := map.cell_at(i)
			if map.kinds[i] != K.GROUND:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var next: Vector2i = cell + d
				if map.in_bounds(next) and map.kinds[map.index(next)] == K.GROUND and map.heights[i] > map.height_at(next) + 1:
					map.heights[i] = map.height_at(next) + 1
					changed = true


## Les pentes : une case au sol plus haute qu'une voisine devient une pente douce (STAIRS, on y marche presque
## normalement), sauf une part « cliffs » des bords en terrain accidenté (petites falaises : on les escalade).
static func _slopes(map: BattleMap, terrain: Dictionary, rng: RandomNumberGenerator) -> void:
	var cliffs := _noise(rng, 0.2)
	for i in map.kinds.size():
		var cell := map.cell_at(i)
		if map.kinds[i] != K.GROUND or not inside(cell):
			continue
		var lower := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + d
			if map.in_bounds(next) and inside(next) and map.walkable(next) and map.height_at(next) < map.heights[i]:
				lower = true
		if lower and (cliffs.get_noise_2d(cell.x, cell.y) + 1.0) / 2.0 >= terrain["cliffs"]:
			map.kinds[i] = K.STAIRS


## La lisière : hors du disque, une case infranchissable (dessinée selon « edge_style » : arbres, rochers, ruines).
static func _edge(map: BattleMap) -> void:
	for i in map.kinds.size():
		if not inside(map.cell_at(i)):
			map.kinds[i] = K.BLOCK
			map.heights[i] = 3


## Les poches qu'on ne peut atteindre depuis les deux zones de départ deviennent des buissons (ou des rochers) : rien
## d'inutile sur la carte, et les vérifications passent plus souvent.
static func _fill_pockets(map: BattleMap, data: Dictionary) -> void:
	var from_heroes := map.reachable(_hero_cells(map, data))
	var from_enemies := map.reachable(_enemy_cells(map, data))
	for i in map.kinds.size():
		var cell := map.cell_at(i)
		if not map.walkable(cell) or not inside(cell):
			continue
		if from_heroes.has(cell) and (data["wall_row"] >= 0 or from_enemies.has(cell)):
			continue
		var base := map.heights[i]
		map.kinds[i] = K.BLOCK
		map.heights[i] = base + 1
		data["structures"].append({"kind": "bush", "rect": Rect2i(cell, Vector2i.ONE), "height": base + 1, "base": base})


## Un bruit de Perlin fractal (fBm) tiré de la graine de la carte.
static func _noise(rng: RandomNumberGenerator, frequency: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.frequency = frequency
	return noise


## Pose un décor rectangulaire au hasard dans le milieu de la carte, sur un terrain plat (tout à la même hauteur,
## au sol), sans chevaucher les autres (ni leur marge « margin »). Sa hauteur s'ajoute à celle du terrain.
## Renvoie le rectangle posé (taille nulle si aucune place n'a été trouvée).
static func _place(map: BattleMap, data: Dictionary, taken: Dictionary, rng: RandomNumberGenerator, rect_size: Vector2i,
		kind: int, height: int, structure: String, margin: int, rows := MIDDLE_ROWS) -> Rect2i:
	for attempt in 40:
		var pos := Vector2i(rng.randi_range(0, WIDTH - rect_size.x), rng.randi_range(rows.x, rows.y - rect_size.y + 1))
		var rect := Rect2i(pos, rect_size)
		if _free(taken, rect.grow(margin)) and _flat(map, rect):
			return _put(map, data, taken, rect, kind, height, structure, margin)
	return Rect2i()


## Pose un décor sur ce rectangle (déjà choisi) ; sa hauteur s'ajoute à celle du terrain.
static func _put(map: BattleMap, data: Dictionary, taken: Dictionary, rect: Rect2i, kind: int, height: int,
		structure: String, margin: int, extra := {}) -> Rect2i:
	var base := map.height_at(rect.position)
	_take(taken, rect.grow(margin))
	map.fill(rect, kind, base + height)
	var entry := {"kind": structure, "rect": rect, "height": base + height, "base": base}
	entry.merge(extra)
	data["structures"].append(entry)
	return rect


static func _free(taken: Dictionary, rect: Rect2i) -> bool:
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			if taken.has(Vector2i(x, y)):
				return false
	return true


## Tout le rectangle est dans la carte, au sol, à la même hauteur.
static func _flat(map: BattleMap, rect: Rect2i) -> bool:
	var height := map.height_at(rect.position)
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var cell := Vector2i(x, y)
			if not map.in_bounds(cell) or not inside(cell) or map.kind_at(cell) != K.GROUND or map.height_at(cell) != height:
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
	var base := map.height_at(rect.position) - 1
	var top := Rect2i(rect.position + Vector2i(1, 1), top_size)
	map.fill(top, K.ROCK, base + 2)
	for x in range(top.position.x, top.end.x):
		for y in range(top.position.y, top.end.y):
			data["lookout"].append(Vector2i(x, y))


## Une route ou un sentier de bas en haut de la carte, qui serpente (bruit 1D) : des cases au sol, à plat (la hauteur
## du terrain, lissée le long du chemin), réservées (rien n'y est posé), dans data["roads"].
static func _road(map: BattleMap, data: Dictionary, taken: Dictionary, rng: RandomNumberGenerator, width: int, sway: float) -> Array:
	var noise := _noise(rng, 0.06)
	var cells := []
	for y in LENGTH:
		var x := roundi(CENTER.x - width / 2.0 + noise.get_noise_1d(y * 1.0) * sway)
		for k in width:
			var cell := Vector2i(clampi(x + k, 0, WIDTH - 1), y)
			if not inside(cell):
				continue
			map.kinds[map.index(cell)] = K.GROUND
			cells.append(cell)
			taken[cell] = true
	data["roads"] = cells
	return cells


## Des arbres (une case chacun, infranchissable) par échantillonnage de Poisson simplifié : on essaie les cases dans
## un ordre tiré de la graine, en gardant celles qui sont à plus de « spacing » cases des arbres déjà posés et où le
## bruit « density » dépasse « threshold » (des bosquets et des clairières). Renvoie le nombre d'arbres.
static func _trees(map: BattleMap, data: Dictionary, taken: Dictionary, rng: RandomNumberGenerator, rows: Vector2i,
		spacing: float, threshold: float, frequency: float, limit: int) -> int:
	var density := _noise(rng, frequency)
	var candidates := []
	for y in range(rows.x, rows.y + 1):
		for x in WIDTH:
			var cell := Vector2i(x, y)
			if not taken.has(cell) and inside(cell) and map.kind_at(cell) == K.GROUND and not _open_zone(cell, data):
				candidates.append(cell)
	var order := _shuffled(candidates.size(), rng)
	var planted := []
	for k in order:
		if planted.size() >= limit:
			break
		var cell: Vector2i = candidates[k]
		if density.get_noise_2d(cell.x, cell.y) < threshold:
			continue
		if planted.any(func(p): return Vector2(p).distance_to(Vector2(cell)) < spacing):
			continue
		planted.append(cell)
		_put(map, data, taken, Rect2i(cell, Vector2i.ONE), K.BLOCK, 3, "trees", 0)
	return planted.size()


## Des herbes hautes là où un bruit dépasse « threshold » (cases au sol, à plat).
static func _grass(map: BattleMap, data: Dictionary, taken: Dictionary, rng: RandomNumberGenerator, threshold: float,
		rows := Vector2i(1, LENGTH - 2)) -> void:
	var noise := _noise(rng, 0.13)
	for y in range(rows.x, rows.y + 1):
		for x in WIDTH:
			var cell := Vector2i(x, y)
			if not taken.has(cell) and inside(cell) and not _open_zone(cell, data) and map.kind_at(cell) == K.GROUND \
					and noise.get_noise_2d(x, y) > threshold:
				map.kinds[map.index(cell)] = K.GRASS


static func _village(map: BattleMap, data: Dictionary, taken: Dictionary, rng: RandomNumberGenerator) -> void:
	# La route de terre qui traverse le village (deux cases de large), et le bourg aplati autour d'elle.
	var road := _road(map, data, taken, rng, 2, 6.0)
	for i in map.kinds.size():
		var cell := map.cell_at(i)
		if road.any(func(r): return absi(r.y - cell.y) <= 1 and absi(r.x - cell.x) <= 5):
			map.heights[i] = 0
	_smooth(map)
	# La grange : un toit à 2 niveaux, une échelle côté héros (le point haut du village).
	var barn := _place(map, data, taken, rng, Vector2i(3, 2), K.ROOF, 2, "barn", 1)
	if barn.size != Vector2i.ZERO:
		var ladder := Vector2i(barn.position.x + rng.randi_range(0, 2), barn.end.y)
		map.fill(Rect2i(ladder, Vector2i.ONE), K.LADDER, map.height_at(ladder))
		taken[ladder] = true
		for x in range(barn.position.x, barn.end.x):
			for y in range(barn.position.y, barn.end.y):
				data["lookout"].append(Vector2i(x, y))
	# Les maisons, alignées de part et d'autre de la route, la façade tournée vers elle (toit à deux pans).
	var houses := 0
	var y := MIDDLE_ROWS.x
	while y <= MIDDLE_ROWS.y - 1 and houses < 10:
		var here: Array = road.filter(func(c): return c.y == y)
		if here.is_empty():
			y += 1
			continue
		var left: int = here.map(func(c): return c.x).min()
		var right: int = here.map(func(c): return c.x).max()
		for side in [-1, 1]:
			if rng.randf() >= 0.9:
				continue
			var size := Vector2i(rng.randi_range(2, 3), 2)
			for gap in [1, 2, 3]:  # (au plus près de la route, là où il y a la place)
				var x0: int = left - gap - size.x if side < 0 else right + 1 + gap
				var rect := Rect2i(Vector2i(x0, y), size)
				# (une case libre sur les côtés ; entre deux maisons d'un même côté, la ruelle d'une case suffit)
				var sides := Rect2i(rect.position - Vector2i(1, 0), rect.size + Vector2i(2, 0))
				if _free(taken, sides) and _flat(map, rect):
					_put(map, data, taken, rect, K.BLOCK, 2, "house", 0, {"facing": Vector2i(-side, 0)})
					_take(taken, sides)
					houses += 1
					break
		y += 3
	# Le puits, au bord de la route.
	_place(map, data, taken, rng, Vector2i.ONE, K.BLOCK, 1, "well", 1)
	# Les champs (herbes hautes), entourés d'une clôture d'un ou deux côtés.
	for i in rng.randi_range(2, 3):
		var field := _place(map, data, taken, rng, Vector2i(rng.randi_range(3, 4), rng.randi_range(2, 3)), K.GRASS, 0, "field", 0)
		if field.size == Vector2i.ZERO:
			continue
		var fence := Rect2i(Vector2i(field.position.x, field.end.y), Vector2i(field.size.x, 1))
		if _free(taken, fence) and _flat(map, fence):
			_put(map, data, taken, fence, K.LOW_WALL, 1, "fence", 0)
	# Quelques arbres et vergers, plutôt vers les bords.
	_trees(map, data, taken, rng, Vector2i(1, LENGTH - 2), 2.5, 0.05, 0.1, 14)


static func _prairie(map: BattleMap, data: Dictionary, taken: Dictionary, rng: RandomNumberGenerator) -> void:
	_mound(map, data, taken, rng, Vector2i(2, 1))
	# Bosquets : des arbres serrés là où le bruit des bois est fort.
	_trees(map, data, taken, rng, Vector2i(1, LENGTH - 2), 1.2, 0.3, 0.12, 24)
	for i in rng.randi_range(3, 5):
		_place(map, data, taken, rng, Vector2i.ONE, K.ROCK, 1, "rock", 1)
	_grass(map, data, taken, rng, 0.18)


static func _forest(map: BattleMap, data: Dictionary, taken: Dictionary, rng: RandomNumberGenerator) -> void:
	# Le sentier (une case de large), qui serpente plus que la route du village, et une butte rocheuse (point haut).
	_road(map, data, taken, rng, 1, 5.0)
	_mound(map, data, taken, rng, Vector2i(2, 1))
	# Les arbres : partout où le bruit des bois dépasse FOREST_DENSITY (clairières ailleurs), y compris près des zones
	# de départ (lisière du bois), espacés de TREE_SPACING.
	_trees(map, data, taken, rng, Vector2i(1, LENGTH - 2), TREE_SPACING, FOREST_DENSITY, 0.11, 110)
	for i in rng.randi_range(2, 3):
		_place(map, data, taken, rng, Vector2i.ONE, K.ROCK, 1, "rock", 1)
	# Le sous-bois : des herbes hautes (on s'y cache).
	_grass(map, data, taken, rng, 0.05)


static func _relief(map: BattleMap, data: Dictionary, taken: Dictionary, rng: RandomNumberGenerator) -> void:
	_mound(map, data, taken, rng, Vector2i(2, 1))
	for i in rng.randi_range(4, 6):
		_place(map, data, taken, rng, Vector2i(rng.randi_range(1, 2), 1), K.ROCK, 1, "rock", 1)
	for i in rng.randi_range(2, 3):
		_place(map, data, taken, rng, Vector2i(2, 2), K.BLOCK, 2, "boulder", 1)
	# Ruines : un pan de mur (2 niveaux) prolongé d'un muret.
	for i in rng.randi_range(2, 3):
		var wall := _place(map, data, taken, rng, Vector2i(rng.randi_range(3, 5), 1), K.LOW_WALL, 1, "ruin", 1)
		if wall.size != Vector2i.ZERO:
			var base := map.height_at(wall.position) - 1
			map.fill(Rect2i(wall.position, Vector2i(rng.randi_range(1, 2), 1)), K.BLOCK, base + 2)
	# Quelques arbres isolés.
	_trees(map, data, taken, rng, MIDDLE_ROWS, 3.0, 0.2, 0.1, 5)


## Ville en ruine (survie) : la rangée de maisons percée de ruelles, les toits, les échelles, le clocher.
static func _town(map: BattleMap, data: Dictionary, rng: RandomNumberGenerator) -> void:
	var top := ALLEY_ROW
	var alleys: Array[int] = []
	# (les ruelles dans la partie large du disque, loin de la lisière)
	var span := float(WIDTH - 8) / GameData.SURVIVAL_ALLEYS
	for i in GameData.SURVIVAL_ALLEYS:
		alleys.append(clampi(4 + int(span * (i + 0.5)) + rng.randi_range(-1, 1), 3, WIDTH - 4))
	alleys.sort()
	# Les pâtés de maisons entre les ruelles : des toits (2 niveaux), jusqu'à la lisière.
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
	# ruelle, toujours dans le disque. Un pâté sans échelle reste fermé (on n'y monte pas : maisons fermées).
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
		var cells := []
		for cx in range(rect.position.x, rect.end.x):
			if inside(Vector2i(cx, entry[1])) and inside(Vector2i(cx, top)):
				cells.append(Vector2i(cx, entry[1]))
		if cells.is_empty():
			continue
		var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		map.fill(Rect2i(cell, Vector2i.ONE), K.LADDER, 0)
		data["structures"].append({"kind": "ladder", "rect": Rect2i(cell, Vector2i.ONE), "height": 2})
		open[rect] = true
	for rect in blocks:
		if open.has(rect):
			map.fill(rect, K.ROOF, 2)
			data["structures"].append({"kind": "roof", "rect": rect, "height": 2})
			for cx in range(rect.position.x, rect.end.x):
				for cy in range(rect.position.y, rect.end.y):
					if inside(Vector2i(cx, cy)):
						data["lookout"].append(Vector2i(cx, cy))
		else:
			map.fill(rect, K.BLOCK, 2)
			data["structures"].append({"kind": "house", "rect": rect, "height": 2, "facing": Vector2i(0, 1)})
	# Le clocher (le plus haut, 4 niveaux) : sur le plus large des pâtés à échelle côté héros, loin des ruelles ;
	# on y monte depuis le toit par une échelle (la case du toit juste devant).
	var widest: Rect2i = blocks[hero_blocks[0]]
	for b in hero_blocks:
		if blocks[b].size.x > widest.size.x:
			widest = blocks[b]
	if widest.size.x >= 3:
		var tower := Vector2i(widest.position.x + widest.size.x / 2, top + 1)
		if inside(tower):
			map.fill(Rect2i(tower, Vector2i.ONE), K.TOWER, 4)
			map.fill(Rect2i(tower + Vector2i(0, 1), Vector2i.ONE), K.LADDER, 2)
			data["structures"].append({"kind": "bell", "rect": Rect2i(tower, Vector2i.ONE), "height": 4})
			data["lookout"] = [tower]
	# Côté ennemis : quelques rochers et débris, pour que la horde n'arrive pas en ligne droite.
	var taken := {}
	for i in map.kinds.size():
		if not inside(map.cell_at(i)):
			taken[map.cell_at(i)] = true
	_take(taken, Rect2i(0, top - 1, WIDTH, ALLEY_LENGTH + 2))
	for i in rng.randi_range(3, 5):
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


## Cité à défendre : le rempart à 2 niveaux en bas (d'un bord du disque à l'autre), la porte fermée, les escaliers à
## l'intérieur.
static func _city(map: BattleMap, data: Dictionary, taken: Dictionary, rng: RandomNumberGenerator) -> void:
	data["wall_row"] = WALL_ROW
	data["hero_rows"] = [DEFENSE_FRONT_ROW, WALL_ROW]  # les tireurs sur le chemin de ronde
	map.fill(Rect2i(0, WALL_ROW, WIDTH, 1), K.RAMPART, 2)
	data["structures"].append({"kind": "rampart", "rect": Rect2i(0, WALL_ROW, WIDTH, 1), "height": 2})
	var gate := Rect2i(WIDTH / 2 - 1, WALL_ROW, 2, 1)
	map.fill(gate, K.BLOCK, 2)
	data["structures"].append({"kind": "gate", "rect": gate, "height": 2})
	for x in [WIDTH / 2 - 5, WIDTH / 2 - 3, WIDTH / 2 + 2, WIDTH / 2 + 4]:
		map.fill(Rect2i(x, WALL_ROW + 1, 1, 1), K.STAIRS, 1)
		data["structures"].append({"kind": "stairs", "rect": Rect2i(x, WALL_ROW + 1, 1, 1), "height": 1})
	for x in WIDTH:
		if not Rect2i(x, WALL_ROW, 1, 1).intersects(gate) and inside(Vector2i(x, WALL_ROW)):
			data["lookout"].append(Vector2i(x, WALL_ROW))
	_take(taken, Rect2i(0, WALL_ROW - 1, WIDTH, LENGTH - WALL_ROW + 1))
	# Devant : plat, quelques barricades et rochers.
	for i in rng.randi_range(3, 4):
		_place(map, data, taken, rng, Vector2i(rng.randi_range(2, 3), 1), K.LOW_WALL, 1, "barricade", 1, Vector2i(7, 15))
	for i in rng.randi_range(2, 4):
		_place(map, data, taken, rng, Vector2i.ONE, K.ROCK, 1, "rock", 1, Vector2i(6, 15))
