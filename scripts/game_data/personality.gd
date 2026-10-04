class_name GamePersonality
extends GameHeroes
## La personnalité des héros (cahier, onglet « Personnalité ») : santé mentale et traits de caractère.
## Les héros sont des personnes, pas des stats : les combats durs, les boss, les blessures, la mort
## d'un allié, les synthèses et les défaites les usent ; le repos et le travail au lobby, et la victoire,
## les réparent. Sous 60, un héros peut refuser les ordres en combat (désobéissance) ; à 0, c'est la
## rupture (effondrement ou éveil), puis l'état « En rupture » hors combat. Les héros qui combattent
## ensemble se lient (connaissance, ami, frère d'armes).
## Fait partie de la pile de GameData (voir game_data.gd).


# ---------------------------------------------------------------------------
# Santé mentale
# ---------------------------------------------------------------------------
# hero["mental"] : de 0 à MENTAL_MAX (100 à l'invocation). Nombre à virgule (la remontée au lobby est
# continue), affiché arrondi. Calme réduit les pertes ; Berserk en coûte. Tous les chiffres sont provisoires.

const MENTAL_MAX := 100.0

## Pertes pendant un combat de la Tour (battle.gd les applique en direct, d'où la rupture en plein combat).
const MENTAL_LOSS_WOUNDS := 12.0       # blessures : ceci pour une vie entière perdue (en proportion des coups)
const MENTAL_LOSS_BLEEDING := 4.0      # se met à saigner (la première fois du combat)
const MENTAL_LOSS_BOSS := 8.0          # un boss arrive sur le terrain
const MENTAL_LOSS_WARNINGS := 6.0      # quête à triple avertissement (défense de la cité), au début
const MENTAL_LOSS_ALLY_DEATH := 10.0   # un allié tombe
const MENTAL_LOSS_BERSERK := 8.0       # entre en Berserk : la rage use l'esprit
## Perte à la fin du combat.
const MENTAL_LOSS_DEFEAT := 10.0       # défaite (ou fuite)
## Gain d'une victoire (après les pertes du combat).
const MENTAL_GAIN_VICTORY := 5.0
## Synthèse (vue comme une exécution) : chaque héros vivant qui reste perd ceci par héros sacrifié.
const MENTAL_LOSS_SYNTHESIS := 3.0
## Remontée à la cité, par heure de temps réel : au repos, ou avec un travail (poste d'assistant ou
## terrain d'entraînement). Rien pour un héros parti (Tour, donjon journalier).
const MENTAL_REST_PER_HOUR := 10.0
const MENTAL_WORK_PER_HOUR := 8.0
## Calme protège : chaque niveau retire cette part des pertes (niveau 10 : moitié moins).
const CALM_MENTAL_GUARD_PER_LEVEL := 0.05
## En combat : sous MENTAL_MALUS_START, l'attaque et la défense baissent peu à peu, jusqu'à
## MENTAL_MALUS_MAX (30 % de moins) à 0 de santé mentale.
const MENTAL_MALUS_START := 60.0
const MENTAL_MALUS_MAX := 0.3


# ---------------------------------------------------------------------------
# Traits de caractère
# ---------------------------------------------------------------------------
# Chaque héros a 1 ou 2 traits fixes (hero["traits"] : [{"name", "known"}]), tirés à l'invocation et
# cachés au début (« ? »). Un trait se révèle la première fois qu'il agit, ou après quelques combats.
# Pour l'instant, sont branchés : les effets sur le stress (Courageux, Lâche, Protecteur, Ambitieux) et
# Loyal (désobéissance) ; les autres viendront avec la vie au lobby.

