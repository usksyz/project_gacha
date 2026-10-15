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

## Couleur de chaque type de case (voir BattleMap.Kind) ; plus claire à chaque niveau de hauteur
## (HEIGHT_LIGHTEN par niveau), et le chiffre de la hauteur dans le coin (Combat v2, C1).
const KIND_COLORS := {
	BattleMap.Kind.GROUND: Color("27301f"),
	BattleMap.Kind.BLOCK: Color("3a3030"),
	BattleMap.Kind.ROOF: Color("7a4434"),
	BattleMap.Kind.LADDER: Color("27301f"),
	BattleMap.Kind.STAIRS: Color("4c5638"),
	BattleMap.Kind.LOW_WALL: Color("6b5a48"),
	BattleMap.Kind.RAMPART: Color("737882"),
	BattleMap.Kind.GATE: Color("5a4128"),
	BattleMap.Kind.GRASS: Color("3a5a2a"),
	BattleMap.Kind.TOWER: Color("8a6a4a"),
	BattleMap.Kind.ROCK: Color("5b5d66"),
}
const HEIGHT_LIGHTEN := 0.09
const LADDER_COLOR := Color("c99a5b")
const EDGE_COLOR := Color(0, 0, 0, 0.55)
const HEIGHT_TEXT_COLOR := Color(1, 1, 1, 0.55)

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
## Durée d'affichage de la bulle « Non ! » d'un héros qui refuse un ordre.
const BUBBLE_TIME := 1.5

## Distance (en cases) à laquelle un toucher « attrape » un pion.
const TAP_RADIUS := 0.8

## Portraits de l'équipe : hauteur de la rangée, couleurs des barres (cahier : vie rouge, mana bleue).
const PORTRAIT_HEIGHT := 106
const HP_COLOR := Color("e04848")
const MANA_COLOR := Color("4a8fe8")
## Endurance (sous la vie) : jaune, grise quand le héros est épuisé.
const STAMINA_COLOR := Color("e8c547")
const STAMINA_TIRED_COLOR := Color("7a7466")

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
## Ordre « Berserk » (entrer en rage ou en sortir), visible quand le héros choisi possède Berserk.
var berserk_button: Button
## Ordre « Échanger de place » (rotation : il part se reposer à l'arrière, un allié frais prend son poste).
var swap_button: Button
## Ordre « Tir de barrage » (un archer tire toutes ses flèches d'un coup), visible quand c'est possible.
var barrage_button: Button

## La vue isométrique 3D (Combat v2, C2 : BattleView3D), à la place de « arena » quand use_3d est vrai :
## par défaut avec les nouveaux visuels ; le mode dev a un bouton pour passer de l'une à l'autre en combat.
var arena3d: BattleView3D
var use_3d := false
var view_button: Button

var paused := false
## Voir play() : fin d'un combat qui n'est pas de la Tour (duel).
var finish_callback := Callable()
## Rapport du dernier combat de la Tour terminé (GameData.finish_tower_battle), vide sinon :
## l'écran Donjons y lit les conseils du Système à montrer après « Continuer ».
var last_report: Dictionary = {}
## Temps accumulé depuis le dernier pas du combat (secondes).
var accumulator := 0.0
## Héros choisi pour recevoir un ordre (son numéro), ou -1.
var selected_id := -1
## Prochain événement du journal à afficher, et premier effet encore visible.
var next_event := 0
var first_effect := 0
## Prochaine fenêtre système du combat à afficher (Battle.alerts), et la colonne où elles s'empilent.
var next_alert := 0
var alert_box: VBoxContainer
## Durée d'affichage d'une fenêtre système de rupture (secondes réelles ; le combat continue dessous).
const ALERT_TIME := 4.0


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	# Fenêtres système de rupture : posées par-dessus le haut du combat, sans bloquer les touchers.
	alert_box = VBoxContainer.new()
	alert_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	alert_box.offset_left = 40
	alert_box.offset_right = -40
	alert_box.offset_top = 150
	alert_box.add_theme_constant_override("separation", 10)
	alert_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(alert_box)


