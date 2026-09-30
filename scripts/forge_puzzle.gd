class_name ForgePuzzle
extends Control
## Mini-jeu de la forge (cahier des charges) : l'écran montre la silhouette de l'objet sur une grille.
## Le joueur y place des fragments de métal (pièces de formes variées, comme au Tetris) pour remplir
## exactement la silhouette avant la fin du temps.
## - on touche une pièce en bas pour la choisir, « Tourner » la fait pivoter, puis on touche la grille :
##   la case marquée d'un point sur la pièce va là où on touche ;
## - toucher une pièce déjà posée la retire ;
## - une case remplie hors de la silhouette, une pièce retirée ou une case d'impureté touchée
##   comptent comme des erreurs.
## Résultat : échec (temps écoulé), succès, grand succès (plus de 30 % du temps restant),
## succès phénoménal (sans erreur, plus de 50 % du temps restant).
## Les difficultés et les malus sont dans GameData (FORGE_DIFFICULTIES, section « Forge »).

## Fin du puzzle : réussi ou non, crans de bonus gagnés, et nom du résultat.
signal finished(success: bool, bonus: int, result_name: String)

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Couleurs des pièces posées.
const PIECE_COLORS := [Color("e0873d"), Color("d9c24a"), Color("5fb86a"), Color("4aa3d9"),
	Color("9b6be0"), Color("e05c8a"), Color("c9cbd6"), Color("3dc9b0")]

# --- Réglages de la partie (voir setup) ---
var grid_size := 5
var settings: Dictionary = {}
var total_time := 180.0
var has_plan := false

# --- État ---
## Cases de la silhouette (ensemble : case -> true), et cases d'impureté.
var silhouette := {}
var impurities := {}
## Pièces : {"shape": [Vector2i] (forme actuelle, coin en haut à gauche en (0, 0)),
## "cells": [Vector2i] (cases occupées si posée, sinon vide), "locked": posée d'office par l'artisan}.
var pieces: Array = []
## Case -> numéro de la pièce qui l'occupe.
var occupied := {}
var selected := -1
var errors := 0
var time_left := 180.0
var elapsed := 0.0
## Vrai quand le puzzle est fini (et avant qu'il soit prêt) : le temps ne tourne plus.
var done := true

# --- Interface ---
var board: Board
var tray: HFlowContainer
var timer_label: Label
var info_label: Label
var rotate_button: Button


## Prépare un puzzle. « difficulty » : une clé de GameData.FORGE_DIFFICULTIES ;
## « maluses » : les malus de GameData.forge_maluses ; « title » : ce qu'on forge.
func setup(difficulty: String, maluses: Array, title: String) -> void:
	settings = GameData.FORGE_DIFFICULTIES[difficulty]
	grid_size = settings["grid"]
	has_plan = not "plan" in maluses
	total_time = GameData.FORGE_TIME - (GameData.INFRA_TIME_MALUS if "infra" in maluses else 0)
	time_left = total_time
	var extra_impurities := GameData.NO_ARTISAN_IMPURITIES if "artisan" in maluses else 0
	while not _generate():
		pass
	_add_impurities(settings["impurities"] + extra_impurities)
	# Artisan présent : une pièce est placée d'office.
	if not "artisan" in maluses:
		_place(0, pieces[0]["solution"])
		pieces[0]["locked"] = true
	_build_ui(title, difficulty)
	_refresh_tray()
	done = false  # c'est parti : le temps tourne


# ---------------------------------------------------------------------------
# Fabrication du puzzle
# ---------------------------------------------------------------------------

## Fait pousser la silhouette pièce par pièce, en partant du centre : chaque pièce part d'une case
## voisine de celles déjà prises. Comme la silhouette est faite des pièces elles-mêmes, le puzzle
## a toujours au moins une solution. Renvoie faux si ça a coincé (on recommence alors).
func _generate() -> bool:
	silhouette.clear()
	pieces.clear()
	var sizes: Array = settings["sizes"]
	for p in settings["pieces"]:
		var start := Vector2i(grid_size / 2, grid_size / 2)
		if p > 0:
			var frontier := _free_neighbours(silhouette.keys())
			if frontier.is_empty():
				return false
			start = frontier.pick_random()
		var cells: Array = [start]
		silhouette[start] = true
		var target := randi_range(sizes[0], sizes[1])
		while cells.size() < target:
			var options := _free_neighbours(cells)
			if options.is_empty():
				break
			var cell: Vector2i = options.pick_random()
			cells.append(cell)
			silhouette[cell] = true
		if cells.size() < 2:
			return false
		var shape := _normalize(cells)
		if settings["rotation"]:
			for i in randi_range(0, 3):  # la pièce est donnée tournée : au joueur de la remettre
				shape = _rotate(shape)
		pieces.append({"shape": shape, "cells": [], "solution": cells, "locked": false})
	return true


