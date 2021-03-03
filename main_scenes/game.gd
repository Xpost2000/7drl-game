extends Node2D

var _turn_scheduler;

const EntityBrain = preload("res://main_scenes/EntityBrain.gd");
onready var _camera = $GameCamera;
onready var _world = $ChunkViews;
onready var _entities = $Entities;
onready var _message_log = $InterfaceLayer/Interface/Messages;

func player_movement_direction():
	if Input.is_action_just_pressed("ui_up"):
		return Vector2(0, -1);
	elif Input.is_action_just_pressed("ui_down"):
		return Vector2(0, 1);
	elif Input.is_action_just_pressed("ui_left"):
		return Vector2(-1, 0);
	elif Input.is_action_just_pressed("ui_right"):
		return Vector2(1, 0);

	return Vector2.ZERO;

var _last_known_current_chunk_position;

func quit_game():
	get_tree().quit();
func restart_game():
	get_tree().reload_current_scene();

func setup_ui():
	$InterfaceLayer/Interface/Death/Holder/OptionsLayout/Restart.connect("pressed", self, "restart_game");
	$InterfaceLayer/Interface/Death/Holder/OptionsLayout/Quit.connect("pressed", self, "quit_game");

class TurnSchedulerTurnInformation:
	func _init(actor, turns):
		self.actor = actor;
		self.turns_left = turns;
	var actor: Object;
	var turns_left: int;
class TurnScheduler:
	# Does not do priority sorting yet.
	func push(actor, priority):
		actors.push_back(TurnSchedulerTurnInformation.new(actor, priority));
	func finished():
		return len(actors) == 0 or len(actors) == current_actor_index;
	func next_actor():
		self.current_actor_index += 1;
	func get_current_actor():
		if not finished():
			return self.actors[self.current_actor_index];
		else:
			return null;

	var current_actor_index: int;
	var actors: Array;

var _player = null;
class EntityPlayerBrain extends EntityBrain:
	func get_turn_action(entity_self, game_state):
		var move_direction = game_state.player_movement_direction();
		if move_direction != Vector2.ZERO:
			return EntityBrain.MoveTurnAction.new(move_direction);
		if Input.is_action_just_pressed("game_action_wait"):
			return EntityBrain.WaitTurnAction.new();
		return null;

class EntityRandomWanderingBrain extends EntityBrain:
	func get_turn_action(entity_self, game_state):
		return EntityBrain.MoveTurnAction.new(Utilities.random_nth([Vector2.UP, Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]));

func update_player_visibility(entity, radius):
	for y_distance in range(-radius, radius):
		for x_distance in range(-radius, radius):
			var cell_position = entity.position + Vector2(x_distance, y_distance);
			if cell_position.distance_squared_to(entity.position) <= radius*radius:
				if entity.can_see_from($ChunkViews, cell_position):
					$ChunkViews.set_cell_visibility(cell_position, true);

func present_entity_actions_as_messages(entity, action):
	if entity == _player:
		if action is EntityBrain.WaitTurnAction:
			_message_log.push_message("Waiting turn...");
		elif action is EntityBrain.MoveTurnAction:
			var move_result = _entities.try_move(entity, action.direction);
			match move_result:
				Enumerations.COLLISION_HIT_WALL: _message_log.push_message("You bumped into a wall.");
				Enumerations.COLLISION_HIT_WORLD_EDGE: _message_log.push_message("You hit the edge of the world.");
				Enumerations.COLLISION_HIT_ENTITY: _message_log.push_message("You bumped into someone");

func _ready():
	# Always assume the player is entity 0 for now.
	# Obviously this can always change but whatever.
	_entities.add_entity("Sean", Vector2.ZERO, EntityPlayerBrain.new());
	_entities.entities[0].flags = 1;
	_entities.entities[0].position = Vector2(0, 0);
	_player = _entities.entities[0];
	_entities.connect("_on_entity_do_action", self, "present_entity_actions_as_messages");
	_entities.add_entity("Martin", Vector2(3, 4), EntityRandomWanderingBrain.new());
	_entities.add_entity("Brandon", Vector2(3, 3));
	_world.set_cell(Vector2(1, 0), 8);
	_world.set_cell(Vector2(1, 1), 8);
	_world.set_cell(Vector2(3, 0), 8);
	_last_known_current_chunk_position = _world.calculate_chunk_position(_entities.entities[0].position);

	_turn_scheduler = TurnScheduler.new();
	setup_ui();

func _draw():
	pass;

func rerender_chunks():
	var current_chunk_position = _world.calculate_chunk_position(_entities.entities[0].position);
	if _last_known_current_chunk_position != current_chunk_position:
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
	if (_entities.entities[0].is_dead()):
		$InterfaceLayer/Interface/Death.show();
		$InterfaceLayer/Interface/Ingame.hide();

func _process(_delta):
	rerender_chunks();
	$CameraTracer.position = _player.associated_sprite_node.global_position;
	update_player_visibility(_player, 5);

	if not _turn_scheduler.finished():
		var current_actor_turn_information = _turn_scheduler.get_current_actor();
		if current_actor_turn_information.turns_left > 0:
			var actor = current_actor_turn_information.actor;
			var actor_turn_action = actor.get_turn_action(self);
			if actor_turn_action:
				_entities.do_action(actor, actor_turn_action);
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
