extends GameSynthesis
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


## Ce que change le mode Berserk sur les valeurs de combat d'un héros (pour sa fiche) :
## [[nom, valeur de base, valeur en Berserk], ...], ou [] s'il n'a pas Berserk.
## Mêmes calculs que battle.gd (_enter_berserk) : bonus de 4 + niveau, doublé avec Surpassement.
func berserk_preview(hero: Dictionary) -> Array:
	var level := skill_level(hero["skills"], "Berserk")
	if level == 0:
		return []
	var bonus := 4 + level
	if skill_level(hero["skills"], "Surpassement") > 0:
		bonus *= SURPASS_BONUS_MULTIPLIER
	var base := combat_stats(hero)
	var gear := gear_stats(hero)
	var atk: int = base["atk"] + gear.get("atk", 0)
	var def: int = base["def"] + gear.get("def", 0)
	var crit: float = base["crit"] + gear.get("crit", 0.0)
	var magic: bool = hero["class"] in ["Mage", "Soigneur"]
	return [
		["Attaque", atk, maxi(1, atk - 10) if magic else atk + bonus],
		["Défense", def, def + roundi(bonus / 2.0)],
		["Vitesse", base["spd"], base["spd"] + bonus],
		["Critiques (%)", roundi(crit * 100), roundi((crit + bonus / 200.0) * 100)],
	]


# ---------------------------------------------------------------------------
# La Tour
# ---------------------------------------------------------------------------


## Un boss garde tous les étages multiples de ce nombre (5, 10, 15...).
const BOSS_EVERY := 5

## Un étage déjà conquis peut être rejoué (pour entraîner une nouvelle équipe ou l'équipe principale) :
## les récompenses sont réduites (0.5 = moitié) et il n'y a pas de gemmes.
const REPLAY_XP_RATE := 0.5
const REPLAY_GOLD_RATE := 0.2


## Types de quêtes d'étage : nom affiché et objectif.
## Extermination, subjugation, annihilation : tuer tous les ennemis (l'annihilation ajoute des renforts).
## Survie et défense : tenir jusqu'à la fin du compte à rebours, face à une horde.
const QUEST_TYPES := {
	"extermination": {"name": "Extermination", "objective": "Éliminer tous les ennemis."},
	"subjugation": {"name": "Subjugation", "objective": "Éliminer tous les ennemis."},
	"annihilation": {"name": "Annihilation", "objective": "Éliminer tous les ennemis, renforts compris."},
	"survival": {"name": "Survie", "objective": "Survivre à la horde jusqu'à la fin du compte à rebours."},
	"defense": {"name": "Défense", "objective": "Empêcher la cité de tomber jusqu'à la fin du compte à rebours."},
}

## Limite de temps, en secondes de combat : pour tuer tous les ennemis, ou à tenir (survie, défense).
const KILL_QUEST_SECONDS := 90
const SURVIVAL_SECONDS := 60

## Solidité des remparts d'une quête de défense : chaque coup d'un ennemi arrivé
## au pied des remparts leur retire 1 point. À 0, la cité tombe.
const DEFENSE_WALLS := 75

## Palier : tous les BOSS_EVERY étages, la difficulté monte d'un cran.
## Les ennemis de l'étage de boss et de tous les étages suivants gagnent ce nombre de niveaux en plus.
const TIER_BONUS_LEVELS := 2

## Les ennemis prennent des forces à chaque niveau (0.08 = +8 % par niveau).
const ENEMY_BONUS_PER_LEVEL := 0.08

## Monstres ordinaires de la Tour, dans l'ordre où ils apparaissent (statistiques au niveau 1).
## Leur « classe » décide de leur façon de combattre, exactement comme pour les héros.
const ENEMY_TYPES := [
	{"name": "Gobelin", "class": "Assassin", "str": 9, "int": 3, "vit": 7, "dex": 12},
	{"name": "Loup noir", "class": "Guerrier", "str": 10, "int": 2, "vit": 8, "dex": 11},
	{"name": "Squelette archer", "class": "Archer", "str": 10, "int": 3, "vit": 6, "dex": 10},
	{"name": "Golem de pierre", "class": "Chevalier", "str": 7, "int": 1, "vit": 14, "dex": 5},
	{"name": "Chaman", "class": "Soigneur", "str": 3, "int": 8, "vit": 7, "dex": 9},
	{"name": "Sorcier gobelin", "class": "Mage", "str": 3, "int": 11, "vit": 5, "dex": 8, "element": "Feu"},
]

