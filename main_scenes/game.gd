extends Node2D

onready var _world_map = $ChunkViews/Current;
onready var _message_log = $InterfaceLayer/Interface/Messages;
onready var _entity_sprites = $EntitySprites;

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

func update_player(player_entity):
	if not player_entity.is_dead():
		var move_result = $Entities.move_entity(player_entity, player_movement_direction());

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

func _ready():
	$Entities.add_entity("Sean", Vector2.ZERO);
	$Entities.entities[0].flags = 1;
	$Entities.entities[0].position = Vector2(0, 0);
	$Entities.add_entity("Martin", Vector2(3, 4));
	$Entities.add_entity("Brandon", Vector2(3, 3));
	$ChunkViews.set_cell(Vector2(1, 0), 8);
	$ChunkViews.set_cell(Vector2(1, 1), 8);
	$ChunkViews.set_cell(Vector2(3, 0), 8);
	_last_known_current_chunk_position = $ChunkViews.calculate_chunk_position($Entities.entities[0].position);
	setup_ui();

func _draw():
	pass;

func _process(_delta):
	var current_chunk_position = $ChunkViews.calculate_chunk_position($Entities.entities[0].position);
	if _last_known_current_chunk_position != current_chunk_position:
		for chunk_row in $ChunkViews.world_chunks:
			for chunk in chunk_row:
				chunk.mark_all_dirty();
		for chunk_view in $ChunkViews.get_children():
			chunk_view.clear();
		$ChunkViews.inclusively_redraw_chunks_around(current_chunk_position);
		$ChunkViews.repaint_animated_tiles(current_chunk_position);

	$ChunkViews.inclusively_redraw_chunks_around(current_chunk_position);

	$CameraTracer.position = $Entities.entities[0].associated_sprite_node.global_position;
	update_player($Entities.entities[0]);

	var distance_field = $ChunkViews.distance_field_map_from($ChunkViews, $Entities.entities[0].position);
	$Entities.entities[1].position = $ChunkViews.distance_field_next_best_position($ChunkViews, distance_field, Vector2(3, 3));

	if ($Entities.entities[0].is_dead()):
		$InterfaceLayer/Interface/Death.show();
		$InterfaceLayer/Interface/Ingame.hide();

	_last_known_current_chunk_position = current_chunk_position;

func _physics_process(_delta):
	pass;
