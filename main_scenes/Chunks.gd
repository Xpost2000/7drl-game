# Should rename this later...
extends Node2D

export var CHUNK_MAX_SIZE = 16;

var world_chunks = [];
const neighbor_vectors = [Vector2(-1, 0),
						  Vector2(1, 0),
						  Vector2(0, 1),
						  Vector2(0, -1),
						  Vector2(1, 1),
						  Vector2(-1, 1),
						  Vector2(1, -1),
						  Vector2(-1, -1),
						  ];

class WorldChunk:
	func _init(size):
		self.size = size;
		var chunk_result = [];
		self.dirty_cells = [];
		for y in range(size):
			var row = [];
			for x in range(size):
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
		for y in range(size):
			for x in range(size):
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

	var size: int;
	var cells: Array;
	var animated_cells: Array;
	# for repainting
	var dirty_cells: Array;

func _ready():
	world_chunks = [
		[WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE)],
		[WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE)],
		[WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE), WorldChunk.new(CHUNK_MAX_SIZE)],
			  ];
	pass;

func _process(delta):
	pass;
