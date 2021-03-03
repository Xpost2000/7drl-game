extends Node2D

var _turn_scheduler;

onready var _camera = $GameCamera;
onready var _world = $ChunkViews;
onready var _entities = $Entities;
onready var _message_log = $InterfaceLayer/Interface/Messages;

func create_tween(node_to_tween, property, start, end, tween_fn, tween_ease, time=1.0, delay=0.0):
	var new_tween = Tween.new();
	new_tween.interpolate_property(node_to_tween, property, start, end, time, tween_fn, tween_ease, delay)
	new_tween.connect("tween_all_completed", self, "remove_child", [new_tween]);
	new_tween.connect("tween_all_completed", new_tween, "queue_free");
	add_child(new_tween);
	return new_tween;

func movement_tween(node, start, end):
	create_tween(node, "position", start, end, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.25).start();

func bump_tween(node, start, direction):
	var first = create_tween(node, "position", start, start + direction * ($ChunkViews.TILE_SIZE/2), Tween.TRANS_LINEAR, Tween.EASE_IN, 0.25);
	first.start();
	var second = create_tween(node, "position", start + direction * ($ChunkViews.TILE_SIZE/2), start, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.25);

	first.connect("tween_all_completed", second, "start");

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

func update_player_visibility(player_entity):
	if not player_entity.is_dead():
		var move_result = _entities.move_entity(player_entity, player_movement_direction());

		if Input.is_action_just_pressed("ui_end"):
			player_entity.health = 0;
			_message_log.push_message("You have chosen to die.");

		var player_visibility_radius = 5;
		for y_distance in range(-player_visibility_radius, player_visibility_radius):
			for x_distance in range(-player_visibility_radius, player_visibility_radius):
				var cell_position = player_entity.position + Vector2(x_distance, y_distance);
				if cell_position.distance_squared_to(player_entity.position) <= player_visibility_radius*player_visibility_radius:
					if player_entity.can_see_from($ChunkViews, cell_position):
						$ChunkViews.set_cell_visibility(cell_position, true);

		match move_result:
			Enumerations.COLLISION_HIT_WALL: _message_log.push_message("You bumped into a wall.");
			Enumerations.COLLISION_HIT_WORLD_EDGE: _message_log.push_message("You hit the edge of the world.");
			Enumerations.COLLISION_HIT_ENTITY: _message_log.push_message("You bumped into someone");

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

func _ready():
	_entities.add_entity("Sean", Vector2.ZERO);
	_entities.entities[0].flags = 1;
	_entities.entities[0].position = Vector2(0, 0);
	_entities.add_entity("Martin", Vector2(3, 4));
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
	$CameraTracer.position = _entities.entities[0].associated_sprite_node.global_position;
	# update_player(_entities.entities[0]);

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
			if entity.wait_time <= 0:
				_turn_scheduler.push(entity, entity.turn_speed);
			else:
				entity.wait_time -= 1;
