class_name Library
## La bibliothèque : le savoir des survivants (document de référence, section 3 bis ; « Compétences :
## registre et recherche », section 10). Donnée du Maître, enregistrée dans la sauvegarde (GameData.library).
## P1b : les données et les fonctions seulement, pas encore de salle ni d'écran (mode dev > Bibliothèque).
## Chiffres provisoires.
##
## Fonctions « static » qui travaillent sur le dictionnaire de la bibliothèque (pour que le banc de test les
## utilise sans le jeu) :
##   {"level": niveau de la salle,
##    "bestiary": {sujet: fiche}, "floors": {"tour:5": carnet}, "formations": [formation],
##    "strategies": {nom: stratégie}, "skills": {compétence: entrée du registre}}
## Seul un héros revenu vivant peut y consigner ce qu'il a appris (deposit) ; rien n'est acquis tant que ce
## n'est pas consigné. Une information d'un seul héros est marquée non vérifiée jusqu'à ce qu'un second la
## confirme.

const E := preload("res://scripts/game_data/personality_engine.gd")
const D := preload("res://scripts/game_data/personality_data.gd")

## Niveaux de la salle : places pour les registres (fiches au plus par registre), vitesse d'étude, postes
## de bibliothécaire.
const LEVELS := {
	1: {"places": 30, "study_speed": 1.0, "librarians": 0},
	2: {"places": 60, "study_speed": 1.25, "librarians": 1},
	3: {"places": 120, "study_speed": 1.5, "librarians": 2},
}
## Étude d'une fiche : points de connaissance par séance ; niveau atteint au plus (3 avec un bibliothécaire ;
## le niveau 4 ne s'apprend que sur le terrain) ; la lecture calme un peu, un récit d'horreur (danger
## HORROR_DANGER ou plus) inquiète un Vulnérable.
const STUDY_POINTS := 15.0
const STUDY_CALM := -3.0
const HORROR_DANGER := 70.0
const HORROR_FEAR := 3.0
## Pessimisme : le danger écrit est surestimé (+5 % par palier de Pessimisme).
const PESSIMISM_STEP := 0.05
## Une fiche est vérifiée quand ce nombre de héros différents l'ont écrite.
const VERIFIED_AUTHORS := 2
## États du registre des compétences, de « on dit que » à la méthode vérifiée.
const SKILL_STATES := ["inconnue", "rumeur", "piste", "hypothese", "en_test", "verifiee", "amelioree"]
const SKILL_STATE_NAMES := {"inconnue": "Inconnue", "rumeur": "Rumeur", "piste": "Piste", "hypothese": "Hypothèse",
	"en_test": "En test", "verifiee": "Méthode vérifiée", "amelioree": "Améliorée"}


static func new_library() -> Dictionary:
	return {"level": 1, "bestiary": {}, "floors": {}, "formations": [], "strategies": {}, "skills": {}}


## Complète une bibliothèque d'une ancienne sauvegarde (registre ajouté plus tard...).
static func migrate(library: Dictionary) -> Dictionary:
	var fresh := new_library()
	for key in fresh:
		if not library.has(key):
			library[key] = fresh[key]
	return library


## Le héros sait-il écrire ? (Métier lettré, ou héros secret.)
static func literate(hero: Dictionary) -> bool:
	return hero.get("secret", false) or E.metier(hero) in D.LITERATE_METIERS


## Le héros consigne ce qu'il rapporte (son pending_report), filtré par sa personnalité :
## - Curiosité ou Acuité des sens (>= 50) : fiches plus détaillées ;
## - Pessimisme : danger surestimé ;
## - Ruse (Honnêteté <= -50) : peut omettre une erreur (marqué en mode dev) ;
## - Ambition (>= 50) : exagère son rôle (carnets d'étage).
## Une fiche écrite par un deuxième héros devient vérifiée. Un illettré raconte : la fiche est marquée
## « racontée » (quelqu'un d'autre l'écrit). Vide son rapport. Renvoie ce qui a été consigné (textes).
static func deposit(library: Dictionary, hero: Dictionary) -> Array:
	migrate(library)
	var written := []
	var author := {"id": hero.get("id", 0), "name": hero.get("name", "?")}
	for item in E.pending_report(hero):
		match item.get("kind", ""):
			"subject":
				written.append(_deposit_subject(library, hero, author, item))
			"floor":
				written.append(_deposit_floor(library, hero, author, item))
			"formation":
				var formation: Dictionary = item.duplicate(true)
				formation["author"] = author
				library["formations"].append(formation)
				written.append("Formation de l'étage %d" % item.get("floor", 0))
			"strategy":
				var strategy: Dictionary = library["strategies"].get(item["name"], {"name": item["name"], "floors": [], "successes": 0, "authors": []})
				if not item.get("floor", 0) in strategy["floors"]:
					strategy["floors"].append(item.get("floor", 0))
				strategy["successes"] += 1 if item.get("success", false) else 0
				_add_author(strategy, author)
				library["strategies"][item["name"]] = strategy
				written.append("Stratégie : %s" % item["name"])
	if hero.has("persona"):
		hero["persona"]["pending_report"] = []
	return written


