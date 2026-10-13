class_name PersonalityEngine
## Personnalité v2 : le MOTEUR (génération, lecture, accès, évolution, fonctions d'effet).
## Les données sont dans PersonalityData (personality_data.gd). Chiffres provisoires.
##
## Ce fichier ne fait pas partie de la pile de GameData : ses fonctions sont « static », on les appelle
## partout en écrivant PersonalityEngine.tier(hero, "AUD"), par exemple.
##
## Contrat (document de référence, sections 4 et 5) : aucune mécanique ne lit les paliers bruts
## (hero["persona"]["tiers"]) ; elles passent par tier(), axis(), composite(), score(), accesses()...
##
## Le profil d'un héros est rangé dans hero["persona"] (enregistré avec le héros) :
##   "version" : PersonalityData.PROFILE_VERSION
##   "tiers" : {axe: palier de -10 à +10}
##   "evo" : {axe: points d'évolution vers le palier suivant ; positif = vers le pôle +}
##   "weights" : {axe: poids personnel, x0,85 à x1,15}
##   "tics" : ["AUD+:0", ...] (pôle et numéro du tic dans PersonalityData.TICS)
##   "layers" : {"value", "need", "fear", "attachment"} (couches de profondeur)
##   "aptitudes" : {domaine: 1 à 5} (talent ; la croissance reste hero["growth"])
##   "effort" : points d'acharnement (ne font que monter)
##   "metier" : identifiant de PersonalityData.METIERS (métier ou passé)
##   "accesses" : identifiants des accès ouverts (recalculés à chaque changement de palier)
##   "legacy_traits" : anciens traits gardés d'une sauvegarde d'avant la version 4 (voir has_old_trait)
##   "secret_profile" : vrai pour un héros secret au profil écrit à la main (avec « layer_notes », « notes »)
##   "seed" : graine du tirage (le même graine redonne le même profil, à lobby égal)
##   "mind" : les 8 briques du moteur commun (P1b, vides ou neutres ; voir new_mind)
## Sur le héros lui-même : hero["revealed_traits"], les anciens traits que le Maître a vus (par nom).

const D := preload("res://scripts/game_data/personality_data.gd")

## Répartitions cumulées des paliers signés (-10 à +10), par queue de rareté (calculées une fois).
static var _cdf_cache := {}


# ---------------------------------------------------------------------------
# Génération (onglet « 1. Paliers », section 3)
# ---------------------------------------------------------------------------

## Tire le profil complet d'un nouveau héros.
## « rarity » : étoiles (1 à 5) ; « background » : identifiant de métier (vide = tiré selon les étoiles) ;
## « roster » : les héros déjà là (tirage diversifiant : on garde, parmi DIVERSITY_CANDIDATES candidats,
## celui qui ressemble le moins aux héros vivants) ; « seed » : 0 = au hasard ; « secret » : héros secret
## (queue SECRET_TAIL, pas de plafond d'absolus).
static func generate(rarity: int, background: String, roster: Array, seed: int = 0, secret := false) -> Dictionary:
	if seed == 0:
		seed = randi() + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var metier := background if D.METIERS.has(background) else roll_metier(rarity, rng, secret)

	# Les héros vivants qui ont déjà un profil : c'est à eux qu'on compare les candidats.
	var lobby: Array = []
	for other in roster:
		if other.get("alive", true) and other.has("persona"):
			lobby.append(other["persona"]["tiers"])
	var count := D.DIVERSITY_CANDIDATES if not lobby.is_empty() else 1
	var best: Dictionary = {}
	var best_distance := -1.0
	for i in count:
		var candidate := _draw_tiers(rarity, metier, rng, secret)
		var distance := _lobby_distance(candidate, lobby)
		if distance > best_distance:
			best = candidate
			best_distance = distance

	var persona := {
		"version": D.PROFILE_VERSION,
		"tiers": best,
		"evo": {},
		"weights": {},
		"tics": [],
		"layers": {},
		"aptitudes": {},
		"effort": D.EFFORT_START,
		"metier": metier,
		"accesses": [],
		"legacy_traits": [],
		"seed": seed,
		"mind": new_mind(rarity),
	}
	for axis_id in D.AXIS_ORDER:
		persona["evo"][axis_id] = 0.0
		persona["weights"][axis_id] = snappedf(rng.randf_range(1.0 - D.PERSONAL_WEIGHT_SPREAD, 1.0 + D.PERSONAL_WEIGHT_SPREAD), 0.01)
	persona["tics"] = _roll_tics(best, rng)
	persona["layers"] = _roll_layers(best, rng)
	persona["aptitudes"] = _roll_aptitudes(rarity, metier, rng)
	persona["accesses"] = _compute_accesses(best)
	return persona


## Tire un métier (1-2 étoiles) ou un passé (3 étoiles et plus) selon les poids de PersonalityData.METIERS.
static func roll_metier(rarity: int, rng: RandomNumberGenerator = null, secret := false) -> String:
	if secret:
		return D.SECRET_METIER
	var total := 0.0
	for metier_id in D.METIERS:
		total += float(D.METIERS[metier_id]["weights"].get(rarity, 0.0))
	var roll := (rng.randf() if rng else randf()) * total
	for metier_id in D.METIERS:
		roll -= float(D.METIERS[metier_id]["weights"].get(rarity, 0.0))
		if roll < 0.0:
			return metier_id
	return D.METIERS.keys()[0]


