extends Node2D

const SHIFT_DURATION: float = 120.0
const MAX_CUSTOMERS: int = 5
const CUSTOMER_SLOTS_Y: float = 350.0
const SLOT_SPACING: float = 120.0
const SLOT_START_X: float = 400.0

const TEX_MILK_ICON := preload("res://Assets/Sprites/MilkIngredientIconDesign.png")
const TEX_SUGAR_ICON := preload("res://Assets/Sprites/SugarIconPicture.png")
const TEX_TAPIOCA_ICON := preload("res://Assets/Sprites/BobaIconpicture.png")
const TEX_BLACK_TEA_ICON := preload("res://Assets/Sprites/BlackTeaIconIngredientDesign.png")

const ACCENT_GOLD := Color(0.91, 0.76, 0.29, 1.0)
const ACCENT_GOLD_DIM := Color(0.91, 0.76, 0.29, 0.4)
const BG_DARK := Color(0.05, 0.05, 0.07, 0.97)
const BG_CARD := Color(0.09, 0.09, 0.11, 0.95)
const TEXT_WHITE := Color(0.93, 0.93, 0.93, 1.0)
const TEXT_DIM := Color(0.5, 0.5, 0.55, 1.0)
const TEXT_GREEN := Color(0.4, 0.88, 0.45, 1.0)
const TEXT_RED := Color(1.0, 0.35, 0.35, 1.0)
const TEXT_BLUE := Color(0.45, 0.72, 1.0, 1.0)
const PANEL_ANIM_SPEED := 0.25

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
var lbl_level: Label
var lbl_contract: Label
var quest_container: VBoxContainer
var time_flash_tween: Tween

var _hotbar_slot1: Panel
var _hotbar_slot2: Panel
var _hotbar_slot3: Panel
var _hotbar_selected_style: StyleBoxFlat
var _hotbar_unselected_style: StyleBoxFlat
var _current_hotbar_idx: int = 1
var _panel_cooldown: float = 0.0

var _cash_register_sfx: AudioStreamPlayer = null
var _error_sfx: AudioStreamPlayer = null

var customer_scene = preload("res://Scenes/Customer.tscn")

func _ready():
	font_bold = load("res://Assets/Fonts/Montserrat-Bold.ttf")
	font_semi = load("res://Assets/Fonts/Montserrat-SemiBold.ttf")
	font_medium = load("res://Assets/Fonts/Montserrat-Medium.ttf")

	GameManager.current_phase = "SHOP"
	time_remaining = SHIFT_DURATION

	setup_hud()
	setup_zones()
	setup_boba_ui()
	setup_close_buttons()
	setup_hotbar()

	_animate_scene_enter()
	start_spawning()
	
	_cash_register_sfx = _make_sfx(preload("res://Assets/Audio/sfx/sfx_cash_register.wav"))
	_error_sfx = _make_sfx(preload("res://Assets/Audio/sfx/sfx_error_sound.wav"))
	_make_sfx(preload("res://Assets/Audio/music/mus_day.wav"), -10.0, &"Music", true)

func _animate_scene_enter():
	if hud_container:
		hud_container.modulate.a = 0.0
		var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.tween_property(hud_container, "modulate:a", 1.0, 0.4)

func setup_close_buttons():
	var close_map = {
		"UI_Layer/BobaPanel/CloseBoba": "UI_Layer/BobaPanel",
		"UI_Layer/UpgradePanel/CloseUpgrade": "UI_Layer/UpgradePanel",
		"UI_Layer/MissionPanel/CloseMission": "UI_Layer/MissionPanel",
		"UI_Layer/AbilityPanel/CloseAbility": "UI_Layer/AbilityPanel",
	}
	for btn_path in close_map:
		var btn = get_node_or_null(btn_path)
		if btn:
			var panel_path = close_map[btn_path]
			btn.pressed.connect(func(p = panel_path):
				var panel = get_node_or_null(p)
				if panel: _close_panel(panel)
			)

func _process(delta):
	if _panel_cooldown > 0.0:
		_panel_cooldown -= delta

	if shift_active:
		time_remaining -= delta
		update_hud()
		if time_remaining <= 0:
			end_day()

	if ui_boba_panel.visible:
		_update_order_display()

	if active_zone and Input.is_action_just_pressed("interact"):
		if _panel_cooldown <= 0.0:
			interact_with_zone(active_zone)

	if Input.is_action_just_pressed("pause"):
		_close_all_panels()

	for i in range(1, 4):
		if Input.is_action_just_pressed("weapon_" + str(i)):
			_select_hotbar_slot(i)
			break


func _make_sfx(stream: AudioStream, volume: float = 0.0, bus: StringName = &"SFX", autoplay: bool = false) -> AudioStreamPlayer:
	var sfx = AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.volume_db = volume
	sfx.bus = bus
	sfx.autoplay = autoplay
	add_child(sfx)
	return sfx

func _make_panel_style(bg: Color = BG_DARK, border: Color = ACCENT_GOLD_DIM, radius: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	return s

func _make_card_style(border_col: Color = ACCENT_GOLD_DIM) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.07, 0.07, 0.09, 0.9)
	s.border_color = border_col
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.content_margin_left = 12
	s.content_margin_top = 10
	s.content_margin_right = 12
	s.content_margin_bottom = 10
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
	btn.add_theme_stylebox_override("normal", _make_panel_style(
		Color(0.12, 0.12, 0.15, 0.9), ACCENT_GOLD_DIM, 6))
	btn.add_theme_stylebox_override("hover", _make_panel_style(
		Color(0.16, 0.15, 0.11, 0.95), Color(0.91, 0.76, 0.29, 0.6), 6))
	btn.add_theme_stylebox_override("pressed", _make_panel_style(
		Color(0.1, 0.1, 0.12, 1.0), ACCENT_GOLD, 6))
	return btn

func _make_divider(color: Color = ACCENT_GOLD_DIM) -> ColorRect:
	var d := ColorRect.new()
	d.custom_minimum_size = Vector2(0, 1)
	d.color = color
	return d

func _make_spacer(height: float = 8.0) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	return s


func _open_panel(panel: Control):
	_panel_cooldown = PANEL_ANIM_SPEED + 0.1
	panel.visible = true
	panel.scale = Vector2(0.92, 0.92)
	panel.modulate.a = 0.0
	panel.pivot_offset = panel.size / 2.0
	if quest_container:
		quest_container.visible = false
	var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.set_parallel(true)
	t.tween_property(panel, "scale", Vector2.ONE, PANEL_ANIM_SPEED)
	t.tween_property(panel, "modulate:a", 1.0, PANEL_ANIM_SPEED * 0.6)