## Boss qui gardent les étages multiples de BOSS_EVERY.
const BOSS_TYPES := [
	{"name": "Chef gobelin", "class": "Guerrier", "str": 16, "int": 4, "vit": 26, "dex": 10},
	{"name": "Minotaure", "class": "Guerrier", "str": 18, "int": 4, "vit": 30, "dex": 9},
	{"name": "Liche", "class": "Mage", "str": 4, "int": 18, "vit": 24, "dex": 10, "element": "Froid"},
	{"name": "Hydre", "class": "Chevalier", "str": 14, "int": 4, "vit": 40, "dex": 6},
]


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
# Combat
# ---------------------------------------------------------------------------

## Réserve de mana des mages et des soigneurs, par point d'Intelligence (la recharge et le coût
## des sorts sont dans battle.gd).
const MANA_PER_INT := 4


## Transforme les 4 statistiques (d'un héros ou d'un ennemi) en valeurs de combat :
## points de vie, attaque, défense, vitesse, chance de coup critique, mana.
func combat_stats(unit: Dictionary) -> Dictionary:
	var stats: Dictionary = unit["stats"]
	var magic: bool = unit["class"] in ["Mage", "Soigneur"]
	return {
		"hp": stats["vit"] * 8,
		"atk": stats["int"] if magic else stats["str"],
		"def": roundi(stats["vit"] / 2.0),
		"spd": stats["dex"],
		"crit": stats["dex"] / 200.0,
		# Mana : seulement pour les classes qui lancent des sorts (réserve = Intelligence x MANA_PER_INT).
		"mana": stats["int"] * MANA_PER_INT if magic else 0,
	}


func is_boss_floor(floor_number: int) -> bool:
	return floor_number % BOSS_EVERY == 0


## Niveau des monstres d'un étage (étage 1 : gobelins de niveau 3).
## À chaque palier (étage 5, 10...), les monstres gagnent TIER_BONUS_LEVELS niveaux de plus :
## l'étage de boss est un mur à franchir, et les étages suivants restent à ce nouveau cran.
func floor_enemy_level(floor_number: int) -> int:
	return floor_number + 2 + floor_tier(floor_number) * TIER_BONUS_LEVELS


## Numéro du palier d'un étage : 0 pour les étages 1 à 4, 1 pour 5 à 9, 2 pour 10 à 14...
func floor_tier(floor_number: int) -> int:
	return floor_number / BOSS_EVERY


## Récompenses d'un étage : de l'or (5 000 à l'étage 1, 10 000 à l'étage 4...),
## quelques gemmes, et de l'expérience pour chaque héros survivant.
## Un étage de boss rapporte trois fois plus.
func tower_rewards(floor_number: int) -> Dictionary:
	var bonus := 3 if is_boss_floor(floor_number) else 1
	return {
		"gold": roundi(5000 * (1 + (floor_number - 1) / 3.0)) * bonus,
		"gems": (30 + 5 * floor_number) * bonus,
		"xp": (10 + 5 * floor_number) * bonus,
	}


## Grade des matériaux gagnés dans la Tour, selon le palier (étages 1-4, 5-9, 10-14...).
## Chiffres provisoires : le cahier montre du « Fer (C) » dès l'étage 1, mais à la forge le grade du minerai
## donne le rang de l'arme : du C si tôt rendrait le tirage d'armes inutile. À valider avec le porteur du projet.
const TOWER_MATERIAL_GRADES := ["E", "D", "C-", "C", "C+"]


