extends Node2D
## Mestečko 64 × 56 dlaždíc postavené z textovej mapy. Uprav MAPA a spusti hru.
## Budovy, postavy a predmety sa umiestňujú podľa data/ulohy.json.
##
##   Zem:     .  tráva     =  cesta     :  cesta s kamienkami    #  námestie (dlažba)
##            _  piesok    ~  voda      d  mólo                  F  les (neprechodný)
##   Objekty: ,  trsy trávy   r/y  kvety   "  vysoká tráva   b  krík   o  kameň
##            -  plot   |  stĺpik   s  tabuľa   m  schránka   t  peň   g  záhon
##            n  lavička   L  lampa   k  stánok   B  nástenka   v  loďka
##            X  spadnutý strom (zátaras)   Y  zábrana s ceduľou   z  značka zastávky
##   Veľké:   T  strom 2×2   Q  fontána 3×3   Z  prístrešok zastávky 3×2  (ľavý horný roh)

const MAPA := """
FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF==FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFYYFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
FFFFFFF==================================================FFFFFFF
FFFFFFF==================================================FFFFFFF
FFFFFFF==..........==..........==......T...==..........==FFFFFFF
FFFFFFF==..........==..........==..........==..........==FFFFFFF
FFFFFFF==..........==..........==..........==..........==FFFFFFF
FFFFFFF==..........==..........==.......T..==..........==FFFFFFF
FFFFFFF==..........==..........==..........==..........==FFFFFFF
FFFFFFF==g.:......b==..:..g....==..:.......==..:..g....==FFFFFFF
FFFFFFF==..=.m.....==o.=.m....b==,.=...T...==..=m......==FFFFFFF
FFFFFFF==..=.......==..=.......==..=.......==..=......o==FFFFFFF
FFFFFFF==================================================FFFFFFF
FFFFFFF==================================================FFFFFFF
FFFFFFF==..........==L########L###########L==..........==FFFFFFF
FFFFFFF==..........==###kkkkk#########B#nn#==..........==FFFFFFF
FFFFFFF==..........==######################==..........==FFFFFFF
FFFFFFF==b.........==##########Q###########==..........==FFFFFFF
FFFFFFF==..........==######################==..........==FFFFFFF
FFFFFFF==..:.......==#nn###################==g.:.......==FFFFFFF
FFFFFFF==..=.m.....==###############nn#####==..=m......==FFFFFFF
FFFFFFF==..=.......==L#############L######L==..=.......==FFFFFFF
FFFFFFF==================================================XFFFFFF
FFFFFFF==================================================XFFFFFF
FFFFFFF==..........==.......T..==..........==..........==FFFFFFF
FFFFFFF==.......T..==..........==......T...==..........==FFFFFFF
FFFFFFF==..........==..........==..........==..........==FFFFFFF
FFFFFFF==,.........==.......T..==..........==..........==FFFFFFF
FFFFFFF==......T...==..........==.......T..==..........==FFFFFFF
FFFFFFF==..:.......==..:.......==..:.......==..:.......==FFFFFFF
FFFFFFF==T.=..g....==..=..T....==..=.T.....==g.=.mT.T..==FFFFFFF
FFFsFFF==..=r......==..=y......==."=.....b.==.g=.......==FFFFFFF
=========================================================FFFFFFF
=========================================================FFFFFFF
FFFFFFF==T....Z...z__......._______........__..........==FFFFFFF
FFFFFFF==..........__......._______........__..........==FFFFFFF
FFFFFFF==~~~.......__......._______........__..........==FFFFFFF
FFFFFFF==....T.....__......._______........__.T........==FFFFFFF
FFFFFFF==......~~~._____~~dd~~~~~~~~~~d______..........==FFFFFFF
FFFFFFF==..T.....T.____~~~dd~~~~~~~~~~d~~____.......t..==FFFFFFF
FFFFFFF==......T...___~~~~dd~~v~~~~~~~d~~~___..........==FFFFFFF
FFFFFFF==.b.......b__~~~~~dd~~~~~~~~~~~~~~~__.--...r.y.==FFFFFFF
FFFFFFF============__~~~~~dd~~~~~~v~~~~~~~~__============FFFFFFF
FFFFFFF============__~~~~~dd~~~~~~~~~~~~~~~__============FFFFFFF
FFFFFFFXXFFFFFFFFFF___~~dddddd~~~~~~~~~~~~___FFFFFFFFFFXXFFFFFFF
FFFFFFFFFFFFFFFFFFFFF__~~~~~~~~~~~~~~~~~~__FFFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFFFF__~~~~~~~~~~~~~~~~__FFFFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFFFFFF___~~~~~~~~~~___FFFFFFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFFFFFFFFF__________FFFFFFFFFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
"""

