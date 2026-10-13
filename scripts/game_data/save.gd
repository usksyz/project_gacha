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
## 2 : les héros secrets ne sont plus immortels (feuille de route v2).
## 3 : personnalité v2 (hero["persona"], voir PersonalityEngine) ; les héros d'avant la reçoivent au chargement.
## 4 : les anciens traits (hero["traits"]) se lisent sur les paliers : chaque héros garde les siens (paliers
##     poussés juste au seuil, PersonalityEngine.migrate), les drapeaux « révélé » passent dans
##     hero["revealed_traits"] ; les héros secrets prennent leur profil écrit à la main.
## 5 : P1b, structures de la personnalité (8 briques, cercles, sujets ; PersonalityEngine.migrate), journal
##     des derniers combats (hero["recent_battles"]), bibliothèque et mémorial du Maître (absents = vides).
const SAVE_VERSION := 5


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
	file.set_value("partie", "conseils_vus", seen_tips)
	file.set_value("partie", "tutoriel", tutorial_step)
	file.set_value("partie", "bibliotheque", library)
	file.set_value("partie", "memorial", memorial)
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
	# Conseils du Système : une partie d'avant les conseils n'est pas celle d'un nouveau joueur, on les
	# compte comme vus (Paramètres > « Réafficher les conseils » pour les revoir).
	seen_tips = file.get_value("partie", "conseils_vus", TIP_IDS.duplicate())
	tutorial_step = file.get_value("partie", "tutoriel", "")  # partie d'avant le tutoriel : pas de tutoriel
	# Bibliothèque (version 5) : absente d'une ancienne sauvegarde = vide.
	library = Library.migrate(file.get_value("partie", "bibliotheque", Library.new_library()))
	memorial = Memorial.migrate(file.get_value("partie", "memorial", Memorial.new_memorial()))
	# Anciennes sauvegardes (une seule expédition à la fois, et un seul retour) : on les reprend.
	var old_expedition: Dictionary = file.get_value("partie", "expedition", {})
	if not old_expedition.is_empty() and not file.has_section_key("partie", "expeditions"):
		expeditions = [old_expedition]
	var old_report: Dictionary = file.get_value("partie", "retour_expedition", {})
	if not old_report.is_empty() and not file.has_section_key("partie", "retours_expeditions"):
		expedition_reports = [old_report]
	# Sauvegarde d'avant la version 2 : les héros secrets y étaient immortels, ils deviennent mortels
	# (la case « Immortel » du mode dev part décochée).
	var version: int = file.get_value("partie", "version", 1)
	for hero in roster:
		if version < 2 and hero.get("secret", false):
			hero["immortal"] = false
	# Héros d'avant la personnalité : une santé mentale à 100 (leurs traits viennent de leur profil, plus bas).
	for hero in roster:
		if not hero.has("mental"):
			hero["mental"] = MENTAL_MAX
	# Héros d'avant la personnalité v2 : leur profil est tiré maintenant (un par un, chacun comparé à ceux
	# déjà tirés, comme à l'invocation) ; un profil plus ancien est complété ; ceux d'avant la version 4 gardent
	# leurs anciens traits, et les héros secrets prennent leur profil écrit à la main (PersonalityEngine.migrate).
	for hero in roster:
		PersonalityEngine.migrate(hero, roster)
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
	# Tutoriel : de quoi payer exactement l'invocation normale x10 qu'il impose.
	real_gold = SUMMON_TYPES["normal"]["cost"] * TUTORIAL_SUMMON_COUNT
	tutorial_step = TUTORIAL_STEPS[0]
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
	seen_tips = []  # partie neuve : le Système accueille le Maître (voir show_tip)
	library = Library.new_library()
	memorial = Memorial.new_memorial()
	# On commence sans héros : les héros secrets (Han compris) s'obtiennent par code.
