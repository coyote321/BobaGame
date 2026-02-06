extends Control

const WORLD_SCENE_PATH: String = "res://Scenes/ShopScene.tscn"

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var options_button: Button = $VBoxContainer/OptionsButton
@onready var exit_button: Button = $VBoxContainer/ExitButton

var options_panel: Panel

func _ready() -> void:
	start_button.pressed.connect(_on_start_button_pressed)
	options_button.pressed.connect(_on_options_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)
	
	# Animate title on load
	animate_title()
	
	# Reset game state
	GameManager.day = 1
	GameManager.money = 0
	GameManager.xp = 0
	GameManager.level = 1
	GameManager.current_phase = "SHOP"
	GameManager.target_order_received = false
	GameManager.current_contract = {}

func animate_title() -> void:
	if has_node("TitleContainer"):
		var title = $TitleContainer
		title.modulate.a = 0
		var tween = create_tween()
		tween.tween_property(title, "modulate:a", 1.0, 1.0)
		tween.parallel().tween_property(title, "position:y", title.position.y, 0.5).from(title.position.y - 30)

func _on_start_button_pressed() -> void:
	# Fade transition
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	get_tree().change_scene_to_file(WORLD_SCENE_PATH)

func _on_options_button_pressed() -> void:
	show_options_panel()

func _on_exit_button_pressed() -> void:
	get_tree().quit()

func show_options_panel():
	if options_panel:
		options_panel.visible = !options_panel.visible
		return
	
	# Create options panel
	options_panel = Panel.new()
	options_panel.set_anchors_preset(Control.PRESET_CENTER)
	options_panel.size = Vector2(400, 300)
	options_panel.position = Vector2(-200, -150)
	add_child(options_panel)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.1, 0.08, 0.95)
	style.border_color = Color(0.4, 0.3, 0.2)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	options_panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	vbox.add_theme_constant_override("separation", 15)
	options_panel.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "OPTIONS"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.7))
	vbox.add_child(title)
	
	# Master Volume
	var vol_label = Label.new()
	vol_label.text = "Master Volume"
	vbox.add_child(vol_label)
	
	var vol_slider = HSlider.new()
	vol_slider.min_value = 0
	vol_slider.max_value = 100
	vol_slider.value = 80
	vol_slider.custom_minimum_size = Vector2(300, 30)
	vbox.add_child(vol_slider)
	
	# SFX Volume
	var sfx_label = Label.new()
	sfx_label.text = "SFX Volume"
	vbox.add_child(sfx_label)
	
	var sfx_slider = HSlider.new()
	sfx_slider.min_value = 0
	sfx_slider.max_value = 100
	sfx_slider.value = 80
	sfx_slider.custom_minimum_size = Vector2(300, 30)
	vbox.add_child(sfx_slider)
	
	# Controls info
	var controls = Label.new()
	controls.text = "CONTROLS:\nWASD - Move | Shift - Sprint\nCtrl - Crouch | E - Interact\n1/2 - Switch weapons | G - Dash\nLeft Click - Attack | Right Click - Aim"
	controls.add_theme_font_size_override("font_size", 12)
	controls.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(controls)
	
	# Close button
	var close_btn = Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size = Vector2(100, 35)
	close_btn.pressed.connect(func(): options_panel.visible = false)
	vbox.add_child(close_btn)
