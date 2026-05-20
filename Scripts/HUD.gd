extends CanvasLayer

const ACCENT_GOLD := Color(0.91, 0.76, 0.29, 1.0)
const ACCENT_CYAN := Color(0.45, 0.95, 1.0, 1.0)
const ACCENT_GREEN := Color(0.45, 0.95, 0.45, 1.0)
const ACCENT_RED := Color(1.0, 0.45, 0.45, 1.0)
const MISSION_PANEL_COMPACT_BOTTOM := 124.0
const MISSION_PANEL_EXPANDED_BOTTOM := 156.0
const MISSION_PANEL_MIN_WIDTH := 210.0
const MISSION_PANEL_MAX_WIDTH := 520.0
const MISSION_PANEL_SIDE_PADDING := 24.0
const OBJECTIVE_CHAR_WIDTH := 9.5

@onready var health_bar: ProgressBar = $HealthPanel/HealthBar
@onready var health_text: Label = $HealthPanel/HealthText
@onready var mission_panel: Panel = $MissionPanel
@onready var objective_label: Label = $MissionPanel/ObjectiveLabel
var timer_label: Label = null
var mission_countdown_tick_timer: Timer = null
@onready var mission_end_panel: Panel = get_node_or_null("MissionEndPanel") as Panel
@onready var mission_end_title: Label = get_node_or_null("MissionEndPanel/VBox/Title") as Label
@onready var mission_end_subtitle: Label = get_node_or_null("MissionEndPanel/VBox/Subtitle") as Label
@onready var return_button: Button = get_node_or_null("MissionEndPanel/VBox/Buttons/ReturnButton") as Button
@onready var next_mission_button: Button = get_node_or_null("MissionEndPanel/VBox/Buttons/NextMissionButton") as Button
@onready var money_label: Label = get_node_or_null("MoneyPanel/MoneyLabel")
@onready var level_label: Label = get_node_or_null("ProgressionPanel/LevelLabel")
@onready var xp_label: Label = get_node_or_null("ProgressionPanel/XPLabel")
@onready var xp_bar: ProgressBar = get_node_or_null("ProgressionPanel/XPBar") as ProgressBar
@onready var enemy_label: Label = get_node_or_null("ProgressionPanel/EnemyLabel")

@onready var hotbar_slot1: Panel = $Hotbar/HBox/Slot1
@onready var hotbar_slot2: Panel = $Hotbar/HBox/Slot2
@onready var hotbar_slot3: Panel = $Hotbar/HBox/Slot3

var _selected_style: StyleBoxFlat
var _unselected_style: StyleBoxFlat
var _health_fill_style: StyleBoxFlat
var _last_health_color_key: String = ""
var _last_money_text: String = ""
var _last_level_text: String = ""
var _last_xp_text: String = ""
var _last_xp_value: int = -1
var _last_xp_need: int = -1

func _ready():
	add_to_group("mission_hud")
	_ensure_timer_nodes()
	if health_bar:
		health_bar.max_value = GameManager.max_health
		health_bar.value = GameManager.max_health
	if health_text:
		health_text.text = str(GameManager.max_health) + " / " + str(GameManager.max_health)
	if mission_end_panel:
		mission_end_panel.visible = false

	if objective_label:
		objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		objective_label.clip_text = true
		if GameManager.current_contract.size() > 0:
			objective_label.text = "TARGET: " + GameManager.current_contract["target"]
		else:
			objective_label.text = _default_objective_text()
		_fit_mission_panel_to_objective(false)

	_selected_style = StyleBoxFlat.new()
	_selected_style.bg_color = Color(0.18, 0.15, 0.08, 0.95)
	_selected_style.border_color = ACCENT_GOLD
	_selected_style.set_border_width_all(3)
	_selected_style.set_corner_radius_all(6)

	_unselected_style = StyleBoxFlat.new()
	_unselected_style.bg_color = Color(0.07, 0.07, 0.1, 0.88)
	_unselected_style.border_color = Color(0.3, 0.3, 0.35, 0.8)
	_unselected_style.set_border_width_all(2)
	_unselected_style.set_corner_radius_all(6)

	_health_fill_style = StyleBoxFlat.new()
	_health_fill_style.set_corner_radius_all(3)
	if health_bar:
		health_bar.add_theme_stylebox_override("fill", _health_fill_style)
		update_health(int(health_bar.value), int(health_bar.max_value))

	_refresh_hotbar()
	update_weapon(1, GameManager.equipped_main)
	if mission_countdown_tick_timer:
		mission_countdown_tick_timer.timeout.connect(_on_mission_countdown_tick)
	call_deferred("_prime_mission_countdown_display")

