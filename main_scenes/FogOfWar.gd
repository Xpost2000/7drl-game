extends Node2D
var _cells = {};

func set_cell(x, y, val):
	_cells[Vector2(x, y)] = val;
	update();

func _ready():
	pass

func clear():
	_cells.clear();

func _draw():
	for cell in _cells:
		draw_rect( Rect2( cell[0] * Enumerations.TILE_SIZE,
							cell[1] * Enumerations.TILE_SIZE,
							Enumerations.TILE_SIZE,
							Enumerations.TILE_SIZE), 
							Color(0, 0, 0, _cells[cell]));

func _process(_delta):
	pass;
