class_name BattleDirector
extends RefCounted
## Le directeur d'IA, première brique (recensement « Techniques de programmation pour le combat », point 10 « plus tard » :
## « un directeur d'IA pour le rythme », comme celui de Left 4 Dead ; ajout du projet). Il ne change RIEN au combat : il
## mesure la tension, seconde par seconde, pour qu'on puisse régler plus tard un vrai directeur (qui ferait souffler
## l'équipe après un pic, ou relancer un combat qui traîne) sur des chiffres. Ce qu'il lit : la vie perdue par les héros
## (la seconde écoulée), les monstres qui chassent, les héros à terre. Tension entre 0 et 1, lissée.
## Phases : « calme » (sous DIRECTOR_TENSE), « tension », « pic » (au-dessus de DIRECTOR_PEAK).

var battle  # Battle (pas de type : les deux classes se connaissent)
## La tension (lissée) et son histoire (une valeur par seconde).
var tension := 0.0
var history := PackedFloat32Array()
## Compteurs pour les mesures : pics (entrées en phase « pic »), secondes passées dans chaque phase.
var peaks := 0
var seconds := {"calme": 0, "tension": 0, "pic": 0}
var _due := 1.0
var _last_hp := -1.0
var _phase := "calme"


func _init(owner) -> void:
	battle = owner


## Chaque seconde de combat : la tension du moment, lissée, et la phase.
func tick() -> void:
	if battle.time < _due:
		return
	_due += 1.0
	var hp := 0.0
	var max_hp := 0.0
	var down := 0
	for hero in battle.heroes:
		hp += maxf(0.0, hero["hp"])
		max_hp += hero["max_hp"]
		if hero["hp"] <= 0:
			down += 1
	var lost := 0.0 if _last_hp < 0.0 else maxf(0.0, _last_hp - hp)
	_last_hp = hp
	var hunting := 0
	var present := 0
	for enemy in battle._alive(battle.enemies):
		present += 1
		if enemy["state"] == "alerte":
			hunting += 1
	var now: float = clampf(lost / maxf(1.0, max_hp) * GameData.DIRECTOR_DAMAGE_WEIGHT \
		+ (float(hunting) / maxf(1.0, present)) * GameData.DIRECTOR_HUNT_WEIGHT \
		+ down * GameData.DIRECTOR_DOWN_WEIGHT, 0.0, 1.0)
	tension = lerpf(tension, now, GameData.DIRECTOR_SMOOTHING)
	history.append(tension)
	var phase := "pic" if tension >= GameData.DIRECTOR_PEAK else ("tension" if tension >= GameData.DIRECTOR_TENSE else "calme")
	if phase == "pic" and _phase != "pic":
		peaks += 1
	_phase = phase
	seconds[phase] += 1


func phase() -> String:
	return _phase
