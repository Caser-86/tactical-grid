extends Node2D

const JOBS := [&"assault", &"sniper", &"heavy", &"medic", &"scout"]
const CELL_SIZE := Vector2(144, 144)

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.82, 0.84, 0.82))
	for index in range(JOBS.size()):
		var texture := ArtCatalog.get_texture(&"unit", JOBS[index])
		var sprite := Sprite2D.new()
		sprite.name = "Silhouette_%s" % JOBS[index]
		sprite.texture = texture
		sprite.modulate = Color.BLACK
		sprite.scale = Vector2(1.5, 1.5)
		sprite.position = Vector2(96.0 + CELL_SIZE.x * index, 112.0)
		add_child(sprite)

