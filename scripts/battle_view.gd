class_name BattleView
extends Control
## Écran de combat, en direct, en vue isométrique 3D (BattleView3D).
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

## Couleur de chaque type de case (voir BattleMap.Kind ; l'aperçu de l'étage, FloorPreview, s'en sert) ; plus claire
## à chaque niveau de hauteur
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

## Portraits de l'équipe : hauteur de la rangée, couleurs des barres (cahier : vie rouge, mana bleue).
const PORTRAIT_HEIGHT := 106
const HP_COLOR := Color("e04848")
const MANA_COLOR := Color("4a8fe8")
## Endurance (sous la vie) : jaune, grise quand le héros est épuisé.
const STAMINA_COLOR := Color("e8c547")
const STAMINA_TIRED_COLOR := Color("7a7466")
## Perception (C3) : bâtonnets du héros choisi (traits fins et point lumineux au bout), ennemis que personne ne voit.
const RAY_COLOR := Color(0.55, 0.95, 1.0, 0.4)
const RAY_DOT_COLOR := Color(0.75, 1.0, 1.0, 0.95)
const UNSEEN_COLOR := Color(0.38, 0.38, 0.42, 0.75)
## Mode dev (IA tactique) : la case choisie par le héros choisi.
const TACTIC_COLOR := Color("ff7ad9")

var battle: Battle
var layout: VBoxContainer
var title_label: Label
var clock_label: Label
var hint_label: Label
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
## « Œil de faucon » (C3) : pour un héros choisi qui l'a, quand il peut l'activer.
var hawk_button: Button

## La vue isométrique 3D (Combat v2, C2 : BattleView3D) : la seule vue du combat depuis que la vue de dessus a été
## retirée (anciens visuels compris).
var arena3d: BattleView3D

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
## (Le Maître ne place plus ses héros avant le combat depuis l'étape E : ils explorent, voir BattleExplore.)
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

	# Le champ de bataille en vue isométrique 3D (on le touche pour donner des ordres). La vue de dessus a été retirée
	# (demande du porteur du projet : moins belle, et la 3D suffit).
	arena3d = BattleView3D.new()
	arena3d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena3d.tapped.connect(_arena_tap)
	layout.add_child(arena3d)
	arena3d.setup(self)

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
	hawk_button = UI.make_button("Œil de faucon", _order_hawk_eye, 22)
	hawk_button.custom_minimum_size.y = 80
	hawk_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hawk_button.add_theme_color_override("font_color", Color("9fd3ff"))
	hawk_button.visible = false
	controls.add_child(hawk_button)
	# Jusqu'à cinq boutons côte à côte : leur texte passe à la ligne plutôt que d'élargir l'écran.
	for button in [berserk_button, swap_button, barrage_button, hawk_button]:
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pause_button = UI.make_button("Pause", _toggle_pause, 26)
	pause_button.custom_minimum_size.y = 80
	pause_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(pause_button)


func _toggle_pause() -> void:
	paused = not paused
	pause_button.text = "Reprendre" if paused else "Pause"
	selected_id = -1  # pas d'ordre pendant la pause
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
	if Settings.dev_mode and selected_id >= 0 and not paused:
		hint_label.text = tactic_text(battle.units[selected_id])  # (son plan change en direct)
	_update_clock()
	# Les effets trop vieux pour être montrés (coups, chiffres, bulles) : on ne les parcourt plus.
	while first_effect < battle.effects.size() and battle.effects[first_effect]["t"] < battle.time - BUBBLE_TIME:
		first_effect += 1
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
	portraits.queue_redraw()


func _update_clock() -> void:
	var limit: float = battle.quest["seconds"]
	var text := ""
	if battle.clock_start < 0:
		text = "%s au premier contact" % _format_time(limit)  # survie, et hors horde (étape E) : le décompte attend
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
	elif paused and Settings.dev_mode and selected_id >= 0:
		hint_label.text = "Pause. " + tactic_text(battle.units[selected_id])  # (mode dev : on inspecte son plan)
	elif paused:
		hint_label.text = "Pause. Les ordres reprendront avec le combat."
	elif selected_id >= 0:
		hint_label.text = "%s : touche un endroit pour l'y envoyer, un ennemi à attaquer, ou un bouton en bas." \
			% battle.units[selected_id]["name"]
		if Settings.dev_mode:
			hint_label.text = tactic_text(battle.units[selected_id])  # (mode dev : son plan et ses raisons)
		elif not battle.height_cells().is_empty():
			hint_label.text += " Touche un toit pour l'y envoyer." \
				+ " On monte par les échelles et les escaliers ; d'en haut, on frappe plus fort et on tire plus loin."
	else:
		hint_label.text = "Touche un héros pour le guider."
	_update_berserk_button()


## Mode dev (IA tactique, C3) : l'attitude du héros, sa case et ses 3 raisons.
const ATTITUDE_NAMES := {"attendre": "attend", "engager": "engage", "distance": "garde ses distances",
	"couvrir": "se couvre", "proteger": "protège", "decrocher": "décroche", "poste": "tient son poste"}


