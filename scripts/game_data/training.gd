class_name GameTraining
extends GamePersonality
## Le terrain d'entraînement : il s'ouvre après assez d'armes tirées, et les héros inscrits y
## apprennent des compétences au fil du temps réel, même jeu fermé.
## Fait partie de la pile de GameData (voir game_data.gd).


# ---------------------------------------------------------------------------
# Terrain d'entraînement
# ---------------------------------------------------------------------------
# Un héros affecté au terrain travaille une compétence (hero["training"], vide = au repos).
# Toutes les TRAINING_SESSION_SECONDS secondes de temps réel, il fait une séance, même si le jeu
# est fermé : au retour, on compte les séances écoulées depuis hero["training_since"].
# L'entraînement ne donne ni statistiques ni niveau, seulement des compétences.
# Un héros qui monte dans la Tour quitte le terrain le temps de l'étage (il garde sa place et
# son programme) : le temps passé dans la Tour ne compte pas, et il reprend l'entraînement après.
# Plus tard : le temps du lobby ira 3 fois plus vite que le temps réel, et les héros iront
# d'eux-mêmes au terrain d'entraînement.

## Croissance (voir heroes.gd, « Croissance selon ce que le héros a fait ») : la stat qu'exerce chaque
## programme, et l'activité comptée par séance (un combat compte environ 10 à 30 coups portés et reçus).
const TRAINING_STATS := {"Maîtrise de l'épée": "str", "Utilisation du bouclier": "vit", "Maîtrise de la lance": "str",
	"Maîtrise de la dague": "dex", "Maîtrise du fouet": "dex", "Maîtrise de l'arc": "dex", "Mouvement souple": "dex"}
const TRAINING_ACTIVITY_PER_SESSION := 3


## (Étape D) Ce que le héros veut travailler maintenant : voir lobby.gd, section « Entraînement ». Déclarée ici (vide)
## pour que update_training puisse l'appeler ; la vraie fonction est dans lobby.gd (plus haut dans la pile, elle voit les armes).
func _wished_program(_hero: Dictionary) -> String:
	return ""


## Le terrain d'entraînement vient de se construire tout seul (assez d'armes tirées) : on l'annonce.
func _announce_training_ground() -> void:
	facility_completed.emit("Construction terminée", [
		"Le terrain d'entraînement a été construit avec succès !",
		"Tes héros peuvent y apprendre des compétences, même quand le jeu est fermé.",
	])
	show_tip("batiment")  # premier bâtiment : conseil du Système, après la fenêtre


# ---------------------------------------------------------------------------
# Reconversion : instructeur et administrateur (ici pour que l'entraînement et la Tour les lisent)
# ---------------------------------------------------------------------------

## Reconversion (ajout du projet, octobre 2026, d'après l'analyse du projet : un héros qui ne se bat plus, ou mal,
## sert autrement qu'en synthèse ; dans l'œuvre, les héros ont une vie et un rôle à la cité). Deux postes qui ne
## sont pas des bâtiments (hero["post"] vaut « instructeur » ou « administrateur ») :
## - instructeur, au terrain d'entraînement (une fois ouvert) : chaque instructeur présent (ni parti, ni au repos)
##   ajoute INSTRUCTOR_BONUS aux progrès de chaque séance, et INSTRUCTOR_MASTER_BONUS de plus pour un élève qu'il
##   dépasse dans la compétence travaillée (training.gd) ;
## - administrateur, à la cité : l'or des victoires dans la Tour et des ventes augmente de ADMIN_GOLD_BASE +
##   ADMIN_GOLD_PER_INT par point d'Intelligence (Intelligence 10 : +10 %), s'il est présent.
## « slots » : nombre de postes. Chiffres provisoires.
const ROLE_POSTS := {
	"instructeur": {"name": "Instructeur (terrain d'entraînement)", "slots": 2,
		"info": "Fait progresser plus vite les héros qui s'entraînent, surtout dans ce qu'il maîtrise mieux qu'eux."},
	"administrateur": {"name": "Administrateur (cité)", "slots": 1,
		"info": "Gère la cité : plus d'or pour chaque victoire dans la Tour (selon son Intelligence)."},
}
const INSTRUCTOR_BONUS := 0.15
const INSTRUCTOR_MASTER_BONUS := 0.15
const ADMIN_GOLD_BASE := 0.05
const ADMIN_GOLD_PER_INT := 0.005


