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

## Le nom d'un poste (bâtiment ou reconversion), "" s'il n'existe pas.
func post_name(post_id: String) -> String:
	if BUILDINGS.has(post_id):
		return BUILDINGS[post_id]["name"]
	return ROLE_POSTS.get(post_id, {}).get("name", "")


## Nombre de postes d'un bâtiment ou d'une reconversion.
func post_slots(post_id: String) -> int:
	return ROLE_POSTS[post_id]["slots"] if ROLE_POSTS.has(post_id) else POSTS_PER_BUILDING


## Le poste existe-t-il en ce moment (bâtiment construit ; instructeur : terrain ouvert) ?
func post_open(post_id: String) -> bool:
	match post_id:
		"instructeur":
			return training_unlocked()
		"administrateur":
			return tutorial_step == ""
	return post_id in buildings


## (Étape C) « Affecter automatiquement » : chaque poste libre reçoit un héros de la cité qui ne fait rien (ni poste,
## ni entraînement, ni repos, pas parti), le plus doué pour ce bâtiment (post_score). Renvoie les annonces (textes).
func auto_fill_posts() -> Array[String]:
	var lines: Array[String] = []
	# Les bâtiments qui demandent un talent d'abord (forge, magie), les autres ensuite.
	var order: Array = BUILDINGS.keys().filter(func(b): return b == "forge" or BUILDINGS[b].get("mage", false))
	order.append_array(BUILDINGS.keys().filter(func(b): return not b in order))
	for building_id in order:
		if not building_id in buildings:
			continue
		while posted_heroes(building_id).size() < POSTS_PER_BUILDING:
			var candidates := alive_heroes().filter(func(h): return h.get("post", "") == "" and h.get("training", "") == "" \
				and not is_away(h) and not is_resting(h) and not h.get("auto_post_refused", false))
			if candidates.is_empty():
				break
			candidates.sort_custom(func(a, b): return post_score(a, building_id) > post_score(b, building_id))
			var hero: Dictionary = candidates[0]
			if set_post(hero, building_id):
				lines.append("%s → %s" % [hero["name"], BUILDINGS[building_id]["name"]])
			else:
				hero["auto_post_refused"] = true  # (pour cette fois : on passe au suivant)
				if last_refusal != "":
					lines.append(last_refusal)
	for hero in alive_heroes():
		hero.erase("auto_post_refused")
	save_game()
	return lines


## À quel point un héros convient à un bâtiment : la forge, son talent pour les métiers (et l'artisan déjà formé) ;
## les bâtiments de magie, son Intelligence ; les autres, son niveau.
func post_score(hero: Dictionary, building_id: String) -> float:
	if building_id == "forge":
		return PersonalityEngine.aptitude(hero, "metiers") * 10.0 + skill_level(hero["skills"], "Forge") * 20.0
	if BUILDINGS.get(building_id, {}).get("mage", false):
		return float(hero["stats"].get("int", 0))
	return float(hero["level"])


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
		if not post_open(building_id) or hero.get("post", "") == building_id:
			return false
		if posted_heroes(building_id).size() >= post_slots(building_id):
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
	if ROLE_POSTS.has(hero.get("post", "")):
		return ROLE_POSTS[hero["post"]]["name"]
	if hero.get("post", "") != "":
		return "Assistant : %s" % post_name(hero["post"])
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
			show_tip("batiment")  # premier bâtiment : conseil du Système, après la fenêtre
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
	show_tip("batiment")  # premier bâtiment : conseil du Système
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
## Gemmes rapportées par chaque expédition (ajout du projet, octobre 2026 : des gemmes hors de la Tour).
const EXPEDITION_GEMS := 40
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
			"text": "%s a collecté « %s (F) ». Astuce : la poubelle ne sert à rien, mais elle se vend." % [who, JUNK_NAME]}
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


