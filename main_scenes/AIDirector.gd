# For now this guy just spawns zombies in hopefully fair-ish ways...
# Director doesn't spawn items dynamically like the real one... I may
# do that if there's time.
extends Node

var game_state = null;

export var director_think_delay = 4;
var director_think_tick = 0;

func _ready():
	pass # Replace with function body.

# score until director will choose to spawn something
export var director_calmness_score_threshold = 100;
# Threshold that makes director with-hold a spawn.
export var mercy_threshold = 0.65;
var calmness_score = 50;

func try_to_decorate_world_with_witches():
	# would require a list of rooms to decorate with to start with.
	pass;

func on_new_world():
	director_think_tick = 0;
	calmness_score = 50;
	try_to_decorate_world_with_witches();
	
func should_spawn_infected():
	return (calmness_score >= director_calmness_score_threshold);

enum InfectedSpawnTypes {
	CALM_HORDE,
	AGGRESSIVE_HORDE,
	TANK,
	BOOMER,
	SMOKER,
	HUNTER,
	HORDE_AND_BOOMER
};

func score_of(infected_type):
	match infected_type:
		InfectedSpawnTypes.CALM_HORDE: return 150;
		InfectedSpawnTypes.AGGRESSIVE_HORDE: return 190;
		InfectedSpawnTypes.TANK: return 320;
		InfectedSpawnTypes.BOOMER: return 180;
		InfectedSpawnTypes.SMOKER: return 190;
		InfectedSpawnTypes.HUNTER: return 190;
		InfectedSpawnTypes.HORDE_AND_BOOMER: return 220;
		
func spawn_common_infected_horde_block(where, radius):
	for y_position in range(radius):
		for x_position in range(radius):
			game_state.make_common_infected_chaser(Vector2(x_position, y_position) + where);
			
# When doing dungeon generation place "spawn markers" around landmarks
# This usually just means rooms or buildings.
# Then scan through them here, and decide if I can fit what I need and then spawn them.
func find_best_block_placement_position(block_size, minimum_distance=-1):
	return Vector2.ZERO;
			
func do_spawn_of(infected_type):
	if infected_type == InfectedSpawnTypes.CALM_HORDE:
		var position = find_best_block_placement_position(3);
		spawn_common_infected_horde_block(position, 3);
	
func choose_infected_type_to_spawn():
	return InfectedSpawnTypes.CALM_HORDE;

func step_round(_delta):
	print("THINK DIRECTOR");
	calmness_score = min(calmness_score, 430);
	if director_think_tick <= 0:
		director_think_tick = director_think_delay;
		print(calmness_score);
		if (randf() > mercy_threshold) and should_spawn_infected():
			print("Would choose to spawn stuff!");
			var chosen_infected_type = choose_infected_type_to_spawn();
			do_spawn_of(chosen_infected_type);
			calmness_score -= score_of(chosen_infected_type);
			print(chosen_infected_type);
		else:
			print("not spawning yet!");
	else:
		director_think_tick -= 1;
