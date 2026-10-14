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
	return cloud_texture("smoke", variant, [Color("8f877c"), Color("625c55"), Color("3e3a36")])


## 078: the smoke billow's shape in a palette of its own: [light, mid, dark]. Dust is the same cloud in
## dry browns, flattened.
static func cloud_texture(name: String, variant: int, palette: Array, flat: float = 1.0) -> ImageTexture:
	return Ink.texture("grit_%s_%d" % [name, variant], Vector2i(160, 160), func(image: Image) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 4100 + variant + name.hash() % 1000
		var centre := Vector2(80, 84)
		var lobes: Array = [[centre, 42.0]]
		for k: int in 6:
			var a: float = TAU * float(k) / 6.0 + rng.randf_range(-0.4, 0.4)
			lobes.append([centre + Vector2(cos(a), sin(a) * 0.8) * rng.randf_range(26.0, 38.0), rng.randf_range(20.0, 32.0)])
		for y: int in 160:
			for x: int in 160:
				var p := Vector2(x, centre.y + (float(y) - centre.y) * flat)
				var f: float = -INF
				for lobe: Array in lobes:
					f = maxf(f, float(lobe[1]) - p.distance_to(lobe[0]))
				f += noise(x, y, 0.06, 60 + variant) * 9.0
				if f <= 0.0:
					image.set_pixel(x, y, Color(0, 0, 0, 0))
					continue
				var col: Color = palette[1]
				var lit: float = (p - centre).normalized().dot(Vector2(-0.6, -0.8)) + noise(x, y, 0.05, 70 + variant) * 0.5
				if lit > 0.35:
					col = palette[0]
				elif lit < -0.15:
					col = palette[2]
					if hatch(x, y, 7.0, 2.0):
						col = Ink.INK
					if lit < -0.55 and hatch(x, y, 7.0, 1.6, -1.0):
						col = Ink.INK
				if speck(x, y, 0.08, 80 + variant):
					col = col.darkened(0.35)
				if f < 5.0 + noise(x, y, 0.2, 50) * 2.0:
					col = Ink.INK
				col.a = erode_alpha(f, 40.0, x, y)
				image.set_pixel(x, y, col))


## A jagged star of uneven spikes (a fixed hand-drawn layout per `seed_value`): ink edge, `outer` hatched
## in the spikes, `inner` toward the heart, white at the middle; loose ink shards round it. Erodible.
## The muzzle flash, the impact star and the blast's heart.
static func star_texture(name: String, outer: Color, inner: Color, seed_value: int, spikes: int = 9,
		short: float = 58.0, long: float = 92.0) -> ImageTexture:
	return Ink.texture("grit_star_%s" % name, Vector2i(192, 192), func(image: Image) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var tips: Array = []
		for k: int in spikes:
			tips.append([TAU * float(k) / float(spikes) + rng.randf_range(-0.25, 0.25), rng.randf_range(short, long)])
		var bits: Array = []
		for k: int in 5:
			var a: float = rng.randf_range(0.0, TAU)
			bits.append(Vector2(96, 96) + Vector2(cos(a), sin(a)) * rng.randf_range(70.0, 88.0))
		var centre := Vector2(96, 96)
		for y: int in 192:
			for x: int in 192:
				var d: Vector2 = Vector2(x, y) - centre
				var r: float = d.length()
				var ang: float = fposmod(d.angle(), TAU)
				var reach: float = 26.0
				for s: Array in tips:
					var off: float = absf(wrapf(ang - float(s[0]), -PI, PI))
					reach = maxf(reach, float(s[1]) * (1.0 - off / (TAU / float(spikes) * 0.75)))
				reach += noise(x, y, 0.09, seed_value) * 5.0
				var col := Color(0, 0, 0, 0)
				var depth: float = reach - r
				if depth > 0.0:
					col = Ink.INK
				if depth > 6.0:
					col = outer
					if r > 34.0 and hatch(x, y, 7.0, 2.0, -1.0):
						col = outer.darkened(0.45)
				if r < 36.0 + noise(x, y, 0.1, seed_value + 1) * 4.0 and depth > 6.0:
					col = inner
				if r < 15.0:
					col = Color.WHITE
				for s: Vector2 in bits:
					var q: Vector2 = Vector2(x, y) - s
					if absf(q.x) + absf(q.y) * 1.8 < 7.0:
						col = Ink.INK
						depth = 6.0
				if col.a > 0.0:
					col.a = erode_alpha(maxf(depth, 0.0), 40.0, x, y)
				image.set_pixel(x, y, col))


