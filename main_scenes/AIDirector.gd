# For now this guy just spawns zombies in hopefully fair-ish ways...
# Director doesn't spawn items dynamically like the real one... I may
# do that if there's time.
extends Node

var game_state = null;
var potential_spawn_locations = [];

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
	potential_spawn_locations.clear();
	director_think_tick = 0;
	calmness_score = 50;
	try_to_decorate_world_with_witches();

func add_spawn_location(where):
	potential_spawn_locations.push_back(where);

func should_spawn_infected():
	return (calmness_score >= director_calmness_score_threshold);

enum InfectedSpawnTypes {
	CALM_HORDE,
	AGGRESSIVE_HORDE,
	TANK,
	BOOMER,
	SMOKER,
	#HUNTER,
	#HORDE_AND_BOOMER
};
const IMPOSSIBLE_TO_SPAWN_ANYMORE = -1;

var spawned = {
	#InfectedSpawnTypes.CALM_HORDE: [0, 2],
	InfectedSpawnTypes.AGGRESSIVE_HORDE: [0, 2],
	InfectedSpawnTypes.TANK: [0, 4],
	InfectedSpawnTypes.BOOMER: [0, -1],
	InfectedSpawnTypes.SMOKER: [0, 3],
	#InfectedSpawnTypes.HUNTER: [0, 0],
	#InfectedSpawnTypes.HORDE_AND_BOOMER: [0, 1],
};

func all_spawn_limits_hit():
	for spawn_entry in spawned:
		var entry = spawned[spawn_entry];
		if entry[0] < entry[1]:
			return false;
	return true;

func score_of(infected_type):
	match infected_type:
		#InfectedSpawnTypes.CALM_HORDE: return 150;
		InfectedSpawnTypes.AGGRESSIVE_HORDE: return 190;
		InfectedSpawnTypes.TANK: return 320;
		InfectedSpawnTypes.BOOMER: return 180;
		InfectedSpawnTypes.SMOKER: return 190;
		#InfectedSpawnTypes.HUNTER: return 190;
		#InfectedSpawnTypes.HORDE_AND_BOOMER: return 220;
					
# When doing dungeon generation place "spawn markers" around landmarks
# This usually just means rooms or buildings.
# Then scan through them here, and decide if I can fit what I need and then spawn them.
func find_best_block_placement_position(block_size, minimum_distance_from_player=-1):
	if not potential_spawn_locations.empty():
		var player_location = game_state._player.position;
		# prefer to spawn farther from the player for this case.
		var max_distance = potential_spawn_locations[0].distance_to(player_location);
		
		var best_placement_candidates = [];
		
		for potential_spawn_location in potential_spawn_locations:
			var current_distance = potential_spawn_location.distance_to(player_location);
			var passes_threshold = current_distance  >= minimum_distance_from_player;
			if passes_threshold:
				var block_fits = true;
				for y_displacement in range(-block_size, block_size):
					for x_displacement in range(-block_size, block_size):
						if game_state._world.is_solid_tile(Vector2(x_displacement, y_displacement) + potential_spawn_location):
							block_fits = false;
							break;
					if not block_fits:
						break;
				if max_distance == current_distance:
					best_placement_candidates.push_back(potential_spawn_location);
				elif max_distance < current_distance:
					max_distance = current_distance;
					best_placement_candidates = [potential_spawn_location];
		return Utilities.random_nth(best_placement_candidates);
	return Vector2.ZERO;

func spawn_common_infected_horde_block(where, radius):
	for y_position in range(radius):
		for x_position in range(radius):
			game_state.make_common_infected_chaser(Vector2(x_position, y_position) + where);
			
func spawn_tank(where):
	game_state.make_tank(where);
func spawn_smoker(where):
	game_state.make_smoker(where);
func spawn_boomer(where):
	game_state.make_boomer(where);
			
func do_spawn_of(infected_type):
	if infected_type == InfectedSpawnTypes.AGGRESSIVE_HORDE:
		var position = find_best_block_placement_position(2);
		spawn_common_infected_horde_block(position, 2);
	elif infected_type == InfectedSpawnTypes.TANK:
		var position = find_best_block_placement_position(1, 8);
		spawn_tank(position);
	elif infected_type == InfectedSpawnTypes.BOOMER:
		var position = find_best_block_placement_position(1);
		spawn_boomer(position);
	elif infected_type == InfectedSpawnTypes.SMOKER:
		var position = find_best_block_placement_position(1);
		spawn_smoker(position);
	
# TODO these should be weighted.
func choose_infected_type_to_spawn():
	var chosen = Utilities.weighted_random(
		[
			[InfectedSpawnTypes.AGGRESSIVE_HORDE, 60],
			[InfectedSpawnTypes.TANK, 25],
			[InfectedSpawnTypes.BOOMER, 30],
			[InfectedSpawnTypes.SMOKER, 30],
		]
	);
	if spawned[chosen][0] < spawned[chosen][1]:
		return chosen;
	else:
		var feels_like_rerolling = randf() < 0.6;
		if not all_spawn_limits_hit() and feels_like_rerolling:
			return choose_infected_type_to_spawn();
		else:
			return IMPOSSIBLE_TO_SPAWN_ANYMORE;

func step_round(_delta):
	print("THINK DIRECTOR");
	calmness_score = min(calmness_score, 430);
	if director_think_tick <= 0:
		director_think_tick = director_think_delay;
		print(calmness_score);
		if (randf() > mercy_threshold) and should_spawn_infected():
			print("Would choose to spawn stuff!");
			var chosen_infected_type = choose_infected_type_to_spawn();
			if chosen_infected_type != IMPOSSIBLE_TO_SPAWN_ANYMORE:
				do_spawn_of(chosen_infected_type);
				calmness_score -= score_of(chosen_infected_type);
				print(chosen_infected_type);
		else:
			print("not spawning yet!");
	else:
		director_think_tick -= 1;
