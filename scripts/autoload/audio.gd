extends Node

## Procedurally synthesised sound effects.
##
## Every sound is generated as PCM at startup — there are **no audio files to license,
## commission, or ship**. For a solo project with no budget that is the difference
## between having sound and not having it, and machine noise (impacts, servos, arcs,
## alarms) is exactly the palette that synthesises convincingly.
##
## Two rules keep it from becoming noise:
##
##   - **Voice limits.** A cycle can emit fifty impacts. Without a cap the mix turns to
##     mush and the important sounds — a kill, an overdrive — vanish inside it.
##   - **Pitch variation.** The same sample at the same pitch twenty times reads as a
##     bug. Every playback is detuned slightly.

const SAMPLE_RATE: int = 22050
const MAX_VOICES: int = 10

var _bank: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _enabled: bool = true


func _ready() -> void:
	_build_bank()
	for i: int in MAX_VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)


func set_enabled(value: bool) -> void:
	_enabled = value


## Plays a named sound. Unknown names are ignored rather than erroring: a missing sound
## should never be able to break a battle.
func play(name: String, volume_db: float = -6.0, pitch_spread: float = 0.14) -> void:
	if not _enabled or not _bank.has(name):
		return
	# Round-robin voices. Stealing the oldest is better than dropping the newest --
	# the most recent event is always the one the player is looking at.
	var player: AudioStreamPlayer = _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	player.stream = _bank[name]
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_spread, pitch_spread)
	player.play()


# --- Synthesis ---------------------------------------------------------------

func _build_bank() -> void:
	# Impacts are filtered noise with a fast decay: the classic "metal struck" shape.
	_bank["hit_light"] = _noise_burst(0.10, 0.55, 2400.0, 0.9)
	_bank["hit_heavy"] = _noise_burst(0.26, 0.90, 900.0, 0.55)
	# Destruction is longer, lower, and given a little tail so it reads as final.
	_bank["destroy"] = _noise_burst(0.55, 1.0, 420.0, 0.30)
	# A rising tone for Overdrive: the one moment that should feel like a reward.
	_bank["overdrive"] = _sweep(0.34, 220.0, 880.0, 0.7)
	# A falling, souring tone for Seize: the same event inverted, because it is the
	# punishment half of the same mechanic.
	_bank["seize"] = _sweep(0.42, 620.0, 130.0, 0.6)
	_bank["detonate"] = _sweep(0.22, 900.0, 1700.0, 0.8)
	_bank["ui_confirm"] = _sweep(0.09, 620.0, 980.0, 0.35)
	_bank["ui_deny"] = _sweep(0.14, 420.0, 240.0, 0.35)
	_bank["cycle"] = _sweep(0.18, 340.0, 520.0, 0.3)


## Noise shaped by an exponential decay and a crude one-pole low-pass. `tone` mixes in
## a sine at the cutoff, which is what stops it sounding like a hiss and starts it
## sounding like something being struck.
func _noise_burst(seconds: float, amplitude: float, cutoff: float, tone: float) -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)

	var rng := RandomNumberGenerator.new()
	rng.seed = int(cutoff) * 7919
	var previous: float = 0.0
	var alpha: float = clampf(cutoff / float(SAMPLE_RATE), 0.02, 0.95)
	var phase: float = 0.0
	var phase_step: float = TAU * cutoff * 0.25 / float(SAMPLE_RATE)

	for i: int in count:
		var t: float = float(i) / float(count)
		var envelope: float = pow(1.0 - t, 2.6)
		var noise: float = rng.randf_range(-1.0, 1.0)
		previous = previous + alpha * (noise - previous)
		phase += phase_step
		var sample: float = lerpf(previous, sin(phase), tone * 0.45) * envelope * amplitude
		_write_sample(data, i, sample)

	return _wav(data)


## A pitch sweep with a soft attack. Used for anything that is a state change rather
## than an impact.
func _sweep(seconds: float, from_hz: float, to_hz: float, amplitude: float) -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)

	var phase: float = 0.0
	for i: int in count:
		var t: float = float(i) / float(count)
		var frequency: float = lerpf(from_hz, to_hz, t * t)
		phase += TAU * frequency / float(SAMPLE_RATE)
		# Attack over the first 8%, then decay. A hard start clicks.
		var envelope: float = minf(t / 0.08, 1.0) * pow(1.0 - t, 1.8)
		# A little third harmonic keeps it from sounding like a test tone.
		var sample: float = (sin(phase) * 0.8 + sin(phase * 3.0) * 0.2) * envelope * amplitude
		_write_sample(data, i, sample)

	return _wav(data)


func _write_sample(data: PackedByteArray, index: int, value: float) -> void:
	var clamped: int = int(clampf(value, -1.0, 1.0) * 32767.0)
	data.encode_s16(index * 2, clamped)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