## Cases libres (dans la grille, hors silhouette) voisines d'une liste de cases.
func _free_neighbours(cells: Array) -> Array:
	var result := []
	for cell in cells:
		for dir in DIRS:
			var next: Vector2i = cell + dir
			if _inside(next) and not silhouette.has(next) and not next in result:
				result.append(next)
	return result


## Cases d'impureté : prises de préférence juste à côté de la silhouette, pour gêner.
func _add_impurities(count: int) -> void:
	var candidates := _free_neighbours(silhouette.keys())
	candidates.shuffle()
	for i in mini(count, candidates.size()):
		impurities[candidates[i]] = true


func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size and cell.y < grid_size


## Ramène une forme dans le coin en haut à gauche (plus petites coordonnées à 0).
static func _normalize(cells: Array) -> Array:
	var low := Vector2i(1000, 1000)
	for cell in cells:
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
	return cells.map(func(cell): return cell - low)


## Tourne une forme d'un quart de tour.
static func _rotate(shape: Array) -> Array:
	return _normalize(shape.map(func(cell): return Vector2i(-cell.y, cell.x)))


## La case « poignée » d'une forme (marquée d'un point) : la plus haute, puis la plus à gauche.
static func anchor_of(shape: Array) -> Vector2i:
	var best: Vector2i = shape[0]
	for cell in shape:
		if cell.y < best.y or (cell.y == best.y and cell.x < best.x):
			best = cell
	return best


# ---------------------------------------------------------------------------
# Jeu
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if done:
		return
	time_left -= delta
	elapsed += delta
	if time_left <= 0.0:
		time_left = 0.0
		_finish(false)
	timer_label.text = "Temps : %d:%02d   Erreurs : %d" % [int(time_left) / 60, int(time_left) % 60, errors]
	board.queue_redraw()


## Le joueur a touché une case de la grille.
func on_cell_pressed(cell: Vector2i) -> void:
	if done:
		return
	# Toucher une pièce posée la retire (sauf celle posée d'office par l'artisan) : c'est une erreur.
	if occupied.has(cell):
		var index: int = occupied[cell]
		if pieces[index]["locked"]:
			info_label.text = "Cette pièce a été posée par l'artisan."
			return
		for c in pieces[index]["cells"]:
			occupied.erase(c)
		pieces[index]["cells"] = []
		errors += 1
		info_label.text = "Pièce retirée : une erreur de plus."
		_refresh_tray()
		return
	if selected < 0:
		info_label.text = "Choisis d'abord une pièce en bas."
		return
	var shape: Array = pieces[selected]["shape"]
	var offset: Vector2i = cell - anchor_of(shape)
	var cells: Array = shape.map(func(c): return c + offset)
	for c in cells:
		if not _inside(c) or occupied.has(c):
			info_label.text = "La pièce ne tient pas ici."
			return
		if impurities.has(c):
			errors += 1
			info_label.text = "Case d'impureté ! Une erreur de plus."
			return
	_place(selected, cells)
	if cells.any(func(c): return not silhouette.has(c)):
		errors += 1
		info_label.text = "Hors de la silhouette : une erreur de plus. Touche la pièce pour la retirer."
	else:
		info_label.text = ""
	selected = -1
	_refresh_tray()
	if _complete():
		_finish(true)


func _place(index: int, cells: Array) -> void:
	pieces[index]["cells"] = cells
	for c in cells:
		occupied[c] = index


## La silhouette est remplie exactement : toutes ses cases couvertes, et rien en dehors.
func _complete() -> bool:
	for cell in silhouette:
		if not occupied.has(cell):
			return false
	for cell in occupied:
		if not silhouette.has(cell):
			return false
	return true


func _rotate_selected() -> void:
	if selected >= 0 and settings["rotation"]:
		pieces[selected]["shape"] = _rotate(pieces[selected]["shape"])
		_refresh_tray()


func _finish(success: bool) -> void:
	done = true
	var bonus := 0
	var result_name := "Échec"
	if success:
		var ratio := time_left / total_time
		result_name = "Succès"
		if errors == 0 and ratio > 0.5:
			result_name = "Succès phénoménal"
			bonus = settings["bonus"]
		elif ratio > 0.3:
			result_name = "Grand succès"
			bonus = settings["bonus"] / 2
	board.queue_redraw()
	finished.emit(success, bonus, result_name)


## Vrai si la silhouette est visible (en Démoniaque, elle s'efface au bout de quelques secondes).
func silhouette_visible() -> bool:
	return settings["fade"] <= 0.0 or elapsed < settings["fade"]


# ---------------------------------------------------------------------------
# Interface
# ---------------------------------------------------------------------------

