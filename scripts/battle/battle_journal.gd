class_name BattleJournal
extends BattleBase
## Combat (voir battle.gd) : le journal de combat de chaque héros (personnalité P1b).


func _journal(unit: Dictionary, kind: String, data := {}) -> void:
	if not unit["is_hero"] or unit["journal"].size() >= JOURNAL_MAX:
		return
	var event := {"t": snappedf(time, 0.1), "kind": kind}
	event.merge(data)
	unit["journal"].append(event)


## Un coup (ou une esquive) : compteurs, premier contact avec cet ennemi, blessure grave.
func _journal_hit(attacker: Dictionary, target: Dictionary, amount: int, critical: bool) -> void:
	for pair in [[attacker, target], [target, attacker]]:
		var hero: Dictionary = pair[0]
		var foe: Dictionary = pair[1]
		if hero["is_hero"] and not foe["is_hero"] and not hero["met"].has(foe["id"]):
			hero["met"][foe["id"]] = true
			_journal(hero, "contact", {"with": foe["base_name"]})
			_foe_count(hero, foe["base_name"], "")
	# Par sorte d'ennemi : coups portés et esquives (ce que le héros en apprend, voir GameData.learn_from_battle).
	if attacker["is_hero"] and not target["is_hero"] and amount >= 0:
		_foe_count(attacker, target["base_name"], "hits")
	if target["is_hero"] and not attacker["is_hero"] and amount < 0:
		_foe_count(target, attacker["base_name"], "dodges")
	if attacker["is_hero"] and amount >= 0:
		attacker["journal_counts"]["hits_given"] += 1
	if target["is_hero"]:
		if amount < 0:
			target["journal_counts"]["dodges"] += 1
		else:
			target["journal_counts"]["hits_taken"] += 1
			if critical or amount >= target["max_hp"] * BLEED_HIT:
				_journal(target, "wound", {"by": attacker["base_name"], "amount": amount})


## Compte un coup porté (« hits ») ou une esquive (« dodges ») d'un héros contre une sorte d'ennemi ; « » : la
## rencontre seulement. fighter["foes"] = {nom de base: {"hits", "dodges"}}.
func _foe_count(hero: Dictionary, base_name: String, what: String) -> void:
	if not hero["foes"].has(base_name):
		hero["foes"][base_name] = {"hits": 0, "dodges": 0}
	if what != "":
		hero["foes"][base_name][what] += 1


## Une formation entre en jeu : notée pour le combat et dans le journal des héros debout.
func _journal_formation(formation: String) -> void:
	if formation in formations_used:
		return
	formations_used.append(formation)
	for hero in _alive(heroes):
		_journal(hero, "formation", {"name": formation})
