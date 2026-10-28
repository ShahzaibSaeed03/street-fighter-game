extends RefCounted
## Textures.gd — builds seamless floor / wall textures (with normal maps for torch relief lighting)
## from noise, so rooms look like real stone, grass, sand, basalt or ice instead of flat colour.
## Styles: stone, grass, sand, lava, ice (floors) and brick (walls).

const SIZE := 256
static var _cache: Dictionary = {}


static func _noise(kind: int, freq: float, seed_v: int, fbm: bool = false) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = kind
	n.frequency = freq
	n.seed = seed_v
	if fbm:
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = 4
	if kind == FastNoiseLite.TYPE_CELLULAR:
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	return n


static func _hash(a: int, b: int) -> float:
	return fposmod(sin(float(a) * 12.9898 + float(b) * 78.233) * 43758.5453, 1.0)


static func make(style: String, base: Color, seed_v: int = 1, with_normal: bool = true) -> CanvasTexture:
	var key: String = "%s|%s|%d|%s" % [style, base.to_html(), seed_v, str(with_normal)]
	if _cache.has(key):
		return _cache[key]
	var cell_freq: float = 0.022
	if style == "lava":
		cell_freq = 0.03
	elif style == "ice":
		cell_freq = 0.026
	elif style == "grass":
		cell_freq = 0.05
	var ci: Image = _noise(FastNoiseLite.TYPE_CELLULAR, cell_freq, seed_v).get_seamless_image(SIZE, SIZE)
	var fi: Image = _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.018, seed_v + 5, true).get_seamless_image(SIZE, SIZE)
	var gi: Image = _noise(FastNoiseLite.TYPE_PERLIN, 0.32, seed_v + 9).get_seamless_image(SIZE, SIZE)
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var heights := PackedFloat32Array()
	heights.resize(SIZE * SIZE)
	for y in SIZE:
		for x in SIZE:
			var c: float = ci.get_pixel(x, y).r
			var f: float = fi.get_pixel(x, y).r
			var g: float = gi.get_pixel(x, y).r
			var col: Color = base
			var h: float = 0.5
			match style:
				"stone":
					var edge: float = smoothstep(0.0, 0.2, c)
					var lum: float = (0.62 + (f - 0.5) * 0.6 + (g - 0.5) * 0.24) * (0.3 + 0.7 * edge)
					col = Color(base.r * lum / 0.62, base.g * lum / 0.62, base.b * lum / 0.62)
					h = edge * 0.7 + f * 0.2 + g * 0.1
				"grass":
					var lum2: float = 0.55 + (f - 0.5) * 0.9 + (g - 0.5) * 0.4
					col = Color(base.r * lum2 / 0.55, base.g * lum2 / 0.55, base.b * lum2 / 0.55)
					col.r += (f - 0.5) * 0.06
					if c < 0.1:
						col = col.lerp(Color(0.22, 0.15, 0.09), 0.65)
					h = g * 0.5 + f * 0.5
				"sand":
					var u: float = float(y) / float(SIZE) * TAU * 6.0 + f * 3.0
					var rip: float = 0.5 + 0.5 * sin(u)
					var lum3: float = 0.58 + (rip - 0.5) * 0.3 + (g - 0.5) * 0.25 + (f - 0.5) * 0.3
					col = Color(base.r * lum3 / 0.58, base.g * lum3 / 0.58, base.b * lum3 / 0.58)
					if c < 0.05:
						col = col.darkened(0.35)
					h = rip * 0.6 + g * 0.2 + smoothstep(0.0, 0.08, c) * 0.2
				"lava":
					var edge2: float = smoothstep(0.0, 0.13, c)
					var lum4: float = 0.45 + (f - 0.5) * 0.4 + (g - 0.5) * 0.2
					col = Color(base.r * lum4 / 0.45, base.g * lum4 / 0.45, base.b * lum4 / 0.45)
					var glow: Color = Color(1.0, 0.40, 0.07) * (0.75 + 0.5 * g)
					col = glow.lerp(col, edge2)
					col.a = 1.0
					h = edge2 * 0.8 + f * 0.2
				"ice":
					var edge3: float = smoothstep(0.0, 0.07, c)
					var lum5: float = 0.7 + (f - 0.5) * 0.45 + (g - 0.5) * 0.12
					col = Color(base.r * lum5 / 0.7, base.g * lum5 / 0.7, base.b * lum5 / 0.7)
					col = Color(0.82, 0.93, 1.0).lerp(col, edge3)
					h = edge3 * 0.5 + f * 0.5
				_:  # brick
					var row: int = y / 16
					var xo: int = x + (row % 2) * 32
					var bx: int = xo / 64
					var mortar: bool = (y % 16) < 2 or (xo % 64) < 2
					var tone: float = 0.8 + _hash(bx, row) * 0.4
					var lum6: float = (0.6 + (g - 0.5) * 0.3 + (f - 0.5) * 0.25) * tone
					if mortar:
						lum6 *= 0.35
					col = Color(base.r * lum6 / 0.6, base.g * lum6 / 0.6, base.b * lum6 / 0.6)
					h = 0.2 if mortar else 0.7 + g * 0.3
			col.a = 1.0
			img.set_pixel(x, y, col)
			heights[y * SIZE + x] = h
	var ct := CanvasTexture.new()
	ct.diffuse_texture = ImageTexture.create_from_image(img)
	if with_normal:
		var nimg := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		var strength: float = 3.2
		for y in SIZE:
			for x in SIZE:
				var hl: float = heights[y * SIZE + (x + SIZE - 1) % SIZE]
				var hr: float = heights[y * SIZE + (x + 1) % SIZE]
				var hu: float = heights[((y + SIZE - 1) % SIZE) * SIZE + x]
				var hd: float = heights[((y + 1) % SIZE) * SIZE + x]
				var nv := Vector3((hl - hr) * strength, (hu - hd) * strength, 1.0).normalized()
				nimg.set_pixel(x, y, Color(nv.x * 0.5 + 0.5, nv.y * 0.5 + 0.5, nv.z * 0.5 + 0.5, 1.0))
		ct.normal_texture = ImageTexture.create_from_image(nimg)
	ct.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_cache[key] = ct
	return ct
