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
    return self.actors.pop();
func get_current_actor():
    if not finished():
        return self.actors.peek();
    else:
        return null;