func _close_panel(panel: Control):
	_panel_cooldown = PANEL_ANIM_SPEED + 0.1
	var t = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	t.set_parallel(true)
	t.tween_property(panel, "scale", Vector2(0.95, 0.95), PANEL_ANIM_SPEED * 0.6)
	t.tween_property(panel, "modulate:a", 0.0, PANEL_ANIM_SPEED * 0.5)
	var qc = quest_container
	t.chain().tween_callback(func():
		panel.visible = false
		panel.modulate.a = 1.0
		panel.scale = Vector2.ONE
		if qc:
			qc.visible = true
	)

func _is_any_panel_open() -> bool:
	for path in ["UI_Layer/BobaPanel", "UI_Layer/UpgradePanel", "UI_Layer/MissionPanel", "UI_Layer/AbilityPanel"]:
		var p = get_node_or_null(path)
		if p and p.visible:
			return true
	return false


func setup_hotbar() -> void:
	var hotbar = get_node_or_null("UI_Layer/Hotbar")
	if not hotbar:
		return

	_hotbar_slot1 = hotbar.get_node_or_null("HBox/Slot1")
	_hotbar_slot2 = hotbar.get_node_or_null("HBox/Slot2")
	_hotbar_slot3 = hotbar.get_node_or_null("HBox/Slot3")

	_hotbar_selected_style = StyleBoxFlat.new()
	_hotbar_selected_style.bg_color = Color(0.14, 0.14, 0.17, 0.6)
	_hotbar_selected_style.border_color = ACCENT_GOLD_DIM
	_hotbar_selected_style.set_border_width_all(1)
	_hotbar_selected_style.set_corner_radius_all(5)

	_hotbar_unselected_style = StyleBoxFlat.new()
	_hotbar_unselected_style.bg_color = Color(0.1, 0.1, 0.12, 0.5)
	_hotbar_unselected_style.set_corner_radius_all(5)

	_refresh_all_hotbar_labels()
	_select_hotbar_slot(1)

func _select_hotbar_slot(idx: int) -> void:
	_current_hotbar_idx = idx
	var slots = [_hotbar_slot1, _hotbar_slot2, _hotbar_slot3]
	for i in range(slots.size()):
		if slots[i]:
			slots[i].add_theme_stylebox_override("panel",
				_hotbar_selected_style if i + 1 == idx else _hotbar_unselected_style)

func _set_hotbar_label(slot: Panel, text: String) -> void:
	if not slot: return
	var label = slot.get_node_or_null("Label")
	if label: label.text = text

func _refresh_all_hotbar_labels() -> void:
	var equipped = [GameManager.equipped_main, GameManager.equipped_melee, GameManager.equipped_special]
	var slots = [_hotbar_slot1, _hotbar_slot2, _hotbar_slot3]
	for i in range(slots.size()):
		_set_hotbar_label(slots[i], str(i + 1) + ": " + equipped[i])

func refresh_hotbar_labels() -> void:
	_refresh_all_hotbar_labels()


func setup_hud():
	hud_container = Control.new()
	hud_container.name = "HUD"
	hud_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI_Layer.add_child(hud_container)

	var bg = Panel.new()
	bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bg.offset_bottom = 72
	var hud_style := StyleBoxFlat.new()
	hud_style.bg_color = Color(0.04, 0.04, 0.06, 0.94)
	hud_style.border_width_bottom = 1
	hud_style.border_color = ACCENT_GOLD_DIM
	hud_style.shadow_color = Color(0, 0, 0, 0.3)
	hud_style.shadow_size = 4
	bg.add_theme_stylebox_override("panel", hud_style)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_container.add_child(bg)


	var left_col := VBoxContainer.new()
	left_col.position = Vector2(20, 8)
	left_col.add_theme_constant_override("separation", 0)
	left_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_container.add_child(left_col)

	lbl_day = _styled_label("DAY 1", font_bold, 22, ACCENT_GOLD)
	left_col.add_child(lbl_day)

	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 6)
	left_col.add_child(time_row)

	var clock_icon = _styled_label("⏱", font_medium, 14, TEXT_DIM)
	time_row.add_child(clock_icon)

	lbl_time = _styled_label("02:00", font_bold, 18, TEXT_WHITE)
	time_row.add_child(lbl_time)


	var sep1 := ColorRect.new()
	sep1.color = Color(0.3, 0.3, 0.35, 0.4)
	sep1.position = Vector2(140, 12)
	sep1.size = Vector2(1, 48)
	hud_container.add_child(sep1)


	var money_col := VBoxContainer.new()
	money_col.position = Vector2(160, 8)
	money_col.add_theme_constant_override("separation", 0)
	money_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_container.add_child(money_col)

	lbl_money = _styled_label("$0", font_bold, 22, TEXT_GREEN)
	money_col.add_child(lbl_money)

	lbl_customers = _styled_label("0 served", font_semi, 15, TEXT_WHITE)
	money_col.add_child(lbl_customers)

	var sep2 := ColorRect.new()
	sep2.color = Color(0.3, 0.3, 0.35, 0.4)
	sep2.position = Vector2(340, 12)
	sep2.size = Vector2(1, 48)
	hud_container.add_child(sep2)


	var xp_col := VBoxContainer.new()
	xp_col.position = Vector2(360, 10)
	xp_col.add_theme_constant_override("separation", 4)
	xp_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_container.add_child(xp_col)

	var xp_header := HBoxContainer.new()
	xp_header.add_theme_constant_override("separation", 6)
	xp_col.add_child(xp_header)

	lbl_level = _styled_label("LVL 1", font_semi, 13, ACCENT_GOLD)
	xp_header.add_child(lbl_level)

	lbl_xp = ProgressBar.new()
	lbl_xp.custom_minimum_size = Vector2(160, 16)
	lbl_xp.show_percentage = false
	var xp_bg := StyleBoxFlat.new()
	xp_bg.bg_color = Color(0.12, 0.12, 0.15, 1)
	xp_bg.set_corner_radius_all(4)
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = ACCENT_GOLD.darkened(0.15)
	xp_fill.set_corner_radius_all(4)
	lbl_xp.add_theme_stylebox_override("background", xp_bg)
	lbl_xp.add_theme_stylebox_override("fill", xp_fill)
	xp_col.add_child(lbl_xp)


	lbl_contract = _styled_label("", font_bold, 16, Color(1.0, 0.7, 0.3, 1.0))
	lbl_contract.position = Vector2(0, 0)
	lbl_contract.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lbl_contract.offset_left = -220.0
	lbl_contract.offset_top = 14.0
	lbl_contract.offset_right = -20.0
	lbl_contract.offset_bottom = 58.0
	lbl_contract.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_contract.visible = false
	hud_container.add_child(lbl_contract)


	quest_container = VBoxContainer.new()
	quest_container.name = "QuestTracker"
	quest_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	quest_container.offset_left = -360.0
	quest_container.offset_top = 80.0
	quest_container.offset_right = -12.0
	quest_container.offset_bottom = 360.0
	quest_container.add_theme_constant_override("separation", 6)
	quest_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI_Layer.add_child(quest_container)
	_build_quest_tracker()

