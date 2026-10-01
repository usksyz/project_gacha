extends SceneTree
# Outil (pas utilisé par le jeu ; le fichier .gdignore cache ce dossier à Godot).
# Fabrique assets/ui/icone-gemme.png à partir de piste-cristal.jpg : garde le cristal (polygone)
# en entier, et autour, seulement les flammes claires proches (halo), qui s'effacent avec la distance.
# Pour le relancer, depuis le dossier du projet :
#   Godot_v4.7.2-stable_win64_console.exe --headless -s tools/detour_gemme.gd
# (L'avertissement « Loaded resource as image file » est normal : c'est un outil, pas le jeu.)
# Avec une image plus grande, il faudra changer BOX et POLY (positions en pixels).

const SRC := "res://assets/ui/piste-cristal.jpg"
const OUT := "res://assets/ui/icone-gemme.png"
const BOX := Rect2i(196, 26, 124, 191)
# Contour du cristal (pixels de l'image d'origine) : pointe haute, droite, pointe basse, gauche.
const POLY := [Vector2(258, 37), Vector2(297, 104), Vector2(257, 213), Vector2(216, 127)]
const GROW := 3.0      # le contour est un peu agrandi
const HALO := 13.0     # portée du halo autour du cristal

func _init() -> void:
	var src := Image.load_from_file(SRC)
	var out := Image.create(BOX.size.x, BOX.size.y, false, Image.FORMAT_RGBA8)
	var center := Vector2.ZERO
	for p in POLY:
		center += p / POLY.size()
	var poly := PackedVector2Array()
	for p in POLY:
		poly.append(p + (p - center).normalized() * GROW)
	for y in BOX.size.y:
		for x in BOX.size.x:
			var p := Vector2(BOX.position.x + x, BOX.position.y + y)
			var c := src.get_pixel(int(p.x), int(p.y))
			var d := _distance_outside(p, poly)
			var alpha := 0.0
			if d <= 0.0:
				alpha = 1.0
			else:
				var edge := clampf(1.0 - d / 2.0, 0.0, 1.0)   # bord adouci
				var bright := clampf((c.get_luminance() - 0.38) / 0.3, 0.0, 1.0)
				var halo := bright * clampf(1.0 - d / HALO, 0.0, 1.0)
				alpha = maxf(edge, halo)
			c.a = alpha
			out.set_pixel(x, y, c)
	out.save_png(OUT)
	print("ok ", OUT)
	quit()

# Distance au polygone si le point est dehors, 0 (ou moins) s'il est dedans.
func _distance_outside(p: Vector2, poly: PackedVector2Array) -> float:
	if Geometry2D.is_point_in_polygon(p, poly):
		return 0.0
	var best := INF
	for i in poly.size():
		var q := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
		best = minf(best, p.distance_to(q))
	return best