func tactic_text(hero: Dictionary) -> String:
	var plan: Dictionary = hero.get("tactic", {})
	if not battle.tactical_ai:
		return "%s : IA tactique coupée (tous foncent)." % hero["name"]
	# (étape E) Sans ennemi connu, il explore : son rôle, et la disposition des ennemis (ce que le Maître ne sait pas).
	if hero["knows"].is_empty() and battle.explore != null and battle.alert.disposition != "horde" \
			and hero["order"].is_empty() and not hero["held"]:
		var marks := ""
		if battle.terrain != null:  # (recensement « Techniques », point 4) l'annotation de la carte
			var counts: Dictionary = battle.terrain.summary()
			marks = " Carte : %d goulets, %d points hauts, %d cachettes." % [counts["goulets"], counts["points hauts"], counts["cachettes"]]
		return "%s : aucun ennemi connu, il explore (%s). Disposition : %s%s.%s" % [hero["name"], battle.explore.role_text(hero),
			GameData.DISPOSITION_NAMES.get(battle.alert.disposition, ""), " (alarme donnée)" if battle.alert.alarm else "", marks]
	if plan.is_empty():
		return "%s : aucun ennemi connu, il attend à son poste." % hero["name"]
	var text: String = "%s %s" % [hero["name"], ATTITUDE_NAMES.get(plan["attitude"], plan["attitude"])]
	if plan["target"] >= 0:
		text += " (cible : %s)" % battle.units[plan["target"]]["name"]
	var why: Array = plan["reasons"].map(func(r): return r["why"])
	if not why.is_empty():
		text += " — " + " ; ".join(why)
	return text


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
	var hawk_shown: bool = not paused and not hero.is_empty() and not _is_duel() and battle.can_hawk_eye(hero)
	if hawk_button.visible != hawk_shown:
		hawk_button.visible = hawk_shown


## Ordre du Maître : le héros choisi part se reposer à l'arrière, un allié frais prend sa place.
func _order_swap() -> void:
	if selected_id < 0 or paused or battle.finished:
		return
	battle.order_swap(battle.units[selected_id])
	Settings.vibrate(30)
	selected_id = -1
	_update_hint()
	portraits.queue_redraw()


## Ordre du Maître : l'archer choisi tire toutes ses flèches d'un coup (il peut refuser, voir Battle.order_barrage).
func _order_barrage() -> void:
	if selected_id < 0 or paused or battle.finished:
		return
	battle.order_barrage(battle.units[selected_id])
	Settings.vibrate(30)
	selected_id = -1
	_update_hint()
	portraits.queue_redraw()


## Ordre du Maître : le héros choisi active Œil de faucon (il peut refuser, voir Battle.order_hawk_eye).
func _order_hawk_eye() -> void:
	if selected_id < 0 or paused or battle.finished:
		return
	battle.order_hawk_eye(battle.units[selected_id])
	Settings.vibrate(30)
	_update_hint()


## Ordre du Maître : le héros choisi entre en rage, ou en sort (il peut refuser, voir Battle.order_berserk).
func _order_berserk() -> void:
	if selected_id < 0 or paused or battle.finished:
		return
	var hero: Dictionary = battle.units[selected_id]
	battle.order_berserk(hero, not hero["berserk"])
	Settings.vibrate(30)
	selected_id = -1
	_update_hint()
	portraits.queue_redraw()


## Un toucher sur le champ de bataille (vue 3D) : « touched » le combattant touché ({} sinon),
## « map_pos » le point de la carte (en cases), « inside » s'il est sur la carte.
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



# ---------------------------------------------------------------------------
# Couleurs et outils de dessin (la vue 3D, BattleView3D, s'en sert ; la vue de dessus a été retirée)
# ---------------------------------------------------------------------------

## Étape E, point 3 : les pièges posés par les héros (le Maître les voit : ses héros savent où ils sont), une croix brune.
const TRAP_COLOR := Color("c08040")

const CORPSE_COLOR := Color(0.35, 0.33, 0.32, 0.8)
const CORPSE_FOUND_COLOR := Color(0.6, 0.2, 0.2, 0.85)


## La couleur de la jauge de détection d'un monstre : jaune (méfiant), orange (il vient voir), rouge (presque pleine).
static func detect_color(level: float) -> Color:
	if level < GameData.DETECT_SUSPECT:
		return Color("fff070").darkened(0.25)
	if level < GameData.DETECT_INVESTIGATE:
		return Color("fff070")
	return Color("ffb060").lerp(Color("ff4040"), clampf((level - GameData.DETECT_INVESTIGATE) / (1.0 - GameData.DETECT_INVESTIGATE), 0.0, 1.0))


## Vrai si un ennemi n'est vu (ni entendu) par aucun héros : on le grise (pas de brouillard total).
func unseen(unit: Dictionary) -> bool:
	return not unit["is_hero"] and battle.perception_on and battle.perception != null \
		and battle.perception.updated_at >= 0.0 and not battle.perception.seen_by_heroes.has(unit["id"])


## Étape C : chiffres empilés. Pour chaque chiffre encore visible, son rang parmi ceux de la même cible (0 = le plus
## récent, en bas ; les plus anciens montent d'une ligne par chiffre plus récent) : ils ne se chevauchent plus.
const FLOAT_LINE := 17.0


static func float_ranks(fight: Battle, first: int) -> Dictionary:
	var ranks := {}
	var counts := {}
	for i in range(fight.effects.size() - 1, first - 1, -1):
		var effect: Dictionary = fight.effects[i]
		if effect["kind"] == "refuse" or fight.time - effect["t"] > FLOAT_TIME:
			continue
		ranks[i] = counts.get(effect["to"], 0)
		counts[effect["to"]] = ranks[i] + 1
	return ranks



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
	arena3d.visible = false
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