func _build_quest_tracker():
	for c in quest_container.get_children():
		c.queue_free()

	var header = _styled_label("DAILY QUESTS", font_bold, 15, ACCENT_GOLD)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_container.add_child(header)

	for quest in GameManager.daily_quests:
		var progress = GameManager.quest_progress.get(quest["id"], 0)
		var completed = quest.get("completed", false)
		var target = quest["target"]
		var color = TEXT_GREEN if completed else TEXT_WHITE


		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quest_container.add_child(row)

		var check = _styled_label("✓" if completed else "○", font_bold, 16, color)
		check.custom_minimum_size = Vector2(20, 0)
		check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(check)

		var desc = _styled_label(quest["desc"], font_semi, 14, color)
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		desc.clip_text = false
		row.add_child(desc)

		var prog_text: String
		var prog_color: Color
		if completed:
			prog_text = "DONE"
			prog_color = TEXT_GREEN
		else:
			prog_text = "%d/%d" % [mini(progress, target), target]
			prog_color = TEXT_DIM.lerp(TEXT_GREEN, float(progress) / float(target))
		var prog_lbl = _styled_label(prog_text, font_bold, 13, prog_color)
		prog_lbl.custom_minimum_size = Vector2(56, 0)
		prog_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(prog_lbl)

func update_hud():
	if lbl_day:
		lbl_day.text = "DAY " + str(GameManager.day)

	if lbl_time:
		var mins = int(time_remaining / 60)
		var secs = int(time_remaining) % 60
		lbl_time.text = "%02d:%02d" % [mins, secs]
		if time_remaining < 30:
			lbl_time.add_theme_color_override("font_color", TEXT_RED)
			if time_flash_tween == null or not time_flash_tween.is_running():
				time_flash_tween = create_tween().set_loops()
				time_flash_tween.tween_property(lbl_time, "modulate:a", 0.4, 0.5)
				time_flash_tween.tween_property(lbl_time, "modulate:a", 1.0, 0.5)
		elif time_remaining < 60:
			lbl_time.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
			_stop_time_flash()
		else:
			lbl_time.add_theme_color_override("font_color", TEXT_DIM)
			_stop_time_flash()

	if lbl_money:
		lbl_money.text = "$" + str(GameManager.money)

	if lbl_customers:
		var served = GameManager.customers_served_today
		lbl_customers.text = str(served) + " served" + ("  (+$" + str(GameManager.daily_earnings) + ")" if GameManager.daily_earnings > 0 else "")

	if lbl_level:
		lbl_level.text = "LVL " + str(GameManager.level)

	if lbl_xp:
		lbl_xp.value = GameManager.get_xp_progress() * 100

	if lbl_contract:
		if GameManager.target_order_received:
			lbl_contract.visible = true
			lbl_contract.text = "CONTRACT READY"
		else:
			lbl_contract.visible = false

	if quest_container and Engine.get_frames_drawn() % 60 == 0:
		_build_quest_tracker()

func _stop_time_flash():
	if time_flash_tween and time_flash_tween.is_running():
		time_flash_tween.kill()
		time_flash_tween = null
		lbl_time.modulate.a = 1.0


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
	if not spawn_point: return

	var slot_index = get_free_slot()
	if slot_index == -1: return

	customer_slots_taken[slot_index] = true

	var cust = customer_scene.instantiate()
	var slot_x = SLOT_START_X + (slot_index * SLOT_SPACING)
	cust.position = Vector2(slot_x, CUSTOMER_SLOTS_Y)
	cust.set_meta("slot_index", slot_index)

	var is_first_customer = customers_spawned == 0
	if (is_first_customer or randf() < 0.5) and not GameManager.target_order_received:
		cust.is_secret_agent = true
		cust.set_meta("is_contract", true)

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

			_show_floating_text("+$" + str(tip), TEXT_GREEN, customer.global_position)

func _on_customer_order(customer):
	if customer.has_meta("is_contract") and customer.get_meta("is_contract"):
		show_contract_notification(customer)

func _show_floating_text(text: String, color: Color, pos: Vector2):
	var lbl = _styled_label(text, font_bold, 18, color)
	lbl.position = pos - Vector2(30, 40)
	lbl.z_index = 100
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("outline_size", 4)
	add_child(lbl)

	var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.set_parallel(true)
	t.tween_property(lbl, "position:y", lbl.position.y - 50, 1.2)
	t.tween_property(lbl, "modulate:a", 0.0, 1.2).set_delay(0.4)
	t.chain().tween_callback(lbl.queue_free)

func show_contract_notification(customer):
	var target_names = ["The Businessman", "The Senator", "The Dealer", "The Kingpin", "The Traitor"]
	var target = target_names.pick_random()
	var reward = randi_range(100, 250)
	GameManager.receive_contract(target, reward)

	var toast := PanelContainer.new()
	toast.set_anchors_preset(Control.PRESET_TOP_LEFT)
	toast.offset_left = 16.0
	toast.offset_top = 80.0
	toast.offset_right = 280.0
	toast.offset_bottom = 140.0
	toast.add_theme_stylebox_override("panel", _make_panel_style(
		Color(0.08, 0.06, 0.06, 0.92), Color(0.7, 0.35, 0.35, 0.35), 6))
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI_Layer.add_child(toast)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	toast.add_child(hbox)

	var icon_lbl = _styled_label("!", font_bold, 16, Color(1.0, 0.4, 0.4, 0.8))
	hbox.add_child(icon_lbl)

	var text_col := VBoxContainer.new()
	text_col.add_theme_constant_override("separation", 1)
	hbox.add_child(text_col)

	var title_lbl = _styled_label("Contract Available", font_semi, 13, Color(0.9, 0.7, 0.6))
	text_col.add_child(title_lbl)

	var detail_lbl = _styled_label(target + "  ·  $" + str(reward), font_medium, 11, TEXT_DIM)
	text_col.add_child(detail_lbl)

	toast.modulate.a = 0.0
	var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(toast, "modulate:a", 1.0, 0.3)
	t.tween_interval(3.0)
	t.tween_property(toast, "modulate:a", 0.0, 0.6)
	t.tween_callback(toast.queue_free)


func interact_with_zone(zone_name):
	if _is_any_panel_open():
		_close_all_panels()
		_panel_cooldown = PANEL_ANIM_SPEED + 0.1
		return

	if zone_name == "counter":
		_open_panel(ui_boba_panel)
		update_mix_label()
	elif zone_name == "upgrade":
		show_upgrade_panel()
	elif zone_name == "mission":
		show_mission_panel()
	elif zone_name == "ability":
		show_ability_panel()

