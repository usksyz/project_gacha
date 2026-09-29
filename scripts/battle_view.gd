class_name BattleView
extends Control
## Écran de combat, en direct et vu du dessus.
## En haut le titre et le chrono, au milieu le champ de bataille, en bas le journal et la pause.
## Pas d'accélération ni de « passer » : on vit le combat. On peut guider ses héros :
## toucher un héros pour le choisir, puis toucher un endroit pour l'y envoyer
## (se mettre à couvert, reculer, relayer un blessé), ou toucher un ennemi pour qu'il l'attaque.
## Le combat continue même si on change d'onglet ; on peut le mettre en pause
## (et donner des ordres pendant la pause).

signal closed

const HERO_COLOR := Color("4caf6a")
const ENEMY_COLOR := Color("e05252")
const ORDER_COLOR := Color("f5d142")
const GROUND_COLOR := Color("27301f")

## Couleur du décor, selon son genre.
const OBSTACLE_COLORS := {
	"rock": Color("5b5d66"),
	"wall": Color("6b5a48"),
	"house": Color("4a3b2e"),
	"rampart": Color("8a8f98"),
}

## Couleur des lignes spéciales du journal, selon leur « style » (voir Battle.events).
const STYLE_COLORS := {
	"bleed": Color("e07070"),      # saignement, hémorragie
	"awaken": Color("c9a2ff"),     # éveil des compétences
	"berserk": Color("ff4040"),    # mode Berserk
	"reinforce": Color("f5b82e"),  # renforts ennemis
}

## Durée d'affichage des coups (traits) et des chiffres qui s'envolent, en secondes de combat.
const STRIKE_TIME := 0.25
const FLOAT_TIME := 0.9

## Distance (en cases) à laquelle un toucher « attrape » un pion.
const TAP_RADIUS := 0.8

var battle: Battle
var layout: VBoxContainer
var title_label: Label
var clock_label: Label
var hint_label: Label
var arena: Control
var log_label: RichTextLabel
var controls: HBoxContainer
var pause_button: Button

var paused := false
## Temps accumulé depuis le dernier pas du combat (secondes).
var accumulator := 0.0
## Héros choisi pour recevoir un ordre (son numéro), ou -1.
var selected_id := -1
## Prochain événement du journal à afficher, et premier effet encore visible.
var next_event := 0
var first_effect := 0


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)


## Lance l'affichage d'un combat déjà préparé (battle.start() a été appelée).
func play(new_battle: Battle, title: String) -> void:
	battle = new_battle
	accumulator = 0.0
	next_event = 0
	first_effect = 0
	selected_id = -1
	paused = false
	_build(title)
	_update_hint()


func _build(title: String) -> void:
	for child in layout.get_children():
		layout.remove_child(child)
		child.queue_free()

	var header := HBoxContainer.new()
	layout.add_child(header)
	title_label = UI.make_label(title, 30)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	header.add_child(title_label)
	clock_label = UI.make_label("", 24)
	clock_label.add_theme_color_override("font_color", Color("f5b82e"))
	header.add_child(clock_label)

	hint_label = UI.make_label("", 20)
	hint_label.add_theme_color_override("font_color", ORDER_COLOR)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(hint_label)

	# Le champ de bataille : dessiné par _draw_arena, et on le touche pour donner des ordres.
	arena = Control.new()
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.draw.connect(_draw_arena)
	arena.gui_input.connect(_on_arena_input)
	layout.add_child(arena)

	# Journal : la dernière ligne reste toujours visible.
	log_label = RichTextLabel.new()
	log_label.custom_minimum_size.y = 140
	log_label.scroll_following = true
	log_label.get_v_scroll_bar().modulate.a = 0.0  # barre invisible : on fait défiler en glissant
	log_label.add_theme_font_size_override("normal_font_size", 18)
	log_label.add_theme_stylebox_override("normal", UI.make_panel_style(Color("12131c")))
	layout.add_child(log_label)

	controls = HBoxContainer.new()
	layout.add_child(controls)
	pause_button = UI.make_button("Pause", _toggle_pause, 26)
	pause_button.custom_minimum_size.y = 80
	pause_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(pause_button)


