extends Node

# Moves the OS mouse cursor with an analog stick. Bindings come from the
# Input Map (Project Settings -> Input Map):
#   menu_cursor_left/right/up/down -> left stick only (used in menus)
#   aim_left/right/up/down   -> right stick (used in gameplay to move cursor)
#
# When the game is paused or there is no active player (main menu, end
# screen, etc.) the LEFT stick drives the cursor so menus are easy to
# navigate. During gameplay the LEFT stick is reserved for movement and
# the RIGHT stick drives the cursor (so it doubles as aim).

@export var cursor_speed: float = 900.0
@export var sensitivity_curve: float = 1.5

func _ready() -> void:
	# Keep moving the cursor while the game is paused (pause menu).
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if is_menu_active() and Input.is_action_just_pressed("menu_select"):
		_left_click_at_cursor()
	
	var stick := _get_active_stick()
	if stick == Vector2.ZERO:
		return
	
	var magnitude: float = pow(clamp(stick.length(), 0.0, 1.0), sensitivity_curve)
	var move: Vector2 = stick.normalized() * magnitude * cursor_speed * delta
	
	var viewport := get_viewport()
	if viewport == null:
		return
	var new_pos := viewport.get_mouse_position() + move
	var size := viewport.get_visible_rect().size
	new_pos.x = clamp(new_pos.x, 0.0, size.x - 1.0)
	new_pos.y = clamp(new_pos.y, 0.0, size.y - 1.0)
	viewport.warp_mouse(new_pos)

func _get_active_stick() -> Vector2:
	if is_menu_active():
		return Input.get_vector("menu_cursor_left", "menu_cursor_right", "menu_cursor_up", "menu_cursor_down")
	return Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")

func is_menu_active() -> bool:
	var tree := get_tree()
	if tree == null:
		return true
	if tree.paused:
		return true
	
	var viewport := get_viewport()
	if viewport and viewport.gui_get_focus_owner():
		return true
	
	var scene := tree.current_scene
	if scene and scene.has_method("_is_any_panel_open") and scene._is_any_panel_open():
		return true
	
	# No player in the scene means we're on a menu / end screen.
	return tree.get_first_node_in_group("player") == null

func _left_click_at_cursor() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	
	var pos := viewport.get_mouse_position()
	_push_mouse_button(viewport, pos, true)
	_push_mouse_button(viewport, pos, false)

func _push_mouse_button(viewport: Viewport, pos: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = pos
	event.global_position = pos
	event.factor = 1.0
	viewport.push_input(event, true)