## Un tirage complet des 18 paliers : tirage corrélé (loi normale), décalé par les étoiles et le passé,
## converti en paliers sans déformer la répartition ; puis garantie de relief et plafond des absolus.
static func _draw_tiers(rarity: int, metier: String, rng: RandomNumberGenerator, secret: bool) -> Dictionary:
	# Corrélations : chaque paire partage un tirage commun, qui prend sa part du hasard de chacun des deux.
	var z := {}
	var shared := {}
	for axis_id in D.AXIS_ORDER:
		shared[axis_id] = 0.0
	for pair in D.CORRELATIONS:
		shared[pair[0]] += absf(pair[2])
		shared[pair[1]] += absf(pair[2])
	for axis_id in D.AXIS_ORDER:
		z[axis_id] = sqrt(maxf(0.0, 1.0 - shared[axis_id])) * rng.randfn(0.0, 1.0)
	for pair in D.CORRELATIONS:
		var common := rng.randfn(0.0, 1.0)
		var w := sqrt(absf(pair[2]))
		z[pair[0]] += w * common
		z[pair[1]] += w * common * signf(pair[2])
	# Décalages : 3 étoiles et plus (plus stables et audacieux), et le passé (métier).
	var rarity_bias: Dictionary = D.RARITY_BIAS.get(rarity, {})
	for axis_id in rarity_bias:
		z[axis_id] += rarity_bias[axis_id]
	var background_bias: Dictionary = D.BACKGROUND_BIAS.get(metier, {})
	for axis_id in background_bias:
		z[axis_id] += background_bias[axis_id] * D.BACKGROUND_BIAS_SCALE
	var tail: float = D.SECRET_TAIL if secret else D.RARITY_TAIL.get(rarity, 1.0)
	var tiers := {}
	for axis_id in D.AXIS_ORDER:
		tiers[axis_id] = _tier_from_uniform(_normal_cdf(z[axis_id]), tail)
	_ensure_relief(tiers, rng)
	if not secret:
		_cap_absolutes(tiers, rng)
	return tiers


## Garantie de relief : au moins un axe à ±60 (sa marque) et au moins trois à ±50 ; sinon, les axes déjà
## les plus forts sont poussés jusque-là.
static func _ensure_relief(tiers: Dictionary, rng: RandomNumberGenerator) -> void:
	var order := _strongest_first(tiers, rng)
	for i in D.RELIEF_TRAIT_COUNT:
		_push_to(tiers, order[i], D.RELIEF_TRAIT_TIER, rng)
	for i in D.RELIEF_MARK_COUNT:
		_push_to(tiers, order[i], D.RELIEF_MARK_TIER, rng)


## Plafond : au plus ABSOLUTE_MAX_COUNT axes à ±90 ou plus ; les suivants redescendent à ±80.
static func _cap_absolutes(tiers: Dictionary, rng: RandomNumberGenerator) -> void:
	var order := _strongest_first(tiers, rng)
	for i in range(D.ABSOLUTE_MAX_COUNT, order.size()):
		var axis_id: String = order[i]
		if absi(tiers[axis_id]) >= D.ABSOLUTE_TIER:
			tiers[axis_id] = signi(tiers[axis_id]) * (D.ABSOLUTE_TIER - 1)


## Les axes du plus fort au plus faible (valeur absolue ; à égalité, au hasard).
static func _strongest_first(tiers: Dictionary, rng: RandomNumberGenerator) -> Array:
	var order: Array = D.AXIS_ORDER.duplicate()
	var noise := {}
	for axis_id in order:
		noise[axis_id] = rng.randf()
	order.sort_custom(func(a, b):
		if absi(tiers[a]) != absi(tiers[b]):
			return absi(tiers[a]) > absi(tiers[b])
		return noise[a] < noise[b])
	return order


## Pousse un axe jusqu'au palier « minimum » (en valeur absolue), du côté où il penche (au hasard s'il est à 0).
static func _push_to(tiers: Dictionary, axis_id: String, minimum: int, rng: RandomNumberGenerator) -> void:
	var value: int = tiers[axis_id]
	if absi(value) >= minimum:
		return
	var side := signi(value)
	if side == 0:
		side = 1 if rng.randf() < 0.5 else -1
	tiers[axis_id] = side * minimum


## Distance d'un candidat au héros du lobby qui lui ressemble le plus (grande = original).
static func _lobby_distance(candidate: Dictionary, lobby: Array) -> float:
	if lobby.is_empty():
		return 0.0
	var nearest := INF
	for other in lobby:
		var total := 0.0
		for axis_id in D.AXIS_ORDER:
			var gap := float(candidate[axis_id] - int(other.get(axis_id, 0)))
			total += gap * gap
		nearest = minf(nearest, total)
	return nearest


## Répartition cumulée des paliers signés (-10 à +10) pour une queue de rareté.
static func _signed_cdf(tail: float) -> Array:
	var key := snappedf(tail, 0.001)
	if _cdf_cache.has(key):
		return _cdf_cache[key]
	var chances: Array = []
	var total := 0.0
	for t in D.TIER_DISTRIBUTION.size():
		var chance: float = D.TIER_DISTRIBUTION[t]
		if D.RARITY_TAIL_POWERS.has(t):
			chance *= pow(tail, D.RARITY_TAIL_POWERS[t])
		chances.append(chance)
		total += chance
	var cumulative: Array = []
	var running := 0.0
	for tier_value in range(-D.TIER_MAX, D.TIER_MAX + 1):
		var t := absi(tier_value)
		running += chances[t] / total * (1.0 if t == 0 else 0.5)  # le signe est tiré à part : moitié-moitié
		cumulative.append(running)
	_cdf_cache[key] = cumulative
	return cumulative