func setup_zones():
	var zone_map = {"CounterZone": "counter", "UpgradeZone": "upgrade", "MissionZone": "mission", "AbilityZone": "ability"}
	for node_name in zone_map:
		if has_node(node_name):
			var zone_name = zone_map[node_name]
			get_node(node_name).area_entered.connect(func(area, z = zone_name): _set_zone(z))
			get_node(node_name).area_exited.connect(func(area): _clear_zone())

func _set_zone(zone_name: String):
	active_zone = zone_name
	var zone_labels = {"counter": "BOBA COUNTER", "upgrade": "WEAPON SHOP", "mission": "CONTRACTS", "ability": "ABILITY SHOP"}
	ui_interaction.text = "[E]  " + zone_labels.get(zone_name, zone_name.to_upper())
	ui_interaction.visible = true

	var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	ui_interaction.modulate.a = 0.0
	t.tween_property(ui_interaction, "modulate:a", 1.0, 0.2)

func _clear_zone():
	active_zone = null
	var t = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(ui_interaction, "modulate:a", 0.0, 0.15)
	t.tween_callback(func(): ui_interaction.visible = false)
	_close_all_panels()

func _close_all_panels():
	for path in ["UI_Layer/BobaPanel", "UI_Layer/UpgradePanel", "UI_Layer/MissionPanel", "UI_Layer/AbilityPanel"]:
		_reset_panel(get_node_or_null(path))
	if quest_container:
		quest_container.visible = true

func _reset_panel(panel: Control):
	if not panel: return
	panel.visible = false
	panel.modulate.a = 1.0
	panel.scale = Vector2.ONE


func show_upgrade_panel(animate: bool = true):
	var panel = get_node_or_null("UI_Layer/UpgradePanel")
	if not panel: return

	var prev_scroll: int = 0
	if not animate:
		var old_scroll := panel.find_child("WeaponScroll", true, false) as ScrollContainer
		if old_scroll:
			prev_scroll = old_scroll.scroll_vertical

	for child in panel.get_children():
		if child.name != "CloseUpgrade":
			child.queue_free()

	var margin := MarginContainer.new()
	margin.name = "Content"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var close_btn = panel.get_node_or_null("CloseUpgrade")
	if close_btn: panel.move_child(close_btn, -1)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(outer_vbox)


	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	outer_vbox.add_child(header_row)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 2)
	header_row.add_child(title_col)

	var title = _styled_label("WEAPON SHOP", font_bold, 22, ACCENT_GOLD)
	title_col.add_child(title)

	var level_lbl = _styled_label("Level " + str(GameManager.level) + "  ·  $" + str(GameManager.money) + " available", font_medium, 12, TEXT_DIM)
	title_col.add_child(level_lbl)

	outer_vbox.add_child(_make_divider())


	var scroll := ScrollContainer.new()
	scroll.name = "WeaponScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(scroll)

	var weapon_list := VBoxContainer.new()
	weapon_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_list.add_theme_constant_override("separation", 8)
	scroll.add_child(weapon_list)

	var available_weapons = GameManager.get_available_weapons()

	for weapon_name in available_weapons:
		var weapon_data = GameManager.weapons[weapon_name]
		var owned = weapon_name in GameManager.owned_weapons
		var wn = weapon_name

		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _make_card_style(
			ACCENT_GOLD_DIM if not owned else Color(0.91, 0.76, 0.29, 0.2)))
		weapon_list.add_child(card)

		var card_hbox := HBoxContainer.new()
		card_hbox.add_theme_constant_override("separation", 10)
		card.add_child(card_hbox)

		var info_col := VBoxContainer.new()
		info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_col.add_theme_constant_override("separation", 2)
		card_hbox.add_child(info_col)

		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 8)
		info_col.add_child(name_row)

		var name_lbl = _styled_label(weapon_name, font_semi, 15, TEXT_WHITE)
		name_row.add_child(name_lbl)

		if owned:
			var owned_badge = _styled_label("OWNED", font_medium, 9, TEXT_GREEN)
			name_row.add_child(owned_badge)

		var type_colors = {"ranged": TEXT_BLUE, "melee": Color(1, 0.7, 0.3), "special": Color(0.8, 0.5, 1.0)}
		var type_col = type_colors.get(weapon_data["type"], TEXT_DIM)

		var stat_parts = []
		stat_parts.append("DMG " + str(weapon_data["damage"]))
		stat_parts.append(weapon_data["type"].to_upper())
		var poison_data = weapon_data.get("tuning", {})
		if poison_data.get("poison_ticks", 0) > 0:
			stat_parts.append("POISON")
		var stat_lbl = _styled_label("  ·  ".join(stat_parts), font_medium, 11, type_col)
		info_col.add_child(stat_lbl)

		var equipped_in = _get_equipped_slot_name(wn)
		if equipped_in != "":
			var eq_lbl = _styled_label("▸ " + equipped_in, font_medium, 10, ACCENT_GOLD_DIM)
			info_col.add_child(eq_lbl)

		if not owned:
			var can_afford = GameManager.money >= weapon_data["cost"]
			var btn := _styled_button("$" + str(weapon_data["cost"]), Vector2(90, 38))
			if not can_afford:
				btn.add_theme_color_override("font_color", TEXT_RED)
				btn.add_theme_stylebox_override("normal", _make_panel_style(
					Color(0.12, 0.08, 0.08, 0.9), Color(1, 0.3, 0.3, 0.3), 6))
			btn.pressed.connect(func(weapon_to_buy = wn):
				if GameManager.buy_weapon(weapon_to_buy):
					if _cash_register_sfx:
						_cash_register_sfx.play()
					show_upgrade_panel(false)
				else:
					if _error_sfx:
						_error_sfx.play()
			)
			card_hbox.add_child(btn)
		else:
			var slot_col := VBoxContainer.new()
			slot_col.add_theme_constant_override("separation", 4)
			card_hbox.add_child(slot_col)

			var slot_label = _styled_label("EQUIP", font_semi, 9, TEXT_DIM)
			slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			slot_col.add_child(slot_label)

			var slot_row := HBoxContainer.new()
			slot_row.add_theme_constant_override("separation", 4)
			slot_col.add_child(slot_row)

			for slot_info in [["1", "main"], ["2", "melee"], ["3", "special"]]:
				var slot_btn := _styled_button(slot_info[0], Vector2(36, 30))
				slot_btn.add_theme_font_size_override("font_size", 12)
				var is_equipped = false
				match slot_info[1]:
					"main": is_equipped = GameManager.equipped_main == wn
					"melee": is_equipped = GameManager.equipped_melee == wn
					"special": is_equipped = GameManager.equipped_special == wn
				if is_equipped:
					_style_active_slot_button(slot_btn)
				var slot_name = slot_info[1]
				slot_btn.pressed.connect(func(w = wn, s = slot_name):
					_equip_to_slot(w, s)
					show_upgrade_panel(false)
				)
				slot_row.add_child(slot_btn)

	if animate:
		_open_panel(panel)
	else:
		panel.visible = true
		panel.modulate.a = 1.0
		panel.scale = Vector2.ONE

	if prev_scroll > 0:
		scroll.set_deferred("scroll_vertical", prev_scroll)