## Matériaux gagnés en conquérant un étage (cahier : « Fer (C) x1, Cuir (C) x3 » à l'étage 1,
## « Fer (C) x2, Cuir (C) x3 » à l'étage 4). Le cuir n'existe pas encore dans le jeu : le charbon le
## remplace. Un étage de boss donne en plus un cristal brut. Renvoie [{"name", "grade", "count"}].
func tower_materials(floor_number: int) -> Array[Dictionary]:
	var grade: String = TOWER_MATERIAL_GRADES[mini(floor_tier(floor_number), TOWER_MATERIAL_GRADES.size() - 1)]
	var items: Array[Dictionary] = [
		{"name": "Minerai de fer", "grade": grade, "count": 1 + floor_number / 4},
		{"name": "Charbon", "grade": grade, "count": 3 + floor_number / 6},
	]
	if is_boss_floor(floor_number):
		items.append({"name": "Cristal brut", "grade": grade, "count": 1})
	return items


## Quête d'un étage : son type, son objectif et ses règles.
## Étage 1 : extermination ; étage 2 : subjugation ; ensuite annihilation ;
## tous les 5 étages : survie face à une horde (niveau des ennemis caché) ;
## tous les 10 étages : défense de la cité, annoncée par trois avertissements.
func floor_quest(floor_number: int) -> Dictionary:
	var type := "annihilation"
	if floor_number % 10 == 0:
		type = "defense"
	elif floor_number % 5 == 0:
		type = "survival"
	elif floor_number == 1:
		type = "extermination"
	elif floor_number == 2:
		type = "subjugation"
	var quest: Dictionary = QUEST_TYPES[type].duplicate()
	quest["type"] = type
	quest["lasting"] = type in ["survival", "defense"]  # il faut tenir, pas tout tuer
	quest["seconds"] = SURVIVAL_SECONDS if quest["lasting"] else KILL_QUEST_SECONDS
	quest["warnings"] = 3 if type == "defense" else 0
	quest["hidden_level"] = type == "survival"
	# Survie (cahier) : « le décompte ne démarre qu'au premier contact avec les ennemis ».
	quest["wait_contact"] = type == "survival"
	quest["walls"] = DEFENSE_WALLS if type == "defense" else 0
	return quest


## Crée les ennemis d'un étage : de plus en plus nombreux, de plus en plus forts,
## et de nouveaux monstres apparaissent en montant. Sur un étage de boss,
## le boss prend la place de 2 monstres (il en reste toujours au moins 2 pour l'escorter).
## Au combat, 6 ennemis au plus se battent en même temps : les autres arrivent en renfort
## (annihilation : quelques-uns ; survie et défense : toute une horde).
func tower_enemies(floor_number: int) -> Array[Dictionary]:
	var quest := floor_quest(floor_number)
	var level := floor_enemy_level(floor_number)
	var enemies: Array[Dictionary] = []
	var monster_count := mini(2 + floor_number / 2, 6)
	if is_boss_floor(floor_number):
		var boss_index := mini(floor_number / BOSS_EVERY - 1, BOSS_TYPES.size() - 1)
		enemies.append(_create_enemy(BOSS_TYPES[boss_index], level + 2))
		enemies[0]["boss"] = true
		monster_count = maxi(2, monster_count - 2)
	match quest["type"]:
		"annihilation":
			monster_count += floor_number / 3
		"survival":
			monster_count += 4 + floor_number / 2
		"defense":
			monster_count += 4 + floor_number / 2
	var known_types := ENEMY_TYPES.slice(0, mini(1 + floor_number / 2, ENEMY_TYPES.size()))
	for i in monster_count:
		enemies.append(_create_enemy(known_types.pick_random(), level))
	_number_duplicates(enemies)
	return enemies


## Crée un ennemi à partir d'un modèle, renforcé selon son niveau.
func _create_enemy(template: Dictionary, level: int) -> Dictionary:
	var multiplier := 1.0 + (level - 1) * ENEMY_BONUS_PER_LEVEL
	var stats := {}
	for stat in STAT_NAMES:
		var value: float = template[stat]
		if stat != "dex":  # la vitesse change peu, pour que l'ordre d'action reste lisible
			value *= multiplier
		stats[stat] = maxi(1, roundi(value * randf_range(0.9, 1.1)))
	# « base_name » garde le nom sans lettre (Gobelin), pour regrouper les ennemis à l'affichage.
	return {"name": template["name"], "base_name": template["name"], "class": template["class"],
		"level": level, "stats": stats, "element": template.get("element", "")}


