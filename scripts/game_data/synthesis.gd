class_name GameSynthesis
extends GameLobby
## Rendre un héros plus fort : promotion (passage à l'étoile suivante) et synthèse (chambre de
## synthèse, où l'on sacrifie des héros pour en renforcer un autre).
## Fait partie de la pile de GameData (voir game_data.gd).


# ---------------------------------------------------------------------------
# Promotion (passage à l'étoile suivante)
# ---------------------------------------------------------------------------
# Un héros arrivé au niveau maximum de sa rareté peut passer à l'étoile suivante : il paie de l'or
# et des pierres d'attribut (matériau de l'entrepôt), gagne une étoile (donc un niveau maximum plus
# haut et de meilleures statistiques) et une compétence spéciale.
# Les pierres d'attribut se trouvent (rarement) au donjon journalier, et sur les étages de boss de la Tour.
# (Le cahier demande aussi un certain niveau de compétence ; on le fixera quand l'œuvre en parlera.)
# Le nom de la pierre (PROMOTION_STONE) est avec les matériaux de l'entrepôt (items.gd).

## Coût de la promotion, selon les étoiles actuelles du héros (1 = passer de 1 à 2 étoiles).
## Provisoire, en attente de l'œuvre.
const PROMOTION_COSTS := {
	1: {"gold": 20000, "stones": 1},
	2: {"gold": 50000, "stones": 3},
	3: {"gold": 100000, "stones": 6},
	4: {"gold": 200000, "stones": 10},
}
## Étoiles maximum par promotion pour l'instant (6 et 7 étoiles viendront plus tard, cahier : phase 6).
const MAX_PROMOTION_RARITY := 5

## Compétences spéciales de promotion : une au hasard, parmi celles que le héros n'a pas encore.
## Provisoire, en attente de l'œuvre (effets dans battle.gd, chiffres ci-dessous).
const PROMOTION_SKILLS := ["Volonté de fer", "Second souffle", "Coup précis", "Peau de pierre", "Vivacité"]
const IRON_WILL_HP_PER_LEVEL := 0.1       # Volonté de fer : +10 % de vie maximum par niveau
const SECOND_WIND_HEAL := 0.15            # Second souffle : soigne 15 % (+5 % par niveau) une fois par combat
const SECOND_WIND_HEAL_PER_LEVEL := 0.05
const PRECISE_STRIKE_CRIT_PER_LEVEL := 0.05  # Coup précis : +5 % de coups critiques par niveau
const STONE_SKIN_PER_LEVEL := 0.04        # Peau de pierre : 4 % de dégâts subis en moins par niveau
const QUICKNESS_PER_LEVEL := 0.05         # Vivacité : coups 5 % plus rapides par niveau

## Pierres d'attribut données par un étage de boss de la Tour conquis pour la première fois
## (la chance d'en ramasser une au donjon journalier, STONE_PICKUP_CHANCE, est dans lobby.gd).
const BOSS_STONES := 1


## Le coût de la promotion d'un héros ({"gold", "stones"}), ou {} s'il ne peut plus monter.
func promotion_cost(hero: Dictionary) -> Dictionary:
	return PROMOTION_COSTS.get(hero["rarity"], {})


## Pourquoi ce héros ne peut pas être promu (texte), ou "" si c'est possible.
func promotion_problem(hero: Dictionary) -> String:
	if not hero["alive"]:
		return "Il n'est plus de ce monde."
	if hero["rarity"] >= MAX_PROMOTION_RARITY or promotion_cost(hero).is_empty():
		return "Déjà au maximum (%d étoiles)." % MAX_PROMOTION_RARITY
	if not is_max_level(hero):
		return "Il doit d'abord atteindre le niveau %d." % MAX_LEVEL[hero["rarity"]]
	if is_away(hero):
		return "Il est parti (%s)." % activity_text(hero)
	var cost := promotion_cost(hero)
	if gold < cost["gold"]:
		return "Pas assez d'or."
	if material_count(PROMOTION_STONE) < cost["stones"]:
		return "Pas assez de pierres d'attribut."
	return ""


