extends Control

@onready var stats_label: Label = $TitleContainer/StatsLabel
@onready var retry_button: Button = $VBoxContainer/RetryButton
@onready var main_menu_button: Button = $VBoxContainer/MainMenuButton
@onready var game_over_label: Label = $TitleContainer/GameOverLabel

func _ready():
	retry_button.pressed.connect(_on_retry_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	

	var stats_text = "Day " + str(GameManager.day)
	stats_text += "  |  Level " + str(GameManager.level)
	stats_text += "  |  $" + str(GameManager.money)
	stats_text += "  |  Contracts: " + str(GameManager.contracts_completed)
	stats_label.text = stats_text
	

	game_over_label.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(game_over_label, "modulate:a", 1.0, 0.6)

func _on_retry_pressed():

	GameManager.health = GameManager.max_health
	GameManager.current_phase = "MISSION"
	var fade = create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.3)
	await fade.finished
	get_tree().change_scene_to_file(GameManager.get_mission_scene())

func _on_main_menu_pressed():
	var fade = create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.3)
	await fade.finished
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
