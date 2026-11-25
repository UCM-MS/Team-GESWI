extends Control
## Titulka + úvodný komiks.
## Ak existuje uložená hra: Enter = pokračovať, N = nová hra.
## Komiks: E / medzerník / klik = ďalšie políčko, Esc = preskočiť.

const PANEL_COUNT := 8

var idx := 0
var tex: TextureRect
var hint: Label
var title: Label
var in_menu := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("1b1420")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	tex = TextureRect.new()
	tex.position = Vector2(8, 2)
	tex.size = Vector2(304, 168)   # políčko 152x84 zväčšené 2x
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(tex)

	hint = Label.new()
	hint.position = Vector2(8, 170)
	hint.size = Vector2(304, 10)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 6)
	hint.add_theme_color_override("font_color", Color("c8bcd0"))
	add_child(hint)

	title = Label.new()
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 8)
	title.add_theme_color_override("font_color", Color("f8f0e0"))
	title.text = "HĽADÁ SA GABRIEL\n\n[Enter] Pokračovať v uloženej hre\n[N] Nová hra"
	add_child(title)

	if Game.has_save():
		in_menu = true
		tex.hide()
		hint.text = ""
	else:
		title.hide()
		_show()


func _show() -> void:
	tex.texture = load("res://assets/comic/panel_%d.png" % (idx + 1))
	tex.modulate.a = 0.0
	create_tween().tween_property(tex, "modulate:a", 1.0, 0.3)
	hint.text = "%d / %d    [E] ďalej · [Esc] preskočiť" % [idx + 1, PANEL_COUNT]


func _unhandled_input(event: InputEvent) -> void:
	if in_menu:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			get_viewport().set_input_as_handled()
			in_menu = false
			Game.continue_game()
		elif event is InputEventKey and event.pressed and event.keycode == KEY_N:
			get_viewport().set_input_as_handled()
			in_menu = false
			title.hide()
			tex.show()
			_show()
		return
	var next: bool = event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if event.is_action_pressed("cancel"):
		_finish()
	elif next:
		get_viewport().set_input_as_handled()
		idx += 1
		if idx >= PANEL_COUNT:
			_finish()
		else:
			_show()


func _finish() -> void:
	set_process_unhandled_input(false)
	Game.new_game()
