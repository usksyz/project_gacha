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
	update_requests()
	timer.timeout.connect(func():
		update_expedition()
		update_training()
		update_mental()
		update_quarrels()
		update_requests())  # (prompt 4) demandes des héros
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
		hero_class = _roll_class(rarity, rarity >= 3)  # (mages : 3 étoiles et plus, comme à l'invocation spéciale)
	var hero := _new_hero(HERO_NAMES.pick_random(), rarity, hero_class, GROWTH[rarity], [])
	if hero_class == "Mage":
		hero["element"] = MAGIC_ELEMENTS.pick_random()
	roster.append(hero)
	save_game()
	return hero


## (prompt 4) Une demande d'un héros tout de suite (si quelqu'un a quelque chose à demander). Renvoie le texte.
func dev_force_request() -> String:
	var request := roll_request()
	if request.is_empty():
		return "Personne n'a rien à demander (il faut un héros sans équipe ambitieux, loyal ou ami d'un membre, ou un héros fatigué au travail)."
	pending_requests.append(request)
	save_game()
	requests_changed.emit()
	return "Demande ajoutée (%s)." % request["reason"]


## (prompt 4) Le rapport du jour de la fée sera de nouveau montré.
func dev_reset_daily_report() -> void:
	daily_report_day = ""
	save_game()
	requests_changed.emit()  # (main.gd regarde alors s'il doit montrer le rapport)


## Rend l'invocation gratuite du jour (comme si elle n'avait pas encore été prise).
func dev_reset_free_summon() -> void:
	free_summon_day = ""
	save_game()


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


## Coche ou décoche la case « Immortel » d'un héros (elle n'agit qu'en mode dev, voir is_immortal).
func dev_set_immortal(hero: Dictionary, on: bool) -> void:
	hero["immortal"] = on
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


## Personnalité v2 (fiche du héros, curseurs par famille) : fixe le palier d'un axe (-10 à +10).
func dev_set_axis_tier(hero: Dictionary, axis_id: String, value: int) -> void:
	PersonalityEngine.set_tier(hero, axis_id, value)
	save_game()


## Ajoute des points d'évolution à un axe (comme le feront les épreuves) ; renvoie le texte des paliers
## franchis et des accès ouverts ou fermés.
func dev_add_evolution(hero: Dictionary, axis_id: String, points: float) -> Array[String]:
	var lines: Array[String] = []
	var axis_name: String = PersonalityData.AXES[axis_id]["name"]
	for crossing in PersonalityEngine.gain_evolution(hero, axis_id, points):
		lines.append("%s : %d → %d (%s)" % [axis_name, crossing["from"] * 10, crossing["to"] * 10,
			PersonalityEngine.tier_name(crossing["to"])])
		for access_id in crossing["opened"]:
			lines.append("Nouvel accès : %s" % PersonalityEngine.access_text(access_id))
		for access_id in crossing["closed"]:
			lines.append("Accès perdu : %s" % PersonalityEngine.access_text(access_id))
	if lines.is_empty():
		var evo: float = hero["persona"]["evo"][axis_id]
		lines.append("%s : %+.1f points d'évolution, pas de nouveau palier." % [axis_name, evo])
	save_game()
	return lines


## Tire une nouvelle personnalité pour ce héros (comparée aux autres héros vivants ; un héros secret
## reprend son profil écrit à la main). Ses anciens traits suivent ses nouveaux paliers.
func dev_reroll_personality(hero: Dictionary) -> void:
	var others := roster.filter(func(other): return other["id"] != hero["id"])
	hero["persona"] = PersonalityEngine.new_persona(hero["name"], hero["rarity"], others, hero.get("secret", false))
	save_game()


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


## Ajoute « count » de chaque matériau des donjons journaliers (au grade voulu), des pierres d'attribut
## et des potions de soin.
func dev_add_materials(grade: String, count: int) -> void:
	for dungeon_id in DAILY_DUNGEONS:
		for material in DAILY_DUNGEONS[dungeon_id]["materials"]:
			add_material(material, grade, count)
	add_material(PROMOTION_STONE, "F", count)
	add_material(POTION, "F", count)
	save_game()


## Donne tous les plans de forge.
func dev_all_plans() -> void:
	for weapon_type in WEAPON_TYPES:
		if not weapon_type in plans:
			plans.append(weapon_type)
	save_game()


# --- Personnalité P1b : sujets, bibliothèque, mémorial (aucun effet en jeu ; pour voir les données) ---

## Une rencontre simulée avec un sujet (« danger » vécu de 0 à 100), comme les combats le feront en P2.
func dev_subject_encounter(hero: Dictionary, subject: String, danger: float) -> String:
	var result := PersonalityEngine.after_encounter(hero, subject, {"danger": danger, "mode": "fought", "hits": 3, "dodges": 1})
	save_game()
	return "%s, %s : appréhension %.0f → %.0f, connaissance %d → %d%s%s" % [hero["name"],
		PersonalityData.SUBJECTS[subject]["name"], result["apprehension_before"], result["apprehension"],
		result["knowledge_before"], result["knowledge"], " ; cicatrice" if result["scar"] else "", " ; haine" if result["hate"] else ""]