## Ajoute une lettre aux ennemis qui portent le même nom (Gobelin A, Gobelin B...),
## pour s'y retrouver dans le journal de combat.
func _number_duplicates(enemies: Array[Dictionary]) -> void:
	var counts := {}
	for enemy in enemies:
		counts[enemy["name"]] = counts.get(enemy["name"], 0) + 1
	var seen := {}
	for enemy in enemies:
		var base_name: String = enemy["name"]
		if counts[base_name] > 1:
			var index: int = seen.get(base_name, 0)
			seen[base_name] = index + 1
			enemy["name"] = "%s %s" % [base_name, char(65 + index)]


## Début d'un combat de la Tour : on le note dans la sauvegarde (voir pending_battle).
## « floor_number » : l'étage joué (un étage déjà conquis peut être rejoué, voir REPLAY_GOLD_RATE).
## Les héros prennent leurs armes dans l'arsenal au départ (gear_up) : à appeler avant Battle.new.
func start_tower_battle(team: Array, enemies: Array, quest: Dictionary, floor_number: int) -> void:
	update_training()  # les séances terminées avant le départ sont comptées
	pending_battle = {
		"floor": floor_number,
		"team": team.map(func(hero): return hero["id"]),
		"enemies": enemies.duplicate(true),
		"quest": quest,
	}
	gear_up(team)  # sauvegarde aussi la partie


## Le jeu a été fermé en plein combat : les héros se sont débrouillés seuls.
## On rejoue tout le combat sans ordres, on applique le résultat, et on le garde pour l'annoncer.
func _resolve_pending_battle() -> void:
	var team: Array[Dictionary] = []
	for hero in alive_heroes():
		if hero["id"] in pending_battle["team"]:
			team.append(hero)
	var floor_number: int = pending_battle["floor"]
	if team.is_empty():
		pending_battle = {}
		save_game()
		return
	var battle := Battle.new(team, pending_battle["enemies"], pending_battle["quest"])
	battle.run()
	absence_report = {"floor": floor_number, "report": finish_tower_battle(battle)}


## Compétences gagnées par les exploits d'un survivant pendant le combat (textes à annoncer) :
## - Tueur de gobelins : coup fatal au boss de l'étage 5 (le Chef gobelin), ou 1 point par gobelin tué ;
## - Résistance aux flammes : 1 point par combat fini dans la même équipe qu'un mage de feu.
func _combat_feats(hero: Dictionary, fighter: Dictionary, battle: Battle) -> Array[String]:
	var news: Array[String] = []
	var goblins := 0
	var boss_goblin := false
	for kill in fighter["kills"]:
		if kill["name"].to_lower().contains("gobelin"):
			goblins += 1
			if kill["boss"]:
				boss_goblin = true
	if boss_goblin and skill_level(hero["skills"], "Tueur de gobelins") == 0:
		hero["skills"].append(new_skill("Tueur de gobelins"))
		news.append("%s — exploit ! Nouvelle compétence : Tueur de gobelins" % hero["name"])
	elif goblins > 0:
		news.append_array(add_skill_progress(hero, "Tueur de gobelins", goblins, GOBLIN_KILLS_PER_LEVEL))
	for ally in battle.heroes:
		if ally["id"] != fighter["id"] and ally["class"] == "Mage" and ally["element"] == "Feu":
			news.append_array(add_skill_progress(hero, "Résistance aux flammes", 1, FIRE_MAGE_FIGHTS_PER_LEVEL))
			break
	return news


