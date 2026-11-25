extends Node2D
class_name BuildingDoor
## Dvere budovy – vstup do interiéru, alebo správa „zatvorené“.

var building: Building
var walk_in := false


func _ready() -> void:
	add_to_group("interactable")
	walk_in = building.info.vstup


func interact(_player) -> void:
	if building.info.vstup:
		Game.enter_building(building.info.id)
	else:
		Game.closed_building(building.info)


func prompt_text() -> String:
	var b := building.info
	if b.vstup:
		return "Vstúpiť: " + str(b.nazov)
	if b.id == "clnaren" and Game.MAIN_COUNT in Game.solved_main:
		return "Prezrieť člnáreň"
	return str(b.nazov) + " (zatvorené)"
