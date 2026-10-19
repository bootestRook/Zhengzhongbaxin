class_name DefenseAudio
extends Node

var sounds: Dictionary = {}
var cache: Dictionary = {}
var last_played: Dictionary = {}
var track: String = ""
var clock: float = 0
var muted: bool = false

func configure(art: Dictionary) -> void:
	sounds = art.get("audio", {})
	$Music.finished.connect(func(): $Music.play())

func update(state: Dictionary, events: Array) -> void:
	muted = state.muted
	$Music.volume_db = -80 if muted else -23
	var next = "bg" if state.phase == "home" else "fightbg"
	if next != track:
		track = next
		$Music.stream = stream(track)
		$Music.play()
	for event in events:
		match event.type:
			"sound": play(event.name)
			"choice_made": play("click")
			"encounter_spawned": play("tips")
			"finished": play("victory" if event.won else "fail")

func stream(key: String) -> AudioStream:
	if not sounds.has(key):
		return null
	if not cache.has(key):
		cache[key] = load(sounds[key][0])
	return cache[key]

func play(key: String) -> void:
	if muted or clock - float(last_played.get(key, -10)) < 0.13:
		return
	var sound = stream(key)
	if sound == null:
		return
	for player in $Effects.get_children():
		if not player.playing:
			player.stream = sound
			player.play()
			last_played[key] = clock
			break

func _process(delta: float) -> void:
	clock += delta

func _exit_tree() -> void:
	$Music.stop()
	$Music.stream = null
	for player in $Effects.get_children():
		player.stop()
		player.stream = null
	cache.clear()
