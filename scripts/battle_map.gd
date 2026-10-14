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

var size := Vector2i.ZERO
var heights := PackedInt32Array()
var kinds := PackedInt32Array()


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


## Remplit un rectangle de cases (type et hauteur).
func fill(rect: Rect2i, kind: int, height: int) -> void:
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var cell := Vector2i(x, y)
			if in_bounds(cell):
				kinds[index(cell)] = kind
				heights[index(cell)] = clampi(height, 0, MAX_HEIGHT)
