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
	update_mental()  # la santé mentale regagnée au lobby depuis la dernière fois
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
	file.set_value("partie", "expeditions", expeditions)
	file.set_value("partie", "retours_expeditions", expedition_reports)
	file.set_value("partie", "sante_mentale_maj", mental_updated_at)
	file.set_value("partie", "liens", bonds)
	file.set_value("partie", "querelles_maj", quarrels_checked_at)
	file.set_value("partie", "nouvelles_relations", relation_news)
	file.set_value("partie", "defis", pending_challenges)
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
	expeditions = file.get_value("partie", "expeditions", [])
	expedition_reports = file.get_value("partie", "retours_expeditions", [])
	mental_updated_at = file.get_value("partie", "sante_mentale_maj", 0.0)
	bonds = file.get_value("partie", "liens", {})  # absent des anciennes sauvegardes : personne ne se connaît
	quarrels_checked_at = file.get_value("partie", "querelles_maj", 0.0)
	relation_news = file.get_value("partie", "nouvelles_relations", [])
	pending_challenges = file.get_value("partie", "defis", [])
	# Anciennes sauvegardes (une seule expédition à la fois, et un seul retour) : on les reprend.
	var old_expedition: Dictionary = file.get_value("partie", "expedition", {})
	if not old_expedition.is_empty() and not file.has_section_key("partie", "expeditions"):
		expeditions = [old_expedition]
	var old_report: Dictionary = file.get_value("partie", "retour_expedition", {})
	if not old_report.is_empty() and not file.has_section_key("partie", "retours_expeditions"):
		expedition_reports = [old_report]
	# Héros d'avant la personnalité : ils reçoivent leurs traits (cachés) et une santé mentale à 100.
	for hero in roster:
		if not hero.has("traits"):
			hero["traits"] = roll_traits()
		if not hero.has("mental"):
			hero["mental"] = MENTAL_MAX
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
	expeditions = []
	expedition_reports = []
	mental_updated_at = 0.0
	bonds = {}
	quarrels_checked_at = 0.0
	relation_news = []
	pending_challenges = []
	# On commence sans héros : les héros secrets (Han compris) s'obtiennent par code.
