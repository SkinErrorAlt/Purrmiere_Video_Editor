extends RefCounted

const GROUP_REPAIR := "Repair"
const GROUP_VOICE := "Voice"
const GROUP_DYNAMICS := "Dynamics"

const DEFS: Array[Dictionary] = [
	{
		"id": "noise_reduction",
		"label": "Noise reduction",
		"group": GROUP_REPAIR,
		"blurb": "Learns the steady hiss, hum and room noise under the voice as it plays and turns it down, even when the noise changes. Give it a second or two to learn.",
		"params": [
			{"key": "reduction_db", "label": "Reduction", "default": 12.0, "min": 0.0, "max": 40.0, "step": 0.5, "unit": " dB"},
			{"key": "sensitivity", "label": "Sensitivity", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "smoothing", "label": "Smoothing", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "learn_s", "label": "Learning time", "default": 1.5, "min": 0.5, "max": 6.0, "step": 0.1, "unit": " s"},
			{"key": "listen", "label": "Listen to", "default": 0.0, "choices": ["Cleaned sound", "Removed noise only"]},
		],
	},
	{
		"id": "click_remover",
		"label": "Click and pop remover",
		"group": GROUP_REPAIR,
		"blurb": "Finds short clicks, pops and crackle and rebuilds the sound underneath from what comes just before and after each one.",
		"params": [
			{"key": "sensitivity", "label": "Sensitivity", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "widen_ms", "label": "Widen each click", "default": 0.3, "min": 0.0, "max": 2.0, "step": 0.05, "unit": " ms"},
			{"key": "longest_ms", "label": "Longest click", "default": 2.0, "min": 0.3, "max": 5.0, "step": 0.1, "unit": " ms"},
			{"key": "listen", "label": "Listen to", "default": 0.0, "choices": ["Repaired sound", "Clicks only"]},
		],
	},
	{
		"id": "declip",
		"label": "De-clip",
		"group": GROUP_REPAIR,
		"blurb": "Rebuilds the tops of waves that were cut flat by recording too loud, then turns the clip down a little so the rebuilt peaks fit.",
		"params": [
			{"key": "sensitivity", "label": "Sensitivity", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "room_db", "label": "Make room", "default": -3.0, "min": -12.0, "max": 0.0, "step": 0.1, "unit": " dB"},
			{"key": "safety", "label": "Rebuilt peaks", "default": 0.0, "choices": ["Soft limit at full scale", "No limit"]},
		],
	},
	{
		"id": "plosive_softener",
		"label": "Plosive softener",
		"group": GROUP_REPAIR,
		"blurb": "Catches the low thump of a P or a B hitting the microphone and turns down just the low end for that moment.",
		"params": [
			{"key": "sensitivity", "label": "Sensitivity", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "strength_db", "label": "Most it takes off", "default": 12.0, "min": 0.0, "max": 30.0, "step": 0.5, "unit": " dB"},
			{"key": "freq", "label": "Below", "default": 150.0, "min": 60.0, "max": 300.0, "step": 1.0, "unit": " Hz"},
		],
	},
	{
		"id": "wind_reducer",
		"label": "Wind reducer",
		"group": GROUP_REPAIR,
		"blurb": "Turns down the low rumble of wind on the microphone. Works best on stereo recordings, where wind sounds different on each side.",
		"params": [
			{"key": "amount", "label": "Amount", "default": 0.7, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "cutoff", "label": "Below", "default": 250.0, "min": 80.0, "max": 800.0, "step": 5.0, "unit": " Hz"},
			{"key": "sensitivity", "label": "Sensitivity", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
	{
		"id": "breath_reducer",
		"label": "Breath reducer",
		"group": GROUP_REPAIR,
		"blurb": "Finds breaths between phrases and turns them down without cutting them out, so the speech still sounds natural.",
		"params": [
			{"key": "reduction_db", "label": "Turn breaths down by", "default": 12.0, "min": 0.0, "max": 40.0, "step": 0.5, "unit": " dB"},
			{"key": "sensitivity", "label": "Sensitivity", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "listen", "label": "Listen to", "default": 0.0, "choices": ["Cleaned sound", "Breaths only"]},
		],
	},
	{
		"id": "mouth_click_softener",
		"label": "Mouth click softener",
		"group": GROUP_REPAIR,
		"blurb": "Softens the small wet clicks and ticks a mouth makes close to the microphone, mostly in pauses and at the edges of words.",
		"params": [
			{"key": "sensitivity", "label": "Sensitivity", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "reduction_db", "label": "Reduction", "default": 18.0, "min": 0.0, "max": 40.0, "step": 0.5, "unit": " dB"},
			{"key": "freq", "label": "Clicks above", "default": 2500.0, "min": 1000.0, "max": 6000.0, "step": 10.0, "unit": " Hz"},
			{"key": "listen", "label": "Listen to", "default": 0.0, "choices": ["Cleaned sound", "Clicks only"]},
		],
	},
	{
		"id": "dereverb",
		"label": "De-reverb",
		"group": GROUP_REPAIR,
		"blurb": "Turns down the echo a room adds after each word, so a voice recorded in a bare room sounds closer. Set Room tail to roughly how long the room rings.",
		"params": [
			{"key": "amount", "label": "Amount", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "tail_s", "label": "Room tail", "default": 0.6, "min": 0.2, "max": 3.0, "step": 0.05, "unit": " s"},
			{"key": "max_db", "label": "Most it takes off", "default": 12.0, "min": 0.0, "max": 30.0, "step": 0.5, "unit": " dB"},
		],
	},
	{
		"id": "whine_remover",
		"label": "Whine remover",
		"group": GROUP_REPAIR,
		"blurb": "Finds steady whistles and whines, such as a fan, a graphics card or electrical buzz, and notches them out while the voice moves around them.",
		"params": [
			{"key": "reduction_db", "label": "Reduction", "default": 24.0, "min": 0.0, "max": 40.0, "step": 0.5, "unit": " dB"},
			{"key": "sensitivity", "label": "Sensitivity", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "steady_s", "label": "Must be steady for", "default": 1.5, "min": 0.3, "max": 5.0, "step": 0.1, "unit": " s"},
		],
	},
	{
		"id": "keyboard_softener",
		"label": "Keyboard and mouse softener",
		"group": GROUP_REPAIR,
		"blurb": "Turns down the short clack of keys and mouse clicks picked up by the microphone and leaves the voice alone.",
		"params": [
			{"key": "reduction_db", "label": "Reduction", "default": 12.0, "min": 0.0, "max": 30.0, "step": 0.5, "unit": " dB"},
			{"key": "sensitivity", "label": "Sensitivity", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "from_hz", "label": "Only above", "default": 1500.0, "min": 500.0, "max": 5000.0, "step": 10.0, "unit": " Hz"},
		],
	},
	{
		"id": "dropout_filler",
		"label": "Dropout filler",
		"group": GROUP_REPAIR,
		"blurb": "Fills short gaps where the sound cut out, as happens on voice chat recordings, by carrying the last moment of sound across the gap.",
		"params": [
			{"key": "longest_ms", "label": "Longest gap to fill", "default": 40.0, "min": 5.0, "max": 120.0, "step": 1.0, "unit": " ms"},
			{"key": "sensitivity", "label": "Sensitivity", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
	{
		"id": "bandwidth_restore",
		"label": "Bandwidth restore",
		"group": GROUP_REPAIR,
		"blurb": "Adds top end back to dull sound that stops short, such as voice chat or a phone call, by copying the highest part that is there up above the cutoff.",
		"params": [
			{"key": "cutoff", "label": "Sound stops at", "default": 7000.0, "min": 2000.0, "max": 16000.0, "step": 50.0, "unit": " Hz"},
			{"key": "amount", "label": "Amount", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "listen", "label": "Listen to", "default": 0.0, "choices": ["Restored sound", "Added part only"]},
		],
	},
	{
		"id": "room_tone_fill",
		"label": "Room tone fill",
		"group": GROUP_REPAIR,
		"blurb": "Learns the quiet sound of the room and plays it into gaps that went dead silent after a cut or a gate, so the silence does not jump out.",
		"params": [
			{"key": "level_db", "label": "Fill level", "default": 0.0, "min": -24.0, "max": 6.0, "step": 0.5, "unit": " dB"},
			{"key": "learn_s", "label": "Learning time", "default": 2.0, "min": 0.5, "max": 8.0, "step": 0.1, "unit": " s"},
			{"key": "listen", "label": "Listen to", "default": 0.0, "choices": ["Sound with fill", "Fill only"]},
		],
	},
	{
		"id": "harshness_softener",
		"label": "Harshness softener",
		"group": GROUP_REPAIR,
		"blurb": "Finds sharp, ringing peaks in the upper range as they happen and turns each one down, for a harsh microphone or a shrill voice.",
		"params": [
			{"key": "depth", "label": "Depth", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "from_hz", "label": "From", "default": 2000.0, "min": 500.0, "max": 8000.0, "step": 10.0, "unit": " Hz"},
			{"key": "to_hz", "label": "To", "default": 10000.0, "min": 2000.0, "max": 20000.0, "step": 50.0, "unit": " Hz"},
			{"key": "sharpness", "label": "Narrow peaks only", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
	{
		"id": "dialogue_enhancer",
		"label": "Dialogue enhancer",
		"group": GROUP_VOICE,
		"blurb": "Makes speech clearer in one go: presence so the words cut through, clarity to take out mud, body for warmth, a low cut for rumble, and gentle evening out of loud and quiet words.",
		"params": [
			{"key": "presence", "label": "Presence", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "clarity", "label": "Clarity", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "body", "label": "Body", "default": 0.0, "min": -1.0, "max": 1.0, "step": 0.01},
			{"key": "low_cut", "label": "Low cut", "default": 80.0, "min": 20.0, "max": 300.0, "step": 1.0, "unit": " Hz"},
			{"key": "even", "label": "Even out", "default": 0.3, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
	{
		"id": "voice_balance",
		"label": "Voice tone balance",
		"group": GROUP_VOICE,
		"blurb": "Listens to the voice for a few seconds and gently moves its tone toward a clear, natural speech balance, taking out boom or adding presence as needed.",
		"params": [
			{"key": "amount", "label": "Amount", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "range_db", "label": "Most it changes", "default": 6.0, "min": 0.0, "max": 12.0, "step": 0.5, "unit": " dB"},
			{"key": "brightness", "label": "Brighter or darker", "default": 0.0, "min": -3.0, "max": 3.0, "step": 0.1, "unit": " dB"},
			{"key": "speed_s", "label": "Settles in", "default": 4.0, "min": 1.0, "max": 20.0, "step": 0.5, "unit": " s"},
		],
	},
	{
		"id": "phase_rotator",
		"label": "Phase rotator",
		"group": GROUP_VOICE,
		"blurb": "Evens out a lopsided voice wave so its peaks come down a little without changing how it sounds, leaving more room before a limiter.",
		"params": [
			{"key": "freq", "label": "Centre", "default": 250.0, "min": 80.0, "max": 1000.0, "step": 1.0, "unit": " Hz"},
			{"key": "stages", "label": "Strength", "default": 1.0, "choices": ["2 stages", "4 stages", "6 stages", "8 stages"]},
		],
	},
	{
		"id": "loudness_normaliser",
		"label": "Loudness normaliser",
		"group": GROUP_DYNAMICS,
		"blurb": "Measures the clip's loudness as it plays and sets one steady gain to reach a platform target, such as -14 LUFS for YouTube, so loud and quiet parts keep their difference. True peaks stay under the ceiling.",
		"params": [
			{"key": "target", "label": "Target", "default": 0.0, "choices": ["YouTube and Spotify, -14 LUFS", "Apple Podcasts, -16 LUFS", "EBU R128, -23 LUFS", "ATSC, -24 LKFS", "Netflix, -27 LKFS", "Loud, -11 LUFS", "Custom"]},
			{"key": "custom_lufs", "label": "Custom target", "default": -14.0, "min": -36.0, "max": -6.0, "step": 0.5, "unit": " LUFS"},
			{"key": "ceiling_db", "label": "True peak ceiling", "default": -1.0, "min": -6.0, "max": 0.0, "step": 0.1, "unit": " dB"},
			{"key": "max_boost_db", "label": "Most it turns up", "default": 20.0, "min": 0.0, "max": 30.0, "step": 0.5, "unit": " dB"},
			{"key": "settle_s", "label": "Settle time", "default": 4.0, "min": 1.0, "max": 20.0, "step": 0.5, "unit": " s"},
		],
	},
	{
		"id": "voice_gate",
		"label": "Voice gate",
		"group": GROUP_DYNAMICS,
		"blurb": "Opens for speech rather than for loudness, so key clicks and room noise between words are turned down even when they are loud.",
		"params": [
			{"key": "floor_db", "label": "Gaps go down to", "default": -24.0, "min": -80.0, "max": 0.0, "step": 0.5, "unit": " dB"},
			{"key": "sensitivity", "label": "Sensitivity", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "hold_ms", "label": "Hold open", "default": 150.0, "min": 20.0, "max": 1000.0, "step": 1.0, "unit": " ms"},
			{"key": "release_ms", "label": "Close time", "default": 80.0, "min": 10.0, "max": 1000.0, "step": 1.0, "unit": " ms"},
		],
	},
]