## Le héros écrit à la bibliothèque ce qu'il rapporte (comme il le fera seul au retour, en P5).
func dev_deposit(hero: Dictionary) -> String:
	var written := Library.deposit(library, hero)
	save_game()
	return "%s consigne : %s" % [hero["name"], ", ".join(written) if not written.is_empty() else "rien à écrire"]


## Le héros étudie toutes les fiches du bestiaire une fois (activité du lobby, en P5).
func dev_study(hero: Dictionary) -> String:
	var gained := 0
	for subject in library["bestiary"]:
		gained += Library.study(library, hero, subject)
	save_game()
	return "%s étudie le bestiaire : %d niveau(x) de connaissance gagné(s)." % [hero["name"], gained]


## Enregistre au mémorial tous les héros tombés qui n'y sont pas encore (tant qu'il reste des places).
func dev_memorial_record_dead() -> String:
	var dead := roster.filter(func(hero): return not hero["alive"] and not Memorial.has_entry(memorial, hero["id"]))
	var result := Memorial.record(memorial, dead)
	save_game()
	return "Enregistrés : %s. Refusés (plus de place) : %s." % [", ".join(result["recorded"]) if result["recorded"] else "personne",
		", ".join(result["refused"]) if result["refused"] else "personne"]


func dev_memorial_upgrade(capacity_upgrade: bool) -> String:
	if capacity_upgrade:
		Memorial.upgrade_capacity(memorial)
	else:
		Memorial.upgrade_memory(memorial)
	save_game()
	return "Mémorial : %d places (niveau %d), mémoire niveau %d." % [Memorial.capacity(memorial), memorial["capacity_level"], memorial["memory_level"]]


## Retire un héros du mémorial (après la fenêtre de confirmation) : renvoie « [Nom] sera oublié à jamais. »
func dev_memorial_remove(hero_id: int) -> String:
	var message := Memorial.remove(memorial, hero_id)
	save_game()
	return message


## Un héros vivant revit un souvenir du mémorial (connaissance gagnée ; stress et réaction seulement affichés).
func dev_memorial_relive(hero: Dictionary, hero_id: int) -> String:
	var result := Memorial.relive(memorial, hero, hero_id)
	save_game()
	if result.is_empty():
		return "Rien à revivre."
	return "%s revit le souvenir : %d sujet(s) appris ; stress %.1f, réaction : %s (appliqués en P4)." % [hero["name"],
		result["subjects"].size(), result["stress"], result["reaction"]]


# ---------------------------------------------------------------------------
# Revoir le dernier combat (recensement « Techniques », point 9 : outils ; mode dev)
# ---------------------------------------------------------------------------

## Le dernier combat de la Tour joué dans cette séance (pas enregistré dans la sauvegarde) : des copies de l'équipe et
## des ennemis tels qu'au départ, la quête, la carte, la graine, les potions et les ordres du Maître (Battle.order_log,
## remplis pendant le combat). Revu, il se rejoue à l'identique (voir Battle.battle_seed) sans rien changer à la partie.
var last_fight := {}


## Au départ d'un combat de la Tour, juste avant de le créer : note de quoi le revoir et sème le hasard.
func record_fight(team: Array, enemies: Array, quest: Dictionary, map: Dictionary, floor_number: int) -> void:
	var pre := randi()
	last_fight = {"team": team.map(func(hero): return hero.duplicate(true)), "enemies": enemies.duplicate(true),
		"quest": quest.duplicate(true), "map": map.duplicate(true), "floor": floor_number, "seed": pre, "orders": [],
		"potions": -1}
	seed(pre)


## Juste après la création du combat noté : ses potions et (le même tableau, rempli pendant le combat) ses ordres.
func record_fight_battle(battle: Battle) -> void:
	if last_fight.is_empty():
		return
	last_fight["potions"] = battle.potions
	last_fight["orders"] = battle.order_log


## Le dernier combat, prêt à être revu (null s'il n'y en a pas) : les copies du départ, la même graine, les mêmes ordres.
func dev_replay_battle() -> Battle:
	if last_fight.is_empty():
		return null
	seed(last_fight["seed"])
	var team: Array = last_fight["team"].map(func(hero): return hero.duplicate(true))
	var battle := Battle.new(team, last_fight["enemies"].duplicate(true), last_fight["quest"].duplicate(true))
	if last_fight["potions"] >= 0:
		battle.potions = last_fight["potions"]
	battle.map_data = last_fight["map"].duplicate(true)
	battle.replay_orders = last_fight["orders"].duplicate(true)
	battle.start()
	return battle