## Lance l'affichage d'un combat déjà préparé (battle.start() a été appelée).
## « on_finish » : appelée avec le combat terminé, elle renvoie les fenêtres de fin à afficher (duel) ;
## sans elle, c'est un combat de la Tour (GameData.finish_tower_battle).
func play(new_battle: Battle, title: String, on_finish := Callable()) -> void:
	battle = new_battle
	finish_callback = on_finish
	last_report = {}
	accumulator = 0.0
	next_event = 0
	first_effect = 0
	next_alert = 0
	for old in alert_box.get_children():
		old.queue_free()
	selected_id = -1
	paused = false
	use_3d = Settings.new_visuals
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
	# Mode dev : passer de la vue 3D à la vue de dessus (et retour) en plein combat.
	view_button = UI.make_button("", _toggle_view, 16)
	view_button.custom_minimum_size = Vector2(96, 40)
	view_button.visible = Settings.dev_mode
	header.add_child(view_button)

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
	# Le même champ de bataille en vue isométrique 3D (une seule des deux vues est visible).
	arena3d = BattleView3D.new()
	arena3d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena3d.tapped.connect(_arena_tap)
	layout.add_child(arena3d)
	arena3d.setup(self)
	_apply_view()

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
	controls.add_theme_constant_override("separation", 8)
	layout.add_child(controls)
	berserk_button = UI.make_button("", _order_berserk, 22)
	berserk_button.custom_minimum_size.y = 80
	berserk_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	berserk_button.add_theme_color_override("font_color", Color("ff6060"))
	berserk_button.visible = false
	controls.add_child(berserk_button)
	swap_button = UI.make_button("Échanger de place", _order_swap, 22)
	swap_button.custom_minimum_size.y = 80
	swap_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	swap_button.add_theme_color_override("font_color", Color("e8c547"))
	swap_button.visible = false
	controls.add_child(swap_button)
	barrage_button = UI.make_button("Tir de barrage", _order_barrage, 22)
	barrage_button.custom_minimum_size.y = 80
	barrage_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barrage_button.add_theme_color_override("font_color", Color("f5d98a"))
	barrage_button.visible = false
	controls.add_child(barrage_button)
	# Jusqu'à quatre boutons côte à côte : leur texte passe à la ligne plutôt que d'élargir l'écran.
	for button in [berserk_button, swap_button, barrage_button]:
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pause_button = UI.make_button("Pause", _toggle_pause, 26)
	pause_button.custom_minimum_size.y = 80
	pause_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(pause_button)


## Mode dev : vue 3D ↔ vue de dessus (le combat continue, rien ne change dans la simulation).
func _toggle_view() -> void:
	use_3d = not use_3d
	_apply_view()


func _apply_view() -> void:
	arena.visible = not use_3d
	arena3d.visible = use_3d
	view_button.text = "Vue de dessus" if use_3d else "Vue 3D"
	if hint_label != null and battle != null:
		_update_hint()


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
		if finish_callback.is_valid():
			_show_windows(finish_callback.call(battle))
		else:
			_show_result(GameData.finish_tower_battle(battle))


