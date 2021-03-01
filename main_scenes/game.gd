extends Node2D

# Just quickly seeing what would get me a decent organization structure.
# Doing a roguelike might require me to do a lot of perversion of the idiomatic godot way
# in which case I'm just writing a python roguelike engine and using godot as my driver/client...
# Which works I guess?

# It gets stuff done really fast even though it ain't maintainable. If godot supported less node based modules
# it'd be way easier to do things...

# Particularly the turnbased part. As to avoid giving myself a headache I can just
# register the turns centrally here...
# If it were real time, I'd do the nodes...

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
	$ChunkViews.set_cell(Vector2(1, 0), 8);
	$ChunkViews.set_cell(Vector2(1, 1), 8);
	$ChunkViews.set_cell(Vector2(3, 0), 8);
	_last_known_current_chunk_position = $ChunkViews.calculate_chunk_position($Entities.entities[0].position);
	setup_ui();

func _draw():
	pass;

# BFS search for now. Since it's the one I can do off the top of my head.
# This is for a chunked path since there's not a good way to make this generic...
# Thankfully I can just make a game one giant chunk and that would also let this work...
const neighbor_vectors = [Vector2(-1, 0),
						Vector2(1, 0),
						Vector2(0, 1),
						Vector2(0, -1),
						Vector2(1, 1),
						Vector2(-1, 1),
						Vector2(1, -1),
						Vector2(-1, -1), ];
func neighbors(chunks, point):
	var valid_neighbors = [];
	for neighbor in neighbor_vectors:
		var new_point = point + neighbor;
		if not chunks.is_solid_tile(new_point):
			valid_neighbors.push_back(new_point);
	return valid_neighbors;

func trace_path(start, origins):
	var current = start;
	var final_path = [];
	while current in origins:
		final_path.push_front(current);
		current = origins[current];
	final_path.push_front(current);
	return final_path;

func request_path_from_to(chunks, start, end):
	var frontier = [start];
	var visited = {};
	var origins = {};

	while len(frontier):
		var current = frontier.pop_front();
		if chunks.get_chunk_at(current):
			for neighbor in neighbors(chunks, current):
				if not (neighbor in visited):
					visited[neighbor] = true;
					origins[neighbor] = current;
					frontier.push_back(neighbor);

		visited[current] = true;
		if current == end:
			return trace_path(current, origins);
	return null;


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

	if ($Entities.entities[0].is_dead()):
		$InterfaceLayer/Interface/Death.show();
		$InterfaceLayer/Interface/Ingame.hide();

	_last_known_current_chunk_position = current_chunk_position;

func _physics_process(_delta):
	pass;
