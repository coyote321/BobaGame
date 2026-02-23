extends Button
class_name MainMenuButton

const COLOR_DEFAULT := Color(0.85, 0.85, 0.85, 1.0)
const COLOR_HOVER := Color(0.91, 0.76, 0.29, 1.0) 
const SLIDE_OFFSET := 20.0
const ANIM_DURATION := 0.15

var _base_x: float = 0.0
var _tween: Tween

func _ready() -> void:
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	add_theme_color_override("font_color", COLOR_DEFAULT)
	add_theme_color_override("font_hover_color", COLOR_HOVER)
	add_theme_color_override("font_pressed_color", COLOR_HOVER.darkened(0.15))
	add_theme_color_override("font_focus_color", COLOR_DEFAULT)

	_apply_empty_stylebox("normal")
	_apply_empty_stylebox("hover")
	_apply_empty_stylebox("pressed")
	_apply_empty_stylebox("focus")

	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)

	clip_text = false
	alignment = HORIZONTAL_ALIGNMENT_LEFT

func _notification(what: int) -> void:
	if what == NOTIFICATION_POST_ENTER_TREE:
		_base_x = position.x

func _on_hover_enter() -> void:
	_kill_tween()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "position:x", _base_x + SLIDE_OFFSET, ANIM_DURATION)

func _on_hover_exit() -> void:
	_kill_tween()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "position:x", _base_x, ANIM_DURATION)

func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

func _apply_empty_stylebox(state: String) -> void:
	var sb := StyleBoxEmpty.new()
	add_theme_stylebox_override(state, sb)

func _draw() -> void:
	if is_hovered() or has_focus():
		var accent_bar := Rect2(0, size.y * 0.25, 3, size.y * 0.5)
		draw_rect(accent_bar, COLOR_HOVER)
