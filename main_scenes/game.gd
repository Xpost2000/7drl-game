# TODO differentiate solid and non-solid entities
# so things like bombs and items don't count as collidable!
extends Node2D

const EntityBrain = preload("res://main_scenes/EntityBrain.gd");
const TurnScheduler = preload("res://main_scenes/TurnScheduler.gd");

var _passed_turns = 0;
var _player = null;
var _survivors = [];
var _last_known_current_chunk_position;

var _survivor_distance_field = null;
const MAX_REGENERATE_FIELD_TURN_TIME = 3;
var _survivor_distance_field_regenerate_timer = 0;

var _explosions = [];

# array of (Vector2, int)
var _boomer_bile_sources = [];
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
		if entity_self.currently_equipped_weapon and (entity_self.rounds_left_in_burst > 0) and entity_self.currently_equipped_weapon is Globals.Gun:
			entity_self.rounds_left_in_burst -= 1;
			if entity_self.currently_equipped_weapon.current_capacity:
				return EntityBrain.FireWeaponTurnAction.new(game_state.firing_target_cursor_location);
			else:
				entity_self.rounds_left_in_burst = 0;
				return null;
		
		if game_state.prompting_firing_target:
			if Input.is_action_just_pressed("game_pause"):
				game_state.prompting_firing_target = false;
			if Input.is_action_just_pressed("game_fire_weapon"):
				game_state.prompting_firing_target = false;
				if game_state.firing_target_cursor_location != game_state._player.position:
					if entity_self.currently_equipped_weapon is Globals.Gun and entity_self.currently_equipped_weapon.rounds_per_shot > 1:
						entity_self.rounds_left_in_burst = entity_self.currently_equipped_weapon.rounds_per_shot-1;
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
				var move_result = game_state._entities.try_move(entity_self, move_direction);
				if move_result == Enumerations.COLLISION_HIT_ENTITY:
					return EntityBrain.ShoveTurnAction.new(move_direction);
				else:
					return EntityBrain.MoveTurnAction.new(move_direction);
		return null;

#################################### Infected
class EntityRandomWanderingBrain extends EntityBrain:
	func get_turn_action(entity_self, game_state):
		return EntityBrain.MoveTurnAction.new(Utilities.random_nth([Vector2.UP, Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]));

class EntityCommonInfectedChaserBrain extends EntityBrain:
	func get_turn_action(entity_self, game_state):
		if entity_self.position.distance_squared_to(game_state._player.position) <= 2:
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

func make_pistol():
	var pistol = Globals.Gun.new("Pistol");
	pistol.capacity = 30;
	pistol.current_capacity = 4;
	pistol.current_capacity_limit = 4;
	pistol.firing_sound_string = "resources/snds/guns/pistol_fire.wav";
	pistol.reload_sound_string = "resources/snds/guns/pistol_clip_in_1.wav";
	return pistol;

func make_rifle():
	var gun = Globals.Gun.new("Assault Rifle");
	gun.capacity = 150;
	gun.current_capacity = 30;
	gun.current_capacity_limit = 30;
	gun.firing_sound_string = "resources/snds/guns/rifle_fire_1.wav";
	gun.reload_sound_string = "resources/snds/guns/rifle_clip_in_1.wav";
	gun.rounds_per_shot = 3;
	return gun;
	
func make_shotgun():
	var gun = Globals.Gun.new("Shotgun");
	gun.shotgun = true;
	gun.capacity = 45;
	gun.current_capacity = 4;
	gun.current_capacity_limit = 4;
	gun.firing_sound_string = "resources/snds/guns/shotgun_fire_1.wav";
	gun.reload_sound_string = "resources/snds/guns/shotgun_load_shell_2.wav";
	return gun;

func make_common_infected_chaser(position):
	var zombie = _entities.add_entity("Infected", position, EntityCommonInfectedChaserBrain.new());
	zombie.visual_info.symbol = "Z";
	zombie.visual_info.foreground = Color.gray;
	return zombie;

