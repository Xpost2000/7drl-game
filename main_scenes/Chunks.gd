# Should rename this later...
extends Node2D
const TILE_SIZE = 32;
const PriorityQueue = preload("res://main_scenes/PriorityQueue.gd");

export var CHUNK_MAX_SIZE = 16;
onready var _fog_of_war = $FogOfWar;

func in_bounds_of(position, chunk_x, chunk_y) -> bool:
	return (position.x >= chunk_x*CHUNK_MAX_SIZE && position.x < (chunk_x + CHUNK_MAX_SIZE)) && (position.y >= chunk_y*CHUNK_MAX_SIZE && position.y < (chunk_y + CHUNK_MAX_SIZE));

var world_chunks = [];
func clear():
	for chunk_row in world_chunks:
		for chunk in chunk_row:
			chunk.clear();
		
const neighbor_vectors = [Vector2(-1, 0),
						  Vector2(1, 0),
						  Vector2(0, 1),
						  Vector2(0, -1),
						  Vector2(1, 1),
						  Vector2(-1, 1),
						  Vector2(1, -1),
						  Vector2(-1, -1),
						  ];

func calculate_chunk_position(absolute_position):
	return Vector2(int(absolute_position.x / CHUNK_MAX_SIZE), int(absolute_position.y / CHUNK_MAX_SIZE));

# for now keep this in sync with tileset...
export var _solid_cells_list = [0, 8, 9];
func is_solid_tile(position) -> bool:
	var cell_at_position = get_cell(position);
	if cell_at_position:
		for cell in _solid_cells_list:
			if cell == cell_at_position[0]:
				return true;
	return false;

# provide world generation algorithms.
class WorldChunk:
	func _init(size):
		self.size = size;
		var visibility_result = [];
		var chunk_result = [];
		self.dirty_cells = [];
		for y in range(size):
			var row = [];
			var visibility_row = [];
			for x in range(size):
				row.push_back(0);
				visibility_row.push_back(0);
				self.dirty_cells.push_back(Vector2(x, y));
			chunk_result.push_back(row);
			visibility_result.push_back(visibility_row);
		self.cells = chunk_result;
		self.visible_cells = visibility_result;

	func mark_all_dirty():
		for y in range(size):
			for x in range(size):
				var any_animated = false;
				for animated_cell in animated_cells:
					if animated_cell[0].x == x && animated_cell[0].y == y:
						any_animated = true;
						break;
				if not any_animated:
					self.dirty_cells.push_back(Vector2(x, y));

	func clear():
		for y in range(size):
			for x in range(size):
				set_cell(x, y, 0);
				set_cell_visible(x, y, 0.0);
		
	func clear_dirty():
		dirty_cells = [];

	func get_cell(x, y):
		return cells[y][x];

	func is_cell_visible(x, y):
		return visible_cells[y][x];

	# Technically we shouldn't be doing dirty cells for this one but whatever.
	func set_cell_visible(x, y, val):
		visible_cells[y][x] = val;
		self.dirty_cells.push_back(Vector2(x, y));

	func set_cell(x, y, val, bloody=false):
		for animated_cell in animated_cells:
			var position_of_cell = animated_cell[0];
			if position_of_cell.x == x && position_of_cell.y == y:
				animated_cells.erase(animated_cell);
				break;

		cells[y][x] = [val, bloody];
		self.dirty_cells.push_back(Vector2(x, y));

	var size: int;
	var cells: Array;
	var visible_cells: Array;
	var animated_cells: Array;
	# for repainting
	var dirty_cells: Array;

func in_bounds(where):
	return (where.y >= 0 && where.y < len(world_chunks)) && where.x >= 0 && where.x < len(world_chunks[where.y]);

func get_chunk_at(where):
	var current_chunk_location = calculate_chunk_position(where); 
	if where.x >= 0 && where.y >= 0 && in_bounds(current_chunk_location):
		return world_chunks[current_chunk_location.y][current_chunk_location.x];
	return null;