func _equip_to_slot(weapon_name: String, slot: String) -> void:
	if weapon_name not in GameManager.owned_weapons: return
	match slot:
		"main": GameManager.equipped_main = weapon_name
		"melee": GameManager.equipped_melee = weapon_name
		"special": GameManager.equipped_special = weapon_name
	refresh_hotbar_labels()

func _get_equipped_slot_name(weapon_name: String) -> String:
	var slots := []
	if GameManager.equipped_main == weapon_name: slots.append("Slot 1")
	if GameManager.equipped_melee == weapon_name: slots.append("Slot 2")
	if GameManager.equipped_special == weapon_name: slots.append("Slot 3")
	return ", ".join(slots)

func _style_active_slot_button(btn: Button) -> void:
	btn.add_theme_color_override("font_color", ACCENT_GOLD)
	btn.add_theme_stylebox_override("normal", _make_panel_style(
		Color(0.18, 0.16, 0.08, 0.95), ACCENT_GOLD, 6))


func _ability_color(data: Dictionary) -> Color:
	var raw = data.get("color", ACCENT_GOLD_DIM)
	if raw is Color:
		return raw
	return ACCENT_GOLD_DIM

func show_ability_panel(animate: bool = true):
	var panel = get_node_or_null("UI_Layer/AbilityPanel")
	if not panel:
		push_warning("AbilityPanel not found in scene tree")
		return

	var prev_scroll: int = 0
	if not animate:
		var old_scroll := panel.find_child("AbilityScroll", true, false) as ScrollContainer
		if old_scroll:
			prev_scroll = old_scroll.scroll_vertical

	for child in panel.get_children():
		if child.name != "CloseAbility":
			child.queue_free()

	var margin := MarginContainer.new()
	margin.name = "Content"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var close_btn = panel.get_node_or_null("CloseAbility")
	if close_btn: panel.move_child(close_btn, -1)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(outer_vbox)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	outer_vbox.add_child(header_row)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 2)
	header_row.add_child(title_col)

	var title = _styled_label("ABILITY SHOP", font_bold, 22, Color(0.85, 0.6, 1.0))
	title_col.add_child(title)

	var level_lbl = _styled_label("Level " + str(GameManager.level) + "  ·  $" + str(GameManager.money) + " available", font_medium, 12, TEXT_DIM)
	title_col.add_child(level_lbl)

	outer_vbox.add_child(_make_divider())

	var scroll := ScrollContainer.new()
	scroll.name = "AbilityScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	list.add_child(_styled_label("ACTIVE ABILITIES", font_semi, 11, ACCENT_GOLD_DIM))

	var ability_names: Array = GameManager.active_abilities.keys()
	ability_names.sort_custom(func(a, b):
		return int(GameManager.active_abilities[a].get("unlock_level", 1)) < int(GameManager.active_abilities[b].get("unlock_level", 1)))
	for ability_name in ability_names:
		list.add_child(_build_ability_card(ability_name))

	list.add_child(_make_spacer(6))
	list.add_child(_make_divider())
	list.add_child(_styled_label("PASSIVE UPGRADES", font_semi, 11, ACCENT_GOLD_DIM))

	var passive_names: Array = GameManager.passive_upgrades.keys()
	passive_names.sort_custom(func(a, b):
		return int(GameManager.passive_upgrades[a].get("unlock_level", 1)) < int(GameManager.passive_upgrades[b].get("unlock_level", 1)))
	for passive_name in passive_names:
		list.add_child(_build_passive_card(passive_name))

	if animate:
		_open_panel(panel)
	else:
		panel.visible = true
		panel.modulate.a = 1.0
		panel.scale = Vector2.ONE

	if prev_scroll > 0:
		scroll.set_deferred("scroll_vertical", prev_scroll)

func _build_ability_card(ability_name: String) -> PanelContainer:
	var data: Dictionary = GameManager.active_abilities.get(ability_name, {})
	var owned: bool = ability_name in GameManager.owned_active_abilities
	var equipped: bool = GameManager.active_ability == ability_name
	var unlock_level: int = int(data.get("unlock_level", 1))
	var unlocked: bool = GameManager.level >= unlock_level
	var col: Color = _ability_color(data)

	var border_col: Color = ACCENT_GOLD_DIM
	if owned:
		border_col = Color(col.r, col.g, col.b, 0.35)
	elif not unlocked:
		border_col = Color(0.35, 0.35, 0.38, 0.35)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _make_card_style(border_col))
	if not unlocked:
		card.modulate = Color(1, 1, 1, 0.55)

	var card_hbox := HBoxContainer.new()
	card_hbox.add_theme_constant_override("separation", 10)
	card.add_child(card_hbox)

	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 2)
	card_hbox.add_child(info_col)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	info_col.add_child(name_row)

	var name_color: Color = TEXT_DIM if not unlocked else TEXT_WHITE
	name_row.add_child(_styled_label(ability_name, font_semi, 15, name_color))

	if not unlocked:
		name_row.add_child(_styled_label("LOCKED", font_medium, 9, TEXT_DIM))
	elif equipped:
		name_row.add_child(_styled_label("EQUIPPED", font_medium, 9, ACCENT_GOLD))
	elif owned:
		name_row.add_child(_styled_label("OWNED", font_medium, 9, TEXT_GREEN))

	var desc_color: Color = TEXT_DIM if not unlocked else col
	var desc_lbl = _styled_label(str(data.get("desc", "")), font_medium, 11, desc_color)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.custom_minimum_size = Vector2(340, 0)
	info_col.add_child(desc_lbl)

	var cooldown_val: float = float(data.get("cooldown", 0.0))
	info_col.add_child(_styled_label("Cooldown " + str(cooldown_val) + "s", font_medium, 10, TEXT_DIM))

	var an = ability_name
	if not unlocked:
		var lock_lbl := _styled_label("Lv " + str(unlock_level), font_semi, 12, TEXT_DIM)
		lock_lbl.custom_minimum_size = Vector2(90, 38)
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card_hbox.add_child(lock_lbl)
	elif not owned:
		var cost_val := int(data.get("cost", 0))
		var can_afford: bool = GameManager.money >= cost_val
		var label_text: String = "FREE" if cost_val == 0 else "$" + str(cost_val)
		var btn := _styled_button(label_text, Vector2(90, 38))
		if cost_val > 0 and not can_afford:
			btn.add_theme_color_override("font_color", TEXT_RED)
			btn.add_theme_stylebox_override("normal", _make_panel_style(
				Color(0.12, 0.08, 0.08, 0.9), Color(1, 0.3, 0.3, 0.3), 6))
		btn.pressed.connect(func(a = an):
			if GameManager.buy_ability(a):
				if _cash_register_sfx:
					_cash_register_sfx.play()
				show_ability_panel(false)
			else:
				if _error_sfx:
					_error_sfx.play()
		)
		card_hbox.add_child(btn)
	elif not equipped:
		var btn := _styled_button("EQUIP", Vector2(90, 38))
		btn.pressed.connect(func(a = an):
			GameManager.equip_ability(a)
			show_ability_panel(false)
		)
		card_hbox.add_child(btn)
	else:
		var active_lbl := _styled_label("ACTIVE", font_semi, 11, ACCENT_GOLD)
		active_lbl.custom_minimum_size = Vector2(90, 38)
		active_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		active_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card_hbox.add_child(active_lbl)

	return card

