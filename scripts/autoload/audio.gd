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
var _ambience_stream: AudioStreamWAV
var _ambience_player: AudioStreamPlayer


func _ready() -> void:
	_build_bank()
	for i: int in MAX_VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)


func set_enabled(value: bool) -> void:
	_enabled = value
	if not value and _ambience_player != null:
		_ambience_player.stop()


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
	# 035, the interactive pass: a soft tick under the cursor, a short clack on a press.
	_bank["ui_hover"] = _sweep(0.03, 1200.0, 1350.0, 0.12)
	_bank["ui_click"] = _noise_burst(0.045, 0.32, 3000.0, 0.5)
	_bank["cycle"] = _sweep(0.18, 340.0, 520.0, 0.3)
	# A machine levelling up (play-test 4): a wrench ratchets three times, then a major
	# chord climbs an octave. The one sound in the garage that should feel like a reward.
	_bank["level_up"] = _level_up()
	# 023, the feel pass: a voice for each kind of action, still all synthesised.
	_bank["step"] = _noise_burst(0.07, 0.35, 260.0, 0.5)
	_bank["shot"] = _noise_burst(0.16, 0.8, 3200.0, 0.25)
	_bank["lob"] = _sweep(0.30, 320.0, 90.0, 0.7)
	_bank["thump"] = _noise_burst(0.34, 1.0, 300.0, 0.5)
	_bank["zap"] = _buzz(0.22, 900.0, 140.0, 61.0, 0.55)
	_bank["saw"] = _buzz(0.32, 150.0, 210.0, 38.0, 0.6)
	_bank["clang"] = _noise_burst(0.20, 0.85, 1500.0, 0.95)
	_bank["pickup"] = _notes([660.0, 990.0], 0.07, 0.4)
	_bank["warn"] = _notes([880.0, 0.0, 880.0], 0.08, 0.35)
	_bank["shield"] = _sweep(0.26, 300.0, 620.0, 0.4)
	_bank["spawn"] = _sweep(0.30, 180.0, 520.0, 0.5)
	_bank["flood"] = _noise_burst(0.70, 0.9, 220.0, 0.2)
	_bank["travel"] = _buzz(0.45, 110.0, 170.0, 23.0, 0.4)
	_bank["reward"] = _notes([523.0, 659.0, 784.0], 0.09, 0.4)
	_bank["win"] = _notes([392.0, 523.0, 659.0, 784.0, 1047.0], 0.13, 0.45)
	_bank["lose"] = _sweep(0.9, 300.0, 70.0, 0.55)
	_ambience_stream = _ambience()


## A buzz: a tone swept from one pitch to another and chopped at `rate` Hz. A saw's teeth, a
## coil's arc, a servo: anything that is a motor rather than a blow.
func _buzz(seconds: float, from_hz: float, to_hz: float, rate: float, amplitude: float) -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase: float = 0.0
	for i: int in count:
		var t: float = float(i) / float(count)
		phase += TAU * lerpf(from_hz, to_hz, t) / float(SAMPLE_RATE)
		var saw: float = fposmod(phase / TAU, 1.0) * 2.0 - 1.0
		var chop: float = 0.55 + 0.45 * signf(sin(TAU * rate * t * seconds))
		var envelope: float = minf(t / 0.05, 1.0) * pow(1.0 - t, 1.2)
		_write_sample(data, i, saw * chop * envelope * amplitude)
	return _wav(data)


