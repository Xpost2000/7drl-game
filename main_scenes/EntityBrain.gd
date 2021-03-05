# Rely on type dispatch for things.
# Technically since it's dynamically typed there's no reason to do extends.
# I just want to semantically define it though.
# This is where you define all actions as well I guess.
class TurnAction:
	func do_action(entities, target):
		pass;
class WaitTurnAction:
	func do_action(entities, target):
		pass;
class MoveTurnAction extends TurnAction:
	func _init(direction):
		self.direction = direction;
	func do_action(entities, target):
		entities.move_entity(target, self.direction);
	var direction: Vector2;
class AttackTurnAction extends TurnAction:
	# Game specific.
	pass

func get_turn_action(entity_self, game_state):
    return WaitTurnAction.new();