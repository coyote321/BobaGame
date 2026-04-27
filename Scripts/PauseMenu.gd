extends CanvasLayer


const ACCENT_GOLD := Color(0.91, 0.76, 0.29, 1.0)
const BG_DARK := Color(0.07, 0.07, 0.09, 0.97)

var _click_sfx: AudioStreamPlayer = null
var _options_panel: Panel = null

@onready var control_root: Control = $Control
@onready var resume_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/ResumeButton
@onready var abort_mission_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/AbortMissionButton
@onready var options_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/OptionsButton
@onready var quit_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/QuitButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	hide_pause_menu()

	# UI click sound
	_click_sfx = AudioStreamPlayer.new()
	_click_sfx.stream = preload("res://Assets/Audio/sfx/sfx_UI_button_click.wav")
	_click_sfx.volume_db = -5.0
	_click_sfx.bus = &"SFX"
	add_child(_click_sfx)

	# Connect all menu buttons with click sound
	var button_map = {
		resume_button: _on_resume_pressed,
		abort_mission_button: _on_abort_mission_pressed,
		options_button: _on_options_pressed,
		quit_button: _on_quit_pressed,
	}
	for btn in button_map:
		if btn:
			btn.pressed.connect(func(cb = button_map[btn]):
				if _click_sfx: _click_sfx.play()
				cb.call()
			)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		# If options panel is open, close it instead of toggling pause
		if _options_panel and is_instance_valid(_options_panel):
			_close_options_panel()
			get_viewport().set_input_as_handled()
			return
		# If a shop panel is open, close it instead of pausing
		var shop = get_tree().current_scene
		if shop and shop.has_method("_is_any_panel_open") and shop._is_any_panel_open():
			if shop.has_method("_close_all_panels"):
				shop._close_all_panels()
			get_viewport().set_input_as_handled()
			return
		if get_tree().paused:
			resume_game()
		else:
			pause_game()
		get_viewport().set_input_as_handled()

func pause_game() -> void:
	show_pause_menu()
	get_tree().paused = true
	print("Game Paused")

func resume_game() -> void:
	_close_options_panel()
	hide_pause_menu()
	get_tree().paused = false
	print("Game Resumed")

func show_pause_menu() -> void:
	control_root.visible = true
	if abort_mission_button:
		abort_mission_button.visible = GameManager.current_phase == "MISSION"
	if resume_button:
		resume_button.call_deferred("grab_focus")

func hide_pause_menu() -> void:
	control_root.visible = false

func _on_resume_pressed() -> void:
	resume_game()

func _on_options_pressed() -> void:
	_toggle_options_panel()

func _on_abort_mission_pressed() -> void:
	hide_pause_menu()
	get_tree().paused = false
	GameManager.abort_mission_to_shop()

func _on_quit_pressed() -> void:
	get_tree().quit()


func _toggle_options_panel() -> void:
	if _options_panel and is_instance_valid(_options_panel):
		_close_options_panel()
	else:
		_show_options_panel()

func _close_options_panel() -> void:
	if _options_panel and is_instance_valid(_options_panel):
		_options_panel.queue_free()
	_options_panel = null
	if control_root.visible and resume_button:
		resume_button.call_deferred("grab_focus")

func _show_options_panel() -> void:
	_options_panel = Panel.new()
	_options_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_options_panel.set_anchors_preset(Control.PRESET_CENTER)
	_options_panel.size = Vector2(420, 360)
	_options_panel.position = Vector2(-210, -180)
	control_root.add_child(_options_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = BG_DARK
	style.border_color = Color(0.91, 0.76, 0.29, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	_options_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 24)
	_options_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "OPTIONS"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", ACCENT_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_add_slider(vbox, "MASTER VOLUME", "Master")
	_add_slider(vbox, "SFX VOLUME", "SFX")
	_add_slider(vbox, "MUSIC VOLUME", "Music")

	var controls_label := Label.new()
	controls_label.text = "KB/M: WASD Move | Shift Sprint | Ctrl Crouch | E Interact\n1/2/3 or Q/R Weapons | G Ability | LMB Attack | RMB Aim | Esc Pause\nXbox: L-Stick Move (moves cursor in menus) | R-Stick Aim\nRT or Y Shoot | LT Aim | A Use/Select | B Crouch | X Ability\nL3 Sprint | LB/RB Cycle Weapon | Start Pause"
	controls_label.add_theme_font_size_override("font_size", 11)
	controls_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(controls_label)

	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.flat = true
	close_btn.custom_minimum_size = Vector2(80, 32)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	close_btn.add_theme_color_override("font_hover_color", ACCENT_GOLD)
	close_btn.pressed.connect(_close_options_panel)
	vbox.add_child(close_btn)
	close_btn.call_deferred("grab_focus")

func _add_slider(parent: VBoxContainer, label_text: String, bus_name: String) -> void:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	parent.add_child(lbl)

	var bus_idx := AudioServer.get_bus_index(bus_name)
	var current_val := 80.0
	if bus_idx >= 0:
		if AudioServer.is_bus_mute(bus_idx):
			current_val = 0.0
		else:
			current_val = db_to_linear(AudioServer.get_bus_volume_db(bus_idx)) * 100.0

	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = current_val
	slider.custom_minimum_size = Vector2(0, 24)
	parent.add_child(slider)

	slider.value_changed.connect(_on_volume_slider_changed.bind(bus_name))

func _on_volume_slider_changed(val: float, bus_name: String) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	if val <= 0.0:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(val / 100.0))
