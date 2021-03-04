# A priority queue backed by a sorted array
var data;

func _priority_ordered_sort(a, b):
    return a[1] < b[1];

func length():
    return len(data) if data else 0;

# if I'm going to sort all the time here at least do insertion sort.
func push(item, priority):
    if (data == null) or (len(data) == 0):
        data = [[item,priority]];
    else:
        data.push_back([item, priority]);
    data.sort_custom(self, "_priority_ordered_sort");
    return item;

func peek():
    if data or len(data):
        var value = data[len(data)-1][0];
        return value;
    else:
        return null;

func pop():
    if data or len(data):
        var value = data[len(data)-1][0];
        data.pop_back();
        return value;
    else:
        return null;