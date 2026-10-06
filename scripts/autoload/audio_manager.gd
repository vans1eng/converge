extends Node

@onready var bgm: AudioStreamPlayer = $BGM
@onready var cell_hover: AudioStreamPlayer2D = $CellHover
@onready var cell_select: AudioStreamPlayer2D = $CellSelect
@onready var cell_break: AudioStreamPlayer2D = $CellBreak
@onready var cell_wrong: AudioStreamPlayer2D = $CellWrong
@onready var ui_hover: AudioStreamPlayer = $UIHover
@onready var ui_click: AudioStreamPlayer = $UIClick
@onready var level_complete: AudioStreamPlayer = $LevelComplete

const MUSIC_FADE_DURATION := 0.4

var _music_tween: Tween
var _music_gain := 1.0
var _music_base_volume := 1.0
var _music_initialized := false
var music_enabled := true
var sound_enabled := true
var active_voices: Array[Node] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_base_volume = bgm.volume_linear
	# Apply saved audio settings before playback to avoid a startup burst.
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	set_music_enabled(bool(config.get_value("audio", "music_enabled", true)))


func _exit_tree() -> void:
	bgm.stop()


func play_cell_hover() -> void:
	if sound_enabled:
		_play_cell_sound(cell_hover)


func play_cell_select() -> void:
	if sound_enabled:
		_play_cell_sound(cell_select)


func play_cell_break() -> void:
	if sound_enabled:
		_play_cell_sound(cell_break)


func play_cell_wrong() -> void:
	if sound_enabled:
		_play_cell_sound(cell_wrong)


func play_ui_hover() -> void:
	if sound_enabled:
		_play_ui_sound(ui_hover)


func play_ui_click() -> void:
	if sound_enabled:
		_play_ui_sound(ui_click)


func play_level_complete() -> void:
	if sound_enabled:
		_play_ui_sound(level_complete)


func _play_cell_sound(source: AudioStreamPlayer2D) -> void:
	var voice := source.duplicate() as AudioStreamPlayer2D
	add_child(voice)
	active_voices.append(voice)
	voice.finished.connect(_on_voice_finished.bind(voice))
	voice.play()


func _play_ui_sound(source: AudioStreamPlayer) -> void:
	var voice := source.duplicate() as AudioStreamPlayer
	add_child(voice)
	active_voices.append(voice)
	voice.finished.connect(_on_voice_finished.bind(voice))
	voice.play()


func _on_voice_finished(voice: Node) -> void:
	active_voices.erase(voice)
	voice.queue_free()


func set_music_enabled(enabled: bool) -> void:
	if _music_initialized and music_enabled == enabled:
		return
	music_enabled = enabled
	var bus_index := AudioServer.get_bus_index("Music")
	if bus_index >= 0:
		AudioServer.set_bus_mute(bus_index, false)
	var target_gain := 1.0 if enabled else 0.0
	if not _music_initialized:
		_music_initialized = true
		_set_music_gain(target_gain)
	else:
		if _music_tween != null and _music_tween.is_running():
			_music_tween.kill()
		_music_tween = create_tween()
		_music_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_music_tween.tween_method(_set_music_gain, _music_gain, target_gain, MUSIC_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Keep playback running silently, so switching never restarts the track.
	if not bgm.playing:
		bgm.play()


func _set_music_gain(gain: float) -> void:
	_music_gain = gain
	bgm.volume_linear = _music_base_volume * gain


func set_sound_enabled(enabled: bool) -> void:
	sound_enabled = enabled
	var bus_index := AudioServer.get_bus_index("SFX")
	if bus_index >= 0:
		AudioServer.set_bus_mute(bus_index, not enabled)
	if not enabled:
		for voice in active_voices:
			voice.call("stop")
			voice.queue_free()
		active_voices.clear()