func _toggle_pause() -> void:
	paused = not paused
	pause_button.text = "Reprendre" if paused else "Pause"
	_update_hint()


## Le combat avance en direct, même si l'écran est caché (autre onglet), sauf en pause.
func _process(delta: float) -> void:
	if battle == null or battle.finished or paused:
		return
	accumulator += delta
	while accumulator >= Battle.TICK and not battle.finished:
		battle.step()
		accumulator -= Battle.TICK
	_advance()
	if battle.finished:
		_show_result(GameData.finish_tower_battle(battle))


## Met à jour le journal, le chrono et le dessin.
func _advance() -> void:
	while next_event < battle.events.size():
		_show_event(battle.events[next_event])
		next_event += 1
	if selected_id >= 0 and battle.units[selected_id]["hp"] <= 0:
		selected_id = -1  # le héros choisi est tombé
		_update_hint()
	_update_clock()
	arena.queue_redraw()


func _update_clock() -> void:
	var limit: float = battle.quest["seconds"]
	var text := ""
	if battle.quest["lasting"]:
		text = "Encore %s" % _format_time(limit - battle.time)
	else:
		text = "%s / %s" % [_format_time(battle.time), _format_time(limit)]
	if battle.quest["walls"] > 0:
		text += "   Remparts %d" % battle.walls
	clock_label.text = text


func _format_time(seconds: float) -> String:
	var total := maxi(0, ceili(seconds))
	return "%d:%02d" % [total / 60, total % 60]


func _show_event(event: Dictionary) -> void:
	var style: String = event["style"]
	if style in STYLE_COLORS:
		log_label.push_color(STYLE_COLORS[style])
		log_label.add_text(event["text"] + "\n")
		log_label.pop()
	else:
		log_label.add_text(event["text"] + "\n")
	if style == "berserk" or style == "awaken":
		Settings.vibrate(150)


# ---------------------------------------------------------------------------
# Ordres du joueur
# ---------------------------------------------------------------------------

func _update_hint() -> void:
	if selected_id >= 0:
		hint_label.text = "%s : touche un endroit pour l'y envoyer, ou un ennemi à attaquer." \
			% battle.units[selected_id]["name"]
	elif paused:
		hint_label.text = "Pause. Tu peux donner des ordres avant de reprendre."
	else:
		hint_label.text = "Touche un héros pour le guider."


func _on_arena_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if battle == null or battle.finished:
		return
	var map_pos: Vector2 = (event.position - _origin()) / _cell_size()
	var touched := _unit_at(map_pos)

	if not touched.is_empty() and touched["is_hero"]:
		# Choisir un héros (ou le relâcher en le touchant à nouveau).
		selected_id = -1 if selected_id == touched["id"] else touched["id"]
	elif selected_id >= 0:
		var hero: Dictionary = battle.units[selected_id]
		if not touched.is_empty():
			battle.order_attack(hero, touched)
		elif Rect2(0, 0, Battle.GRID_W, Battle.GRID_H).has_point(map_pos):
			battle.order_move(hero, map_pos)
		else:
			return
		Settings.vibrate(30)
		selected_id = -1
	_update_hint()
	arena.queue_redraw()


## Le combattant debout le plus proche du point touché (ou {} si personne n'est assez près).
func _unit_at(map_pos: Vector2) -> Dictionary:
	var result: Dictionary = {}
	var best := TAP_RADIUS
	for unit in battle.units:
		if not unit["present"] or unit["hp"] <= 0:
			continue
		var distance: float = unit["pos"].distance_to(map_pos)
		if distance < best:
			best = distance
			result = unit
	return result


# ---------------------------------------------------------------------------
# Dessin du champ de bataille
# ---------------------------------------------------------------------------

## Taille d'une case à l'écran, et coin haut-gauche de la carte (la carte est centrée).
func _cell_size() -> float:
	return minf(arena.size.x / Battle.GRID_W, arena.size.y / Battle.GRID_H)


func _origin() -> Vector2:
	return (arena.size - Vector2(Battle.GRID_W, Battle.GRID_H) * _cell_size()) / 2


## Position à l'écran d'un point de la carte (en cases).
func _to_screen(pos: Vector2) -> Vector2:
	return _origin() + pos * _cell_size()


