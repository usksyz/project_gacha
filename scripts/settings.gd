extends Node
## Paramètres du joueur (son, vibrations, plein écran...).
## Chargé automatiquement au lancement (« autoload ») : accessible partout en écrivant Settings.
## Les réglages sont enregistrés sur l'appareil, dans un petit fichier, et relus au lancement.

const FILE_PATH := "user://parametres.cfg"

## Volumes, de 0 à 100 (%).
var music_volume := 80
var sfx_volume := 80
var vibrations := true
var fullscreen := false
## Nouveaux visuels (images de la « Piste graphique » du cahier des charges) ou anciens, pour comparer.
var new_visuals := true

## Émis quand on change de visuels : les écrans concernés se redessinent.
signal visuals_changed

## Mode dev (pour tester) : activé par un code secret, il donne de l'or et des gemmes infinis
## et ouvre les outils du mode dev (Paramètres, et la fiche de chaque héros). Enregistré sur l'appareil :
## il reste actif après « Recommencer la partie », jusqu'au bouton « Quitter le mode dev ».
const DEV_CODE := "MODEDEV"
var dev_mode := false

## Émis quand le mode dev s'active ou se désactive.
signal dev_mode_changed


func _init() -> void:
	# Lu dès la création (avant les autres scripts) : GameData en a besoin au lancement (or et gemmes).
	load_settings()


func _ready() -> void:
	# Deux « bus » audio : la musique et les effets ont chacun leur volume.
	for bus_name in ["Musique", "Effets"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var index := AudioServer.bus_count
			AudioServer.add_bus(index)
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")
	_apply_volumes()
	# Sur le web, le navigateur n'autorise le plein écran qu'après un appui du joueur.
	if fullscreen and not OS.has_feature("web"):
		apply_fullscreen()


## Enregistre un réglage sur l'appareil et l'applique tout de suite.
func change(setting: String, value: Variant) -> void:
	set(setting, value)
	_apply_volumes()
	if setting == "fullscreen":
		apply_fullscreen()
	save_settings()
	if setting == "new_visuals":
		visuals_changed.emit()
	if setting == "dev_mode":
		dev_mode_changed.emit()
		# L'or et les gemmes affichés changent (infinis, ou les vraies réserves).
		GameData.gold_changed.emit(GameData.gold)
		GameData.gems_changed.emit(GameData.gems)


## Fait vibrer le téléphone (si les vibrations sont activées). « duration » en millisecondes.
func vibrate(duration: int) -> void:
	if vibrations:
		Input.vibrate_handheld(duration)


func apply_fullscreen() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func _apply_volumes() -> void:
	_set_bus_volume("Musique", music_volume)
	_set_bus_volume("Effets", sfx_volume)


func _set_bus_volume(bus_name: String, percent: int) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(index, percent == 0)
	AudioServer.set_bus_volume_db(index, linear_to_db(percent / 100.0))


func save_settings() -> void:
	var file := ConfigFile.new()
	file.set_value("son", "musique", music_volume)
	file.set_value("son", "effets", sfx_volume)
	file.set_value("jeu", "vibrations", vibrations)
	file.set_value("jeu", "plein_ecran", fullscreen)
	file.set_value("affichage", "nouveaux_visuels", new_visuals)
	file.set_value("jeu", "mode_dev", dev_mode)
	file.save(FILE_PATH)


func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(FILE_PATH) != OK:
		return  # premier lancement : on garde les valeurs par défaut
	music_volume = file.get_value("son", "musique", music_volume)
	sfx_volume = file.get_value("son", "effets", sfx_volume)
	vibrations = file.get_value("jeu", "vibrations", vibrations)
	fullscreen = file.get_value("jeu", "plein_ecran", fullscreen)
	new_visuals = file.get_value("affichage", "nouveaux_visuels", new_visuals)
	dev_mode = file.get_value("jeu", "mode_dev", dev_mode)