## Les traits et ce qu'ils font (affiché sur la fiche une fois révélés).
const TRAITS := {
	"Courageux": "Stresse moitié moins face aux boss. En rupture, s'éveille plus souvent (25 % au lieu de 15 %).",
	"Lâche": "Stresse deux fois plus face aux boss. En rupture, s'enfuit plus souvent (80 % au lieu de 50 %).",
	"Loyal": "Obéit mieux aux ordres en combat quand sa santé mentale est basse (moitié moins de refus).",
	"Paresseux": "Refuse parfois l'entraînement ou une affectation (1 fois sur 5).",
	"Querelleur": "Se brouille parfois avec un autre héros à la cité : ils deviennent hostiles (à régler par un duel).",
	"Protecteur": "Stresse deux fois plus quand un allié meurt. (Plus tard : couvre ses alliés.)",
	"Ambitieux": "Veut être dans la meilleure équipe : stresse quand un héros plus faible part dans la Tour à sa place.",
	"Mauvais": "Baisse l'efficacité du lobby (-5 % par héros mauvais) et use ceux qui travaillent avec lui.",
}
## Chance d'avoir un deuxième trait (sinon un seul).
const TRAIT_TWO_CHANCE := 0.4
## Traits qui ne vont pas ensemble.
const INCOMPATIBLE_TRAITS := [["Courageux", "Lâche"]]
## Un trait encore caché se révèle tous les TRAIT_REVEAL_FIGHTS combats de la Tour finis.
const TRAIT_REVEAL_FIGHTS := 5
## Effets sur le stress : face aux boss (Courageux, Lâche), à la mort d'un allié (Protecteur),
## et perte d'un Ambitieux quand un héros plus faible (niveau × étoiles) part dans la Tour à sa place,
## jamais en dessous de MENTAL_LEFT_OUT_FLOOR.
const BRAVE_BOSS_FACTOR := 0.5
const COWARD_BOSS_FACTOR := 2.0
const PROTECTOR_DEATH_FACTOR := 2.0
const MENTAL_LOSS_LEFT_OUT := 3.0
const MENTAL_LEFT_OUT_FLOOR := 40.0


## Tire les traits d'un nouveau héros : 1, ou 2 (TRAIT_TWO_CHANCE), compatibles, tous cachés.
func roll_traits() -> Array:
	var names: Array = TRAITS.keys()
	var first: String = names.pick_random()
	var traits := [{"name": first, "known": false}]
	if randf() < TRAIT_TWO_CHANCE:
		var others := names.filter(func(name): return name != first and _traits_compatible(first, name))
		traits.append({"name": others.pick_random(), "known": false})
	return traits


func _traits_compatible(a: String, b: String) -> bool:
	for pair in INCOMPATIBLE_TRAITS:
		if a in pair and b in pair:
			return false
	return true


func has_trait(hero: Dictionary, trait_name: String) -> bool:
	return hero.get("traits", []).any(func(t): return t["name"] == trait_name)


## Révèle un trait (s'il était caché). Renvoie l'annonce « Trait révélé : ... », ou "" s'il était déjà connu.
func reveal_trait(hero: Dictionary, trait_name: String) -> String:
	for t in hero.get("traits", []):
		if t["name"] == trait_name and not t["known"]:
			t["known"] = true
			return "Trait révélé : %s est %s !" % [hero["name"], trait_name]
	return ""


## Les traits tels que le joueur les voit : « Courageux, ? » (« ? » = pas encore révélé).
func traits_text(hero: Dictionary) -> String:
	var parts := []
	for t in hero.get("traits", []):
		parts.append(t["name"] if t["known"] else "?")
	return ", ".join(parts) if not parts.is_empty() else "?"


## Un trait agit : il se révèle s'il était caché (l'annonce va dans « news »).
func _trait_acts(hero: Dictionary, trait_name: String, news: Array) -> void:
	var line := reveal_trait(hero, trait_name)
	if line != "":
		news.append(line)


## La force d'un héros pour Ambitieux : niveau × étoiles.
func hero_power(hero: Dictionary) -> int:
	return hero["level"] * hero["rarity"]


## Ambitieux : un héros ambitieux resté à la cité perd un peu de santé mentale si un héros plus faible
## que lui (hero_power) est parti à sa place dans la Tour (« fighters » : les héros du combat), sans jamais
## descendre sous MENTAL_LEFT_OUT_FLOOR à cause de ça. Son trait se révèle.
func mental_left_out(fighters: Array, news: Array) -> void:
	var fighting_ids := fighters.map(func(hero): return hero["id"])
	var weakest := INF
	for hero in fighters:
		weakest = minf(weakest, hero_power(hero))
	for hero in alive_heroes():
		if hero["id"] in fighting_ids or is_away(hero) or not has_trait(hero, "Ambitieux"):
			continue
		if hero_power(hero) <= weakest or mental(hero) <= MENTAL_LEFT_OUT_FLOOR:
			continue
		mental_loss(hero, minf(MENTAL_LOSS_LEFT_OUT, mental(hero) - MENTAL_LEFT_OUT_FLOOR))
		_trait_acts(hero, "Ambitieux", news)


## La santé mentale d'un héros (100 pour ceux qui n'en ont pas encore).
func mental(hero: Dictionary) -> float:
	return hero.get("mental", MENTAL_MAX)


