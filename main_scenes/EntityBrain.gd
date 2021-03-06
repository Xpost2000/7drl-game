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
class HealingAction:
	func do_action(entities, target):
		print("HEAL ACTION")
		if target.current_medkit.uses_left <= 0:
			target.inventory.erase(target.current_medkit);
			target.current_medkit = null;
			target.use_medkit_timer = 0;
		else:
			target.current_medkit.uses_left -= 1;
			target.use_medkit_timer -= 1;
			var damaged_amount = target.max_health - target.health;
			target.health += (damaged_amount * 0.9235/Globals.HEALING_MEDKIT_TURNS); 
class AttackTurnAction extends TurnAction:
	# Game specific.
	pass

func get_turn_action(entity_self, game_state):
	return WaitTurnAction.new();
