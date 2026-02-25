extends Node2D

const SHIFT_DURATION: float = 120.0
const MAX_CUSTOMERS: int = 5
const CUSTOMER_SLOTS_Y: float = 350.0
const SLOT_SPACING: float = 120.0
const SLOT_START_X: float = 400.0

const ACCENT_GOLD := Color(0.91, 0.76, 0.29, 1.0)
const ACCENT_GOLD_DIM := Color(0.91, 0.76, 0.29, 0.4)
const BG_DARK := Color(0.07, 0.07, 0.09, 0.95)
const TEXT_WHITE := Color(0.92, 0.92, 0.92, 1.0)
const TEXT_DIM := Color(0.55, 0.55, 0.6, 1.0)
const TEXT_GREEN := Color(0.45, 0.85, 0.45, 1.0)
const TEXT_RED := Color(1.0, 0.35, 0.35, 1.0)

var font_bold: Font
var font_semi: Font
var font_medium: Font

var time_remaining: float = SHIFT_DURATION
var shift_active: bool = true
var active_customers: Array = []
var customer_slots_taken: Array = [false, false, false, false, false]
var current_mix: Array = []
var active_zone = null
var customers_spawned: int = 0

@onready var ui_interaction = $UI_Layer/InteractionLabel
@onready var ui_boba_panel = $UI_Layer/BobaPanel
@onready var player = $Player
@onready var spawn_point = $CustomerSpawnPoint

var hud_container: Control
var lbl_day: Label
var lbl_time: Label
var lbl_money: Label
var lbl_customers: Label
var lbl_xp: ProgressBar
var lbl_contract: Label

var customer_scene = preload("res://Scenes/Customer.tscn")

func _ready():
	font_bold = load("res://Assets/Fonts/Montserrat-Bold.ttf")
	font_semi = load("res://Assets/Fonts/Montserrat-SemiBold.ttf")
	font_medium = load("res://Assets/Fonts/Montserrat-Medium.ttf")

	print("Shop Manager Started - Day ", GameManager.day)
	GameManager.current_phase = "SHOP"
	time_remaining = SHIFT_DURATION

	setup_hud()
	setup_zones()
	setup_boba_ui()
	setup_close_buttons()

	start_spawning()

func setup_close_buttons():
	var close_boba = get_node_or_null("UI_Layer/BobaPanel/CloseBoba")
	if close_boba:
		close_boba.pressed.connect(func(): ui_boba_panel.visible = false)

	var close_upgrade = get_node_or_null("UI_Layer/UpgradePanel/CloseUpgrade")
	if close_upgrade:
		close_upgrade.pressed.connect(func():
			var panel = get_node_or_null("UI_Layer/UpgradePanel")
			if panel:
				panel.visible = false
		)

	var close_mission = get_node_or_null("UI_Layer/MissionPanel/CloseMission")
	if close_mission:
		close_mission.pressed.connect(func():
			var panel = get_node_or_null("UI_Layer/MissionPanel")
			if panel:
				panel.visible = false
		)

func _process(delta):
	if shift_active:
		time_remaining -= delta
		update_hud()

		if time_remaining <= 0:
			end_day()

	if active_zone and Input.is_action_just_pressed("interact"):
		interact_with_zone(active_zone)

# ============ STYLE HELPERS ============

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
	btn.add_theme_stylebox_override("hover", _make_panel_style(Color(0.18, 0.17, 0.13, 0.95), Color(0.91, 0.76, 0.29, 0.5), 4))
	btn.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.12, 0.12, 0.14, 1.0), ACCENT_GOLD, 4))
	return btn

# ============ HUD SYSTEM ============