## Met à jour le journal, le chrono et le dessin.
func _advance() -> void:
	while next_event < battle.events.size():
		_show_event(battle.events[next_event])
		next_event += 1
	while next_alert < battle.alerts.size():
		_show_alert(battle.alerts[next_alert])
		next_alert += 1
	if selected_id >= 0 and (battle.units[selected_id]["hp"] <= 0 or not battle.units[selected_id]["present"]):
		selected_id = -1  # le héros choisi est tombé
		_update_hint()
	_update_berserk_button()  # (le héros peut entrer en rage ou en sortir de lui-même)
	_update_clock()
	# Les effets trop vieux pour être montrés (coups, chiffres, bulles) : on ne les parcourt plus.
	while first_effect < battle.effects.size() and battle.effects[first_effect]["t"] < battle.time - BUBBLE_TIME:
		first_effect += 1
	if arena.visible:
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
	# Duel : les deux duellistes côte à côte, chacun sur la moitié de l'encart.
	var shown: Array = battle.heroes + battle.enemies if _is_duel() else battle.heroes
	var width := portraits.size.x / (2 if _is_duel() else GameData.TEAM_SIZE)
	for i in shown.size():
		var hero: Dictionary = shown[i]
		var box := Rect2(Vector2(i * width, 0), Vector2(width, PORTRAIT_HEIGHT)).grow(-3)
		var color: Color = GameData.RARITY_COLORS[hero["rarity"]]
		var fallen: bool = hero["hp"] <= 0 or not hero["present"]
		portraits.draw_rect(box, Color("262a3b") if not fallen else Color("1b1d2a"))
		var border := color
		if _is_duel():
			border = HERO_COLOR if hero["is_hero"] else ENEMY_COLOR
		if hero["berserk"]:
			border = Color("ff4040")
		if battle.panicking(hero):
			border = Color("b0b0c8")
		if hero["id"] == selected_id:
			border = ORDER_COLOR
		portraits.draw_rect(box, border, false, 3.0 if hero["id"] == selected_id else 2.0)
		var text_color := Color.WHITE if not fallen else Color(1, 1, 1, 0.4)
		portraits.draw_string(font, box.position + Vector2(6, 22), hero["name"], HORIZONTAL_ALIGNMENT_LEFT,
			box.size.x - 12, 16, text_color)
		if hero.get("agony", false):
			# À l'agonie : les secondes qui restent pour le sauver.
			portraits.draw_string(font, box.position + Vector2(6, 48), "AGONIE %d s" % ceili(hero["agony_until"] - battle.time),
				HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 12, 15, Color("ff4040"))
			if hero.get("embedded", false):  # arme plantée : seule une potion peut le sauver
				portraits.draw_string(font, box.position + Vector2(6, 68), "arme plantée", HORIZONTAL_ALIGNMENT_LEFT,
					box.size.x - 12, 13, Color("ffb060"))
			continue
		if hero.get("stabilized", false) and not hero["present"]:
			portraits.draw_string(font, box.position + Vector2(6, 48), "à l'abri", HORIZONTAL_ALIGNMENT_LEFT,
				box.size.x - 12, 15, Color("6fe08a"))
			continue
		if fallen:
			portraits.draw_string(font, box.position + Vector2(6, 48), "à terre" if hero["immortal"] else "tombé",
				HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 12, 15, Color(1, 0.5, 0.5, 0.7))
			continue
		# Vie : la barre, puis « 57 / 88 · 65 % » en dessous.
		var ratio: float = float(hero["hp"]) / hero["max_hp"]
		var bar := Rect2(box.position + Vector2(6, 30), Vector2(box.size.x - 12, 12))
		_draw_bar(bar, ratio, HP_COLOR)
		# Endurance : une fine barre jaune sous la vie (grise quand il est épuisé).
		var stamina_bar := Rect2(bar.position + Vector2(0, 14), Vector2(bar.size.x, 5))
		_draw_bar(stamina_bar, hero["stamina"] / hero["max_stamina"], STAMINA_TIRED_COLOR if hero["exhausted"] else STAMINA_COLOR)
		portraits.draw_string(font, bar.position + Vector2(0, 33), "%d / %d · %d %%" % [hero["hp"], hero["max_hp"],
			ceili(ratio * 100)], HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 13, Color(1, 0.8, 0.8))
		# Mana (mages et soigneurs) : la barre avec ses points dessus.
		if hero["max_mana"] > 0:
			var mana_bar := Rect2(bar.position + Vector2(0, 40), Vector2(bar.size.x, 12))
			_draw_bar(mana_bar, hero["mana"] / hero["max_mana"], MANA_COLOR)
			portraits.draw_string(font, mana_bar.position + Vector2(0, 10), "%d / %d" % [int(hero["mana"]), hero["max_mana"]],
				HORIZONTAL_ALIGNMENT_CENTER, mana_bar.size.x, 11, Color.WHITE)
		elif hero.get("arrows", -1) >= 0:
			# Carquois (héros à l'arc) : les flèches qui restent ; « dague » quand il n'en a plus.
			var arrows_text := "Flèches %d / %d" % [hero["arrows"], GameData.QUIVER_SIZE] if hero["arrows"] > 0 else "Plus de flèches"
			portraits.draw_string(font, bar.position + Vector2(0, 50), arrows_text, HORIZONTAL_ALIGNMENT_CENTER,
				bar.size.x, 12, Color("f5d98a") if hero["arrows"] > 0 else Color("ffb060"))
		elif battle.wear_factor(hero) <= GameData.WEAR_NOTICE:
			# Arme émoussée : ce qu'il lui reste de force.
			portraits.draw_string(font, bar.position + Vector2(0, 50), "Arme %d %%" % roundi(battle.wear_factor(hero) * 100),
				HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 12, Color("c0b090"))
		# Santé mentale du moment : une fine barre tout en bas (« PEUR » quand il a peur, voir Battle._scare,
		# qu'il fuie ou non ; « PANIQUE » pendant un effondrement).
		var mind_bar := Rect2(box.position + Vector2(6, box.size.y - 9), Vector2(box.size.x - 12, 5))
		_draw_bar(mind_bar, hero["mental"] / GameData.MENTAL_MAX, UI.mental_color(hero["mental"]))
		if hero["hp"] > 0 and battle.afraid(hero):
			portraits.draw_string(font, mind_bar.position + Vector2(0, -2), "PEUR", HORIZONTAL_ALIGNMENT_CENTER,
				mind_bar.size.x, 13, Color("ffb060"))
		elif battle.panicking(hero):
			portraits.draw_string(font, mind_bar.position + Vector2(0, -2), "PANIQUE", HORIZONTAL_ALIGNMENT_CENTER,
				mind_bar.size.x, 13, Color("e0e0ff"))
		elif hero["berserk"]:
			# Rage d'éveil : « REFUS DE MOURIR » tant qu'il ne peut pas tomber sous 1 point de vie.
			var refusing: bool = battle.time < hero.get("refuse_death_until", 0.0)
			portraits.draw_string(font, mind_bar.position + Vector2(0, -2), "REFUS DE MOURIR" if refusing else "BERSERK",
				HORIZONTAL_ALIGNMENT_CENTER, mind_bar.size.x, 13, Color("ff4040"))
		elif hero.get("resting", false):
			portraits.draw_string(font, mind_bar.position + Vector2(0, -2), "REPOS", HORIZONTAL_ALIGNMENT_CENTER,
				mind_bar.size.x, 13, STAMINA_COLOR)
		elif battle.has_migraine(hero):
			portraits.draw_string(font, mind_bar.position + Vector2(0, -2), "MIGRAINE", HORIZONTAL_ALIGNMENT_CENTER,
				mind_bar.size.x, 13, Color("c9a2ff"))