## Short notes one after another (0 Hz is a rest): pickups, warnings, the stings.
func _notes(hz: Array, each: float, amplitude: float) -> AudioStreamWAV:
	var per: int = int(SAMPLE_RATE * each)
	var tail: int = int(SAMPLE_RATE * 0.18)
	var mix := PackedFloat32Array()
	mix.resize(per * hz.size() + tail)
	for n: int in hz.size():
		if float(hz[n]) <= 0.0:
			continue
		var phase: float = 0.0
		for i: int in per + tail:
			var t: float = float(i) / float(per + tail)
			phase += TAU * float(hz[n]) / float(SAMPLE_RATE)
			mix[n * per + i] += (sin(phase) * 0.8 + sin(phase * 2.0) * 0.2) * minf(t / 0.04, 1.0) * pow(1.0 - t, 2.2) * amplitude
	var data := PackedByteArray()
	data.resize(mix.size() * 2)
	for i: int in mix.size():
		_write_sample(data, i, mix[i])
	return _wav(data)


## The yard at night: machinery idling somewhere, four seconds that loop. Play-test 7: the slow
## swell of filtered noise that was here read as surf ("this game is not about the beach"), so
## there is no noise at all now -- two low drones beating slowly against each other and a
## faint transformer whine, every frequency a whole number of cycles in the loop so the seam
## is silent.
func _ambience() -> AudioStreamWAV:
	var seconds: float = 4.0
	var count: int = int(SAMPLE_RATE * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i: int in count:
		var t: float = float(i) / float(count)
		var s: float = t * seconds
		# 55 and 56.5 Hz beat 1.5 times a second: an engine turning over, not a wave.
		var drone: float = sin(TAU * 55.0 * s) * 0.09 + sin(TAU * 56.5 * s) * 0.07 + sin(TAU * 110.0 * s) * 0.03
		var whine: float = sin(TAU * 240.0 * s) * 0.012 * (0.7 + 0.3 * sin(TAU * 2.0 * t))
		_write_sample(data, i, (drone + whine) * 0.8)
	var stream: AudioStreamWAV = _wav(data)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = count
	return stream


## Starts or stops the yard's bed of noise (the map and the fight ask for it).
func ambience(on: bool) -> void:
	if _ambience_player == null:
		_ambience_player = AudioStreamPlayer.new()
		_ambience_player.stream = _ambience_stream
		_ambience_player.volume_db = -22.0
		add_child(_ambience_player)
	if on and _enabled:
		if not _ambience_player.playing:
			_ambience_player.play()
	else:
		_ambience_player.stop()


## Every name the bank holds (a test checks each `Audio.play` call against it).
func names() -> Array:
	return _bank.keys()


func enabled() -> bool:
	return _enabled


func _level_up() -> AudioStreamWAV:
	var seconds: float = 0.95
	var count: int = int(SAMPLE_RATE * seconds)
	var mix := PackedFloat32Array()
	mix.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	# Ratchet: three short, bright clicks.
	for k: int in 3:
		var start: int = int(SAMPLE_RATE * (0.02 + 0.07 * float(k)))
		var length: int = int(SAMPLE_RATE * 0.035)
		var previous: float = 0.0
		for i: int in length:
			var t: float = float(i) / float(length)
			previous = previous + 0.55 * (rng.randf_range(-1.0, 1.0) - previous)
			mix[start + i] += previous * pow(1.0 - t, 3.0) * 0.55
	# The chord: root, third, fifth, each sweeping up an octave with a soft attack.
	var chord_start: int = int(SAMPLE_RATE * 0.24)
	var chord_len: int = count - chord_start
	for ratio: float in [1.0, 1.26, 1.5]:
		var phase: float = 0.0
		for i: int in chord_len:
			var t: float = float(i) / float(chord_len)
			var hz: float = 300.0 * ratio * lerpf(1.0, 2.0, 1.0 - pow(1.0 - minf(t * 1.8, 1.0), 2.0))
			phase += TAU * hz / float(SAMPLE_RATE)
			var envelope: float = minf(t / 0.06, 1.0) * pow(1.0 - t, 1.4)
			mix[chord_start + i] += (sin(phase) * 0.8 + sin(phase * 2.0) * 0.2) * envelope * 0.22
	var data := PackedByteArray()
	data.resize(count * 2)
	for i: int in count:
		_write_sample(data, i, mix[i])
	return _wav(data)


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
