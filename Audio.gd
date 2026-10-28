extends Node
## Audio.gd — autoload ("Audio"). Plays pooled sound effects and loops the music.
## Missing files are skipped silently, so the game still runs without audio.
## Generate the files with:  python tools/make_audio.py

const SOUNDS := {
	"swing": "res://assets/audio/swing.wav",
	"hit": "res://assets/audio/hit.wav",
	"hurt": "res://assets/audio/hurt.wav",
	"dodge": "res://assets/audio/dodge.wav",
	"coin": "res://assets/audio/coin.wav",
	"enemy_death": "res://assets/audio/enemy_death.wav",
	"player_death": "res://assets/audio/player_death.wav",
	"wave_complete": "res://assets/audio/wave_complete.wav",
	"click": "res://assets/audio/click.wav",
	"heal": "res://assets/audio/heal.wav",
	"alert": "res://assets/audio/alert.wav",
	"gate": "res://assets/audio/gate.wav",
}
const MUSIC_PATH := "res://assets/audio/music.wav"
const MUSIC_DB := -13.0
const POOL_SIZE := 12

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # UI clicks must work while the tree is paused
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for key in SOUNDS:
		if ResourceLoader.exists(SOUNDS[key]):
			_streams[key] = load(SOUNDS[key])
	if ResourceLoader.exists(MUSIC_PATH):
		_music = AudioStreamPlayer.new()
		_music.stream = load(MUSIC_PATH)
		_music.volume_db = MUSIC_DB
		add_child(_music)
		_music.finished.connect(_music.play)  # loop
		_music.play()


## Plays a one-shot effect with a little random pitch variation.
func play(sound_name: String, volume_db: float = 0.0, pitch_variation: float = 0.07) -> void:
	if not _streams.has(sound_name):
		return
	var chosen: AudioStreamPlayer = _players[0]
	for p in _players:
		if not p.playing:
			chosen = p
			break
	chosen.stream = _streams[sound_name]
	chosen.volume_db = volume_db
	chosen.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	chosen.play()


## Lowers/raises the music (e.g. quiet during the upgrade screen).
func set_music_volume(db: float) -> void:
	if _music:
		_music.volume_db = db
