extends SceneTree
## Vérifie que tous les scripts du jeu se compilent (avec les autoloads, contrairement à --check-only).
## GameData démarre (il relit et réécrit la sauvegarde) : le lancer dans une COPIE du projet (override.cfg) :
##   Godot --headless --path <copie> -s res://tools/check_scripts.gd
## Les erreurs s'affichent au-dessus du résultat.

var started := false


func _process(_delta: float) -> bool:
	if started:
		return true
	started = true
	var count := 0
	var failed := []
	for folder in ["res://scripts", "res://scripts/game_data", "res://scripts/battle"]:
		for file in DirAccess.get_files_at(folder):
			if not file.ends_with(".gd"):
				continue
			var script: GDScript = load(folder + "/" + file)
			count += 1
			if script == null or not script.can_instantiate():
				failed.append(file)
	print("%d scripts, %d en erreur %s" % [count, failed.size(), failed])
	quit(1 if not failed.is_empty() else 0)
	return true
