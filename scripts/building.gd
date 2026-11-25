extends StaticBody2D
class_name Building
## Budova v meste. Pôvod uzla je v ľavom dolnom rohu, takže sa správne triedi podľa Y
## (hráč môže zájsť za strechu). Dáta budovy sú v data/ulohy.json → "budovy".

var info: Dictionary = {}


func setup(b: Dictionary) -> void:
	info = b
	name = str(b.id)
	var w := int(b.w)
	position = Vector2(int(b.x) * 16, (int(b.y) + 4) * 16)

	var spr := Sprite2D.new()
	spr.texture = load("res://assets/budovy/%s.png" % b.id)
	spr.centered = false
	spr.offset = Vector2(0, -64)
	add_child(spr)

	# najvyšší riadok strechy je priechodný (hráč zájde za budovu)
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(w * 16, 48)
	cs.shape = sh
	cs.position = Vector2(w * 8, -24)
	add_child(cs)

	var door := BuildingDoor.new()
	door.building = self
	door.position = Vector2(((w - 1) / 2) * 16 + 8, -8)
	add_child(door)


func door_tile() -> Vector2i:
	return Vector2i(int(info.x) + (int(info.w) - 1) / 2, int(info.y) + 3)
