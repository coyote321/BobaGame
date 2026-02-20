extends CanvasLayer

# All nodes are defined in HUD.tscn — just reference them here
@onready var health_bar: ProgressBar = $HealthPanel/HealthBar
@onready var health_text: Label = $HealthPanel/HealthText
@onready var objective_label: Label = $MissionPanel/ObjectiveLabel
@onready var abort_button: Button = $MissionPanel/AbortButton
@onready var return_button: Button = $MissionPanel/ReturnButton
@onready var money_label: Label = $MoneyLabel

# Hotbar slot references
@onready var hotbar_slot1: Panel = $Hotbar/HBox/Slot1
@onready var hotbar_slot2: Panel = $Hotbar/HBox/Slot2
@onready var hotbar_slot3: Panel = $Hotbar/HBox/Slot3

# Style for selected vs unselected hotbar slots
var _selected_style: StyleBoxFlat
var _unselected_style: StyleBoxFlat

func _ready():
	# Set initial health bar values
	health_bar.max_value = GameManager.max_health
	health_bar.value = GameManager.max_health
	health_text.text = str(GameManager.max_health) + " / " + str(GameManager.max_health)
	
	# Set initial objective
	if GameManager.current_contract.size() > 0:
		objective_label.text = "TARGET: " + GameManager.current_contract["target"]
	else:
		objective_label.text = "ELIMINATE ALL ENEMIES"
	
	# Build hotbar styles
	_selected_style = StyleBoxFlat.new()
	_selected_style.bg_color = Color(0.5, 0.5, 0.5, 0.3)
	_selected_style.border_color = Color(0.7, 0.7, 0.7, 1)
	_selected_style.set_border_width_all(2)
	_selected_style.set_corner_radius_all(5)
	
	_unselected_style = StyleBoxFlat.new()
	_unselected_style.bg_color = Color(0.3, 0.3, 0.3, 0.5)
	_unselected_style.set_corner_radius_all(5)
	
	# Populate hotbar with equipped weapon names
	_refresh_hotbar()
	# Highlight slot 1 (main weapon) by default
	update_weapon(1, GameManager.equipped_main)

# ===== Health =====
func update_health(current_hp: int, max_hp: int):
	health_bar.value = current_hp
	health_text.text = str(current_hp) + " / " + str(max_hp)
	
	# Color transitions: green → yellow → red
	var fill = StyleBoxFlat.new()
	fill.set_corner_radius_all(3)
	var hp_ratio = float(current_hp) / float(max_hp)
	if hp_ratio > 0.6:
		fill.bg_color = Color(0.35, 0.75, 0.35)
	elif hp_ratio > 0.3:
		fill.bg_color = Color(0.8, 0.75, 0.2)
	else:
		fill.bg_color = Color(0.8, 0.25, 0.2)
	health_bar.add_theme_stylebox_override("fill", fill)

# ===== Weapons / Hotbar =====
func _refresh_hotbar():
	# Show weapon names in each slot
	_set_slot_label(hotbar_slot1, "1: " + GameManager.equipped_main)
	_set_slot_label(hotbar_slot2, "2: " + GameManager.equipped_melee)
	_set_slot_label(hotbar_slot3, "3: " + GameManager.equipped_special)

func _set_slot_label(slot: Panel, text: String):
	var label = slot.get_node_or_null("Label")
	if label:
		label.text = text

func update_weapon(weapon_idx: int, _weapon_name: String):
	# Highlight the selected slot, dim the others
	var slots = [hotbar_slot1, hotbar_slot2, hotbar_slot3]
	for i in range(slots.size()):
		if i + 1 == weapon_idx:
			slots[i].add_theme_stylebox_override("panel", _selected_style)
		else:
			slots[i].add_theme_stylebox_override("panel", _unselected_style)

# ===== Mission =====
func update_objective(text: String):
	objective_label.text = text

func update_stealth(_stealth_rating: float):
	pass  # Stealth UI removed for simplicity

func show_mission_complete(stealth_bonus: int):
	objective_label.text = "MISSION COMPLETE"
	objective_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
	
	abort_button.visible = false
	return_button.visible = true

func connect_buttons(abort_callback: Callable, return_callback: Callable):
	abort_button.pressed.connect(abort_callback)
	return_button.pressed.connect(return_callback)

# ===== Money =====
func _process(_delta):
	if money_label:
		money_label.text = "$ " + str(GameManager.money)

# ===== Visibility =====
func hide_hud():
	visible = false
