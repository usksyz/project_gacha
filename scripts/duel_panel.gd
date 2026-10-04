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
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	if challenge:
		_add_button(buttons, "Refuser", _refuse)
		_add_button(buttons, "Autoriser le duel", _play)
	else:
		_add_button(buttons, "Annuler", _close)
		_add_button(buttons, "Que le duel commence", _play)


## Défi refusé : celui qui l'a lancé est vexé (voir GameData.refuse_challenge).
func _refuse() -> void:
	var line := GameData.refuse_challenge(challenger, rival)
	_new_box()
	box.add_child(UI.make_system_window("Défi refusé", [line]))
	_add_button(box, "Compris", _close)


## Le duel en direct, puis la fenêtre de fin (GameData.finish_duel).
func _play() -> void:
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
		return [UI.make_system_window("Fin du duel", GameData.finish_duel(challenger, rival, done.victory))])


func _close() -> void:
	finished.emit()
	queue_free()
