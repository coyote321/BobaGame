extends Node
class_name CraftingSystem


static func validate_mix(mix: Array, order: Dictionary) -> Dictionary:
	var result = {
		"base": "Unknown",
		"milk": "No Milk",
		"topping": "None"
	}
	

	if "Black Tea" in mix:
		result["base"] = "Black Tea"
	elif "Green Tea" in mix:
		result["base"] = "Green Tea"
	

	if "Milk" in mix:
		result["milk"] = "Milk"
	

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
