class_name Grit
extends RefCounted

## 076 (the user: "too cartoony -- the game's style is not only Ink & Rust but something like Borderlands
## and comics"): the drawing vocabulary for effects. Silhouettes are jagged and irregular (noise on every
## edge), the ink line is thick and wobbles, shade is HATCHED in diagonal ink strokes (crossed where it is
## darkest), fills carry grain, and smoke and fire do not shrink away -- they ERODE into grit.
##
## Erosion: an erodible texture keeps its shape in alpha 0.5..1, deepest inside highest, with grain mixed
## in. Drawn with an alpha cut at 0.5 it shows whole; raising the cut (`erode`) eats it from the edges
## inward, breaking into specks as it goes.

static var _noises: Dictionary = {}


## Simplex noise in -1..1 (three octaves), one generator per seed and frequency.
static func noise(x: float, y: float, frequency: float = 0.05, seed_value: int = 0) -> float:
	var key: int = seed_value * 100000 + int(frequency * 10000.0)
	if not _noises.has(key):
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.fractal_octaves = 3
		n.seed = seed_value
		n.frequency = frequency
		_noises[key] = n
	return (_noises[key] as FastNoiseLite).get_noise_2d(x, y)


## True on a diagonal ink stroke: lines `spacing` px apart, `width` px thick; `slope` +1 or -1 picks the
## diagonal. The strokes wobble a little, like a pen.
static func hatch(x: float, y: float, spacing: float, width: float, slope: float = 1.0) -> bool:
	var s: float = x + slope * y + noise(x, y, 0.08, 7) * 2.0
	return fposmod(s, spacing) < width


## Grain: true on a dark speck (`amount` 0..1 of the area).
static func speck(x: float, y: float, amount: float, seed_value: int = 3) -> bool:
	return noise(x, y, 0.45, seed_value) > 1.0 - amount * 1.6


## Alpha for an erodible pixel `depth` px inside its edge (of at most `deep`): 0.5..1, deeper higher,
## grain mixed in so it breaks into specks.
static func erode_alpha(depth: float, deep: float, x: float, y: float) -> float:
	var g: float = (noise(x, y, 0.3, 11) + 1.0) * 0.5
	return 0.5 + 0.5 * clampf(depth / deep * 0.72 + g * 0.28, 0.0, 1.0)


## Eats `sprite` away over `time` seconds after `delay` (its alpha cut raised from 0.5 to 1).
static func erode(owner: Node, sprite: Sprite3D, delay: float, time: float) -> Tween:
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.5
	var t := owner.create_tween()
	if delay > 0.0:
		t.tween_interval(delay)
	t.tween_property(sprite, "alpha_scissor_threshold", 1.0, time).set_ease(Tween.EASE_IN)
	t.tween_callback(sprite.queue_free)
	return t


## A smoke cloud (`variant` 0..3): a jagged billow in sooty greys, lit from the upper left, its shade
## hatched and its darkest crossed, a thick ink edge, grain all through; erodible.
static func smoke_texture(variant: int) -> ImageTexture:
	return Ink.texture("grit_smoke_%d" % variant, Vector2i(160, 160), func(image: Image) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 4100 + variant
		var centre := Vector2(80, 84)
		var lobes: Array = [[centre, 42.0]]
		for k: int in 6:
			var a: float = TAU * float(k) / 6.0 + rng.randf_range(-0.4, 0.4)
			lobes.append([centre + Vector2(cos(a), sin(a) * 0.8) * rng.randf_range(26.0, 38.0), rng.randf_range(20.0, 32.0)])
		var light := Color("8f877c")
		var mid := Color("625c55")
		var dark := Color("3e3a36")
		for y: int in 160:
			for x: int in 160:
				var p := Vector2(x, y)
				var f: float = -INF
				for lobe: Array in lobes:
					f = maxf(f, float(lobe[1]) - p.distance_to(lobe[0]))
				f += noise(x, y, 0.06, 20 + variant) * 9.0
				if f <= 0.0:
					image.set_pixel(x, y, Color(0, 0, 0, 0))
					continue
				var col: Color = mid
				var lit: float = (p - centre).normalized().dot(Vector2(-0.6, -0.8)) + noise(x, y, 0.05, 30 + variant) * 0.5
				if lit > 0.35:
					col = light
				elif lit < -0.15:
					col = dark
					if hatch(x, y, 7.0, 2.0):
						col = Ink.INK
					if lit < -0.55 and hatch(x, y, 7.0, 1.6, -1.0):
						col = Ink.INK
				if speck(x, y, 0.08, 40 + variant):
					col = col.darkened(0.35)
				if f < 5.0 + noise(x, y, 0.2, 50) * 2.0:
					col = Ink.INK
				col.a = erode_alpha(f, 40.0, x, y)
				image.set_pixel(x, y, col))
