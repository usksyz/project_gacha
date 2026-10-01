class_name GemIcon
extends Control
## Icône des gemmes (nouveaux visuels) : le cristal détouré de piste-cristal.jpg
## (assets/ui/icone-gemme.png, fabriqué par tools/detour_gemme.gd), qui lévite doucement en boucle.
## Exemple : row.add_child(GemIcon.new(32)) pour une icône de 32 pixels de haut.

const IMAGE := preload("res://assets/ui/icone-gemme.png")
## Hauteur de la lévitation (part de la hauteur de l'icône) et durée d'une montée.
const FLOAT_HEIGHT := 0.08
const FLOAT_SECONDS := 1.4

var art: TextureRect


func _init(height: float) -> void:
	custom_minimum_size = Vector2(roundf(height * IMAGE.get_width() / IMAGE.get_height()), height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER  # centré sur la ligne de texte, pas étiré
	art = TextureRect.new()
	art.texture = IMAGE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.size = custom_minimum_size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)


## La lévitation : le cristal monte et descend sans fin (mouvement adouci, comme une respiration).
func _ready() -> void:
	var amplitude := custom_minimum_size.y * FLOAT_HEIGHT
	art.position.y = amplitude
	var tween := create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(art, "position:y", -amplitude, FLOAT_SECONDS)
	tween.tween_property(art, "position:y", amplitude, FLOAT_SECONDS)