## À la fin du temps, chaque groupe est rappelé : les matériaux et les déchets vont dans l'entrepôt (les déchets
## se vendent, voir « Vente »), les plans sont gardés. Appelée régulièrement (et au lancement).
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
			"junk":
				# (avant le prompt 1, les déchets étaient jetés ; ils se vendent maintenant)
				add_material(JUNK_NAME, "F", 1)
				var junk_key := "%s (F)" % JUNK_NAME
				totals[junk_key] = totals.get(junk_key, 0) + 1
	var lines := ["L'équipe « %s » est revenue du donjon journalier (%s)." % [team_name(expedition["team_index"]),
		expedition_dungeon(expedition)["name"]]]
	for monster in rare_monsters:
		lines.append("Monstre rare chassé : %s !" % monster)
	if totals.is_empty():
		lines.append("Elle n'a rien rapporté.")
	var keys := totals.keys()
	keys.sort()  # rangé par matériau
	for key in keys:
		lines.append("%s x%d" % [key, totals[key]])
	# Gemmes hors de la Tour (ajout du projet, octobre 2026, voir game_state.gd « Missions du jour »).
	add_gems(EXPEDITION_GEMS)
	lines.append("Gemmes trouvées : %d." % EXPEDITION_GEMS)
	# Les héros retrouvent la cité : l'entraînement reprend avec une séance neuve.
	for hero in alive_heroes():
		if hero["id"] in expedition["team"]:
			hero["training_since"] = Time.get_unix_time_from_system()
	return {"lines": lines}


# ---------------------------------------------------------------------------
# Entraînement : chaque héros travaille ce qu'il veut (étape D)
# ---------------------------------------------------------------------------
# Le porteur du projet : « On ne choisit pas l'entraînement : les héros s'entraînent à ce qu'ils veulent. Un archer, par
# ses autres expériences, peut se rendre compte qu'il a besoin du corps à corps ; un épéiste comme Han peut vouloir
# apprendre à parer les tirs ; une équipe avec un mage élémentaire peut souhaiter développer une résistance à cet
# élément pour ne pas être laissée de côté en combattant à côté ; la répétition d'une action avec un sens permet de
# débloquer et améliorer des compétences. » (Remplace la suggestion et le bouton « Auto » de l'étape A.)
# Ce qu'il a vécu en combat devient un besoin (hero["practice_needs"], merge_practice, tower.gd) ; au terrain, il
# travaille le plus fort de ses besoins (training_wish), revu à chaque séance. Sans vécu (héros neuf), il veut
# maîtriser son arme. Le Maître l'envoie au terrain ou le met au repos ; il ne choisit pas le programme.
# Personnalité : un Curieux préfère ce qu'il ne sait pas encore, un Persévérant tient à ce qu'il travaille déjà.

## Ce que veut travailler ce héros : {"skill": compétence ("" : rien d'utile), "reason": pourquoi, en mots (sans
## chiffres), "weights": {compétence: poids} (mode dev)}.
func training_wish(hero: Dictionary) -> Dictionary:
	var weights := {}
	for skill_name in hero.get("practice_needs", {}):
		weights[skill_name] = float(hero["practice_needs"][skill_name])
	# Sans vécu marquant, il veut maîtriser son arme (ordre de training_order, poids faibles).
	var order := training_order(hero)
	for i in order.size():
		weights[order[i]] = weights.get(order[i], 0.0) + 0.5 / (i + 1)
	var curious := PersonalityEngine.tier(hero, "CUR")
	var stubborn := PersonalityEngine.tier(hero, "PER")
	var best := ""
	var best_weight := 0.0
	for skill_name in weights:
		if not skill_name in TRAINING_SKILLS or not _can_train(hero, skill_name):
			continue
		var weight: float = weights[skill_name]
		if skill_level(hero["skills"], skill_name) == 0:
			weight *= 1.0 + maxi(0, curious) * 0.05
		if skill_name == hero.get("training", ""):
			weight *= 1.0 + maxi(0, stubborn) * 0.05
		if weight > best_weight:
			best = skill_name
			best_weight = weight
	return {"skill": best, "reason": _wish_reason(hero, best), "weights": weights}


## Peut-il encore progresser dans cette compétence (pas au maximum, dans ses affinités, sans incompatibilité) ?
func _can_train(hero: Dictionary, skill_name: String) -> bool:
	var level := skill_level(hero["skills"], skill_name)
	if level >= SKILL_MAX_LEVEL or skill_name in hero.get("stalled_skills", []):
		return false
	if not PersonalityEngine.has_affinity(hero, skill_name):
		return false
	return level > 0 or can_learn_skill(hero, hero["skills"], skill_name)


