extends Node2D
## Interiér budovy (20 × 12 dlaždíc). Rozloženie je v data/ulohy.json → "interiery".
##   ^ stena (vrch)  W stena  O okno  B tabuľa  N siete  R náradie  I obraz  L hodiny
##   . podlaha  r koberec  c pult  s regál  k knižnica  t stôl  h stolička  f chladnička
##   z mraznička  o pec  l skrinka  w ponk  x debna  p kvetináč  d lavica  q balíky
##   a gauč  b posteľ  e chlieb  g kvety  u sud  E východ
##   1 obyvateľ  3 skrytá kosť  4 mačka Micka  @ kde hráč vojde

const OBJ := {
	"^": TileIds.WALL_TOP, "W": TileIds.WALL, "O": TileIds.WALL_WINDOW, "B": TileIds.BLACKBOARD,
	"N": TileIds.NET, "R": TileIds.TOOL_WALL, "I": TileIds.PICTURE, "L": TileIds.CLOCK,
	"c": TileIds.COUNTER, "s": TileIds.SHELF, "k": TileIds.BOOKSHELF, "t": TileIds.TABLE,
	"h": TileIds.CHAIR, "f": TileIds.FRIDGE, "z": TileIds.FREEZER, "o": TileIds.OVEN,
	"l": TileIds.LOCKER, "w": TileIds.WORKBENCH, "x": TileIds.CRATE, "p": TileIds.PLANT,
	"d": TileIds.DESK, "q": TileIds.PARCELS, "a": TileIds.SOFA, "b": TileIds.BED,
	"e": TileIds.BREAD, "g": TileIds.FLOWER_TABLE, "u": TileIds.BARREL, "E": TileIds.EXIT_MAT,
}
const FLOORS := {"wood": TileIds.FLOOR_WOOD, "tile": TileIds.FLOOR_TILE, "stone": TileIds.FLOOR_STONE}
const NPC_SCENE := preload("res://scenes/npc.tscn")

@onready var zem: TileMapLayer = $Zem
@onready var objekty: TileMapLayer = $Objekty
@onready var postavy: Node2D = $Postavy
@onready var player = $Postavy/Player

var info: Dictionary
var exits: Array = []


func _ready() -> void:
	info = Game.building(Game.building_id)
	var tpl: Dictionary = Game.data.interiery[info.interier]
	var floor_tile: Vector2i = FLOORS.get(tpl.podlaha, TileIds.FLOOR_WOOD)
	var rows: Array = tpl.mapa
	var spawn := Vector2i(9, 10)
	for y in rows.size():
		var line: String = rows[y]
		for x in line.length():
			var c := line[x]
			var cell := Vector2i(x, y)
			zem.set_cell(cell, 0, TileIds.RUG if c == "r" else floor_tile)
			if OBJ.has(c):
				objekty.set_cell(cell, 0, OBJ[c])
			match c:
				"E":
					exits.append(cell)
				"@":
					spawn = cell
				"1":
					_spawn_residents(cell)
				"3":
					if Game.building_id in Game.data.kosti and not (Game.building_id in Game.bones):
						var it := Item.new()
						it.setup("kost", cell, Game.building_id)
						postavy.add_child(it)
				"4":
					if Game.cat_building() == Game.building_id:
						var cat := Item.new()
						cat.setup("macka", cell, Game.building_id)
						postavy.add_child(cat)
	var size := Vector2i(rows[0].length(), rows.size()) * 16
	player.set_camera_limits(Rect2i(Vector2i.ZERO, size))
	player.place(spawn, Vector2i.UP)
	player.stepped.connect(_on_step)
	Game.dialog.show_toast(info.nazov)
	if Game.building_id == "marekov_dom" and not Game.has_flag("uvod"):
		Game.flags["uvod"] = true
		Game.dialog.show_messages.call_deferred([Game.data.texty.start, Game.data.texty.ovladanie])


func _spawn_residents(cell: Vector2i) -> void:
	for pid in Game.data.postavy:
		var p: Dictionary = Game.data.postavy[pid]
		if p.get("budova", "") == Game.building_id:
			var n = NPC_SCENE.instantiate()
			n.setup(pid, cell, p.get("smer", "down"))
			postavy.add_child(n)
			return


func _on_step(tile: Vector2i) -> void:
	if tile in exits:
		Game.exit_building()
