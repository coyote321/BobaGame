extends CanvasLayer


const MAIN_MENU_PATH: String = "res://Scenes/MainMenu.tscn"

@onready var control_root: Control = $Control
@onready var resume_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/ResumeButton
@onready var menu_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/MenuButton
@onready var quit_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/QuitButton

func _ready() -> void:
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	
	hide_pause_menu()
	
	
	resume_button.pressed.connect(_on_resume_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _unhandled_input(event: InputEvent) -> void:
	
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if get_tree().paused:
			resume_game()
		else:
			pause_game()
		
			get_viewport().set_input_as_handled()

func pause_game() -> void:
	show_pause_menu()
	get_tree().paused = true
	print("Game Paused")

func resume_game() -> void:
	hide_pause_menu()
	get_tree().paused = false
	print("Game Resumed")

func show_pause_menu() -> void:
	control_root.visible = true

func hide_pause_menu() -> void:
	control_root.visible = false

func _on_resume_pressed() -> void:
	resume_game()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_PATH)

func _on_quit_pressed() -> void:
	get_tree().quit()
