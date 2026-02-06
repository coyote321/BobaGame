extends CharacterBody2D

signal customer_left(customer)
signal order_ready(customer)

var patience: float = 100.0
var max_patience: float = 100.0
var decay_rate: float = 5.0
var order: Dictionary = {}
var is_waiting: bool = false
var has_ordered: bool = false
var satisfaction_score: int = 0
var is_secret_agent: bool = false

@onready var patience_bar = $Control/ProgressBar
@onready var order_label = $Control/OrderLabel
@onready var body_sprite = $Sprite2D

func _ready():
	# Randomize appearance
	if is_secret_agent:
		body_sprite.modulate = Color(0.2, 0.2, 0.3)
	else:
		body_sprite.modulate = Color(randf_range(0.5, 1.0), randf_range(0.5, 1.0), randf_range(0.5, 1.0))
	
	# Patience based on day
	max_patience = 60.0 - (GameManager.day * 2) 
	if max_patience < 20: max_patience = 20
	patience = max_patience
	decay_rate = 100.0 / max_patience
	
	generate_order()
	update_ui()

func _process(delta):
	if is_waiting:
		patience -= decay_rate * delta
		patience_bar.value = (patience / max_patience) * 100
		
		if patience_bar.value > 50:
			patience_bar.modulate = Color.GREEN
		elif patience_bar.value > 20:
			patience_bar.modulate = Color.YELLOW
		else:
			patience_bar.modulate = Color.RED
			
		if patience <= 0:
			leave_angry()

func generate_order():
	# SIMPLE: Only order from EXACTLY what's unlocked
	# Bases
	var available_bases = []
	if "Black Tea" in GameManager.unlocked_ingredients:
		available_bases.append("Black Tea")
	if "Green Tea" in GameManager.unlocked_ingredients:
		available_bases.append("Green Tea")
	if available_bases.is_empty():
		available_bases = ["Black Tea"]
	
	# Milk - only if player has it
	var use_milk = "Milk" in GameManager.unlocked_ingredients and randf() > 0.5
	
	# Toppings
	var available_toppings = []
	if "Tapioca" in GameManager.unlocked_ingredients:
		available_toppings.append("Tapioca")
	if "Sugar" in GameManager.unlocked_ingredients:
		available_toppings.append("Sugar")
	if "Honey" in GameManager.unlocked_ingredients:
		available_toppings.append("Honey")
	
	# Build order
	order = {
		"base": available_bases.pick_random(),
		"milk": "Milk" if use_milk else "No Milk",
		"topping": available_toppings.pick_random() if available_toppings.size() > 0 and randf() > 0.3 else "None"
	}
	
	update_order_display()
	has_ordered = true
	is_waiting = true
	emit_signal("order_ready", self)

func update_order_display():
	var text = ""
	
	if is_secret_agent:
		text = "🦉 SECRET ORDER\n"
	
	text += order["base"]
	if order["milk"] == "Milk":
		text += " + Milk"
	if order["topping"] != "None":
		text += " + " + order["topping"]
	
	if is_secret_agent:
		text += "\n(The owl...)"
	
	order_label.text = text

func update_ui():
	patience_bar.value = 100

func receive_item(item_data: Dictionary) -> bool:
	if not has_ordered: return false
	
	var accuracy = calculate_accuracy(item_data)
	var speed_bonus = (patience / max_patience) * 2
	
	satisfaction_score = int(accuracy + speed_bonus)
	satisfaction_score = clampi(satisfaction_score, 1, 5)
	
	serve_complete()
	return true

func calculate_accuracy(item: Dictionary) -> int:
	var matches = 0
	if item.get("base") == order["base"]: matches += 1
	if item.get("milk") == order["milk"]: matches += 1
	if item.get("topping") == order["topping"]: matches += 1
	
	if matches == 3: return 3
	if matches == 2: return 2
	return 1

func serve_complete():
	is_waiting = false
	
	if is_secret_agent:
		order_label.text = "🦉 The owl flies\nat midnight..."
	elif satisfaction_score >= 4:
		order_label.text = "★★★★★ Amazing!"
	elif satisfaction_score >= 3:
		order_label.text = "★★★☆☆ Thanks!"
	else:
		order_label.text = "★☆☆☆☆ Meh."
	
	await get_tree().create_timer(1.5).timeout
	leave_shop()

func leave_angry():
	is_waiting = false
	satisfaction_score = 0
	order_label.text = "😤 Too slow!"
	await get_tree().create_timer(1.0).timeout
	leave_shop()

func leave_shop():
	emit_signal("customer_left", self)
	queue_free()
