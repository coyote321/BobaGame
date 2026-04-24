extends Control

const WORLD_SCENE_PATH: String = "res://Scenes/ShopScene.tscn"
const ACCENT_GOLD := Color(0.91, 0.76, 0.29, 1.0)
const BG_DARK := Color(0.1, 0.1, 0.12, 0.97)

@onready var start_button: Button = $CenterColumn/ButtonContainer/StartButton
@onready var options_button: Button = $CenterColumn/ButtonContainer/OptionsButton
@onready var exit_button: Button = $CenterColumn/ButtonContainer/ExitButton
@onready var title_label: Label = $CenterColumn/TitleLabel
@onready var subtitle: Label = $CenterColumn/Subtitle

var options_panel: Panel
var _click_sfx: AudioStreamPlayer = null

func _ready() -> void:
	# UI click sound
	_click_sfx = AudioStreamPlayer.new()
	_click_sfx.stream = preload("res://Assets/Audio/sfx/sfx_UI_button_click.wav")
	_click_sfx.volume_db = -5.0
	_click_sfx.bus = &"SFX"
	add_child(_click_sfx)

	# Connect all buttons with click sound
	var button_map = {
		start_button: _on_start_button_pressed,
		options_button: _on_options_button_pressed,
		exit_button: _on_exit_button_pressed,
	}
	for btn in button_map:
		btn.pressed.connect(func(cb = button_map[btn]):
			if _click_sfx: _click_sfx.play()
			cb.call()
		)

	_animate_intro()
	GameManager.reset_game()
	
	start_button.call_deferred("grab_focus")

func _animate_intro() -> void:
	var column := $CenterColumn
	column.modulate.a = 0.0
	column.position.y -= 20.0

	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(column, "modulate:a", 1.0, 0.8)
	tween.parallel().tween_property(column, "position:y", column.position.y + 20.0, 0.6)

func _on_start_button_pressed() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished
	get_tree().change_scene_to_file(WORLD_SCENE_PATH)

func _on_options_button_pressed() -> void:
	_show_options_panel()

func _on_exit_button_pressed() -> void:
	get_tree().quit()

func _show_options_panel() -> void:
	# Always rebuild the panel so sliders read the current audio state
	if options_panel and is_instance_valid(options_panel):
		options_panel.queue_free()
		options_panel = null
		return

	options_panel = Panel.new()
	options_panel.set_anchors_preset(Control.PRESET_CENTER)
	options_panel.size = Vector2(420, 400)
	options_panel.position = Vector2(-210, -200)
	add_child(options_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = BG_DARK
	style.border_color = Color(0.2, 0.2, 0.22)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	options_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	options_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "OPTIONS"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", ACCENT_GOLD)
	vbox.add_child(title)

	_add_slider(vbox, "MASTER VOLUME", "Master")
	_add_slider(vbox, "SFX VOLUME", "SFX")
	_add_slider(vbox, "MUSIC VOLUME", "Music")

	var controls := Label.new()
	controls.text = "KB/M: WASD Move | Shift Sprint | Ctrl Crouch | E Interact\n1/2/3 or Q/R Weapons | G Ability | LMB Attack | RMB Aim | Esc Pause\nXbox: L-Stick Move (moves cursor in menus) | R-Stick Aim\nRT or Y Shoot | LT Aim | A Use/Select | B Crouch | X Ability\nL3 Sprint | LB/RB Cycle Weapon | Start Pause"
	controls.add_theme_font_size_override("font_size", 11)
	controls.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(controls)

	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.flat = true
	close_btn.custom_minimum_size = Vector2(80, 32)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	close_btn.add_theme_color_override("font_hover_color", ACCENT_GOLD)
	close_btn.pressed.connect(func(): options_panel.queue_free(); options_panel = null; start_button.call_deferred("grab_focus"))
	vbox.add_child(close_btn)
	close_btn.call_deferred("grab_focus")

func _add_slider(parent: VBoxContainer, label_text: String, bus_name: String) -> void:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	parent.add_child(lbl)

	# Read the current volume from AudioServer so the slider matches
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

	# Connect slider changes to AudioServer
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
