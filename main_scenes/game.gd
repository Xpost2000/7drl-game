# TODO differentiate solid and non-solid entities
# so things like bombs and items don't count as collidable!
extends Node2D

const EntityBrain = preload("res://main_scenes/EntityBrain.gd");
const TurnScheduler = preload("res://main_scenes/TurnScheduler.gd");

var _passed_turns = 0;
var _player = null;
var _last_known_current_chunk_position;

var _survivor_distance_field = null;
const MAX_REGENERATE_FIELD_TURN_TIME = 4;
var _survivor_distance_field_regenerate_timer = 0;

var _explosions = [];
# man I love how inconsistent my usage of class is.
const EXPLOSION_MAX_ANIMATION_FRAMES = 12;
const EXPLOSION_ANIMATION_FPS = 46;
var _global_explosion_animation_timer = 0.0;
class Explosion:
	var position: Vector2;
	var radius: int;
	var damage: int;
	var type: int;
	var animation_timer: int;
	func _init(where, radius, damage, type):
		self.position = where;
		self.radius = radius;
		self.damage = damage;
		self.type = type;
		self.animation_timer = 0;
func add_explosion(where, radius, damage, type):
	_explosions.push_back(Explosion.new(where, radius, damage, type));

onready var _turn_scheduler = TurnScheduler.new();

onready var _camera = $GameCamera;
onready var _world = $ChunkViews;
onready var _entities = $Entities;
onready var _projectiles = $Projectiles;
onready var _interface = $InterfaceLayer/Interface;
onready var _ascii_renderer = $CharacterASCIIDraw;

var prompting_item_use = false;
var prompting_firing_target = false;
var item_occupying_current_space = null;

var firing_target_cursor_location = Vector2(0,0);

func player_movement_direction():
	if Globals.is_action_pressed_with_delay("ui_up"):
		return Vector2(0, -1);
	elif Globals.is_action_pressed_with_delay("ui_down"):
		return Vector2(0, 1);
	elif Globals.is_action_pressed_with_delay("ui_left"):
		return Vector2(-1, 0);
	elif Globals.is_action_pressed_with_delay("ui_right"):
		return Vector2(1, 0);
	return Vector2.ZERO;

class EntityPlayerBrain extends EntityBrain:
	func get_turn_action(entity_self, game_state):
		if game_state.prompting_firing_target:
			if Input.is_action_just_pressed("game_pause"):
				game_state.prompting_firing_target = false;
			if Input.is_action_just_pressed("game_fire_weapon"):
				game_state.prompting_firing_target = false;
				if game_state.firing_target_cursor_location != game_state._player.position:
					return EntityBrain.FireWeaponTurnAction.new(game_state.firing_target_cursor_location);
				else:
					game_state._interface.message("You cannot shoot yourself.");
		elif game_state.prompting_item_use:
				var pressed_key = Globals.any_key_pressed();
				if Input.is_action_just_pressed("game_pause"):
					game_state.prompting_item_use = false;

				if pressed_key and pressed_key != "Shift" and pressed_key != "Ctrl" and pressed_key != "Alt":
					game_state.prompting_item_use = false;
					# this is kind of stupid.
					if pressed_key.find("Shift+") == -1:
						pressed_key = pressed_key.to_lower();
					else:
						pressed_key = pressed_key.substr(6);
					var letter_index = Globals.alphabet.find(pressed_key);
					if letter_index != -1:
						if letter_index < len(entity_self.inventory):
							var item_picked = entity_self.inventory[letter_index];
							# special casing medkits. They work the most differently of all items...
							# I might fix this tonight
							if item_picked is Globals.Medkit:
								item_picked.on_use(game_state, entity_self);
							else:
								return EntityBrain.UseItemAction.new(item_picked);
		else:
			var move_direction = game_state.player_movement_direction();
			game_state.item_occupying_current_space = game_state._entities.get_item_pickup_at_position(entity_self.position);
			if Input.is_action_just_pressed("game_action_pickup_item"):
				return EntityBrain.PickupItemTurnAction.new(game_state.item_occupying_current_space);
			if Input.is_action_just_pressed("game_action_wait"):
				return EntityBrain.WaitTurnAction.new();
			if Input.is_action_just_pressed("game_use_item"):
				game_state.prompting_item_use = true;
				Globals.any_key_pressed();
			if Input.is_action_just_pressed("game_reload_weapon"):
				if entity_self.currently_equipped_weapon and entity_self.currently_equipped_weapon is Globals.Gun:
					return EntityBrain.ReloadWeaponTurnAction.new();
				else:
					game_state._interface.message("You can only reload a gun");
			elif Input.is_action_just_pressed("game_fire_weapon"):
				if entity_self.currently_equipped_weapon:
					game_state.prompting_firing_target = true;
					var closest_entity = entity_self.find_closest_entity(game_state, true);
					if closest_entity:
						game_state.firing_target_cursor_location = closest_entity.position;
					else:
						game_state._interface.message("No visible target.");
						game_state.firing_target_cursor_location = game_state._player.position;
				else:
					game_state._interface.message("No gun or projectile equipped");
			if move_direction != Vector2.ZERO:
				AudioGlobal.play_sound(
				Utilities.random_nth([
				"resources/snds/footsteps/gravel1.wav",
				"resources/snds/footsteps/gravel2.wav",
				"resources/snds/footsteps/gravel3.wav",
				"resources/snds/footsteps/gravel4.wav"
				]));
				return EntityBrain.MoveTurnAction.new(move_direction);
		return null;

