extends RefCounted

const GROUP_REPAIR := "Repair"
const GROUP_STEREO := "Stereo"
const GROUP_UTILITY := "Utility"
const SOURCES: Array = ["Source A", "Source B", "Source C", "Source D"]
const REFERENCES: Array = ["Reference A", "Reference B", "Reference C", "Reference D"]

const DEFS: Array[Dictionary] = [
	{
		"id": "noise_print",
		"label": "Noise Print Reduction",
		"group": GROUP_REPAIR,
		"blurb": "Learns the noise from a stretch you choose, such as the first second of room tone before anyone speaks, and takes that exact noise out of the whole clip. Unlike Noise reduction, which keeps guessing the noise as it plays, the print stays fixed, so held notes and steady voices are not eaten. Until it has heard the stretch it guesses the noise from the quietest moments.",
		"params": [
			{"key": "reduction_db", "label": "Reduction", "default": 15.0, "min": 0.0, "max": 40.0, "step": 0.5, "unit": " dB"},
			{"key": "learn_from_s", "label": "Learn from", "default": 0.0, "min": 0.0, "max": 3600.0, "step": 0.1, "unit": " s"},
			{"key": "learn_len_s", "label": "Learn for", "default": 1.0, "min": 0.2, "max": 10.0, "step": 0.1, "unit": " s"},
			{"key": "threshold_db", "label": "Keep sound above the print by", "default": 4.0, "min": 0.0, "max": 12.0, "step": 0.5, "unit": " dB"},
			{"key": "smoothing", "label": "Smoothing", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "listen", "label": "Listen to", "default": 0.0, "choices": ["Cleaned sound", "Removed noise only"]},
		],
	},
	{
		"id": "de_hiss",
		"label": "De-hiss",
		"group": GROUP_REPAIR,
		"blurb": "Turns down tape, preamp and camera hiss in the top of the sound only, with no delay and no watery artefacts, and opens again the moment there is real treble such as cymbals or an s. Everything below Hiss above is left untouched.",
		"params": [
			{"key": "reduction_db", "label": "Reduction", "default": 12.0, "min": 0.0, "max": 30.0, "step": 0.5, "unit": " dB"},
			{"key": "freq", "label": "Hiss above", "default": 3000.0, "min": 1000.0, "max": 10000.0, "step": 10.0, "unit": " Hz"},
			{"key": "sensitivity", "label": "Sensitivity", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "release_ms", "label": "Recovery", "default": 80.0, "min": 20.0, "max": 500.0, "step": 1.0, "unit": " ms"},
			{"key": "listen", "label": "Listen to", "default": 0.0, "choices": ["Cleaned sound", "Hiss only"]},
		],
	},
	{
		"id": "de_crackle",
		"label": "De-crackle",
		"group": GROUP_REPAIR,
		"blurb": "Takes out the dense, tiny ticks of vinyl crackle, a crackling cable or a dirty connector, hundreds a second, by rebuilding each one from the sound either side. The Click and pop remover is for fewer, bigger clicks; this one is for a constant crackle bed.",
		"params": [
			{"key": "sensitivity", "label": "Sensitivity", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "longest_ms", "label": "Longest crackle", "default": 0.6, "min": 0.1, "max": 2.0, "step": 0.05, "unit": " ms"},
			{"key": "freq", "label": "Crackle above", "default": 2500.0, "min": 1000.0, "max": 6000.0, "step": 10.0, "unit": " Hz"},
			{"key": "listen", "label": "Listen to", "default": 0.0, "choices": ["Repaired sound", "Crackle only"]},
		],
	},
	{
		"id": "hum_remover",
		"label": "Hum and Buzz Remover",
		"group": GROUP_REPAIR,
		"blurb": "Finds whether the hum is at 50 or 60 Hz, follows it as the mains frequency drifts, and cancels up to 40 harmonics with notches only half a hertz wide, so a voice around them is kept. De-hum has fixed notches and a few harmonics; use this one for buzz with many harmonics or hum that wanders.",
		"params": [
			{"key": "mains", "label": "Hum at", "default": 0.0, "choices": ["Find it", "50 Hz", "60 Hz", "Set by hand"]},
			{"key": "freq", "label": "Set by hand to", "default": 50.0, "min": 10.0, "max": 1000.0, "step": 0.1, "unit": " Hz"},
			{"key": "harmonics", "label": "Harmonics", "default": 12.0, "min": 1.0, "max": 40.0, "step": 1.0},
			{"key": "width_hz", "label": "Notch width", "default": 0.5, "min": 0.1, "max": 5.0, "step": 0.05, "unit": " Hz"},
			{"key": "amount", "label": "Amount", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "listen", "label": "Listen to", "default": 0.0, "choices": ["Cleaned sound", "Hum only"]},
		],
	},
	{
		"id": "spectral_repair",
		"label": "Spectral Repair",
		"group": GROUP_REPAIR,
		"blurb": "Finds short sounds that jump out of the background and fall back again, such as a knock on the desk, a tap on the microphone or a chair tick, and brings just those frequencies down to the background level, leaving the sound under them. It leaves speech alone unless you choose Repair everywhere. It comes out about 43 ms late, so slide the clip that much earlier if sync matters.",
		"params": [
			{"key": "threshold_db", "label": "Stands out by at least", "default": 12.0, "min": 6.0, "max": 30.0, "step": 0.5, "unit": " dB"},
			{"key": "strength", "label": "Strength", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "from_hz", "label": "From", "default": 40.0, "min": 20.0, "max": 10000.0, "step": 10.0, "unit": " Hz"},
			{"key": "to_hz", "label": "To", "default": 16000.0, "min": 200.0, "max": 20000.0, "step": 50.0, "unit": " Hz"},
			{"key": "protect", "label": "Speech", "default": 0.0, "choices": ["Leave speech alone", "Repair everywhere"]},
			{"key": "listen", "label": "Listen to", "default": 0.0, "choices": ["Repaired sound", "Removed part only"]},
		],
	},
	{
		"id": "deconstruct",
		"label": "Deconstruct",
		"group": GROUP_REPAIR,
		"blurb": "Splits the sound into its steady tones, its noise and its hits, and lets you turn each one up or down: take the hiss and room out from under a voice or music, bring footsteps and impacts forward, or pull the drums back. It comes out about 43 ms late.",
		"params": [
			{"key": "tone_db", "label": "Tone", "default": 0.0, "min": -40.0, "max": 12.0, "step": 0.5, "unit": " dB"},
			{"key": "noise_db", "label": "Noise", "default": -6.0, "min": -40.0, "max": 12.0, "step": 0.5, "unit": " dB"},
			{"key": "hits_db", "label": "Hits", "default": 0.0, "min": -40.0, "max": 12.0, "step": 0.5, "unit": " dB"},
			{"key": "separation", "label": "Separation", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
	{
		"id": "safety_merge",
		"label": "Safety Track Merge",
		"group": GROUP_REPAIR,
		"blurb": "For recorders and wireless mics that record a quieter safety copy on the other side, such as 20 dB down on the right: wherever the main recording clipped, the safety copy is brought up and put in its place, so the real peaks come back instead of being guessed. Both sides then carry the merged sound, held under the ceiling. Ordinary stereo is left alone.",
		"params": [
			{"key": "main", "label": "Main recording on", "default": 0.0, "choices": ["Left", "Right"]},
			{"key": "safety", "label": "Safety is quieter by", "default": 0.0, "choices": ["Measure it", "6 dB", "10 dB", "12 dB", "20 dB"]},
			{"key": "clip_db", "label": "Main counts as clipped from", "default": -0.5, "min": -6.0, "max": 0.0, "step": 0.1, "unit": " dB"},
			{"key": "ceiling_db", "label": "Hold peaks under", "default": -1.0, "min": -6.0, "max": 0.0, "step": 0.1, "unit": " dB"},
			{"key": "listen", "label": "Listen to", "default": 0.0, "choices": ["Merged sound", "Only what came from the safety"]},
		],
	},
	{
		"id": "bleed_source",
		"label": "Bleed Source",
		"group": GROUP_REPAIR,
		"blurb": "Put this on the track whose sound leaks into another microphone, such as a second person's mic, or the game or voice chat that played through your speakers. It tells the Bleed and Echo Reducer with the same letter what to take out; the sound plays on unchanged.",
		"params": [
			{"key": "key", "label": "Send as", "default": 0.0, "choices": SOURCES},
		],
	},
	{
		"id": "bleed_reducer",
		"label": "Bleed and Echo Reducer",
		"group": GROUP_REPAIR,
		"blurb": "Takes out the sound of another track that leaked into this microphone, band by band, such as the other person on a podcast or your speakers playing the game and voice chat back into your mic. Put a Bleed Source with the same letter on the track that leaks. It learns how much leaks in by itself and keeps this mic's own voice. It comes out about 27 ms late.",
		"params": [
			{"key": "key", "label": "Take out", "default": 0.0, "choices": SOURCES},
			{"key": "reduction_db", "label": "Most reduction", "default": 20.0, "min": 0.0, "max": 40.0, "step": 0.5, "unit": " dB"},
			{"key": "strength", "label": "Strength", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "range_ms", "label": "Leak arrives within", "default": 120.0, "min": 10.0, "max": 500.0, "step": 1.0, "unit": " ms"},
			{"key": "listen", "label": "Listen to", "default": 0.0, "choices": ["Cleaned sound", "Removed bleed only"]},
		],
	},
	{
		"id": "channel_align",
		"label": "Channel Align",
		"group": GROUP_STEREO,
		"blurb": "For one clip with two microphones or a faulty recording on its left and right: finds how far apart the two sides are in time, to a fraction of a sample, and lines them up; flips a side that is upside down; and fills a side that is silent, as happens with a mic plugged into input 1 only. Unrelated stereo is left alone. It comes out 10 ms late.",
		"params": [
			{"key": "range_ms", "label": "Search up to", "default": 5.0, "min": 0.5, "max": 10.0, "step": 0.1, "unit": " ms"},
			{"key": "polarity", "label": "Upside down side", "default": 0.0, "choices": ["Fix it", "Leave it"]},
			{"key": "output", "label": "Output", "default": 0.0, "choices": ["Aligned stereo", "Aligned mono mix"]},
			{"key": "dead", "label": "When one side is silent", "default": 0.0, "choices": ["Fill it from the other side", "Leave it"]},
			{"key": "follow", "label": "After it lines up", "default": 0.0, "choices": ["Keep following", "Lock once found"]},
		],
	},
	{
		"id": "align_reference",
		"label": "Align Reference",
		"group": GROUP_UTILITY,
		"blurb": "Marks this track as the one to line up to, such as the lav mic, for Track Align on another track with the same letter. It plays unchanged but 10 ms late, so the other track can be moved either way. Put both on the tracks, or on clips that start at the same moment.",
		"params": [
			{"key": "letter", "label": "Reference", "default": 0.0, "choices": REFERENCES},
		],
	},
	{
		"id": "track_align",
		"label": "Track Align",
		"group": GROUP_UTILITY,
		"blurb": "Lines this track up in time and polarity with the Align Reference with the same letter, so two microphones on the same voice stop fighting and sound full again, such as a boom that is a few milliseconds behind a lav. Both come out 10 ms late. Put both on the tracks, or on clips that start at the same moment.",
		"params": [
			{"key": "letter", "label": "Line up with", "default": 0.0, "choices": REFERENCES},
			{"key": "range_ms", "label": "Search up to", "default": 5.0, "min": 0.5, "max": 10.0, "step": 0.1, "unit": " ms"},
			{"key": "fix", "label": "Fix", "default": 0.0, "choices": ["Timing and polarity", "Timing only", "Polarity only"]},
			{"key": "follow", "label": "After it lines up", "default": 0.0, "choices": ["Keep following", "Lock once found"]},
		],
	},
	{
		"id": "centre_extract",
		"label": "Centre Extract",
		"group": GROUP_STEREO,
		"blurb": "Takes out what sits in the middle of a stereo mix, such as the singer of a song you want under your voice, or keeps only the middle, such as the dialogue in a game recording. It works frequency by frequency, so it removes far more of the middle than Mid and side, and the bass and cymbals outside the range are kept.",
		"params": [
			{"key": "mode", "label": "Mode", "default": 0.0, "choices": ["Remove the centre", "Keep only the centre"]},
			{"key": "amount", "label": "Amount", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "width", "label": "Centre width", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "from_hz", "label": "Only above", "default": 150.0, "min": 20.0, "max": 2000.0, "step": 1.0, "unit": " Hz"},
			{"key": "to_hz", "label": "Only below", "default": 8000.0, "min": 1000.0, "max": 20000.0, "step": 50.0, "unit": " Hz"},
		],
	},
	{
		"id": "mono_fold",
		"label": "Clean Mono Fold",
		"group": GROUP_STEREO,
		"blurb": "Folds stereo to mono without the hollow, phasey sound of a plain sum: sides that are slightly apart in time or upside down no longer cancel, and wide sounds keep their level. Use it for a phone speaker version or a mono export of game audio.",
		"params": [
			{"key": "width", "label": "Keep some stereo", "default": 0.0, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "from_hz", "label": "Fold cleanly above", "default": 20.0, "min": 20.0, "max": 2000.0, "step": 1.0, "unit": " Hz"},
		],
	},
	{
		"id": "test_signal",
		"label": "Test Signal",
		"group": GROUP_UTILITY,
		"blurb": "The standard line up and test signals, replacing the sound under it: a 1 kHz tone at -18 dBFS, the EBU stereo ident, GLITS, a sweep from 20 Hz to 20 kHz, pink or white noise at an exact level for setting up speakers, a polarity pulse and a one frame sync pop. Sine levels are peak levels and noise levels are RMS.",
		"params": [
			{"key": "signal", "label": "Signal", "default": 0.0, "choices": ["Line up tone", "Stereo ident, left broken", "GLITS", "Sine sweep", "Pink noise", "White noise", "Pink noise, 500 Hz to 2 kHz", "Polarity pulse", "Sync pop"]},
			{"key": "level_db", "label": "Level", "default": -18.0, "min": -60.0, "max": 0.0, "step": 0.5, "unit": " dBFS"},
			{"key": "freq", "label": "Tone pitch", "default": 1000.0, "min": 20.0, "max": 20000.0, "step": 1.0, "unit": " Hz"},
			{"key": "channels", "label": "Channels", "default": 0.0, "choices": ["Both sides", "Left only", "Right only", "Left and right in turn"]},
			{"key": "sweep_s", "label": "Sweep length", "default": 10.0, "min": 1.0, "max": 60.0, "step": 0.5, "unit": " s"},
			{"key": "pop_fps", "label": "Sync pop is one frame at", "default": 1.0, "choices": ["24 fps", "25 fps", "30 fps", "50 fps", "60 fps"]},
		],
	},
	{
		"id": "auto_trim",
		"label": "Auto Trim",
		"group": GROUP_UTILITY,
		"blurb": "Gain staging for the top of an effects chain: listens to the first seconds, sets one input trim so the average level sits at the target (-18 dBFS, the level console and tape effects expect), then holds it. It can also trim by loudness or by peaks. Unlike the Loudness normaliser it has no limiter and is not meant for the final level.",
		"params": [
			{"key": "target_db", "label": "Target", "default": -18.0, "min": -40.0, "max": -3.0, "step": 0.5, "unit": " dB"},
			{"key": "measure", "label": "Measure", "default": 0.0, "choices": ["Average level", "Loudness, LUFS", "Peaks"]},
			{"key": "learn_s", "label": "Listens for", "default": 5.0, "min": 0.5, "max": 30.0, "step": 0.5, "unit": " s"},
			{"key": "after", "label": "Then", "default": 0.0, "choices": ["Hold the trim", "Keep following slowly"]},
			{"key": "max_db", "label": "Most change", "default": 18.0, "min": 0.0, "max": 30.0, "step": 0.5, "unit": " dB"},
			{"key": "ignore_db", "label": "Ignore quieter than", "default": -50.0, "min": -80.0, "max": -20.0, "step": 0.5, "unit": " dB"},
		],
	},
	{
		"id": "time_offset",
		"label": "Time Offset",
		"group": GROUP_UTILITY,
		"blurb": "Makes the sound late by an exact time, finer than a frame, to fix lip sync or to line a track up with one that has a late effect on it, and can move one side against the other by a fraction of a millisecond. Changes crossfade, so there is no click and no pitch wobble.",
		"params": [
			{"key": "delay_ms", "label": "Delay", "default": 0.0, "min": 0.0, "max": 1000.0, "step": 0.01, "unit": " ms"},
			{"key": "side_ms", "label": "Right later than left by", "default": 0.0, "min": -5.0, "max": 5.0, "step": 0.001, "unit": " ms"},
		],
	},
	{
		"id": "click_track",
		"label": "Click Track",
		"group": GROUP_UTILITY,
		"blurb": "Plays a metronome click at a set tempo over the sound, with the first beat of each bar higher, so you can cut to the beat of a song. Turn it off before you export.",
		"params": [
			{"key": "bpm", "label": "Tempo", "default": 120.0, "min": 30.0, "max": 300.0, "step": 0.1, "unit": " bpm"},
			{"key": "beats", "label": "Beats in a bar", "default": 4.0, "min": 1.0, "max": 12.0, "step": 1.0},
			{"key": "sound", "label": "Sound", "default": 0.0, "choices": ["Click", "Wood block", "Beep"]},
			{"key": "level_db", "label": "Click level", "default": -12.0, "min": -40.0, "max": 0.0, "step": 0.5, "unit": " dB"},
			{"key": "first_s", "label": "First beat at", "default": 0.0, "min": 0.0, "max": 10.0, "step": 0.001, "unit": " s"},
			{"key": "keep", "label": "Keep the sound under it", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
]