const GROUND := {
	"=": TileIds.PATH, ":": TileIds.PATH_PEBBLES, "_": TileIds.SAND, "~": TileIds.WATER,
	"v": TileIds.WATER, "d": TileIds.DOCK,
}
const SINGLE := {
	",": TileIds.GRASS_TUFTS, "r": TileIds.FLOWERS_RED, "y": TileIds.FLOWERS_YELLOW,
	"\"": TileIds.TALL_GRASS, "b": TileIds.BUSH, "o": TileIds.ROCK, "-": TileIds.FENCE,
	"|": TileIds.FENCE_POST, "s": TileIds.SIGN, "m": TileIds.MAILBOX, "t": TileIds.STUMP,
	"g": TileIds.FLOWERBED, "n": TileIds.BENCH, "L": TileIds.LAMP, "k": TileIds.STALL,
	"B": TileIds.BOARD, "v": TileIds.BOAT, "X": TileIds.LOG, "Y": TileIds.ROADBLOCK, "z": TileIds.BUS_SIGN,
}
const BIG := {
	"T": [TileIds.TREE, Vector2i(2, 2)],
	"Q": [TileIds.FOUNTAIN, Vector2i(3, 3)],
	"Z": [TileIds.SHELTER, Vector2i(3, 2)],
}

const NPC_SCENE := preload("res://scenes/npc.tscn")
const DOG_SCENE := preload("res://scenes/pes.tscn")

@onready var zem: TileMapLayer = $Zem
@onready var stopy: TileMapLayer = $Stopy
@onready var objekty: TileMapLayer = $Objekty
@onready var nad: TileMapLayer = $Nad
@onready var postavy: Node2D = $Postavy
@onready var player = $Postavy/Player

var rows: PackedStringArray
var ball: Item
var gabriel


func _ready() -> void:
	rows = MAPA.strip_edges().split("\n")
	_build_tiles()
	for b in Game.data.budovy:
		var bld := Building.new()
		postavy.add_child(bld)
		bld.setup(b)
	for pid in Game.data.postavy:
		var p: Dictionary = Game.data.postavy[pid]
		if p.has("vonku"):
			_spawn_npc(pid, Vector2i(int(p.vonku[0]), int(p.vonku[1])), p.get("smer", "down"))
	gabriel = DOG_SCENE.instantiate()
	var g: Array = Game.data.gabriel
	gabriel.position = Vector2(int(g[0]) * 16 + 8, int(g[1]) * 16 + 8)
	postavy.add_child(gabriel)

	var size := Vector2i(rows[0].length(), rows.size()) * 16
	player.set_camera_limits(Rect2i(Vector2i.ZERO, size))
	if Game.spawn_tile.x >= 0:
		player.place(Game.spawn_tile, Vector2i.DOWN)
	Game.state_changed.connect(_refresh)
	_refresh()
	if Game.pending_ending:
		_ending.call_deferred()
	elif Game.finale_done:
		_place_home_dog()


func _spawn_npc(pid: String, tile: Vector2i, dir: String):
	var n = NPC_SCENE.instantiate()
	n.setup(pid, tile, dir)
	postavy.add_child(n)
	return n


