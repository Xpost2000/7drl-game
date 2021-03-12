extends Node

var game_state = null;

export var director_think_delay = 4;
var director_think_tick = 0;

func _ready():
	pass # Replace with function body.

# score until director will choose to spawn something
export var director_calmness_score_threshold = 100;
var calmness_score = 50;

func on_new_world():
	
func step_round(_delta):
	if director_think_tick <= 0:
		director_think_tick = director_think_delay;
		print("director think");
	else:
		director_think_tick -= 1;
