extends Node
## Globálny stav hry (autoload "Game"): úlohy, indície, zápisník, uloženie, prechody medzi scénami.
## Texty a čísla úloh sú v data/ulohy.json – dajú sa meniť bez zásahu do kódu.

signal clues_changed(count: int)
signal state_changed

const MAIN_COUNT := 11
const BONES_COUNT := 8
const SIDE_COUNT := 10
const SAVE_PATH := "user://ulozenie.json"
const TOWN_SCENE := "res://scenes/main.tscn"
const INTERIOR_SCENE := "res://scenes/interior.tscn"

var data: Dictionary = {}

# --- stav hry (ukladá sa) ---
var solved_main: Array = []      # čísla hlavných úloh (1..11)
var solved_side: Array = []      # id vedľajších úloh (+ "macka", "kosti")
var flags: Dictionary = {}       # pistalka, kolac, bicykel, napoveda, kniha_stop, clnaren, ...
var bones: Array = []            # id budov, kde už je kosť nájdená
var cat_stage := 0               # 0 = úloha nezačatá, 1..3 = kde je Micka, 4 = nájdená, 5 = odovzdaná
var step_progress: Dictionary = {}  # rozpracované úlohy: kľúč -> index kroku
var building_id := "marekov_dom" # "" = vonku v meste
var spawn_tile := Vector2i(-1, -1)
var finale_done := false

# --- dočasné ---
var ui_busy := false
var dialog                       # nastaví dialog.gd
var player                       # nastaví player.gd
var pending_ending := false
var changing := false


func _ready() -> void:
	_add_action("move_up", [KEY_UP, KEY_W])
	_add_action("move_down", [KEY_DOWN, KEY_S])
	_add_action("move_left", [KEY_LEFT, KEY_A])
	_add_action("move_right", [KEY_RIGHT, KEY_D])
	_add_action("interact", [KEY_E, KEY_SPACE])
	_add_action("cancel", [KEY_ESCAPE])
	_add_action("notebook", [KEY_N, KEY_TAB])
	_load_data()


func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _load_data() -> void:
	var res = load("res://data/ulohy.json")
	if res is JSON:
		data = res.data
	else:
		var f := FileAccess.open("res://data/ulohy.json", FileAccess.READ)
		data = JSON.parse_string(f.get_as_text())


# ---------------------------------------------------------------- pomocné dotazy

func building(id: String) -> Dictionary:
	for b in data.budovy:
		if b.id == id:
			return b
	return {}


func person(pid: String) -> Dictionary:
	return data.postavy.get(pid, {})


func main_quest_of(pid: String) -> Dictionary:
	for q in data.hlavne:
		if q.postava == pid:
			return q
	return {}


func side_quest_of(pid: String) -> Dictionary:
	for q in data.vedlajsie:
		if q.postava == pid:
			return q
	return {}


func next_main_id() -> int:
	return solved_main.size() + 1


func side_unlocked(q: Dictionary) -> bool:
	var need := int(q.get("odomkne", 0))
	return need == 0 or need in solved_main


func has_flag(f: String) -> bool:
	return flags.get(f, false)


func goal_text() -> String:
	var n := next_main_id()
	if n <= MAIN_COUNT:
		return data.hlavne[n - 1].ciel
	if not has_flag("clnaren"):
		return "Člnáreň pri jazere"
	if not finale_done:
		return "Stará záhradná chatka"
	return "Gabriel je doma!"


## Má postava pre hráča niečo nové? (výkričník nad hlavou)
func has_news(pid: String) -> bool:
	if pid == "mama":
		return solved_main.is_empty()
	var mq := main_quest_of(pid)
	if not mq.is_empty() and int(mq.id) == next_main_id():
		return true
	if not mq.is_empty() and not (int(mq.id) in solved_main):
		return false
	if pid == "eva" and (cat_stage == 0 or cat_stage == 4):
		return true
	var sq := side_quest_of(pid)
	return not sq.is_empty() and side_unlocked(sq) and not (sq.id in solved_side)