func _ground_at(x: int, y: int) -> Vector2i:
	var c := rows[y][x]
	if c == "F":
		return TileIds.FOREST_A if (x * 7 + y * 3) % 2 else TileIds.FOREST_B
	if c == "#":
		return TileIds.PLAZA_A if (x + y) % 2 else TileIds.PLAZA_B
	if GROUND.has(c):
		return GROUND[c]
	# pod objektom použij najčastejšiu zem okolo (napr. lavička na dlažbe)
	var count := {}
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if ny >= 0 and ny < rows.size() and nx >= 0 and nx < rows[ny].length():
			var n := rows[ny][nx]
			if n in ["#", "_", "=", "~", "d"]:
				count[n] = count.get(n, 0) + 1
	if not count.is_empty():
		var best: String = count.keys()[0]
		for k in count:
			if count[k] > count[best]:
				best = k
		if best == "#":
			return TileIds.PLAZA_A if (x + y) % 2 else TileIds.PLAZA_B
		return GROUND[best]
	return TileIds.GRASS if (x * 7 + y * 13) % 11 else TileIds.GRASS_TUFTS


func _build_tiles() -> void:
	for y in rows.size():
		var line: String = rows[y]
		for x in line.length():
			var c := line[x]
			var cell := Vector2i(x, y)
			zem.set_cell(cell, 0, _ground_at(x, y))
			if SINGLE.has(c):
				objekty.set_cell(cell, 0, SINGLE[c])
			elif BIG.has(c):
				var origin: Vector2i = BIG[c][0]
				var size: Vector2i = BIG[c][1]
				for j in size.y:
					for i in size.x:
						# horný riadok stromov a prístrešku ide do vrstvy "Nad" – hráč prejde za korunu
						var layer := nad if (j == 0 and c != "Q") else objekty
						layer.set_cell(cell + Vector2i(i, j), 0, origin + Vector2i(i, j))


## Stopy, loptička a Gabriel sa objavia až po 11. indícii.
func _refresh() -> void:
	var after11: bool = Game.MAIN_COUNT in Game.solved_main
	stopy.clear()
	if after11:
		for p in Game.data.stopy:
			stopy.set_cell(Vector2i(int(p[0]), int(p[1])), 0, TileIds.FOOTPRINTS)
	var want_ball := after11 and not Game.has_flag("clnaren")
	if want_ball and ball == null:
		ball = Item.new()
		var b: Array = Game.data.lopticka
		ball.setup("lopticka", Vector2i(int(b[0]), int(b[1])))
		postavy.add_child(ball)
	elif not want_ball and ball != null and is_instance_valid(ball):
		ball.queue_free()
		ball = null


func _place_home_dog() -> void:
	var g: Array = Game.data.zaver_gabriel
	gabriel.at_home = true
	gabriel.position = Vector2(int(g[0]) * 16 + 8, int(g[1]) * 16 + 8)
	gabriel._refresh()


func _ending() -> void:
	_place_home_dog()
	for e in Game.data.zaver_postavy:
		var n = _spawn_npc(e[0], Vector2i(int(e[1][0]), int(e[1][1])), "up")
		n.ambient_text = "Vitaj doma, Gabriel!"
	var lines: Array = (Game.data.texty.zaver as Array).slice(0, 2)
	if "kosti" in Game.solved_side:
		lines.append(Game.data.texty.fotka)
	Game.dialog.show_messages(lines, func():
		Game.pending_ending = false
		Game.save_game()
		Game.dialog.show_end("KONIEC\n\nGabriel je doma!\n\nHlavné úlohy: %d / %d\nVedľajšie úlohy: %d / %d\nNájdené kosti: %d / %d\n\nĎakujeme, že si hral!\n[E] hrať ďalej" % [
			Game.solved_main.size(), Game.MAIN_COUNT, Game.solved_side.size(), Game.SIDE_COUNT,
			Game.bones.size(), Game.BONES_COUNT]))


func on_step(_tile: Vector2i) -> void:
	pass