func _is_duel() -> bool:
	return battle != null and battle.quest.get("duel", false)


func _draw_bar(rect: Rect2, ratio: float, color: Color) -> void:
	portraits.draw_rect(rect, Color("12131c"))
	portraits.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)), color)


## Toucher un portrait choisit le héros (comme toucher son pion), ou le relâche.
func _on_portraits_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if battle == null or battle.finished or paused or battle.quest.get("duel", false):
		return
	var index := int(click.position.x / (portraits.size.x / GameData.TEAM_SIZE))
	if index < 0 or index >= battle.heroes.size() or battle.heroes[index]["hp"] <= 0 or not battle.heroes[index]["present"]:
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
		text = "%s au premier contact" % _format_time(limit)  # survie : le décompte attend
	elif battle.quest["lasting"]:
		text = "Encore %s" % _format_time(limit - battle.clock_time())
	else:
		text = "%s / %s" % [_format_time(battle.clock_time()), _format_time(limit)]
	if battle.quest["walls"] > 0:
		text += "   Remparts %d" % battle.walls
	if battle.quest.get("waves", 0) > 0:  # survie par vagues
		text += "   Vague %d/%d" % [battle.current_wave() + 1, battle.quest["waves"]]
	clock_label.text = text


func _format_time(seconds: float) -> String:
	var total := maxi(0, ceili(seconds))
	return "%d:%02d" % [total / 60, total % 60]


