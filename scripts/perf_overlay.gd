class_name PerfOverlay
extends CanvasLayer
## L'affichage des performances (demande du porteur du projet : « affichage des perf du matériel hors mode dev,
## option dans les réglages » ; Paramètres > Jeu > « Performances »). Un petit encart en haut à gauche, par-dessus
## tous les écrans : images par seconde, temps d'une image, appels de dessin, mémoire, puis le matériel (carte
## graphique, processeur, système). Mis à jour deux fois par seconde. Rien ne change dans le jeu.

const REFRESH := 0.5

var _label: Label
var _wait := 0.0
## Le matériel (lu une fois : il ne change pas pendant la partie).
var _hardware := ""


func _ready() -> void:
	layer = 100  # (au-dessus de tout, fenêtres comprises)
	_label = Label.new()
	_label.position = Vector2(6, 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color("9fe0a0"))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("outline_size", 4)
	# (texte long : il passe à la ligne plutôt que de sortir de l'écran du téléphone)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size.x = get_viewport().get_visible_rect().size.x - 12.0
	add_child(_label)
	var adapter := RenderingServer.get_video_adapter_name()
	_hardware = "%s · %s (%d cœurs) · %s" % [adapter if adapter != "" else "carte graphique inconnue",
		OS.get_processor_name() if OS.get_processor_name() != "" else "processeur inconnu", OS.get_processor_count(),
		OS.get_name()]
	Settings.perf_changed.connect(_apply)
	_apply()


func _apply() -> void:
	visible = Settings.show_perf
	_wait = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = REFRESH
	var fps := Engine.get_frames_per_second()
	var frame_ms := 1000.0 / maxf(1.0, fps)
	var calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var memory := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	_label.text = "%d images/s · %.1f ms · %d appels de dessin · %.0f Mo\n%s" % [fps, frame_ms, calls, memory, _hardware]
