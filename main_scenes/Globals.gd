extends Node

onready var game_main_scene = preload("res://main_scenes/GameMain.tscn");
onready var main_menu_scene = preload("res://main_scenes/MainMenuUI.tscn");

onready var _key_delay_timer = 0.0;

func is_action_pressed_with_delay(action):
	if _key_delay_timer <= 0.0 and Input.is_action_pressed(action):
		_key_delay_timer = GamePreferences.KEY_DELAY_TIME;
		return true;
	return false;
func is_action_just_pressed_with_delay(action):
	if _key_delay_timer <= 0.0 and Input.is_action_just_pressed(action):
		_key_delay_timer = GamePreferences.KEY_DELAY_TIME;
		return true;
	return false;

func _process(delta):
	_key_delay_timer -= delta;