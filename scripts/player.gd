extends CharacterBody2D
## Marek – pohyb po políčkach 16×16 (ako v starých Pokémonoch)

signal stepped(tile: Vector2i)

const TILE := 16
const DIR_NAMES := {Vector2i.DOWN: "down", Vector2i.UP: "up", Vector2i.LEFT: "left", Vector2i.RIGHT: "right"}

@export var step_time := 0.2      # sekundy na jedno políčko
@export var bike_step_time := 0.12

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

var facing := Vector2i.DOWN
var moving := false


func _ready() -> void:
	Game.player = self
	position = (position / TILE).floor() * TILE + Vector2(TILE / 2, TILE / 2)
	_play_idle()


func place(tile_pos: Vector2i, face := Vector2i.DOWN) -> void:
	position = Vector2(tile_pos * TILE) + Vector2(TILE / 2, TILE / 2)
	facing = face
	_play_idle()
	_update_prompt.call_deferred()


func tile() -> Vector2i:
	return Vector2i((position / TILE).floor())


func set_camera_limits(r: Rect2i) -> void:
	camera.limit_left = r.position.x
	camera.limit_top = r.position.y
	camera.limit_right = r.end.x
	camera.limit_bottom = r.end.y
	camera.reset_smoothing()


func _physics_process(_delta: float) -> void:
	if moving:
		return
	if Game.ui_busy:
		_play_idle()
		return
	var dir := _input_dir()
	if dir == Vector2i.ZERO:
		_play_idle()
		return
	if dir != facing:
		facing = dir
		_update_prompt()
	var motion := Vector2(dir * TILE)
	if test_move(global_transform, motion):
		_play_idle()   # narazil – len sa otočí
		# do dverí sa dá vojsť aj chôdzou
		var n = _interactable_ahead()
		if n and n.get("walk_in") and dir == Vector2i.UP:
			n.interact(self)
		return
	_step(motion)


func _step(motion: Vector2) -> void:
	moving = true
	anim.play("walk_" + DIR_NAMES[facing])
	var tw := create_tween()
	var t := bike_step_time if Game.has_flag("bicykel") else step_time
	tw.tween_property(self, "position", position + motion, t)
	await tw.finished
	moving = false
	_update_prompt()
	stepped.emit(tile())


func _input_dir() -> Vector2i:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if v == Vector2.ZERO:
		return Vector2i.ZERO
	if absf(v.x) > absf(v.y):
		return Vector2i(int(signf(v.x)), 0)
	return Vector2i(0, int(signf(v.y)))


func _play_idle() -> void:
	anim.play("idle_" + DIR_NAMES[facing])


func _interactable_ahead():
	var target := global_position + Vector2(facing * TILE)
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.is_visible_in_tree() and n.global_position.distance_to(target) < 4.0:
			return n
	return null


func _update_prompt() -> void:
	if Game.dialog == null or not is_instance_valid(Game.dialog):
		return
	var n = _interactable_ahead()
	Game.dialog.set_prompt(n.prompt_text() if n and n.has_method("prompt_text") else "")


func _unhandled_input(event: InputEvent) -> void:
	if moving or Game.ui_busy or not event.is_action_pressed("interact"):
		return
	var n = _interactable_ahead()
	if n:
		get_viewport().set_input_as_handled()
		n.interact(self)