func _build_passive_card(passive_name: String) -> PanelContainer:
	var data: Dictionary = GameManager.passive_upgrades.get(passive_name, {})
	var tier: int = int(GameManager.passive_tiers.get(passive_name, 0))
	var max_tier: int = int(data.get("max_tier", 3))
	var unlock_level: int = int(data.get("unlock_level", 1))
	var unlocked: bool = GameManager.level >= unlock_level
	var col: Color = _ability_color(data)
	var maxed: bool = tier >= max_tier

	var border_col: Color = ACCENT_GOLD_DIM
	if tier > 0:
		border_col = Color(col.r, col.g, col.b, 0.35)
	elif not unlocked:
		border_col = Color(0.35, 0.35, 0.38, 0.35)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _make_card_style(border_col))
	if not unlocked:
		card.modulate = Color(1, 1, 1, 0.55)

	var card_hbox := HBoxContainer.new()
	card_hbox.add_theme_constant_override("separation", 10)
	card.add_child(card_hbox)

	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 2)
	card_hbox.add_child(info_col)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	info_col.add_child(name_row)

	var name_color: Color = TEXT_DIM if not unlocked else TEXT_WHITE
	name_row.add_child(_styled_label(passive_name, font_semi, 15, name_color))

	if not unlocked:
		name_row.add_child(_styled_label("LOCKED", font_medium, 9, TEXT_DIM))
	else:
		name_row.add_child(_styled_label("TIER %d/%d" % [tier, max_tier], font_medium, 9,
			ACCENT_GOLD if tier > 0 else TEXT_DIM))

	var desc_color: Color = TEXT_DIM if not unlocked else col
	var desc_text: String = str(data.get("desc", "")) + " (" + str(data.get("per_tier", "")) + ")"
	var desc_lbl = _styled_label(desc_text, font_medium, 11, desc_color)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.custom_minimum_size = Vector2(340, 0)
	info_col.add_child(desc_lbl)

	var pn = passive_name
	if not unlocked:
		var lock_lbl := _styled_label("Lv " + str(unlock_level), font_semi, 12, TEXT_DIM)
		lock_lbl.custom_minimum_size = Vector2(90, 38)
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card_hbox.add_child(lock_lbl)
	elif maxed:
		var maxed_lbl := _styled_label("MAXED", font_semi, 11, TEXT_GREEN)
		maxed_lbl.custom_minimum_size = Vector2(90, 38)
		maxed_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		maxed_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card_hbox.add_child(maxed_lbl)
	else:
		var cost_val: int = GameManager.get_passive_next_cost(passive_name)
		var can_afford: bool = GameManager.money >= cost_val
		var btn := _styled_button("$" + str(cost_val), Vector2(90, 38))
		if not can_afford:
			btn.add_theme_color_override("font_color", TEXT_RED)
			btn.add_theme_stylebox_override("normal", _make_panel_style(
				Color(0.12, 0.08, 0.08, 0.9), Color(1, 0.3, 0.3, 0.3), 6))
		btn.pressed.connect(func(p = pn):
			if GameManager.upgrade_passive(p):
				if _cash_register_sfx:
					_cash_register_sfx.play()
				show_ability_panel(false)
			else:
				if _error_sfx:
					_error_sfx.play()
		)
		card_hbox.add_child(btn)

	return card


func show_mission_panel():
	var panel = get_node_or_null("UI_Layer/MissionPanel")
	if not panel: return

	for child in panel.get_children():
		if child.name != "CloseMission":
			child.queue_free()

	var margin := MarginContainer.new()
	margin.name = "Content"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var close_btn = panel.get_node_or_null("CloseMission")
	if close_btn: panel.move_child(close_btn, -1)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(outer_vbox)

	var title = _styled_label("CONTRACTS", font_bold, 22, ACCENT_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(title)

	outer_vbox.add_child(_make_divider())


	if GameManager.target_order_received and GameManager.current_contract.size() > 0:
		var contract_card := PanelContainer.new()
		contract_card.add_theme_stylebox_override("panel", _make_card_style(Color(1.0, 0.3, 0.3, 0.25)))
		outer_vbox.add_child(contract_card)

		var card_hbox := HBoxContainer.new()
		card_hbox.add_theme_constant_override("separation", 8)
		contract_card.add_child(card_hbox)

		var info_col := VBoxContainer.new()
		info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_col.add_theme_constant_override("separation", 2)
		card_hbox.add_child(info_col)

		info_col.add_child(_styled_label("ACTIVE CONTRACT", font_semi, 10, TEXT_RED))
		info_col.add_child(_styled_label(GameManager.current_contract["target"], font_bold, 15, TEXT_WHITE))
		info_col.add_child(_styled_label("Reward: $" + str(GameManager.current_contract["reward"]), font_medium, 11, TEXT_GREEN))

		var go_btn := _styled_button("GO", Vector2(70, 36))
		go_btn.add_theme_font_size_override("font_size", 13)
		go_btn.add_theme_stylebox_override("normal", _make_panel_style(
			Color(0.14, 0.08, 0.08, 0.95), Color(1.0, 0.35, 0.35, 0.5), 6))
		go_btn.add_theme_stylebox_override("hover", _make_panel_style(
			Color(0.2, 0.1, 0.1, 0.95), Color(1.0, 0.35, 0.35, 0.8), 6))
		go_btn.add_theme_color_override("font_color", TEXT_RED)
		go_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.5, 0.5))
		go_btn.pressed.connect(_on_start_contract_mission)
		card_hbox.add_child(go_btn)


	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(scroll)

	var mission_list := VBoxContainer.new()
	mission_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mission_list.add_theme_constant_override("separation", 6)
	scroll.add_child(mission_list)

	var missions = GameManager.get_available_missions()
	if missions.is_empty():
		var empty_lbl = _styled_label("No missions available yet.\nServe customers to unlock contracts.", font_medium, 13, TEXT_DIM)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mission_list.add_child(empty_lbl)
	else:
		for m in missions:
			_build_mission_card(mission_list, m)

	_open_panel(panel)