## Une fenêtre système (rupture) : elle reste ALERT_TIME secondes puis s'efface ; le combat continue.
func _show_alert(alert: Dictionary) -> void:
	var window := UI.make_system_window(alert["title"], alert["lines"], alert["danger"])
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in window.find_children("*", "Control", true, false):
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alert_box.add_child(window)
	Settings.vibrate(300)
	var tween := window.create_tween()
	tween.tween_interval(ALERT_TIME)
	tween.tween_property(window, "modulate:a", 0.0, 0.5)
	tween.tween_callback(window.queue_free)


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
	if battle.quest.get("duel", false):
		hint_label.text = "Duel : les deux héros règlent leur conflit seuls, sans ordres. Il s'arrête à %d %% de vie." \
			% roundi(GameData.DUEL_STOP_HP * 100)
	elif paused:
		hint_label.text = "Pause. Les ordres reprendront avec le combat."
	elif selected_id >= 0:
		hint_label.text = "%s : touche un endroit pour l'y envoyer, un ennemi à attaquer, ou un bouton en bas." \
			% battle.units[selected_id]["name"]
		if not battle.height_cells().is_empty():
			hint_label.text += (" Touche un toit pour l'y envoyer." if use_3d else " Le chiffre d'une case : sa hauteur.") \
				+ " On monte par les échelles et les escaliers ; d'en haut, on frappe plus fort et on tire plus loin."
	else:
		hint_label.text = "Touche un héros pour le guider."
	_update_berserk_button()


## Le bouton « Berserk » n'apparaît que pour un héros choisi qui possède Berserk (pas pendant la pause).
func _update_berserk_button() -> void:
	if berserk_button == null or not is_instance_valid(berserk_button):
		return
	var hero: Dictionary = battle.units[selected_id] if selected_id >= 0 else {}
	var shown: bool = not paused and not hero.is_empty() and battle.can_berserk(hero)
	if berserk_button.visible != shown:
		berserk_button.visible = shown
	var text := "Sortir du Berserk" if shown and hero["berserk"] else "Berserk !"
	if berserk_button.text != text:
		berserk_button.text = text
	# (Même rangée : « Échanger de place », pour un héros choisi qui n'est pas déjà au repos.)
	var swap_shown: bool = not paused and not hero.is_empty() and not _is_duel() and battle.can_swap(hero)
	if swap_button.visible != swap_shown:
		swap_button.visible = swap_shown
	var barrage_shown: bool = not paused and not hero.is_empty() and not _is_duel() and battle.can_barrage(hero)
	if barrage_button.visible != barrage_shown:
		barrage_button.visible = barrage_shown


## Ordre du Maître : le héros choisi part se reposer à l'arrière, un allié frais prend sa place.
func _order_swap() -> void:
	if selected_id < 0 or paused or battle.finished:
		return
	battle.order_swap(battle.units[selected_id])
	Settings.vibrate(30)
	selected_id = -1
	_update_hint()
	arena.queue_redraw()
	portraits.queue_redraw()


## Ordre du Maître : l'archer choisi tire toutes ses flèches d'un coup (il peut refuser, voir Battle.order_barrage).
func _order_barrage() -> void:
	if selected_id < 0 or paused or battle.finished:
		return
	battle.order_barrage(battle.units[selected_id])
	Settings.vibrate(30)
	selected_id = -1
	_update_hint()
	arena.queue_redraw()
	portraits.queue_redraw()


## Ordre du Maître : le héros choisi entre en rage, ou en sort (il peut refuser, voir Battle.order_berserk).
func _order_berserk() -> void:
	if selected_id < 0 or paused or battle.finished:
		return
	var hero: Dictionary = battle.units[selected_id]
	battle.order_berserk(hero, not hero["berserk"])
	Settings.vibrate(30)
	selected_id = -1
	_update_hint()
	arena.queue_redraw()
	portraits.queue_redraw()


func _on_arena_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if battle == null or battle.finished or paused or battle.quest.get("duel", false):
		return  # pas d'ordre pendant la pause, ni pendant un duel
	var map_pos: Vector2 = (event.position - _origin()) / _cell_size()
	_arena_tap(_unit_at(map_pos), map_pos, Rect2(0, 0, Battle.GRID_W, Battle.GRID_H).has_point(map_pos))