## Un nombre de 0 à 1 (venu du tirage corrélé) devient un palier selon la répartition.
static func _tier_from_uniform(u: float, tail: float) -> int:
	var cumulative := _signed_cdf(tail)
	for i in cumulative.size():
		if u < cumulative[i]:
			return i - D.TIER_MAX
	return D.TIER_MAX


## Répartition de la loi normale (approximation d'Abramowitz et Stegun, précise à 0,0000002 près).
static func _normal_cdf(x: float) -> float:
	var t := 1.0 / (1.0 + 0.2316419 * absf(x))
	var poly := t * (0.319381530 + t * (-0.356563782 + t * (1.781477937 + t * (-1.821255978 + t * 1.330274429))))
	var tail := exp(-x * x / 2.0) / sqrt(TAU) * poly
	return 1.0 - tail if x >= 0.0 else tail


## 3 à 6 tics, pris parmi les pôles à ±30 ou plus (les plus forts ont plus de chances).
static func _roll_tics(tiers: Dictionary, rng: RandomNumberGenerator) -> Array:
	var pool := []
	for axis_id in D.AXIS_ORDER:
		var value: int = tiers[axis_id]
		if absi(value) >= D.TIC_TIER:
			var pole := pole_id(axis_id, value)
			for i in D.TICS[pole].size():
				pool.append({"id": "%s:%d" % [pole, i], "weight": float(absi(value))})
	var wanted := rng.randi_range(D.TICS_MIN, D.TICS_MAX)
	var tics := []
	while tics.size() < wanted and not pool.is_empty():
		var total := 0.0
		for entry in pool:
			total += entry["weight"]
		var roll := rng.randf() * total
		for i in pool.size():
			roll -= pool[i]["weight"]
			if roll < 0.0 or i == pool.size() - 1:
				tics.append(pool[i]["id"])
				pool.remove_at(i)
				break
	return tics


