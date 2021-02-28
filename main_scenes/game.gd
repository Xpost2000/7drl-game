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

const TILE_SIZE = 32;
const CHUNK_SIZE = 16;

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
	var first = create_tween(node, "position", start, start + direction * (TILE_SIZE/2), Tween.TRANS_LINEAR, Tween.EASE_IN, 0.25);
	first.start();
	var second = create_tween(node, "position", start + direction * (TILE_SIZE/2), start, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.25);

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

# for now keep this in sync with tileset...
var _solid_cells_list = [8, 9];
func in_bounds_of(world_map, position, chunk_x, chunk_y) -> bool:
	return (position.x >= chunk_x*CHUNK_SIZE && position.x < (chunk_x + CHUNK_SIZE)) && (position.y >= chunk_y*CHUNK_SIZE && position.y < (chunk_y + CHUNK_SIZE));

func is_solid_tile(world_map, position) -> bool:
	# this shouldn't happen, however it is cause the tiles are relative to the chunk position.
	if in_bounds_of(world_map, position, 0, 0):
		var cell_at_position = world_map.get_cell(position.x, position.y);
		for cell in _solid_cells_list:
			if cell == cell_at_position:
				return true;
	return false;

# might be uber class?
# everything will probably only have one turn, to be safe?
# TODO support multi turn entities
func calculate_chunk_position(absolute_position):
	return Vector2(int(absolute_position.x / CHUNK_SIZE), int(absolute_position.y / CHUNK_SIZE));
class Entity:
	func _init(sprite):
		self.associated_sprite_node = sprite;

	func calculate_current_chunk_position():
		return Vector2(int(position.x / CHUNK_SIZE), int(position.y / CHUNK_SIZE));

	var name: String;
	var health: int;
	var position: Vector2;
	var associated_sprite_node: Sprite;
var entities = [];
func remove_entity_at_index(index):
	var sprite = entities[index].associated_sprite_node;
	entities.remove(index);
	_entity_sprites.remove_child(sprite);
	sprite.queue_free();

func add_entity(name, position):
	var sprite = Sprite.new();

	var atlas_texture = AtlasTexture.new();
	atlas_texture.atlas = load("res://resources/ProjectUtumno_full.png");
	atlas_texture.region = Rect2(450, 1890, 30, 30);

	sprite.texture = atlas_texture;
	_entity_sprites.add_child(sprite);

	var new_entity = Entity.new(sprite);
	new_entity.name = name;
	new_entity.position = position;

	entities.push_back(new_entity);
	return new_entity;

const HIT_WALL = 0;
const HIT_WORLD_EDGE = 1;
const NO_COLLISION = 2;
func move_entity(entity, direction):
	var sprite_node = entity.associated_sprite_node;
	var chunk_position = entity.calculate_current_chunk_position();
	var current_chunk = $ChunkViews.world_chunks[chunk_position.y][chunk_position.x];

	sprite_node.position = (entity.position+Vector2(0.5, 0.5)) * TILE_SIZE;
	if direction != Vector2.ZERO:
		var new_position = entity.position + direction;

		var in_world_bounds = (new_position.x >= 0) && (new_position.y >= 0) && $ChunkViews.in_bounds(calculate_chunk_position(new_position));
		var in_bounds = in_bounds_of(current_chunk, new_position, chunk_position.x, chunk_position.y);
		var hitting_wall = is_solid_tile(current_chunk, new_position - Vector2(chunk_position.x * CHUNK_SIZE, chunk_position.y * CHUNK_SIZE));
		if in_bounds && not hitting_wall:
			entity.position = new_position;
		else:
			if hitting_wall:
				return HIT_WALL;
			elif not in_bounds:
				if in_world_bounds:
					entity.position = new_position;
					return NO_COLLISION;
				else:
					return HIT_WORLD_EDGE;

func update_player(player_entity):
	var move_result = move_entity(player_entity, player_movement_direction());
	match move_result:
		HIT_WALL: _message_log.push_message("You bumped into a wall.");
		HIT_WORLD_EDGE: _message_log.push_message("You hit the edge of the world.");

class WorldChunk:
	func _init():
		var chunk_result = [];
		self.dirty_cells = [];
		for y in range(CHUNK_SIZE):
			var row = [];
			for x in range(CHUNK_SIZE):
				var probability = randf();
				if probability > 0.7:
					row.push_back(0);
				elif probability > 0.4: 
					row.push_back(1);
				else:
					# This push is for collision detection. Auxiliary holder
					row.push_back(10);
					# Animated cells draw on top of "real" cells.
					# maybe this should be a dictionary.
					animated_cells.push_back([Vector2(x, y), 10, 4]);
				self.dirty_cells.push_back(Vector2(x, y));
			chunk_result.push_back(row);
		self.cells = chunk_result;

	func mark_all_dirty():
		for y in range(CHUNK_SIZE):
			for x in range(CHUNK_SIZE):
				var any_animated = false;
				for animated_cell in animated_cells:
					if animated_cell[0].x == x && animated_cell[0].y == y:
						any_animated = true;
						break;
				if not any_animated:
					self.dirty_cells.push_back(Vector2(x, y));

	func clear_dirty():
		dirty_cells = [];

	func get_cell(x, y):
		return cells[y][x];

	func set_cell(x, y, val):
		for animated_cell in animated_cells:
			var position_of_cell = animated_cell[0];
			if position_of_cell.x == x && position_of_cell.y == y:
				animated_cells.erase(animated_cell);
				break;

		cells[y][x] = val;
		self.dirty_cells.push_back(Vector2(x, y));

	var cells: Array;
	var animated_cells: Array;
	# for repainting
	var dirty_cells: Array;

