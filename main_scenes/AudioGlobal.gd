extends Node;
# Okay, it looks like I need to make audio effects not loop...

var music_resources = {};
var sound_effect_resources = {};

const SOUND_CHANNELS = 16;
var free_sound_channel = 0;
var sound_effect_channels = [];

const DEFAULT_MAX_VOLUME_DB = -10.0;

var music_channel = null;

func load_music(filepath):
	var resource = null;
	if !(filepath in music_resources):
		music_resources[filepath] = load("res://" + filepath);

	resource = music_resources[filepath];
	return resource;

func load_sound(filepath):
	var resource = null;
	if !(filepath in sound_effect_resources):
		sound_effect_resources[filepath] = load("res://" + filepath);
		if "loop" in sound_effect_resources[filepath]:
			sound_effect_resources[filepath].loop = false;

	resource = sound_effect_resources[filepath];
	return resource;

func _ready():
	for channel in range(SOUND_CHANNELS):
		var new_channel = AudioStreamPlayer.new();
		add_child(new_channel);
		sound_effect_channels.append(new_channel);

	music_channel = AudioStreamPlayer.new();
	add_child(music_channel);

func stop_sound(channel_index):
	var channel = sound_effect_channels[channel_index];
	channel.stop();

func play_sound(filepath, volume=DEFAULT_MAX_VOLUME_DB, channel_index=-1):
	var channel = null;
	if channel_index == -1:
		channel = sound_effect_channels[free_sound_channel];

		free_sound_channel += 1;
		free_sound_channel %= SOUND_CHANNELS;
	else:
		channel = sound_effect_channels[channel_index];
	

	channel.stream = load_sound(filepath);
	channel.volume_db = volume;
	channel.play();

func is_channel_playing(index):
	return sound_effect_channels[index].playing;

func is_music_playing():
	return music_channel.playing;

func pause_music():
	music_channel.stop();
func resume_music():
	music_channel.play();

func play_music(filepath, volume=DEFAULT_MAX_VOLUME_DB):
	var music = load_music(filepath);
	music.loop = false;
	music_channel.stream = music;
	music_channel.volume_db = volume;
	music_channel.play();
	print(music);
	print(music_channel.playing);
	print(music_channel.stream_paused);
	
var currently_playing_music = null;
var music_played_amount = 0;
func looped_play_music(filepath, override=false, volume=DEFAULT_MAX_VOLUME_DB, times=-1):
	if (!is_music_playing() or (currently_playing_music != filepath and override)):
		if (times == -1 or music_played_amount < times):
			currently_playing_music = filepath;
			music_played_amount += 1;
			play_music(filepath, volume);
