class_name FloorPreview
extends Control
## Aperçu d'un étage déjà visité (prompt 3, point 1) : la carte figée de l'étage (GameData.floor_layout) vue de
## dessus, en petit, avec la zone de départ des héros (cadre vert) et la place de départ des ennemis que les
## héros ont déjà vus (points rouges). Les couleurs des cases sont celles de la vue de dessus du combat
## (BattleView.KIND_COLORS). Rien n'est touché : c'est un dessin.

const CELL := 16.0
const ZONE_COLOR := Color(0.35, 0.85, 0.45, 0.9)
const ENEMY_DOT := Color("e05252")

var map := BattleMap.new()
var hero_rows: Array = []
## Cases de départ des ennemis déjà vus (Vector2i).
var enemy_starts: Array = []
## Carte ronde (cartes, étape 2 : format 2 et plus).
var round_map := false


## « map_data » : la carte (floor_layout(...)["map"]) ; « starts » : les cases de départ à montrer.
func setup(map_data: Dictionary, starts: Array) -> void:
	map.from_data(map_data)
	hero_rows = map_data.get("hero_rows", [])
	round_map = map_data.get("version", 1) >= 2
	enemy_starts = starts
	custom_minimum_size = Vector2(map.size.x, map.size.y) * CELL
	queue_redraw()


func _draw() -> void:
	for i in map.heights.size():
		var cell := map.cell_at(i)
		if round_map and not MapGenerator.inside(cell):
			continue  # (cartes, étape 2 : la lisière, hors du disque, n'est pas dessinée)
		var height := map.height_at(cell)
		var color: Color = BattleView.KIND_COLORS.get(map.kind_at(cell), BattleView.GROUND_COLOR) \
			.lightened(height * BattleView.HEIGHT_LIGHTEN)
		draw_rect(Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL) - Vector2.ONE), color)
	if hero_rows.size() >= 2:
		var top: int = mini(hero_rows[0], hero_rows[1])
		var bottom: int = maxi(hero_rows[0], hero_rows[1])
		draw_rect(Rect2(Vector2(0, top) * CELL, Vector2(map.size.x, bottom - top + 1) * CELL), ZONE_COLOR, false, 2.0)
	for start in enemy_starts:
		draw_circle((Vector2(start) + Vector2(0.5, 0.5)) * CELL, CELL * 0.35, ENEMY_DOT)
