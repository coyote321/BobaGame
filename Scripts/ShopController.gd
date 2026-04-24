extends Node2D

const ACCENT_GOLD := Color(0.91, 0.76, 0.29, 1.0)
const ACCENT_GOLD_DIM := Color(0.91, 0.76, 0.29, 0.4)
const BG_DARK := Color(0.07, 0.07, 0.09, 0.95)
const TEXT_WHITE := Color(0.92, 0.92, 0.92, 1.0)
const TEXT_DIM := Color(0.55, 0.55, 0.6, 1.0)

var font_bold: Font
var font_semi: Font
var font_medium: Font

var current_order = []
var current_mix = []
var is_customer_waiting = false
var order_description = ""

@onready var ui_interaction = $UI_Layer/InteractionLabel
@onready var ui_boba_panel = $UI_Layer/BobaPanel
@onready var ui_upgrade_panel = $UI_Layer/UpgradePanel
@onready var ui_mission_panel = $UI_Layer/MissionPanel
@onready var player = $Player

var active_zone = null

var lbl_info: Label
var lbl_order: Label
var lbl_mix: Label

func _ready():
	font_bold = load("res://Assets/Fonts/Montserrat-Bold.ttf")
	font_semi = load("res://Assets/Fonts/Montserrat-SemiBold.ttf")
	font_medium = load("res://Assets/Fonts/Montserrat-Medium.ttf")

	setup_boba_ui()
	setup_upgrade_ui()
	setup_mission_ui()

	$CounterZone.area_entered.connect(_on_zone_entered.bind("counter"))
	$CounterZone.area_exited.connect(_on_zone_exited)
	$UpgradeZone.area_entered.connect(_on_zone_entered.bind("upgrade"))
	$UpgradeZone.area_exited.connect(_on_zone_exited)
	$MissionZone.area_entered.connect(_on_zone_entered.bind("mission"))
	$MissionZone.area_exited.connect(_on_zone_exited)

	$UI_Layer/BobaPanel/CloseBoba.pressed.connect(func(): ui_boba_panel.visible = false)
	$UI_Layer/UpgradePanel/CloseUpgrade.pressed.connect(func(): ui_upgrade_panel.visible = false)
	$UI_Layer/MissionPanel/CloseMission.pressed.connect(func(): ui_mission_panel.visible = false)

	spawn_customer()

func _process(delta):
	if active_zone and Input.is_action_just_pressed("interact"):
		open_active_panel()

func _on_zone_entered(area, zone_name):
	active_zone = zone_name
	ui_interaction.text = "PRESS 'E' — " + zone_name.to_upper()
	ui_interaction.visible = true

func _on_zone_exited(area):
	active_zone = null
	ui_interaction.visible = false

func open_active_panel():
	ui_boba_panel.visible = (active_zone == "counter")
	ui_upgrade_panel.visible = (active_zone == "upgrade")
	ui_mission_panel.visible = (active_zone == "mission")

	if active_zone == "mission":
		var btn = $UI_Layer/MissionPanel/StartBtn
		btn.visible = GameManager.target_order_received
	
	# Give first interactive control focus so controller users can navigate.
	var panel: Control = null
	if active_zone == "counter":
		panel = ui_boba_panel
	elif active_zone == "upgrade":
		panel = ui_upgrade_panel
	elif active_zone == "mission":
		panel = ui_mission_panel
	if panel:
		var first_btn := _find_first_button(panel)
		if first_btn:
			first_btn.call_deferred("grab_focus")

func _find_first_button(node: Node) -> Button:
	for child in node.get_children():
		if child is Button and child.visible:
			return child
		var nested := _find_first_button(child)
		if nested:
			return nested
	return null

func _make_panel_style(bg: Color = BG_DARK, border: Color = ACCENT_GOLD_DIM, radius: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	return s

func _styled_label(text: String, font_ref: Font, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", font_ref)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _styled_button(text: String, min_size: Vector2 = Vector2(140, 42)) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.flat = true
	btn.add_theme_font_override("font", font_semi)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", TEXT_WHITE)
	btn.add_theme_color_override("font_hover_color", ACCENT_GOLD)
	btn.add_theme_color_override("font_pressed_color", ACCENT_GOLD.darkened(0.15))
	btn.add_theme_stylebox_override("normal", _make_panel_style(Color(0.14, 0.14, 0.17, 0.9), ACCENT_GOLD_DIM, 4))
	btn.add_theme_stylebox_override("hover", _make_panel_style(Color(0.18, 0.17, 0.13, 0.95), ACCENT_GOLD.lerp(Color.WHITE, 0.1) * Color(1,1,1,0.5), 4))
	btn.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.12, 0.12, 0.14, 1.0), ACCENT_GOLD, 4))
	return btn