func _draw_arena() -> void:
	if battle == null:
		return
	var cell := _cell_size()
	if cell < 4:
		return  # zone trop petite (écran en train de se fermer) : rien à dessiner
	var origin := _origin()
	arena.draw_rect(Rect2(origin, Vector2(Battle.GRID_W, Battle.GRID_H) * cell), GROUND_COLOR)

	for obstacle in battle.obstacles:
		var rect: Rect2i = obstacle["rect"]
		var screen_rect := Rect2(origin + Vector2(rect.position) * cell, Vector2(rect.size) * cell).grow(-1.5)
		arena.draw_rect(screen_rect, OBSTACLE_COLORS[obstacle["kind"]])

	# Entre deux pas du combat, les pions glissent de leur ancienne position à la nouvelle.
	var weight := clampf(accumulator / Battle.TICK, 0.0, 1.0)
	var positions := {}
	for unit in battle.units:
		if unit["present"]:
			positions[unit["id"]] = unit["prev_pos"].lerp(unit["pos"], weight)

	_draw_orders(positions, cell)
	for id in positions:
		_draw_unit(battle.units[id], _to_screen(positions[id]), cell)
	_draw_names(positions, cell)
	_draw_effects(positions, cell)


## Les ordres en cours : un trait jaune vers l'endroit ou l'ennemi visé.
func _draw_orders(positions: Dictionary, cell: float) -> void:
	for hero in battle.heroes:
		var order: Dictionary = hero["order"]
		if order.is_empty() or hero["hp"] <= 0 or not positions.has(hero["id"]):
			continue
		var from := _to_screen(positions[hero["id"]])
		if order["kind"] == "move":
			var to := _to_screen(order["pos"])
			arena.draw_dashed_line(from, to, Color(ORDER_COLOR, 0.7), 2.0, 8.0)
			arena.draw_arc(to, cell * 0.25, 0, TAU, 16, ORDER_COLOR, 2.0)
		elif positions.has(order["target"]):
			var to := _to_screen(positions[order["target"]])
			arena.draw_dashed_line(from, to, Color(ORDER_COLOR, 0.7), 2.0, 8.0)
			arena.draw_arc(to, cell * 0.55, 0, TAU, 20, ORDER_COLOR, 2.0)


func _draw_unit(unit: Dictionary, center: Vector2, cell: float) -> void:
	var font := ThemeDB.fallback_font
	var radius := cell * (0.5 if unit["boss"] else 0.36)
	if unit["hp"] <= 0:
		# Un ennemi vaincu disparaît ; un héros tombé reste, grisé.
		if unit["is_hero"]:
			arena.draw_circle(center, radius, Color(0.3, 0.3, 0.3, 0.6))
			arena.draw_string(font, center + Vector2(-radius, radius * 0.4), "x", HORIZONTAL_ALIGNMENT_CENTER,
				radius * 2, int(radius * 1.2), Color(0.8, 0.8, 0.8))
		return

	if unit["id"] == selected_id:  # héros choisi : un anneau jaune
		arena.draw_arc(center, radius + 6, 0, TAU, 24, ORDER_COLOR, 3.0)
	if unit["berserk"]:  # Berserk : un halo rouge
		arena.draw_circle(center, radius + 5, Color(1, 0.15, 0.15, 0.45))
	var fill := Color("7a2a2a")
	var outline := ENEMY_COLOR
	if unit["is_hero"]:
		fill = GameData.RARITY_COLORS[unit["rarity"]].darkened(0.35)
		outline = HERO_COLOR
	elif unit["boss"]:
		fill = Color("5a1f6e")
	arena.draw_circle(center, radius, fill)
	arena.draw_arc(center, radius, 0, TAU, 24, outline, 2.0)
	arena.draw_string(font, center + Vector2(-radius, radius * 0.45), unit["name"].left(1),
		HORIZONTAL_ALIGNMENT_CENTER, radius * 2, int(radius * 1.2), Color.WHITE)

	# Barre de vie au-dessus du pion.
	var bar_width := cell * 0.8
	var bar_pos := center + Vector2(-bar_width / 2, -radius - 7)
	arena.draw_rect(Rect2(bar_pos, Vector2(bar_width, 4)), Color("12131c"))
	arena.draw_rect(Rect2(bar_pos, Vector2(bar_width * clampf(float(unit["hp"]) / unit["max_hp"], 0, 1), 4)), outline)

	if unit["bleed"]["ticks"] > 0:  # saigne : une goutte rouge
		arena.draw_circle(center + Vector2(radius * 0.8, -radius * 0.6), 3.5, Color("ff3030"))