func initialize_survivors():
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
	_player.add_item(Globals.MolotovCocktailItem.new());
	_player.add_item(Globals.BoomerBileItem.new());
	_player.add_item(Globals.BoomerBileItem.new());
	_player.add_item(Globals.BoomerBileItem.new());
	_player.add_item(Globals.PillBottle.new());
	_player.add_item(make_rifle());
	_player.add_item(make_pistol());
	_player.add_item(make_shotgun());
	var second = _entities.add_entity("Louis", Vector2(2, 2), EntityPlayerBrain.new());
	second.health = 100;
	second.turn_speed = 1;
	second.flags = 1;
	second.add_item(Globals.Medkit.new());
	second.add_item(make_pistol());
	second.add_item(Globals.PipebombItem.new());
	var third = _entities.add_entity("Francis", Vector2(4, 3), EntityPlayerBrain.new());
	third.health = 100;
	third.turn_speed = 1;
	third.flags = 1;
	third.add_item(Globals.Medkit.new());
	third.add_item(make_pistol());
	third.add_item(Globals.PipebombItem.new());
	var fourth = _entities.add_entity("Zoey", Vector2(1, 4), EntityPlayerBrain.new());
	fourth.health = 100;
	fourth.turn_speed = 1;
	fourth.flags = 1;
	fourth.add_item(Globals.Medkit.new());
	fourth.add_item(make_pistol());
	fourth.add_item(Globals.PipebombItem.new());
	_survivors = [_player, second, third, fourth];

func _ready():
	initialize_survivors();
	_entities.connect("_on_entity_do_action", self, "present_entity_actions_as_messages");
	for i in range (1):
		make_common_infected_chaser(Vector2(5, 5+i));

	_entities.add_item_pickup(Vector2(4, 5), Globals.Medkit.new());
	for i in range (5):
		_world.set_cell(Vector2(8+i, 4), 8);
	# _world.set_cell(Vector2(1, 0), 8);
	# _world.set_cell(Vector2(1, 1), 8);
	# _world.set_cell(Vector2(3, 0), 8);
	_last_known_current_chunk_position = _world.calculate_chunk_position(_entities.entities[0].position);

	_ascii_renderer.world = _world;
	_ascii_renderer.entities = _entities;
	# todo remove world and entities...
	_ascii_renderer.game_state = self;
	update_player_visibility(_player, 8);

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

# Special infected should only see a version with survivors exclusively?
# survivors see one with zombies
func regenerate_infected_distance_field():
	var sources = [];
	for survivor in _survivors:
		sources.push_back([survivor.position, 0]);
	for boomer_bile_source in _boomer_bile_sources:
		print(boomer_bile_source);
		sources.push_back([boomer_bile_source[0], 0]);
	_survivor_distance_field = _world.distance_field_map_from(sources);
	_survivor_distance_field_regenerate_timer = MAX_REGENERATE_FIELD_TURN_TIME;
	
func step_round(_delta):
	if (not _player.is_dead()):
		if _survivor_distance_field_regenerate_timer <= 0:
			regenerate_infected_distance_field();
		else:
			_survivor_distance_field_regenerate_timer -= 1;

	for boomer_bile_source in _boomer_bile_sources:
		if boomer_bile_source[1] <= 0:
			_boomer_bile_sources.erase(boomer_bile_source);
		boomer_bile_source[1] -= 1;

func _process(_delta):
	rerender_chunks();
	$Fixed/Draw.update();

	_interface.report_inventory(_player);
	_interface.report_player_health(_player);
	_interface.report_survivor_stats(_survivors);
	
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

	if not Globals.paused:
		if _projectiles.projectiles.empty() and _explosions.empty():
			while not _turn_scheduler.finished():
				var current_actor_turn_information = _turn_scheduler.get_current_actor();
				if current_actor_turn_information and current_actor_turn_information.turns_left > 0:
					var actor = current_actor_turn_information.actor;
					var actor_turn_action = actor.get_turn_action(self);
					if actor_turn_action:
						_entities.do_action(self, actor, actor_turn_action);
						if not actor_turn_action is EntityBrain.FireWeaponTurnAction or (actor.rounds_left_in_burst > 0):
							current_actor_turn_information.turns_left -= 1;
						# this is important for the player as it doesn't allow
						# them to burn through all their turns
						if actor == _player and not _player.is_dead(): 
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
						match explosion.type:
							Enumerations.EXPLOSION_TYPE_ACID:
								AudioGlobal.play_sound("resources/snds/spitter_acid_fadeout2.wav");
								pass;
							Enumerations.EXPLOSION_TYPE_BOOMERBILE:
								AudioGlobal.play_sound("resources/snds/ceda_jar_explode.wav");
								_boomer_bile_sources.push_back([explosion.position, (randi() % 5)+14]);
								regenerate_infected_distance_field();
								pass;
							Enumerations.EXPLOSION_TYPE_FIRE:
								AudioGlobal.play_sound("resources/snds/ceda_jar_explode.wav");
								pass;
							Enumerations.EXPLOSION_TYPE_NORMAL:
								AudioGlobal.play_sound("resources/snds/pipebomb/explode.wav");
								for entity in _entities.entities:
									if explosion.position.distance_squared_to(entity.position) <= explosion.radius * explosion.radius:
										entity.health -= 100;
								pass;

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