#################################### Infected
class EntityRandomWanderingBrain extends EntityBrain:
	func get_turn_action(entity_self, game_state):
		return EntityBrain.MoveTurnAction.new(Utilities.random_nth([Vector2.UP, Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]));

class EntityCommonInfectedChaserBrain extends EntityBrain:
	func get_turn_action(entity_self, game_state):
		if entity_self.position.distance_to(game_state._player.position) <= 1.414:
			return EntityBrain.AttackTurnAction.new(game_state._player, 5);
		else:
			var next_position = game_state._world.distance_field_next_best_position(
				game_state._survivor_distance_field, entity_self.position, game_state._entities);
			var direction = next_position - entity_self.position;
			return EntityBrain.MoveTurnAction.new(direction);

class EntitySpecialInfectedTank extends EntityBrain:
	func get_turn_action(entity_self, game_state):
		pass;

class EntitySpecialInfectedHunter extends EntityBrain:
	func get_turn_action(entity_self, game_state):
		pass;

class EntitySpecialInfectedWitch extends EntityBrain:
	func get_turn_action(entity_self, game_state):
		pass;

class EntitySpecialInfectedBoomer extends EntityBrain:
	func get_turn_action(entity_self, game_state):
		pass;

class EntitySpecialInfectedJockey extends EntityBrain:
	func get_turn_action(entity_self, game_state):
		pass;

class EntitySpecialInfectedSmoker extends EntityBrain:
	func get_turn_action(entity_self, game_state):
		pass;

class EntitySpecialInfectedSpitter extends EntityBrain:
	func get_turn_action(entity_self, game_state):
		pass;
#################################### Infected

func update_player_visibility(entity, radius):
	for other_entity in _entities.entities:
		if other_entity != entity:
			if not entity.can_see_from($ChunkViews, other_entity.position):
				other_entity.associated_sprite_node.hide();
			else:	
				other_entity.associated_sprite_node.show();

	for y_distance in range(-radius, radius):
		for x_distance in range(-radius, radius):
			var cell_position = entity.position + Vector2(x_distance, y_distance);
			if cell_position.distance_squared_to(entity.position) <= radius*radius:
				if entity.can_see_from($ChunkViews, cell_position):
					$ChunkViews.set_cell_visibility(cell_position, 1);
				else:
					$ChunkViews.set_cell_visibility(cell_position, 0.5);

func present_entity_actions_as_messages(entity, action):
	if entity == _player:
		var healing_progress_bar = _interface.get_node("Ingame/HealingDisplay/HealingProgressBar");
		if action is EntityBrain.WaitTurnAction:
			_interface.message("Waiting turn...");
		elif action is EntityBrain.MoveTurnAction:
			var move_result = _entities.try_move(entity, action.direction);
			# $ChunkViews.a_star_request_path_from_to(entity.position, Vector2(4, 4));
			update_player_visibility(entity, 5);
			match move_result:
				Enumerations.COLLISION_HIT_WALL: _interface.message("You bumped into a wall.");
				Enumerations.COLLISION_HIT_WORLD_EDGE: _interface.message("You hit the edge of the world.");
				Enumerations.COLLISION_HIT_ENTITY: _interface.message("You bumped into someone");
		elif action is EntityBrain.HealingAction:
			if entity.use_medkit_timer > 0:
				healing_progress_bar.max_value = (Globals.HEALING_MEDKIT_TURNS);
				healing_progress_bar.value = (Globals.HEALING_MEDKIT_TURNS+1) - (entity.use_medkit_timer);
				_interface.message(entity.name + " is healing themselves.");
			else:
				_interface.message(entity.name + " finished using a medkit.");

