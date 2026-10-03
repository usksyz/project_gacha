class_name GamePersonality
extends GameHeroes
## La personnalité des héros (cahier, onglet « Personnalité ») : santé mentale et traits de caractère.
## Les héros sont des personnes, pas des stats : les combats durs, les boss, les blessures, la mort
## d'un allié, les synthèses et les défaites les usent ; le repos et le travail au lobby, et la victoire,
## les réparent. Pas encore fait : la rupture à 0, les liens entre héros, la désobéissance.
## Fait partie de la pile de GameData (voir game_data.gd).


# ---------------------------------------------------------------------------
# Santé mentale
# ---------------------------------------------------------------------------
# hero["mental"] : de 0 à MENTAL_MAX (100 à l'invocation). Nombre à virgule (la remontée au lobby est
# continue), affiché arrondi. Calme réduit les pertes ; Berserk en coûte. Tous les chiffres sont provisoires.

const MENTAL_MAX := 100.0

## Pertes à la fin d'un combat de la Tour (pour chaque héros qui y a survécu).
const MENTAL_LOSS_WOUNDS := 12.0       # blessures : jusqu'à ceci, selon la part de vie perdue à la fin
const MENTAL_LOSS_BLEEDING := 4.0      # a saigné pendant le combat
const MENTAL_LOSS_BOSS := 8.0          # étage de boss
const MENTAL_LOSS_WARNINGS := 6.0      # quête à triple avertissement (défense de la cité)
const MENTAL_LOSS_ALLY_DEATH := 10.0   # pour chaque allié tombé dans ce combat
const MENTAL_LOSS_DEFEAT := 10.0       # défaite (ou fuite)
const MENTAL_LOSS_BERSERK := 8.0       # est entré en Berserk : la rage use l'esprit
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


## La santé mentale d'un héros (100 pour ceux qui n'en ont pas encore).
func mental(hero: Dictionary) -> float:
	return hero.get("mental", MENTAL_MAX)


## Change la santé mentale (entre 0 et MENTAL_MAX). Ne sauvegarde pas.
func change_mental(hero: Dictionary, amount: float) -> void:
	hero["mental"] = clampf(mental(hero) + amount, 0.0, MENTAL_MAX)


## Fait perdre « amount » de santé mentale, moins ce que Calme protège. Renvoie la perte réelle.
func mental_loss(hero: Dictionary, amount: float) -> float:
	var guard := minf(1.0, skill_level(hero["skills"], "Calme") * CALM_MENTAL_GUARD_PER_LEVEL)
	var before := mental(hero)
	change_mental(hero, -amount * (1.0 - guard))
	return before - mental(hero)


## Efficacité en combat selon la santé mentale : 1.0 (normal) au-dessus de MENTAL_MALUS_START,
## puis de moins en moins, jusqu'à 1 - MENTAL_MALUS_MAX à 0. Utilisée par battle.gd.
func mental_combat_factor(hero: Dictionary) -> float:
	var value := mental(hero)
	if value >= MENTAL_MALUS_START:
		return 1.0
	return 1.0 - MENTAL_MALUS_MAX * (1.0 - value / MENTAL_MALUS_START)


## Texte court de l'état d'esprit (fiche du héros).
func mental_text(hero: Dictionary) -> String:
	var value := mental(hero)
	if value >= 80.0:
		return "serein"
	if value >= MENTAL_MALUS_START:
		return "tendu"
	if value >= 30.0:
		return "éprouvé"
	return "au bord de la rupture"


## Fin d'un combat de la Tour, pour un héros qui a survécu : ses pertes (blessures, saignement, boss,
## avertissements, alliés tombés, défaite, Berserk), puis le gain de la victoire.
## « fighter » : ce qu'il était dans le combat (battle.gd) ; « dead_allies » : héros tombés.
## Renvoie le texte « Han : santé mentale 100 → 84 » (ou "" si rien n'a changé).
func mental_after_battle(hero: Dictionary, fighter: Dictionary, quest: Dictionary, boss: bool,
		dead_allies: int, victory: bool) -> String:
	var before := mental(hero)
	var loss := MENTAL_LOSS_WOUNDS * (1.0 - clampf(float(fighter["hp"]) / fighter["max_hp"], 0.0, 1.0))
	if fighter["has_bled"]:
		loss += MENTAL_LOSS_BLEEDING
	if boss:
		loss += MENTAL_LOSS_BOSS
	if quest.get("warnings", 0) > 0:
		loss += MENTAL_LOSS_WARNINGS
	loss += MENTAL_LOSS_ALLY_DEATH * dead_allies
	if not victory:
		loss += MENTAL_LOSS_DEFEAT
	if fighter["berserk"]:
		loss += MENTAL_LOSS_BERSERK
	mental_loss(hero, loss)
	if victory:
		change_mental(hero, MENTAL_GAIN_VICTORY)
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
		change_mental(hero, hours * (MENTAL_WORK_PER_HOUR if working else MENTAL_REST_PER_HOUR))
