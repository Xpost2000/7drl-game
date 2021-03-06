extends Node2D

const EntityBrain = preload("res://main_scenes/EntityBrain.gd");
const TurnScheduler = preload("res://main_scenes/TurnScheduler.gd");

var _passed_turns = 0;
var _player = null;
var _last_known_current_chunk_position;
onready var _turn_scheduler = TurnScheduler.new();

onready var _camera = $GameCamera;
onready var _world = $ChunkViews;
onready var _entities = $Entities;
onready var _interface = $InterfaceLayer/Interface;
onready var _ascii_renderer = $CharacterASCIIDraw;

var prompting_item_use = false;

func player_movement_direction():
	if Globals.is_action_pressed_with_delay("ui_up"):
		return Vector2(0, -1);
	elif Globals.is_action_pressed_with_delay("ui_down"):
		return Vector2(0, 1);
	elif Globals.is_action_pressed_with_delay("ui_left"):
		return Vector2(-1, 0);
	elif Globals.is_action_pressed_with_delay("ui_right"):
		return Vector2(1, 0);
	elif Globals.is_action_pressed_with_delay("game_move_diagonal_top_right"):
		return Vector2(1, -1);
	elif Globals.is_action_pressed_with_delay("game_move_diagonal_bottom_right"):
		return Vector2(1, 1);
	elif Globals.is_action_pressed_with_delay("game_move_diagonal_top_left"):
		return Vector2(-1, -1);
	elif Globals.is_action_pressed_with_delay("game_move_diagonal_bottom_left"):
		return Vector2(-1, 1);
	return Vector2.ZERO;

class EntityPlayerBrain extends EntityBrain:
	func get_turn_action(entity_self, game_state):
		if game_state.prompting_item_use:
			var pressed_key = Globals.any_key_pressed();
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
						item_picked.on_use(game_state, entity_self);
						print("using " + item_picked.as_string());
			else:
				pass;
		else:
			var move_direction = game_state.player_movement_direction();
			if move_direction != Vector2.ZERO:
				return EntityBrain.MoveTurnAction.new(move_direction);
			if Input.is_action_just_pressed("game_action_wait"):
				return EntityBrain.WaitTurnAction.new();
			if Input.is_action_just_pressed("game_use_item"):
				game_state.prompting_item_use = true;
				Globals.any_key_pressed();
		return null;

class EntityRandomWanderingBrain extends EntityBrain:
	func get_turn_action(entity_self, game_state):
		return EntityBrain.MoveTurnAction.new(Utilities.random_nth([Vector2.UP, Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]));

func update_player_visibility(entity, radius):	
	# wtf is this indentation?
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
	_entities.add_entity("Sean", Vector2.ZERO, EntityPlayerBrain.new());
	_player = _entities.entities[0];
	_player.flags = 1;
	_player.position = Vector2(0, 0);
	_player.add_item(Globals.Medkit.new());
	var gun = Globals.Gun.new("Assault Rifle");
	gun.capacity = 120;
	gun.current_capacity = 30;
	_player.add_item(gun);
	_entities.connect("_on_entity_do_action", self, "present_entity_actions_as_messages");
	_entities.add_entity("Martin", Vector2(3, 4), EntityRandomWanderingBrain.new());
	_entities.add_entity("Brandon", Vector2(3, 3));
	_world.set_cell(Vector2(1, 0), 8);
	_world.set_cell(Vector2(1, 1), 8);
	_world.set_cell(Vector2(3, 0), 8);
	_last_known_current_chunk_position = _world.calculate_chunk_position(_entities.entities[0].position);

	_ascii_renderer.world = _world;
	_ascii_renderer.entities = _entities;
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
	_passed_turns += 1;

func _process(_delta):
	rerender_chunks();
	$Fixed/Draw.update();

	_interface.report_inventory(_player);
	_interface.report_player_health(_player);

	var healing_display = _interface.get_node("Ingame/HealingDisplay");
	if _player.current_medkit:
		healing_display.show();
	else:
		healing_display.hide();

	if prompting_item_use:
		_interface.get_node("Ingame/ItemPrompt").show();
	else:
		_interface.get_node("Ingame/ItemPrompt").hide();

	if Input.is_action_just_pressed("ui_end"):
		_player.health -= 15;

	if Input.is_action_just_pressed("game_pause"):
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
		if not _turn_scheduler.finished():
			var current_actor_turn_information = _turn_scheduler.get_current_actor();
			if current_actor_turn_information and current_actor_turn_information.turns_left > 0:
				var actor = current_actor_turn_information.actor;
				var actor_turn_action = actor.get_turn_action(self);
				if actor_turn_action:
					_entities.do_action(actor, actor_turn_action);
					_ascii_renderer.update();
					current_actor_turn_information.turns_left -= 1;
			else:
				step(_delta);
				_turn_scheduler.next_actor();
		else:
			for entity in _entities.entities:
				if not entity.is_dead() and entity.wait_time <= 0 :
					_turn_scheduler.push(entity, entity.turn_speed);
				else:
					entity.wait_time -= 1;
