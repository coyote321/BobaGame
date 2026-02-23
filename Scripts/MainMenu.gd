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

func _ready() -> void:
	start_button.pressed.connect(_on_start_button_pressed)
	options_button.pressed.connect(_on_options_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)

	_animate_intro()
	GameManager.reset_game()

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
	if options_panel:
		options_panel.visible = !options_panel.visible
		return

	options_panel = Panel.new()
	options_panel.set_anchors_preset(Control.PRESET_CENTER)
	options_panel.size = Vector2(420, 340)
	options_panel.position = Vector2(-210, -170)
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

	_add_slider(vbox, "MASTER VOLUME", 80)
	_add_slider(vbox, "SFX VOLUME", 80)

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

func _add_slider(parent: VBoxContainer, label_text: String, default_val: float) -> void:
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
	parent.add_child(slider)