## Applique le résultat d'un combat de la Tour et renvoie un rapport pour l'écran de fin :
## - les héros tombés meurent pour toujours (sauf les immortels) ;
## - en cas de victoire : or, gemmes, expérience pour les survivants, étage suivant ;
## - en cas de défaite : les survivants gagnent quand même la moitié de l'expérience
##   (sinon une équipe bloquée ne pourrait plus jamais progresser) ;
## - un étage déjà conquis (rejoué pour entraîner une équipe) donne moins d'expérience et d'or,
##   pas de gemmes, et ne fait pas monter dans la Tour.
func finish_tower_battle(battle: Battle) -> Dictionary:
	var floor_number: int = pending_battle.get("floor", tower_floor)
	var replay := floor_number < tower_floor
	pending_battle = {}  # le combat est terminé (la sauvegarde est réécrite plus bas)
	# Les héros inscrits au terrain d'entraînement le retrouvent : la séance repart de zéro.
	for fighter in battle.heroes:
		fighter["source"]["training_since"] = Time.get_unix_time_from_system()
	var report := {
		"victory": battle.victory,
		"gold": 0,
		"gems": 0,
		"xp": 0,
		"dead": [],       # [{"hero": ..., "cause": ...}]
		"level_ups": [],  # [{"hero": ..., "levels": ...}]
		"skills": [],     # compétences apprises ou améliorées pendant le combat (textes)
		"notices": [],    # annonces spéciales (déblocages...)
		"items": [],      # objets gagnés, rangés dans l'entrepôt : [{"name", "grade", "count"}]
		"lost_weapons": [],  # armes perdues avec les héros morts (textes)
		"mvp": battle.mvp(),
		"floor": floor_number,
		"replay": replay,  # étage déjà conquis, rejoué pour s'entraîner
	}
	if battle.victory and not replay and floor_number == DAILY_UNLOCK_FLOOR:
		report["notices"].append("Félicitations, Maître ! Vous avez franchi le %de étage. Le donjon journalier est débloqué." % DAILY_UNLOCK_FLOOR)
		report["notices"].append("Conseil : rassemblez des matériaux et renforcez vos héros avant de monter plus haut.")
	for fighter in battle.heroes:
		if fighter["hp"] <= 0 and not fighter["immortal"]:
			fighter["source"]["alive"] = false
			_remove_from_teams(fighter["source"]["id"])
			# La cause est gardée sur la fiche du héros (et donc dans la sauvegarde).
			fighter["source"]["death_cause"] = fighter["killer"]
			report["dead"].append({"hero": fighter["source"], "cause": fighter["killer"]})
			# Ses armes sont perdues avec lui (tidy_arsenal les retire plus bas).
			for weapon in arsenal:
				if weapon["owner"] == fighter["source"]["id"]:
					report["lost_weapons"].append("%s : %s" % [fighter["source"]["name"], weapon_name(weapon)])

	var rewards := tower_rewards(floor_number)
	if replay:
		rewards["gold"] = roundi(rewards["gold"] * REPLAY_GOLD_RATE)
		rewards["gems"] = 0
		rewards["xp"] = roundi(rewards["xp"] * REPLAY_XP_RATE)
	if battle.victory:
		report.merge(rewards, true)
		if not replay:
			tower_floor += 1
			# Matériaux gradés, rangés dans l'entrepôt (pas en rejouant un étage : on ne les gagne qu'une fois).
			report["items"].append_array(tower_materials(floor_number))
			# Objet de promotion : un étage de boss conquis donne des pierres d'attribut.
			if is_boss_floor(floor_number):
				report["items"].append({"name": PROMOTION_STONE, "grade": "F", "count": BOSS_STONES})
			for item in report["items"]:
				add_material(item["name"], item["grade"], item["count"])
		add_gold(rewards["gold"])
		add_gems(rewards["gems"])
	else:
		report["xp"] = rewards["xp"] / 2

	for fighter in battle.heroes:
		var hero: Dictionary = fighter["source"]
		if hero["alive"]:
			# Les compétences gagnées pendant le combat sont gardées par les survivants.
			hero["skills"] = fighter["skills"]
			report["skills"].append_array(fighter["skill_news"])
			# Maîtrise de l'arc : chaque flèche tirée fait progresser la compétence.
			if fighter["shots"] > 0:
				report["skills"].append_array(add_skill_progress(hero, "Maîtrise de l'arc",
					fighter["shots"], skill_progress_needed("Maîtrise de l'arc")))
			report["skills"].append_array(_combat_feats(hero, fighter, battle))
			report["skills"].append_array(check_evolutions(hero))
			var levels := gain_xp(hero, report["xp"])
			if levels > 0:
				report["level_ups"].append({"hero": hero, "levels": levels})
	tidy_arsenal()  # armes des morts perdues, les autres reposent les leurs (et la partie est sauvegardée)
	return report


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
