extends CanvasLayer

# All nodes are defined in HUD.tscn — just reference them here
@onready var health_bar: ProgressBar = $HealthPanel/HealthBar
@onready var health_text: Label = $HealthPanel/HealthText
@onready var objective_label: Label = $MissionPanel/ObjectiveLabel
@onready var stealth_label: Label = $MissionPanel/StealthLabel
@onready var abort_button: Button = $MissionPanel/AbortButton
@onready var return_button: Button = $MissionPanel/ReturnButton
@onready var money_label: Label = $MoneyLabel
@onready var weapon_name_label: Label = $WeaponName
@onready var weapon_bar: HBoxContainer = $WeaponBar

func _ready():
	# Set initial health bar values
	health_bar.max_value = GameManager.max_health
	health_bar.value = GameManager.max_health
	health_text.text = str(GameManager.max_health) + " / " + str(GameManager.max_health)
	
	# Set initial weapon name
	weapon_name_label.text = GameManager.equipped_main
	
	# Set initial objective
	if GameManager.current_contract.size() > 0:
		objective_label.text = "TARGET: " + GameManager.current_contract["target"]
	else:
		objective_label.text = "ELIMINATE ALL ENEMIES"

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

# ===== Weapons =====
func update_weapon(weapon_idx: int, weapon_name: String):
	weapon_name_label.text = weapon_name
	
	# Highlight the active slot
	for i in range(weapon_bar.get_child_count()):
		var slot = weapon_bar.get_child(i)
		var style = slot.get_theme_stylebox("panel")
		if style:
			style = style.duplicate()
			if i + 1 == weapon_idx:
				style.border_color = Color(0.7, 0.7, 0.7, 1)
				style.bg_color = Color(0.25, 0.25, 0.3, 0.9)
			else:
				style.border_color = Color(0.3, 0.3, 0.35, 0.6)
				style.bg_color = Color(0.1, 0.1, 0.13, 0.85)
			slot.add_theme_stylebox_override("panel", style)

# ===== Mission =====
func update_objective(text: String):
	objective_label.text = text

func update_stealth(stealth_rating: float):
	var bars = int(stealth_rating / 10.0)
	var bar_str = ""
	for i in range(10):
		bar_str += "█" if i < bars else "░"
	
	stealth_label.text = "STEALTH: " + bar_str
	
	if stealth_rating > 70:
		stealth_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4))
	elif stealth_rating > 30:
		stealth_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	else:
		stealth_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))

func show_mission_complete(stealth_bonus: int):
	objective_label.text = "MISSION COMPLETE"
	objective_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
	
	if stealth_bonus > 0:
		stealth_label.text = "STEALTH BONUS: +$" + str(stealth_bonus) + " | +50 XP"
	else:
		stealth_label.text = "+50 XP"
	
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
