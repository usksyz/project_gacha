extends GameTower
## Données et règles du jeu.
## Ce script est chargé automatiquement au lancement (« autoload ») :
## n'importe quel autre script peut y accéder en écrivant GameData.
##
## Les règles suivent le cahier des charges (document « Feuille de route »).
##
## Le code est rangé en plusieurs fichiers par thème (dossier scripts/game_data/) qui s'empilent :
## chaque fichier « extends » le précédent, et GameData (ce fichier) est en haut de la pile.
## Il a donc tout ce que contiennent les autres : on écrit toujours GameData.roster, GameData.summon()...
##   game_state.gd : état de la partie (variables enregistrées), monnaies, signaux
##   heroes.gd : fiche d'un héros, compétences, expérience, équipes, favoris, où est un héros
##   training.gd : terrain d'entraînement
##   items.gd : armes (tirage, arsenal, équipement) et matériaux de l'entrepôt
##   summon.gd : invocation des héros et codes secrets
##   lobby.gd : construction et postes d'assistant, donjon journalier, forge
##   synthesis.gd : promotion et synthèse des héros
##   tower.gd : la Tour (étages, quêtes, ennemis) et le combat (début, fin, récompenses)


func _ready() -> void:
	# On reprend la partie enregistrée ; s'il n'y en a pas (premier lancement), on en commence une.
	if not load_game():
		_new_game()
	if not pending_battle.is_empty():
		_resolve_pending_battle()
	# L'entraînement et le donjon journalier ont continué pendant que le jeu était fermé,
	# puis on les fait avancer toutes les 5 secondes.
	update_expedition()
	update_training()
	tidy_arsenal()  # (anciennes sauvegardes) les héros à la cité reposent leurs armes ; voir aussi check_auto_buildings
	var timer := Timer.new()
	timer.wait_time = 5.0
	timer.timeout.connect(func():
		update_expedition()
		update_training())
	add_child(timer)
	timer.start()


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
# Mode dev (outils de test)
# ---------------------------------------------------------------------------
# Actif quand Settings.dev_mode est vrai (code secret Settings.DEV_CODE) : or et gemmes infinis
# (voir « gems » et « gold »), et ces outils, utilisés par dev_panel.gd et la fiche du héros.
# Ils passent outre les règles du jeu : à ne jamais appeler en dehors du mode dev.

## Crée un héros de la rareté voulue ; « hero_class » vide = classe tirée au hasard (mages possibles).
func dev_create_hero(rarity: int, hero_class := "") -> Dictionary:
	if hero_class == "":
		hero_class = _roll_class(rarity, true)
	var hero := _new_hero(HERO_NAMES.pick_random(), rarity, hero_class, GROWTH[rarity], [])
	if hero_class == "Mage":
		hero["element"] = MAGIC_ELEMENTS.pick_random()
	roster.append(hero)
	save_game()
	return hero


## Fait gagner « count » niveaux à un héros (sans dépasser son niveau maximum).
func dev_add_levels(hero: Dictionary, count: int) -> void:
	for i in count:
		if is_max_level(hero):
			break
		gain_xp(hero, xp_to_next(hero["level"]) - hero["xp"])
	save_game()


func dev_add_xp(hero: Dictionary, amount: int) -> void:
	gain_xp(hero, amount)
	save_game()


## Passe à l'étoile suivante gratuitement, sans attendre le niveau maximum.
func dev_promote(hero: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if hero["rarity"] >= MAX_PROMOTION_RARITY:
		return lines
	lines = _apply_promotion(hero)
	hero["level"] = mini(hero["level"], MAX_LEVEL[hero["rarity"]])
	save_game()
	return lines


func dev_add_stats(hero: Dictionary, amount: int) -> void:
	for stat in STAT_NAMES:
		hero["stats"][stat] = maxi(1, hero["stats"][stat] + amount)
	save_game()


## Donne une compétence au niveau 1 (sans vérifier les incompatibilités), ou la monte d'un niveau.
func dev_give_skill(hero: Dictionary, skill_name: String) -> void:
	for skill in hero["skills"]:
		if skill["name"] == skill_name:
			skill["level"] = mini(skill["level"] + 1, SKILL_MAX_LEVEL)
			save_game()
			return
	var skill := new_skill(skill_name)
	if skill_name in SKILL_FUSIONS:
		skill["rank"] = SKILL_FUSIONS[skill_name]["rank"]
	elif skill_name in SKILL_EVOLUTIONS:
		skill["rank"] = SKILL_EVOLUTIONS[skill_name]["rank"]
	hero["skills"].append(skill)
	save_game()


func dev_set_skill_level(hero: Dictionary, skill_name: String, level: int) -> void:
	for skill in hero["skills"]:
		if skill["name"] == skill_name:
			skill["level"] = clampi(level, 1, SKILL_MAX_LEVEL)
	save_game()


func dev_remove_skill(hero: Dictionary, skill_name: String) -> void:
	hero["skills"] = hero["skills"].filter(func(skill): return skill["name"] != skill_name)
	save_game()


## Ramène un héros mort (sans ses armes, perdues avec lui).
func dev_revive(hero: Dictionary) -> void:
	hero["alive"] = true
	hero["death_cause"] = ""
	save_game()


## Change le prochain étage de la Tour à conquérir (1 au minimum).
func dev_set_floor(floor_number: int) -> void:
	tower_floor = maxi(1, floor_number)
	save_game()


func dev_unlock_training() -> void:
	var was_unlocked := training_unlocked()
	weapon_draws = maxi(weapon_draws, TRAINING_UNLOCK_DRAWS)
	save_game()
	if not was_unlocked:
		_announce_training_ground()


## Les héros à l'entraînement (et à la cité) font une séance tout de suite.
func dev_training_session() -> void:
	update_training()
	for hero in trainees():
		if not is_away(hero):
			hero["training_since"] = Time.get_unix_time_from_system() - TRAINING_SESSION_SECONDS
	update_training()
	save_game()


## Le donjon journalier peut être refait aujourd'hui.
func dev_reset_daily() -> void:
	last_expedition_day = ""
	save_game()


## L'expédition en cours se termine tout de suite (tous ses ramassages compris).
func dev_finish_expedition() -> void:
	if expedition.is_empty():
		return
	var shift := float(expedition_remaining())
	expedition["start"] -= shift
	expedition["end"] -= shift
	update_expedition()


## Construit tous les bâtiments, gratuitement et sans conditions.
func dev_build_all() -> void:
	for building_id in BUILDINGS:
		if not building_id in buildings:
			buildings.append(building_id)
	save_game()


## Ajoute « count » de chaque matériau du donjon journalier (au grade voulu) et des pierres d'attribut.
func dev_add_materials(grade: String, count: int) -> void:
	for material in DAILY_DUNGEON["materials"]:
		add_material(material, grade, count)
	add_material(PROMOTION_STONE, "F", count)
	save_game()


## Donne tous les plans de forge.
func dev_all_plans() -> void:
	for weapon_type in WEAPON_TYPES:
		if not weapon_type in plans:
			plans.append(weapon_type)
	save_game()
