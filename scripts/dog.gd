extends StaticBody2D
## Gabriel – objaví sa za záhradnou chatkou, keď Marek nájde stopy pri člnárni.

@export var meno := "Gabriel"
var at_home := false   # po finále stojí pri Marekovom dome


func _ready() -> void:
	add_to_group("interactable")
	$AnimatedSprite2D.play("idle")
	Game.state_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var on := at_home or (Game.has_flag("clnaren") and not Game.finale_done)
	visible = on
	$CollisionShape2D.set_deferred("disabled", not on)


func interact(_player) -> void:
	if at_home:
		Game.dialog.show_message("Gabriel šťastne vrtí chvostom. Už nikam neutečie.")
	else:
		Game.found_gabriel()


func prompt_text() -> String:
	return meno
