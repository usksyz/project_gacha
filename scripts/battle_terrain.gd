class_name BattleTerrain
extends RefCounted
## L'annotation tactique des cartes (recensement « Techniques de programmation pour le combat », point 4 ; ajout du
## projet). Une fois par combat, juste après la construction de la carte, chaque case est lue comme le ferait un
## éclaireur :
## - un goulet (« choke ») : un passage d'une case de large, bordé des deux côtés (maisons, rochers, murets, relief
##   qu'on ne franchit pas d'un pas) ; un piège y est imparable ;
## - un point haut (« high ») : une case en hauteur qui domine ses voisines (au moins HIGH_MIN_LOWER plus basses) ;
## - une cachette (« hide ») : des herbes hautes, ou une case au sol collée à un obstacle plus haut que la tête (on s'y
##   tapit contre le mur).
## Ce que le combat en fait : un poseur de pièges choisit un goulet sur le chemin des monstres (BattleExplore._trap_cell),
## l'équipe se rallie à couvert (BattleExplore.stalk). Aucun tirage au hasard. Chiffres dans GameData (tower.gd, après
## SNEAK_EXPOSURE_MAX).

var map: BattleMap
var choke := PackedByteArray()
var high := PackedByteArray()
var hide := PackedByteArray()


func _init(battle_map: BattleMap) -> void:
	map = battle_map
	var count := map.heights.size()
	choke.resize(count)
	high.resize(count)
	hide.resize(count)
	choke.fill(0)
	high.fill(0)
	hide.fill(0)
	for i in count:
		var cell := map.cell_at(i)
		if not map.walkable(cell) or map.kind_at(cell) == BattleMap.Kind.LADDER:
			continue
		var open := []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			open.append(map.link(cell, cell + d) != BattleMap.Link.NONE)
		# Goulet : ouvert d'un côté à l'autre, fermé sur les deux flancs.
		if (open[0] and open[1] and not open[2] and not open[3]) or (open[2] and open[3] and not open[0] and not open[1]):
			choke[i] = 1
		var h := map.height_at(cell)
		var lower := 0
		var wall := false
		for d in BattleMap.DIRECTIONS:
			var next: Vector2i = cell + d
			if not map.in_bounds(next):
				continue
			if map.height_at(next) < h:
				lower += 1
			if absi(d.x) + absi(d.y) == 1 and (map.kind_at(next) == BattleMap.Kind.BLOCK \
					or map.height_at(next) > h + BattleMap.EYE_HEIGHT):
				wall = true
		if h >= 1 and lower >= GameData.HIGH_MIN_LOWER:
			high[i] = 1
		if map.kind_at(cell) == BattleMap.Kind.GRASS or (h == 0 and wall):
			hide[i] = 1


func is_choke(cell: Vector2i) -> bool:
	return map.in_bounds(cell) and choke[map.index(cell)] == 1


func is_high(cell: Vector2i) -> bool:
	return map.in_bounds(cell) and high[map.index(cell)] == 1


func is_hide(cell: Vector2i) -> bool:
	return map.in_bounds(cell) and hide[map.index(cell)] == 1


## La case annotée la plus proche de « around » (« kind » : "choke", "high" ou "hide"), à moins de « radius » cases,
## où « accept » (Callable sur la case, facultatif) est vrai ; Vector2i(-1, -1) s'il n'y en a pas.
func nearest(kind: String, around: Vector2, radius: float, accept := Callable()) -> Vector2i:
	var marks: PackedByteArray = {"choke": choke, "high": high, "hide": hide}[kind]
	var best := Vector2i(-1, -1)
	var best_d := INF
	var here := map.cell_of(around)
	var r := ceili(radius)
	for y in range(maxi(0, here.y - r), mini(map.size.y, here.y + r + 1)):
		for x in range(maxi(0, here.x - r), mini(map.size.x, here.x + r + 1)):
			var cell := Vector2i(x, y)
			if marks[map.index(cell)] != 1:
				continue
			var d := BattleMap.center(cell).distance_to(around)
			if d > radius or d >= best_d:
				continue
			if accept.is_valid() and not accept.call(cell):
				continue
			best = cell
			best_d = d
	return best


## Les comptes, pour le mode dev et les mesures.
func summary() -> Dictionary:
	return {"goulets": choke.count(1), "points hauts": high.count(1), "cachettes": hide.count(1)}