func _build_mission_card(parent: VBoxContainer, m: Dictionary):
	var tier: int = m.get("tier", 1)
	var mtype: String = m.get("type", "extermination")
	var label_text: String = m.get("label", mtype.capitalize())
	var card_color: Color = m.get("color", ACCENT_GOLD_DIM)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _make_card_style(card_color.lerp(Color.TRANSPARENT, 0.6)))
	parent.add_child(card)

	var card_hbox := HBoxContainer.new()
	card_hbox.add_theme_constant_override("separation", 8)
	card.add_child(card_hbox)

	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 1)
	card_hbox.add_child(info_col)

	var tier_text = "  I" if tier == 1 else ("  II" if tier == 2 else "  III")
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	info_col.add_child(name_row)
	name_row.add_child(_styled_label(label_text + tier_text, font_bold, 16, card_color))

	var desc_text: String = m.get("desc", "")
	if m.has("time_limit"):
		desc_text += "  (" + str(int(m["time_limit"])) + "s)"
	info_col.add_child(_styled_label(desc_text, font_medium, 13, TEXT_WHITE))

	var reward_parts := []
	reward_parts.append("$" + str(m.get("reward_money", 0)))
	reward_parts.append(str(m.get("reward_xp", 0)) + " XP")
	info_col.add_child(_styled_label("  ·  ".join(reward_parts), font_semi, 13, TEXT_GREEN))

	var go_btn := _styled_button("GO", Vector2(80, 40))
	go_btn.add_theme_font_size_override("font_size", 15)
	var captured_m = m.duplicate()
	go_btn.pressed.connect(func(_m = captured_m): _launch_mission(_m))
	card_hbox.add_child(go_btn)

func _launch_mission(m: Dictionary):
	var tl = m.get("time_limit", 0.0)
	GameManager.mission_profile = GameManager.build_mission_profile(
		m.get("type", "extermination"),
		m.get("tier", 1),
		m.get("reward_money", 50),
		m.get("reward_xp", 40),
		tl,
		"",
		int(m.get("waves", 0))
	)
	GameManager.start_mission()
	get_tree().change_scene_to_file("res://Scenes/MissionScene.tscn")

func _on_start_contract_mission():
	var contract = GameManager.current_contract
	var reward = contract.get("reward", 100)
	GameManager.mission_profile = GameManager.build_mission_profile(
		"assassination", 1, reward, 50, 0.0, contract.get("target", ""))
	GameManager.start_mission()
	get_tree().change_scene_to_file("res://Scenes/MissionScene.tscn")


var lbl_mix: Label
var lbl_order_display: Label

func setup_boba_ui():
	var p = ui_boba_panel
	for c in p.get_children():
		if str(c.name).begins_with("Close"):
			continue
		c.queue_free()

	var margin := MarginContainer.new()
	margin.name = "Content"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(margin)

	var close_btn = p.get_node_or_null("CloseBoba")
	if close_btn: p.move_child(close_btn, -1)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var header = _styled_label("BOBA STATION", font_bold, 18, ACCENT_GOLD)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	vbox.add_child(_make_divider())


	var order_card := PanelContainer.new()
	order_card.add_theme_stylebox_override("panel", _make_panel_style(
		Color(0.04, 0.04, 0.06, 0.9), Color(0.3, 0.3, 0.35, 0.4), 5))
	vbox.add_child(order_card)

	var order_vbox := VBoxContainer.new()
	order_vbox.add_theme_constant_override("separation", 4)
	order_card.add_child(order_vbox)

	var order_header = _styled_label("ORDER", font_bold, 13, ACCENT_GOLD_DIM)
	order_vbox.add_child(order_header)

	lbl_order_display = _styled_label("No customer waiting", font_bold, 14, TEXT_WHITE)
	lbl_order_display.autowrap_mode = TextServer.AUTOWRAP_WORD
	order_vbox.add_child(lbl_order_display)

	vbox.add_child(_make_spacer(4))

	lbl_mix = _styled_label("Mix: empty", font_semi, 13, Color(0.55, 0.85, 1.0))
	vbox.add_child(lbl_mix)


	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(grid)

	var ing_colors = {
		"Black Tea": Color(0.75, 0.6, 0.4),
		"Green Tea": Color(0.55, 0.82, 0.5),
		"Milk": Color(0.92, 0.92, 0.96),
		"Tapioca": Color(0.6, 0.55, 0.7),
		"Sugar": Color(1.0, 0.85, 0.5)
	}

	var ing_icons = {
		"Milk": TEX_MILK_ICON,
		"Sugar": TEX_SUGAR_ICON,
		"Tapioca": TEX_TAPIOCA_ICON,
		"Black Tea": TEX_BLACK_TEA_ICON,
	}

	var icon_size := 32

	for ing in GameManager.unlocked_ingredients:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 8)
		cell.alignment = BoxContainer.ALIGNMENT_CENTER

		var icon_tex = ing_icons.get(ing, null)
		if icon_tex:
			var icon := TextureRect.new()
			icon.texture = icon_tex
			icon.custom_minimum_size = Vector2(icon_size, icon_size)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(icon)
		else:
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(icon_size, icon_size)
			cell.add_child(spacer)

		var btn := _styled_button("+ " + ing, Vector2(140, 40))
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_font_override("font", font_semi)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var col = ing_colors.get(ing, TEXT_WHITE)

		var bright_col = col.lerp(Color.WHITE, 0.25)
		btn.add_theme_color_override("font_color", bright_col)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		btn.add_theme_constant_override("outline_size", 4)
		btn.pressed.connect(_add_to_mix.bind(ing))
		cell.add_child(btn)

		grid.add_child(cell)

	vbox.add_child(_make_spacer(2))


	const ACTION_BTN_SIZE := Vector2(160, 46)
	const ACTION_BTN_FONT_SIZE := 16

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.size_flags_vertical = Control.SIZE_SHRINK_END
	vbox.add_child(actions)

	var serve_btn := _styled_button("SERVE", ACTION_BTN_SIZE)
	serve_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	serve_btn.size_flags_vertical = Control.SIZE_FILL
	serve_btn.size_flags_stretch_ratio = 1.0
	serve_btn.add_theme_font_size_override("font_size", ACTION_BTN_FONT_SIZE)
	serve_btn.add_theme_font_override("font", font_bold)
	serve_btn.add_theme_stylebox_override("normal", _make_panel_style(
		Color(0.08, 0.18, 0.08, 0.95), Color(0.4, 0.88, 0.45, 0.8), 8))
	serve_btn.add_theme_stylebox_override("hover", _make_panel_style(
		Color(0.12, 0.24, 0.12, 0.95), Color(0.5, 1.0, 0.55, 1.0), 8))
	serve_btn.add_theme_color_override("font_color", TEXT_GREEN.lightened(0.25))
	serve_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	serve_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	serve_btn.add_theme_constant_override("outline_size", 4)
	serve_btn.pressed.connect(_on_serve_drink)
	actions.add_child(serve_btn)

	var clear_btn := _styled_button("CLEAR", ACTION_BTN_SIZE)
	clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_btn.size_flags_vertical = Control.SIZE_FILL
	clear_btn.size_flags_stretch_ratio = 1.0
	clear_btn.add_theme_font_size_override("font_size", ACTION_BTN_FONT_SIZE)
	clear_btn.add_theme_font_override("font", font_bold)
	clear_btn.add_theme_stylebox_override("normal", _make_panel_style(
		Color(0.16, 0.08, 0.08, 0.95), Color(0.7, 0.35, 0.35, 0.6), 8))
	clear_btn.add_theme_stylebox_override("hover", _make_panel_style(
		Color(0.22, 0.1, 0.1, 0.95), Color(0.9, 0.45, 0.45, 0.9), 8))
	clear_btn.add_theme_color_override("font_color", Color(0.9, 0.55, 0.55))
	clear_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	clear_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	clear_btn.add_theme_constant_override("outline_size", 4)
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
	_update_order_display()