## Un toucher sur le champ de bataille (vue de dessus ou vue 3D) : « touched » le combattant touché ({} sinon),
## « map_pos » le point de la carte (en cases), « inside » s'il est sur la carte. Mêmes ordres dans les deux vues.
func _arena_tap(touched: Dictionary, map_pos: Vector2, inside: bool) -> void:
	if battle == null or battle.finished or paused or battle.quest.get("duel", false):
		return  # pas d'ordre pendant la pause, ni pendant un duel
	if not touched.is_empty() and touched["is_hero"]:
		# Choisir un héros (ou le relâcher en le touchant à nouveau).
		selected_id = -1 if selected_id == touched["id"] else touched["id"]
	elif selected_id >= 0:
		var hero: Dictionary = battle.units[selected_id]
		if not touched.is_empty():
			battle.order_attack(hero, touched)
		elif inside:
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
	_draw_cells(origin, cell)

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


## La carte « 3D sur grille » vue du dessus (Combat v2, C1) : chaque case dans la couleur de son type, plus
## claire quand elle est haute, avec sa hauteur écrite dans le coin ; les échelles, escaliers, toits, tours,
## remparts, murets, rochers et herbes ont leur dessin ; un trait sombre marque chaque bord qui tombe vers une
## case plus basse (on lit le relief).
func _draw_cells(origin: Vector2, cell: float) -> void:
	var map: BattleMap = battle.map
	var font := ThemeDB.fallback_font
	var font_size := maxi(8, int(cell * 0.32))
	for i in map.kinds.size():
		var c := map.cell_at(i)
		var kind := map.kinds[i]
		var height := map.heights[i]
		var area := Rect2(origin + Vector2(c) * cell, Vector2.ONE * cell)
		var color: Color = KIND_COLORS.get(kind, GROUND_COLOR).lightened(height * HEIGHT_LIGHTEN)
		if kind != BattleMap.Kind.GROUND or height > 0:
			arena.draw_rect(area, color)
		match kind:
			BattleMap.Kind.BLOCK:
				# Obstacle (maison fermée, arbre, puits, pan de mur) : hachuré.
				arena.draw_rect(area.grow(-1.5), color.darkened(0.25), false, 1.5)
				arena.draw_line(area.position + Vector2(3, 3), area.end - Vector2(3, 3), color.lightened(0.15), 1.0)
				arena.draw_line(Vector2(area.end.x - 3, area.position.y + 3), Vector2(area.position.x + 3, area.end.y - 3), color.lightened(0.15), 1.0)
			BattleMap.Kind.ROOF:
				# Toit : des rangées de tuiles.
				for k in range(1, 4):
					var y := area.position.y + area.size.y * k / 4.0
					arena.draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), color.darkened(0.2), 1.0)
			BattleMap.Kind.LADDER:
				# Échelle : deux montants et des barreaux.
				var left := area.position.x + cell * 0.28
				var right := area.end.x - cell * 0.28
				arena.draw_line(Vector2(left, area.position.y + 2), Vector2(left, area.end.y - 2), LADDER_COLOR, 2.0)
				arena.draw_line(Vector2(right, area.position.y + 2), Vector2(right, area.end.y - 2), LADDER_COLOR, 2.0)
				for k in range(1, 5):
					var y := area.position.y + area.size.y * k / 5.0
					arena.draw_line(Vector2(left, y), Vector2(right, y), LADDER_COLOR, 1.5)
			BattleMap.Kind.STAIRS:
				# Escalier ou pente : des marches.
				for k in range(1, 3):
					var x := area.position.x + area.size.x * k / 3.0
					arena.draw_line(Vector2(x, area.position.y + 3), Vector2(x, area.end.y - 3), color.lightened(0.2), 1.0)
			BattleMap.Kind.LOW_WALL:
				arena.draw_rect(Rect2(area.position + Vector2(2, cell * 0.3), Vector2(cell - 4, cell * 0.4)), color.lightened(0.15))
			BattleMap.Kind.RAMPART:
				# Chemin de ronde : des créneaux côté ennemis (en haut).
				arena.draw_rect(Rect2(area.position + Vector2(cell * 0.1, 0), Vector2(cell * 0.3, cell * 0.25)), color.lightened(0.2))
				arena.draw_rect(Rect2(area.position + Vector2(cell * 0.6, 0), Vector2(cell * 0.3, cell * 0.25)), color.lightened(0.2))
			BattleMap.Kind.TOWER:
				# Clocher : la cloche.
				arena.draw_circle(area.get_center(), cell * 0.22, Color("d8b04a"))
			BattleMap.Kind.ROCK:
				arena.draw_circle(area.get_center(), cell * 0.38, color.lightened(0.12))
			BattleMap.Kind.GRASS:
				for k in 4:
					var p := area.position + Vector2(cell * (0.2 + 0.2 * k), cell * (0.35 if k % 2 == 0 else 0.65))
					arena.draw_line(p, p + Vector2(0, -cell * 0.18), color.lightened(0.3), 1.0)
		# Bords qui tombent vers une case plus basse : un trait sombre.
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = c + d
			if map.in_bounds(next) and map.height_at(next) < height and kind != BattleMap.Kind.BLOCK:
				var a := area.get_center() + Vector2(d) * cell * 0.5 + Vector2(d.y, d.x) * cell * 0.5
				var b := area.get_center() + Vector2(d) * cell * 0.5 - Vector2(d.y, d.x) * cell * 0.5
				arena.draw_line(a, b, EDGE_COLOR, 2.0)
		if height > 0:
			arena.draw_string(font, area.position + Vector2(2, font_size), str(height), HORIZONTAL_ALIGNMENT_LEFT, -1,
				font_size, HEIGHT_TEXT_COLOR)


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
		# Un héros à l'agonie : un cercle rouge qui bat, et les secondes qui lui restent.
		if unit.get("agony", false):
			var pulse := 0.5 + 0.5 * sin(battle.time * 8.0)
			arena.draw_circle(center, radius, Color(0.6, 0.1, 0.1, 0.5 + 0.4 * pulse))
			arena.draw_arc(center, radius + 3, 0, TAU, 24, Color(1, 0.25, 0.25), 2.0)
			arena.draw_string(font, center + Vector2(-radius * 2, radius * 0.4), str(ceili(unit["agony_until"] - battle.time)),
				HORIZONTAL_ALIGNMENT_CENTER, radius * 4, int(radius * 1.2), Color.WHITE)
			return
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
	if _is_duel():
		# Duel : les deux sont des héros (couleur de leur rareté) ; le cercle dit le camp (vert / rouge).
		fill = GameData.RARITY_COLORS[unit["rarity"]].darkened(0.35)
		outline = HERO_COLOR if unit["is_hero"] else ENEMY_COLOR
	elif unit["is_hero"]:
		fill = GameData.RARITY_COLORS[unit["rarity"]].darkened(0.35)
		outline = HERO_COLOR
	elif unit["boss"]:
		fill = Color("5a1f6e")
	arena.draw_circle(center, radius, fill)
	arena.draw_arc(center, radius, 0, TAU, 24, outline, 2.0)
	arena.draw_string(font, center + Vector2(-radius, radius * 0.45), unit["name"].left(1),
		HORIZONTAL_ALIGNMENT_CENTER, radius * 2, int(radius * 1.2), Color.WHITE)

	# Barre de vie au-dessus du pion (et, pour un héros, l'endurance juste dessous, en jaune).
	var bar_width := cell * 0.8
	var bar_pos := center + Vector2(-bar_width / 2, -radius - 10 if unit["person"] else -radius - 7)
	arena.draw_rect(Rect2(bar_pos, Vector2(bar_width, 4)), Color("12131c"))
	arena.draw_rect(Rect2(bar_pos, Vector2(bar_width * clampf(float(unit["hp"]) / unit["max_hp"], 0, 1), 4)), outline)
	if unit["person"]:
		var stamina_pos := bar_pos + Vector2(0, 4)
		arena.draw_rect(Rect2(stamina_pos, Vector2(bar_width, 2.5)), Color("12131c"))
		arena.draw_rect(Rect2(stamina_pos, Vector2(bar_width * clampf(unit["stamina"] / unit["max_stamina"], 0, 1), 2.5)),
			STAMINA_TIRED_COLOR if unit["exhausted"] else STAMINA_COLOR)

	if unit["bleed"]["ticks"] > 0:  # saigne : une goutte rouge
		arena.draw_circle(center + Vector2(radius * 0.8, -radius * 0.6), 3.5, Color("ff3030"))
	if battle.height_of(unit) > 0:  # en hauteur : sa hauteur dans une pastille claire
		var badge := center + Vector2(radius * 0.8, radius * 0.7)
		arena.draw_circle(badge, maxf(5.0, cell * 0.16), Color("e8e2c8"))
		var size := maxi(8, int(cell * 0.24))
		arena.draw_string(font, badge + Vector2(-size, size * 0.38), str(battle.height_of(unit)), HORIZONTAL_ALIGNMENT_CENTER,
			size * 2, size, Color("1b1b1b"))


