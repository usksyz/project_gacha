class_name BattleView
extends Control
## Écran de combat, en direct et vu du dessus.
## En haut le titre, le chrono et la barre de vie du boss ; au milieu le champ de bataille ;
## en dessous l'encart de l'équipe (vie en rouge, mana en bleu, toucher un héros le choisit) ;
## en bas le journal et la pause.
## Pas d'accélération ni de « passer » : on vit le combat. On peut guider ses héros :
## toucher un héros pour le choisir, puis toucher un endroit pour l'y envoyer
## (se mettre à couvert, reculer, relayer un blessé), ou toucher un ennemi pour qu'il l'attaque.
## Le combat continue même si on change d'onglet ; on peut le mettre en pause
## (mais pas donner d'ordres pendant la pause : les ordres se donnent dans le feu de l'action).

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
	"disobey": Color("b0b0c8"),    # ordre refusé (santé mentale basse), Loyal
}

## Durée d'affichage des coups (traits) et des chiffres qui s'envolent, en secondes de combat.
const STRIKE_TIME := 0.25
const FLOAT_TIME := 0.9

## Distance (en cases) à laquelle un toucher « attrape » un pion.
const TAP_RADIUS := 0.8

## Portraits de l'équipe : hauteur de la rangée, couleurs des barres (cahier : vie rouge, mana bleue).
const PORTRAIT_HEIGHT := 96
const HP_COLOR := Color("e04848")
const MANA_COLOR := Color("4a8fe8")

var battle: Battle
var layout: VBoxContainer
var title_label: Label
var clock_label: Label
var hint_label: Label
var arena: Control
var boss_bar: Control
var portraits: Control
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

	# Barre de vie du boss (seulement s'il y en a un).
	boss_bar = Control.new()
	boss_bar.custom_minimum_size.y = 30
	boss_bar.draw.connect(_draw_boss_bar)
	boss_bar.visible = battle.enemies.any(func(enemy): return enemy["boss"])
	layout.add_child(boss_bar)

	# Le champ de bataille : dessiné par _draw_arena, et on le touche pour donner des ordres.
	arena = Control.new()
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.draw.connect(_draw_arena)
	arena.gui_input.connect(_on_arena_input)
	layout.add_child(arena)

	# Encart de l'équipe, sous le champ de bataille : les héros côte à côte, avec leurs PV
	# (actuels / max et pourcentage) et leur mana (mages et soigneurs). Toucher un héros le choisit.
	portraits = Control.new()
	portraits.custom_minimum_size.y = PORTRAIT_HEIGHT
	portraits.draw.connect(_draw_portraits)
	portraits.gui_input.connect(_on_portraits_input)
	layout.add_child(portraits)

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
	selected_id = -1  # pas d'ordre pendant la pause
	_update_hint()
	arena.queue_redraw()


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
	portraits.queue_redraw()
	boss_bar.queue_redraw()