## A blast (078, replacing the round cartoon boom): a ragged fireball -- dark red hatched rim, orange,
## yellow, a white-hot heart -- torn by noise, with soot hatched into its lower side. Erodible.
static func blast_texture(variant: int) -> ImageTexture:
	return Ink.texture("grit_blast_%d" % variant, Vector2i(224, 224), func(image: Image) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5200 + variant
		var centre := Vector2(112, 116)
		var lobes: Array = [[centre, 56.0]]
		for k: int in 8:
			var a: float = TAU * float(k) / 8.0 + rng.randf_range(-0.3, 0.3)
			lobes.append([centre + Vector2(cos(a), sin(a)) * rng.randf_range(42.0, 60.0), rng.randf_range(24.0, 40.0)])
		for y: int in 224:
			for x: int in 224:
				var p := Vector2(x, y)
				var f: float = -INF
				for lobe: Array in lobes:
					f = maxf(f, float(lobe[1]) - p.distance_to(lobe[0]))
				f += noise(x, y, 0.05, 90 + variant) * 14.0
				if f <= 0.0:
					image.set_pixel(x, y, Color(0, 0, 0, 0))
					continue
				var heat: float = f / 70.0 + noise(x, y, 0.07, 95 + variant) * 0.12
				var col: Color = Color("a3261a")
				if hatch(x, y, 6.0, 2.0):
					col = Color("5e140c")
				if heat > 0.2:
					col = Color("ff6a1f")
				if heat > 0.42:
					col = Ink.ACTION
				if heat > 0.62:
					col = Color("fff3cf")
				if heat > 0.78:
					col = Color.WHITE
				# Soot under it.
				if p.y > centre.y + 18.0 and heat < 0.42 and hatch(x, y, 5.0, 1.6, -1.0):
					col = Color("3a1a12")
				if f < 6.0 + noise(x, y, 0.2, 99) * 2.0:
					col = Ink.INK
				col.a = erode_alpha(f, 60.0, x, y)
				image.set_pixel(x, y, col))


## Action lines (078): ragged ink strokes bursting out, broken, thick inside and sharp at the tip. Erodible.
static func rays_texture() -> ImageTexture:
	return Ink.texture("grit_rays", Vector2i(256, 256), func(image: Image) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 313
		var spokes: Array = []
		for k: int in 18:
			spokes.append([TAU * float(k) / 18.0 + rng.randf_range(-0.12, 0.12), rng.randf_range(96.0, 126.0),
				rng.randf_range(62.0, 80.0)])
		var c := Vector2(128, 128)
		for y: int in 256:
			for x: int in 256:
				var d: Vector2 = Vector2(x, y) - c
				var r: float = d.length()
				var ang: float = fposmod(d.angle(), TAU)
				var col := Color(0, 0, 0, 0)
				for s: Array in spokes:
					var start: float = float(s[2])
					var end: float = float(s[1])
					if r < start or r > end:
						continue
					var width: float = 0.07 * (1.0 - (r - start) / (end - start))
					var off: float = absf(wrapf(ang - float(s[0]) + noise(x, y, 0.05, 31) * 0.03, -PI, PI))
					if off < width and noise(r, float(s[0]) * 40.0, 0.08, 32) > -0.45:
						col = Ink.INK
						col.a = erode_alpha((width - off) * 300.0, 20.0, x, y)
				image.set_pixel(x, y, col))


## A spark (078): a long hard sliver, white-hot core in an ink edge, a ragged tail.
static func spark_texture() -> ImageTexture:
	return Ink.texture("grit_spark", Vector2i(32, 128), func(image: Image) -> void:
		for y: int in 128:
			for x: int in 32:
				var v: float = float(y) / 127.0
				var half: float = 13.0 * (1.0 - absf(v - 0.3) / 0.7) if v > 0.3 else 13.0 * (v / 0.3)
				half += noise(0.0, y, 0.2, 33) * 2.0 * v
				var u: float = absf(float(x) - 15.5)
				var col := Color(0, 0, 0, 0)
				if u < half:
					col = Ink.INK
				if u < half - 4.0:
					col = Color.WHITE
				image.set_pixel(x, y, col))