func set_cell_gore(where, value):
	var current_chunk_location = calculate_chunk_position(where); 
	var chunk = get_chunk_at(where);
	where -= current_chunk_location * CHUNK_MAX_SIZE;
	if chunk:
		chunk.set_cell(where.x, where.y, chunk.get_cell(where.x, where.y)[0], value);
func set_cell(where, value):
	var current_chunk_location = calculate_chunk_position(where); 
	var chunk = get_chunk_at(where);
	where -= current_chunk_location * CHUNK_MAX_SIZE;
	if chunk:
		chunk.set_cell(where.x, where.y, value);
func get_cell(where):
	var current_chunk_location = calculate_chunk_position(where); 
	var chunk = get_chunk_at(where);
	where -= current_chunk_location * CHUNK_MAX_SIZE;
	if chunk:
		return chunk.get_cell(where.x, where.y);
	return null;

func set_cell_visibility(where, value):
	var current_chunk_location = calculate_chunk_position(where); 
	var chunk = get_chunk_at(where);
	where -= current_chunk_location * CHUNK_MAX_SIZE;
	if chunk:
		chunk.set_cell_visible(where.x, where.y, value);
func is_cell_visible(where):
	var current_chunk_location = calculate_chunk_position(where); 
	var chunk = get_chunk_at(where);
	where -= current_chunk_location * CHUNK_MAX_SIZE;
	if chunk:
		return chunk.is_cell_visible(where.x, where.y);
	return null;

# filter for visited tiles only. (fog of war needs to do things)
func neighbors(chunks, point, entities=null):
	var valid_neighbors = [];
	for neighbor in neighbor_vectors:
		var new_point = point + neighbor;
		if chunks.get_chunk_at(new_point) and not chunks.is_solid_tile(new_point):
			if entities:
				if not entities.get_entity_at_position(new_point):
					valid_neighbors.push_back(new_point);
			else:
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

func request_path_from_to(start, end):
	var frontier = [start];
	var visited = {};
	var origins = {};

	while len(frontier):
		var current = frontier.pop_front();
		if get_chunk_at(current):
			for neighbor in neighbors(self, current):
				if not (neighbor in visited):
					visited[neighbor] = true;
					origins[neighbor] = current;
					frontier.push_back(neighbor);

		visited[current] = true;
		if current == end:
			return trace_path(current, origins);
	return null;

func manhattan_distance_heuristic(a, b):
	return abs(a.x - b.x) + abs(a.y - b.y);

func a_star_request_path_from_to(start, end):
	var frontier = PriorityQueue.new();
	frontier.push(start, 0);
	var visited = {};
	var origins = {};
	var distance_scores = {start: 0};

	while frontier.length():
		var current = frontier.pop();
		if get_chunk_at(current):
			for neighbor in neighbors(self, current):
				var current_score = distance_scores[current] if current in distance_scores else 0;
				var neighbor_score = distance_scores[neighbor] if neighbor in distance_scores else 0;
				var movement_distance = current_score + neighbor_score + 1 + manhattan_distance_heuristic(neighbor, end);

				if not (neighbor in visited) or movement_distance < neighbor_score:
					visited[neighbor] = true;
					distance_scores[neighbor] = movement_distance;
					origins[neighbor] = current;
					frontier.push(neighbor, movement_distance);
		visited[current] = true;

		if current == end:
			return trace_path(current, origins);
	return null;

# This is an example of how I should use the distance field.
# only accounts for solid blocks. Not entities in the way.
func distance_field_next_best_position(distance_field, from, entities=null):
	if from in distance_field:
		var result_position = from;
		var minimum_neighbor = distance_field[from];
		for neighbor in neighbors(self, from, entities):
			if neighbor in distance_field:
				var neighbor_cell = distance_field[neighbor]; 
				if not minimum_neighbor or neighbor_cell < minimum_neighbor:
					minimum_neighbor = neighbor_cell;
					result_position = neighbor;
		return result_position;
	return from;
	
