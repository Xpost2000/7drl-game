const PriorityQueue = preload("res://main_scenes/PriorityQueue.gd");
var actors: PriorityQueue;

class TurnSchedulerTurnInformation:
	func _init(actor, turns):
		self.actor = actor;
		self.turns_left = turns;
	var actor: Object;
	var turns_left: int;

# Does not do priority sorting yet.
func _init():
	self.actors = PriorityQueue.new();
func push(actor, priority):
	actors.push(TurnSchedulerTurnInformation.new(actor, priority), priority);
func finished():
	return actors.length() == 0;
func next_actor():
	# self.current_actor_index += 1;
	var current_actor = self.actors.peek();
	if current_actor:
		current_actor.actor.wait_time = current_actor.actor.wait_time_between_turns;
		return self.actors.pop();
	else:
		return null;
func get_current_actor():
	if not finished():
		var current =  self.actors.peek();
		if current and current.actor.is_dead():
			next_actor();
			return get_current_actor();
		else:
			return current;
	else:
		return null;