static func _deposit_subject(library: Dictionary, hero: Dictionary, author: Dictionary, item: Dictionary) -> String:
	var subject: String = item["subject"]
	var entry: Dictionary = library["bestiary"].get(subject, {"subject": subject, "knowledge": 0, "detail": 0,
		"danger": 0.0, "authors": [], "verified": false, "told": false, "omission": false, "prior": false})
	var knowledge_level: int = item.get("knowledge", 0)
	var detail := knowledge_level
	if E.tier(hero, "CUR") >= 5 or E.tier(hero, "ACU") >= 5:
		detail = mini(D.KNOWLEDGE_MAX, detail + 1)
	var danger: float = item.get("apprehension", 50.0) * (1.0 + PESSIMISM_STEP * maxi(0, -E.tier(hero, "OPT")))
	entry["knowledge"] = maxi(entry["knowledge"], knowledge_level)
	entry["detail"] = maxi(entry["detail"], detail)
	entry["danger"] = danger if entry["authors"].is_empty() else (float(entry["danger"]) + danger) / 2.0
	entry["told"] = entry["told"] or not literate(hero)
	entry["omission"] = entry["omission"] or E.tier(hero, "HON") <= -5
	entry["prior"] = entry["prior"] or E.subjects(hero).get(subject, {}).get("prior", false)
	_add_author(entry, author)
	library["bestiary"][subject] = entry
	return "Bestiaire : %s (connaissance %d)" % [D.SUBJECTS.get(subject, {}).get("name", subject), knowledge_level]


static func _deposit_floor(library: Dictionary, hero: Dictionary, author: Dictionary, item: Dictionary) -> String:
	var key := "tour:%d" % item.get("floor", 0)
	var notes: Dictionary = library["floors"].get(key, {"floor": item.get("floor", 0), "visits": 0, "victories": 0,
		"waves": 0, "killed_by": [], "worked": [], "authors": [], "verified": false, "exaggerated": false})
	notes["visits"] += 1
	notes["victories"] += 1 if item.get("victory", false) else 0
	notes["waves"] = maxi(notes["waves"], item.get("waves", 0))
	for cause in item.get("killed_by", []):
		if not cause in notes["killed_by"]:
			notes["killed_by"].append(cause)
	for what in item.get("worked", []):
		if not what in notes["worked"]:
			notes["worked"].append(what)
	notes["exaggerated"] = notes["exaggerated"] or E.tier(hero, "AMB") >= 5
	_add_author(notes, author)
	library["floors"][key] = notes
	return "Carnet de l'étage %d" % item.get("floor", 0)


static func _add_author(entry: Dictionary, author: Dictionary) -> void:
	if not entry["authors"].any(func(other): return other["id"] == author["id"]):
		entry["authors"].append(author)
	entry["verified"] = entry["authors"].size() >= VERIFIED_AUTHORS


## Un héros étudie une fiche du bestiaire (activité du lobby, comme l'entraînement) : connaissance jusqu'au
## niveau 2 (3 avec un bibliothécaire), jamais au-delà de ce que la fiche contient ; un peu moins
## d'appréhension (on sait à quoi s'attendre), sauf un récit d'horreur chez un Vulnérable. Renvoie le
## nombre de niveaux gagnés.
static func study(library: Dictionary, hero: Dictionary, subject: String, librarian := false) -> int:
	var entry: Dictionary = library.get("bestiary", {}).get(subject, {})
	if entry.is_empty():
		return 0
	var cap := mini(D.KNOWLEDGE_CAP["study_librarian" if librarian else "study"], int(entry["knowledge"]))
	var fear := STUDY_CALM
	if float(entry["danger"]) >= HORROR_DANGER and E.tier(hero, "STA") <= -5:
		fear = HORROR_FEAR
	var speed: float = LEVELS.get(int(library.get("level", 1)), LEVELS[1])["study_speed"]
	return E.learn_subject(hero, subject, STUDY_POINTS * speed, cap, fear)


## Nombre de fiches vérifiées (bestiaire et carnets) : comptera dans le niveau du lobby.
static func verified_count(library: Dictionary) -> int:
	var count := 0
	for register in ["bestiary", "floors"]:
		for key in library.get(register, {}):
			if library[register][key].get("verified", false):
				count += 1
	return count


# ---------------------------------------------------------------------------
# Registre des compétences (« Compétences : registre et recherche », sections 3 et 10)
# ---------------------------------------------------------------------------
# Entrée : {"skill", "state" (SKILL_STATES), "elements" ({élément: valeur}, vrais ou faux), "authors",
# "verified", "testable"}. La recherche autonome (research_engine.gd) viendra avec la phase 2.

static func skill_entry(library: Dictionary, skill_name: String) -> Dictionary:
	return library.get("skills", {}).get(skill_name, {"skill": skill_name, "state": "inconnue", "elements": {},
		"authors": [], "verified": false, "testable": true})


## Fait avancer (ou corrige) l'état d'une compétence dans le registre : rumeur, piste (un élément de recette,
## vrai ou faux), hypothèse, en test, méthode vérifiée (au moins un héros l'a apprise ainsi), améliorée.
static func set_skill_state(library: Dictionary, skill_name: String, state: String, author := {}, elements := {}) -> Dictionary:
	migrate(library)
	var entry := skill_entry(library, skill_name)
	if state in SKILL_STATES:
		entry["state"] = state
	entry["elements"].merge(elements, true)
	if not author.is_empty() and not entry["authors"].any(func(other): return other["id"] == author.get("id", -1)):
		entry["authors"].append(author)
	entry["verified"] = SKILL_STATES.find(entry["state"]) >= SKILL_STATES.find("verifiee")
	library["skills"][skill_name] = entry
	return entry
