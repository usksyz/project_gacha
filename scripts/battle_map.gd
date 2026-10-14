class_name BattleMap
extends RefCounted
## Le champ de bataille « 3D sur grille » (cahier, onglet « Combat v2 », sections 0 et 2 ; étape C1).
## Chaque case a une hauteur (0 à MAX_HEIGHT niveaux : rue, rocher ou muret, mur, toit, tour) et un type
## (sol, obstacle, toit, échelle, escalier...). La simulation (battle.gd) s'en sert pour savoir où l'on peut
## marcher, et à quelle hauteur se tient chacun ; l'écran (battle_view.gd) ne fait que la montrer.
## Ajout du projet : les types de cases et leurs hauteurs sont un choix de mise en œuvre du cahier.

## Types de cases.
## GROUND : sol (rue, herbe rase) ; BLOCK : obstacle infranchissable (arbre, puits, mur haut, maison fermée) ;
## ROOF : toit (on marche dessus) ; LADDER : case avec une échelle (on monte ou descend jusqu'à 3 niveaux) ;
## STAIRS : escalier ou rampe (on change d'un niveau à vitesse normale) ; LOW_WALL : muret, clôture (1 niveau,
## on l'enjambe en escaladant ; il couvre des tirs) ; RAMPART : chemin de ronde d'un rempart ; GATE : porte ;
## GRASS : herbes hautes (plus tard : elles raccourcissent la vue) ; TOWER : sommet d'une tour, d'un clocher ;
## ROCK : rocher (on l'escalade s'il ne fait qu'un niveau de plus).
enum Kind {GROUND, BLOCK, ROOF, LADDER, STAIRS, LOW_WALL, RAMPART, GATE, GRASS, TOWER, ROCK}

const KIND_NAMES := {
	Kind.GROUND: "sol", Kind.BLOCK: "obstacle", Kind.ROOF: "toit", Kind.LADDER: "échelle", Kind.STAIRS: "escalier",
	Kind.LOW_WALL: "muret", Kind.RAMPART: "rempart", Kind.GATE: "porte", Kind.GRASS: "herbes hautes",
	Kind.TOWER: "tour", Kind.ROCK: "rocher",
}

## Hauteur la plus haute d'une case (tour, clocher).
const MAX_HEIGHT := 4

## Passage d'une case à sa voisine (cahier, « Combat v2 », section 2) :
## WALK : même hauteur ; STAIRS : escalier ou rampe, un niveau, presque à vitesse normale ; CLIMB : escalade
## d'un niveau sans aide (très lent) ; LADDER : échelle, jusqu'à LADDER_MAX_LEVELS niveaux (lent) ; DROP :
## sauter d'un niveau (sans risque) ; JUMP : sauter de deux niveaux (dégâts légers, on ne remonte pas par là).
## Plus haut sans échelle : impossible (il faudra une compétence). Trois niveaux et plus vers le bas : seulement
## en tombant (poussé), et c'est une blessure grave.
enum Link {NONE, WALK, STAIRS, CLIMB, LADDER, DROP, JUMP}
const LADDER_MAX_LEVELS := 3

## Pour la recherche de chemin : un niveau de hauteur « compte » comme VERTICAL_COST cases de marche.
const VERTICAL_COST := 1.5
## Ligne de vue : hauteur des yeux et du milieu du corps au-dessus de la case (en niveaux).
const EYE_HEIGHT := 0.8
const BODY_HEIGHT := 0.5

## Les 8 directions (les 4 premières : côtés ; les 4 dernières : diagonales).
const DIRECTIONS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]

var size := Vector2i.ZERO
var heights := PackedInt32Array()
var kinds := PackedInt32Array()

## Les deux camps (graphes et coûts des chemins : voir build_graph, set_cost).
const SIDE_HEROES := 0
const SIDE_ENEMIES := 1
## Coût de base d'une case pour la recherche de chemin (cahier : « coût selon la pente, les échelles ») : on
## monte sur un muret ou un rocher en escaladant (4 fois plus lent que marcher) : on le contourne plutôt ;
## les autres : 1. La foule et le danger s'y ajoutent pendant le combat (voir Battle._refresh_costs).
const TERRAIN_COSTS := {Kind.STAIRS: 1.15, Kind.LADDER: 2.0, Kind.GRASS: 1.05, Kind.LOW_WALL: 3.0, Kind.ROCK: 2.0}
## Champs de flux : précision de la file par seaux (seaux par unité de coût).
const FLOW_BUCKETS := 4.0