## Pourquoi il veut travailler cette compétence (ce que voit le Maître : des faits, pas de chiffres).
func _wish_reason(hero: Dictionary, skill_name: String) -> String:
	var name: String = hero["name"]
	var needs: Dictionary = hero.get("practice_needs", {})
	var lived: bool = needs.get(skill_name, 0.0) >= 1.0
	match skill_name:
		"":
			return "%s n'a plus rien d'utile à apprendre au terrain pour l'instant." % name
		"Maîtrise de la dague":
			if lived and (hero["class"] == "Archer" or fighting_weapon(hero).get("type", "") == "Arc"):
				return "%s veut apprendre à se battre au corps à corps : des ennemis l'ont souvent pris au contact." % name
		"Parade des projectiles":
			return "%s veut apprendre à parer les tirs : les flèches et les sorts l'ont souvent touché." % name
		"Mouvement souple":
			if lived:
				return "%s veut apprendre à esquiver : on le touche trop souvent." % name
		"Utilisation du bouclier":
			if lived:
				return "%s veut mieux se servir de son bouclier : il encaisse beaucoup de coups." % name
	for element in ELEMENT_RESISTANCES:
		if ELEMENT_RESISTANCES[element] == skill_name:
			var word: String = {"Feu": "le feu", "Vent": "le vent", "Froid": "le froid"}[element]
			if alive_heroes().any(func(h): return h["class"] == "Mage" and h.get("element", "") == element and h["id"] != hero["id"]):
				return "%s veut s'endurcir contre %s, pour pouvoir se battre aux côtés de son mage." % [name, word]
			return "%s veut s'endurcir contre %s : il en a souffert au combat." % [name, word]
	for type in WEAPON_WORDS:
		if WEAPON_TYPES[type]["skill"] == skill_name:
			if lived:
				return "%s veut mieux manier %s : c'est l'arme dont il se sert le plus." % [name, WEAPON_WORDS[type]]
			return "%s veut apprendre à manier %s." % [name, WEAPON_WORDS[type]]
	return "%s veut travailler : %s." % [name, skill_name]


const WEAPON_WORDS := {"Épée": "l'épée", "Lance": "la lance", "Dague": "la dague", "Fouet": "le fouet", "Arc": "l'arc"}


## Les programmes qu'un héros sans vécu marquant veut, dans l'ordre : son arme de prédilection, l'arme qu'il porte, les
## armes de sa classe, le bouclier (classes à bouclier), l'esquive.
func training_order(hero: Dictionary) -> Array:
	var order := []
	if uses_magic(hero):
		return ["Mouvement souple"]  # (les mages et les soigneurs n'ont pas d'arme)
	var usable: Array = CLASS_WEAPONS.get(hero["class"], ["Épée"])
	var favorite := PersonalityEngine.favorite_weapon(hero, usable)
	var carried: String = fighting_weapon(hero).get("type", "")
	for type in [favorite, carried] + usable:
		if type != "" and WEAPON_TYPES.has(type) and type != "Bouclier":
			var skill_name: String = WEAPON_TYPES[type]["skill"]
			if skill_name in TRAINING_SKILLS and not skill_name in order:
				order.append(skill_name)
	if hero["class"] in SHIELD_CLASSES:
		order.insert(mini(1, order.size()), "Utilisation du bouclier")
	order.append("Mouvement souple")
	return order


## Le Maître envoie un héros au terrain : il y travaille ce qu'il veut. Renvoie faux si c'est impossible (raison dans
## last_refusal : terrain plein, refus, rien à apprendre).
func send_to_training(hero: Dictionary) -> bool:
	var wish := training_wish(hero)
	if wish["skill"] == "":
		last_refusal = wish["reason"]
		return false
	if not set_training(hero, wish["skill"]):
		if last_refusal == "":
			last_refusal = "Le terrain est plein (%d places) : renvoie d'abord un héros au repos." % TRAINING_SLOTS
		return false
	return true


## Les héros de la cité qui pourraient s'entraîner : vivants, pas partis, ni au terrain ni à un poste, pas en repos.
func idle_heroes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hero in alive_heroes():
		if hero.get("training", "") == "" and hero.get("post", "") == "" and not is_away(hero) and not is_resting(hero):
			result.append(hero)
	return result