var _last_known_current_chunk_position;
func _ready():
	add_entity("Sean", Vector2.ZERO);
	_last_known_current_chunk_position = entities[0].calculate_current_chunk_position();

# yes this is probably very slow. I'm trying to go as far as I can with the
# engine is just my client approach, since it's easier for me to do that.
func paint_chunk_to_tilemap(tilemap, chunk, chunk_x, chunk_y):
	for dirty_cell in chunk.dirty_cells:
		var x = dirty_cell.x;
		var y = dirty_cell.y;
		tilemap.set_cell(x + (chunk_x * CHUNK_SIZE), y + (chunk_y * CHUNK_SIZE), chunk.get_cell(x, y));

	chunk.clear_dirty();

var _global_tile_tick_frame = 0;
func paint_animated_tiles(tilemap, chunk, chunk_x, chunk_y):
	for animated_cell_datum in chunk.animated_cells:
		var cell = animated_cell_datum[0];
		var cell_frames = animated_cell_datum[2];
		var cell_id = animated_cell_datum[1] + _global_tile_tick_frame % cell_frames;
		var x = cell.x;
		var y = cell.y;

		tilemap.set_cell(x + (chunk_x * CHUNK_SIZE), y + (chunk_y * CHUNK_SIZE), cell_id);

const neighbor_vectors = [Vector2(-1, 0),
						  Vector2(1, 0),
						  Vector2(0, 1),
						  Vector2(0, -1),
						  Vector2(1, 1),
						  Vector2(-1, 1),
						  Vector2(1, -1),
						  Vector2(-1, -1),
						  ];

func repaint_animated_tiles():
	var current_chunk_position = entities[0].calculate_current_chunk_position();

	var chunk_offsets = neighbor_vectors.duplicate();
	chunk_offsets.push_back(Vector2(0, 0));
	for neighbor_index in len(chunk_offsets):
		var neighbor_vector = chunk_offsets[neighbor_index];
		var offset_position = current_chunk_position + neighbor_vector;
		
		if $ChunkViews.in_bounds(offset_position):
			$ChunkViews.get_child(neighbor_index).show();
			call_deferred("paint_animated_tiles", $ChunkViews.get_child(neighbor_index), $ChunkViews.world_chunks[offset_position.y][offset_position.x], offset_position.x, offset_position.y);
		else:
			$ChunkViews.get_child(neighbor_index).hide();



var _tick_time = 0;

func _process(_delta):
	var current_chunk_position = entities[0].calculate_current_chunk_position();
	if _last_known_current_chunk_position != current_chunk_position:
		for chunk_row in $ChunkViews.world_chunks:
			for chunk in chunk_row:
				chunk.mark_all_dirty();
		for chunk_view in $ChunkViews.get_children():
			chunk_view.clear();

		var chunk_offsets = neighbor_vectors.duplicate();
		chunk_offsets.push_back(Vector2(0, 0));
		for neighbor_index in len(chunk_offsets):
			var neighbor_vector = chunk_offsets[neighbor_index];
			var offset_position = current_chunk_position + neighbor_vector;
			
			if $ChunkViews.in_bounds(offset_position):
				$ChunkViews.get_child(neighbor_index).show();
				paint_chunk_to_tilemap($ChunkViews.get_child(neighbor_index), $ChunkViews.world_chunks[offset_position.y][offset_position.x], offset_position.x, offset_position.y);
			else:
				$ChunkViews.get_child(neighbor_index).hide();
		repaint_animated_tiles();

	if _tick_time > 0.15:
		repaint_animated_tiles();
		_tick_time = 0;
	else:
		_tick_time += _delta;
		_global_tile_tick_frame += 1;

	var chunk_offsets = neighbor_vectors.duplicate();
	chunk_offsets.push_back(Vector2(0, 0));
	for neighbor_index in len(chunk_offsets):
		var neighbor_vector = chunk_offsets[neighbor_index];
		var offset_position = current_chunk_position + neighbor_vector;
		

		if $ChunkViews.in_bounds(offset_position):
			$ChunkViews.get_child(neighbor_index).show();
			paint_chunk_to_tilemap($ChunkViews.get_child(neighbor_index), $ChunkViews.world_chunks[offset_position.y][offset_position.x], offset_position.x, offset_position.y);
		else:
			$ChunkViews.get_child(neighbor_index).hide();

	$CameraTracer.position = entities[0].associated_sprite_node.global_position;
	update_player(entities[0]);
	_last_known_current_chunk_position = current_chunk_position;

func _physics_process(_delta):
	pass;
