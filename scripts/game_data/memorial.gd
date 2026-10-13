class_name Memorial
## Le mémorial : le savoir des morts (document de référence, section 3 bis). Donnée du Maître, enregistrée
## dans la sauvegarde (GameData.memorial). P1b : les données et les fonctions seulement, pas encore de
## salle ni d'écran (mode dev > Mémorial). Chiffres provisoires.
##
## Fonctions « static » qui travaillent sur le dictionnaire du mémorial :
##   {"capacity_level": niveau des places, "memory_level": niveau de la mémoire, "entries": [souvenir]}
## Places limitées : après un combat avec des morts, le Maître coche qui enregistrer (record) ; un mort non
## enregistré emporte son savoir. Pas besoin de ramener le corps : même une équipe décimée peut être
## enregistrée en entier. Capacité et mémoire s'améliorent séparément ; monter la mémoire améliore aussi les
## souvenirs déjà enregistrés (on garde tout, on filtre à la lecture : view).

const E := preload("res://scripts/game_data/personality_engine.gd")
const D := preload("res://scripts/game_data/personality_data.gd")

## Places selon le niveau de capacité.
const CAPACITY := {1: 2, 2: 4, 3: 6, 4: 9, 5: 12}
## Ce qui est gardé selon le niveau de mémoire (cumulatif) : « battles » derniers combats, « moments_only »
## (seulement les moments clés), « knowledge » (connaissance des sujets gardée, jusqu'à ce niveau),
## « floor » (carnet complet de l'étage où il est mort et formation utilisée), « past » (savoir de son métier).
const MEMORY := {
	1: {"battles": 1, "moments_only": true, "knowledge": 0, "floor": false, "past": false},
	2: {"battles": 1, "moments_only": true, "knowledge": 2, "floor": false, "past": false},
	3: {"battles": 1, "moments_only": false, "knowledge": 2, "floor": true, "past": false},
	4: {"battles": 3, "moments_only": false, "knowledge": 2, "floor": true, "past": false},
	5: {"battles": 3, "moments_only": false, "knowledge": 3, "floor": true, "past": true},
}
const MAX_LEVEL := 5
## Les moments clés d'un combat (journal, voir Battle) : premier contact, blessures graves, chute, mort.
const KEY_MOMENTS := ["contact", "wound", "agony", "death", "rescued"]
## Revivre un souvenir : connaissance gagnée par sujet (points), stress (Sensibilité affective, lien).
const RELIVE_POINTS := 40.0
const RELIVE_STRESS := 10.0
const RELIVE_SENSITIVITY_STEP := 0.06
const RELIVE_INTIMATE_FACTOR := 2.0


static func new_memorial() -> Dictionary:
	return {"capacity_level": 1, "memory_level": 1, "entries": []}


static func migrate(memorial: Dictionary) -> Dictionary:
	var fresh := new_memorial()
	for key in fresh:
		if not memorial.has(key):
			memorial[key] = fresh[key]
	return memorial


static func capacity(memorial: Dictionary) -> int:
	return CAPACITY[clampi(int(memorial.get("capacity_level", 1)), 1, MAX_LEVEL)]


static func free_places(memorial: Dictionary) -> int:
	return capacity(memorial) - memorial.get("entries", []).size()


## Améliorations (plus tard payées au lobby ; mode dev pour l'instant). Renvoient le nouveau niveau.
static func upgrade_capacity(memorial: Dictionary) -> int:
	memorial["capacity_level"] = mini(MAX_LEVEL, int(memorial.get("capacity_level", 1)) + 1)
	return memorial["capacity_level"]


static func upgrade_memory(memorial: Dictionary) -> int:
	memorial["memory_level"] = mini(MAX_LEVEL, int(memorial.get("memory_level", 1)) + 1)
	return memorial["memory_level"]


static func has_entry(memorial: Dictionary, hero_id: int) -> bool:
	return memorial.get("entries", []).any(func(entry): return entry["id"] == hero_id)


static func entry(memorial: Dictionary, hero_id: int) -> Dictionary:
	for item in memorial.get("entries", []):
		if item["id"] == hero_id:
			return item
	return {}