## Change la santé mentale (entre 0 et MENTAL_MAX). Un héros en rupture remonté à BROKEN_RECOVERY
## (en pratique, par le repos) est remis d'aplomb. Ne sauvegarde pas.
func change_mental(hero: Dictionary, amount: float) -> void:
	hero["mental"] = clampf(mental(hero) + amount, 0.0, MENTAL_MAX)
	if is_broken(hero) and mental(hero) >= BROKEN_RECOVERY:
		hero["broken"] = false


## Fait perdre « amount » de santé mentale, moins ce que Calme protège. Renvoie la perte réelle.
func mental_loss(hero: Dictionary, amount: float) -> float:
	var before := mental(hero)
	change_mental(hero, -amount * (1.0 - mental_guard(hero["skills"])))
	return before - mental(hero)


## Part des pertes de santé mentale que Calme retire (0 sans Calme, 0,5 au niveau 10).
func mental_guard(skills: Array) -> float:
	return minf(1.0, skill_level(skills, "Calme") * CALM_MENTAL_GUARD_PER_LEVEL)


## Efficacité en combat selon la santé mentale : 1.0 (normal) au-dessus de MENTAL_MALUS_START,
## puis de moins en moins, jusqu'à 1 - MENTAL_MALUS_MAX à 0.
func mental_combat_factor(hero: Dictionary) -> float:
	return mental_factor(mental(hero))


## La même chose à partir d'une valeur de santé mentale (battle.gd, qui la suit en direct).
func mental_factor(value: float) -> float:
	if value >= MENTAL_MALUS_START:
		return 1.0
	return 1.0 - MENTAL_MALUS_MAX * (1.0 - value / MENTAL_MALUS_START)


## Désobéissance en combat : sous DISOBEY_START de santé mentale, un héros peut ignorer un ordre du
## Maître (au toucher), jusqu'à DISOBEY_MAX de risque à 0. Loyal : risque multiplié par LOYAL_DISOBEY_FACTOR.
const DISOBEY_START := 60.0
const DISOBEY_MAX := 0.5
const LOYAL_DISOBEY_FACTOR := 0.5
## Après un refus, le héros boude : il ignore tous les ordres pendant ce temps (secondes de combat).
const DISOBEY_SULK := 3.0


## Risque d'ignorer un ordre, selon la santé mentale (sans compter Loyal). Utilisé par battle.gd.
func disobey_chance(mental_value: float) -> float:
	if mental_value >= DISOBEY_START:
		return 0.0
	return DISOBEY_MAX * (1.0 - mental_value / DISOBEY_START)


# ---------------------------------------------------------------------------
# Liens entre héros
# ---------------------------------------------------------------------------
# Cahier, onglet « Personnalité », section 4. Chaque paire de héros a des points de lien (bonds, dans
# game_state.gd), qui donnent un palier : inconnus, connaissance, ami, frère d'armes. Ils montent quand
# les deux finissent un combat de la Tour dans la même équipe, plus vite après une victoire difficile.
# Tous les chiffres sont provisoires.

## Les paliers, du plus bas au plus haut, et les points qu'il faut pour chacun.
const BOND_LEVELS := ["inconnus", "connaissance", "ami", "frère d'armes"]
const BOND_THRESHOLDS := [0.0, 5.0, 25.0, 60.0]
const BOND_ACQUAINTANCE := 1
const BOND_FRIEND := 2
const BOND_BROTHERS := 3
## Hostiles : un palier sous « inconnus » (points de lien négatifs), né d'une querelle à la cité
## (Querelleur, voir update_quarrels). Pas de bonus de lien, de la santé mentale perdue à chaque combat
## dans la même équipe, et plus aucun point gagné ensemble : seul un duel règle le conflit.
const BOND_HOSTILE := -1
const HOSTILE_POINTS := -1.0
## Points gagnés par chaque paire de survivants d'un combat de la Tour : toujours BOND_POINTS_FIGHT,
## plus BOND_POINTS_VICTORY en cas de victoire ; le tout multiplié par HARD_VICTORY_FACTOR si la victoire
## a été difficile (étage de boss, allié tombé, ou survivants à moins de HARD_VICTORY_HP de leur vie).
const BOND_POINTS_FIGHT := 3.0
const BOND_POINTS_VICTORY := 2.0
const HARD_VICTORY_FACTOR := 2.0
const HARD_VICTORY_HP := 0.5
## En combat (battle.gd), par palier (inconnus, connaissance, ami, frère d'armes) :
## - bonus d'attaque et de défense quand un allié lié se bat à moins de BOND_RANGE cases (le meilleur compte) ;
## - perte de santé mentale à sa mort, multipliée (MENTAL_LOSS_ALLY_DEATH × ceci) : de quoi déclencher une rupture.
const BOND_FIGHT_BONUS := [0.0, 0.0, 0.05, 0.10]
const BOND_RANGE := 2.5
const BOND_DEATH_FACTOR := [1.0, 1.0, 2.0, 3.0]


