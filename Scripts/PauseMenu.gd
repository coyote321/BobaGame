extends CanvasLayer

const ACCENT_GOLD := Color(0.91, 0.76, 0.29, 1.0)
const BG_DARK := Color(0.1, 0.1, 0.12, 0.97)

@onready var control_root: Control = $Control
@onready var resume_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/ResumeButton
@onready var options_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/OptionsButton
@onready var quit_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/QuitButton

var options_panel: Panel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide_pause_menu()

	resume_button.pressed.connect(_on_resume_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if get_tree().paused:
			resume_game()
		else:
			pause_game()
		get_viewport().set_input_as_handled()

func pause_game() -> void:
	show_pause_menu()
	get_tree().paused = true

func resume_game() -> void:
	if options_panel and options_panel.visible:
		options_panel.visible = false
	hide_pause_menu()
	get_tree().paused = false

func show_pause_menu() -> void:
	control_root.visible = true

func hide_pause_menu() -> void:
	control_root.visible = false
	if options_panel:
		options_panel.visible = false

func _on_resume_pressed() -> void:
	resume_game()

func _on_options_pressed() -> void:
	_show_options_panel()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _show_options_panel() -> void:
	if options_panel:
		options_panel.visible = !options_panel.visible
		return

	options_panel = Panel.new()
	options_panel.set_anchors_preset(Control.PRESET_CENTER)
	options_panel.size = Vector2(420, 340)
	options_panel.position = Vector2(-210, -170)
	control_root.add_child(options_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = BG_DARK
	style.border_color = Color(0.91, 0.76, 0.29, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
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

	_add_slider(vbox, "MASTER VOLUME", GameManager.master_volume, GameManager.set_master_volume)
	_add_slider(vbox, "SFX VOLUME", GameManager.sfx_volume, GameManager.set_sfx_volume)

	var controls := Label.new()
	controls.text = "WASD Move  |  Shift Sprint  |  Ctrl Crouch\nE Interact  |  1/2 Weapons  |  G Dash\nLMB Attack  |  RMB Aim"
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
	close_btn.pressed.connect(func(): options_panel.visible = false)
	vbox.add_child(close_btn)

func _add_slider(parent: VBoxContainer, label_text: String, default_val: float, callback: Callable) -> void:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	parent.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.value = default_val
	slider.custom_minimum_size = Vector2(0, 24)
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(callback)
	parent.add_child(slider)