## Enregistre les héros choisis par le Maître (morts seulement, pas déjà là), tant qu'il reste des places.
## On garde tout ce qu'il savait ; la mémoire du mémorial décide de ce qu'on peut en relire (view).
## Renvoie {"recorded": [noms], "refused": [noms]} (refusés : plus de place, vivant ou déjà enregistré).
static func record(memorial: Dictionary, heroes: Array, day := -1) -> Dictionary:
	migrate(memorial)
	var result := {"recorded": [], "refused": []}
	for hero in heroes:
		if hero.get("alive", true) or has_entry(memorial, hero["id"]) or free_places(memorial) <= 0:
			result["refused"].append(hero.get("name", "?"))
			continue
		var battles: Array = hero.get("recent_battles", [])
		var last: Dictionary = battles.back() if not battles.is_empty() else {}
		memorial["entries"].append({
			"id": hero["id"], "name": hero["name"], "rarity": hero.get("rarity", 1), "class": hero.get("class", ""),
			"cause": hero.get("death_cause", ""), "day": E.today() if day < 0 else day,
			"metier": E.metier(hero), "subjects": E.subjects(hero).duplicate(true),
			"battles": battles.duplicate(true), "floor": last.get("floor", 0),
			"formation": last.get("formation", []).duplicate(true),
		})
		result["recorded"].append(hero["name"])
	return result


## Ce que le mémorial garde d'un souvenir, selon son niveau de mémoire : {"battles": [combats (moments
## clés seulement aux niveaux 1-2)], "subjects": {sujet: connaissance (bornée)}, "floor", "formation",
## "past" (métier)}.
static func view(memorial: Dictionary, item: Dictionary) -> Dictionary:
	var memory: Dictionary = MEMORY[clampi(int(memorial.get("memory_level", 1)), 1, MAX_LEVEL)]
	var battles := []
	for battle in item.get("battles", []).slice(-int(memory["battles"])):
		var copy: Dictionary = battle.duplicate(true)
		if memory["moments_only"]:
			copy["events"] = copy.get("events", []).filter(func(event): return event.get("kind", "") in KEY_MOMENTS)
		battles.append(copy)
	var known := {}
	for subject in item.get("subjects", {}):
		var level := mini(int(item["subjects"][subject].get("knowledge", 0)), int(memory["knowledge"]))
		if level > 0:
			known[subject] = level
	return {"battles": battles, "subjects": known, "floor": item.get("floor", 0) if memory["floor"] else 0,
		"formation": item.get("formation", []) if memory["floor"] else [],
		"past": item.get("metier", "") if memory["past"] else ""}


## Retire un héros du mémorial (le Maître a confirmé dans la fenêtre « Retirer [Nom] du mémorial ? ») :
## son souvenir est effacé, la place libérée. Renvoie le message à afficher, « [Nom] sera oublié à jamais. »,
## ou « » s'il n'y était pas. (Les réactions des héros liés viendront avec les événements, P4.)
static func remove(memorial: Dictionary, hero_id: int) -> String:
	var item := entry(memorial, hero_id)
	if item.is_empty():
		return ""
	memorial["entries"].erase(item)
	return "%s sera oublié à jamais." % item["name"]


## Un héros vivant se recueille et revit un souvenir : il gagne la connaissance du mort (ce que la mémoire
## du mémorial en garde). C'est aussi une épreuve : renvoie le stress que ça lui coûte (Sensibilité
## affective, x2 pour un intime ; le Détaché apprend froidement, sans souffrir) et sa réaction (peur, haine,
## détermination ou froid), qui seront appliqués en P4. Renvoie {"subjects": {sujet: niveaux gagnés},
## "stress", "reaction"}.
static func relive(memorial: Dictionary, hero: Dictionary, hero_id: int) -> Dictionary:
	var item := entry(memorial, hero_id)
	if item.is_empty() or not hero.has("persona"):
		return {}
	var kept := view(memorial, item)
	var gains := {}
	for subject in kept["subjects"]:
		var gained := E.learn_subject(hero, subject, RELIVE_POINTS, kept["subjects"][subject])
		if gained > 0:
			gains[subject] = gained
	var stress := RELIVE_STRESS * E.effect_mul(1.0, RELIVE_SENSITIVITY_STEP, E.tier(hero, "SEN"))
	if E.circle(hero, {"id": hero_id, "fights": 99}) == "intime":
		stress *= RELIVE_INTIMATE_FACTOR
	var reaction := "peur"
	if E.tier(hero, "SEN") <= -5:
		reaction = "froid"
		stress = 0.0
	elif E.tier(hero, "PER") >= 5:
		reaction = "détermination"
	elif E.tier(hero, "COL") >= 5:
		reaction = "haine"
	return {"subjects": gains, "stress": stress, "reaction": reaction}


## Le Maître regarde le souvenir : le replay de son dernier combat, vu par le mort (les événements que la
## mémoire du mémorial garde). [] s'il n'y a rien.
static func replay(memorial: Dictionary, hero_id: int) -> Array:
	var item := entry(memorial, hero_id)
	if item.is_empty():
		return []
	var battles: Array = view(memorial, item)["battles"]
	return battles.back().get("events", []) if not battles.is_empty() else []
