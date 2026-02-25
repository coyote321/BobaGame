extends CanvasLayer

const ACCENT_GOLD := Color(0.91, 0.76, 0.29, 1.0)
const ACCENT_GOLD_DIM := Color(0.91, 0.76, 0.29, 0.4)
const TEXT_GREEN := Color(0.45, 0.85, 0.45, 1.0)

@onready var health_bar: ProgressBar = $HealthPanel/HealthBar
@onready var health_text: Label = $HealthPanel/HealthText
@onready var objective_label: Label = $MissionPanel/ObjectiveLabel
@onready var abort_button: Button = $MissionPanel/AbortButton
@onready var return_button: Button = $MissionPanel/ReturnButton
@onready var money_label: Label = $MoneyLabel

@onready var hotbar_slot1: Panel = $Hotbar/HBox/Slot1
@onready var hotbar_slot2: Panel = $Hotbar/HBox/Slot2
@onready var hotbar_slot3: Panel = $Hotbar/HBox/Slot3

var _selected_style: StyleBoxFlat
var _unselected_style: StyleBoxFlat

func _ready():
	health_bar.max_value = GameManager.max_health
	health_bar.value = GameManager.max_health
	health_text.text = str(GameManager.max_health) + " / " + str(GameManager.max_health)

	if GameManager.current_contract.size() > 0:
		objective_label.text = "TARGET: " + GameManager.current_contract["target"]
	else:
		objective_label.text = "ELIMINATE ALL ENEMIES"

	_selected_style = StyleBoxFlat.new()
	_selected_style.bg_color = Color(0.14, 0.14, 0.17, 0.6)
	_selected_style.border_color = ACCENT_GOLD_DIM
	_selected_style.set_border_width_all(1)
	_selected_style.set_corner_radius_all(5)

	_unselected_style = StyleBoxFlat.new()
	_unselected_style.bg_color = Color(0.1, 0.1, 0.12, 0.5)
	_unselected_style.set_corner_radius_all(5)

	_refresh_hotbar()
	update_weapon(1, GameManager.equipped_main)

func update_health(current_hp: int, max_hp: int):
	health_bar.value = current_hp
	health_text.text = str(current_hp) + " / " + str(max_hp)

	var fill = StyleBoxFlat.new()
	fill.set_corner_radius_all(3)
	var hp_ratio = float(current_hp) / float(max_hp)
	if hp_ratio > 0.6:
		fill.bg_color = Color(0.35, 0.75, 0.35)
	elif hp_ratio > 0.3:
		fill.bg_color = ACCENT_GOLD.darkened(0.1)
	else:
		fill.bg_color = Color(0.8, 0.25, 0.2)
	health_bar.add_theme_stylebox_override("fill", fill)

func _refresh_hotbar():
	_set_slot_label(hotbar_slot1, "1: " + GameManager.equipped_main)
	_set_slot_label(hotbar_slot2, "2: " + GameManager.equipped_melee)
	_set_slot_label(hotbar_slot3, "3: " + GameManager.equipped_special)

func _set_slot_label(slot: Panel, text: String):
	var label = slot.get_node_or_null("Label")
	if label:
		label.text = text

func update_weapon(weapon_idx: int, _weapon_name: String):
	var slots = [hotbar_slot1, hotbar_slot2, hotbar_slot3]
	for i in range(slots.size()):
		if i + 1 == weapon_idx:
			slots[i].add_theme_stylebox_override("panel", _selected_style)
		else:
			slots[i].add_theme_stylebox_override("panel", _unselected_style)

func update_objective(text: String):
	objective_label.text = text

func update_stealth(_stealth_rating: float):
	pass

func show_mission_complete(stealth_bonus: int):
	objective_label.text = "MISSION COMPLETE"
	objective_label.add_theme_color_override("font_color", TEXT_GREEN)

	abort_button.visible = false
	return_button.visible = true

func connect_buttons(abort_callback: Callable, return_callback: Callable):
	abort_button.pressed.connect(abort_callback)
	return_button.pressed.connect(return_callback)

func _process(_delta):
	if money_label:
		money_label.text = "$ " + str(GameManager.money)

func hide_hud():
	visible = false