## Create timer/countdown nodes programmatically if they don't exist in the scene.
func _ensure_timer_nodes() -> void:
	# -- TimerLabel inside MissionPanel --
	timer_label = get_node_or_null("MissionPanel/TimerLabel") as Label
	if timer_label == null and mission_panel:
		var font_semi = load("res://Assets/Fonts/Montserrat-SemiBold.ttf")
		timer_label = Label.new()
		timer_label.name = "TimerLabel"
		timer_label.visible = false
		timer_label.offset_left = 14.0
		timer_label.offset_top = 38.0
		timer_label.offset_right = 220.0
		timer_label.offset_bottom = 60.0
		timer_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
		timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
		timer_label.add_theme_constant_override("outline_size", 3)
		if font_semi:
			timer_label.add_theme_font_override("font", font_semi)
		timer_label.add_theme_font_size_override("font_size", 14)
		timer_label.text = ""
		mission_panel.add_child(timer_label)



	# -- MissionCountdownTickTimer --
	mission_countdown_tick_timer = get_node_or_null("MissionCountdownTickTimer") as Timer
	if mission_countdown_tick_timer == null:
		mission_countdown_tick_timer = Timer.new()
		mission_countdown_tick_timer.name = "MissionCountdownTickTimer"
		mission_countdown_tick_timer.process_callback = Timer.TIMER_PROCESS_IDLE
		mission_countdown_tick_timer.wait_time = 0.1
		mission_countdown_tick_timer.one_shot = false
		mission_countdown_tick_timer.autostart = false
		add_child(mission_countdown_tick_timer)

func _bootstrap_seconds_from_profile() -> float:
	var p: Dictionary = GameManager.mission_profile
	if p.is_empty():
		return -1.0
	var tl := float(p.get("time_limit", 0.0))
	if tl > 0.0:
		return tl
	match String(p.get("type", "")):
		"timed_hunt":
			return 60.0
		"survival":
			return 120.0
		_:
			return -1.0

func _prime_mission_countdown_display() -> void:
	if GameManager.current_phase != "MISSION":
		return
	var sec := GameManager.mission_countdown_seconds
	if sec < 0.0:
		sec = _bootstrap_seconds_from_profile()
		if sec > 0.0:
			GameManager.mission_countdown_seconds = sec
	if sec >= 0.0:
		update_timer(sec)
		if mission_countdown_tick_timer and mission_countdown_tick_timer.is_stopped():
			mission_countdown_tick_timer.start()
	elif mission_countdown_tick_timer:
		mission_countdown_tick_timer.stop()

func _stop_mission_countdown_tick_timer() -> void:
	if mission_countdown_tick_timer and not mission_countdown_tick_timer.is_stopped():
		mission_countdown_tick_timer.stop()

func _on_mission_countdown_tick() -> void:
	if GameManager.current_phase != "MISSION":
		_stop_mission_countdown_tick_timer()
		return
	var sec := GameManager.mission_countdown_seconds
	if sec < 0.0:
		_stop_mission_countdown_tick_timer()
		update_timer(-1.0)
		return
	update_timer(sec)

