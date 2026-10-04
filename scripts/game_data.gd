extends GameSave
## Données et règles du jeu.
## Ce script est chargé automatiquement au lancement (« autoload ») :
## n'importe quel autre script peut y accéder en écrivant GameData.
##
## Les règles suivent le cahier des charges (document « Feuille de route »).
##
## Le code est rangé en plusieurs fichiers par thème (dossier scripts/game_data/) qui s'empilent :
## chaque fichier « extends » le précédent, et GameData (ce fichier) est en haut de la pile.
## Il a donc tout ce que contiennent les autres : on écrit toujours GameData.roster, GameData.summon()...
## Un fichier ne peut utiliser que ce qui est dans les fichiers d'en dessous (plus haut dans cette liste) ;
## seule exception, save_game(), déclarée dans game_state.gd et remplacée par la vraie dans save.gd.
##   game_state.gd : état de la partie (variables enregistrées), monnaies, signaux
##   heroes.gd : fiche d'un héros, compétences, expérience, équipes, favoris, où est un héros
##   personality.gd : personnalité (santé mentale, traits de caractère)
##   training.gd : terrain d'entraînement
##   items.gd : armes (tirage, arsenal, équipement) et matériaux de l'entrepôt
##   summon.gd : invocation des héros et codes secrets
##   lobby.gd : construction et postes d'assistant, donjon journalier, forge
##   synthesis.gd : promotion et synthèse des héros
##   tower.gd : la Tour (étages, quêtes, ennemis) et le combat (début, fin, récompenses)
##   save.gd : sauvegarde (écrire, relire, effacer) et partie neuve
##   game_data.gd (ici) : le lancement du jeu et les outils du mode dev


# ---------------------------------------------------------------------------
# Lancement du jeu
# ---------------------------------------------------------------------------

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
	update_quarrels()
	timer.timeout.connect(func():
		update_expedition()
		update_training()
		update_mental()
		update_quarrels())
	add_child(timer)
	timer.start()


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


## Les expéditions en cours se terminent tout de suite (tous leurs ramassages compris).
func dev_finish_expedition() -> void:
	for expedition in expeditions:
		var shift := float(expedition_remaining(expedition))
		expedition["start"] -= shift
		expedition["end"] -= shift
	update_expedition()


## Change la santé mentale d'un héros (sans Calme ni traits).
func dev_change_mental(hero: Dictionary, amount: float) -> void:
	change_mental(hero, amount)
	save_game()


## Monte d'un cran le lien entre un héros et un autre héros vivant, trouvé par son nom (sans tenir compte
## des majuscules). Renvoie le texte à afficher.
func dev_raise_bond(hero: Dictionary, partner_name: String) -> String:
	var other := _dev_find_partner(hero, partner_name)
	if other.is_empty():
		return _dev_partner_missing(partner_name)
	var level := bond_level(hero, other)
	if level >= BOND_BROTHERS:
		return "%s et %s sont déjà frères d'armes." % [hero["name"], other["name"]]
	var line := set_bond_level(hero, other, level + 1)
	save_game()
	if level == BOND_HOSTILE:
		return "%s et %s ne sont plus hostiles." % [hero["name"], other["name"]]
	return line


## Rend un héros hostile envers un autre héros vivant, trouvé par son nom. Renvoie le texte à afficher.
func dev_make_hostile(hero: Dictionary, partner_name: String) -> String:
	var other := _dev_find_partner(hero, partner_name)
	if other.is_empty():
		return _dev_partner_missing(partner_name)
	var line := make_hostile(hero, other)
	save_game()
	return line


## Un autre héros vivant nommé « partner_name » (sans tenir compte des majuscules), ou {}.
func _dev_find_partner(hero: Dictionary, partner_name: String) -> Dictionary:
	var wanted := partner_name.strip_edges().to_lower()
	for other in alive_heroes():
		if wanted != "" and other["id"] != hero["id"] and other["name"].to_lower() == wanted:
			return other
	return {}


func _dev_partner_missing(partner_name: String) -> String:
	if partner_name.strip_edges() == "":
		return "Écris d'abord le nom d'un autre héros."
	return "Aucun autre héros vivant ne s'appelle « %s »." % partner_name.strip_edges()


## Met un héros « En rupture », santé mentale à 0 (pour tester la rupture et la mort de stress).
func dev_break(hero: Dictionary) -> void:
	hero["mental"] = 0.0
	break_hero(hero)
	save_game()


## Passe le tutoriel : il s'arrête là (rien n'est donné), ses fenêtres sont comptées comme vues.
func dev_skip_tutorial() -> void:
	for tip_id in TIP_IDS:
		if is_tutorial_tip(tip_id) and not tip_id in seen_tips:
			seen_tips.append(tip_id)
	end_tutorial()
	save_game()


## Construit tous les bâtiments, gratuitement et sans conditions.
func dev_build_all() -> void:
	for building_id in BUILDINGS:
		if not building_id in buildings:
			buildings.append(building_id)
	save_game()


## Ajoute « count » de chaque matériau des donjons journaliers (au grade voulu) et des pierres d'attribut.
func dev_add_materials(grade: String, count: int) -> void:
	for dungeon_id in DAILY_DUNGEONS:
		for material in DAILY_DUNGEONS[dungeon_id]["materials"]:
			add_material(material, grade, count)
	add_material(PROMOTION_STONE, "F", count)
	save_game()


## Donne tous les plans de forge.
func dev_all_plans() -> void:
	for weapon_type in WEAPON_TYPES:
		if not weapon_type in plans:
			plans.append(weapon_type)
	save_game()
