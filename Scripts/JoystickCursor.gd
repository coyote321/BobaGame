extends Node

# Moves the OS mouse cursor with an analog stick. Bindings come from the
# Input Map (Project Settings -> Input Map):
#   move_left/right/up/down  -> left stick (used in menus to move cursor)
#   aim_left/right/up/down   -> right stick (used in gameplay to move cursor)
#
# When the game is paused or there is no active player (main menu, end
# screen, etc.) the LEFT stick drives the cursor so menus are easy to
# navigate. During gameplay the LEFT stick is reserved for movement and
# the RIGHT stick drives the cursor (so it doubles as aim).

@export var cursor_speed: float = 900.0
@export var sensitivity_curve: float = 1.5

const STICK_DEADZONE: float = 0.25

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
		return _get_joypad_vector(
			JOY_AXIS_LEFT_X,
			JOY_AXIS_LEFT_Y,
			JOY_BUTTON_DPAD_LEFT,
			JOY_BUTTON_DPAD_RIGHT,
			JOY_BUTTON_DPAD_UP,
			JOY_BUTTON_DPAD_DOWN
		)
	return _get_joypad_vector(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)

func _get_joypad_vector(axis_x, axis_y, dpad_left := -1, dpad_right := -1, dpad_up := -1, dpad_down := -1) -> Vector2:
	var strongest := Vector2.ZERO
	for device in Input.get_connected_joypads():
		var axis := Vector2(
			Input.get_joy_axis(device, axis_x),
			Input.get_joy_axis(device, axis_y)
		)
		if abs(axis.x) < STICK_DEADZONE:
			axis.x = 0.0
		if abs(axis.y) < STICK_DEADZONE:
			axis.y = 0.0

		var dpad := Vector2.ZERO
		if dpad_left != -1 and Input.is_joy_button_pressed(device, dpad_left):
			dpad.x -= 1.0
		if dpad_right != -1 and Input.is_joy_button_pressed(device, dpad_right):
			dpad.x += 1.0
		if dpad_up != -1 and Input.is_joy_button_pressed(device, dpad_up):
			dpad.y -= 1.0
		if dpad_down != -1 and Input.is_joy_button_pressed(device, dpad_down):
			dpad.y += 1.0

		var vector := dpad.normalized() if dpad != Vector2.ZERO else axis
		if vector.length() > strongest.length():
			strongest = vector

	return strongest if strongest.length() >= STICK_DEADZONE else Vector2.ZERO

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
