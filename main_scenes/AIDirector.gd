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
var calmness_score = 50;

func on_new_world():
	director_think_tick = 0;
	calmness_score = 50;
	
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
		InfectedSpawnTypes.CALM_HORDE: return 36+(randi()%25);
		InfectedSpawnTypes.AGGRESSIVE_HORDE: return 50 + (randi()%15);
		InfectedSpawnTypes.TANK: return 125;
		InfectedSpawnTypes.BOOMER: return 40;
		InfectedSpawnTypes.SMOKER: return 45;
		InfectedSpawnTypes.HUNTER: return 40;
		InfectedSpawnTypes.HORDE_AND_BOOMER: return 70;
		
func do_spawn_of(infected_type):
	print(infected_type);
	
func choose_infected_type_to_spawn():
	return InfectedSpawnTypes.CALM_HORDE;

func step_round(_delta):
	if director_think_tick <= 0:
		director_think_tick = director_think_delay;
		if should_spawn_infected():
			var chosen_infected_type = choose_infected_type_to_spawn();
			do_spawn_of(chosen_infected_type);
			calmness_score -= score_of(chosen_infected_type);
	else:
		director_think_tick -= 1;