func _ready():
	# Always assume the player is entity 0 for now.
	# Obviously this can always change but whatever.
	_entities.add_entity("Bill", Vector2.ZERO, EntityPlayerBrain.new());
	_player = _entities.entities[0];
	_player.health = 100;
	_player.turn_speed = 1;
	_player.flags = 1;
	_player.position = Vector2(0, 0);
	_player.add_item(Globals.Medkit.new());
	_player.add_item(Globals.AdrenalineShot.new());
	_player.add_item(Globals.PipebombItem.new());
	_player.add_item(Globals.PillBottle.new());
	var gun = Globals.Gun.new("Assault Rifle");
	gun.capacity = 50;
	gun.current_capacity = 8;
	gun.current_capacity_limit = 8;
	gun.firing_sound_string = "resources/snds/guns/rifle_fire_1.wav";
	_player.add_item(gun);
	var pistol = Globals.Gun.new("Pistol");
	pistol.capacity = 30;
	pistol.current_capacity = 4;
	pistol.current_capacity_limit = 4;
	pistol.firing_sound_string = "resources/snds/guns/pistol_fire.wav";
	_player.add_item(pistol);
	_entities.connect("_on_entity_do_action", self, "present_entity_actions_as_messages");
	for i in range (10):
		var zombie = _entities.add_entity("Zombie", Vector2(3, 4+i), EntityCommonInfectedChaserBrain.new());
		zombie.visual_info.symbol = "Z";
		zombie.visual_info.foreground = Color.gray;

	_entities.add_item_pickup(Vector2(4, 5), Globals.Medkit.new());
	for i in range (5):
		_world.set_cell(Vector2(8+i, 9), 8);
	# _world.set_cell(Vector2(1, 0), 8);
	# _world.set_cell(Vector2(1, 1), 8);
	# _world.set_cell(Vector2(3, 0), 8);
	_last_known_current_chunk_position = _world.calculate_chunk_position(_entities.entities[0].position);

	_ascii_renderer.world = _world;
	_ascii_renderer.entities = _entities;
	# todo remove world and entities...
	_ascii_renderer.game_state = self;
	update_player_visibility(_player, 5);

	_ascii_renderer.update();
	_turn_scheduler = TurnScheduler.new();

func rerender_chunks():
	var current_chunk_position = _world.calculate_chunk_position(_entities.entities[0].position);
	_ascii_renderer.current_chunk_position = current_chunk_position;
	if _last_known_current_chunk_position != current_chunk_position:
		_ascii_renderer.update();
		for chunk_row in _world.world_chunks:
			for chunk in chunk_row:
				chunk.mark_all_dirty();
		for chunk_view in _world.get_children():
			chunk_view.clear();
		_world.inclusively_redraw_chunks_around(current_chunk_position);
		_world.repaint_animated_tiles(current_chunk_position);
		_last_known_current_chunk_position = current_chunk_position;

	_world.inclusively_redraw_chunks_around(current_chunk_position);

func step(_delta):
	if (_player.is_dead()):
		_interface.state = _interface.DEATH_STATE;
	else:
		_passed_turns += 1;

func step_round(_delta):
	if (not _player.is_dead()):
		if _survivor_distance_field_regenerate_timer <= 0:
			_survivor_distance_field = _world.distance_field_map_from(_player.position);
			_survivor_distance_field_regenerate_timer = MAX_REGENERATE_FIELD_TURN_TIME;
		else:
			_survivor_distance_field_regenerate_timer -= 1;