## Graphes des chemins, un par camp (cases où l'on se tient, passages permis ; voir build_graph).
var _graphs: Array[AStar3D] = [AStar3D.new(), AStar3D.new()]
## Coût de chaque case : de base (terrain), puis pour chaque camp (base + foule + danger).
var base_costs := PackedFloat32Array()
var costs: Array[PackedFloat32Array] = []
## Liens entre cases (indices) et leurs longueurs, vers l'avant et vers l'arrière (champs de flux).
var out_links: Array[PackedInt32Array] = []
var out_lengths: Array[PackedFloat32Array] = []
var in_links: Array[PackedInt32Array] = []
var in_lengths: Array[PackedFloat32Array] = []


func _init(width := 0, length := 0) -> void:
	if width > 0:
		setup(width, length)


## Une carte plate et vide (que du sol à la hauteur 0).
func setup(width: int, length: int) -> void:
	size = Vector2i(width, length)
	heights = PackedInt32Array()
	heights.resize(width * length)
	heights.fill(0)
	kinds = PackedInt32Array()
	kinds.resize(width * length)
	kinds.fill(Kind.GROUND)


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func index(cell: Vector2i) -> int:
	return cell.y * size.x + cell.x


func cell_at(i: int) -> Vector2i:
	return Vector2i(i % size.x, i / size.x)


## Hauteur de la case (0 hors de la carte).
func height_at(cell: Vector2i) -> int:
	return heights[index(cell)] if in_bounds(cell) else 0


func kind_at(cell: Vector2i) -> int:
	return kinds[index(cell)] if in_bounds(cell) else Kind.BLOCK


## Peut-on s'y tenir ? (Dans la carte, et pas un obstacle.)
func walkable(cell: Vector2i) -> bool:
	return in_bounds(cell) and kinds[index(cell)] != Kind.BLOCK


## Le centre d'une case (en cases, comme les positions des combattants).
static func center(cell: Vector2i) -> Vector2:
	return Vector2(cell) + Vector2(0.5, 0.5)


## La case où se trouve une position.
func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(clampi(floori(pos.x), 0, size.x - 1), clampi(floori(pos.y), 0, size.y - 1))


## Comment passe-t-on de la case « a » à sa voisine « b » ? (Voir Link.)
func link(a: Vector2i, b: Vector2i) -> int:
	if not walkable(a) or not walkable(b):
		return Link.NONE
	var dh := height_at(b) - height_at(a)
	if dh == 0:
		return Link.WALK
	var ka := kind_at(a)
	var kb := kind_at(b)
	if (ka == Kind.LADDER or kb == Kind.LADDER) and absi(dh) <= LADDER_MAX_LEVELS:
		return Link.LADDER
	if absi(dh) == 1 and (ka == Kind.STAIRS or kb == Kind.STAIRS):
		return Link.STAIRS
	if dh == 1:
		return Link.CLIMB
	if dh == -1:
		return Link.DROP
	if dh == -2:
		return Link.JUMP
	return Link.NONE


## Peut-on aller de « a » à la case voisine « b » en un pas (diagonale comprise) ? En diagonale : seulement à
## plat, et sans couper le coin d'une case où l'on ne passe pas à plat.
func step_link(a: Vector2i, b: Vector2i) -> int:
	var d := b - a
	if absi(d.x) + absi(d.y) <= 1:
		return link(a, b)
	if link(a, b) != Link.WALK or link(a, Vector2i(b.x, a.y)) != Link.WALK or link(a, Vector2i(a.x, b.y)) != Link.WALK:
		return Link.NONE
	return Link.WALK


