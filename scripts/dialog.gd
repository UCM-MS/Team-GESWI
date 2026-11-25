extends CanvasLayer
## Dialógové okno, otázky (text / výber / číselná os), HUD, zápisník a záverečná obrazovka.
## Celé UI sa skladá v kóde.

const INK := Color("2b1d2e")
const PAPER := Color("f8f8f0")
const ACCENT := Color("3d6fc4")
const GREY := Color("7a6a7e")
const FLAG_NAMES := {
	"pistalka": "Dedkova píšťalka", "kolac": "koláč pre Gabriela", "bicykel": "bicykel",
	"napoveda": "nápoveda navyše", "kniha_stop": "Kniha stôp", "ciapka": "čiapka so psíkom", "rybar": "rybárske tipy",
}

var root: Control
var panel: PanelContainer
var label: Label
var choices: VBoxContainer
var axis: NumberLine
var input: LineEdit
var hint: Label
var hud: Label
var goal: Label
var prompt: Label
var toast: Label
var fade: ColorRect
var notebook: PanelContainer
var nb_grid: GridContainer
var nb_footer: Label
var nb_title: Label
var nb_page := 0
var end_panel: PanelContainer
var end_label: Label

var mode := ""            # "", "msg", "question", "notebook", "end"
var queue: Array = []
var on_done: Callable

var quest: Dictionary = {}
var quest_key := ""
var speaker := ""
var step := 0
var on_success: Callable
var choice_sel := 0