# ---------------------------------------------------------------- rozhovory a úlohy

func talk(pid: String) -> void:
	var p := person(pid)
	var meno: String = p.get("meno", "?")
	var t: Dictionary = data.texty

	if pid == "mama":
		var lines: Array = t.mama_pred if solved_main.is_empty() else t.mama_po
		dialog.show_messages(lines.map(func(l): return "Mama: " + l))
		return

	var mq := main_quest_of(pid)
	if not mq.is_empty():
		var qid := int(mq.id)
		if qid == next_main_id():
			_start_main(mq, meno)
			return
		if not (qid in solved_main):
			dialog.show_message("%s: %s" % [meno, t.zaneprazdneny])
			return

	if pid == "eva" and _talk_cat(meno):
		return

	var sq := side_quest_of(pid)
	if not sq.is_empty() and side_unlocked(sq) and not (sq.id in solved_side):
		_start_side(sq, meno)
		return

	if not mq.is_empty():
		dialog.show_message("%s: %s\n%s" % [meno, t.hotovo_opakuj, mq.stopa])
	elif not sq.is_empty():
		dialog.show_message("%s: %s" % [meno, t.vedlajsia_dakujem])
	else:
		dialog.show_message("%s: Ahoj, Marek!" % meno)


func _start_main(q: Dictionary, meno: String) -> void:
	dialog.ask_quest(meno, q, "h%d" % int(q.id), q.uvod, func(): _main_done(q, meno))


func _main_done(q: Dictionary, meno: String) -> void:
	var qid := int(q.id)
	if not (qid in solved_main):
		solved_main.append(qid)
	step_progress.erase("h%d" % qid)
	clues_changed.emit(solved_main.size())
	state_changed.emit()
	save_game()
	var lines: Array = ["%s: %s Dobre, tak počúvaj:\n%s" % [meno, data.texty.spravne, q.stopa]]
	lines.append("Zapísal si si indíciu %d / %d do zápisníka. [N]" % [solved_main.size(), MAIN_COUNT])
	if qid == MAIN_COUNT:
		lines.append("Všetkých 11 indícií! Šľapaje vedú ku člnárni pri jazere.")
	dialog.show_messages(lines)


func _start_side(q: Dictionary, meno: String) -> void:
	var title: String = q.nazov + ("  (rozšírenie)" if q.get("rozsirenie", false) else "")
	dialog.show_messages(["Vedľajšia úloha: %s\nNie je povinná. Esc = odmietnuť." % title], func():
		dialog.ask_quest(meno, q, "v_" + q.id, q.uvod, func(): _side_done(q, meno)))


func _side_done(q: Dictionary, meno: String) -> void:
	if not (q.id in solved_side):
		solved_side.append(q.id)
	step_progress.erase("v_" + q.id)
	if q.has("flag"):
		flags[q.flag] = true
	state_changed.emit()
	save_game()
	dialog.show_messages(["%s: %s Ďakujem!" % [meno, data.texty.spravne], "Odmena: " + q.odmena])


func _talk_cat(meno: String) -> bool:
	var t: Dictionary = data.texty
	if not (1 in solved_main):
		return false
	match cat_stage:
		0:
			cat_stage = 1
			state_changed.emit()
			save_game()
			dialog.show_messages(["Vedľajšia úloha: Mačka Micka (bez matematiky)", "%s: %s" % [meno, t.macka_uvod]])
			return true
		1, 2, 3:
			dialog.show_message("%s: Micka sa ešte nenašla. Skús %s." % [meno, building(data.macka[cat_stage - 1]).nazov])
			return true
		4:
			cat_stage = 5
			if not ("macka" in solved_side):
				solved_side.append("macka")
			state_changed.emit()
			save_game()
			dialog.show_messages(["%s: %s" % [meno, t.macka_odmena]])
			return true
	return false