func setup_hud():
	hud_container = Control.new()
	hud_container.name = "HUD"
	hud_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	$UI_Layer.add_child(hud_container)

	var bg = Panel.new()
	bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bg.offset_bottom = 64
	bg.add_theme_stylebox_override("panel", _make_panel_style(
		Color(0.06, 0.06, 0.08, 0.92), Color(0.91, 0.76, 0.29, 0.15), 0))
	hud_container.add_child(bg)

	var accent = ColorRect.new()
	accent.color = ACCENT_GOLD_DIM
	accent.position = Vector2(0, 63)
	accent.size = Vector2(1280, 1)
	hud_container.add_child(accent)

	lbl_day = _styled_label("DAY 1", font_bold, 24, ACCENT_GOLD)
	lbl_day.position = Vector2(24, 10)
	hud_container.add_child(lbl_day)

	lbl_time = _styled_label("02:00", font_medium, 16, TEXT_DIM)
	lbl_time.position = Vector2(24, 38)
	hud_container.add_child(lbl_time)

	lbl_money = _styled_label("$0", font_semi, 22, TEXT_GREEN)
	lbl_money.position = Vector2(220, 12)
	hud_container.add_child(lbl_money)

	lbl_customers = _styled_label("Served: 0", font_medium, 14, TEXT_DIM)
	lbl_customers.position = Vector2(220, 40)
	hud_container.add_child(lbl_customers)

	var xp_label = _styled_label("LVL", font_semi, 12, ACCENT_GOLD_DIM)
	xp_label.position = Vector2(460, 24)
	hud_container.add_child(xp_label)

	lbl_xp = ProgressBar.new()
	lbl_xp.position = Vector2(494, 22)
	lbl_xp.size = Vector2(140, 20)
	lbl_xp.show_percentage = false
	var xp_bg_style := StyleBoxFlat.new()
	xp_bg_style.bg_color = Color(0.15, 0.15, 0.18, 1)
	xp_bg_style.set_corner_radius_all(3)
	var xp_fill_style := StyleBoxFlat.new()
	xp_fill_style.bg_color = ACCENT_GOLD.darkened(0.2)
	xp_fill_style.set_corner_radius_all(3)
	lbl_xp.add_theme_stylebox_override("background", xp_bg_style)
	lbl_xp.add_theme_stylebox_override("fill", xp_fill_style)
	hud_container.add_child(lbl_xp)

	lbl_contract = _styled_label("", font_semi, 16, TEXT_RED)
	lbl_contract.position = Vector2(700, 20)
	lbl_contract.visible = false
	hud_container.add_child(lbl_contract)

func update_hud():
	if lbl_day:
		lbl_day.text = "DAY " + str(GameManager.day)
	if lbl_time:
		var mins = int(time_remaining / 60)
		var secs = int(time_remaining) % 60
		lbl_time.text = "%02d:%02d" % [mins, secs]
		if time_remaining < 30:
			lbl_time.add_theme_color_override("font_color", TEXT_RED)
		elif time_remaining < 60:
			lbl_time.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
		else:
			lbl_time.add_theme_color_override("font_color", TEXT_DIM)
	if lbl_money:
		lbl_money.text = "$" + str(GameManager.money) + "  (+$" + str(GameManager.daily_earnings) + ")"
	if lbl_customers:
		lbl_customers.text = "Served: " + str(GameManager.customers_served_today)
	if lbl_xp:
		lbl_xp.value = GameManager.get_xp_progress() * 100
	if lbl_contract:
		if GameManager.target_order_received:
			lbl_contract.visible = true
			lbl_contract.text = "CONTRACT AVAILABLE"
		else:
			lbl_contract.visible = false

# ============ CUSTOMER SYSTEM ============

func start_spawning():
	while shift_active:
		await get_tree().create_timer(randf_range(3.0, 8.0)).timeout
		if not shift_active: break

		if active_customers.size() < MAX_CUSTOMERS:
			spawn_customer()

func get_free_slot() -> int:
	for i in range(MAX_CUSTOMERS):
		if not customer_slots_taken[i]:
			return i
	return -1

func spawn_customer():
	if not spawn_point:
		print("No Spawn Point!")
		return

	var slot_index = get_free_slot()
	if slot_index == -1:
		return

	customer_slots_taken[slot_index] = true

	var cust = customer_scene.instantiate()
	var slot_x = SLOT_START_X + (slot_index * SLOT_SPACING)
	cust.position = Vector2(slot_x, CUSTOMER_SLOTS_Y)
	cust.set_meta("slot_index", slot_index)

	var is_first_customer = customers_spawned == 0
	if (is_first_customer or randf() < 0.5) and not GameManager.target_order_received:
		cust.is_secret_agent = true
		cust.set_meta("is_contract", true)
		print("SECRET AGENT SPAWNED!")

	customers_spawned += 1

	cust.customer_left.connect(_on_customer_left)
	cust.order_ready.connect(_on_customer_order)

	add_child(cust)
	active_customers.append(cust)

func _on_customer_left(customer):
	if customer in active_customers:
		active_customers.erase(customer)

		if customer.has_meta("slot_index"):
			var idx = customer.get_meta("slot_index")
			if idx >= 0 and idx < MAX_CUSTOMERS:
				customer_slots_taken[idx] = false

		if customer.satisfaction_score > 0:
			GameManager.add_reputation(customer.satisfaction_score * 10)
			GameManager.customers_served_today += 1
			GameManager.update_quest_progress("serve_customers", 1)

			var xp_reward = customer.satisfaction_score * 5
			GameManager.add_xp(xp_reward)

			var tip = customer.satisfaction_score * 2
			GameManager.add_money(tip)
			GameManager.update_quest_progress("earn_tips", tip)

func _on_customer_order(customer):
	print("Customer ordered: ", customer.order)

	if customer.has_meta("is_contract") and customer.get_meta("is_contract"):
		show_contract_notification(customer)