## La clé d'une paire dans bonds : « 3-7 » (le plus petit numéro d'abord).
func _bond_key(a: Dictionary, b: Dictionary) -> String:
	return "%d-%d" % [mini(a["id"], b["id"]), maxi(a["id"], b["id"])]


func bond_points(a: Dictionary, b: Dictionary) -> float:
	return bonds.get(_bond_key(a, b), 0.0)


## Le palier du lien entre deux héros (0 = inconnus ... BOND_BROTHERS = frères d'armes).
func bond_level(a: Dictionary, b: Dictionary) -> int:
	if a["id"] == b["id"]:
		return 0
	var points := bond_points(a, b)
	if points < 0.0:
		return BOND_HOSTILE
	var level := 0
	for i in BOND_THRESHOLDS.size():
		if points >= BOND_THRESHOLDS[i]:
			level = i
	return level


## Ajoute des points de lien (au plus ce qu'il faut pour frères d'armes). Renvoie l'annonce du nouveau
## palier (« X et Y sont devenus amis. »), ou "" s'il n'a pas changé. Ne sauvegarde pas.
func add_bond_points(a: Dictionary, b: Dictionary, points: float) -> String:
	if a["id"] == b["id"] or bond_level(a, b) == BOND_HOSTILE:
		return ""  # des hostiles ne se rapprochent pas : il faut un duel
	var before := bond_level(a, b)
	bonds[_bond_key(a, b)] = minf(bond_points(a, b) + points, BOND_THRESHOLDS[-1])
	var after := bond_level(a, b)
	if after == before:
		return ""
	match after:
		BOND_ACQUAINTANCE:
			return "%s et %s se connaissent maintenant." % [a["name"], b["name"]]
		BOND_FRIEND:
			return "%s et %s sont devenus amis." % [a["name"], b["name"]]
		_:
			return "%s et %s sont devenus frères d'armes." % [a["name"], b["name"]]


## Monte un lien jusqu'au palier « level » (s'il est plus bas). Renvoie l'annonce, ou "".
func set_bond_level(a: Dictionary, b: Dictionary, level: int) -> String:
	if bond_level(a, b) == BOND_HOSTILE:
		bonds[_bond_key(a, b)] = 0.0  # l'hostilité est oubliée
	var missing: float = BOND_THRESHOLDS[level] - bond_points(a, b)
	return add_bond_points(a, b, missing) if missing > 0.0 else ""


## Fin d'un combat de la Tour : chaque paire de survivants (« survivors » : les héros encore en vie)
## se rapproche. « hard » : victoire difficile. Renvoie les annonces des nouveaux paliers.
func bonds_after_battle(survivors: Array, victory: bool, hard: bool) -> Array[String]:
	var points := BOND_POINTS_FIGHT + (BOND_POINTS_VICTORY if victory else 0.0)
	if victory and hard:
		points *= HARD_VICTORY_FACTOR
	var news: Array[String] = []
	for i in survivors.size():
		for j in range(i + 1, survivors.size()):
			var line := add_bond_points(survivors[i], survivors[j], points)
			if line != "":
				news.append(line)
	return news


## Groupes liés (cahier : « les groupes invoqués déjà liés commencent avec un lien élevé ») : quand on
## invoque plusieurs héros d'un coup, il arrive (LINKED_GROUP_CHANCE) que 2 ou 3 d'entre eux se
## connaissent déjà : une petite troupe venue ensemble (hero["group"] = son nom). Ils commencent amis.
## Les noms sont inventés (l'univers du jeu reste original).
const LINKED_GROUP_CHANCE := 0.2
const LINKED_GROUP_NAMES := [
	"la Compagnie de la Lanterne", "les Lames du Gué", "la Bande du Corbeau gris", "les Frères de l'Enclume",
	"l'Escorte des Marais", "les Veilleurs du Col", "la Troupe du Chardon", "les Chiens de la Brume",
]

## Le dernier groupe lié formé par une invocation ({"name", "heroes"}, ou {} : aucun), pour l'annoncer.
var last_linked_group := {}