func distance_field_map_from(starts):
	var frontier = [];
	var visited = {};
	var distance_scores = {};
	for start in starts:
		frontier.push_back(start[0]);
		distance_scores[start[0]] = 0 if len(start) == 1 else start[1];

	while len(frontier):
		var current = frontier.pop_front();
		if get_chunk_at(current):
			for neighbor in neighbors(self, current):
				var current_score = distance_scores[current] if current in distance_scores else 0;
				var neighbor_score = distance_scores[neighbor] if neighbor in distance_scores else 0;
				var movement_distance = current_score + neighbor_score + 1;

				if not (neighbor in visited) or movement_distance < neighbor_score:
					visited[neighbor] = true;
					distance_scores[neighbor] = movement_distance;
					frontier.push_back(neighbor);
		visited[current] = true;
	return distance_scores;

func _ready():
	randomize();
	world_chunks = [
		[WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE)],
		[WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE)],
		[WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE)],
		[WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE)],
			  ];
	pass;

var _global_tile_tick_frame = 0;
func paint_animated_tiles(tilemap, chunk, chunk_x, chunk_y):
	for animated_cell_datum in chunk.animated_cells:
		var cell = animated_cell_datum[0];
		var cell_frames = animated_cell_datum[2];
		var cell_id = animated_cell_datum[1] + _global_tile_tick_frame % cell_frames;
		var x = cell.x;
		var y = cell.y;

		tilemap.set_cell(x + (chunk_x * CHUNK_MAX_SIZE), y + (chunk_y * CHUNK_MAX_SIZE), cell_id);

func repaint_animated_tiles(current_chunk_position):
	var chunk_offsets = neighbor_vectors.duplicate();
	chunk_offsets.push_back(Vector2(0, 0));
	for neighbor_index in len(chunk_offsets):
		var neighbor_vector = chunk_offsets[neighbor_index];
		var offset_position = current_chunk_position + neighbor_vector;
		
		if in_bounds(offset_position):
			get_child(neighbor_index).show();
			call_deferred("paint_animated_tiles", get_child(neighbor_index), world_chunks[offset_position.y][offset_position.x], offset_position.x, offset_position.y);
		else:
			get_child(neighbor_index).hide();

# The current tileset shows the "invisible cell" as id 14.
# Obviously change this for the real stuff.
func paint_chunk_to_tilemap(tilemap, chunk, chunk_x, chunk_y):
	for dirty_cell in chunk.dirty_cells:
		var x = dirty_cell.x;
		var y = dirty_cell.y;
		tilemap.set_cell(x + (chunk_x * CHUNK_MAX_SIZE), y + (chunk_y * CHUNK_MAX_SIZE), chunk.get_cell(x, y)[0]);
		_fog_of_war.set_cell(x + (chunk_x * CHUNK_MAX_SIZE), y + (chunk_y * CHUNK_MAX_SIZE), 1 - chunk.is_cell_visible(x, y));
	chunk.clear_dirty();

var _tick_time = 0;

func inclusively_redraw_chunks_around(chunk_position):
	if _tick_time > 0.15:
		repaint_animated_tiles(chunk_position);
	else:
		_global_tile_tick_frame += 1;

	var chunk_offsets = neighbor_vectors.duplicate();
	chunk_offsets.push_back(Vector2(0, 0));
	for neighbor_index in len(chunk_offsets):
		var neighbor_vector = chunk_offsets[neighbor_index];
		var offset_position = chunk_position + neighbor_vector;
		
		if in_bounds(offset_position):
			get_child(neighbor_index).show();
			paint_chunk_to_tilemap(get_child(neighbor_index), world_chunks[offset_position.y][offset_position.x], offset_position.x, offset_position.y);
		else:
			get_child(neighbor_index).hide();


func _process(delta):
	if _tick_time > 0.15:
		_tick_time = 0;
	else:
		_tick_time += delta;