## Barre de vie du boss, en haut : son nom et sa vie.
func _draw_boss_bar() -> void:
	var font := ThemeDB.fallback_font
	for enemy in battle.enemies:
		if not enemy["boss"]:
			continue
		var ratio := clampf(float(enemy["hp"]) / enemy["max_hp"], 0.0, 1.0)
		var rect := Rect2(Vector2.ZERO, boss_bar.size)
		boss_bar.draw_rect(rect, Color("12131c"))
		boss_bar.draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), Color("7a2a8a"))
		boss_bar.draw_rect(rect, Color("c9a2ff"), false, 2.0)
		var text := "%s — %d / %d" % [enemy["name"], maxi(0, enemy["hp"]), enemy["max_hp"]]
		if not enemy["present"]:
			text = "%s — pas encore arrivé" % enemy["name"]
		boss_bar.draw_string(font, Vector2(10, rect.size.y * 0.72), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		return


## Une case par héros : nom, barre de vie (rouge) avec « PV / PV max » et le pourcentage restant,
## barre de mana (bleue) avec ses points s'il en a.
## Encadrée en jaune s'il est choisi, en rouge s'il est en Berserk ; grisée s'il est tombé.
func _draw_portraits() -> void:
	var font := ThemeDB.fallback_font
	var width := portraits.size.x / GameData.TEAM_SIZE
	for i in battle.heroes.size():
		var hero: Dictionary = battle.heroes[i]
		var box := Rect2(Vector2(i * width, 0), Vector2(width, PORTRAIT_HEIGHT)).grow(-3)
		var color: Color = GameData.RARITY_COLORS[hero["rarity"]]
		var fallen: bool = hero["hp"] <= 0
		portraits.draw_rect(box, Color("262a3b") if not fallen else Color("1b1d2a"))
		var border := color
		if hero["berserk"]:
			border = Color("ff4040")
		if hero["id"] == selected_id:
			border = ORDER_COLOR
		portraits.draw_rect(box, border, false, 3.0 if hero["id"] == selected_id else 2.0)
		var text_color := Color.WHITE if not fallen else Color(1, 1, 1, 0.4)
		portraits.draw_string(font, box.position + Vector2(6, 22), hero["name"], HORIZONTAL_ALIGNMENT_LEFT,
			box.size.x - 12, 16, text_color)
		if fallen:
			portraits.draw_string(font, box.position + Vector2(6, 48), "à terre" if hero["immortal"] else "tombé",
				HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 12, 15, Color(1, 0.5, 0.5, 0.7))
			continue
		# Vie : la barre, puis « 57 / 88 · 65 % » en dessous.
		var ratio: float = float(hero["hp"]) / hero["max_hp"]
		var bar := Rect2(box.position + Vector2(6, 30), Vector2(box.size.x - 12, 12))
		_draw_bar(bar, ratio, HP_COLOR)
		portraits.draw_string(font, bar.position + Vector2(0, 27), "%d / %d · %d %%" % [hero["hp"], hero["max_hp"],
			ceili(ratio * 100)], HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 13, Color(1, 0.8, 0.8))
		# Mana (mages et soigneurs) : la barre avec ses points dessus.
		if hero["max_mana"] > 0:
			var mana_bar := Rect2(bar.position + Vector2(0, 36), Vector2(bar.size.x, 12))
			_draw_bar(mana_bar, hero["mana"] / hero["max_mana"], MANA_COLOR)
			portraits.draw_string(font, mana_bar.position + Vector2(0, 10), "%d / %d" % [int(hero["mana"]), hero["max_mana"]],
				HORIZONTAL_ALIGNMENT_CENTER, mana_bar.size.x, 11, Color.WHITE)


func _draw_bar(rect: Rect2, ratio: float, color: Color) -> void:
	portraits.draw_rect(rect, Color("12131c"))
	portraits.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)), color)


## Toucher un portrait choisit le héros (comme toucher son pion), ou le relâche.
func _on_portraits_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if battle == null or battle.finished or paused:
		return
	var index := int(click.position.x / (portraits.size.x / GameData.TEAM_SIZE))
	if index < 0 or index >= battle.heroes.size() or battle.heroes[index]["hp"] <= 0:
		return
	var hero_id: int = battle.heroes[index]["id"]
	selected_id = -1 if selected_id == hero_id else hero_id
	_update_hint()
	arena.queue_redraw()
	portraits.queue_redraw()


func _update_clock() -> void:
	var limit: float = battle.quest["seconds"]
	var text := ""
	if battle.clock_start < 0:
		text = "Décompte de %s au premier contact" %_format_time(limit)  # survie : le décompte attend
	elif battle.quest["lasting"]:
		text = "Encore %s" % _format_time(limit - battle.clock_time())
	else:
		text = "%s / %s" % [_format_time(battle.clock_time()), _format_time(limit)]
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
	if paused:
		hint_label.text = "Pause. Les ordres reprendront avec le combat."
	elif selected_id >= 0:
		hint_label.text = "%s : touche un endroit pour l'y envoyer, ou un ennemi à attaquer." \
			% battle.units[selected_id]["name"]
	else:
		hint_label.text = "Touche un héros pour le guider."


func _on_arena_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if battle == null or battle.finished or paused:
		return  # pas d'ordre pendant la pause
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
				"bolt":  # petit trait de magie, quand le mage n'a plus de mana
					arena.draw_line(from, to, Color(0.55, 0.75, 1, fade), 1.5)

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
		elif effect["kind"] == "refuse":
			color = Color("b0b0c8")
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
	boss_bar.visible = false
	portraits.visible = false
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
