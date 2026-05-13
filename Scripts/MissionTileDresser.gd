extends Node

const TILE_ROOT := "res://Assets/Sprites/ZombieTileset"
const TILE_SCALE: float = 4.0

static func decorate(scene: Node2D) -> void:
	if scene == null or scene.get_node_or_null("TileDressing") != null:
		return

	var dresser := Node2D.new()
	dresser.name = "TileDressing"
	dresser.z_index = -80
	scene.add_child(dresser)
	scene.move_child(dresser, 0)

	var bounds := _scene_bounds(scene)
	var scene_name := String(scene.name)
	var terrain := _load_textures("Terrain Variations")
	var roads := _load_textures("Modular Road")
	var paths := _load_textures("Modular Terrain Path")
	var urban := _load_textures("Urban Assets")
	var cars := _load_textures("Broken Cars and Tires")
	var stains := _load_textures("Random Blood Stains")
	var trees := _load_textures("Trees")
	var fences := _load_textures("Modular Fences")
	var walls := _load_textures("Terrain wall")
	var gas := _load_textures("Gas Station")

	_add_ground_variation(dresser, bounds, terrain)

	match scene_name:
		"MissionScene":
			_add_road_strip(dresser, roads, Vector2(220, 760), Vector2(2260, 760), 96.0)
			_add_prop_cluster(dresser, cars + urban + stains, [
				Vector2(420, 610), Vector2(690, 960), Vector2(1470, 610),
				Vector2(1740, 910), Vector2(2070, 520), Vector2(1010, 1180)
			], 4.0, -30)
		"MissionScene2":
			_add_road_strip(dresser, roads, Vector2(260, 1120), Vector2(2180, 360), 112.0)
			_add_prop_cluster(dresser, urban + fences + stains, [
				Vector2(520, 420), Vector2(840, 1160), Vector2(1220, 820),
				Vector2(1620, 330), Vector2(1960, 1000)
			], 4.0, -30)
		"MissionScene3":
			_add_arena_rim(dresser, paths + walls, Vector2(1100, 700), 520.0)
			_add_prop_cluster(dresser, stains + fences + urban, [
				Vector2(560, 360), Vector2(1640, 360), Vector2(560, 1040),
				Vector2(1640, 1040), Vector2(1100, 250), Vector2(1100, 1150)
			], 4.0, -30)
		"MissionScene4":
			_add_road_strip(dresser, paths, Vector2(280, 720), Vector2(2120, 720), 96.0)
			_add_prop_cluster(dresser, trees + fences + stains, [
				Vector2(340, 260), Vector2(520, 1180), Vector2(1860, 260),
				Vector2(2040, 1180), Vector2(1160, 300), Vector2(1360, 1120)
			], 4.0, -30)
		"MissionScene5":
			_add_road_strip(dresser, roads + paths, Vector2(220, 2580), Vector2(3120, 700), 118.0)
			_add_prop_cluster(dresser, cars + fences + stains + gas + trees, [
				Vector2(560, 2460), Vector2(940, 2140), Vector2(1440, 1820),
				Vector2(1880, 1500), Vector2(2380, 1160), Vector2(2860, 900),
				Vector2(3420, 580), Vector2(3260, 1220), Vector2(1180, 560)
			], 4.8, -30)

static func _scene_bounds(scene: Node2D) -> Rect2:
	var bg := scene.get_node_or_null("Background") as Polygon2D
	if bg == null or bg.polygon.is_empty():
		return Rect2(Vector2.ZERO, Vector2(2400, 1500))

	var rect := Rect2(bg.polygon[0], Vector2.ZERO)
	for point in bg.polygon:
		rect = rect.expand(point)
	return rect

static func _load_textures(folder: String) -> Array:
	var textures := []
	var dir_path := TILE_ROOT + "/" + folder
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return textures

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.to_lower().ends_with(".png"):
			var tex := _load_png_texture(dir_path + "/" + file_name)
			if tex:
				textures.append(tex)
		file_name = dir.get_next()
	dir.list_dir_end()
	return textures

static func _load_png_texture(path: String) -> Texture2D:
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)

static func _add_ground_variation(parent: Node2D, bounds: Rect2, textures: Array) -> void:
	if textures.is_empty():
		return
	var start_x := int(bounds.position.x) + 96
	var end_x := int(bounds.position.x + bounds.size.x) - 96
	var start_y := int(bounds.position.y) + 96
	var end_y := int(bounds.position.y + bounds.size.y) - 96
	var idx := 0
	for x in range(start_x, end_x, 192):
		for y in range(start_y, end_y, 192):
			if (idx % 3) != 0:
				idx += 1
				continue
			var pos := Vector2(x + ((idx * 37) % 90), y + ((idx * 53) % 90))
			_add_sprite(parent, textures[idx % textures.size()], pos, TILE_SCALE, -90, 0.0, 0.28)
			idx += 1

static func _add_road_strip(parent: Node2D, textures: Array, start: Vector2, end: Vector2, spacing: float) -> void:
	if textures.is_empty():
		return
	var distance := start.distance_to(end)
	var steps := maxi(1, int(distance / spacing))
	var angle := (end - start).angle()
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var pos := start.lerp(end, t)
		_add_sprite(parent, textures[i % textures.size()], pos, TILE_SCALE, -85, angle, 0.82)

static func _add_arena_rim(parent: Node2D, textures: Array, center: Vector2, radius: float) -> void:
	if textures.is_empty():
		return
	for i in range(28):
		var angle := (TAU / 28.0) * float(i)
		var pos := center + Vector2(cos(angle), sin(angle)) * radius
		_add_sprite(parent, textures[i % textures.size()], pos, TILE_SCALE, -84, angle, 0.75)

static func _add_prop_cluster(parent: Node2D, textures: Array, positions: Array, scale: float, z: int) -> void:
	if textures.is_empty():
		return
	for i in range(positions.size()):
		var rot := 0.0
		if (i % 4) == 1:
			rot = PI * 0.5
		elif (i % 4) == 2:
			rot = PI
		elif (i % 4) == 3:
			rot = PI * 1.5
		_add_sprite(parent, textures[i % textures.size()], positions[i], scale, z, rot, 0.95)

static func _add_sprite(parent: Node2D, tex: Texture2D, pos: Vector2, scale_value: float, z: int, rotation: float = 0.0, alpha: float = 1.0) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.position = pos
	sprite.scale = Vector2(scale_value, scale_value)
	sprite.rotation = rotation
	sprite.z_index = z
	sprite.modulate.a = alpha
	parent.add_child(sprite)