## Construit les graphes des chemins (à appeler une fois la carte finie). Chaque case où l'on se tient est un
## point, placé à sa hauteur (un niveau compte VERTICAL_COST cases) ; chaque passage permis, un lien à sens
## unique (on saute d'un toit, on n'y remonte pas sans échelle). Un graphe par camp (SIDE_HEROES,
## SIDE_ENEMIES) : mêmes passages, mais chaque camp a ses coûts (le danger des tirs ennemis, voir set_cost).
## Garde aussi les liens et leurs longueurs pour les champs de flux (flow_field).
func build_graph() -> void:
	var count := heights.size()
	base_costs = PackedFloat32Array()
	base_costs.resize(count)
	out_links.clear()
	out_lengths.clear()
	in_links.clear()
	in_lengths.clear()
	for i in count:
		out_links.append(PackedInt32Array())
		out_lengths.append(PackedFloat32Array())
		in_links.append(PackedInt32Array())
		in_lengths.append(PackedFloat32Array())
		base_costs[i] = TERRAIN_COSTS.get(kinds[i], 1.0)
	costs.clear()
	for side in 2:
		var graph := _graphs[side]
		graph.clear()
		costs.append(base_costs.duplicate())
		for i in count:
			var cell := cell_at(i)
			if walkable(cell):
				graph.add_point(i, _point(i), base_costs[i])
	for i in count:
		var cell := cell_at(i)
		if not walkable(cell):
			continue
		for d in DIRECTIONS:
			var next: Vector2i = cell + d
			if in_bounds(next) and step_link(cell, next) != Link.NONE:
				var j := index(next)
				var length := _point(i).distance_to(_point(j))
				for graph in _graphs:
					graph.connect_points(i, j, false)
				out_links[i].append(j)
				out_lengths[i].append(length)
				in_links[j].append(i)
				in_lengths[j].append(length)


func _point(i: int) -> Vector3:
	var cell := cell_at(i)
	return Vector3(cell.x + 0.5, heights[i] * VERTICAL_COST, cell.y + 0.5)


## Coût d'entrée dans une case pour la recherche de chemin d'un camp (1 = normal ; plus : pente, foule,
## danger...). Ne change rien si le coût est le même.
func set_cost(cell: Vector2i, cost: float, side: int) -> void:
	var i := index(cell)
	if costs[side][i] == cost or not _graphs[side].has_point(i):
		return
	costs[side][i] = cost
	_graphs[side].set_point_weight_scale(i, cost)


## Le chemin de « from » à « to » pour un camp : centres des cases à traverser (sans la case de départ). Si
## « to » est inaccessible, le chemin va au plus près. Vide si l'on est déjà dans la case d'arrivée.
func find_path(from: Vector2i, to: Vector2i, side := SIDE_HEROES) -> PackedVector2Array:
	var path := PackedVector2Array()
	from = nearest_walkable(from)
	to = nearest_walkable(to)
	if from == to:
		return path
	var ids := _graphs[side].get_id_path(index(from), index(to), true)
	for k in range(1, ids.size()):
		path.append(center(cell_at(ids[k])))
	return path


## Champ de flux (cahier, « Combat v2 », section 3) : pour chaque case, le coût du chemin le plus court
## jusqu'à l'une des cases « goals », avec les coûts du camp « side » (INF : on ne peut pas y aller). Un seul
## calcul sert à toute une horde (voir flow_step). Parcours de Dijkstra à l'envers, file par seaux.
func flow_field(goals: Array, side: int) -> PackedFloat32Array:
	var dist := PackedFloat32Array()
	dist.resize(heights.size())
	dist.fill(INF)
	var buckets := {}
	for goal in goals:
		if walkable(goal):
			dist[index(goal)] = 0.0
			if not buckets.has(0):
				buckets[0] = PackedInt32Array()
			buckets[0].append(index(goal))
	var side_costs: PackedFloat32Array = costs[side]
	var bucket := 0
	var last := 0
	while bucket <= last:
		if buckets.has(bucket):
			var list: PackedInt32Array = buckets[bucket]
			var k := 0
			while k < list.size():
				var c: int = list[k]
				k += 1
				var dc := dist[c]
				if int(dc * FLOW_BUCKETS) != bucket:
					continue  # déjà vue plus près
				var links: PackedInt32Array = in_links[c]
				var lengths: PackedFloat32Array = in_lengths[c]
				for n in links.size():
					var m: int = links[n]
					var nd := dc + lengths[n] * side_costs[c]
					if nd < dist[m]:
						dist[m] = nd
						var b := int(nd * FLOW_BUCKETS)
						if not buckets.has(b):
							buckets[b] = PackedInt32Array()
						buckets[b].append(m)
						last = maxi(last, b)
						if b == bucket:
							list = buckets[bucket]
			buckets.erase(bucket)
		bucket += 1
	return dist


