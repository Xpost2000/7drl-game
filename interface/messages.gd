extends VBoxContainer
export var MESSAGE_LIFETIME_MAX = 2.5;

class LabelWithLifetime extends Label:
	func _init(text, lifetime):
		self.text = text;
		self.lifetime = lifetime;
		self.max_lifetime = lifetime;

	func _process(delta):
		self.lifetime -= delta;
		# self.set("custom_colors/font_color", Color(0, 1, 1, self.lifetime / self.max_lifetime));

	func dead():
		return self.lifetime <= 0.0;

	var lifetime: float;
	var max_lifetime: float;

func push_message(message):
	var message_label = LabelWithLifetime.new(message, MESSAGE_LIFETIME_MAX);
	add_child(message_label);

func _process(_delta):
	for message in get_children():
		if message.dead():
			remove_child(message);