## Couches de profondeur : chaque option est notée selon les axes qui la rendent probable, plus du hasard.
static func _roll_layers(tiers: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var layers := {}
	for layer_id in D.LAYERS:
		var options: Dictionary = D.LAYERS[layer_id]["options"]
		var best := ""
		var best_score := -INF
		for option_id in options:
			var score := rng.randfn(0.0, D.LAYER_NOISE)
			for axis_id in options[option_id]["axes"]:
				score += float(tiers[axis_id]) / D.TIER_MAX * options[option_id]["axes"][axis_id]
			if score > best_score:
				best = option_id
				best_score = score
		layers[layer_id] = best
	return layers


## Aptitudes par domaine (talent) : base selon les étoiles, ±1 au hasard, plus le métier ; de 1 à 5.
static func _roll_aptitudes(rarity: int, metier: String, rng: RandomNumberGenerator) -> Dictionary:
	var bonus: Dictionary = D.METIERS.get(metier, {}).get("aptitudes", {})
	var aptitudes := {}
	for domain in D.APTITUDE_DOMAINS:
		var value: float = D.APTITUDE_BASE.get(rarity, 2.0) + rng.randf_range(-1.0, 1.0) + float(bonus.get(domain, 0))
		aptitudes[domain] = clampi(roundi(value), D.APTITUDE_MIN, D.APTITUDE_MAX)
	return aptitudes


# ---------------------------------------------------------------------------
# Sauvegarde : migration des héros d'avant la personnalité v2
# ---------------------------------------------------------------------------

## Donne un profil aux héros qui n'en ont pas (anciennes sauvegardes), et complète un profil d'une
## version plus ancienne. Renvoie vrai si le héros a changé.
static func migrate(hero: Dictionary, roster: Array) -> bool:
	var changed := false
	# Version 2 : un héros secret qui a un profil écrit à la main le prend (même s'il avait un profil tiré).
	if is_secret_profiled(hero) and not hero.get("persona", {}).get("secret_profile", false):
		hero["persona"] = secret_persona(hero["name"])
		hero["persona"]["mind"] = new_mind(hero.get("rarity", 1))
		changed = true
	elif not hero.has("persona"):
		hero["persona"] = generate(hero.get("rarity", 1), "", roster, 0, hero.get("secret", false))
		changed = true
	# Version 2 : les anciens traits tirés à part deviennent des lectures de paliers (voir _adopt_old_traits).
	if hero.has("traits"):
		_adopt_old_traits(hero)
		changed = true
	if not hero.has("revealed_traits"):
		hero["revealed_traits"] = []
		changed = true
	var persona: Dictionary = hero["persona"]
	for key in ["tiers", "evo", "weights", "layers", "aptitudes"]:
		if not persona.has(key):
			persona[key] = {}
			changed = true
	for axis_id in D.AXIS_ORDER:
		if not persona["tiers"].has(axis_id):
			persona["tiers"][axis_id] = 0
			changed = true
		if not persona["evo"].has(axis_id):
			persona["evo"][axis_id] = 0.0
			changed = true
		if not persona["weights"].has(axis_id):
			persona["weights"][axis_id] = 1.0
			changed = true
	for key in [["tics", []], ["effort", D.EFFORT_START], ["metier", roll_metier(hero.get("rarity", 1), null, hero.get("secret", false))],
			["seed", 0], ["legacy_traits", []]]:
		if not persona.has(key[0]):
			persona[key[0]] = key[1]
			changed = true
	# Version 3 (P1b) : les 8 briques, vides ou neutres ; une brique ajoutée plus tard est complétée.
	if not persona.has("mind"):
		persona["mind"] = new_mind(hero.get("rarity", 1))
		changed = true
	else:
		var fresh := new_mind(hero.get("rarity", 1))
		for key in fresh:
			if not persona["mind"].has(key):
				persona["mind"][key] = fresh[key]
				changed = true
	if persona.get("version", 0) < D.PROFILE_VERSION:
		persona["version"] = D.PROFILE_VERSION
		changed = true
	refresh_accesses(hero)  # les règles d'accès ont pu changer depuis la dernière partie
	return changed


# ---------------------------------------------------------------------------
# Les 8 briques du moteur commun (onglet « 4. Interactions », section 2) — P1b : structures seulement
# ---------------------------------------------------------------------------
# hero["persona"]["mind"] :
#   "needs" : {besoin: 0 à 100} (NEEDS ; NEED_START = satisfait)
#   "thoughts" : [{"id", "intensity", "until"}] (pensées datées : l'humeur, en P4)
#   "expectations" : {attente: valeur} (EXPECTATIONS)
#   "dissonance" : stress cumulé d'avoir agi contre sa nature (0 au départ)
#   "memories" : [{"kind", "weight", "day", "with"}] (souvenirs marquants, en P4)
#   "opinions" : {numéro du héros (texte): -100 à +100} (ce qu'il pense des autres ; GameData.bonds reste
#                la source des liens actuels)
#   "trust" : opinion envers le Maître (la confiance), 0 au départ
#   "coping" : {"habits": {stratégie: nombre de fois}, "current": stratégie en cours ou ""}
#   "desires" : [identifiants de DESIRES] (1 à 3, en P5)
# Aucune mécanique ne les lit encore : elles n'ont aucun effet en jeu.

## Les 8 briques d'un nouveau héros, vides ou neutres.
static func new_mind(rarity: int) -> Dictionary:
	var needs := {}
	for need_id in D.NEEDS:
		needs[need_id] = D.NEED_START
	var expectations := {}
	for expectation_id in D.EXPECTATIONS:
		var data: Dictionary = D.EXPECTATIONS[expectation_id]
		expectations[expectation_id] = float(data.get("start", 0.0)) + float(data.get("start_per_star", 0.0)) * rarity
	return {
		"needs": needs,
		"thoughts": [],
		"expectations": expectations,
		"dissonance": 0.0,
		"memories": [],
		"opinions": {},
		"trust": 0.0,
		"coping": {"habits": {}, "current": ""},
		"desires": [],
	}


static func mind(hero: Dictionary) -> Dictionary:
	return hero.get("persona", {}).get("mind", {})


## Valeur d'un besoin (0 à 100 ; satisfait par défaut).
static func need(hero: Dictionary, need_id: String) -> float:
	return float(mind(hero).get("needs", {}).get(need_id, D.NEED_START))


## Poids d'un besoin pour ce héros (1 = normal) : ses axes, et la couche « besoin ». Pour P5.
static func need_weight(hero: Dictionary, need_id: String) -> float:
	var weight := 1.0
	for axis_id in D.NEEDS[need_id]["axes"]:
		weight += tier(hero, axis_id) / float(D.TIER_MAX) * float(D.NEEDS[need_id]["axes"][axis_id])
	var layer: String = hero.get("persona", {}).get("layers", {}).get("need", "")
	if D.NEED_FROM_LAYER.get(layer, "") == need_id:
		weight += D.NEED_LAYER_BONUS
	return maxf(0.1, weight)


## Opinion d'un héros sur un autre (-100 à +100 ; 0 s'il n'en a pas encore).
static func opinion(hero: Dictionary, other: Dictionary) -> float:
	return float(mind(hero).get("opinions", {}).get(str(other.get("id", -1)), 0.0))


## Change l'opinion d'un héros sur un autre (bornée). Pour P4 et le mode dev.
static func add_opinion(hero: Dictionary, other: Dictionary, delta: float) -> void:
	if not hero.has("persona") or other.get("id", -1) == hero.get("id", -2):
		return
	var opinions: Dictionary = hero["persona"]["mind"]["opinions"]
	var key := str(other["id"])
	opinions[key] = clampf(float(opinions.get(key, 0.0)) + delta, D.OPINION_MIN, D.OPINION_MAX)


## Confiance envers le Maître (son opinion du Maître, -100 à +100).
static func trust(hero: Dictionary) -> float:
	return float(mind(hero).get("trust", 0.0))


# ---------------------------------------------------------------------------
# Lecture (aucune mécanique ne lit les paliers bruts : elles passent par ici)
# ---------------------------------------------------------------------------

## Palier d'un axe, de -10 à +10 (0 si le héros n'a pas de profil).
static func tier(hero: Dictionary, axis_id: String) -> int:
	if not hero.has("persona"):
		return 0
	return int(hero["persona"]["tiers"].get(axis_id, 0))


## Valeur d'un axe de -100 à +100 (palier x 10). « target » : le héros (ou autre) vers qui il agit ; son
## cercle (intime, nouveau, plus fort...) décale les paliers avant tout calcul (Interactions, P3 : pour
## l'instant aucun décalage).
static func axis(hero: Dictionary, axis_id: String, target = null) -> int:
	return effective_tier(hero, axis_id, target) * 10


## Palier effectif : palier + décalage du cercle de la cible, borné à ±10.
static func effective_tier(hero: Dictionary, axis_id: String, target = null) -> int:
	return clampi(tier(hero, axis_id) + _circle_shift(hero, target, axis_id), -D.TIER_MAX, D.TIER_MAX)


## Décalage du cercle de la cible (onglet « 4. Interactions ») : à venir (P3). Neutre pour l'instant.
static func _circle_shift(_hero: Dictionary, _target, _axis_id: String) -> int:
	return 0


## +1, -1 ou 0 selon que l'axe a passé le seuil du trait (50) d'un côté ou de l'autre.
static func pole(hero: Dictionary, axis_id: String) -> int:
	var value := tier(hero, axis_id)
	return signi(value) if absi(value) >= 5 else 0


## Le pôle d'un axe pour un palier : « AUD+ » (Audace) ou « AUD- » (Prudence).
static func pole_id(axis_id: String, value: int) -> String:
	return axis_id + ("+" if value >= 0 else "-")


## Nom du pôle vers lequel penche l'axe (« Prudence »), ou « Neutre » à 0.
static func pole_name(axis_id: String, value: int) -> String:
	if value == 0:
		return "Neutre"
	return D.AXES[axis_id]["plus" if value > 0 else "minus"]


## Nom du palier (« Trait », « Absolu »...) d'après PersonalityData.TIER_LADDER.
static func tier_name(value: int) -> String:
	return D.TIER_LADDER[absi(value)]["name"]


## Composite (Courage, Discipline...) : moyenne pondérée des paliers, arrondie au palier, renvoyée de
## -100 à +100 comme axis(). Les mécaniques lisent d'abord les composites, un axe seul quand l'effet est précis.
static func composite(hero: Dictionary, composite_id: String, target = null) -> int:
	var tiers := {}
	for axis_id in D.COMPOSITES[composite_id]["axes"]:
		tiers[axis_id] = effective_tier(hero, axis_id, target)
	return _composite_tier(tiers, composite_id) * 10


## Composite en palier (-10 à +10), calculé sur des paliers donnés.
static func _composite_tier(tiers: Dictionary, composite_id: String) -> int:
	var data: Dictionary = D.COMPOSITES[composite_id]
	var total := 0.0
	for axis_id in data["axes"]:
		total += int(tiers.get(axis_id, 0)) * float(data["axes"][axis_id])
	return clampi(roundi(total / float(data["div"])), -D.TIER_MAX, D.TIER_MAX)


## Score d'un comportement (onglet « Facettes ») de -100 à +100 : somme des 18 contributions
## (axe / 100 x poids x poids personnel), divisée par la somme des poids en valeur absolue, x 100.
static func score(hero: Dictionary, behaviour_id: String, target = null) -> float:
	var weights: Array = D.BEHAVIOURS[behaviour_id]["weights"]
	var personal: Dictionary = hero.get("persona", {}).get("weights", {})
	var total := 0.0
	var norm := 0.0
	for i in D.AXIS_ORDER.size():
		var axis_id: String = D.AXIS_ORDER[i]
		var w: float = weights[i] * float(personal.get(axis_id, 1.0))
		total += axis(hero, axis_id, target) / 100.0 * w
		norm += absf(w)
	return clampf(total / norm * 100.0, -100.0, 100.0) if norm > 0.0 else 0.0


## Les identifiants des accès ouverts (exclusives, traits majeurs, signatures, éveils, synergies).
## Recalculés à chaque changement de palier (refresh_accesses) ; ne pas les modifier à la main.
static func accesses(hero: Dictionary) -> Array:
	return hero.get("persona", {}).get("accesses", [])


static func has_access(hero: Dictionary, access_id: String) -> bool:
	return access_id in accesses(hero)


## Recalcule les accès ouverts d'après les paliers. Renvoie [ouverts, fermés] par rapport à avant.
static func refresh_accesses(hero: Dictionary) -> Array:
	if not hero.has("persona"):
		return [[], []]
	var before: Array = hero["persona"].get("accesses", [])
	var after := _compute_accesses(hero["persona"]["tiers"])
	hero["persona"]["accesses"] = after
	return [after.filter(func(id): return not id in before), before.filter(func(id): return not id in after)]


static func _compute_accesses(tiers: Dictionary) -> Array:
	var result := []
	for axis_id in D.AXIS_ORDER:
		var value: int = tiers.get(axis_id, 0)
		if value == 0:
			continue
		var access: Dictionary = D.POLE_ACCESS[pole_id(axis_id, value)]
		for level in D.ACCESS_TIERS:
			if absi(value) < level:
				break
			if level == 5:
				result.append_array(access[5])
			else:
				result.append(access[level]["id"])
	for synergy_id in D.SYNERGIES:
		if _meets(tiers, D.SYNERGIES[synergy_id]["needs"]):
			result.append(synergy_id)
	return result


## Les tensions (pas d'accès, mais du drame) que porte le héros.
static func tensions(hero: Dictionary) -> Array:
	var result := []
	for tension_id in D.TENSIONS:
		if _meets(hero.get("persona", {}).get("tiers", {}), D.TENSIONS[tension_id]["needs"]):
			result.append(tension_id)
	return result


## Les paliers remplissent-ils ces conditions ? {axe: palier minimal dans le sens du pôle (négatif = pôle bas)}.
static func _meets(tiers: Dictionary, needs: Dictionary) -> bool:
	for axis_id in needs:
		var needed: int = needs[axis_id]
		var value: int = tiers.get(axis_id, 0)
		if (needed > 0 and value < needed) or (needed < 0 and value > needed):
			return false
	return true


## Description lisible d'un accès (mode dev) : « Trait majeur : Furie (faiblesse : ...) ».
static func access_text(access_id: String) -> String:
	if D.SYNERGIES.has(access_id):
		var synergy: Dictionary = D.SYNERGIES[access_id]
		var extra := " (il faut aussi : %s)" % synergy["extra"] if synergy.has("extra") else ""
		return "Accès croisé : %s — %s%s" % [synergy["name"], synergy["text"], extra]
	for pole in D.POLE_ACCESS:
		var access: Dictionary = D.POLE_ACCESS[pole]
		if access_id in access[5]:
			return "Exclusive (%s) : %s" % [_pole_label(pole), access_id]
		if access[7]["id"] == access_id:
			return "Trait majeur : %s — %s (faiblesse : %s)" % [access[7]["name"], access[7]["text"], access[7]["weakness"]]
		if access[9]["id"] == access_id:
			return "Signature : %s — %s (compulsion : %s)" % [access[9]["name"], access[9]["text"], access[9]["compulsion"]]
		if access[10]["id"] == access_id:
			return "Éveil possible : %s" % access[10]["text"]
	return access_id


static func _pole_label(pole: String) -> String:
	var axis_id := pole.substr(0, pole.length() - 1)
	return D.AXES[axis_id]["plus" if pole.ends_with("+") else "minus"]


## Texte d'un tic (« AUD+:0 » → « Se place toujours devant les autres »).
static func tic_text(tic_id: String) -> String:
	var parts := tic_id.split(":")
	if parts.size() != 2 or not D.TICS.has(parts[0]):
		return tic_id
	return D.TICS[parts[0]][int(parts[1])]


## Métier (ou passé) du héros : son identifiant, et son nom (« » si le héros n'a pas de profil).
static func metier(hero: Dictionary) -> String:
	return hero.get("persona", {}).get("metier", "")


static func metier_name(hero: Dictionary) -> String:
	var metier_id := metier(hero)
	return D.METIERS[metier_id]["name"] if D.METIERS.has(metier_id) else ""


# ---------------------------------------------------------------------------
# Les anciens traits, lus sur les paliers (« 1. Paliers », section 12)
# ---------------------------------------------------------------------------
# Courageux, Lâche, Loyal... ne sont plus tirés à part : un héros les a quand ses paliers remplissent les
# conditions de PersonalityData.OLD_TRAITS. Exception : persona["legacy_traits"], les anciens traits qu'un
# héros d'avant la version 4 de la sauvegarde avait et que son profil ne peut pas donner en même temps
# qu'un autre (Protecteur et Querelleur, par exemple : l'Empathie ne peut pas être à la fois >= 50 et <= 20).

## Le héros a-t-il cet ancien trait ?
static func has_old_trait(hero: Dictionary, trait_name: String) -> bool:
	if not hero.has("persona"):
		return false
	if trait_name in hero["persona"].get("legacy_traits", []):
		return true
	return _old_trait_met(hero["persona"]["tiers"], trait_name)


## Ses anciens traits, dans l'ordre de PersonalityData.OLD_TRAITS.
static func old_traits(hero: Dictionary) -> Array:
	return D.OLD_TRAITS.keys().filter(func(trait_name): return has_old_trait(hero, trait_name))


static func _old_trait_met(tiers: Dictionary, trait_name: String) -> bool:
	if not D.OLD_TRAITS.has(trait_name):
		return false
	var rule: Dictionary = D.OLD_TRAITS[trait_name]
	var composites: Dictionary = rule.get("composite", {})
	for composite_id in composites:
		var needed: int = composites[composite_id]
		var value := _composite_tier(tiers, composite_id)
		if (needed > 0 and value < needed) or (needed < 0 and value > needed):
			return false
	if not _meets(tiers, rule.get("needs", {})):
		return false
	var at_most: Dictionary = rule.get("at_most", {})
	for axis_id in at_most:
		if int(tiers.get(axis_id, 0)) > at_most[axis_id]:
			return false
	if rule.has("synergy") and not _meets(tiers, D.SYNERGIES[rule["synergy"]]["needs"]):
		return false
	return true


## Migration : pousse les paliers juste au seuil d'un ancien trait (le moins de changements possible).
static func push_old_trait(tiers: Dictionary, trait_name: String) -> void:
	var rule: Dictionary = D.OLD_TRAITS[trait_name]
	var needs: Dictionary = rule.get("needs", {}).duplicate()
	if rule.has("synergy"):
		needs.merge(D.SYNERGIES[rule["synergy"]]["needs"])
	for axis_id in needs:
		var needed: int = needs[axis_id]
		if needed > 0:
			tiers[axis_id] = maxi(int(tiers[axis_id]), needed)
		else:
			tiers[axis_id] = mini(int(tiers[axis_id]), needed)
	var at_most: Dictionary = rule.get("at_most", {})
	for axis_id in at_most:
		tiers[axis_id] = mini(int(tiers[axis_id]), at_most[axis_id])
	# Un composite : on pousse d'un palier à la fois l'axe qui y pèse le plus (Audace pour le Courage),
	# puis les suivants s'il est déjà au bout.
	var composites: Dictionary = rule.get("composite", {})
	for composite_id in composites:
		var needed: int = composites[composite_id]
		var direction := signi(needed)
		var weights: Dictionary = D.COMPOSITES[composite_id]["axes"]
		var order: Array = weights.keys()
		order.sort_custom(func(a, b): return absf(weights[a]) > absf(weights[b]))
		for guard in 100:
			if direction * _composite_tier(tiers, composite_id) >= direction * needed:
				break
			var moved := false
			for axis_id in order:
				var step := direction * signi(int(signf(weights[axis_id])))
				if absi(int(tiers[axis_id]) + step) <= D.TIER_MAX:
					tiers[axis_id] = int(tiers[axis_id]) + step
					moved = true
					break
			if not moved:
				break


## Migration (sauvegarde version 4) : le héros garde ses anciens traits (hero["traits"], tirés à part) :
## ses paliers sont poussés juste au seuil de chacun ; ceux qu'on ne peut pas avoir ensemble restent dans
## persona["legacy_traits"]. Les drapeaux « révélé » sont gardés par nom (hero["revealed_traits"]).
## Un héros secret prend son profil écrit à la main (ses anciens traits tirés au hasard ne comptent pas).
static func _adopt_old_traits(hero: Dictionary) -> void:
	var revealed: Array = hero.get("revealed_traits", [])
	var names: Array = []
	for old in hero.get("traits", []):
		names.append(old["name"])
		if old.get("known", false) and not old["name"] in revealed:
			revealed.append(old["name"])
	hero["revealed_traits"] = revealed
	hero.erase("traits")
	if is_secret_profiled(hero):
		return  # (son profil est posé par migrate)
	var tiers: Dictionary = hero["persona"]["tiers"]
	for trait_name in names:
		if D.OLD_TRAITS.has(trait_name):
			push_old_trait(tiers, trait_name)
	var legacy: Array = names.filter(func(trait_name): return D.OLD_TRAITS.has(trait_name) and not _old_trait_met(tiers, trait_name))
	hero["persona"]["legacy_traits"] = legacy
	refresh_accesses(hero)


# ---------------------------------------------------------------------------
# Héros secrets : profils écrits à la main (« 1. Paliers », section 11)
# ---------------------------------------------------------------------------

## Le profil d'un nouveau héros : celui écrit à la main pour un héros secret qui en a un, sinon un tirage.
static func new_persona(hero_name: String, rarity: int, roster: Array, secret := false) -> Dictionary:
	if secret and D.SECRET_PROFILES.has(hero_name):
		var persona := secret_persona(hero_name)
		persona["mind"] = new_mind(rarity)
		return persona
	return generate(rarity, "", roster, 0, secret)


static func is_secret_profiled(hero: Dictionary) -> bool:
	return hero.get("secret", false) and D.SECRET_PROFILES.has(hero.get("name", ""))


## Le profil écrit à la main d'un héros secret : paliers, couches, talent et effort ; pas de métier. Ni la
## répartition, ni le relief, ni le plafond des absolus. Tics et poids personnels tirés (graine).
static func secret_persona(hero_name: String, seed: int = 0) -> Dictionary:
	var profile: Dictionary = D.SECRET_PROFILES[hero_name]
	if seed == 0:
		seed = randi() + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var tiers := {}
	for axis_id in D.AXIS_ORDER:
		tiers[axis_id] = clampi(int(profile["tiers"].get(axis_id, 0)), -D.TIER_MAX, D.TIER_MAX)
	var layers := _roll_layers(tiers, rng)  # (une couche que le cahier ne donne pas : tirée selon les axes)
	layers.merge(profile.get("layers", {}), true)
	var aptitudes := {}
	var talent: int = D.TALENT_LEVELS.get(profile.get("talent", "moyen"), 3)
	for domain in D.APTITUDE_DOMAINS:
		aptitudes[domain] = int(profile.get("aptitudes", {}).get(domain, talent))
	var persona := {
		"version": D.PROFILE_VERSION,
		"tiers": tiers,
		"evo": {},
		"weights": {},
		"tics": _roll_tics(tiers, rng),
		"layers": layers,
		"layer_notes": profile.get("layer_notes", {}).duplicate(),
		"notes": profile.get("notes", []).duplicate(),
		"aptitudes": aptitudes,
		"effort": float(D.EFFORT_LEVELS.get(profile.get("effort", "moyen"), 30.0)),
		"metier": "",
		"accesses": _compute_accesses(tiers),
		"legacy_traits": [],
		"secret_profile": true,
		"seed": seed,
		"mind": new_mind(1),  # (rang attendu : voir le héros, réglé par migrate si besoin)
	}
	for axis_id in D.AXIS_ORDER:
		persona["evo"][axis_id] = 0.0
		persona["weights"][axis_id] = snappedf(rng.randf_range(1.0 - D.PERSONAL_WEIGHT_SPREAD, 1.0 + D.PERSONAL_WEIGHT_SPREAD), 0.01)
	return persona


# ---------------------------------------------------------------------------
# Évolution (onglet « 1. Paliers », section 8)
# ---------------------------------------------------------------------------

## Ajoute des points d'évolution à un axe (positifs = vers le pôle +, négatifs = vers le pôle -), à la
## vitesse de sa famille (tempérament x0,1, caractère x1, humeur x2, corps x1). « worked » : l'axe est
## travaillé (entraînement, épreuve choisie) : l'acharnement multiplie le gain (x1,05 par palier de
## Persévérance). Franchit autant de paliers que les points le permettent : aller vers un palier plus
## fort coûte EVOLUTION_COST, revenir vers zéro EVOLUTION_COST_SOFTEN.
## Renvoie les franchissements : [{"axis", "from", "to", "opened": [accès], "closed": [accès]}].
## (La « scène » du franchissement, visible du Maître, viendra avec notify en P3.)
static func gain_evolution(hero: Dictionary, axis_id: String, points: float, worked := false) -> Array:
	if not hero.has("persona") or not D.AXES.has(axis_id):
		return []
	var persona: Dictionary = hero["persona"]
	var gain := points * float(D.FAMILIES[D.AXES[axis_id]["family"]]["speed"])
	if worked:
		gain *= acharnement(hero)
	var evo: float = persona["evo"].get(axis_id, 0.0) + gain
	var crossings := []
	while evo != 0.0:
		var current: int = persona["tiers"][axis_id]
		var step := signi(int(signf(evo)))
		var next := current + step
		if absi(next) > D.TIER_MAX:
			evo = 0.0  # déjà au bout : rien de plus à gagner de ce côté
			break
		var cost := evolution_cost(current, next)
		if absf(evo) < cost:
			break
		evo -= step * cost
		persona["tiers"][axis_id] = next
		var changes := refresh_accesses(hero)
		crossings.append({"axis": axis_id, "from": current, "to": next, "opened": changes[0], "closed": changes[1]})
	persona["evo"][axis_id] = evo
	return crossings


## Coût pour passer d'un palier au palier voisin.
static func evolution_cost(from_tier: int, to_tier: int) -> float:
	if absi(to_tier) > absi(from_tier):
		return float(D.EVOLUTION_COST[absi(to_tier)])
	return float(D.EVOLUTION_COST_SOFTEN)


## Multiplicateur d'acharnement : x1,05 par palier de Persévérance (x0,61 à x1,63).
static func acharnement(hero: Dictionary) -> float:
	return pow(D.ACHARNEMENT_PER_TIER, tier(hero, "PER"))


## Ajoute des points d'effort (ils ne font que monter : un nombre négatif est ignoré).
static func add_effort(hero: Dictionary, points: float) -> void:
	if hero.has("persona") and points > 0.0:
		hero["persona"]["effort"] = float(hero["persona"].get("effort", 0.0)) + points


## Fixe un palier (mode dev, curseurs), remet ses points d'évolution à zéro et recalcule les accès.
static func set_tier(hero: Dictionary, axis_id: String, value: int) -> void:
	if not hero.has("persona"):
		return
	hero["persona"]["tiers"][axis_id] = clampi(value, -D.TIER_MAX, D.TIER_MAX)
	hero["persona"]["evo"][axis_id] = 0.0
	refresh_accesses(hero)


# ---------------------------------------------------------------------------
# Fonctions d'effet (onglet « 1. Paliers », section 5). p : palier (-10 à +10) ; t : sa valeur absolue.
# Bornes « low » / « high » facultatives : chaque effet doit rester dans les siennes.
# ---------------------------------------------------------------------------

## Additionner (chances, seuils, délais) : base + k x p.
## Exemple : chance de peur, -3 points par palier d'Audace (de -30 à +30 points).
static func effect_add(base: float, k: float, p: int, low := -INF, high := INF) -> float:
	return clampf(base + k * p, low, high)


## Multiplier (vitesses et quantités qui s'accumulent) : base x (1 + m)^p.
## Exemple : progrès d'entraînement, x1,04 par palier de Persévérance (de x0,68 à x1,48).
static func effect_mul(base: float, m: float, p: int, low := -INF, high := INF) -> float:
	return clampf(base * pow(1.0 + m, p), low, high)


## Diviser (résistances, rendements décroissants, jamais zéro) : base / (1 + d x t).
## Exemple : stress reçu / (1 + 0,06 x t de Stabilité), au mieux /1,6 à Stabilité 100.
static func effect_div(base: float, d: float, p: int, low := -INF, high := INF) -> float:
	return clampf(base / (1.0 + d * absi(p)), low, high)


## Croiser (ce qui demande deux choses à la fois) : (a / 10) x (b / 10) sur les valeurs, soit le produit
## des paliers. Exemple : capacité de trahison = Ruse x Maîtrise. Le signe de chaque palier compte :
## l'appelant passe les paliers dans le sens des pôles voulus (Ruse = -Honnêteté).
static func effect_cross(a: int, b: int, low := -INF, high := INF) -> float:
	return clampf(float(a) * float(b), low, high)


## Rapporter (qui l'emporte entre deux forces) : a / (1 + b). Exemple : contrôle de la rage = Maîtrise /
## (1 + Colère) ; sous 1, la colère déborde. « b » est une force : sous 0, elle compte pour 0.
static func effect_ratio(a: int, b: int, low := -INF, high := INF) -> float:
	return clampf(float(a) / (1.0 + maxf(0.0, float(b))), low, high)


# ---------------------------------------------------------------------------
# Pour la suite : points d'entrée neutres (document de référence, section 4)
# ---------------------------------------------------------------------------
# Ils existent déjà pour que les mécaniques puissent s'y brancher ; ils ne changent rien au jeu tant que
# leurs données (MODIFIERS, choix notés) ne sont pas écrites (P2 et P3).

## Multiplicateur d'un effet nommé (« fear_chance », « disobey_chance »...) : neutre (1,0) pour l'instant.
static func modifier(_effect: String, _hero: Dictionary, _context := {}) -> float:
	return 1.0


## Choix d'un héros parmi des options : pour l'instant, l'option par défaut (context["default"], sinon
## la première).
static func decide(_hero: Dictionary, options: Array, context := {}):
	if context.has("default"):
		return context["default"]
	return options[0] if not options.is_empty() else null


## Couche de perception (P3) : ce que le Maître apprend d'un héros (fenêtres, notifications), filtré plus
## tard selon l'Honnêteté et la confiance. Pour l'instant tout passe : le message revient tel quel.
static func notify(_hero: Dictionary, message: String, _severity := 0) -> String:
	return message


## Ce que le Maître voit d'un champ de la fiche (« serein » au bord de la rupture, plus tard). Pour
## l'instant, la vraie valeur.
static func perceived(_hero: Dictionary, _field: String, value):
	return value


## Le héros peut-il apprendre cette compétence ? (P2 : affinités et conditions de la personnalité.) Pour
## l'instant, la règle actuelle : GameData.can_learn_skill (il ne l'a pas, pas d'incompatibilité, Han à part).
## GameData est cherché dans l'arbre de scène, pour que ce fichier reste utilisable sans le jeu (banc de test).
static func can_learn(hero: Dictionary, skill_name: String, skills = null) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var game: Node = tree.root.get_node_or_null("GameData") if tree else null
	if game == null:
		return true
	return game.can_learn_skill(hero, skills if skills != null else hero.get("skills", []), skill_name)