## Les héros à un poste de reconversion qui sont là (ni partis, ni au repos, ni en rupture).
func role_workers(post_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hero in alive_heroes():
		if hero.get("post", "") == post_id and not is_away(hero) and not is_resting(hero) and not is_broken(hero):
			result.append(hero)
	return result


## Instructeurs (reconversion) : le multiplicateur des progrès d'un élève qui travaille « program ».
func instructor_factor(trainee: Dictionary, program: String) -> float:
	var factor := 1.0
	if not training_unlocked():
		return factor
	for teacher in role_workers("instructeur"):
		factor += INSTRUCTOR_BONUS
		if skill_level(teacher["skills"], program) > skill_level(trainee["skills"], program):
			factor += INSTRUCTOR_MASTER_BONUS
	return factor


## Les compétences de TEACHABLE_SKILLS qu'un instructeur présent connaît mieux que cet élève (et qu'il peut apprendre).
func teachable_from_instructors(trainee: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if not training_unlocked():
		return result
	for skill_name in TEACHABLE_SKILLS:
		var own := skill_level(trainee["skills"], skill_name)
		if own >= SKILL_MAX_LEVEL or (own == 0 and (not can_learn_skill(trainee, trainee["skills"], skill_name) \
				or not PersonalityEngine.has_affinity(trainee, skill_name))):
			continue
		for teacher in role_workers("instructeur"):
			if skill_level(teacher["skills"], skill_name) > own:
				result.append(skill_name)
				break
	return result


## Administrateur (reconversion) : le multiplicateur de l'or gagné (1 sans administrateur présent).
func admin_gold_factor() -> float:
	var factor := 1.0
	if tutorial_step != "":
		return factor
	for admin in role_workers("administrateur"):
		factor += ADMIN_GOLD_BASE + ADMIN_GOLD_PER_INT * float(admin["stats"].get("int", 0))
	return factor


## Vrai quand le terrain d'entraînement est ouvert (assez d'armes tirées).
func training_unlocked() -> bool:
	return weapon_draws >= TRAINING_UNLOCK_DRAWS


## Les héros vivants inscrits au terrain d'entraînement (y compris ceux partis dans la Tour).
func trainees() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hero in alive_heroes():
		if hero.get("training", "") != "":
			result.append(hero)
	return result


## Affecte un héros à un programme d'entraînement (« » = le renvoyer au repos).
## Renvoie faux si toutes les places du terrain sont prises, ou si le héros refuse (rupture, Paresseux :
## la raison est alors dans last_refusal, voir personality.gd).
func set_training(hero: Dictionary, skill_name: String) -> bool:
	last_refusal = ""
	var already: bool = hero.get("training", "") != ""
	if skill_name != "" and not already and trainees().size() >= TRAINING_SLOTS:
		return false
	if skill_name != "" and not already and not accepts_work(hero):
		return false
	if skill_name != "" and not already and is_disoriented(hero):
		# (octobre 2026) cahier : « Déboussolé : erre, cherche une sortie, refuse l'entraînement »
		last_refusal = "%s erre dans la cité à la recherche d'une sortie : il refuse de s'entraîner." % hero["name"]
		return false
	update_training()  # les séances déjà faites dans l'ancien programme sont comptées
	hero["training"] = skill_name
	hero.erase("training_auto")  # (étape A, remplacé à l'étape D : c'est le héros qui choisit son programme)
	if skill_name != "":
		hero["post"] = ""  # un héros ne travaille qu'à un endroit à la fois
	hero["training_since"] = Time.get_unix_time_from_system()
	save_game()
	if skill_name != "":
		complete_daily_mission("entrainement")
	return true


## Secondes avant la prochaine séance d'un héros à l'entraînement.
func seconds_to_next_session(hero: Dictionary) -> int:
	var elapsed: float = Time.get_unix_time_from_system() - hero.get("training_since", 0.0)
	return maxi(0, ceili(TRAINING_SESSION_SECONDS - elapsed))


## Compte les séances terminées depuis la dernière fois et donne les points de progrès.
## Les nouveautés s'ajoutent à training_news, en attendant d'être annoncées au joueur.
func update_training() -> void:
	var now := Time.get_unix_time_from_system()
	var changed := false
	for hero in trainees():
		if is_away(hero):
			continue  # dans la Tour ou au donjon journalier : pas d'entraînement pendant ce temps
		if is_resting(hero):
			hero["training_since"] = now  # (prompt 4) jour de repos : pas de séance ; elle repartira de zéro après
			continue
		var since: float = hero.get("training_since", now)
		if since > now:
			since = now  # l'horloge de l'appareil a reculé
		var sessions := int((now - since) / TRAINING_SESSION_SECONDS)
		if sessions <= 0:
			continue
		hero["training_since"] = since + sessions * TRAINING_SESSION_SECONDS
		# Des héros Mauvais à la cité baissent l'efficacité (voir personality.gd) : on le remarque ici.
		var efficiency := lobby_efficiency()
		# (étape D) il travaille ce qu'il veut maintenant : son envie a pu changer depuis la dernière séance
		var switched := _wished_program(hero)
		if switched != "":
			training_news.append(switched)
		var program: String = hero["training"]
		if program == "":
			changed = true
			continue  # (plus rien d'utile à apprendre : il est retourné au repos)
		var needed := skill_progress_needed(program)
		# (les compétences qui comptent autrement, comme l'arc par flèche, gardent le même nombre de séances par niveau)
		# (octobre 2026) les instructeurs (reconversion, plus haut) font progresser plus vite
		var points: int = maxi(1, roundi(sessions * (TRAINING_POINTS_BASE + hero["growth"]) * efficiency \
			* instructor_factor(hero, program) * needed / float(TRAINING_POINTS_PER_LEVEL)))
		training_news.append_array(add_skill_progress(hero, program, points, needed))
		# (octobre 2026) Un instructeur transmet aussi les compétences de l'œuvre qu'il connaît mieux que l'élève.
		for skill_name in teachable_from_instructors(hero):
			training_news.append_array(add_skill_progress(hero, skill_name, sessions * TEACH_POINTS_PER_SESSION,
				skill_progress_needed(skill_name)))
		# Chaque séance oriente aussi la croissance de ses stats (voir heroes.gd) : l'épée exerce la Force,
		# le bouclier la Santé. (L'entraînement ne donne ni stats ni niveaux : seulement au prochain niveau.)
		add_activity(hero, {TRAINING_STATS.get(program, "str"): sessions * TRAINING_ACTIVITY_PER_SESSION})
		if efficiency < 1.0:
			training_news.append_array(notice_bad_heroes())
		changed = true
	if changed:
		save_game()
		training_updated.emit()