## A scrap shard (078; `variant` 0..2): a torn plate with a rivet, rust and paint, hatched underside.
static func shard_texture(variant: int) -> ImageTexture:
	return Ink.texture("grit_shard_%d" % variant, Vector2i(64, 64), func(image: Image) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 700 + variant
		var poly := PackedVector2Array()
		var n: int = 5 + variant
		for k: int in n:
			var a: float = TAU * float(k) / float(n) + rng.randf_range(-0.3, 0.3)
			poly.append(Vector2(32, 32) + Vector2(cos(a), sin(a)) * rng.randf_range(14.0, 29.0))
		var inner := PackedVector2Array()
		for q: Vector2 in poly:
			inner.append(Vector2(32, 32) + (q - Vector2(32, 32)) * 0.78)
		for y: int in 64:
			for x: int in 64:
				var p := Vector2(x, y)
				var col := Color(0, 0, 0, 0)
				if Geometry2D.is_point_in_polygon(p, poly):
					col = Ink.INK
				if Geometry2D.is_point_in_polygon(p, inner):
					# 079 (the user): the metal a little darker.
					col = (Ink.MUSTARD if variant == 0 else (Ink.RUST if variant == 1 else Ink.STEEL)).darkened(0.3)
					if p.y > 34.0:
						col = col.darkened(0.45)
						if hatch(x, y, 5.0, 1.5):
							col = Ink.INK
					if speck(x, y, 0.12, 34 + variant):
						col = Color("6b3a22")
					if p.distance_to(Vector2(28, 26)) < 2.5:
						col = Ink.INK
				image.set_pixel(x, y, col))


## A shock ring seen from above (078, replacing the glowing torus): a ragged band of `c` between ink
## lines, hatched, broken in places, with cracks running out of it. Erodible.
static func ring_texture(c: Color) -> ImageTexture:
	return Ink.texture("grit_ring_" + c.to_html(), Vector2i(192, 192), func(image: Image) -> void:
		var centre := Vector2(96, 96)
		for y: int in 192:
			for x: int in 192:
				var d: Vector2 = Vector2(x, y) - centre
				var r: float = d.length() + noise(x, y, 0.06, 35) * 7.0
				var gap: bool = noise(d.angle() * 30.0, 0.0, 0.2, 36) > 0.45
				var col := Color(0, 0, 0, 0)
				var depth: float = 0.0
				if r < 92.0 and r > 64.0 and not gap:
					col = Ink.INK
					depth = minf(r - 64.0, 92.0 - r)
					if r < 87.0 and r > 69.0:
						col = c
						if Grit.hatch(x, y, 7.0, 2.0):
							col = c.darkened(0.45)
						if r < 74.0:
							col = c.lerp(Color.WHITE, 0.55)
				var crack: float = absf(fposmod(d.angle() / TAU * 9.0, 1.0) - 0.5)
				if r > 40.0 and r < 66.0 and crack < 0.012 * (66.0 - r) / 26.0 + 0.004:
					col = Ink.INK
					depth = 4.0
				if col.a > 0.0:
					col.a = erode_alpha(depth, 14.0, x, y)
				image.set_pixel(x, y, col))


## A scorch mark seen from above (078, replacing the soft soot disc): a ragged black burn, its rim
## hatched, cracks and a few embers. Erodible.
static func scorch_texture() -> ImageTexture:
	return Ink.texture("grit_scorch", Vector2i(192, 192), func(image: Image) -> void:
		var centre := Vector2(96, 96)
		for y: int in 192:
			for x: int in 192:
				var d: Vector2 = Vector2(x, y) - centre
				var r: float = d.length() + noise(x, y, 0.04, 37) * 18.0
				var col := Color(0, 0, 0, 0)
				var depth: float = 86.0 - r
				if depth > 0.0:
					col = Color("1c1714")
					if depth < 22.0:
						col = Color(0, 0, 0, 0) if not hatch(x, y, 6.0, 2.4) else Color("1c1714")
					if absf(fposmod(d.angle() / TAU * 7.0 + noise(x, y, 0.03, 38) * 0.3, 1.0) - 0.5) < 0.02 and depth > 10.0:
						col = Color("4a3a30")
					if speck(x, y, 0.03, 39) and depth > 30.0:
						col = Color("ff7a1f")
				if col.a > 0.0:
					col.a = erode_alpha(maxf(depth, 0.0), 60.0, x, y)
				image.set_pixel(x, y, col))
