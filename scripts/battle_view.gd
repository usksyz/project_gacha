class_name BattleView
extends Control
## Écran de combat : rejoue, vu du dessus, un combat déjà calculé par Battle.
## En haut le titre et le chrono, au milieu le champ de bataille, en bas le journal
## et les boutons (pause, vitesse, passer). À la fin, les fenêtres de résultat.

signal closed

## Vitesses proposées par le bouton d'accélération.
const SPEEDS := [1, 2, 4]

const HERO_COLOR := Color("4caf6a")
const ENEMY_COLOR := Color("e05252")
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

var battle: Battle
var report: Dictionary
var layout: VBoxContainer
var title_label: Label
var clock_label: Label
var arena: Control
var log_label: RichTextLabel
var controls: HBoxContainer
var pause_button: Button
var speed_button: Button

## Moment du combat affiché (secondes), et lecture en cours ou non.
var time := 0.0
var playing := false
var paused := false
## Prochain événement du journal et premier effet encore visible (pour ne pas tout relire à chaque image).
var next_event := 0
var first_effect := 0


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)


## Lance le combat à l'écran. « report » = le rapport de GameData.finish_tower_battle.
func play(new_battle: Battle, title: String, new_report: Dictionary) -> void:
	battle = new_battle
	report = new_report
	time = 0.0
	next_event = 0
	first_effect = 0
	paused = false
	playing = true
	_build(title)


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

	# Le champ de bataille : dessiné par _draw_arena à chaque image.
	arena = Control.new()
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.draw.connect(_draw_arena)
	layout.add_child(arena)

	# Journal : la dernière ligne reste toujours visible.
	log_label = RichTextLabel.new()
	log_label.custom_minimum_size.y = 150
	log_label.scroll_following = true
	log_label.get_v_scroll_bar().modulate.a = 0.0  # barre invisible : on fait défiler en glissant
	log_label.add_theme_font_size_override("normal_font_size", 18)
	log_label.add_theme_stylebox_override("normal", UI.make_panel_style(Color("12131c")))
	layout.add_child(log_label)

	# Boutons du bas : pause, accélération (la vitesse choisie est enregistrée dans les paramètres), fin directe.
	controls = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	layout.add_child(controls)
	pause_button = UI.make_button("Pause", _toggle_pause, 24)
	pause_button.custom_minimum_size = Vector2(170, 80)
	controls.add_child(pause_button)
	speed_button = UI.make_button("", _next_speed, 24)
	speed_button.custom_minimum_size = Vector2(170, 80)
	controls.add_child(speed_button)
	_next_speed(0)
	var skip_button := UI.make_button("Passer", _skip, 24)
	skip_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(skip_button)


func _toggle_pause() -> void:
	paused = not paused
	pause_button.text = "Reprendre" if paused else "Pause"


## Passe à la vitesse suivante (x1 → x2 → x4 → x1). « step » = 0 pour juste afficher la vitesse.
func _next_speed(step := 1) -> void:
	if step != 0:
		Settings.change("battle_speed_index", (Settings.battle_speed_index + step) % SPEEDS.size())
	speed_button.text = "x%d" % SPEEDS[Settings.battle_speed_index]


## Va directement à la fin du combat.
func _skip() -> void:
	if playing:
		time = battle.duration
		_advance(true)


func _process(delta: float) -> void:
	if not playing or paused or not is_visible_in_tree():
		return
	time = minf(time + delta * SPEEDS[Settings.battle_speed_index], battle.duration)
	_advance(false)


## Met à jour le journal, le chrono et le dessin pour le moment « time ».
func _advance(skipping: bool) -> void:
	while next_event < battle.events.size() and battle.events[next_event]["t"] <= time:
		_show_event(battle.events[next_event], skipping)
		next_event += 1
	_update_clock()
	arena.queue_redraw()
	if time >= battle.duration:
		playing = false
		_show_result()


func _update_clock() -> void:
	var limit: float = battle.quest["seconds"]
	var text := ""
	if battle.quest["lasting"]:
		text = "Encore %s" % _format_time(limit - time)
	else:
		text = "%s / %s" % [_format_time(time), _format_time(limit)]
	if battle.quest["walls"] > 0:
		text += "   Remparts %d" % battle.wall_frames[_frame_index()]
	clock_label.text = text


func _format_time(seconds: float) -> String:
	var total := maxi(0, ceili(seconds))
	return "%d:%02d" % [total / 60, total % 60]


func _frame_index() -> int:
	return clampi(floori(time / Battle.TICK), 0, battle.frames.size() - 1)


