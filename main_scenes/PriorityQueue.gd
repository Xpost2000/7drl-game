# A priority queue backed by a sorted array
var data;
func _init():
	data = [];

func length():
	return len(data) if data else 0;

# if I'm going to sort all the time here at least do insertion sort.
func push(item, priority):
	if len(data) == 0:
		data.push_back([item,priority]);
	else:
		var used_elements = length();
		data.push_back(null);
		var exit_index = 0;
		for index in range(1, used_elements+1):
			if priority >= data[used_elements - index][1]:
				data[used_elements - index + 1] = data[used_elements - index];
			else:
				break;
			exit_index = index;
		data[used_elements - 1 - exit_index + 1] = [item, priority];
	return item;

func peek():
	if data or len(data):
		var value = data[-1][0];
		return value;
	else:
		return null;

func peek_maximum():
	if data or len(data):
		var value = data[0][0];
		return value;
	else:
		return null;

func pop():
	if data or len(data):
		var value = peek();
		data.pop_back();
		return value;
	else:
		return null;

func maximum_pop():
	if data or len(data):
		var value = peek_maximum();
		data.pop_front();
		return value;
	else:
		return null;