## Nom des héros sous leur pion, seulement s'il a la place (pas d'autre héros trop près).
## Duel : les deux noms, toujours, celui du défié au-dessus de son pion pour ne pas se chevaucher.
func _draw_names(positions: Dictionary, cell: float) -> void:
	var font := ThemeDB.fallback_font
	if _is_duel():
		for id in positions:
			var duelist: Dictionary = battle.units[id]
			var at := _to_screen(positions[id])
			var offset := Vector2(-cell * 1.5, cell * 0.36 + 14) if duelist["is_hero"] else Vector2(-cell * 1.5, -cell * 0.36 - 12)
			arena.draw_string(font, at + offset, duelist["name"], HORIZONTAL_ALIGNMENT_CENTER, cell * 3, 14,
				HERO_COLOR.lightened(0.4) if duelist["is_hero"] else ENEMY_COLOR.lightened(0.3))
		return
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

		# Ordre refusé : une petite bulle « Non ! » au-dessus du héros, qui reste puis s'efface.
		if effect["kind"] == "refuse":
			_draw_bubble(font, to + Vector2(0, -cell * 0.4), effect["text"], clampf(2.0 * (1.0 - age / BUBBLE_TIME), 0.0, 1.0))
			continue
		if age > FLOAT_TIME:
			continue

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


