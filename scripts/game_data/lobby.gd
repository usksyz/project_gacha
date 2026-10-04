class_name GameLobby
extends GameSummon
## Le lobby (la cité) : construction des bâtiments et postes d'assistant, donjon journalier
## (expéditions de récolte) et forge.
## Fait partie de la pile de GameData (voir game_data.gd).


# ---------------------------------------------------------------------------
# Construction et affectation aux bâtiments
# ---------------------------------------------------------------------------
# Les bâtiments se construisent en gemmes (cahier des charges), une fois le terrain d'entraînement
# ouvert (10 armes tirées) :
# - la forge, annexe de l'armurerie (500 gemmes, comme dans le cahier) ;
# - les bâtiments de magie, annexes du terrain d'entraînement, seulement avec un mage vivant
#   parmi ses héros. Une fois construits tous les trois, ils fusionnent en Hall de magie.
#   Leurs fonctions (Recherche, synthèse d'objets, savoir des mages) viendront plus tard.
# Chaque bâtiment construit a POSTS_PER_BUILDING postes d'assistant (hero["post"]) : un héros affecté
# y travaille au lieu de s'entraîner. À la forge, un assistant devient peu à peu artisan (compétence « Forge »).

## « cost » : prix en gemmes ; « mage » : il faut un mage pour le construire ;
## « info » : ce que fait le bâtiment ; « built » : l'annonce une fois construit.
const BUILDINGS := {
	"synthese": {"name": "Chambre de synthèse", "cost": 500, "mage": false, "needs_training": false,
		"info": "On y sacrifie un héros pour en renforcer un autre (synthèse).",
		"built": "La chambre de synthèse a été construite avec succès !"},
	"forge": {"name": "Forge", "cost": 500, "mage": false,
		"info": "Annexe de l'armurerie : fabrique des armes avec les matériaux du donjon journalier.",
		"built": "La forge a été construite avec succès !"},
	# Choix du porteur du projet : le premier bâtiment de magie se construit tout seul, gratuitement,
	# quand un mage rejoint les héros (« auto »).
	"atelier_magie": {"name": "Atelier de magie", "cost": 0, "mage": true, "auto": "mage", "needs_training": false,
		"info": "Débloque la fonction « Recherche ».",
		"built": "L'atelier de magie a été construit avec succès !"},
	"laboratoire": {"name": "Laboratoire d'alchimie", "cost": 500, "mage": true,
		"info": "Débloque plusieurs types de synthèse d'objets.",
		"built": "Le laboratoire d'alchimie a été construit avec succès !"},
	"bibliotheque": {"name": "Bibliothèque", "cost": 500, "mage": true,
		"info": "Les mages y apprennent et gagnent en connaissances.",
		"built": "La bibliothèque a été construite avec succès !"},
}
const MAGIC_BUILDINGS := ["atelier_magie", "laboratoire", "bibliotheque"]
const MAGIC_HALL_NAME := "Hall de magie"

## Postes d'assistant par bâtiment (cahier : « deux postes d'assistant par métier »).
const POSTS_PER_BUILDING := 2