func _ready() -> void:
	Game.dialog = self
	layer = 10
	var theme := Theme.new()
	theme.default_font_size = 7
	theme.set_color("font_color", "Label", INK)

	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	add_child(root)

	hud = _outlined_label(Vector2(4, 2))
	goal = _outlined_label(Vector2(4, 11))
	goal.add_theme_font_size_override("font_size", 6)
	prompt = _outlined_label(Vector2(0, 0))
	prompt.add_theme_font_size_override("font_size", 6)
	prompt.anchor_left = 1.0
	prompt.anchor_right = 1.0
	prompt.offset_left = -150
	prompt.offset_right = -4
	prompt.offset_top = 2
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	toast = _outlined_label(Vector2(0, 26))
	toast.anchor_right = 1.0
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_size_override("font_size", 8)
	toast.modulate.a = 0.0

	# --- dialógový panel ---
	panel = PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 4
	panel.offset_right = -4
	panel.offset_top = -40
	panel.offset_bottom = -4
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.add_theme_stylebox_override("panel", _box(PAPER, INK, 2))
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)

	choices = VBoxContainer.new()
	choices.add_theme_constant_override("separation", 0)
	box.add_child(choices)

	axis = NumberLine.new()
	box.add_child(axis)

	var row := HBoxContainer.new()
	box.add_child(row)
	input = LineEdit.new()
	input.placeholder_text = "výsledok"
	input.custom_minimum_size = Vector2(110, 14)
	input.add_theme_color_override("font_color", INK)
	input.add_theme_color_override("caret_color", INK)
	input.add_theme_color_override("font_placeholder_color", GREY)
	var ib := _box(Color.WHITE, ACCENT, 1)
	ib.content_margin_top = 1
	ib.content_margin_bottom = 1
	input.add_theme_stylebox_override("normal", ib)
	input.add_theme_stylebox_override("focus", ib)
	input.text_submitted.connect(_on_submit)
	row.add_child(input)
	hint = Label.new()
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", GREY)
	hint.add_theme_font_size_override("font_size", 6)
	row.add_child(hint)
	panel.hide()

	_build_notebook()
	_build_end()

	fade = ColorRect.new()
	fade.color = Color(0.06, 0.04, 0.08, 1.0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	create_tween().tween_property(fade, "color:a", 0.0, 0.25)

	Game.clues_changed.connect(func(_c): _update_hud())
	Game.state_changed.connect(_update_hud)
	_update_hud()


func _outlined_label(pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 3)
	root.add_child(l)
	return l


func _box(bg: Color, border: Color, w: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(w)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(5)
	return sb


func _update_hud() -> void:
	hud.text = "Indície: %d / %d" % [Game.solved_main.size(), Game.MAIN_COUNT]
	goal.text = "Cieľ: " + Game.goal_text()


func fade_out() -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.2)
	await tw.finished


func set_prompt(text: String) -> void:
	prompt.text = ("[E] " + text) if text != "" else ""


func show_toast(text: String) -> void:
	toast.text = text
	var tw := create_tween()
	tw.tween_property(toast, "modulate:a", 1.0, 0.25)
	tw.tween_interval(1.6)
	tw.tween_property(toast, "modulate:a", 0.0, 0.5)


# ------------------------------------------------------------------ správy

func show_message(text: String) -> void:
	show_messages([text])


func show_messages(lines: Array, done: Callable = Callable()) -> void:
	queue = lines.duplicate()
	on_done = done
	_next_message()


func _next_message() -> void:
	if queue.is_empty():
		var cb := on_done
		on_done = Callable()
		close()
		if cb.is_valid():
			cb.call()
		return
	mode = "msg"
	Game.ui_busy = true
	label.text = str(queue.pop_front())
	_show_widgets("")
	hint.text = "[E] ďalej"
	panel.show()


func _show_widgets(kind: String) -> void:
	input.visible = kind == "text"
	choices.visible = kind == "volba"
	axis.visible = kind == "os"
	input.get_parent().visible = true


func close() -> void:
	mode = ""
	input.release_focus()
	panel.hide()
	notebook.hide()
	end_panel.hide()
	Game.ui_busy = false


# ------------------------------------------------------------------ úlohy

## Spustí (alebo obnoví) viackrokovú úlohu. Pri chybe hráč dostane nápovedu a skúša znova.
func ask_quest(who: String, q: Dictionary, key: String, _intro: String, success: Callable) -> void:
	quest = q
	quest_key = key
	speaker = who
	on_success = success
	step = int(Game.step_progress.get(key, 0))
	axis.placed = []
	for i in step:
		var st: Dictionary = q.kroky[i]
		if st.typ == "os":
			axis.placed.append([_point_name(st), float(st.odpoved)])
	_show_step("" if step == 0 else "(Pokračujeme tam, kde sme skončili.)")


func _point_name(st: Dictionary) -> String:
	var r := RegEx.new()
	r.compile("bod ([A-Z])")
	var m := r.search(st.otazka)
	return m.get_string(1) if m else "•"


func _show_step(extra: String) -> void:
	var steps: Array = quest.kroky
	var st: Dictionary = steps[step]
	mode = "question"
	Game.ui_busy = true
	var txt := "%s: %s\n" % [speaker, quest.uvod]
	if extra != "":
		txt += extra + "\n"
	txt += ("(%d/%d) " % [step + 1, steps.size()] if steps.size() > 1 else "") + str(st.otazka)
	if Game.has_flag("napoveda") and str(st.get("napoveda", "")) != "":
		txt += "\nTip: " + str(st.napoveda)
	label.text = txt
	match str(st.typ):
		"volba":
			_show_widgets("volba")
			input.hide()
			choice_sel = 0
			_render_choices()
			hint.text = "↑↓ alebo 1–%d · E/Enter = vybrať · Esc = zavrieť" % (st.moznosti as Array).size()
		"os":
			_show_widgets("os")
			input.hide()
			axis.setup(float(st.get("min", -5)), float(st.get("max", 5)), float(st.get("krok", 0.5)), _point_name(st))
			hint.text = "←→ posúvaj bod · E/Enter = potvrdiť · Esc = zavrieť"
		_:
			_show_widgets("text")
			input.text = ""
			input.placeholder_text = "výsledok (viac čísel oddeľ ;)" if ";" in str(st.odpoved) else "výsledok"
			hint.text = "Enter = odpovedať · Esc = zavrieť"
			input.grab_focus.call_deferred()
	panel.show()


func _render_choices() -> void:
	for c in choices.get_children():
		c.queue_free()
	var st: Dictionary = quest.kroky[step]
	var opts: Array = st.moznosti
	for i in opts.size():
		var l := Label.new()
		var sel := i == choice_sel
		l.text = ("> " if sel else "   ") + "%d) %s" % [i + 1, opts[i]]
		l.add_theme_color_override("font_color", ACCENT if sel else INK)
		choices.add_child(l)


func _on_submit(text: String) -> void:
	if mode != "question" or str(quest.kroky[step].typ) != "text":
		return
	_answer(text)


func _answer(ans) -> void:
	var st: Dictionary = quest.kroky[step]
	if _check(st, ans):
		if str(st.typ) == "os":
			axis.placed.append([_point_name(st), float(st.odpoved)])
		step += 1
		if step >= (quest.kroky as Array).size():
			Game.step_progress.erase(quest_key)
			input.release_focus()
			var cb := on_success
			close()
			cb.call()
		else:
			Game.step_progress[quest_key] = step
			_show_step(Game.data.texty.spravne)
	else:
		var tip := str(st.get("napoveda", ""))
		_show_step(Game.data.texty.nespravne + ((" " + tip) if tip != "" else ""))


func _check(st: Dictionary, ans) -> bool:
	match str(st.typ):
		"volba":
			return int(ans) == int(st.odpoved)
		"os":
			return absf(float(ans) - float(st.odpoved)) < 0.001
	var got := parse_numbers(str(ans))
	var want := parse_numbers(str(st.odpoved))
	if want.is_empty():
		return str(ans).strip_edges().to_lower() == str(st.odpoved).strip_edges().to_lower()
	if got.size() != want.size():
		return false
	if not st.get("poradie", true):
		got.sort()
		want.sort()
	for i in got.size():
		if absf(got[i] - want[i]) > float(st.get("tolerancia", 0.001)):
			return false
	return true


## Vytiahne z textu všetky čísla. Rozumie desatinnej čiarke, znaku − aj medzerám (napr. "- 5").
static func parse_numbers(text: String) -> Array:
	var t := text.replace("−", "-").replace("–", "-")
	var r := RegEx.new()
	r.compile("[-+]?\\s*\\d+(?:[.,]\\d+)?")
	var out: Array = []
	for m in r.search_all(t):
		out.append(m.get_string().replace(" ", "").replace(",", ".").to_float())
	return out


# ------------------------------------------------------------------ zápisník

func _build_notebook() -> void:
	notebook = PanelContainer.new()
	notebook.set_anchors_preset(Control.PRESET_FULL_RECT)
	notebook.offset_left = 6
	notebook.offset_right = -6
	notebook.offset_top = 6
	notebook.offset_bottom = -6
	notebook.add_theme_stylebox_override("panel", _box(Color("fbf3dc"), INK, 2))
	root.add_child(notebook)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	notebook.add_child(v)
	nb_title = Label.new()
	nb_title.add_theme_font_size_override("font_size", 8)
	v.add_child(nb_title)
	nb_grid = GridContainer.new()
	nb_grid.columns = 3
	nb_grid.add_theme_constant_override("h_separation", 6)
	nb_grid.add_theme_constant_override("v_separation", 0)
	v.add_child(nb_grid)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	nb_footer = Label.new()
	nb_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nb_footer.add_theme_font_size_override("font_size", 6)
	nb_footer.add_theme_color_override("font_color", GREY)
	v.add_child(nb_footer)
	notebook.hide()


func _nb_cell(text: String, w: int, color := INK) -> void:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = w
	l.add_theme_font_size_override("font_size", 6)
	l.add_theme_color_override("font_color", color)
	l.clip_text = true
	l.custom_minimum_size.y = 8
	nb_grid.add_child(l)


func open_notebook(page := 0) -> void:
	nb_page = page if Game.has_flag("kniha_stop") else 0
	# mriežku zakaždým postavíme nanovo, aby sa prepočítali šírky stĺpcov
	var parent := nb_grid.get_parent()
	var idx := nb_grid.get_index()
	nb_grid.queue_free()
	nb_grid = GridContainer.new()
	nb_grid.columns = 3
	nb_grid.add_theme_constant_override("h_separation", 6)
	nb_grid.add_theme_constant_override("v_separation", 0)
	parent.add_child(nb_grid)
	parent.move_child(nb_grid, idx)
	var learned := nb_page == 1
	nb_title.text = "Kniha stôp – čo som sa naučil" if learned else "Zápisník – kde · kto · čo videl"
	for q in Game.data.hlavne:
		var qid := int(q.id)
		var solved := qid in Game.solved_main
		var nxt := qid == Game.next_main_id()
		var col := INK if solved else (ACCENT if nxt else GREY)
		if learned:
			_nb_cell("%d. %s" % [qid, q.zapisnik.kde if solved else "?"], 58, col)
			_nb_cell("", 40, col)
			_nb_cell(str(q.ciastkovy_ciel) if solved else "–", 180, col)
		elif solved:
			var z: Dictionary = q.zapisnik
			_nb_cell("%d. %s" % [qid, z.kde], 58)
			_nb_cell(str(z.kto), 40)
			_nb_cell(str(z.co), 180)
		else:
			_nb_cell("%d. ?" % qid, 58, col)
			_nb_cell("–", 40, col)
			_nb_cell(("(ďalej: %s)" % q.ciel) if nxt else "–", 180, col)
	var items: Array = []
	for f in FLAG_NAMES:
		if Game.has_flag(f):
			items.append(FLAG_NAMES[f])
	var keys := "[N] alebo [Esc] zavrieť"
	if Game.has_flag("kniha_stop"):
		keys = "[←→] Zápisník / Kniha stôp · " + keys
	nb_footer.text = "Vedľajšie úlohy: %d / %d · Kosti: %d / %d · Výbava: %s\n%s" % [
		Game.solved_side.size(), Game.SIDE_COUNT, Game.bones.size(), Game.BONES_COUNT,
		", ".join(items) if not items.is_empty() else "nič", keys]
	mode = "notebook"
	Game.ui_busy = true
	notebook.show()


# ------------------------------------------------------------------ koniec

func _build_end() -> void:
	end_panel = PanelContainer.new()
	end_panel.set_anchors_preset(Control.PRESET_CENTER)
	end_panel.custom_minimum_size = Vector2(220, 0)
	end_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	end_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	end_panel.add_theme_stylebox_override("panel", _box(Color("fbf3dc"), INK, 2))
	root.add_child(end_panel)
	end_label = Label.new()
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_panel.add_child(end_label)
	end_panel.hide()


func show_end(text: String) -> void:
	mode = "end"
	Game.ui_busy = true
	end_label.text = text
	end_panel.show()


# ------------------------------------------------------------------ vstup

func _input(event: InputEvent) -> void:
	# Esc funguje aj vtedy, keď je kurzor v textovom poli
	if mode == "question" and event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		Game.step_progress[quest_key] = step
		close()


func _unhandled_input(event: InputEvent) -> void:
	match mode:
		"msg":
			if event.is_action_pressed("interact") or event.is_action_pressed("cancel") or event.is_action_pressed("ui_accept"):
				get_viewport().set_input_as_handled()
				_next_message()
		"notebook", "end":
			if mode == "notebook" and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") \
					or event.is_action_pressed("move_left") or event.is_action_pressed("move_right")):
				get_viewport().set_input_as_handled()
				open_notebook(1 - nb_page)
			elif event.is_action_pressed("notebook") or event.is_action_pressed("cancel") or event.is_action_pressed("interact"):
				get_viewport().set_input_as_handled()
				close()
		"question":
			_question_input(event)
		"":
			if event.is_action_pressed("notebook") and not Game.ui_busy:
				get_viewport().set_input_as_handled()
				open_notebook()


func _question_input(event: InputEvent) -> void:
	var st: Dictionary = quest.kroky[step]
	var confirm := event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")
	match str(st.typ):
		"volba":
			var n := (st.moznosti as Array).size()
			if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
				choice_sel = (choice_sel - 1 + n) % n
				_render_choices()
			elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
				choice_sel = (choice_sel + 1) % n
				_render_choices()
			elif event is InputEventKey and event.pressed and not event.echo and event.keycode >= KEY_1 and event.keycode < KEY_1 + n:
				choice_sel = event.keycode - KEY_1
				_render_choices()
				get_viewport().set_input_as_handled()
				_answer(choice_sel)
				return
			elif confirm:
				get_viewport().set_input_as_handled()
				_answer(choice_sel)
				return
			else:
				return
			get_viewport().set_input_as_handled()
		"os":
			if event.is_action_pressed("ui_left", true) or event.is_action_pressed("move_left", true):
				axis.move(-1)
			elif event.is_action_pressed("ui_right", true) or event.is_action_pressed("move_right", true):
				axis.move(1)
			elif confirm:
				get_viewport().set_input_as_handled()
				_answer(axis.value)
				return
			else:
				return
			get_viewport().set_input_as_handled()