func show_contract_notification(customer):
	var target_names = ["The Businessman", "The Senator", "The Dealer", "The Kingpin", "The Traitor"]
	var target = target_names.pick_random()
	var reward = randi_range(100, 250)

	GameManager.receive_contract(target, reward)

	var notif = _styled_label("\"The owl flies at midnight...\"\nTarget: " + target,
		font_semi, 20, TEXT_RED)
	notif.position = Vector2(400, 300)
	notif.z_index = 100
	add_child(notif)

	var tween = create_tween()
	tween.tween_property(notif, "modulate:a", 0.0, 3.0)
	tween.tween_callback(notif.queue_free)

# ============ ZONE INTERACTIONS ============

func interact_with_zone(zone_name):
	if zone_name == "counter":
		ui_boba_panel.visible = !ui_boba_panel.visible
		update_mix_label()
	elif zone_name == "upgrade":
		show_upgrade_panel()
	elif zone_name == "mission":
		show_mission_panel()

func setup_zones():
	if has_node("CounterZone"):
		$CounterZone.area_entered.connect(func(area): _set_zone("counter"))
		$CounterZone.area_exited.connect(func(area): _clear_zone())
	if has_node("UpgradeZone"):
		$UpgradeZone.area_entered.connect(func(area): _set_zone("upgrade"))
		$UpgradeZone.area_exited.connect(func(area): _clear_zone())
	if has_node("MissionZone"):
		$MissionZone.area_entered.connect(func(area): _set_zone("mission"))
		$MissionZone.area_exited.connect(func(area): _clear_zone())

func _set_zone(name):
	active_zone = name
	ui_interaction.text = "PRESS 'E' — " + name.to_upper()
	ui_interaction.visible = true

func _clear_zone():
	active_zone = null
	ui_interaction.visible = false
	ui_boba_panel.visible = false
	var upgrade_panel = get_node_or_null("UI_Layer/UpgradePanel")
	if upgrade_panel:
		upgrade_panel.visible = false
	var mission_panel = get_node_or_null("UI_Layer/MissionPanel")
	if mission_panel:
		mission_panel.visible = false

# ============ UPGRADE/WEAPON SHOP ============

func show_upgrade_panel(toggle: bool = true):
	var panel = get_node_or_null("UI_Layer/UpgradePanel")
	if not panel:
		return
	if toggle:
		panel.visible = !panel.visible
	else:
		panel.visible = true

	for child in panel.get_children():
		if child.name != "CloseUpgrade":
			child.queue_free()

	var margin := MarginContainer.new()
	margin.name = "Content"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title = _styled_label("WEAPON SHOP", font_bold, 22, ACCENT_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var level_lbl = _styled_label("Level " + str(GameManager.level), font_medium, 13, TEXT_DIM)
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(level_lbl)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = ACCENT_GOLD_DIM
	vbox.add_child(divider)

	var available_weapons = GameManager.get_available_weapons()

	for weapon_name in available_weapons:
		var weapon_data = GameManager.weapons[weapon_name]
		var owned = weapon_name in GameManager.owned_weapons
		var wn = weapon_name

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vbox.add_child(row)

		var info_col := VBoxContainer.new()
		info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_col.add_theme_constant_override("separation", 0)
		row.add_child(info_col)

		var name_lbl = _styled_label(weapon_name, font_semi, 15, TEXT_WHITE)
		info_col.add_child(name_lbl)

		var stat_lbl = _styled_label("DMG: " + str(weapon_data["damage"]) + "  |  " + weapon_data["type"].to_upper(), font_medium, 11, TEXT_DIM)
		info_col.add_child(stat_lbl)

		var btn := _styled_button("EQUIP" if owned else "$" + str(weapon_data["cost"]), Vector2(90, 36))
		if owned:
			btn.pressed.connect(func(weapon_to_equip = wn): GameManager.equip_weapon(weapon_to_equip))
		else:
			btn.pressed.connect(func(weapon_to_buy = wn):
				if GameManager.buy_weapon(weapon_to_buy):
					show_upgrade_panel(false)
			)
		row.add_child(btn)

# ============ MISSION PANEL ============

func show_mission_panel():
	var panel = get_node_or_null("UI_Layer/MissionPanel")
	if not panel:
		return
	panel.visible = !panel.visible

	for child in panel.get_children():
		if child.name != "CloseMission":
			child.queue_free()

	var margin := MarginContainer.new()
	margin.name = "Content"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

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

	if GameManager.target_order_received and GameManager.current_contract.size() > 0:
		var target_lbl = _styled_label("Target: " + GameManager.current_contract["target"],
			font_semi, 16, TEXT_WHITE)
		vbox.add_child(target_lbl)

		var reward_lbl = _styled_label("Reward: $" + str(GameManager.current_contract["reward"]),
			font_medium, 14, TEXT_GREEN)
		vbox.add_child(reward_lbl)

		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 8)
		vbox.add_child(spacer)

		var btn := _styled_button("START MISSION", Vector2(200, 46))
		btn.pressed.connect(_on_start_mission)
		vbox.add_child(btn)
	else:
		var desc = _styled_label("No contract yet.\nServe customers to receive one,\nor try Free Play.", font_medium, 14, TEXT_DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(desc)

		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 4)
		vbox.add_child(spacer)

		var free_btn := _styled_button("FREE PLAY MISSION", Vector2(220, 46))
		free_btn.pressed.connect(_on_free_play_mission)
		vbox.add_child(free_btn)