## Promeut un héros. Renvoie les lignes à annoncer, ou [] si c'est impossible.
func promote(hero: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if promotion_problem(hero) != "":
		return lines
	var cost := promotion_cost(hero)
	gold -= cost["gold"]
	gold_changed.emit(gold)
	_take_material(PROMOTION_STONE, cost["stones"])
	lines.append_array(_apply_promotion(hero))
	save_game()
	return lines


## Le passage à l'étoile suivante lui-même (sans payer ni vérifier) : stats, niveau maximum,
## compétence spéciale. Renvoie les lignes à annoncer.
func _apply_promotion(hero: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var old_rarity: int = hero["rarity"]
	hero["rarity"] += 1
	hero["xp"] = 0
	# Les statistiques montent de l'écart entre les deux raretés (ex. 1 → 2 étoiles : +2 partout).
	var gap: int = BASE_STAT[hero["rarity"]] - BASE_STAT[old_rarity]
	for stat in STAT_NAMES:
		hero["stats"][stat] += gap
	lines.append("%s passe à %s ! Niveau maximum : %d." % [hero["name"], "★".repeat(hero["rarity"]), MAX_LEVEL[hero["rarity"]]])
	lines.append("Toutes ses statistiques : +%d." % gap)
	var choices := PROMOTION_SKILLS.filter(func(name): return skill_level(hero["skills"], name) == 0)
	if not choices.is_empty():
		var skill_name: String = choices.pick_random()
		hero["skills"].append({"name": skill_name, "rank": "Spéciale", "level": 1})
		lines.append("Compétence spéciale : %s." % skill_name)
	return lines


# ---------------------------------------------------------------------------
# Synthèse de héros (chambre de synthèse)
# ---------------------------------------------------------------------------
# On sacrifie un ou plusieurs héros (de n'importe quel rang) pour en renforcer un autre (cahier :
# « on fusionne 2 héros ou plus : un seul survit »). Les sacrifiés disparaissent pour toujours (comme
# une mort, leurs armes sont perdues avec eux). Le héros renforcé :
# - gagne de l'expérience, et au moins un niveau (cahier : « le héros renforcé monte de niveau »),
#   sauf s'il est déjà au niveau maximum ;
# - pour chaque sacrifié, a des chances de récupérer une de ses compétences, au niveau 1 (compétence héritée) ;
# - s'il se bat de loin, a des chances de gagner Œil de faucon (cahier : Jenna l'obtient en synthèse) ;
# - très rarement, gagne Analyse froide.
# (Le cahier parle aussi d'une perte de moral : elle viendra avec le moral, en phase 5.)
# Chiffres provisoires.

## Nombre de héros qu'on peut sacrifier d'un coup.
const SYNTHESIS_MAX_SACRIFICES := 5
## Expérience gagnée par sacrifié : une base, plus (niveau x étoiles du sacrifié) x ce nombre.
const SYNTHESIS_XP_BASE := 20
const SYNTHESIS_XP_PER_LEVEL_STAR := 10
## Chance de récupérer une compétence de chaque sacrifié (au niveau 1), et chance d'Analyse froide.
const INHERIT_CHANCE := 0.2
const COLD_ANALYSIS_CHANCE := 0.01
## Analyse froide : précision et coups critiques en plus, par niveau (0.1 = 10 %).
## La précision réduit les chances d'esquive de la cible.
const COLD_ANALYSIS_PER_LEVEL := 0.1
## Œil de faucon : chance à chaque synthèse (apprise, ou un niveau de plus) pour les classes qui
## se battent de loin ; puis, pour les tirs (flèches et sorts), portée en plus (en cases) et
## précision en plus, par niveau.
const HAWK_EYE_CHANCE := 0.3
const HAWK_EYE_CLASSES := ["Archer", "Mage", "Soigneur"]
const HAWK_EYE_REACH_PER_LEVEL := 0.3
const HAWK_EYE_PRECISION_PER_LEVEL := 0.05


## Expérience que le héros renforcé gagne en sacrifiant « sacrifice ».
func synthesis_xp(sacrifice: Dictionary) -> int:
	return SYNTHESIS_XP_BASE + sacrifice["level"] * sacrifice["rarity"] * SYNTHESIS_XP_PER_LEVEL_STAR


## Expérience totale d'une synthèse : celle de chaque sacrifié, et au moins de quoi monter
## d'un niveau. 0 si le héros est déjà au niveau maximum.
func synthesis_total_xp(target: Dictionary, sacrifices: Array) -> int:
	if is_max_level(target):
		return 0
	var xp := 0
	for sacrifice in sacrifices:
		xp += synthesis_xp(sacrifice)
	return maxi(xp, xp_to_next(target["level"]) - target["xp"])


## Pourquoi ce héros ne peut pas être sacrifié pour renforcer « target » (texte), ou "" si c'est possible.
func synthesis_problem(target: Dictionary, sacrifice: Dictionary) -> String:
	if not "synthese" in buildings:
		return "La chambre de synthèse n'est pas construite."
	if target["id"] == sacrifice["id"]:
		return "Un héros ne peut pas se sacrifier pour lui-même."
	if not target["alive"] or not sacrifice["alive"]:
		return "Les deux héros doivent être en vie."
	if sacrifice.get("secret", false):
		return "Un héros légendaire ne peut pas être sacrifié."
	if is_favorite(sacrifice):
		return "Un héros favori ne peut pas être sacrifié (retire-le d'abord des favoris)."
	if is_away(target) or is_away(sacrifice):
		return "Les deux héros doivent être à la cité."
	return ""


## Vrai si ce héros peut gagner Œil de faucon en synthèse (sa classe se bat de loin).
func can_get_hawk_eye(hero: Dictionary) -> bool:
	return hero["class"] in HAWK_EYE_CLASSES and _own_skill_level(hero["skills"], "Œil de faucon") < SKILL_MAX_LEVEL


## La synthèse : « sacrifices » disparaissent pour renforcer « target ».
## Renvoie les lignes à annoncer, ou [] si c'est impossible.
func synthesize(target: Dictionary, sacrifices: Array) -> Array[String]:
	var lines: Array[String] = []
	if sacrifices.is_empty() or sacrifices.size() > SYNTHESIS_MAX_SACRIFICES:
		return lines
	for sacrifice in sacrifices:
		if synthesis_problem(target, sacrifice) != "":
			return lines

	var xp := synthesis_total_xp(target, sacrifices)
	# Les sacrifiés disparaissent pour toujours.
	for sacrifice in sacrifices:
		sacrifice["alive"] = false
		sacrifice["death_cause"] = "sacrifié en synthèse pour renforcer %s" % target["name"]
		_remove_from_teams(sacrifice["id"])
		lines.append("%s (%s) a disparu pour toujours." % [sacrifice["name"], "★".repeat(sacrifice["rarity"])])

	if xp == 0:
		lines.append("%s est déjà au niveau maximum : l'expérience est perdue (pense à la promotion)." % target["name"])
	else:
		var levels := gain_xp(target, xp)
		lines.append("%s gagne %d d'expérience%s." % [target["name"], xp,
			" et passe au niveau %d" % target["level"] if levels > 0 else ""])

	# Compétence héritée : pour chaque sacrifié, une chance de récupérer une de ses compétences.
	for sacrifice in sacrifices:
		if randf() >= INHERIT_CHANCE:
			continue
		var candidates := []
		for skill in sacrifice["skills"]:
			if can_learn_skill(target, target["skills"], skill["name"]) and not skill["name"] in SKILL_FUSIONS:
				candidates.append(skill["name"])
		if not candidates.is_empty():
			var inherited: String = candidates.pick_random()
			target["skills"].append(new_skill(inherited))
			lines.append("Compétence héritée de %s : %s (niveau 1) !" % [sacrifice["name"], inherited])
	# Œil de faucon : pour ceux qui se battent de loin ; un niveau de plus s'ils l'ont déjà.
	if can_get_hawk_eye(target) and randf() < HAWK_EYE_CHANCE:
		var level := _own_skill_level(target["skills"], "Œil de faucon")
		if level == 0:
			target["skills"].append(new_skill("Œil de faucon"))
			lines.append("Nouvelle compétence : Œil de faucon !")
		else:
			for skill in target["skills"]:
				if skill["name"] == "Œil de faucon":
					skill["level"] += 1
			lines.append("Œil de faucon passe au niveau %d !" % (level + 1))
	# Analyse froide : très rare, juste après une synthèse.
	if randf() < COLD_ANALYSIS_CHANCE and can_learn_skill(target, target["skills"], "Analyse froide"):
		target["skills"].append(new_skill("Analyse froide"))
		lines.append("Compétence rare : Analyse froide !")
	lines.append(mental_after_synthesis(sacrifices.size()))
	tidy_arsenal()  # les armes des sacrifiés sont perdues (et la partie est sauvegardée)
	return lines