## Les héros vivants affectés à un bâtiment.
func posted_heroes(building_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hero in alive_heroes():
		if hero.get("post", "") == building_id:
			result.append(hero)
	return result


## Affecte un héros à un bâtiment construit (« » = le retirer de son poste).
## Il quitte alors le terrain d'entraînement : un héros ne travaille qu'à un endroit à la fois.
## Renvoie faux si le bâtiment n'est pas construit, si ses postes sont pris, ou si le héros refuse
## (rupture, Paresseux : la raison est alors dans last_refusal, voir personality.gd).
func set_post(hero: Dictionary, building_id: String) -> bool:
	last_refusal = ""
	if building_id != "":
		if not building_id in buildings or hero.get("post", "") == building_id:
			return false
		if posted_heroes(building_id).size() >= POSTS_PER_BUILDING:
			return false
		if not accepts_work(hero):
			return false
		if hero.get("training", "") != "":
			update_training()
			hero["training"] = ""
	hero["post"] = building_id
	save_game()
	return true


## Où est un héros en ce moment (texte court), pour l'affichage.
func activity_text(hero: Dictionary) -> String:
	if in_tower(hero):
		return "Dans la Tour"
	if on_expedition(hero):
		return "Au donjon journalier"
	if hero.get("post", "") != "":
		return "Assistant : %s" % BUILDINGS[hero["post"]]["name"]
	if hero.get("training", "") != "":
		return "Terrain d'entraînement"
	if is_broken(hero):
		return "En rupture (repos forcé)"
	return "Au repos"


## Vrai si au moins un mage vivant fait partie des héros.
func has_mage() -> bool:
	for hero in alive_heroes():
		if hero["class"] == "Mage":
			return true
	return false


## Les bâtiments qui se construisent tout seuls quand leur condition est remplie (atelier de magie :
## un mage parmi les héros). Appelée à chaque sauvegarde (donc après tout changement) et au lancement.
## Renvoie vrai si quelque chose a été construit.
func check_auto_buildings() -> bool:
	var done := false
	for building_id in BUILDINGS:
		var info: Dictionary = BUILDINGS[building_id]
		if info.get("auto", "") == "mage" and not building_id in buildings and has_mage():
			buildings.append(building_id)
			done = true
			var lines: Array = [info["built"], "Un mage a rejoint tes héros : le premier bâtiment de magie est né."]
			if has_magic_hall():
				lines.append("Les trois bâtiments fusionnent : le %s est né !" % MAGIC_HALL_NAME)
			facility_completed.emit.call_deferred("Construction terminée", lines)
	return done


## Vrai quand les trois bâtiments de magie sont construits (ils forment alors le Hall de magie).
func has_magic_hall() -> bool:
	for building_id in MAGIC_BUILDINGS:
		if not building_id in buildings:
			return false
	return true


## Pourquoi on ne peut pas construire ce bâtiment (texte), ou "" si c'est possible.
func build_problem(building_id: String) -> String:
	if building_id in buildings:
		return "Déjà construit."
	if BUILDINGS[building_id].get("auto", "") == "mage":
		return "Se construit tout seul quand un mage rejoint tes héros."
	if BUILDINGS[building_id].get("needs_training", true) and not training_unlocked():
		return "Il faut d'abord le terrain d'entraînement."
	if BUILDINGS[building_id]["mage"] and not has_mage():
		return "Il faut un mage parmi tes héros."
	if gems < BUILDINGS[building_id]["cost"]:
		return "Pas assez de gemmes."
	return ""


## Construit un bâtiment. Renvoie les messages à afficher, ou [] si c'est impossible.
func build(building_id: String) -> Array[String]:
	var messages: Array[String] = []
	if build_problem(building_id) != "":
		return messages
	gems -= BUILDINGS[building_id]["cost"]
	gems_changed.emit(gems)
	buildings.append(building_id)
	messages.append(BUILDINGS[building_id]["built"])
	if building_id in MAGIC_BUILDINGS and has_magic_hall():
		messages.append("Les trois bâtiments fusionnent : le %s est né !" % MAGIC_HALL_NAME)
	save_game()
	return messages


# ---------------------------------------------------------------------------
# Entrepôt et donjon journalier
# ---------------------------------------------------------------------------
# Les matériaux s'accumulent dans l'entrepôt (warehouse : {nom: {grade: nombre}}).
# Le donjon journalier (débloqué après l'étage DAILY_UNLOCK_FLOOR) n'est pas un combat : une équipe
# y part récolter pendant EXPEDITION_SECONDS de temps réel (même jeu fermé), puis elle est rappelée
# automatiquement et les matériaux vont dans l'entrepôt. Pas de limite (choix du porteur du projet) :
# autant d'expéditions qu'on veut, plusieurs groupes à la fois (expeditions), tant qu'il reste des héros.
# Les ramassages sont tirés au départ (expedition["log"]) et annoncés au fil du temps.
# Trois donjons selon le jour réel (cahier : calendrier du donjon journalier), tous ouverts le dimanche.

## Étage à franchir pour débloquer le donjon journalier.
const DAILY_UNLOCK_FLOOR := 5

## Les donjons journaliers. Noms du manhwa : exception à la règle des noms originaux, choix du porteur
## du projet. « days » : jours d'ouverture (1 = lundi... 6 = samedi, comme Time) ; le dimanche, tous.
## Chacun a ses trois matériaux. Provisoire : le cahier ne donne que la difficulté de la forêt
## (« super facile ») et ne nomme pas les matériaux (sauf des branches d'arbres dans la forêt).
const DAILY_DUNGEONS := {
	"mine": {"name": "Mine d'Isralta", "difficulty": "super facile", "days": [1, 2],
		"materials": ["Minerai de fer", "Charbon", "Cristal brut"],
		"rare": {"name": "Taupe de cristal", "info": "une taupe géante couverte de cristaux"}},
	"foret": {"name": "Forêt Kenout", "difficulty": "super facile", "days": [3, 4],
		"materials": ["Bois", "Peau de bête", "Herbe médicinale"],
		"rare": {"name": "Reine de la forêt", "info": "un cervidé blanc à corne dorée"}},
	"plateau": {"name": "Plateau Sinmiel", "difficulty": "super facile", "days": [5, 6],
		"materials": ["Pierre de taille", "Plume", "Lin"],
		"rare": {"name": "Aigle d'argent", "info": "un rapace aux plumes d'argent"}},
}

## Monstres rares (cahier : la Reine de la forêt, les jours de forêt) : chaque donjon a le sien
## (« rare » ci-dessus ; celui de la mine et du plateau sont inventés, le cahier ne les donne pas).
## Chance qu'il apparaisse pendant une expédition, et pierres d'attribut (de qualité inférieure,
## grade F) qu'il laisse : elles servent à la promotion. Chiffres provisoires.
const RARE_MONSTER_CHANCE := 0.1
const RARE_MONSTER_STONES := 2
## Mode dev : le monstre rare apparaît à chaque expédition. Pas enregistré.
var dev_force_rare := false
## Le dimanche (0 pour Time), tous les donjons sont ouverts.
const SUNDAY := 0
const WEEKDAY_NAMES := ["Dimanche", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi"]

## Mode dev : jour de la semaine simulé (0 = dimanche... 6 = samedi), -1 = le vrai jour. Pas enregistré.
var dev_daily_weekday := -1
## Ce qu'on peut aussi ramasser de temps en temps : un déchet inutile, ou (rarement) un plan de forge.
const JUNK_NAME := "Poubelle"
const JUNK_CHANCE := 0.12
const PLAN_CHANCE := 0.02
## Chance de ramasser une pierre d'attribut (elle sert à la promotion).
const STONE_PICKUP_CHANCE := 0.03

## Durée d'une expédition (secondes de temps réel) et temps entre deux ramassages d'un héros.
const EXPEDITION_SECONDS := 1800
const PICKUP_SECONDS := 120

## Grades des matériaux ramassés et leur chance (total 1.0).
const MATERIAL_GRADE_RATES := {
	"F": 0.45, "E-": 0.20, "E": 0.13, "E+": 0.09, "D-": 0.06, "D": 0.04, "D+": 0.02, "C-": 0.01,
}


func daily_unlocked() -> bool:
	return tower_floor > DAILY_UNLOCK_FLOOR


## Le jour de la semaine (0 = dimanche, 1 = lundi... 6 = samedi), selon l'horloge de l'appareil.
func daily_weekday() -> int:
	if dev_daily_weekday >= 0:
		return dev_daily_weekday
	return Time.get_datetime_dict_from_system()["weekday"]


## Les donjons journaliers ouverts aujourd'hui (identifiants de DAILY_DUNGEONS) : tous le dimanche.
func open_daily_dungeons() -> Array[String]:
	var result: Array[String] = []
	var day := daily_weekday()
	for dungeon_id in DAILY_DUNGEONS:
		if day == SUNDAY or day in DAILY_DUNGEONS[dungeon_id]["days"]:
			result.append(dungeon_id)
	return result


## Le donjon d'une expédition (« mine » pour celles des anciennes sauvegardes, avant le calendrier).
func expedition_dungeon(expedition: Dictionary) -> Dictionary:
	return DAILY_DUNGEONS[expedition.get("dungeon", "mine")]


## « Forêt Kenout (super facile) ».
func dungeon_title(dungeon_id: String) -> String:
	return "%s (%s)" % [DAILY_DUNGEONS[dungeon_id]["name"], DAILY_DUNGEONS[dungeon_id]["difficulty"]]


## Pourquoi on ne peut pas partir au donjon journalier (texte), ou "" si c'est possible.
func expedition_problem() -> String:
	if not daily_unlocked():
		return "Verrouillé : franchis l'étage %d." % DAILY_UNLOCK_FLOOR
	return ""


## Les héros d'une équipe composée à l'avance qui peuvent partir (vivants, pas dans la Tour).
func expedition_members(team_index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hero in team_members(team_index):
		if not is_away(hero):
			result.append(hero)
	return result


## Envoie une équipe dans un donjon journalier ouvert aujourd'hui (« dungeon_id »). Tous les
## ramassages sont tirés maintenant, avec le moment où ils arrivent. Renvoie faux si c'est impossible.
func start_expedition(team_index: int, dungeon_id: String) -> bool:
	var team := expedition_members(team_index)
	if expedition_problem() != "" or team.is_empty() or not dungeon_id in open_daily_dungeons():
		return false
	update_training()  # les séances terminées avant le départ sont comptées
	var now := Time.get_unix_time_from_system()
	var pickups := []
	for hero in team:
		var t := randf_range(20.0, PICKUP_SECONDS)
		while t < EXPEDITION_SECONDS:
			pickups.append(_roll_pickup(hero, t, dungeon_id))
			t += PICKUP_SECONDS * randf_range(0.7, 1.3)
	var rare := _roll_rare_monster(dungeon_id, team)
	if not rare.is_empty():
		pickups.append(rare)
	pickups.sort_custom(func(a, b): return a["t"] < b["t"])
	expeditions.append({"team": team.map(func(hero): return hero["id"]), "team_index": team_index,
		"dungeon": dungeon_id, "start": now, "end": now + EXPEDITION_SECONDS, "log": pickups})
	gear_up(team)  # les héros prennent leurs armes dans l'arsenal (et la partie est sauvegardée)
	return true


## Le monstre rare du donjon apparaît-il pendant cette expédition (RARE_MONSTER_CHANCE) ? Si oui,
## renvoie le moment de la chasse, avec les pierres d'attribut qu'il laisse ; sinon {}.
func _roll_rare_monster(dungeon_id: String, team: Array) -> Dictionary:
	if randf() >= RARE_MONSTER_CHANCE and not dev_force_rare:
		return {}
	var monster: Dictionary = DAILY_DUNGEONS[dungeon_id]["rare"]
	var hunter: Dictionary = team.pick_random()
	return {"t": randf_range(60.0, EXPEDITION_SECONDS - 60.0), "kind": "material", "rare": true,
		"monster": monster["name"], "name": PROMOTION_STONE, "grade": "F", "count": RARE_MONSTER_STONES,
		"text": "Monstre rare : %s, %s ! Chasse réussie pour le groupe de %s (%s) : +%d %s." % [monster["name"],
			monster["info"], hunter["name"], "★".repeat(hunter["rarity"]), RARE_MONSTER_STONES,
			PROMOTION_STONE.to_lower().replace("pierre", "pierres")]}


## Un ramassage : un matériau gradé du donjon, un déchet, ou (rarement) un plan de forge.
func _roll_pickup(hero: Dictionary, t: float, dungeon_id: String) -> Dictionary:
	var who := "%s (%s)" % [hero["name"], "★".repeat(hero["rarity"])]
	var roll := randf()
	if roll < PLAN_CHANCE:
		var type: String = WEAPON_TYPES.keys().pick_random()
		return {"t": t, "kind": "plan", "name": type,
			"text": "%s a trouvé un plan de forge : « %s » !" % [who, type]}
	if roll < PLAN_CHANCE + STONE_PICKUP_CHANCE:
		return {"t": t, "kind": "material", "name": PROMOTION_STONE, "grade": "F",
			"text": "%s a trouvé une « %s » ! Elle sert à la promotion." % [who, PROMOTION_STONE]}
	if roll < PLAN_CHANCE + STONE_PICKUP_CHANCE + JUNK_CHANCE:
		return {"t": t, "kind": "junk", "name": JUNK_NAME, "grade": "F",
			"text": "%s a collecté « %s (F) ». Astuce : la poubelle est inutile, jetez-la." % [who, JUNK_NAME]}
	var material: String = DAILY_DUNGEONS[dungeon_id]["materials"].pick_random()
	var grade := _roll_from(MATERIAL_GRADE_RATES)
	return {"t": t, "kind": "material", "name": material, "grade": grade,
		"text": "%s a collecté « %s (%s) »." % [who, material, grade]}


## Tire une clé au hasard dans un tableau {clé: chance}.
func _roll_from(rates: Dictionary) -> String:
	var roll := randf()
	var cumulative := 0.0
	for key in rates:
		cumulative += rates[key]
		if roll < cumulative:
			return key
	return rates.keys()[0]


## Secondes écoulées depuis le départ d'une expédition, et secondes restantes.
func expedition_elapsed(expedition: Dictionary) -> float:
	return Time.get_unix_time_from_system() - expedition.get("start", 0.0)


func expedition_remaining(expedition: Dictionary) -> int:
	return maxi(0, ceili(expedition.get("end", 0.0) - Time.get_unix_time_from_system()))


## Les ramassages déjà faits d'une expédition (ceux dont le moment est passé).
func expedition_log_so_far(expedition: Dictionary) -> Array:
	var elapsed := expedition_elapsed(expedition)
	return expedition.get("log", []).filter(func(entry): return entry["t"] <= elapsed)


## À la fin du temps, chaque groupe est rappelé : les matériaux vont dans l'entrepôt,
## les plans sont gardés, les déchets jetés. Appelée régulièrement (et au lancement).
func update_expedition() -> void:
	var finished := expeditions.filter(func(expedition): return expedition_remaining(expedition) <= 0)
	if finished.is_empty():
		return
	for expedition in finished:
		expeditions.erase(expedition)
		expedition_reports.append(_finish_expedition(expedition))
	tidy_arsenal()  # les héros reposent leurs armes dans l'arsenal (et la partie est sauvegardée)
	lobby_updated.emit()


## Le retour d'un groupe : ce qu'il a rapporté va dans l'entrepôt. Renvoie le rapport à annoncer.
func _finish_expedition(expedition: Dictionary) -> Dictionary:
	var totals := {}
	var rare_monsters := []
	for entry in expedition["log"]:
		match entry["kind"]:
			"material":
				var count: int = entry.get("count", 1)  # un monstre rare laisse plusieurs pierres d'un coup
				add_material(entry["name"], entry["grade"], count)
				var key := "%s (%s)" % [entry["name"], entry["grade"]]
				totals[key] = totals.get(key, 0) + count
				if entry.get("rare", false):
					rare_monsters.append(entry["monster"])
			"plan":
				if not entry["name"] in plans:
					plans.append(entry["name"])
				totals["Plan : %s" % entry["name"]] = 1
	var lines := ["L'équipe %d est revenue du donjon journalier (%s)." % [expedition["team_index"] + 1,
		expedition_dungeon(expedition)["name"]]]
	for monster in rare_monsters:
		lines.append("Monstre rare chassé : %s !" % monster)
	if totals.is_empty():
		lines.append("Elle n'a rien rapporté d'utile.")
	var keys := totals.keys()
	keys.sort()  # rangé par matériau
	for key in keys:
		lines.append("%s x%d" % [key, totals[key]])
	# Les héros retrouvent la cité : l'entraînement reprend avec une séance neuve.
	for hero in alive_heroes():
		if hero["id"] in expedition["team"]:
			hero["training_since"] = Time.get_unix_time_from_system()
	return {"lines": lines}


# ---------------------------------------------------------------------------
# Forge
# ---------------------------------------------------------------------------
# La forge (annexe de l'armurerie) fabrique des armes avec les matériaux de l'entrepôt.
# Le rang de base de l'arme est le grade du matériau principal choisi (+1 cran avec un plan).
# Malus (cahier des charges) : infrastructures insuffisantes (forge de niveau 1, strict minimum),
# pas d'artisan (aucun assistant de la forge n'a la compétence « Forge »), pas de plan.
# Deux façons de produire :
# - automatique : un simple tirage selon la probabilité de succès ; l'arme reste à son rang de base ;
# - à la main : le puzzle de forge (voir forge_puzzle.gd), qui peut faire monter le rang de plusieurs crans.
# En cas d'échec, les matériaux sont perdus.

## Recettes : matériau principal (qui donne le rang) et sa quantité, plus les matériaux en appoint.
## Pour l'instant tout vient de la mine (le bois, le cuir... viendront avec les autres donjons).
const FORGE_RECIPES := {
	"Épée": {"main": "Minerai de fer", "qty": 5, "extra": {"Charbon": 2}},
	"Lance": {"main": "Minerai de fer", "qty": 4, "extra": {"Charbon": 2}},
	"Dague": {"main": "Minerai de fer", "qty": 3, "extra": {"Charbon": 1}},
	"Fouet": {"main": "Minerai de fer", "qty": 3, "extra": {"Charbon": 1}},
	"Arc": {"main": "Minerai de fer", "qty": 3, "extra": {"Charbon": 1}},
	"Bouclier": {"main": "Minerai de fer", "qty": 6, "extra": {"Charbon": 2}},
}

## Difficultés du puzzle (cahier des charges) : taille de la grille, nombre de pièces (et leur taille),
## cases d'impureté, pièces révélées une par une, rotation permise, silhouette qui s'efface (secondes),
## crans de bonus au maximum, et chance de succès affichée avant de confirmer.
const FORGE_DIFFICULTIES := {
	"Facile": {"grid": 5, "pieces": 4, "sizes": [2, 3], "impurities": 0, "reveal": false,
		"rotation": true, "fade": 0.0, "bonus": 1, "chance": 0.95},
	"Normal": {"grid": 6, "pieces": 6, "sizes": [2, 4], "impurities": 0, "reveal": false,
		"rotation": true, "fade": 0.0, "bonus": 2, "chance": 0.8},
	"Difficile": {"grid": 7, "pieces": 8, "sizes": [3, 4], "impurities": 3, "reveal": false,
		"rotation": true, "fade": 0.0, "bonus": 3, "chance": 0.6},
	"Infernal": {"grid": 8, "pieces": 10, "sizes": [3, 4], "impurities": 4, "reveal": true,
		"rotation": true, "fade": 0.0, "bonus": 4, "chance": 0.4},
	"Démoniaque": {"grid": 9, "pieces": 12, "sizes": [3, 5], "impurities": 5, "reveal": true,
		"rotation": false, "fade": 10.0, "bonus": 5, "chance": 0.2},
}

## Temps du puzzle (secondes), et effets des malus dans le puzzle.
const FORGE_TIME := 180
const INFRA_TIME_MALUS := 30          # infrastructures insuffisantes : 30 secondes en moins
const NO_ARTISAN_IMPURITIES := 2      # pas d'artisan : 2 cases d'impureté en plus
## Production automatique : chance de succès sans malus, et ce que retire chaque malus.
const FORGE_AUTO_CHANCE := 0.9
const FORGE_MALUS_CHANCE := 0.15
## Niveau de la forge (les niveaux de bâtiment viendront plus tard) : au niveau 1, les
## infrastructures sont insuffisantes ; au niveau 2, elles donneraient 30 secondes en plus.
const FORGE_LEVEL := 1
## Points de compétence « Forge » gagnés par chaque assistant présent à chaque fabrication
## (100 points par niveau, comme à l'entraînement) : au bout de 4 fabrications, il devient artisan.
const ARTISAN_POINTS_PER_WORK := 25


func forge_built() -> bool:
	return "forge" in buildings


## Les assistants de la forge présents (pas partis dans la Tour ou au donjon).
func forge_assistants() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hero in posted_heroes("forge"):
		if not is_away(hero):
			result.append(hero)
	return result


## Vrai si un assistant présent est artisan (compétence « Forge »).
func has_artisan() -> bool:
	for hero in forge_assistants():
		if skill_level(hero["skills"], "Forge") > 0:
			return true
	return false


## Les malus qui s'appliquent pour forger ce type d'arme : liste de clés "infra", "artisan", "plan".
func forge_maluses(weapon_type: String) -> Array:
	var result := []
	if FORGE_LEVEL < 2:
		result.append("infra")
	if not has_artisan():
		result.append("artisan")
	if not weapon_type in plans:
		result.append("plan")
	return result


const MALUS_NAMES := {"infra": "Infrastructures insuffisantes (30 s en moins)",
	"artisan": "Pas d'artisan (2 cases d'impureté en plus)",
	"plan": "Pas de plan (silhouette en pointillés, pas de cran en plus)"}


## Chance de succès (0 à 1) : « difficulty » = une difficulté du puzzle, ou "auto".
func forge_chance(weapon_type: String, difficulty: String) -> float:
	var malus_count := forge_maluses(weapon_type).size()
	# Des héros Mauvais à la cité : tout marche un peu moins bien (lobby_efficiency, personality.gd).
	if difficulty == "auto":
		return clampf((FORGE_AUTO_CHANCE - malus_count * FORGE_MALUS_CHANCE) * lobby_efficiency(), 0.05, 1.0)
	return clampf((FORGE_DIFFICULTIES[difficulty]["chance"] - malus_count * 0.1) * lobby_efficiency(), 0.02, 1.0)


## La chance en mots, comme dans le cahier : Certaine, Élevée, Moyenne, Faible, Infime.
func chance_word(chance: float) -> String:
	if chance >= 0.95:
		return "Certaine"
	if chance >= 0.7:
		return "Élevée"
	if chance >= 0.45:
		return "Moyenne"
	if chance >= 0.2:
		return "Faible"
	return "Infime"


## Grades du matériau principal dont on a assez pour cette recette (les meilleurs d'abord),
## en vérifiant aussi les matériaux d'appoint.
func forge_grades(weapon_type: String) -> Array:
	var recipe: Dictionary = FORGE_RECIPES[weapon_type]
	for material in recipe["extra"]:
		if material_count(material) < recipe["extra"][material]:
			return []
	var result := []
	for grade in WEAPON_GRADES.keys():
		if material_count(recipe["main"], grade) >= recipe["qty"]:
			result.push_front(grade)
	return result


## Rang de base : le grade du matériau principal, +1 cran avec un plan.
func forge_base_grade(weapon_type: String, material_grade: String) -> String:
	var rank := grade_rank(material_grade)
	if weapon_type in plans:
		rank += 1
	return _grade_at(rank)


func _grade_at(rank: int) -> String:
	var grades := WEAPON_GRADES.keys()
	return grades[clampi(rank, 0, grades.size() - 1)]


## Prend les matériaux d'une fabrication dans l'entrepôt. Renvoie faux s'il en manque.
func _consume_recipe(weapon_type: String, material_grade: String) -> bool:
	if not material_grade in forge_grades(weapon_type):
		return false
	var recipe: Dictionary = FORGE_RECIPES[weapon_type]
	_take_material(recipe["main"], recipe["qty"], material_grade)
	for material in recipe["extra"]:
		_take_material(material, recipe["extra"][material])
	return true


## Production automatique : un tirage selon la probabilité. Renvoie
## {"ok": false} s'il manque des matériaux, sinon {"ok": true, "success": bool, "weapon": ..., "news": [...]}.
func forge_auto(weapon_type: String, material_grade: String) -> Dictionary:
	var chance := forge_chance(weapon_type, "auto")
	if not _consume_recipe(weapon_type, material_grade):
		return {"ok": false}
	var result := {"ok": true, "success": randf() < chance, "weapon": {}}
	if result["success"]:
		result["weapon"] = _add_forged(weapon_type, forge_base_grade(weapon_type, material_grade))
	result["news"] = _forge_work_done()
	save_game()
	return result


## Début d'une fabrication à la main : les matériaux sont pris tout de suite (perdus en cas d'échec).
func forge_manual_begin(weapon_type: String, material_grade: String) -> bool:
	if not _consume_recipe(weapon_type, material_grade):
		return false
	save_game()
	return true


## Fin du puzzle. « bonus » : crans gagnés (0 pour un succès simple). Renvoie l'arme et les nouveautés.
func forge_manual_end(weapon_type: String, material_grade: String, success: bool, bonus: int) -> Dictionary:
	var result := {"success": success, "weapon": {}}
	if success:
		var rank := grade_rank(forge_base_grade(weapon_type, material_grade)) + bonus
		result["weapon"] = _add_forged(weapon_type, _grade_at(rank))
	result["news"] = _forge_work_done()
	save_game()
	return result


func _add_forged(weapon_type: String, grade: String) -> Dictionary:
	var weapon := {"id": next_weapon_id, "type": weapon_type, "grade": grade, "owner": 0, "forged": true}
	next_weapon_id += 1
	arsenal.append(weapon)
	save_game()
	return weapon


## Chaque fabrication fait progresser les assistants présents vers la compétence « Forge ».
func _forge_work_done() -> Array[String]:
	var news: Array[String] = []
	var efficiency := lobby_efficiency()  # moins de progrès avec des héros Mauvais à la cité
	for hero in forge_assistants():
		news.append_array(add_skill_progress(hero, "Forge", roundi(ARTISAN_POINTS_PER_WORK * efficiency),
			TRAINING_POINTS_PER_LEVEL))
	if efficiency < 1.0:
		news.append_array(notice_bad_heroes())
	return news