func cat_building() -> String:
	if cat_stage >= 1 and cat_stage <= 3:
		return data.macka[cat_stage - 1]
	return ""


func find_cat() -> void:
	var lines: Array = data.texty.macka_najdena
	var line: String = lines[cat_stage - 1]
	cat_stage += 1
	state_changed.emit()
	save_game()
	dialog.show_message(line)


func find_bone(bid: String) -> void:
	if bid in bones:
		return
	bones.append(bid)
	var lines: Array = ["%s (%d / %d)" % [data.texty.kost_najdena, bones.size(), BONES_COUNT]]
	if bones.size() >= BONES_COUNT and not ("kosti" in solved_side):
		solved_side.append("kosti")
		lines.append(data.texty.kosti_vsetky)
	state_changed.emit()
	save_game()
	dialog.show_messages(lines)


func closed_building(b: Dictionary) -> void:
	if b.id == "clnaren" and MAIN_COUNT in solved_main:
		flags["clnaren"] = true
		state_changed.emit()
		save_game()
		dialog.show_messages(data.texty.clnaren_stopy)
		return
	dialog.show_message(b.get("zatvorene", b.nazov + " je zatvorené."))


func found_gabriel() -> void:
	var t: Dictionary = data.texty
	var lines: Array = (t.gabriel_pistalka if has_flag("pistalka") else t.gabriel_bez).duplicate()
	if has_flag("kolac"):
		lines.append(t.gabriel_kolac)
	finale_done = true
	dialog.show_messages(lines, func():
		pending_ending = true
		var p: Array = data.zaver_hrac
		spawn_tile = Vector2i(int(p[0]), int(p[1]))
		save_game()
		goto_town())


# ---------------------------------------------------------------- scény

func new_game() -> void:
	solved_main = []
	solved_side = []
	flags = {}
	bones = []
	cat_stage = 0
	step_progress = {}
	finale_done = false
	pending_ending = false
	building_id = "marekov_dom"
	spawn_tile = Vector2i(-1, -1)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_change(INTERIOR_SCENE)


func continue_game() -> void:
	load_game()
	_change(TOWN_SCENE if building_id == "" else INTERIOR_SCENE)


func enter_building(bid: String) -> void:
	building_id = bid
	spawn_tile = Vector2i(-1, -1)
	save_game()
	_change(INTERIOR_SCENE)


func exit_building() -> void:
	var b := building(building_id)
	building_id = ""
	spawn_tile = Vector2i(int(b.x) + (int(b.w) - 1) / 2, int(b.y) + 4)
	save_game()
	_change(TOWN_SCENE)


func goto_town() -> void:
	building_id = ""
	_change(TOWN_SCENE)


func _change(path: String) -> void:
	if changing:
		return
	changing = true
	ui_busy = true
	if dialog and is_instance_valid(dialog):
		await dialog.fade_out()
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	changing = false
	ui_busy = false


# ---------------------------------------------------------------- uloženie

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var spawn := spawn_tile
	if building_id == "" and player and is_instance_valid(player) and not pending_ending:
		spawn = player.tile()
	var d := {
		"solved_main": solved_main, "solved_side": solved_side, "flags": flags, "bones": bones,
		"cat_stage": cat_stage, "step_progress": step_progress, "building_id": building_id,
		"spawn": [spawn.x, spawn.y], "finale_done": finale_done,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


func load_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	solved_main = (d.get("solved_main", []) as Array).map(func(x): return int(x))
	solved_side = d.get("solved_side", [])
	flags = d.get("flags", {})
	bones = d.get("bones", [])
	cat_stage = int(d.get("cat_stage", 0))
	step_progress = d.get("step_progress", {})
	building_id = d.get("building_id", "")
	var s: Array = d.get("spawn", [-1, -1])
	spawn_tile = Vector2i(int(s[0]), int(s[1]))
	finale_done = d.get("finale_done", false)
	pending_ending = false
