extends StaticBody2D
## Obyvateľ mesta. Čo povie a akú úlohu zadá, rozhoduje Game.talk() podľa data/ulohy.json.

const DIR_NAMES := {Vector2i.DOWN: "down", Vector2i.UP: "up", Vector2i.LEFT: "left", Vector2i.RIGHT: "right"}

@export var postava_id := ""
@export_enum("down", "up", "left", "right") var smer := "down"
var ambient_text := ""     # ak je nastavené, postava len povie túto vetu (záverečná scéna)

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
var marker: Label


func setup(pid: String, tile: Vector2i, dir := "down") -> void:
	postava_id = pid
	smer = dir
	position = Vector2(tile * 16) + Vector2(8, 8)


func _ready() -> void:
	add_to_group("interactable")
	var p := Game.person(postava_id)
	if p.has("sprite"):
		anim.sprite_frames = load("res://resources/%s_frames.tres" % p.sprite)
	anim.play("idle_" + smer)
	marker = Label.new()
	marker.text = "!"
	marker.position = Vector2(-2, -34)
	marker.add_theme_font_size_override("font_size", 9)
	marker.add_theme_color_override("font_color", Color("ffd84a"))
	marker.add_theme_color_override("font_outline_color", Color("2b1d2e"))
	marker.add_theme_constant_override("outline_size", 3)
	add_child(marker)
	var tw := create_tween().set_loops()
	tw.tween_property(marker, "position:y", -36.0, 0.4)
	tw.tween_property(marker, "position:y", -34.0, 0.4)
	Game.state_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	marker.visible = ambient_text == "" and Game.has_news(postava_id)


func interact(player) -> void:
	anim.play("idle_" + DIR_NAMES[-player.facing])
	if ambient_text != "":
		Game.dialog.show_message("%s: %s" % [Game.person(postava_id).meno, ambient_text])
	else:
		Game.talk(postava_id)


func prompt_text() -> String:
	return str(Game.person(postava_id).get("meno", "?"))
