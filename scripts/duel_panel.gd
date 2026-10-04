class_name DuelPanel
extends ColorRect
## Un duel entre deux héros hostiles (voir GameData, personality.gd), par-dessus l'écran qui l'ouvre :
## la fenêtre « X défie Y ! », puis le duel en direct (BattleView), puis la fenêtre de fin.
## Deux façons de l'ouvrir :
## - depuis la fiche d'un héros, le Maître organise le duel (boutons « Que le duel commence » / « Annuler ») ;
## - un héros a lancé lui-même le défi (« challenge ») : « Autoriser le duel » ou « Refuser »
##   (un refus vexe celui qui a défié, voir GameData.refuse_challenge).

## Émis quand le panneau se ferme (duel terminé, annulé ou refusé).
signal finished

var challenger: Dictionary
var rival: Dictionary
## Vrai si c'est un défi lancé par un héros (sinon, le Maître organise le duel).
var challenge := false
var box: VBoxContainer
## Pari choisi par le Maître avant le duel : la mise (0 = pas de pari) et le numéro du héros soutenu (-1 : aucun).
var bet_stake := 0
var bet_on := -1
## Message sous le pari (pas assez d'or...).
var bet_message := ""


## Ouvre le panneau par-dessus « parent ».
static func open(parent: Node, new_challenger: Dictionary, new_rival: Dictionary, from_hero := false) -> DuelPanel:
	var panel := DuelPanel.new()
	panel.challenger = new_challenger
	panel.rival = new_rival
	panel.challenge = from_hero
	parent.add_child(panel)
	return panel


func _ready() -> void:
	color = Color(0, 0, 0, 0.85)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_show_confirm()


## Une colonne centrée de fenêtres et de boutons (vide l'ancienne).
func _new_box() -> void:
	for child in get_children():
		child.queue_free()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	box = VBoxContainer.new()
	box.custom_minimum_size.x = 600
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)


func _add_button(parent: Container, text: String, action: Callable) -> Button:
	var button := UI.make_button(text, action, 24)
	button.custom_minimum_size = Vector2(0, 84)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	return button


## La fenêtre du défi, avec ses deux boutons.
func _show_confirm() -> void:
	_new_box()
	var problem := GameData.duel_problem(challenger, rival)
	if problem != "":
		box.add_child(UI.make_system_window("Duel impossible", [problem]))
		_add_button(box, "Compris", _close)
		return
	box.add_child(UI.make_system_window("Défi" if challenge else "Duel", [
		"%s défie %s !" % [GameData.hero_label(challenger), GameData.hero_label(rival)],
		"Conseil : les duels sont un moyen de résoudre les conflits entre héros.",
		"Le duel s'arrête à %d %% de vie : personne ne meurt." % roundi(GameData.DUEL_STOP_HP * 100),
	]))
	_add_bet_section()
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	if challenge:
		_add_button(buttons, "Refuser", _refuse)
		_add_button(buttons, "Autoriser le duel", _play)
	else:
		_add_button(buttons, "Annuler", _close)
		_add_button(buttons, "Que le duel commence", _play)


## Le pari (voir GameData.bet_refusals, BET_STAKES) : si les deux héros sont d'accord, le Maître choisit
## une mise et le héros sur qui il mise. Toucher un choix déjà pris l'enlève.
func _add_bet_section() -> void:
	var lines := ["Conseil : avec l'accord des deux parties, les héros peuvent faire des paris."]
	var refusals := GameData.bet_refusals(challenger, rival)
	for hero in refusals:
		lines.append("%s refuse de parier : il n'a pas la tête à ça (santé mentale trop basse)." % hero["name"])
	if refusals.is_empty():
		lines.append("Mise de l'or sur un héros : s'il gagne, il te rapporte le double ; sinon, tu perds la mise.")
	box.add_child(UI.make_system_window("Pari", lines))
	if not refusals.is_empty():
		return

	var stakes := HBoxContainer.new()
	stakes.add_theme_constant_override("separation", 10)
	box.add_child(stakes)
	for stake in GameData.BET_STAKES:
		_add_choice(stakes, "%d or" % stake, bet_stake == stake, func():
			bet_stake = 0 if bet_stake == stake else stake)
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 10)
	box.add_child(sides)
	for hero in [challenger, rival]:
		_add_choice(sides, "Sur %s" % hero["name"], bet_on == hero["id"], func():
			bet_on = -1 if bet_on == hero["id"] else hero["id"])

	var summary := "Pas de pari."
	if bet_stake > 0 and bet_on >= 0:
		summary = "Pari : %d or sur %s." % [bet_stake, GameData.hero_by_id(bet_on)["name"]]
	elif bet_stake > 0 or bet_on >= 0:
		summary = "Choisis une mise et un héros pour parier."
	if bet_message != "":
		summary += " " + bet_message
	var label := UI.make_label(summary, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)


## Un choix du pari : doré quand il est pris. Le toucher change le pari et redessine la fenêtre.
func _add_choice(parent: Container, text: String, chosen: bool, action: Callable) -> void:
	var button := UI.make_button(text, func():
		action.call()
		bet_message = ""
		_show_confirm.call_deferred(), 20)
	button.custom_minimum_size = Vector2(0, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if chosen:
		button.add_theme_color_override("font_color", Color("f5c542"))
		button.text = "[ %s ]" % text
	parent.add_child(button)


## Le pari prêt à être joué ({"stake", "on"}), ou {} : pas de pari (ou pari incomplet).
func _bet() -> Dictionary:
	if bet_stake > 0 and bet_on >= 0 and GameData.bet_refusals(challenger, rival).is_empty():
		return {"stake": bet_stake, "on": bet_on}
	return {}


## Défi refusé : celui qui l'a lancé est vexé (voir GameData.refuse_challenge).
func _refuse() -> void:
	var line := GameData.refuse_challenge(challenger, rival)
	_new_box()
	box.add_child(UI.make_system_window("Défi refusé", [line]))
	_add_button(box, "Compris", _close)


## Le duel en direct, puis la fenêtre de fin (GameData.finish_duel).
func _play() -> void:
	# La mise est payée avant le duel ; sans assez d'or, on reste sur la fenêtre.
	var bet := _bet()
	if not bet.is_empty() and not GameData.place_bet(bet["stake"]):
		bet_message = "Pas assez d'or pour cette mise."
		_show_confirm.call_deferred()
		return
	if challenge:
		GameData.drop_challenge(challenger, rival)
	for child in get_children():
		child.queue_free()
	color = Color("101119")
	var view := BattleView.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(view)
	view.closed.connect(_close)
	var battle := Battle.new([challenger], [rival], GameData.duel_quest())
	battle.start()
	view.play(battle, "Duel : %s contre %s" % [challenger["name"], rival["name"]], func(done: Battle) -> Array:
		return [UI.make_system_window("Fin du duel", GameData.finish_duel(challenger, rival, done.victory, bet))])


func _close() -> void:
	finished.emit()
	queue_free()
