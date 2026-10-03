class_name GameSave
extends GameTower
## La sauvegarde de la partie (écrire, relire, effacer) et la partie neuve.
## Fait partie de la pile de GameData (voir game_data.gd) : c'est l'avant-dernier fichier, il voit
## donc tout ce qui est enregistré. Sa fonction save_game() remplace celle de game_state.gd.


# ---------------------------------------------------------------------------
# Sauvegarde
# ---------------------------------------------------------------------------
# La partie est enregistrée sur l'appareil, dans le dossier « user:// » de Godot
# (sur le web : le stockage du navigateur). Elle est réécrite après chaque changement
# (invocation, combat, code secret, gemmes ou or gagnés) et relue au lancement.
# ConfigFile garde les types (un nombre entier reste un entier), contrairement au JSON.

const SAVE_PATH := "user://sauvegarde.cfg"

## Numéro du format de sauvegarde : à augmenter si on change ce qui est enregistré,
## pour pouvoir adapter les anciennes sauvegardes.
const SAVE_VERSION := 1


## Enregistre toute la partie : monnaies, étage, héros (morts compris), codes utilisés.
func save_game() -> void:
	check_auto_buildings()  # un changement peut remplir la condition d'un bâtiment (nouveau mage...)
	var file := ConfigFile.new()
	file.set_value("partie", "version", SAVE_VERSION)
	file.set_value("partie", "gemmes", real_gems)
	file.set_value("partie", "or", real_gold)
	file.set_value("partie", "pity", pity_counter)
	file.set_value("partie", "etage", tower_floor)
	file.set_value("partie", "prochain_id", next_hero_id)
	file.set_value("partie", "codes_utilises", used_codes)
	file.set_value("partie", "heros", roster)
	file.set_value("partie", "equipes", teams)
	file.set_value("partie", "combat_en_cours", pending_battle)
	file.set_value("partie", "nouvelles_entrainement", training_news)
	file.set_value("partie", "arsenal", arsenal)
	file.set_value("partie", "prochaine_arme", next_weapon_id)
	file.set_value("partie", "armes_tirees", weapon_draws)
	file.set_value("partie", "batiments", buildings)
	file.set_value("partie", "entrepot", warehouse)
	file.set_value("partie", "plans", plans)
	file.set_value("partie", "expedition", expedition)
	file.set_value("partie", "derniere_expedition", last_expedition_day)
	file.set_value("partie", "retour_expedition", expedition_report)
	file.save(SAVE_PATH)


## Relit la partie enregistrée. Renvoie false s'il n'y a pas de sauvegarde lisible.
func load_game() -> bool:
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) != OK:
		return false
	real_gems = file.get_value("partie", "gemmes", 3000)
	real_gold = file.get_value("partie", "or", 0)
	pity_counter = file.get_value("partie", "pity", 0)
	tower_floor = file.get_value("partie", "etage", 1)
	next_hero_id = file.get_value("partie", "prochain_id", 1)
	# « assign » recopie la liste lue dans nos listes typées (Array[String], Array[Dictionary]).
	used_codes.assign(file.get_value("partie", "codes_utilises", []))
	roster.assign(file.get_value("partie", "heros", []))
	teams = file.get_value("partie", "equipes", _empty_teams())
	while teams.size() < TEAM_COUNT:
		teams.append([])
	pending_battle = file.get_value("partie", "combat_en_cours", {})
	training_news = file.get_value("partie", "nouvelles_entrainement", [])
	arsenal = file.get_value("partie", "arsenal", [])
	next_weapon_id = file.get_value("partie", "prochaine_arme", 1)
	weapon_draws = file.get_value("partie", "armes_tirees", 0)
	buildings = file.get_value("partie", "batiments", [])
	warehouse = file.get_value("partie", "entrepot", {})
	plans = file.get_value("partie", "plans", [])
	expedition = file.get_value("partie", "expedition", {})
	last_expedition_day = file.get_value("partie", "derniere_expedition", "")
	expedition_report = file.get_value("partie", "retour_expedition", {})
	return not roster.is_empty()


## Efface la sauvegarde (utilisé par « Recommencer la partie »).
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


# ---------------------------------------------------------------------------
# Nouvelle partie
# ---------------------------------------------------------------------------

## « Recommencer la partie » (depuis les paramètres) : efface la sauvegarde et repart de zéro.
func reset_game() -> void:
	delete_save()
	_new_game()


## Prépare une partie neuve.
func _new_game() -> void:
	real_gems = 3000
	real_gold = 0
	pity_counter = 0
	tower_floor = 1
	roster.clear()
	next_hero_id = 1
	used_codes.clear()
	teams = _empty_teams()
	pending_battle = {}
	absence_report = {}
	training_news = []
	arsenal = []
	next_weapon_id = 1
	weapon_draws = 0
	buildings = []
	warehouse = {}
	plans = []
	expedition = {}
	last_expedition_day = ""
	expedition_report = {}
	# On commence sans héros : les héros secrets (Han compris) s'obtiennent par code.
