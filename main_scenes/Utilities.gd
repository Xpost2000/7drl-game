extends Node;
onready var _global_rng = RandomNumberGenerator.new();

func random_nth(list):
	var random_index = _global_rng.randi_range(0, len(list)-1);
	return list[random_index];

func create_tween(node_to_tween, property, start, end, tween_fn, tween_ease, time=1.0, delay=0.0):
	var new_tween = Tween.new();
	new_tween.interpolate_property(node_to_tween, property, start, end, time, tween_fn, tween_ease, delay)
	new_tween.connect("tween_all_completed", self, "remove_child", [new_tween]);
	new_tween.connect("tween_all_completed", new_tween, "queue_free");
	add_child(new_tween);
	return new_tween;

func movement_tween(node, start, end):
	create_tween(node, "position", start, end, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.25).start();

func bump_tween(node, start, direction):
	var first = create_tween(node, "position", start, start + direction * ($ChunkViews.TILE_SIZE/2), Tween.TRANS_LINEAR, Tween.EASE_IN, 0.25);
	first.start();
	var second = create_tween(node, "position", start + direction * ($ChunkViews.TILE_SIZE/2), start, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.25);

	first.connect("tween_all_completed", second, "start");

	# Should probably do some reading on resources.
func read_entire_file_as_string(file_name):
	var file = File.new();
	file.open(file_name, File.READ);
	return file.get_as_text();

func read_json_no_check(filepath):
	return JSON.parse(Utilities.read_entire_file_as_string(filepath)).get_result();

func write_entire_file_from_string(file_name, string):
	# lifted directly from docs
	var file = File.new();
	file.open(file_name, File.WRITE);
	file.store_string(string);
	file.close();

func get_file_names_of_directory(path):
	var result = [];
	var directory = Directory.new();
	# not error checking
	directory.open(path);

	directory.list_dir_begin();
	var file_name_to_append = directory.get_next();
	while len(file_name_to_append):
		if !directory.current_is_dir():
			result.push_back(file_name_to_append);
		file_name_to_append = directory.get_next();

	return result;