## Invocation de plusieurs héros : avec un peu de chance, 2 ou 3 d'entre eux forment un groupe lié
## (amis dès le départ). Le groupe va dans last_linked_group. Ne sauvegarde pas.
func roll_linked_group(summoned: Array) -> void:
	last_linked_group = {}
	if summoned.size() < 2 or randf() >= LINKED_GROUP_CHANCE:
		return
	var members := summoned.duplicate()
	members.shuffle()
	members = members.slice(0, randi_range(2, mini(3, members.size())))
	var group_name: String = LINKED_GROUP_NAMES.pick_random()
	for hero in members:
		hero["group"] = group_name
	for i in members.size():
		for j in range(i + 1, members.size()):
			set_bond_level(members[i], members[j], BOND_FRIEND)
	last_linked_group = {"name": group_name, "heroes": members}


## Le nom d'un palier : « hostiles », « inconnus », « connaissance », « ami », « frère d'armes ».
func bond_name(level: int) -> String:
	return "hostiles" if level == BOND_HOSTILE else BOND_LEVELS[level]


# --- Querelleur et hostilités ---
# Cahier (onglet principal, « Relations entre héros, groupes et duels ») : le système signale quand un
# héros devient hostile envers un autre ; les héros n'ont pas le droit de se battre à la cité, le
# conflit se règle par un duel.

## Chaque heure de temps réel passée à la cité, un Querelleur a cette chance de se brouiller avec un
## autre héros présent. Au plus QUARREL_MAX_HOURS heures comptées d'un coup (jeu longtemps fermé).
const QUARREL_CHANCE_PER_HOUR := 0.1
const QUARREL_MAX_HOURS := 24
## Deux hostiles dans la même équipe de combat : chacun perd ceci au début du combat.
const MENTAL_LOSS_HOSTILE := 5.0


## « Han (★) » : le nom suivi des étoiles, comme dans les fenêtres système.
func hero_label(hero: Dictionary) -> String:
	return "%s (%s)" % [hero["name"], "★".repeat(hero["rarity"])]


## Brouille deux héros : leur lien devient « hostiles ». Renvoie l'annonce. Ne sauvegarde pas.
func make_hostile(hero: Dictionary, other: Dictionary) -> String:
	bonds[_bond_key(hero, other)] = HOSTILE_POINTS
	return "%s fait preuve d'hostilité envers %s !" % [hero_label(hero), hero_label(other)]


## Les paires d'hostiles parmi « heroes » : [[a, b], ...].
func hostile_pairs(heroes: Array) -> Array:
	var pairs := []
	for i in heroes.size():
		for j in range(i + 1, heroes.size()):
			if bond_level(heroes[i], heroes[j]) == BOND_HOSTILE:
				pairs.append([heroes[i], heroes[j]])
	return pairs


## Querelles à la cité : pour chaque heure réelle écoulée, chaque Querelleur présent à la cité peut se
## brouiller avec un autre héros présent (QUARREL_CHANCE_PER_HOUR) ; son trait se révèle. Les annonces
## vont dans relation_news, puis le signal relations_changed prévient main.gd. Appelée toutes les 5 s.
func update_quarrels() -> void:
	var now := Time.get_unix_time_from_system()
	if quarrels_checked_at <= 0.0 or quarrels_checked_at > now:
		quarrels_checked_at = now  # première fois, ou l'horloge de l'appareil a reculé
		return
	var hours := int((now - quarrels_checked_at) / 3600.0)
	if hours < 1:
		return
	quarrels_checked_at += hours * 3600.0
	var news := []
	for hour in mini(hours, QUARREL_MAX_HOURS):
		var present := alive_heroes().filter(func(h): return not is_away(h))
		for hero in present:
			if not has_trait(hero, "Querelleur") or randf() >= QUARREL_CHANCE_PER_HOUR:
				continue
			var targets := present.filter(func(h): return h["id"] != hero["id"] and bond_level(hero, h) != BOND_HOSTILE)
			if targets.is_empty():
				continue
			news.append(make_hostile(hero, targets.pick_random()))
			var revealed := reveal_trait(hero, "Querelleur")
			if revealed != "":
				news.append(revealed)
	if not news.is_empty():
		relation_news.append_array(news)
		relations_changed.emit()
	save_game()