func _process(_delta):
	rerender_chunks();
	$Fixed/Draw.update();

	_interface.report_inventory(_player);
	_interface.report_player_health(_player);

	var item_pickup_prompt = _interface.get_node("Ingame/PickupItemPrompt");
	if item_occupying_current_space:
		item_pickup_prompt.show();
	else:
		item_pickup_prompt.hide();

	var healing_display = _interface.get_node("Ingame/HealingDisplay");
	if _player.current_medkit:
		healing_display.show();
	else:
		healing_display.hide();
		healing_display.find_node("HealingProgressBar").value = 0;

	if prompting_firing_target:
		_interface.get_node("Ingame/TargettingInfo").show();
		var move_direction = player_movement_direction();
		firing_target_cursor_location += move_direction;
		# we could still selectively update screen at certain points.
		# also do bounds checking for the cursor.
		_ascii_renderer.update();
		var target_information_label = _interface.get_node("Ingame/TargettingInfo/Info");
		var entity_at = _entities.get_entity_at_position(firing_target_cursor_location);
		if entity_at:
			target_information_label.text = entity_at.name;
		else:
			target_information_label.text = "Air";
	else:
		_interface.get_node("Ingame/TargettingInfo").hide();

	if prompting_item_use:
		_interface.get_node("Ingame/ItemPrompt").show();
	else:
		_interface.get_node("Ingame/ItemPrompt").hide();

	if Input.is_action_just_pressed("game_pause") and not prompting_firing_target and not prompting_item_use:
		if not Globals.paused:
			_interface.state = _interface.PAUSE_STATE;
			Globals.paused = true;
		else:
			_interface.state = _interface.previous_state;
			Globals.paused = false;

	if GamePreferences.ascii_mode:
		$CameraTracer.position = _player.position * Vector2(_ascii_renderer.FONT_HEIGHT/2, _ascii_renderer.FONT_HEIGHT);
		_ascii_renderer.show();
		_world.hide();
		_entities.hide();
	else:
		$CameraTracer.position = _player.associated_sprite_node.global_position;
		_ascii_renderer.hide();
		_world.show();
		_entities.show();

	if not Globals.paused and not _player.is_dead():
		if _projectiles.projectiles.empty() and _explosions.empty():
			while not _turn_scheduler.finished():
				var current_actor_turn_information = _turn_scheduler.get_current_actor();
				if current_actor_turn_information and current_actor_turn_information.turns_left > 0:
					var actor = current_actor_turn_information.actor;
					var actor_turn_action = actor.get_turn_action(self);
					if actor_turn_action:
						_entities.do_action(self, actor, actor_turn_action);
						current_actor_turn_information.turns_left -= 1;
						# this is important for the player as it doesn't allow
						# them to burn through all their turns
						if actor == _player: 
							_ascii_renderer.update();
							break;
					else: 
						_ascii_renderer.update();
						break;
				else:
					step(_delta);
					_turn_scheduler.next_actor();
			if _turn_scheduler.finished():
				step_round(_delta);
				for entity in _entities.entities:
					if not entity.is_dead() and entity.adrenaline_active_timer > 0:
						entity.adrenaline_active_timer -= 1;

					if not entity.is_dead() and entity.wait_time <= 0 :
						_turn_scheduler.push(entity, entity.get_turn_speed());
					else:
						entity.wait_time -= 1;

		if not _explosions.empty():
			var deletion_list = [];
			if _global_explosion_animation_timer <= 0.0:
				for explosion in _explosions:
					# To survivors any explosion should deal 10% of their normal amount.
					if explosion.animation_timer == (1):
						AudioGlobal.play_sound("resources/snds/pipebomb/explode.wav");
						for entity in _entities.entities:
							if explosion.position.distance_squared_to(entity.position) <= explosion.radius * explosion.radius:
								entity.health -= 100;

					if explosion.animation_timer >= EXPLOSION_MAX_ANIMATION_FRAMES:
						deletion_list.push_back(explosion);
					else:
						explosion.animation_timer += 1;
				_global_explosion_animation_timer = 1.0 / EXPLOSION_ANIMATION_FPS;
				for item in deletion_list:
					_explosions.erase(item);
			else:
				_global_explosion_animation_timer -= _delta;
			_ascii_renderer.update();
		if not _projectiles.projectiles.empty():
			for projectile in _projectiles.projectiles:
				projectile.tick(self);
			_ascii_renderer.update();