func _default_objective_text() -> String:
	var profile = GameManager.mission_profile
	var mtype: String = profile.get("type", "extermination")
	match mtype:
		"extermination":
			return "ELIMINATE ALL ENEMIES"
		"timed_hunt":
			return "TIMED: ELIMINATE ALL"
		"boss_hunt":
			if bool(profile.get("is_final_mission", false)):
				return "DEFEAT THE REACTOR OVERLORD"
			return "DEFEAT THE BOSS"
		"survival":
			return "SURVIVE ALL WAVES"
	return "ELIMINATE ALL ENEMIES"

func _set_mission_panel_expanded(expanded: bool) -> void:
	if mission_panel:
		mission_panel.offset_bottom = MISSION_PANEL_EXPANDED_BOTTOM if expanded else MISSION_PANEL_COMPACT_BOTTOM

func _get_objective_panel_width() -> float:
	if not objective_label:
		return MISSION_PANEL_MIN_WIDTH
	var estimated_width := objective_label.text.length() * OBJECTIVE_CHAR_WIDTH + MISSION_PANEL_SIDE_PADDING
	return clampf(estimated_width, MISSION_PANEL_MIN_WIDTH, MISSION_PANEL_MAX_WIDTH)

func _fit_mission_panel_to_objective(expanded: bool) -> void:
	if not mission_panel:
		return
	var panel_width := _get_objective_panel_width()
	mission_panel.offset_right = mission_panel.offset_left + panel_width
	if objective_label:
		objective_label.offset_right = panel_width - 12.0
	if timer_label:
		timer_label.offset_right = panel_width - 14.0
	_set_mission_panel_expanded(expanded)

func update_health(current_hp: int, max_hp: int):
	if not health_bar or not health_text:
		return
	health_bar.value = current_hp
	health_text.text = str(current_hp) + " / " + str(max_hp)

	var hp_ratio = float(current_hp) / float(max_hp)
	var color_key := "danger"
	var fill_color := Color(0.9, 0.25, 0.25)
	if hp_ratio > 0.6:
		color_key = "healthy"
		fill_color = Color(0.35, 0.85, 0.35)
	elif hp_ratio > 0.3:
		color_key = "warning"
		fill_color = Color(1.0, 0.75, 0.25)
	if color_key != _last_health_color_key:
		_health_fill_style.bg_color = fill_color
		_last_health_color_key = color_key

func _refresh_hotbar():
	var equipped = [GameManager.equipped_main, GameManager.equipped_melee, GameManager.equipped_special]
	var slots = [hotbar_slot1, hotbar_slot2, hotbar_slot3]
	for i in range(slots.size()):
		_set_slot_label(slots[i], str(i + 1) + "  " + equipped[i])
		if slots[i]:
			slots[i].add_theme_stylebox_override("panel", _unselected_style)

func _set_slot_label(slot: Panel, text: String):
	if not slot:
		return
	var label = slot.get_node_or_null("Label")
	if label:
		label.text = text

func update_weapon(weapon_idx: int, _weapon_name: String):
	var equipped = [GameManager.equipped_main, GameManager.equipped_melee, GameManager.equipped_special]
	var slots = [hotbar_slot1, hotbar_slot2, hotbar_slot3]
	for i in range(slots.size()):
		_set_slot_label(slots[i], str(i + 1) + "  " + equipped[i])
		if slots[i] == null:
			continue
		slots[i].add_theme_stylebox_override("panel",
			_selected_style if i + 1 == weapon_idx else _unselected_style)

func update_objective(text: String):
	if objective_label:
		objective_label.text = text
	var expanded := false
	if timer_label:
		expanded = timer_label.visible
	_fit_mission_panel_to_objective(expanded)

func update_timer(seconds_remaining: float):
	if seconds_remaining < 0.0:
		_stop_mission_countdown_tick_timer()
		if timer_label:
			timer_label.visible = false
		_fit_mission_panel_to_objective(false)
		return
	var secs := maxi(0, int(ceil(seconds_remaining)))
	var txt := "TIME LEFT  %02d:%02d" % [secs / 60, secs % 60]
	var col: Color
	if seconds_remaining < 10.0:
		col = ACCENT_RED
	elif seconds_remaining < 30.0:
		col = Color(1, 0.8, 0.3)
	else:
		col = ACCENT_GOLD
	_fit_mission_panel_to_objective(true)
	if timer_label:
		timer_label.visible = true
		timer_label.text = txt
		timer_label.add_theme_color_override("font_color", col)

