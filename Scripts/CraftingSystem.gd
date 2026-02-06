extends Node
class_name CraftingSystem

# Simple ingredient matching
static func validate_mix(mix: Array, order: Dictionary) -> Dictionary:
	var result = {
		"base": "Unknown",
		"milk": "No Milk",
		"topping": "None"
	}
	
	# Identify Base
	if "Black Tea" in mix:
		result["base"] = "Black Tea"
	elif "Green Tea" in mix:
		result["base"] = "Green Tea"
	
	# Identify Milk
	if "Milk" in mix:
		result["milk"] = "Milk"
	
	# Identify Toppings (first match wins)
	if "Tapioca" in mix:
		result["topping"] = "Tapioca"
	elif "Sugar" in mix:
		result["topping"] = "Sugar"
	elif "Honey" in mix:
		result["topping"] = "Honey"
	
	return result

static func get_mix_description(mix: Array) -> String:
	if mix.is_empty():
		return "Empty Cup"
	return " + ".join(mix)