## « Envoyer au terrain les héros libres » : remplit les places libres avec les héros qui ne font rien (ceux qui ont le
## plus envie d'abord), chacun sur ce qu'il veut. Renvoie les noms inscrits, et les refus (textes).
func auto_fill_training() -> Dictionary:
	var enrolled := []
	var refusals := []
	var heroes := idle_heroes().filter(func(h): return training_wish(h)["skill"] != "")
	heroes.sort_custom(func(a, b): return _wish_strength(a) > _wish_strength(b))
	for hero in heroes:
		if trainees().size() >= TRAINING_SLOTS:
			break
		if send_to_training(hero):
			enrolled.append(hero["name"])
		elif last_refusal != "":
			refusals.append(last_refusal)
	return {"enrolled": enrolled, "refusals": refusals}


func _wish_strength(hero: Dictionary) -> float:
	var wish := training_wish(hero)
	return float(wish["weights"].get(wish["skill"], 0.0))


## À chaque séance, le héros travaille ce qu'il veut maintenant (son envie a pu changer après un combat). Renvoie
## l'annonce d'un changement, ou "". (Déclarée vide dans training.gd, qui l'appelle.)
func _wished_program(hero: Dictionary) -> String:
	var current: String = hero.get("training", "")
	if current == "":
		return ""
	var wish := training_wish(hero)
	if wish["skill"] == current:
		return ""
	hero["training"] = wish["skill"]
	if wish["skill"] == "":
		return "%s a fini tout ce qu'il pouvait apprendre au terrain : il retourne au repos." % hero["name"]
	return wish["reason"]


# ---------------------------------------------------------------------------
# Vente (deuxième source d'or)
# ---------------------------------------------------------------------------
# Prompt 1 (économie) : on vend à l'entrepôt les déchets (JUNK_NAME) et les armes de grade F rangées dans
# l'arsenal (pas celles qu'un héros porte). Pas pendant le tutoriel (ses armes servent à l'étage 1).
# Prix provisoires.
const JUNK_SELL_PRICE := 200
const WEAPON_F_SELL_PRICE := 500


## Les armes F rangées (owner 0) qu'on peut vendre.
func sellable_weapons() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for weapon in free_weapons():
		if weapon["grade"] == "F":
			result.append(weapon)
	return result


## Ce que rapporterait la vente : {"junk": nombre de déchets, "weapons": nombre d'armes F, "gold": or}.
func sale_value() -> Dictionary:
	var junk := material_count(JUNK_NAME)
	var weapons := sellable_weapons().size()
	return {"junk": junk, "weapons": weapons, "gold": junk * JUNK_SELL_PRICE + weapons * WEAPON_F_SELL_PRICE}


func can_sell() -> bool:
	return tutorial_step == "" and sale_value()["gold"] > 0


## Vend tous les déchets et toutes les armes F rangées. Renvoie l'or gagné (0 si rien à vendre).
func sell_all() -> int:
	if not can_sell():
		return 0
	var value := sale_value()
	_take_material(JUNK_NAME, value["junk"])
	for weapon in sellable_weapons():
		arsenal.erase(weapon)
	gold += value["gold"]
	gold_changed.emit(gold)
	save_game()
	return value["gold"]


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

## Potion de soin (POTION, items.gd) : préparée à la forge, sans puzzle ni tirage (prompt 1, pour que les potions
## emportées dans la Tour existent hors du mode dev). L'herbe médicinale vient de la Forêt Kenout (de n'importe
## quel grade, les plus faibles d'abord). Recette provisoire.
const POTION_RECIPE := {"Herbe médicinale": 3}


## Vrai si l'entrepôt a de quoi préparer une potion de soin.
func can_brew_potion() -> bool:
	for material in POTION_RECIPE:
		if material_count(material) < POTION_RECIPE[material]:
			return false
	return true


## Prépare une potion de soin (grade F, rangée dans l'entrepôt). Renvoie faux s'il manque des herbes.
func brew_potion() -> bool:
	if not forge_built() or not can_brew_potion():
		return false
	for material in POTION_RECIPE:
		_take_material(material, POTION_RECIPE[material])
	add_material(POTION, "F", 1)
	save_game()
	return true


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
		if not is_away(hero) and not is_resting(hero):  # (prompt 4 : un jour de repos, il ne vient pas)
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
