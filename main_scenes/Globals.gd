extends Node

onready var game_main_scene = preload("res://main_scenes/GameMain.tscn");
onready var main_menu_scene = preload("res://main_scenes/MainMenuUI.tscn");

onready var paused = false;
onready var _key_delay_timer = 0.0;

const alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

# define items here
class Item:
	var name: String;
	func as_string():
		return self.name;
	func on_use(game_state, target):
		pass;
	func on_attack(game_state, user, target):
		pass;
	func on_fire(game_state, user, direction):
		pass;

class Gun extends Item:
	const Projectiles = preload("res://main_scenes/Projectiles.gd");
	var capacity: int;
	var current_capacity: int;

	func as_string():
		return self.name + " (" + str(self.current_capacity) + "/" + str(self.capacity) + ")";
	func _init(name):
		self.name = name;
	func on_use(game_state, target):
		target.currently_equipped_weapon = self;
	func on_fire(game_state, user, direction):
		var new_bullet = Projectiles.BulletProjectile.new(user.position, direction);
		game_state._projectiles.add_projectile(new_bullet);

const HEALING_MEDKIT_TURNS = 3;
# glorified state setter.
# this is really bad already.
class Medkit extends Item:
	var uses_left: int;
	func as_string():
		return self.name + " (uses: " + str(self.uses_left) + ")";
	func _init():
		self.name = "Medkit";
		self.uses_left = HEALING_MEDKIT_TURNS;
	func on_use(game_state, target):
		if self.uses_left:
			target.current_medkit = self;
			target.use_medkit_timer = self.uses_left;

class PillBottle extends Item:
	func as_string():
		return self.name;
	func _init():
		self.name = "Pills";
	func on_use(game_state, target):
		# TODO clamp health gain.
		game_state._interface.message(target.name + " used pills");
		target.health += 30;
		target.remove_item(self);

class AdrenalineShot extends Item:
	func as_string():
		return self.name;
	func _init():
		self.name = "Adrenaline";
	func on_use(game_state, target):
		# TODO clamp health gain.
		game_state._interface.message(target.name + " injected adrenaline");
		target.health += 15;
		target.adrenaline_active_timer = 5;
		target.remove_item(self);

class BoomerBileItem extends Item:
	func as_string():
		return self.name;
	func _init():
		self.name = "Boomer Bile";
	func on_use(game_state, target):
		pass;
class MolotovCocktailItem extends Item:
	func as_string():
		return self.name;
	func _init():
		self.name = "Molotov Cocktail";
	func on_use(game_state, target):
		pass;
class PipebombItem extends Item:
	const Projectiles = preload("res://main_scenes/Projectiles.gd");
	func as_string():
		return self.name;
	func _init():
		self.name = "Pipebomb";
	func on_use(game_state, target):
		AudioGlobal.play_sound("resources/snds/pipebomb/beep.wav");
		target.currently_equipped_weapon = self;
	func on_fire(game_state, user, direction):
		user.remove_item(user.currently_equipped_weapon);
		user.currently_equipped_weapon = null;
		var new_bullet = Projectiles.PipebombProjectile.new(user.position, direction);
		game_state._projectiles.add_projectile(new_bullet);
		AudioGlobal.play_sound("resources/snds/pipebomb/beep.wav");
# end of item definitions;
var _global_event = null;
func _input(event):
	_global_event = event;
func any_key_pressed():
	if _global_event is InputEventKey and _global_event.pressed:
		var result = OS.get_scancode_string(_global_event.get_scancode_with_modifiers());
		_global_event = null;
		return result;
	return null;

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