# --- Mauvais ---
# Cahier : « certains héros invoqués sont mauvais. Ils perturbent l'ordre de la salle d'attente et
# réduisent son efficacité. » Chaque héros Mauvais présent à la cité retire MAUVAIS_EFFICIENCY_LOSS à
# l'efficacité du lobby (points d'entraînement, chance de la forge, progrès des artisans), sans
# descendre sous MAUVAIS_EFFICIENCY_MIN. Il use aussi ceux qui travaillent au même endroit que lui
# (même poste d'assistant, ou terrain d'entraînement) : MAUVAIS_COWORKER_LOSS_PER_HOUR chacun.
# Son trait se révèle quand l'effet est remarqué (une séance d'entraînement ou un travail de forge).
const MAUVAIS_EFFICIENCY_LOSS := 0.05
const MAUVAIS_EFFICIENCY_MIN := 0.5
const MAUVAIS_COWORKER_LOSS_PER_HOUR := 2.0


## Les héros Mauvais présents à la cité (vivants, pas partis en mission).
func bad_heroes_at_city() -> Array:
	return alive_heroes().filter(func(h): return has_trait(h, "Mauvais") and not is_away(h))


## Efficacité du lobby : 1.0 normalement, moins MAUVAIS_EFFICIENCY_LOSS par héros Mauvais à la cité.
func lobby_efficiency() -> float:
	return maxf(MAUVAIS_EFFICIENCY_MIN, 1.0 - MAUVAIS_EFFICIENCY_LOSS * bad_heroes_at_city().size())


## L'effet des Mauvais vient d'être remarqué (travail fait avec une efficacité réduite) : leurs traits
## cachés se révèlent. Renvoie les annonces (vide si personne n'a été démasqué). Ne sauvegarde pas.
func notice_bad_heroes() -> Array[String]:
	var news: Array[String] = []
	for hero in bad_heroes_at_city():
		var line := reveal_trait(hero, "Mauvais")
		if line != "":
			news.append(line)
	if not news.is_empty():
		news.append("Le travail à la cité est moins efficace (-%d %%) : des héros mauvais y sèment le désordre." \
			% roundi((1.0 - lobby_efficiency()) * 100))
	return news


## Lieu de travail d'un héros à la cité : son poste d'assistant, « training » au terrain, "" s'il ne
## travaille pas.
func _workplace(hero: Dictionary) -> String:
	if hero.get("post", "") != "":
		return hero["post"]
	return "training" if hero.get("training", "") != "" else ""


## Combien de héros Mauvais travaillent au même endroit que ce héros (lui non compris).
func bad_coworkers(hero: Dictionary) -> int:
	var place := _workplace(hero)
	if place == "":
		return 0
	return bad_heroes_at_city().filter(func(h): return h["id"] != hero["id"] and _workplace(h) == place).size()


# --- Duels ---
# Le moyen officiel de régler un conflit (cahier) : depuis la fiche, le Maître organise un duel entre deux
# hostiles. Un contre un avec le moteur de combat (battle.gd, quête « duel ») ; on s'arrête à DUEL_STOP_HP de
# sa vie, sans jamais mourir. Le gagnant reprend confiance, le perdant en perd un peu, et l'hostilité
# retombe à « connaissance ». (Pas encore fait : les paris du cahier.)
const DUEL_STOP_HP := 0.1
const DUEL_SECONDS := 90
const DUEL_WIN_MENTAL := 10.0
const DUEL_LOSE_MENTAL := 5.0


## La « quête » d'un duel, pour battle.gd : pas de remparts, ni de niveau caché, 90 secondes au plus.
func duel_quest() -> Dictionary:
	return {"type": "duel", "name": "Duel", "duel": true, "lasting": false, "seconds": DUEL_SECONDS,
		"hidden_level": false, "walls": 0}


## Pourquoi ce duel est impossible (texte), ou "" s'il peut avoir lieu.
func duel_problem(challenger: Dictionary, rival: Dictionary) -> String:
	if not challenger["alive"] or not rival["alive"]:
		return "Un duel se fait entre deux héros vivants."
	if bond_level(challenger, rival) != BOND_HOSTILE:
		return "%s et %s ne sont pas hostiles : pas de duel." % [challenger["name"], rival["name"]]
	for hero in [challenger, rival]:
		if is_away(hero):
			return "%s n'est pas à la cité : il est parti en mission." % hero["name"]
	return ""


