extends RefCounted
## A plain radix-2 FFT in GDScript: the reference the GPU spectrogram is checked against, and the measure of why
## the spectrogram does not run on the CPU.


static func fft(re: PackedFloat64Array, im: PackedFloat64Array) -> void:
	var n: int = re.size()
	var j: int = 0
	for i: int in range(1, n):
		var bit: int = n >> 1
		while j & bit:
			j ^= bit
			bit >>= 1
		j ^= bit
		if i < j:
			var tr: float = re[i]
			re[i] = re[j]
			re[j] = tr
			var ti: float = im[i]
			im[i] = im[j]
			im[j] = ti
	var size: int = 2
	while size <= n:
		var half: int = size >> 1
		var ang: float = -TAU / float(size)
		var wr: float = cos(ang)
		var wi: float = sin(ang)
		var start: int = 0
		while start < n:
			var cr: float = 1.0
			var ci: float = 0.0
			for k: int in half:
				var a: int = start + k
				var b: int = a + half
				var xr: float = re[b] * cr - im[b] * ci
				var xi: float = re[b] * ci + im[b] * cr
				re[b] = re[a] - xr
				im[b] = im[a] - xi
				re[a] += xr
				im[a] += xi
				var nr: float = cr * wr - ci * wi
				ci = cr * wi + ci * wr
				cr = nr
			start += size
		size <<= 1


## Power of each bin 0..n/2 for one window of samples starting at `start`, scaled so a full scale sine is 0 dB.
static func column_db(samples: PackedFloat32Array, start: int, window: PackedFloat32Array) -> PackedFloat64Array:
	var n: int = window.size()
	var re := PackedFloat64Array()
	var im := PackedFloat64Array()
	re.resize(n)
	im.resize(n)
	var total: float = 0.0
	for k: int in n:
		var i: int = start + k
		var s: float = samples[i] if i >= 0 and i < samples.size() else 0.0
		re[k] = s * window[k]
		total += window[k]
	fft(re, im)
	var norm2: float = pow(total * 0.5, 2.0)
	var out := PackedFloat64Array()
	out.resize(n / 2 + 1)
	for k2: int in n / 2 + 1:
		var p: float = re[k2] * re[k2] + im[k2] * im[k2]
		out[k2] = 10.0 * log(maxf(p / norm2, 1e-30)) / log(10.0)
	return out