func update_enemy_count(remaining: int, total: int):
	if enemy_label:
		enemy_label.text = "ENEMIES LEFT  %d / %d" % [remaining, total]

func update_stealth(_stealth_rating: float):
	pass

func show_mission_complete(stealth_bonus: int):
	var subtitle := "Walk through the shop door to return."
	var show_next := true
	if bool(GameManager.mission_profile.get("is_final_mission", false)):
		subtitle = "The Overlord is gone. Peace can return to town."
		show_next = false
	if stealth_bonus > 0:
		subtitle += "  Stealth bonus: $" + str(stealth_bonus)
	_show_mission_end_state("MISSION COMPLETE", ACCENT_GREEN, subtitle, show_next)

func show_mission_failed(reason: String):
	_show_mission_end_state("MISSION FAILED", ACCENT_RED, reason, false)

func _show_mission_end_state(text: String, color: Color, subtitle: String, show_next: bool):
	_stop_mission_countdown_tick_timer()
	if objective_label:
		objective_label.text = text
		objective_label.add_theme_color_override("font_color", color)
	_fit_mission_panel_to_objective(false)
	if timer_label:
		timer_label.visible = false
	if mission_end_panel:
		mission_end_panel.visible = true
	if mission_end_title:
		mission_end_title.text = text
		mission_end_title.add_theme_color_override("font_color", color)
	if mission_end_subtitle:
		mission_end_subtitle.text = subtitle
	if return_button:
		return_button.visible = true
	if next_mission_button:
		next_mission_button.visible = show_next
	if show_next and next_mission_button:
		next_mission_button.call_deferred("grab_focus")
	elif return_button:
		return_button.call_deferred("grab_focus")

func is_mission_end_panel_visible() -> bool:
	return mission_end_panel != null and mission_end_panel.visible

func connect_buttons(_abort_callback: Callable, return_callback: Callable, next_callback: Callable = Callable()):
	if return_button and return_callback.is_valid():
		return_button.pressed.connect(return_callback)
	if next_mission_button and next_callback.is_valid():
		next_mission_button.pressed.connect(next_callback)

func _process(_delta):
	# --- Self-update mission timer from GameManager every frame ---
	if GameManager.current_phase == "MISSION":
		var sec := GameManager.mission_countdown_seconds
		if sec >= 0.0:
			var secs := maxi(0, int(ceil(sec)))
			var txt := "TIME LEFT  %02d:%02d" % [secs / 60, secs % 60]
			var col: Color
			if sec < 10.0:
				col = ACCENT_RED
			elif sec < 30.0:
				col = Color(1, 0.8, 0.3)
			else:
				col = ACCENT_GOLD
			_fit_mission_panel_to_objective(true)
			if timer_label:
				timer_label.visible = true
				timer_label.text = txt
				timer_label.add_theme_color_override("font_color", col)

	if money_label:
		var money_text := "$ " + str(GameManager.money)
		if money_text != _last_money_text:
			money_label.text = money_text
			_last_money_text = money_text
	if level_label:
		var level_text := "LVL  " + str(GameManager.level)
		if level_text != _last_level_text:
			level_label.text = level_text
			_last_level_text = level_text
	if xp_label and xp_bar:
		var need = GameManager.get_xp_for_next_level()
		if need != _last_xp_need:
			xp_bar.max_value = need
			_last_xp_need = need
		if GameManager.xp != _last_xp_value:
			xp_bar.value = GameManager.xp
			_last_xp_value = GameManager.xp
		var xp_text := "XP  %d / %d" % [GameManager.xp, need]
		if xp_text != _last_xp_text:
			xp_label.text = xp_text
			_last_xp_text = xp_text

func hide_hud():
	_stop_mission_countdown_tick_timer()
	visible = false
