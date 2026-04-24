extends CanvasLayer

const ACCENT_GOLD := Color(0.91, 0.76, 0.29, 1.0)
const ACCENT_CYAN := Color(0.45, 0.95, 1.0, 1.0)
const ACCENT_GREEN := Color(0.45, 0.95, 0.45, 1.0)
const ACCENT_RED := Color(1.0, 0.45, 0.45, 1.0)

@onready var health_bar: ProgressBar = $HealthPanel/HealthBar
@onready var health_text: Label = $HealthPanel/HealthText
@onready var objective_label: Label = $MissionPanel/ObjectiveLabel
@onready var timer_label: Label = $MissionPanel/TimerLabel
@onready var abort_button: Button = $MissionPanel/AbortButton
@onready var return_button: Button = $MissionPanel/ReturnButton
@onready var money_label: Label = $MoneyPanel/MoneyLabel
@onready var level_label: Label = $ProgressionPanel/LevelLabel
@onready var xp_label: Label = $ProgressionPanel/XPLabel
@onready var xp_bar: ProgressBar = $ProgressionPanel/XPBar
@onready var enemy_label: Label = $ProgressionPanel/EnemyLabel

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
	if health_bar:
		health_bar.max_value = GameManager.max_health
		health_bar.value = GameManager.max_health
	if health_text:
		health_text.text = str(GameManager.max_health) + " / " + str(GameManager.max_health)

	if objective_label:
		if GameManager.current_contract.size() > 0:
			objective_label.text = "TARGET: " + GameManager.current_contract["target"]
		else:
			objective_label.text = _default_objective_text()

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

	_refresh_hotbar()
	update_weapon(1, GameManager.equipped_main)

func _default_objective_text() -> String:
	var profile = GameManager.mission_profile
	var mtype: String = profile.get("type", "extermination")
	match mtype:
		"extermination":
			return "ELIMINATE ALL ENEMIES"
		"timed_hunt":
			return "CLEAR BEFORE TIME RUNS OUT"
		"boss_hunt":
			return "DEFEAT THE BOSS"
		"survival":
			return "SURVIVE ALL WAVES"
	return "ELIMINATE ALL ENEMIES"

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

func update_timer(seconds_remaining: float):
	if not timer_label:
		return
	if seconds_remaining < 0:
		timer_label.visible = false
		return
	timer_label.visible = true
	var secs := int(ceil(seconds_remaining))
	timer_label.text = "TIME  %02d:%02d" % [secs / 60, secs % 60]
	if seconds_remaining < 10.0:
		timer_label.add_theme_color_override("font_color", ACCENT_RED)
	elif seconds_remaining < 20.0:
		timer_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	else:
		timer_label.add_theme_color_override("font_color", ACCENT_GOLD)

func update_enemy_count(remaining: int, total: int):
	if enemy_label:
		enemy_label.text = "ENEMIES  %d / %d" % [remaining, total]

func update_stealth(_stealth_rating: float):
	pass

func show_mission_complete(_stealth_bonus: int):
	_show_mission_end_state("MISSION COMPLETE", ACCENT_GREEN)

func show_mission_failed(reason: String):
	_show_mission_end_state("MISSION FAILED — " + reason, ACCENT_RED)

func _show_mission_end_state(text: String, color: Color):
	if objective_label:
		objective_label.text = text
		objective_label.add_theme_color_override("font_color", color)
	if timer_label:
		timer_label.visible = false
	if abort_button:
		abort_button.visible = false
	if return_button:
		return_button.visible = true

func connect_buttons(abort_callback: Callable, return_callback: Callable):
	if abort_button:
		abort_button.pressed.connect(abort_callback)
	if return_button:
		return_button.pressed.connect(return_callback)

func _process(_delta):
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
	visible = false