## Nom des héros sous leur pion, seulement s'il a la place (pas d'autre héros trop près).
func _draw_names(positions: Dictionary, cell: float) -> void:
	var font := ThemeDB.fallback_font
	for id in positions:
		var unit: Dictionary = battle.units[id]
		if not unit["is_hero"]:
			continue
		var crowded := false
		for other in positions:
			if other != id and battle.units[other]["is_hero"] and positions[other].distance_to(positions[id]) < 1.6:
				crowded = true
				break
		if not crowded or id == selected_id:
			var center := _to_screen(positions[id])
			arena.draw_string(font, center + Vector2(-cell, cell * 0.36 + 12), unit["name"],
				HORIZONTAL_ALIGNMENT_CENTER, cell * 2, 11, Color(1, 1, 1, 0.8))


## Coups (traits), sorts, soins, et chiffres qui s'envolent.
func _draw_effects(positions: Dictionary, cell: float) -> void:
	var font := ThemeDB.fallback_font
	var now := battle.time
	while first_effect < battle.effects.size() and battle.effects[first_effect]["t"] < now - FLOAT_TIME:
		first_effect += 1
	for i in range(first_effect, battle.effects.size()):
		var effect: Dictionary = battle.effects[i]
		var age: float = now - effect["t"]
		if not positions.has(effect["to"]):
			continue
		var to := _to_screen(positions[effect["to"]])
		var from: Vector2 = _to_screen(positions[effect["from"]]) if positions.has(effect["from"]) else to

		if age < STRIKE_TIME:
			var fade := 1.0 - age / STRIKE_TIME
			match effect["kind"]:
				"hit":
					arena.draw_line(from.lerp(to, 0.4), to, Color(1, 1, 1, fade), 3.0)
				"arrow":
					arena.draw_line(from, to, Color(1, 0.85, 0.3, fade), 2.0)
				"spell":
					arena.draw_line(from, to, Color(0.7, 0.45, 1, fade), 2.0)
					arena.draw_circle(to, Battle.SPELL_RADIUS * cell * 0.5, Color(0.6, 0.3, 1, 0.25 * fade))
				"heal":
					arena.draw_line(from, to, Color(0.4, 1, 0.5, fade), 2.0)

		# Le chiffre monte et s'efface.
		var color := Color.WHITE
		var size := 16
		if effect["crit"]:
			color = Color("ffa030")
			size = 22
		elif effect["kind"] == "heal":
			color = Color("6fe08a")
		elif effect["kind"] == "bleed":
			color = Color("ff5050")
		elif effect["text"] == "esquive !":
			color = Color("9fd3ff")
		color.a = clampf(1.0 - age / FLOAT_TIME, 0.0, 1.0)
		var rise := Vector2(-40, -cell * 0.4 - age * cell * 0.8)
		arena.draw_string(font, to + rise, effect["text"], HORIZONTAL_ALIGNMENT_CENTER, 80, size, color)


# ---------------------------------------------------------------------------
# Fin du combat
# ---------------------------------------------------------------------------

## Remplace la carte et la pause par les fenêtres de fin de combat :
## une fenêtre rouge par héros mort, puis le résultat (récompenses, niveaux, MVP).
func _show_result(report: Dictionary) -> void:
	controls.queue_free()
	arena.visible = false
	hint_label.visible = false
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Le journal et les fenêtres de fin se partagent la place ; les fenêtres défilent si besoin.
	var scroll := UI.make_scroll()
	layout.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	for window in UI.make_battle_report_windows(report):
		box.add_child(window)

	var continue_button := UI.make_button("Continuer", func(): closed.emit())
	continue_button.custom_minimum_size.y = 90
	box.add_child(continue_button)