func setup_boba_ui():
	var p = ui_boba_panel

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	p.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var header = _styled_label("BOBA STATION", font_bold, 22, ACCENT_GOLD)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = ACCENT_GOLD_DIM
	vbox.add_child(divider)

	lbl_info = _styled_label("", font_medium, 13, TEXT_DIM)
	lbl_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl_info)

	var order_bg := Panel.new()
	order_bg.custom_minimum_size = Vector2(0, 70)
	order_bg.add_theme_stylebox_override("panel", _make_panel_style(Color(0.05, 0.05, 0.07, 0.8), Color(0.2, 0.2, 0.25, 0.5), 4))
	vbox.add_child(order_bg)

	var order_margin := MarginContainer.new()
	order_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	order_margin.add_theme_constant_override("margin_left", 12)
	order_margin.add_theme_constant_override("margin_top", 8)
	order_margin.add_theme_constant_override("margin_right", 12)
	order_margin.add_theme_constant_override("margin_bottom", 8)
	order_bg.add_child(order_margin)

	lbl_order = _styled_label("", font_medium, 14, ACCENT_GOLD)
	lbl_order.autowrap_mode = TextServer.AUTOWRAP_WORD
	order_margin.add_child(lbl_order)

	lbl_mix = _styled_label("Mix: []", font_medium, 14, Color(0.5, 0.78, 1.0))
	vbox.add_child(lbl_mix)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(grid)

	var ingredients = {
		"Tea": Color(0.85, 0.7, 0.5),
		"Milk": Color(0.92, 0.92, 0.96),
		"Tapioca": Color(0.65, 0.65, 0.7),
		"Poison": Color(0.75, 0.45, 0.95)
	}

	for ing in ingredients:
		var btn := _styled_button("+ " + ing, Vector2(155, 36))
		btn.add_theme_color_override("font_color", ingredients[ing])
		btn.add_theme_color_override("font_hover_color", ingredients[ing].lightened(0.3))
		btn.pressed.connect(_add_ingredient.bind(ing))
		grid.add_child(btn)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(actions)

	var serve := _styled_button("SERVE DRINK", Vector2(155, 44))
	serve.pressed.connect(_on_serve_pressed)
	actions.add_child(serve)

	var clear := _styled_button("CLEAR", Vector2(155, 44))
	clear.add_theme_color_override("font_color", TEXT_DIM)
	clear.pressed.connect(_on_clear_pressed)
	actions.add_child(clear)

	update_info_label()

func _on_clear_pressed():
	current_mix = []
	update_mix_label()

func setup_upgrade_ui():
	var p = ui_upgrade_panel

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	p.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title = _styled_label("UPGRADES", font_bold, 22, ACCENT_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = ACCENT_GOLD_DIM
	vbox.add_child(divider)

	var btn := _styled_button("UPGRADE BOBA LAUNCHER  —  $50", Vector2(300, 44))
	btn.pressed.connect(_on_upgrade_pressed)
	vbox.add_child(btn)

func setup_mission_ui():
	var p = ui_mission_panel

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	p.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title = _styled_label("CONTRACTS", font_bold, 22, ACCENT_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = ACCENT_GOLD_DIM
	vbox.add_child(divider)

	var desc = _styled_label("Serve special orders to unlock missions.", font_medium, 13, TEXT_DIM)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc)

	var btn := _styled_button("START MISSION", Vector2(200, 46))
	btn.name = "StartBtn"
	btn.pressed.connect(_on_start_mission_pressed)
	vbox.add_child(btn)

func update_info_label():
	if lbl_info:
		lbl_info.text = "Day %d  |  $%d" % [GameManager.day, GameManager.money]

func spawn_customer():
	current_mix = []
	update_mix_label()
	is_customer_waiting = true
	var possible_ingredients = ["Tea", "Milk", "Tapioca"]
	current_order = []
	order_description = "Order: "
	var count = randi() % 2 + 2
	for i in range(count):
		var ing = possible_ingredients.pick_random()
		current_order.append(ing)
		order_description += ing + " "
	if randf() < 0.4:
		order_description += "\n\nSPECIAL ORDER"
		GameManager.target_order_received = true
	lbl_order.text = order_description

func _add_ingredient(ing):
	current_mix.append(ing)
	update_mix_label()

func update_mix_label():
	if lbl_mix:
		lbl_mix.text = "Mix: " + str(current_mix)

func _on_serve_pressed():
	if not is_customer_waiting: return
	var correct = (current_mix == current_order)
	if correct:
		GameManager.add_money(15)
		lbl_order.text = "Delicious! Well done."
	else:
		lbl_order.text = "Not what they ordered..."
	is_customer_waiting = false
	update_info_label()
	await get_tree().create_timer(1.0).timeout
	spawn_customer()

func _on_upgrade_pressed():
	if GameManager.money >= 50:
		GameManager.money -= 50
		GameManager.player_damage_multiplier += 0.5
		update_info_label()
	else:
		print("Need more cash")

func _on_start_mission_pressed():
	GameManager.start_mission()
	get_tree().change_scene_to_file(GameManager.get_mission_scene())