## Le pas suivant dans un champ de flux : la case voisine de « from » qui rapproche le plus du but (coût du
## pas compris), sauf celles de « avoid » ({indice: vrai}, cases prises). Vector2i(-1, -1) s'il n'y en a pas
## qui rapproche.
func flow_step(dist: PackedFloat32Array, from: Vector2i, side: int, avoid := {}) -> Vector2i:
	var i := index(nearest_walkable(from))
	var best := -1
	var best_cost := INF
	var links: PackedInt32Array = out_links[i]
	var lengths: PackedFloat32Array = out_lengths[i]
	for n in links.size():
		var j: int = links[n]
		if avoid.has(j) or dist[j] >= dist[i]:
			continue
		var cost: float = lengths[n] * costs[side][j] + dist[j]
		if cost < best_cost:
			best = j
			best_cost = cost
	return cell_at(best) if best >= 0 else Vector2i(-1, -1)


## La case où l'on peut se tenir la plus proche (elle-même si c'est possible).
func nearest_walkable(cell: Vector2i) -> Vector2i:
	cell = Vector2i(clampi(cell.x, 0, size.x - 1), clampi(cell.y, 0, size.y - 1))
	if walkable(cell):
		return cell
	for radius in range(1, maxi(size.x, size.y)):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var c := cell + Vector2i(dx, dy)
				if walkable(c):
					return c
	return cell


## Peut-on aller de « from » à « to » à pied (en passant par les échelles, les escaliers, les sauts) ?
## (Parcours en largeur, pour vérifier une carte pendant qu'on la fabrique.)
func connected(from: Vector2i, to: Vector2i) -> bool:
	if not walkable(from) or not walkable(to):
		return false
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		if cell == to:
			return true
		for d in DIRECTIONS.slice(0, 4):
			var next: Vector2i = cell + d
			if not seen.has(next) and link(cell, next) != Link.NONE:
				seen[next] = true
				queue.append(next)
	return false


## Toutes les cases que l'on peut atteindre à pied depuis l'une des cases « from » : {case: vrai}.
func reachable(from: Array) -> Dictionary:
	var seen := {}
	var queue: Array[Vector2i] = []
	for cell in from:
		if walkable(cell) and not seen.has(cell):
			seen[cell] = true
			queue.append(cell)
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for d in DIRECTIONS.slice(0, 4):
			var next: Vector2i = cell + d
			if not seen.has(next) and link(cell, next) != Link.NONE:
				seen[next] = true
				queue.append(next)
	return seen


## La carte en donnée (pour la sauvegarde : voir MapGenerator).
func to_data() -> Dictionary:
	return {"size": size, "heights": heights.duplicate(), "kinds": kinds.duplicate()}


## Reprend une carte enregistrée (voir to_data). Le graphe des chemins est reconstruit.
func from_data(data: Dictionary) -> void:
	size = data["size"]
	heights = PackedInt32Array(data["heights"])
	kinds = PackedInt32Array(data["kinds"])
	build_graph()


## Ligne de vue en 3D (cahier : « un mur cache ce qui est derrière, sauf pour qui est plus haut que lui ») :
## des yeux de celui qui regarde (EYE_HEIGHT au-dessus de sa case) au milieu du corps de la cible
## (BODY_HEIGHT), rien ne doit dépasser la ligne. Un obstacle compte à sa hauteur (au moins 1 niveau).
func line_of_sight(from: Vector2, from_height: float, to: Vector2, to_height: float) -> bool:
	var start_cell := cell_of(from)
	var end_cell := cell_of(to)
	var eye := from_height + EYE_HEIGHT
	var body := to_height + BODY_HEIGHT
	var steps := int(from.distance_to(to) / 0.3) + 1
	for i in range(1, steps):
		var t := float(i) / steps
		var cell := cell_of(from.lerp(to, t))
		if cell == start_cell or cell == end_cell:
			continue
		var top := height_at(cell)
		if kind_at(cell) == Kind.BLOCK:
			top = maxi(top, 1)
		if top > lerpf(eye, body, t):
			return false
	return true


## Remplit un rectangle de cases (type et hauteur).
func fill(rect: Rect2i, kind: int, height: int) -> void:
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var cell := Vector2i(x, y)
			if in_bounds(cell):
				kinds[index(cell)] = kind
				heights[index(cell)] = clampi(height, 0, MAX_HEIGHT)