## Bulle de parole (fond blanc, petite pointe vers le bas) centrée au-dessus du point « tip ».
func _draw_bubble(font: Font, tip: Vector2, text: String, alpha: float) -> void:
	draw_bubble_on(arena, font, tip, text, alpha)


## La même bulle, dessinée sur n'importe quel Control (la vue 3D s'en sert aussi).
func draw_bubble_on(canvas: Control, font: Font, tip: Vector2, text: String, alpha: float) -> void:
	var font_size := 18
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 16
	var box := Rect2(tip + Vector2(-width / 2.0, -34), Vector2(width, 26))
	var fill := Color(1, 1, 1, 0.92 * alpha)
	canvas.draw_rect(box, fill)
	canvas.draw_colored_polygon(PackedVector2Array([tip + Vector2(-6, -8), tip + Vector2(6, -8), tip]), fill)
	canvas.draw_string(font, box.position + Vector2(0, 19), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size,
		Color(0.75, 0.1, 0.1, alpha))


# ---------------------------------------------------------------------------
# Fin du combat
# ---------------------------------------------------------------------------

## Remplace la carte et la pause par les fenêtres de fin de combat :
## une fenêtre rouge par héros mort, puis le résultat (récompenses, niveaux, MVP).
func _show_result(report: Dictionary) -> void:
	last_report = report
	_show_windows(UI.make_battle_report_windows(report))


## Remplace la carte et la pause par ces fenêtres de fin, puis un bouton « Continuer ».
func _show_windows(windows: Array) -> void:
	controls.queue_free()
	arena.visible = false
	arena3d.visible = false
	view_button.visible = false
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
	for window in windows:
		box.add_child(window)

	var continue_button := UI.make_button("Continuer", func(): closed.emit())
	continue_button.custom_minimum_size.y = 90
	box.add_child(continue_button)
