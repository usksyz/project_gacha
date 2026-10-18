#!/bin/bash
# Lance les bancs de test sans écran, l'un après l'autre (ajout d'octobre 2026, analyse du projet : « lancer les bancs à
# chaque push »). Utilisé par GitHub (.github/workflows/tests.yml et deploy-web.yml) ; marche aussi sur un PC Linux.
# Les bancs RECOMMENCENT la partie : ne le lancer que dans une copie du projet (avec override.cfg, voir CLAUDE.md) ou
# sur GitHub (machine neuve, sans sauvegarde).
#   tools/lancer_tests.sh <chemin de Godot>
# Le code de sortie vaut 1 si un banc échoue ; le bilan liste les bancs en échec.
GODOT="${1:-godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --import > /dev/null 2>&1 || true
echoues=()
lancer() {
	local nom="$1"; shift
	echo "=== $nom"
	if timeout 900 "$GODOT" --headless "$@" > "/tmp/test_$nom.txt" 2>&1; then
		grep -E "ÉCHEC|RÉSULTAT|BILAN|scripts," "/tmp/test_$nom.txt" | head -20
	else
		echoues+=("$nom")
		grep -E "ÉCHEC|RÉSULTAT|BILAN|SCRIPT ERROR|scripts," "/tmp/test_$nom.txt" | head -40
	fi
}
lancer check_scripts -s res://tools/check_scripts.gd
lancer test_combat_v2 res://tools/test_combat_v2.tscn
lancer test_personality -s res://tools/test_personality.gd
lancer test_summon -s res://tools/test_summon.gd -- tirages=200000
for banc in test_economie test_etapeA test_etapeC test_etapeD test_etapeE test_prompt3 test_prompt4 test_prompt5 test_ameliorations; do
	lancer "$banc" -s "res://tools/$banc.gd"
done
echo
if [ ${#echoues[@]} -eq 0 ]; then
	echo "Tous les bancs sont bons."
else
	echo "Bancs en échec : ${echoues[*]}"
	exit 1
fi