func _show_event(event: Dictionary, skipping: bool) -> void:
	var style: String = event["style"]
	if style in STYLE_COLORS:
		log_label.push_color(STYLE_COLORS[style])
		log_label.add_text(event["text"] + "\n")
		log_label.pop()
	else:
		log_label.add_text(event["text"] + "\n")
	if (style == "berserk" or style == "awaken") and not skipping:
		Settings.vibrate(150)


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
	if battle == null or battle.frames.is_empty():
		return
	var cell := _cell_size()
	var origin := _origin()
	arena.draw_rect(Rect2(origin, Vector2(Battle.GRID_W, Battle.GRID_H) * cell), GROUND_COLOR)

	for obstacle in battle.obstacles:
		var rect: Rect2i = obstacle["rect"]
		var screen_rect := Rect2(origin + Vector2(rect.position) * cell, Vector2(rect.size) * cell).grow(-1.5)
		arena.draw_rect(screen_rect, OBSTACLE_COLORS[obstacle["kind"]])

	# Positions à ce moment : entre deux images enregistrées, on glisse de l'une à l'autre.
	var f := time / Battle.TICK
	var i0 := _frame_index()
	var i1 := mini(i0 + 1, battle.frames.size() - 1)
	var weight := clampf(f - i0, 0.0, 1.0)
	var a: PackedFloat32Array = battle.frames[i0]
	var b: PackedFloat32Array = battle.frames[i1]
	var positions := {}
	for id in battle.units.size():
		var flags := int(a[id * 4 + 3])
		if flags & 1 == 0:
			continue  # pas encore arrivé sur le terrain
		var pos := Vector2(a[id * 4], a[id * 4 + 1]).lerp(Vector2(b[id * 4], b[id * 4 + 1]), weight)
		positions[id] = pos
		_draw_unit(battle.units[id], _to_screen(pos), a[id * 4 + 2], flags, cell)

	_draw_names(positions, cell)
	_draw_effects(positions, cell)


func _draw_unit(unit: Dictionary, center: Vector2, hp: float, flags: int, cell: float) -> void:
	var font := ThemeDB.fallback_font
	var radius := cell * (0.5 if unit["boss"] else 0.36)
	if hp <= 0:
		# Un ennemi vaincu disparaît ; un héros tombé reste, grisé.
		if unit["is_hero"]:
			arena.draw_circle(center, radius, Color(0.3, 0.3, 0.3, 0.6))
			arena.draw_string(font, center + Vector2(-radius, radius * 0.4), "x", HORIZONTAL_ALIGNMENT_CENTER,
				radius * 2, int(radius * 1.2), Color(0.8, 0.8, 0.8))
		return

	if flags & 4:  # Berserk : un halo rouge
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
	arena.draw_rect(Rect2(bar_pos, Vector2(bar_width * clampf(hp / unit["max_hp"], 0, 1), 4)), outline)

	if flags & 2:  # saigne : une goutte rouge
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
		if not crowded:
			var center := _to_screen(positions[id])
			arena.draw_string(font, center + Vector2(-cell, cell * 0.36 + 12), unit["name"],
				HORIZONTAL_ALIGNMENT_CENTER, cell * 2, 11, Color(1, 1, 1, 0.8))


## Coups (traits), sorts, soins, et chiffres qui s'envolent.
func _draw_effects(positions: Dictionary, cell: float) -> void:
	var font := ThemeDB.fallback_font
	while first_effect < battle.effects.size() and battle.effects[first_effect]["t"] < time - FLOAT_TIME:
		first_effect += 1
	for i in range(first_effect, battle.effects.size()):
		var effect: Dictionary = battle.effects[i]
		var age: float = time - effect["t"]
		if age < 0:
			break  # les effets suivants sont dans le futur
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
		color.a = 1.0 - age / FLOAT_TIME
		var rise := Vector2(-40, -cell * 0.4 - age * cell * 0.8)
		arena.draw_string(font, to + rise, effect["text"], HORIZONTAL_ALIGNMENT_CENTER, 80, size, color)


# ---------------------------------------------------------------------------
# Fin du combat
# ---------------------------------------------------------------------------

## Remplace la carte et les boutons par les fenêtres de fin de combat :
## une fenêtre rouge par héros mort, puis le résultat (récompenses, niveaux, MVP).
func _show_result() -> void:
	GameData.show_money()
	controls.queue_free()
	arena.visible = false
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Le journal et les fenêtres de fin se partagent la place ; les fenêtres défilent si besoin.
	var scroll := UI.make_scroll()
	layout.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)

	if not report["dead"].is_empty():
		Settings.vibrate(400)
	for death in report["dead"]:
		var hero: Dictionary = death["hero"]
		box.add_child(UI.make_system_window("Un héros est tombé", [
			"%s (%s) a quitté ce monde pour toujours." % [hero["name"], UI.rarity_text(hero["rarity"])],
			"Cause : %s." % death["cause"],
		], true))

	if not report["notices"].is_empty():
		box.add_child(UI.make_system_window("Félicitations !", report["notices"]))
	if not report["skills"].is_empty():
		box.add_child(UI.make_system_window("Éveil des compétences !", report["skills"]))

	var lines := []
	if report["victory"]:
		lines.append("+%d or   +%d gemmes" % [report["gold"], report["gems"]])
	else:
		lines.append("Les survivants sont ramenés à la cité.")
	lines.append("+%d expérience pour chaque survivant" % report["xp"])
	for level_up in report["level_ups"]:
		var hero: Dictionary = level_up["hero"]
		lines.append("%s passe au niveau %d !" % [hero["name"], hero["level"]])
	if report["mvp"] != "":
		lines.append("MVP : %s" % report["mvp"])
	box.add_child(UI.make_system_window("Étage conquis !" if report["victory"] else "Défaite", lines))

	var continue_button := UI.make_button("Continuer", func(): closed.emit())
	continue_button.custom_minimum_size.y = 90
	box.add_child(continue_button)