func _build_ui(title: String, difficulty: String) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("15121f")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	layout.add_child(UI.make_label("%s — %s" % [title, difficulty], 26))
	timer_label = UI.make_label("", 24)
	timer_label.add_theme_color_override("font_color", Color("f5b82e"))
	layout.add_child(timer_label)

	var center := CenterContainer.new()
	layout.add_child(center)
	board = Board.new()
	board.puzzle = self
	board.custom_minimum_size = Vector2(560, 560)
	center.add_child(board)

	info_label = UI.make_label("Remplis exactement la silhouette.", 20)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(info_label)

	var scroll := UI.make_scroll()
	layout.add_child(scroll)
	tray = HFlowContainer.new()
	tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tray.add_theme_constant_override("h_separation", 8)
	tray.add_theme_constant_override("v_separation", 8)
	scroll.add_child(tray)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	layout.add_child(buttons)
	rotate_button = UI.make_button("Tourner", _rotate_selected, 24)
	rotate_button.visible = settings["rotation"]
	var give_up := UI.make_button("Abandonner", func():
		if not done:
			_finish(false), 24)
	for button in [rotate_button, give_up]:
		button.custom_minimum_size.y = 80
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(button)


## Les pièces à poser, en bas. En Infernal et Démoniaque, elles sont révélées une par une.
func _refresh_tray() -> void:
	for child in tray.get_children():
		tray.remove_child(child)
		child.queue_free()
	var shown := 0
	for index in pieces.size():
		if not pieces[index]["cells"].is_empty():
			continue
		if settings["reveal"] and shown >= 1:
			break
		shown += 1
		var button := Button.new()
		button.custom_minimum_size = Vector2(120, 120)
		var color: Color = PIECE_COLORS[index % PIECE_COLORS.size()]
		var border := Color.WHITE if index == selected else color.darkened(0.3)
		UI.set_button_style(button, UI.make_panel_style(Color("262a3b"), border, 4 if index == selected else 2),
			UI.make_panel_style(Color("363b52"), border, 4))
		button.pressed.connect(func():
			selected = index
			_refresh_tray.call_deferred())
		var icon := PieceIcon.new()
		icon.shape = pieces[index]["shape"]
		icon.color = color
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		tray.add_child(button)
	if settings["reveal"] and shown == 1 and selected < 0:
		for index in pieces.size():
			if pieces[index]["cells"].is_empty():
				selected = index  # une seule pièce révélée : elle est choisie d'office
				break
		_refresh_tray.call_deferred()
	rotate_button.disabled = selected < 0


## La grille : silhouette (nette avec un plan, en pointillés sans), impuretés, pièces posées.
class Board extends Control:
	var puzzle: ForgePuzzle

	func _cell_size() -> float:
		return minf(size.x, size.y) / puzzle.grid_size

	func _gui_input(event: InputEvent) -> void:
		# Un doigt sur l'écran arrive aussi comme un clic de souris (Godot le convertit).
		var click := event as InputEventMouseButton
		if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			var cell := Vector2i(floori(click.position.x / _cell_size()), floori(click.position.y / _cell_size()))
			if puzzle._inside(cell):
				puzzle.on_cell_pressed(cell)
			accept_event()

	func _draw() -> void:
		var s := _cell_size()
		var n := puzzle.grid_size
		draw_rect(Rect2(Vector2.ZERO, Vector2(s * n, s * n)), Color("1b1d2a"))
		for x in n:
			for y in n:
				var cell := Vector2i(x, y)
				var rect := Rect2(Vector2(x, y) * s, Vector2(s, s)).grow(-2)
				if puzzle.silhouette.has(cell) and puzzle.silhouette_visible():
					if puzzle.has_plan:
						draw_rect(rect, Color(0.36, 0.83, 0.77, 0.35))
					else:
						draw_circle(rect.get_center(), s * 0.08, Color(0.36, 0.83, 0.77, 0.8))
				if puzzle.impurities.has(cell):
					draw_rect(rect, Color(0.8, 0.2, 0.2, 0.5))
					draw_line(rect.position, rect.end, Color("e05252"), 3)
					draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), Color("e05252"), 3)
				if puzzle.occupied.has(cell):
					var index: int = puzzle.occupied[cell]
					var color: Color = ForgePuzzle.PIECE_COLORS[index % ForgePuzzle.PIECE_COLORS.size()]
					draw_rect(rect, color if puzzle.silhouette.has(cell) else color.darkened(0.5))
				draw_rect(Rect2(Vector2(x, y) * s, Vector2(s, s)), Color(1, 1, 1, 0.08), false, 1)


## Petite image d'une pièce dans la réserve ; la case « poignée » porte un point.
class PieceIcon extends Control:
	var shape: Array = []
	var color := Color.WHITE

	func _draw() -> void:
		var width := 1
		var height := 1
		for cell in shape:
			width = maxi(width, cell.x + 1)
			height = maxi(height, cell.y + 1)
		var s := minf((size.x - 16) / width, (size.y - 16) / height)
		s = minf(s, 24.0)
		var origin := (size - Vector2(width, height) * s) / 2
		for cell in shape:
			draw_rect(Rect2(origin + Vector2(cell) * s, Vector2(s, s)).grow(-1), color)
		var anchor := ForgePuzzle.anchor_of(shape)
		draw_circle(origin + (Vector2(anchor) + Vector2(0.5, 0.5)) * s, s * 0.18, Color.BLACK)