func _update_order_display():
	if not lbl_order_display: return
	var target_customer = _get_waiting_customer()
	if target_customer:
		var o = target_customer.order
		var parts := []
		parts.append(o.get("base", ""))
		if o.get("milk", "No Milk") == "Milk":
			parts.append("Milk")
		if o.get("topping", "None") != "None":
			parts.append(o["topping"])
		var prefix = "⚑ " if target_customer.is_secret_agent else ""
		lbl_order_display.text = prefix + " + ".join(parts)
		lbl_order_display.add_theme_color_override("font_color",
			Color(1.0, 0.75, 0.55) if target_customer.is_secret_agent else TEXT_WHITE)
	else:
		lbl_order_display.text = "No customer waiting"
		lbl_order_display.add_theme_color_override("font_color", TEXT_DIM)

func _get_waiting_customer():
	for c in active_customers:
		if c.is_waiting:
			return c
	return null

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
			# Play cash register sound
			if _cash_register_sfx:
				_cash_register_sfx.play()
			current_mix = []
			update_mix_label()
			_close_panel(ui_boba_panel)
			GameManager.add_money(10)
			GameManager.add_xp(10)
		else:
			if _error_sfx:
				_error_sfx.play()
			_show_floating_text("Wrong order!", TEXT_RED, target_customer.global_position)


func end_day():
	shift_active = false
	_stop_time_flash()
	GameManager.end_day()
	show_day_summary()

func show_day_summary():
	var overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	$UI_Layer.add_child(overlay)

	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var center_panel := Panel.new()
	center_panel.set_anchors_preset(Control.PRESET_CENTER)
	center_panel.offset_left = -280
	center_panel.offset_top = -220
	center_panel.offset_right = 280
	center_panel.offset_bottom = 220
	center_panel.add_theme_stylebox_override("panel", _make_panel_style(
		Color(0.05, 0.05, 0.07, 0.98), Color(0.91, 0.76, 0.29, 0.4), 14))
	overlay.add_child(center_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_bottom", 28)
	center_panel.add_child(margin)

	var center := VBoxContainer.new()
	center.add_theme_constant_override("separation", 12)
	margin.add_child(center)

	var title = _styled_label("DAY " + str(GameManager.day) + " COMPLETE", font_bold, 32, ACCENT_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(title)

	center.add_child(_make_divider(ACCENT_GOLD_DIM))


	var stats_card := PanelContainer.new()
	stats_card.add_theme_stylebox_override("panel", _make_card_style())
	center.add_child(stats_card)

	var stats_vbox := VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 8)
	stats_card.add_child(stats_vbox)

	var _add_stat_row = func(label_text: String, value_text: String, value_color: Color):
		var row := HBoxContainer.new()
		stats_vbox.add_child(row)
		var k = _styled_label(label_text, font_medium, 16, TEXT_DIM)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(k)
		var v = _styled_label(value_text, font_semi, 18, value_color)
		row.add_child(v)

	_add_stat_row.call("Earnings", "$" + str(GameManager.daily_earnings), TEXT_GREEN)
	_add_stat_row.call("Customers", str(GameManager.customers_served_today), TEXT_WHITE)
	_add_stat_row.call("Level", str(GameManager.level), ACCENT_GOLD)
	_add_stat_row.call("XP", str(GameManager.xp) + "/" + str(GameManager.get_xp_for_next_level()), TEXT_DIM)

	center.add_child(_make_spacer(8))

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(btn_row)

	if GameManager.target_order_received:
		var mission_btn := _styled_button("GO ON MISSION", Vector2(190, 52))
		mission_btn.add_theme_font_size_override("font_size", 15)
		mission_btn.add_theme_stylebox_override("normal", _make_panel_style(
			Color(0.14, 0.08, 0.08, 0.95), Color(1.0, 0.35, 0.35, 0.5), 8))
		mission_btn.add_theme_color_override("font_color", TEXT_RED)
		mission_btn.pressed.connect(func():
			var c = GameManager.current_contract
			GameManager.mission_profile = GameManager.build_mission_profile(
				"assassination", 1, c.get("reward", 100), 50, 0.0, c.get("target", ""))
			GameManager.start_mission()
			get_tree().change_scene_to_file("res://Scenes/MissionScene.tscn")
		)
		btn_row.add_child(mission_btn)

	var continue_btn := _styled_button("NEXT DAY", Vector2(190, 52))
	continue_btn.add_theme_font_size_override("font_size", 15)
	continue_btn.pressed.connect(func():
		GameManager.start_shop()
		get_tree().reload_current_scene()
	)
	btn_row.add_child(continue_btn)

	overlay.modulate.a = 0.0
	center_panel.scale = Vector2(0.9, 0.9)
	center_panel.pivot_offset = center_panel.size / 2.0

	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
	tween.tween_property(center_panel, "scale", Vector2.ONE, 0.4).set_delay(0.1)
