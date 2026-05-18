extends Control

const SHOP_SCENE_PATH: String = "res://Scenes/ShopScene.tscn"
const ACCENT_GOLD := Color(0.91, 0.76, 0.29, 1.0)

const PAGES: Array = [
	{
		"title": "THE YEAR IS 2030...",
		"body": "Earth has thrived on the rise of new technology. Humanity is connected and unstoppable.\n\nIn the heart of the city, one little shop has become legend - [color=#e8c34a]The Boba Shop[/color]. Its drinks have captivated the world.\n\nBut where there is wealth, shadows grow."
	},
	{
		"title": "A WORLD IN CRISIS",
		"body": "Corrupt gang leaders exploit the same technology that built our future.\n\nThey crave money without work. Power without effort. They sit on stolen fortunes inside guarded mansions, untouchable by the law.\n\nThey believe they are [color=#e8c34a]on top of the world[/color]."
	},
	{
		"title": "THE REACTOR OVERLORD",
		"body": "Behind every gang, every paid-off guard, and every blackout is one giant boss: the Chief Engineer of the ruined nuclear plant.\n\nHe feeds on reactor power, controls the city through fear, and keeps your town trapped under his machine.\n\nTo restore peace, you will have to reach the wasteland and [color=#e8c34a]bring him down[/color]."
	},
	{
		"title": "YOU ARE THE BOBARISTA",
		"body": "By day, you serve drinks with a smile.\nBy night, a [color=#e8c34a]secret menu order[/color] is whispered across the counter - a contract.\n\nSlip out of your apron.\nFollow the clues through rundown streets and watchful windows.\nFind the target. Finish the job."
	},
	{
		"title": "CONTROLS",
		"body": "[color=#e8c34a]KEYBOARD & MOUSE[/color]\nWASD - Move    Shift - Sprint    Ctrl - Crouch\nLMB - Attack    RMB - Aim    E - Interact\n1 / 2 / 3 or Q / R - Switch Weapons\nG - Ability    Esc - Pause\n\n[color=#e8c34a]GAMEPAD[/color]\nL-Stick - Move    R-Stick - Aim    RT / Y - Shoot\nLT - Aim    A - Use / Select    B - Crouch\nX - Ability    L3 - Sprint    LB / RB - Cycle Weapon\nStart - Pause"
	},
	{
		"title": "BREW. SERVE. STRIKE.",
		"body": "Run your shop. Earn your reputation.\nTake the contracts. Cleanse the city.\n\nWhen the final mission opens, breach the nuclear wasteland and end the Overlord's rule."
	},
]

@onready var title_label: Label = $Center/VBox/TitleLabel
@onready var accent_line: ColorRect = $Center/VBox/AccentLine
@onready var body_label: RichTextLabel = $Center/VBox/BodyLabel
@onready var prompt_label: Label = $PromptLabel
@onready var skip_label: Label = $SkipLabel
@onready var background: ColorRect = $Background
@onready var vignette: ColorRect = $Vignette

var _page_index: int = 0
var _type_tween: Tween = null
var _is_typing: bool = false
var _changing_scene: bool = false
var _click_sfx: AudioStreamPlayer = null

const TYPE_SECONDS_PER_CHAR: float = 0.018

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_click_sfx = AudioStreamPlayer.new()
	_click_sfx.stream = preload("res://Assets/Audio/sfx/sfx_UI_button_click.wav")
	_click_sfx.volume_db = -8.0
	_click_sfx.bus = &"SFX"
	add_child(_click_sfx)

	body_label.bbcode_enabled = true
	body_label.fit_content = true
	body_label.scroll_active = false

	modulate.a = 0.0
	var fade_in := create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, 0.8)

	_show_page(0)

func _show_page(idx: int) -> void:
	_page_index = idx
	var page: Dictionary = PAGES[idx]
	title_label.text = page["title"]
	body_label.text = "[center]" + str(page["body"]) + "[/center]"
	body_label.visible_ratio = 0.0

	prompt_label.modulate.a = 0.0

	var title_start := title_label.position
	title_label.modulate.a = 0.0
	title_label.position = title_start + Vector2(0, -10)

	var line_tween := create_tween().set_parallel(true)
	line_tween.tween_property(title_label, "modulate:a", 1.0, 0.45)
	line_tween.tween_property(title_label, "position", title_start, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	line_tween.tween_property(accent_line, "modulate:a", 1.0, 0.45)

	_start_typewriter()

func _start_typewriter() -> void:
	_is_typing = true
	if _type_tween and _type_tween.is_valid():
		_type_tween.kill()
	var total_chars: int = body_label.get_total_character_count()
	var duration: float = max(0.4, total_chars * TYPE_SECONDS_PER_CHAR)
	_type_tween = create_tween()
	_type_tween.tween_property(body_label, "visible_ratio", 1.0, duration)
	_type_tween.finished.connect(_on_typewriter_finished)

func _on_typewriter_finished() -> void:
	_is_typing = false
	prompt_label.text = "PRESS  SPACE  /  A  TO CONTINUE" if _page_index < PAGES.size() - 1 else "PRESS  SPACE  /  A  TO BEGIN"
	var t := create_tween().set_loops()
	t.tween_property(prompt_label, "modulate:a", 1.0, 0.4)
	t.tween_property(prompt_label, "modulate:a", 0.35, 0.8)
	t.tween_property(prompt_label, "modulate:a", 1.0, 0.4)

func _unhandled_input(event: InputEvent) -> void:
	if _changing_scene:
		# Swallow any further input during the fade-out so spam-Escape can't
		# leak through to the autoloaded PauseMenu and leave the next scene
		# stuck in a paused state with the pause menu open.
		if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
			get_viewport().set_input_as_handled()
		return

	var skip_all := false
	var advance := false

	if event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START):
		skip_all = true
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		advance = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			advance = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance = true

	if skip_all:
		_play_click()
		_finish_intro()
		get_viewport().set_input_as_handled()
		return

	if advance:
		_play_click()
		if _is_typing:
			if _type_tween and _type_tween.is_valid():
				_type_tween.kill()
			body_label.visible_ratio = 1.0
			_on_typewriter_finished()
		else:
			if _page_index >= PAGES.size() - 1:
				_finish_intro()
			else:
				_show_page(_page_index + 1)
		get_viewport().set_input_as_handled()

func _play_click() -> void:
	if _click_sfx:
		_click_sfx.play()

func _finish_intro() -> void:
	if _changing_scene:
		return
	_changing_scene = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	# Defensive: if anything (e.g. a leaked Esc press) left the tree paused or
	# the pause menu visible during the fade, clear that state before handing
	# off to the next scene.
	get_tree().paused = false
	var pause_menu: Node = get_node_or_null("/root/PauseMenu")
	if pause_menu and pause_menu.has_method("hide_pause_menu"):
		pause_menu.hide_pause_menu()
	get_tree().change_scene_to_file(SHOP_SCENE_PATH)