## Fin d'un duel : le gagnant gagne DUEL_WIN_MENTAL, le perdant perd DUEL_LOSE_MENTAL (moins avec Calme),
## et leur hostilité retombe à « connaissance ». Sauvegarde. Renvoie les lignes de la fenêtre de fin.
func finish_duel(challenger: Dictionary, rival: Dictionary, challenger_won: bool) -> Array[String]:
	var winner := challenger if challenger_won else rival
	var loser := rival if challenger_won else challenger
	var winner_before := mental(winner)
	var loser_before := mental(loser)
	change_mental(winner, DUEL_WIN_MENTAL)
	mental_loss(loser, DUEL_LOSE_MENTAL)
	set_bond_level(challenger, rival, BOND_ACQUAINTANCE)
	save_game()
	return [
		"%s remporte le duel contre %s." % [hero_label(winner), hero_label(loser)],
		"%s : santé mentale %d → %d" % [winner["name"], roundi(winner_before), roundi(mental(winner))],
		"%s : santé mentale %d → %d" % [loser["name"], roundi(loser_before), roundi(mental(loser))],
		"Le conflit est réglé : %s et %s ne sont plus hostiles (connaissance)." % [challenger["name"], rival["name"]],
	]


## Les liens d'un héros (hostiles compris, pas les inconnus), du plus fort au plus faible :
## [{"hero": autre héros, "level": palier}]. Les morts y restent.
func hero_bonds(hero: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for other in roster:
		var level := bond_level(hero, other)
		if level != 0:
			result.append({"hero": other, "level": level})
	result.sort_custom(func(x, y): return x["level"] > y["level"])
	return result


## Rupture (cahier, onglet « Personnalité », section 2) : quand la santé mentale d'un héros tombe à 0
## pendant un combat (une fois par combat), son esprit lâche. Le plus souvent, effondrement : il panique
## PANIC_SECONDS secondes (il fuit, ou frappe au hasard, alliés compris) et ébranle ses alliés proches.
## Plus rarement, éveil : l'éveil des compétences, et sa santé mentale remonte à RUPTURE_AWAKEN_MENTAL.
const RUPTURE_AWAKEN_CHANCE := 0.15
const BRAVE_AWAKEN_CHANCE := 0.25      # Courageux
const RUPTURE_AWAKEN_MENTAL := 30.0
const PANIC_SECONDS := 6.0
const PANIC_FLEE_CHANCE := 0.5         # sinon, il frappe au hasard
const COWARD_FLEE_CHANCE := 0.8        # Lâche
const PANIC_RADIUS := 3.0              # en cases : les alliés aussi proches sont ébranlés...
const PANIC_SPREAD_LOSS := 8.0         # ... de tant de santé mentale


## État « En rupture » (hero["broken"]) : un héros qui finit un combat à 0 de santé mentale le reste
## jusqu'à remonter à BROKEN_RECOVERY grâce au repos. Il refuse alors l'entraînement et les affectations
## (et quitte ceux qu'il avait). Envoyé quand même dans la Tour, s'il retombe à 0 pendant le combat, il
## peut mourir de stress (STRESS_DEATH_CHANCE), comme dans l'œuvre : mort définitive, armes perdues.
## Paresseux : refuse parfois un travail même sans rupture (LAZY_REFUSAL_CHANCE).
const BROKEN_RECOVERY := 50.0
const STRESS_DEATH_CHANCE := 0.3
const LAZY_REFUSAL_CHANCE := 0.2

## Pourquoi le dernier travail proposé a été refusé (texte à afficher), voir accepts_work.
var last_refusal := ""


func is_broken(hero: Dictionary) -> bool:
	return hero.get("broken", false)


## Met un héros en rupture : il quitte son poste et le terrain d'entraînement. Renvoie l'annonce.
## Ne sauvegarde pas.
func break_hero(hero: Dictionary) -> String:
	hero["broken"] = true
	hero["post"] = ""
	hero["training"] = ""
	return "%s est en rupture : il refuse de travailler et de s'entraîner jusqu'à retrouver %d de santé mentale (repos)." \
		% [hero["name"], BROKEN_RECOVERY]


## Le héros accepte-t-il un travail (entraînement, poste d'assistant) ? Sinon, la raison est dans
## last_refusal. En rupture : toujours non ; Paresseux : parfois non (et son trait se révèle).
func accepts_work(hero: Dictionary) -> bool:
	last_refusal = ""
	if is_broken(hero):
		last_refusal = "%s est en rupture : il refuse de travailler tant que sa santé mentale n'est pas remontée à %d." \
			% [hero["name"], BROKEN_RECOVERY]
		return false
	if has_trait(hero, "Paresseux") and randf() < LAZY_REFUSAL_CHANCE:
		var revealed := reveal_trait(hero, "Paresseux") != ""
		last_refusal = "%s traîne des pieds et refuse : il est paresseux. Réessaie plus tard." % hero["name"]
		if revealed:
			last_refusal += " (Trait révélé : Paresseux)"
			save_game()
		return false
	return true


## Chance qu'une rupture soit un éveil (sinon un effondrement).
func rupture_awaken_chance(hero: Dictionary) -> float:
	return BRAVE_AWAKEN_CHANCE if has_trait(hero, "Courageux") else RUPTURE_AWAKEN_CHANCE


## Chance qu'un héros qui s'effondre fuie (sinon il frappe au hasard).
func panic_flee_chance(hero: Dictionary) -> float:
	return COWARD_FLEE_CHANCE if has_trait(hero, "Lâche") else PANIC_FLEE_CHANCE


## Texte court de l'état d'esprit (fiche du héros).
func mental_text(hero: Dictionary) -> String:
	if is_broken(hero):
		return "en rupture"
	var value := mental(hero)
	if value >= 80.0:
		return "serein"
	if value >= MENTAL_MALUS_START:
		return "tendu"
	if value >= 30.0:
		return "éprouvé"
	return "au bord de la rupture"


## Fin d'un combat de la Tour, pour un héros qui a survécu. Pendant le combat, battle.gd a suivi sa santé
## mentale en direct (blessures, saignement, boss, avertissements, alliés tombés, Berserk, rupture) et
## noté ce qui s'est passé dans fighter["mind_news"] (traits révélés, ruptures) : on reprend tout ça,
## puis la perte de la défaite et le gain de la victoire. Les annonces vont dans « news ».
## Renvoie le texte « Han : santé mentale 100 → 84 » (ou "" si rien n'a changé).
func mental_after_battle(hero: Dictionary, fighter: Dictionary, victory: bool, news: Array) -> String:
	news.append_array(fighter["mind_news"])
	var before := mental(hero)
	hero["mental"] = clampf(fighter["mental"], 0.0, MENTAL_MAX)
	if not victory:
		mental_loss(hero, MENTAL_LOSS_DEFEAT)
	# Fini à 0 : il reste en rupture (avant le gain de la victoire, qui ne suffit pas à le remettre d'aplomb).
	if mental(hero) <= 0.0 and not is_broken(hero):
		news.append(break_hero(hero))
	if victory:
		change_mental(hero, MENTAL_GAIN_VICTORY)
	# Avec le temps, on apprend à connaître un héros : un trait caché se révèle tous les quelques combats.
	hero["fights"] = hero.get("fights", 0) + 1
	if hero["fights"] % TRAIT_REVEAL_FIGHTS == 0:
		var hidden: Array = hero.get("traits", []).filter(func(t): return not t["known"])
		if not hidden.is_empty():
			_trait_acts(hero, hidden.pick_random()["name"], news)
	if roundi(mental(hero)) == roundi(before):
		return ""
	return "%s : santé mentale %d → %d" % [hero["name"], roundi(before), roundi(mental(hero))]


## Synthèse : chaque héros vivant qui reste (le renforcé compris) est ébranlé. Renvoie l'annonce.
func mental_after_synthesis(sacrifice_count: int) -> String:
	for hero in alive_heroes():
		mental_loss(hero, MENTAL_LOSS_SYNTHESIS * sacrifice_count)
	return "Tes héros ont vu la synthèse : leur santé mentale baisse (-%d, moins avec Calme)." \
		% roundi(MENTAL_LOSS_SYNTHESIS * sacrifice_count)


## Remontée au lobby : depuis la dernière fois, chaque héros à la cité regagne de la santé mentale
## (repos ou travail, voir MENTAL_REST_PER_HOUR). Appelée régulièrement et avant chaque sauvegarde ;
## ne sauvegarde pas elle-même (la valeur est recalculée au lancement depuis mental_updated_at).
func update_mental() -> void:
	var now := Time.get_unix_time_from_system()
	if mental_updated_at <= 0.0 or mental_updated_at > now:
		mental_updated_at = now  # première fois, ou l'horloge de l'appareil a reculé
		return
	var hours := (now - mental_updated_at) / 3600.0
	mental_updated_at = now
	for hero in alive_heroes():
		if is_away(hero):
			continue
		var working: bool = hero.get("post", "") != "" or hero.get("training", "") != ""
		var rate := MENTAL_WORK_PER_HOUR if working else MENTAL_REST_PER_HOUR
		rate -= bad_coworkers(hero) * MAUVAIS_COWORKER_LOSS_PER_HOUR  # un Mauvais au même travail use les autres
		change_mental(hero, hours * rate)
