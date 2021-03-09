extends ColorRect

# TODO replace with timer callbacks.
export(float) var dimmer_max_time = 1.0;
export(float) var hang_max_time = 1.0;

export(float) var dimmer_timer = 0;
export(float) var hang_time = 0;

export(bool) var fade_in = true;
export(bool) var disabled = false;

signal finished;
signal start_fade_in;
signal start_fade_out;

func _ready():
	print("ready for action");

func finished_fade():
	return dimmer_timer >= dimmer_max_time;

func begin_fade_in():
	fade_in = true;
	dimmer_timer = 0;
	emit_signal("start_fade_in");

func begin_fade_out():
	fade_in = false;
	dimmer_timer = 0;
	emit_signal("start_fade_out");

func _process(delta):
	if !disabled:
		if fade_in:
			color.a = dimmer_timer / dimmer_max_time;
		else:
			color.a = 1.0 - (dimmer_timer/dimmer_max_time);

		if !finished_fade():
			dimmer_timer += delta;
			dimmer_timer = clamp(dimmer_timer, 0.0, dimmer_max_time);
		else:
			if hang_time < hang_max_time:
				hang_time += delta;
			else:
				emit_signal("finished");
