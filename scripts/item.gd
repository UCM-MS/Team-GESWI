extends StaticBody2D
class_name Item
## Predmet na zemi: kosť, Gabrielova loptička alebo mačka Micka.

const FRAMES := {"kost": 0, "lopticka": 1, "macka": 2}

var kind := "kost"
var building_id := ""
var spr: Sprite2D


func setup(k: String, tile: Vector2i, bid := "") -> void:
	kind = k
	building_id = bid
	position = Vector2(tile * 16) + Vector2(8, 8)
	spr = Sprite2D.new()
	spr.texture = load("res://assets/sprites/predmety.png")
	spr.hframes = 5
	spr.frame = FRAMES[k]
	add_child(spr)
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(14, 14)
	cs.shape = sh
	add_child(cs)
	add_to_group("interactable")
	if k == "macka":
		var t := Timer.new()
		t.wait_time = 0.7
		t.autostart = true
		t.timeout.connect(func(): spr.frame = 5 - spr.frame)   # 2 <-> 3
		add_child(t)
	else:
		var tw := create_tween().set_loops()
		tw.tween_property(spr, "position:y", -1.0, 0.5)
		tw.tween_property(spr, "position:y", 0.0, 0.5)


func interact(_player) -> void:
	match kind:
		"kost":
			Game.find_bone(building_id)
			queue_free()
		"macka":
			Game.find_cat()
			queue_free()
		"lopticka":
			Game.closed_building(Game.building("clnaren"))
			queue_free()


func prompt_text() -> String:
	return {"kost": "Kosť!", "macka": "Mačka Micka", "lopticka": "Loptička"}[kind]