func _on_start_mission():
	GameManager.start_mission()
	get_tree().change_scene_to_file("res://Scenes/MissionScene.tscn")

func _on_free_play_mission():
	GameManager.current_contract = {"target": "Practice Target", "reward": 50}
	GameManager.target_order_received = true
	GameManager.start_mission()
	get_tree().change_scene_to_file("res://Scenes/MissionScene.tscn")

# ============ BOBA CRAFTING ============

var lbl_mix: Label

func setup_boba_ui():
	var p = ui_boba_panel
	for c in p.get_children():
		if str(c.name).begins_with("Close"):
			continue
		c.queue_free()

	var margin := MarginContainer.new()
	margin.name = "Content"
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

	lbl_mix = _styled_label("Mix: empty", font_medium, 14, Color(0.5, 0.78, 1.0))
	vbox.add_child(lbl_mix)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(grid)

	for ing in GameManager.unlocked_ingredients:
		var btn := _styled_button("+ " + ing, Vector2(160, 36))
		btn.pressed.connect(_add_to_mix.bind(ing))
		grid.add_child(btn)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(actions)

	var serve_btn := _styled_button("SERVE", Vector2(140, 44))
	serve_btn.pressed.connect(_on_serve_drink)
	actions.add_child(serve_btn)

	var clear_btn := _styled_button("CLEAR", Vector2(140, 44))
	clear_btn.add_theme_color_override("font_color", TEXT_DIM)
	clear_btn.pressed.connect(func():
		current_mix = []
		update_mix_label()
	)
	actions.add_child(clear_btn)

func _add_to_mix(ing):
	if current_mix.size() < 4:
		current_mix.append(ing)
		update_mix_label()

func update_mix_label():
	if lbl_mix:
		lbl_mix.text = "Mix: " + CraftingSystem.get_mix_description(current_mix)

func _on_serve_drink():
	var target_customer = null
	for c in active_customers:
		if c.is_waiting:
			target_customer = c
			break

	if target_customer:
		var created_drink = CraftingSystem.validate_mix(current_mix, target_customer.order)
		var success = target_customer.receive_item(created_drink)

		if success:
			current_mix = []
			update_mix_label()
			ui_boba_panel.visible = false
			GameManager.add_money(10)
			GameManager.add_xp(10)

# ============ DAY END ============

func end_day():
	shift_active = false
	GameManager.end_day()
	show_day_summary()

func show_day_summary():
	var overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	$UI_Layer.add_child(overlay)

	var bg = ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.offset_left = -240
	center.offset_top = -180
	center.offset_right = 240
	center.offset_bottom = 180
	center.add_theme_constant_override("separation", 14)
	overlay.add_child(center)

	var title = _styled_label("DAY " + str(GameManager.day) + " COMPLETE", font_bold, 34, ACCENT_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(title)

	var accent := ColorRect.new()
	accent.custom_minimum_size = Vector2(0, 2)
	accent.color = ACCENT_GOLD_DIM
	center.add_child(accent)

	var earnings = _styled_label("Earnings:  $" + str(GameManager.daily_earnings), font_semi, 22, TEXT_GREEN)
	earnings.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(earnings)

	var customers = _styled_label("Customers Served:  " + str(GameManager.customers_served_today), font_medium, 18, TEXT_WHITE)
	customers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(customers)

	var level = _styled_label("Level " + str(GameManager.level) + "   XP: " + str(GameManager.xp) + "/" + str(GameManager.level * GameManager.XP_PER_LEVEL), font_medium, 16, TEXT_DIM)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(level)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	center.add_child(spacer)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 20)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(btn_row)

	if GameManager.target_order_received:
		var mission_btn := _styled_button("GO ON MISSION", Vector2(180, 50))
		mission_btn.pressed.connect(func():
			GameManager.start_mission()
			get_tree().change_scene_to_file("res://Scenes/MissionScene.tscn")
		)
		btn_row.add_child(mission_btn)

	var continue_btn := _styled_button("NEXT DAY", Vector2(180, 50))
	continue_btn.pressed.connect(func():
		GameManager.start_shop()
		get_tree().reload_current_scene()
	)
	btn_row.add_child(continue_btn)

	overlay.modulate.a = 0.0
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
