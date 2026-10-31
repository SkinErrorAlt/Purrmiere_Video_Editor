extends RefCounted

const G_EQ := "EQ and Filters"
const G_STEREO := "Stereo"
const G_UTILITY := "Utility"
const G_DYN := "Dynamics"
const G_REPAIR := "Repair"
const G_VOICE := "Voice"
const G_SPACE := "Delay and Reverb"
const G_CHAR := "Character"
const G_PRESETS := "Presets"
const KEYS: Array = ["Key A", "Key B", "Key C", "Key D"]
const OUT := {"key": "output_db", "label": "Output", "default": 0.0, "min": -24.0, "max": 12.0, "step": 0.1, "unit": " dB"}
const GAIN_OUT := {"id": "gain", "p": {"db": "output_db"}}
const BW_Q1 := 0.5098
const BW_Q2 := 0.6013
const BW_Q3 := 0.9
const BW_Q4 := 2.5629
const HQ := 2.87
const TQ := 4.32

const DEFS: Array[Dictionary] = [
	{
		"id": "fill_left_with_right", "group": G_STEREO, "label": "Fill Left with Right",
		"blurb": "Copies the right channel into the left, for a recording where only the right side has the voice.",
		"params": [{"key": "amount", "label": "Amount", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [{"id": "stereo_matrix", "p": {"left_from_left": ["amount", -1.0, 1.0], "left_from_right": "amount", "right_from_left": 0.0, "right_from_right": 1.0}}],
	},
	{
		"id": "fill_right_with_left", "group": G_STEREO, "label": "Fill Right with Left",
		"blurb": "Copies the left channel into the right, for a recording where only the left side has the voice.",
		"params": [{"key": "amount", "label": "Amount", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [{"id": "stereo_matrix", "p": {"left_from_left": 1.0, "left_from_right": 0.0, "right_from_left": "amount", "right_from_right": ["amount", -1.0, 1.0]}}],
	},
	{
		"id": "channel_volume", "group": G_UTILITY, "label": "Channel Volume",
		"blurb": "Turns the left and the right channel up or down on their own.",
		"params": [
			{"key": "left_db", "label": "Left", "default": 0.0, "min": -60.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "right_db", "label": "Right", "default": 0.0, "min": -60.0, "max": 12.0, "step": 0.1, "unit": " dB"},
		],
		"chain": [
			{"id": "stereo_matrix", "p": {"left_from_left": ["left_db", "db", -12.0], "left_from_right": 0.0, "right_from_left": 0.0, "right_from_right": ["right_db", "db", -12.0]}},
			{"id": "gain", "p": {"db": 12.0}},
		],
	},
	{
		"id": "bass_tone", "group": G_EQ, "label": "Bass",
		"blurb": "Lifts or cuts the low end below about 200 Hz with one knob.",
		"params": [{"key": "boost_db", "label": "Boost", "default": 4.0, "min": -24.0, "max": 24.0, "step": 0.1, "unit": " dB"}],
		"chain": [{"id": "low_shelf", "p": {"freq": 200.0, "gain": "boost_db", "q": 0.7071}}],
	},
	{
		"id": "treble_tone", "group": G_EQ, "label": "Treble",
		"blurb": "Lifts or cuts the top end above about 4 kHz with one knob.",
		"params": [{"key": "boost_db", "label": "Boost", "default": 4.0, "min": -24.0, "max": 24.0, "step": 0.1, "unit": " dB"}],
		"chain": [{"id": "high_shelf", "p": {"freq": 4000.0, "gain": "boost_db", "q": 0.7071}}],
	},
	{
		"id": "mute_audio", "group": G_UTILITY, "label": "Mute",
		"blurb": "Silences the clip without removing it, and can be keyed to mute only a stretch.",
		"no_guard": true,
		"params": [{"key": "amount", "label": "Amount", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [{"id": "stereo_matrix", "p": {"left_from_left": ["amount", -1.0, 1.0], "left_from_right": 0.0, "right_from_left": 0.0, "right_from_right": ["amount", -1.0, 1.0]}}],
	},
	{
		"id": "graphic_eq20", "group": G_EQ, "label": "Graphic EQ, 20 bands",
		"blurb": "Twenty sliders half an octave apart, from 22 Hz to 16 kHz.",
		"params": [
			{"key": "g22", "label": "22 Hz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g31", "label": "31 Hz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g44", "label": "44 Hz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g63", "label": "63 Hz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g88", "label": "88 Hz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g125", "label": "125 Hz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g177", "label": "177 Hz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g250", "label": "250 Hz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g355", "label": "355 Hz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g500", "label": "500 Hz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g710", "label": "710 Hz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g1k", "label": "1 kHz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g1k4", "label": "1.4 kHz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g2k", "label": "2 kHz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g2k8", "label": "2.8 kHz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g4k", "label": "4 kHz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g5k6", "label": "5.6 kHz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g8k", "label": "8 kHz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g11k", "label": "11 kHz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g16k", "label": "16 kHz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
		],
		"chain": [
			{"id": "eq3", "p": {"low_hz": 22.0, "low_db": "g22", "low_q": HQ, "mid_hz": 31.5, "mid_db": "g31", "mid_q": HQ, "high_hz": 44.0, "high_db": "g44", "high_q": HQ}},
			{"id": "eq3", "p": {"low_hz": 63.0, "low_db": "g63", "low_q": HQ, "mid_hz": 88.0, "mid_db": "g88", "mid_q": HQ, "high_hz": 125.0, "high_db": "g125", "high_q": HQ}},
			{"id": "eq3", "p": {"low_hz": 177.0, "low_db": "g177", "low_q": HQ, "mid_hz": 250.0, "mid_db": "g250", "mid_q": HQ, "high_hz": 355.0, "high_db": "g355", "high_q": HQ}},
			{"id": "eq3", "p": {"low_hz": 500.0, "low_db": "g500", "low_q": HQ, "mid_hz": 710.0, "mid_db": "g710", "mid_q": HQ, "high_hz": 1000.0, "high_db": "g1k", "high_q": HQ}},
			{"id": "eq3", "p": {"low_hz": 1400.0, "low_db": "g1k4", "low_q": HQ, "mid_hz": 2000.0, "mid_db": "g2k", "mid_q": HQ, "high_hz": 2800.0, "high_db": "g2k8", "high_q": HQ}},
			{"id": "eq3", "p": {"low_hz": 4000.0, "low_db": "g4k", "low_q": HQ, "mid_hz": 5600.0, "mid_db": "g5k6", "mid_q": HQ, "high_hz": 8000.0, "high_db": "g8k", "high_q": HQ}},
			{"id": "eq3", "p": {"low_hz": 11200.0, "low_db": "g11k", "low_q": HQ, "mid_hz": 16000.0, "mid_db": "g16k", "mid_q": HQ, "high_hz": 20000.0, "high_db": 0.0, "high_q": HQ}},
		],
	},
	{
		"id": "graphic_eq30", "group": G_EQ, "label": "Graphic EQ, 30 bands",
		"blurb": "Thirty sliders a third of an octave apart, from 25 Hz to 20 kHz, the standard room and live sound layout.",
		"params": [
			{"key": "g25", "label": "25 Hz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g31", "label": "31.5 Hz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g40", "label": "40 Hz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g50", "label": "50 Hz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g63", "label": "63 Hz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g80", "label": "80 Hz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g100", "label": "100 Hz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g125", "label": "125 Hz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g160", "label": "160 Hz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g200", "label": "200 Hz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g250", "label": "250 Hz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g315", "label": "315 Hz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g400", "label": "400 Hz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g500", "label": "500 Hz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g630", "label": "630 Hz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g800", "label": "800 Hz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g1k", "label": "1 kHz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g1k25", "label": "1.25 kHz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g1k6", "label": "1.6 kHz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g2k", "label": "2 kHz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g2k5", "label": "2.5 kHz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g3k15", "label": "3.15 kHz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g4k", "label": "4 kHz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g5k", "label": "5 kHz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g6k3", "label": "6.3 kHz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g8k", "label": "8 kHz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g10k", "label": "10 kHz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g12k5", "label": "12.5 kHz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g16k", "label": "16 kHz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "g20k", "label": "20 kHz", "default": 0.0, "min": -12.0, "max": 12.0, "step": 0.1, "unit": " dB"},
		],
		"chain": [
			{"id": "eq3", "p": {"low_hz": 25.0, "low_db": "g25", "low_q": TQ, "mid_hz": 31.5, "mid_db": "g31", "mid_q": TQ, "high_hz": 40.0, "high_db": "g40", "high_q": TQ}},
			{"id": "eq3", "p": {"low_hz": 50.0, "low_db": "g50", "low_q": TQ, "mid_hz": 63.0, "mid_db": "g63", "mid_q": TQ, "high_hz": 80.0, "high_db": "g80", "high_q": TQ}},
			{"id": "eq3", "p": {"low_hz": 100.0, "low_db": "g100", "low_q": TQ, "mid_hz": 125.0, "mid_db": "g125", "mid_q": TQ, "high_hz": 160.0, "high_db": "g160", "high_q": TQ}},
			{"id": "eq3", "p": {"low_hz": 200.0, "low_db": "g200", "low_q": TQ, "mid_hz": 250.0, "mid_db": "g250", "mid_q": TQ, "high_hz": 315.0, "high_db": "g315", "high_q": TQ}},
			{"id": "eq3", "p": {"low_hz": 400.0, "low_db": "g400", "low_q": TQ, "mid_hz": 500.0, "mid_db": "g500", "mid_q": TQ, "high_hz": 630.0, "high_db": "g630", "high_q": TQ}},
			{"id": "eq3", "p": {"low_hz": 800.0, "low_db": "g800", "low_q": TQ, "mid_hz": 1000.0, "mid_db": "g1k", "mid_q": TQ, "high_hz": 1250.0, "high_db": "g1k25", "high_q": TQ}},
			{"id": "eq3", "p": {"low_hz": 1600.0, "low_db": "g1k6", "low_q": TQ, "mid_hz": 2000.0, "mid_db": "g2k", "mid_q": TQ, "high_hz": 2500.0, "high_db": "g2k5", "high_q": TQ}},
			{"id": "eq3", "p": {"low_hz": 3150.0, "low_db": "g3k15", "low_q": TQ, "mid_hz": 4000.0, "mid_db": "g4k", "mid_q": TQ, "high_hz": 5000.0, "high_db": "g5k", "high_q": TQ}},
			{"id": "eq3", "p": {"low_hz": 6300.0, "low_db": "g6k3", "low_q": TQ, "mid_hz": 8000.0, "mid_db": "g8k", "mid_q": TQ, "high_hz": 10000.0, "high_db": "g10k", "high_q": TQ}},
			{"id": "eq3", "p": {"low_hz": 12500.0, "low_db": "g12k5", "low_q": TQ, "mid_hz": 16000.0, "mid_db": "g16k", "mid_q": TQ, "high_hz": 20000.0, "high_db": "g20k", "high_q": TQ}},
		],
	},
	{
		"id": "simple_parametric_eq", "group": G_EQ, "label": "Simple Parametric EQ",
		"blurb": "One bell shaped band: pick the frequency, how much and how wide.",
		"params": [
			{"key": "freq", "label": "Frequency", "default": 1000.0, "min": 20.0, "max": 20000.0, "step": 10.0, "unit": " Hz"},
			{"key": "gain_db", "label": "Gain", "default": 0.0, "min": -24.0, "max": 24.0, "step": 0.1, "unit": " dB"},
			{"key": "q", "label": "Width", "default": 1.0, "min": 0.1, "max": 12.0, "step": 0.01},
		],
		"chain": [{"id": "eq3", "p": {"low_db": 0.0, "mid_hz": "freq", "mid_db": "gain_db", "mid_q": "q", "high_db": 0.0}}],
	},
	{
		"id": "notch_six", "group": G_EQ, "label": "Notch Filter, six notches",
		"blurb": "Up to six narrow cuts at frequencies you set, for whistles, buzzes and tones that sit still. A notch at 0 dB is off.",
		"params": [
			{"key": "n1_hz", "label": "Notch 1", "default": 100.0, "min": 20.0, "max": 20000.0, "step": 1.0, "unit": " Hz"},
			{"key": "n1_db", "label": "Notch 1 depth", "default": 0.0, "min": -80.0, "max": 0.0, "step": 0.5, "unit": " dB"},
			{"key": "n2_hz", "label": "Notch 2", "default": 200.0, "min": 20.0, "max": 20000.0, "step": 1.0, "unit": " Hz"},
			{"key": "n2_db", "label": "Notch 2 depth", "default": 0.0, "min": -80.0, "max": 0.0, "step": 0.5, "unit": " dB"},
			{"key": "n3_hz", "label": "Notch 3", "default": 400.0, "min": 20.0, "max": 20000.0, "step": 1.0, "unit": " Hz"},
			{"key": "n3_db", "label": "Notch 3 depth", "default": 0.0, "min": -80.0, "max": 0.0, "step": 0.5, "unit": " dB"},
			{"key": "n4_hz", "label": "Notch 4", "default": 800.0, "min": 20.0, "max": 20000.0, "step": 1.0, "unit": " Hz"},
			{"key": "n4_db", "label": "Notch 4 depth", "default": 0.0, "min": -80.0, "max": 0.0, "step": 0.5, "unit": " dB"},
			{"key": "n5_hz", "label": "Notch 5", "default": 1600.0, "min": 20.0, "max": 20000.0, "step": 1.0, "unit": " Hz"},
			{"key": "n5_db", "label": "Notch 5 depth", "default": 0.0, "min": -80.0, "max": 0.0, "step": 0.5, "unit": " dB"},
			{"key": "n6_hz", "label": "Notch 6", "default": 3200.0, "min": 20.0, "max": 20000.0, "step": 1.0, "unit": " Hz"},
			{"key": "n6_db", "label": "Notch 6 depth", "default": 0.0, "min": -80.0, "max": 0.0, "step": 0.5, "unit": " dB"},
			{"key": "q", "label": "Narrowness", "default": 8.0, "min": 0.5, "max": 40.0, "step": 0.1},
		],
		"chain": [
			{"id": "notch", "p": {"freq": "n1_hz", "depth": "n1_db", "q": "q"}},
			{"id": "notch", "p": {"freq": "n2_hz", "depth": "n2_db", "q": "q"}},
			{"id": "notch", "p": {"freq": "n3_hz", "depth": "n3_db", "q": "q"}},
			{"id": "notch", "p": {"freq": "n4_hz", "depth": "n4_db", "q": "q"}},
			{"id": "notch", "p": {"freq": "n5_hz", "depth": "n5_db", "q": "q"}},
			{"id": "notch", "p": {"freq": "n6_hz", "depth": "n6_db", "q": "q"}},
		],
	},
	{
		"id": "steep_lowpass", "group": G_EQ, "label": "Steep Low Pass, 48 dB per octave",
		"blurb": "An eighth order Butterworth low pass: flat right up to the cutoff, then a cliff. For cutting hiss or making a hard band edge.",
		"params": [{"key": "cutoff", "label": "Cutoff", "default": 8000.0, "min": 20.0, "max": 20000.0, "step": 10.0, "unit": " Hz"}],
		"chain": [
			{"id": "lowpass", "p": {"cutoff": "cutoff", "q": BW_Q1}},
			{"id": "lowpass", "p": {"cutoff": "cutoff", "q": BW_Q2}},
			{"id": "lowpass", "p": {"cutoff": "cutoff", "q": BW_Q3}},
			{"id": "lowpass", "p": {"cutoff": "cutoff", "q": BW_Q4}},
		],
	},
	{
		"id": "steep_highpass", "group": G_EQ, "label": "Steep High Pass, 48 dB per octave",
		"blurb": "An eighth order Butterworth high pass, for taking out rumble and handling noise right up to the voice without thinning it.",
		"params": [{"key": "cutoff", "label": "Cutoff", "default": 120.0, "min": 20.0, "max": 20000.0, "step": 1.0, "unit": " Hz"}],
		"chain": [
			{"id": "highpass", "p": {"cutoff": "cutoff", "q": BW_Q1}},
			{"id": "highpass", "p": {"cutoff": "cutoff", "q": BW_Q2}},
			{"id": "highpass", "p": {"cutoff": "cutoff", "q": BW_Q3}},
			{"id": "highpass", "p": {"cutoff": "cutoff", "q": BW_Q4}},
		],
	},
	{
		"id": "steep_bandpass", "group": G_EQ, "label": "Steep Band Pass, 48 dB per octave",
		"blurb": "Keeps only what sits between two frequencies, with steep walls on both sides.",
		"params": [
			{"key": "low_hz", "label": "From", "default": 300.0, "min": 20.0, "max": 20000.0, "step": 1.0, "unit": " Hz"},
			{"key": "high_hz", "label": "To", "default": 3400.0, "min": 20.0, "max": 20000.0, "step": 10.0, "unit": " Hz"},
		],
		"chain": [
			{"id": "highpass", "p": {"cutoff": "low_hz", "q": BW_Q1}},
			{"id": "highpass", "p": {"cutoff": "low_hz", "q": BW_Q2}},
			{"id": "highpass", "p": {"cutoff": "low_hz", "q": BW_Q3}},
			{"id": "highpass", "p": {"cutoff": "low_hz", "q": BW_Q4}},
			{"id": "lowpass", "p": {"cutoff": "high_hz", "q": BW_Q1}},
			{"id": "lowpass", "p": {"cutoff": "high_hz", "q": BW_Q2}},
			{"id": "lowpass", "p": {"cutoff": "high_hz", "q": BW_Q3}},
			{"id": "lowpass", "p": {"cutoff": "high_hz", "q": BW_Q4}},
		],
	},
	{
		"id": "dynamics_suite", "group": G_DYN, "label": "Dynamics",
		"blurb": "Gate, expander, compressor and limiter in one, in that order, each with its own threshold.",
		"params": [
			{"key": "gate_db", "label": "Gate shuts below", "default": -70.0, "min": -90.0, "max": 0.0, "step": 0.5, "unit": " dB"},
			{"key": "expand_db", "label": "Expander below", "default": -50.0, "min": -80.0, "max": 0.0, "step": 0.5, "unit": " dB"},
			{"key": "expand_ratio", "label": "Expander ratio", "default": 2.0, "min": 1.0, "max": 10.0, "step": 0.1},
			{"key": "comp_db", "label": "Compressor threshold", "default": -20.0, "min": -80.0, "max": 0.0, "step": 0.5, "unit": " dB"},
			{"key": "comp_ratio", "label": "Compressor ratio", "default": 3.0, "min": 1.0, "max": 40.0, "step": 0.1},
			{"key": "attack_ms", "label": "Attack", "default": 10.0, "min": 0.1, "max": 500.0, "step": 0.1, "unit": " ms"},
			{"key": "release_ms", "label": "Release", "default": 150.0, "min": 1.0, "max": 5000.0, "step": 1.0, "unit": " ms"},
			{"key": "makeup_db", "label": "Makeup", "default": 2.0, "min": -24.0, "max": 24.0, "step": 0.1, "unit": " dB"},
			{"key": "ceiling_db", "label": "Limiter ceiling", "default": -1.0, "min": -24.0, "max": 0.0, "step": 0.1, "unit": " dB"},
		],
		"chain": [
			{"id": "noise_gate", "p": {"threshold_db": "gate_db", "floor_db": -60.0}},
			{"id": "expander", "p": {"threshold_db": "expand_db", "ratio": "expand_ratio"}},
			{"id": "compressor", "p": {"threshold_db": "comp_db", "ratio": "comp_ratio", "attack_ms": "attack_ms", "release_ms": "release_ms", "makeup_db": "makeup_db"}},
			{"id": "limiter", "p": {"ceiling_db": "ceiling_db"}},
		],
	},
	{
		"id": "vocal_enhancer", "group": G_VOICE, "label": "Vocal Enhancer",
		"blurb": "One switch voice polish: a low cut, less mud, more presence and gentle compression, tuned for a low voice, a high voice or music.",
		"params": [
			{"key": "mode", "label": "Tuned for", "default": 0.0, "choices": ["Low voice", "High voice", "Music"]},
			{"key": "amount", "label": "Amount", "default": 0.7, "min": 0.0, "max": 1.0, "step": 0.01},
		],
		"chain": [
			{"id": "highpass", "p": {"cutoff": ["mode", "pick", [70.0, 110.0, 35.0]], "q": 0.7071}},
			{"id": "eq3", "p": {"low_hz": ["mode", "pick", [220.0, 300.0, 250.0]], "low_db": ["amount", -3.0, 0.0], "low_q": 1.0, "mid_hz": ["mode", "pick", [3200.0, 4200.0, 2500.0]], "mid_db": ["amount", 3.5, 0.0], "mid_q": 0.8, "high_hz": 10000.0, "high_db": ["amount", 2.5, 0.0], "high_q": 0.7}},
			{"id": "compressor", "p": {"threshold_db": -22.0, "ratio": ["mode", "pick", [3.0, 3.0, 1.8]], "attack_ms": 8.0, "release_ms": 140.0}},
		],
	},
	{
		"id": "presence_boost", "group": G_VOICE, "label": "Presence Boost",
		"blurb": "Lifts the part of a voice that carries the words, around 4 to 5 kHz, so speech cuts through music.",
		"params": [
			{"key": "amount_db", "label": "Amount", "default": 3.0, "min": 0.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "freq", "label": "Centre", "default": 4500.0, "min": 2000.0, "max": 8000.0, "step": 10.0, "unit": " Hz"},
			{"key": "width", "label": "Width", "default": 0.8, "min": 0.3, "max": 4.0, "step": 0.01},
		],
		"chain": [{"id": "eq3", "p": {"low_db": 0.0, "mid_hz": "freq", "mid_db": "amount_db", "mid_q": "width", "high_db": 0.0}}],
	},
	{
		"id": "voice_clarity", "group": G_VOICE, "label": "Voice Clarity",
		"blurb": "Cuts rumble and mud, adds presence and air, and tames the s sounds that the extra brightness brings out.",
		"params": [{"key": "amount", "label": "Amount", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [
			{"id": "highpass", "p": {"cutoff": 90.0, "q": 0.7071}},
			{"id": "eq3", "p": {"low_hz": 260.0, "low_db": ["amount", -4.0, 0.0], "low_q": 1.0, "mid_hz": 3500.0, "mid_db": ["amount", 4.0, 0.0], "mid_q": 0.8, "high_hz": 11000.0, "high_db": ["amount", 3.0, 0.0], "high_q": 0.7}},
			{"id": "de_esser", "p": {"freq": 6500.0, "threshold_db": -28.0, "range_db": ["amount", 10.0, 0.0]}},
		],
	},
	{
		"id": "pop_and_rumble_cleanup", "group": G_REPAIR, "label": "Pop and Rumble Clean Up",
		"blurb": "Takes out low rumble, handling noise and the thumps of p and b sounds in one go.",
		"params": [
			{"key": "low_cut", "label": "Rumble below", "default": 80.0, "min": 20.0, "max": 300.0, "step": 1.0, "unit": " Hz"},
			{"key": "strength_db", "label": "Pop strength", "default": 12.0, "min": 0.0, "max": 30.0, "step": 0.5, "unit": " dB"},
		],
		"chain": [
			{"id": "de_rumble", "p": {"freq": "low_cut", "slope": 1.0}},
			{"id": "plosive_softener", "p": {"strength_db": "strength_db"}},
		],
	},
	{
		"id": "mouth_and_breath_cleanup", "group": G_REPAIR, "label": "Mouth and Breath Clean Up",
		"blurb": "Softens lip smacks, mouth clicks and loud breaths between phrases, for voiceover and close microphones.",
		"params": [
			{"key": "breath_db", "label": "Breaths down by", "default": 10.0, "min": 0.0, "max": 40.0, "step": 0.5, "unit": " dB"},
			{"key": "click_db", "label": "Clicks down by", "default": 18.0, "min": 0.0, "max": 40.0, "step": 0.5, "unit": " dB"},
		],
		"chain": [
			{"id": "click_remover", "p": {"sensitivity": 0.4}},
			{"id": "mouth_click_softener", "p": {"reduction_db": "click_db"}},
			{"id": "breath_reducer", "p": {"reduction_db": "breath_db"}},
		],
	},
	{
		"id": "hum_and_hiss_cleanup", "group": G_REPAIR, "label": "Hum and Hiss Clean Up",
		"blurb": "Finds and removes mains hum and its harmonics, then turns down steady hiss in the top end.",
		"params": [
			{"key": "hum", "label": "Hum removal", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "hiss_db", "label": "Hiss down by", "default": 10.0, "min": 0.0, "max": 30.0, "step": 0.5, "unit": " dB"},
		],
		"chain": [
			{"id": "hum_remover", "p": {"mains": 0.0, "amount": "hum"}},
			{"id": "de_hiss", "p": {"reduction_db": "hiss_db"}},
		],
	},
	{
		"id": "echo_room_cleanup", "group": G_REPAIR, "label": "Echoey Room Clean Up",
		"blurb": "Pulls back the room sound behind a voice and lets the tail between words fall away.",
		"params": [{"key": "amount", "label": "Amount", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [
			{"id": "dereverb", "p": {"amount": "amount"}},
			{"id": "expander", "p": {"threshold_db": -50.0, "ratio": 1.6, "range_db": -12.0}},
			{"id": "eq3", "p": {"low_hz": 300.0, "low_db": ["amount", -3.0, 0.0], "low_q": 1.0, "mid_db": 0.0, "high_db": 0.0}},
		],
	},
	{
		"id": "harsh_voice_tamer", "group": G_VOICE, "label": "Harsh Voice Tamer",
		"blurb": "Turns down the piercing 3 kHz and 6 kHz parts of a voice only at the moments they get loud, so the voice stays bright the rest of the time.",
		"params": [
			{"key": "depth_db", "label": "Most it cuts", "default": 6.0, "min": 0.0, "max": 24.0, "step": 0.5, "unit": " dB"},
			{"key": "threshold_db", "label": "Starts at", "default": -30.0, "min": -60.0, "max": 0.0, "step": 0.5, "unit": " dB"},
		],
		"chain": [
			{"id": "dynamic_eq", "p": {"freq": 3000.0, "q": 1.5, "threshold_db": "threshold_db", "range_db": "depth_db", "mode": 0.0}},
			{"id": "dynamic_eq", "p": {"freq": 6500.0, "q": 2.0, "threshold_db": "threshold_db", "range_db": "depth_db", "mode": 0.0}},
		],
	},
	{
		"id": "sibilance_fix", "group": G_VOICE, "label": "Sibilance Fix",
		"blurb": "A de-esser and a narrow dynamic cut together, for voices with sharp s and sh sounds.",
		"params": [
			{"key": "threshold_db", "label": "Starts at", "default": -30.0, "min": -58.0, "max": 0.0, "step": 0.5, "unit": " dB"},
			{"key": "range_db", "label": "Most it cuts", "default": 10.0, "min": 0.0, "max": 24.0, "step": 0.5, "unit": " dB"},
		],
		"chain": [
			{"id": "de_esser", "p": {"freq": 6500.0, "threshold_db": "threshold_db", "range_db": "range_db"}},
			{"id": "dynamic_eq", "p": {"freq": 8500.0, "q": 2.0, "threshold_db": ["threshold_db", 1.0, -2.0], "range_db": ["range_db", 0.6, 0.0], "mode": 0.0}},
		],
	},
	{
		"id": "mud_cut", "group": G_EQ, "label": "Mud and Boxiness Cut",
		"blurb": "Thins out the cloudy 250 to 500 Hz area that makes a voice sound like it is in a cardboard box.",
		"params": [{"key": "amount_db", "label": "Amount", "default": 4.0, "min": 0.0, "max": 12.0, "step": 0.1, "unit": " dB"}],
		"chain": [{"id": "eq3", "p": {"low_hz": 250.0, "low_db": ["amount_db", -1.0, 0.0], "low_q": 1.0, "mid_hz": 500.0, "mid_db": ["amount_db", -0.5, 0.0], "mid_q": 1.4, "high_db": 0.0}}],
	},
	{
		"id": "nasal_cut", "group": G_EQ, "label": "Nasal Voice Fix",
		"blurb": "A narrow cut around 1 kHz for a voice that sounds pinched or honky.",
		"params": [
			{"key": "amount_db", "label": "Amount", "default": 4.0, "min": 0.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "freq", "label": "Centre", "default": 1000.0, "min": 600.0, "max": 2000.0, "step": 10.0, "unit": " Hz"},
		],
		"chain": [{"id": "eq3", "p": {"low_db": 0.0, "mid_hz": "freq", "mid_db": ["amount_db", -1.0, 0.0], "mid_q": 2.0, "high_db": 0.0}}],
	},
	{
		"id": "warm_voice", "group": G_VOICE, "label": "Warm Voice",
		"blurb": "A touch more chest, a little less edge and some soft tape colour.",
		"params": [{"key": "amount", "label": "Amount", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [
			{"id": "eq3", "p": {"low_hz": 180.0, "low_db": ["amount", 3.0, 0.0], "low_q": 0.8, "mid_db": 0.0, "high_hz": 9000.0, "high_db": ["amount", -2.0, 0.0], "high_q": 0.7}},
			{"id": "tape_saturation", "p": {"drive_db": ["amount", 5.0, 0.0], "mix": ["amount", 0.6, 0.0]}},
		],
	},
	{
		"id": "dialogue_level_gentle", "group": G_DYN, "label": "Dialogue Leveling, gentle",
		"blurb": "Evens out a speaker who drifts nearer and further from the microphone, slowly and without pumping.",
		"params": [{"key": "target", "label": "Target level", "default": -20.0, "min": -40.0, "max": -6.0, "step": 0.5, "unit": " dB"}],
		"chain": [
			{"id": "leveler", "p": {"target": "target", "max_boost": 8.0, "max_cut": 8.0, "speed": 2.0}},
			{"id": "compressor", "p": {"threshold_db": ["target", 1.0, 2.0], "ratio": 2.0, "attack_ms": 15.0, "release_ms": 200.0}},
		],
	},
	{
		"id": "dialogue_level_strong", "group": G_DYN, "label": "Dialogue Leveling, strong",
		"blurb": "Holds a voice at one level whatever happens: whispers come up and shouts come down.",
		"params": [{"key": "target", "label": "Target level", "default": -20.0, "min": -40.0, "max": -6.0, "step": 0.5, "unit": " dB"}],
		"chain": [
			{"id": "leveler", "p": {"target": "target", "max_boost": 15.0, "max_cut": 15.0, "speed": 6.0}},
			{"id": "compressor", "p": {"threshold_db": ["target", 1.0, -2.0], "ratio": 4.0, "attack_ms": 5.0, "release_ms": 120.0}},
		],
	},
	{
		"id": "duck_music_gentle", "group": G_DYN, "label": "Duck Under Voice, gentle",
		"blurb": "Lowers this sound a little while the voice on the chosen key is talking. Put Duck key on the voice track.",
		"params": [
			{"key": "key", "label": "Listen to", "default": 0.0, "choices": KEYS},
			{"key": "amount_db", "label": "Lowers by", "default": -8.0, "min": -40.0, "max": 0.0, "step": 0.5, "unit": " dB"},
		],
		"chain": [{"id": "ducker", "p": {"key": "key", "amount_db": "amount_db", "attack_ms": 80.0, "hold_ms": 300.0, "release_ms": 900.0}}],
	},
	{
		"id": "duck_music_strong", "group": G_DYN, "label": "Duck Under Voice, strong",
		"blurb": "Drops this sound well down while the voice on the chosen key is talking, and brings it back quickly in the gaps.",
		"params": [
			{"key": "key", "label": "Listen to", "default": 0.0, "choices": KEYS},
			{"key": "amount_db", "label": "Lowers by", "default": -18.0, "min": -40.0, "max": 0.0, "step": 0.5, "unit": " dB"},
		],
		"chain": [{"id": "ducker", "p": {"key": "key", "amount_db": "amount_db", "attack_ms": 20.0, "hold_ms": 200.0, "release_ms": 400.0}}],
	},
	{
		"id": "duck_music_voice_band", "group": G_DYN, "label": "Duck Under Voice, voice range only",
		"blurb": "Carves a hole only in the voice range of the music while someone talks, so the bass and the sparkle keep going.",
		"params": [
			{"key": "key", "label": "Listen to", "default": 0.0, "choices": KEYS},
			{"key": "amount_db", "label": "Lowers by", "default": -12.0, "min": -40.0, "max": 0.0, "step": 0.5, "unit": " dB"},
		],
		"chain": [{"id": "ducker", "p": {"key": "key", "amount_db": "amount_db", "band": 1.0, "release_ms": 600.0}}],
	},
	{
		"id": "safe_peak_limiter", "group": G_DYN, "label": "Safe Peak Limiter",
		"blurb": "A fast compressor into a brick wall a little under full scale, leaving room for the peaks between samples that some players add.",
		"params": [{"key": "ceiling_db", "label": "Ceiling", "default": -2.0, "min": -12.0, "max": -1.0, "step": 0.1, "unit": " dB"}],
		"chain": [
			{"id": "compressor", "p": {"threshold_db": ["ceiling_db", 1.0, -4.0], "ratio": 10.0, "attack_ms": 1.0, "release_ms": 60.0, "knee_db": 3.0}},
			{"id": "limiter", "p": {"ceiling_db": "ceiling_db", "release_ms": 50.0}},
		],
	},
	{
		"id": "youtube_loudness", "group": G_DYN, "label": "Loudness for YouTube",
		"blurb": "Brings the clip to -14 LUFS with peaks held under -1 dB, the level YouTube plays at.",
		"params": [{"key": "ceiling_db", "label": "Peak ceiling", "default": -1.0, "min": -6.0, "max": 0.0, "step": 0.1, "unit": " dB"}],
		"chain": [{"id": "loudness_normaliser", "p": {"target": 0.0, "ceiling_db": "ceiling_db"}}],
	},
	{
		"id": "podcast_loudness", "group": G_DYN, "label": "Loudness for Podcasts",
		"blurb": "Brings the clip to -16 LUFS with peaks held under -1 dB, the usual level for podcasts.",
		"params": [{"key": "ceiling_db", "label": "Peak ceiling", "default": -1.0, "min": -6.0, "max": 0.0, "step": 0.1, "unit": " dB"}],
		"chain": [{"id": "loudness_normaliser", "p": {"target": 1.0, "ceiling_db": "ceiling_db"}}],
	},
	{
		"id": "broadcast_loudness", "group": G_DYN, "label": "Loudness for Broadcast",
		"blurb": "Brings the clip to -23 LUFS, the EBU R128 level for television.",
		"params": [{"key": "ceiling_db", "label": "Peak ceiling", "default": -1.0, "min": -6.0, "max": 0.0, "step": 0.1, "unit": " dB"}],
		"chain": [{"id": "loudness_normaliser", "p": {"target": 2.0, "ceiling_db": "ceiling_db"}}],
	},
	{
		"id": "three_band_expander", "group": G_DYN, "label": "Multiband Expander",
		"blurb": "Turns the lows, middle and highs down on their own when each goes quiet, so noise under a voice drops away band by band.",
		"params": [
			{"key": "threshold_db", "label": "Below", "default": -45.0, "min": -60.0, "max": 0.0, "step": 0.5, "unit": " dB"},
			{"key": "range_db", "label": "Most it lowers", "default": 9.0, "min": 0.0, "max": 24.0, "step": 0.5, "unit": " dB"},
		],
		"chain": [
			{"id": "dynamic_eq", "p": {"freq": 150.0, "q": 0.5, "threshold_db": "threshold_db", "range_db": "range_db", "mode": 1.0}},
			{"id": "dynamic_eq", "p": {"freq": 1500.0, "q": 0.5, "threshold_db": "threshold_db", "range_db": "range_db", "mode": 1.0}},
			{"id": "dynamic_eq", "p": {"freq": 8000.0, "q": 0.7, "threshold_db": "threshold_db", "range_db": "range_db", "mode": 1.0}},
		],
	},
	{
		"id": "keyed_gate", "group": G_DYN, "label": "Gate Opened by Another Track",
		"blurb": "Lets this sound through only while the track on the chosen key plays, for tightening a bleed microphone to its own instrument.",
		"params": [
			{"key": "key", "label": "Listen to", "default": 0.0, "choices": KEYS},
			{"key": "open_db", "label": "Opens above", "default": -40.0, "min": -74.0, "max": 0.0, "step": 0.5, "unit": " dB"},
			{"key": "range_db", "label": "How far it shuts", "default": -40.0, "min": -90.0, "max": 0.0, "step": 0.5, "unit": " dB"},
		],
		"chain": [{"id": "gate_pro", "p": {"key": ["key", 1.0, 1.0], "open_db": "open_db", "close_db": ["open_db", 1.0, -6.0], "range_db": "range_db"}}],
	},
	{
		"id": "shout_tamer", "group": G_DYN, "label": "Shout Tamer",
		"blurb": "Catches screams, laughs and sudden shouts fast, for gaming and reaction videos.",
		"params": [{"key": "threshold_db", "label": "Starts at", "default": -16.0, "min": -40.0, "max": 0.0, "step": 0.5, "unit": " dB"}],
		"chain": [
			{"id": "compressor", "p": {"threshold_db": "threshold_db", "ratio": 8.0, "attack_ms": 1.0, "release_ms": 120.0, "knee_db": 4.0}},
			{"id": "limiter", "p": {"ceiling_db": -3.0, "release_ms": 80.0}},
		],
	},
	{
		"id": "quiet_voice_lift", "group": G_DYN, "label": "Quiet Voice Lift",
		"blurb": "Brings up soft speech and trailing word ends without making the loud parts any louder.",
		"params": [{"key": "max_gain", "label": "Most it lifts", "default": 12.0, "min": 0.0, "max": 30.0, "step": 0.5, "unit": " dB"}],
		"chain": [
			{"id": "upward_compressor", "p": {"threshold_db": -38.0, "ratio": 2.0, "max_gain": "max_gain"}},
			{"id": "compressor", "p": {"threshold_db": -14.0, "ratio": 3.0, "attack_ms": 5.0, "release_ms": 100.0}},
		],
	},
	{
		"id": "small_room_voice", "group": G_SPACE, "label": "Small Room",
		"blurb": "A short, natural room around a voice, for matching a dry booth recording to a camera shot.",
		"params": [{"key": "mix", "label": "Mix", "default": 0.15, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [{"id": "room", "p": {"size": 0.25, "decay_s": 0.45, "predelay_ms": 4.0, "mix": "mix"}}],
	},
	{
		"id": "large_room", "group": G_SPACE, "label": "Large Room",
		"blurb": "A big lively room, like a gym or a function hall.",
		"params": [{"key": "mix", "label": "Mix", "default": 0.25, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [{"id": "room", "p": {"size": 0.85, "decay_s": 1.3, "predelay_ms": 18.0, "mix": "mix"}}],
	},
	{
		"id": "vocal_plate", "group": G_SPACE, "label": "Vocal Plate",
		"blurb": "The smooth bright plate used on singers and voiceover, with a little pre delay to keep words clear.",
		"params": [{"key": "mix", "label": "Mix", "default": 0.2, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [{"id": "plate", "p": {"decay_s": 1.6, "predelay_ms": 25.0, "mix": "mix"}}],
	},
	{
		"id": "concert_hall", "group": G_SPACE, "label": "Concert Hall",
		"blurb": "A large warm hall with a long tail.",
		"params": [{"key": "mix", "label": "Mix", "default": 0.25, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [{"id": "hall_reverb", "p": {"size": 0.8, "decay_s": 2.8, "predelay_ms": 25.0, "mix": "mix"}}],
	},
	{
		"id": "church", "group": G_SPACE, "label": "Church",
		"blurb": "A stone church with a long dark tail.",
		"params": [{"key": "mix", "label": "Mix", "default": 0.3, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [{"id": "cathedral", "p": {"decay_s": 4.5, "mix": "mix"}}],
	},
	{
		"id": "bathroom", "group": G_SPACE, "label": "Bathroom",
		"blurb": "Hard tiled walls close by.",
		"params": [{"key": "mix", "label": "Mix", "default": 0.35, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [{"id": "convolution_reverb", "p": {"space": 1.0, "mix": "mix"}}],
	},
	{
		"id": "inside_a_car", "group": G_SPACE, "label": "Inside a Car",
		"blurb": "The short boxy sound of a car cabin.",
		"params": [{"key": "mix", "label": "Mix", "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [{"id": "convolution_reverb", "p": {"space": 2.0, "mix": "mix"}}],
	},
	{
		"id": "stairwell", "group": G_SPACE, "label": "Stairwell",
		"blurb": "A concrete stairwell with a ringing echo.",
		"params": [{"key": "mix", "label": "Mix", "default": 0.35, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [{"id": "convolution_reverb", "p": {"space": 3.0, "mix": "mix"}}],
	},
	{
		"id": "warehouse", "group": G_SPACE, "label": "Warehouse",
		"blurb": "A big empty building with a long metallic tail.",
		"params": [{"key": "mix", "label": "Mix", "default": 0.3, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [{"id": "convolution_reverb", "p": {"space": 7.0, "mix": "mix"}}],
	},
	{
		"id": "tape_slap_echo", "group": G_SPACE, "label": "Tape Slap Echo",
		"blurb": "One quick warm repeat with tape colour, the classic rockabilly and radio voice echo.",
		"params": [
			{"key": "time_ms", "label": "Time", "default": 120.0, "min": 40.0, "max": 250.0, "step": 1.0, "unit": " ms"},
			{"key": "mix", "label": "Mix", "default": 0.3, "min": 0.0, "max": 1.0, "step": 0.01},
		],
		"chain": [
			{"id": "slapback", "p": {"time_ms": "time_ms", "mix": "mix", "tone_hz": 3500.0}},
			{"id": "tape_saturation", "p": {"drive_db": 4.0, "mix": 0.5}},
		],
	},
	{
		"id": "whisper_voice", "group": G_VOICE, "label": "Whisper Voice",
		"blurb": "Turns a spoken voice into a breathy whisper that follows the words.",
		"params": [{"key": "voice", "label": "Your voice under it", "default": 0.15, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [
			{"id": "ghost_voice", "p": {"whisper": 1.0, "your_voice": "voice", "float": 0.0, "echo": 0.1}},
			{"id": "highpass", "p": {"cutoff": 180.0, "q": 0.7071}},
		],
	},
	{
		"id": "cave_voice", "group": G_VOICE, "label": "Cave Voice",
		"blurb": "A voice deep in a rock cave, with a dark tail and a slow echo off the far wall.",
		"params": [{"key": "mix", "label": "Mix", "default": 0.45, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [
			{"id": "convolution_reverb", "p": {"space": 5.0, "mix": "mix"}},
			{"id": "delay", "p": {"delay_ms": 260.0, "feedback": 0.25, "wet": ["mix", 0.35, 0.0], "damp_hz": 2500.0}},
		],
	},
	{
		"id": "stadium_announcer", "group": G_VOICE, "label": "Stadium Announcer",
		"blurb": "A voice through a stadium PA, bouncing back off the far stands.",
		"params": [{"key": "room", "label": "Stadium", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [
			{"id": "pa_system", "p": {"room": 0.3}},
			{"id": "slapback", "p": {"time_ms": 230.0, "mix": ["room", 0.4, 0.0], "feedback": 0.3, "tone_hz": 3000.0}},
			{"id": "outdoors", "p": {"place": 7.0, "level": "room"}},
		],
	},
	{
		"id": "phone_speaker", "group": G_VOICE, "label": "Phone on Speaker",
		"blurb": "A phone call heard through the phone's loudspeaker in the room.",
		"params": [{"key": "room", "label": "Room", "default": 0.25, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [
			{"id": "telephone", "p": {"grit": 0.4}},
			{"id": "room", "p": {"size": 0.3, "decay_s": 0.5, "mix": "room"}},
		],
	},
	{
		"id": "drive_thru_speaker", "group": G_VOICE, "label": "Drive Through Speaker",
		"blurb": "A crackly order speaker: narrow, crunchy and a bit broken.",
		"params": [{"key": "crunch", "label": "Crunch", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [
			{"id": "telephone", "p": {"low_hz": 500.0, "high_hz": 3000.0, "grit": "crunch", "line_noise": 0.2}},
			{"id": "bitcrush", "p": {"bits": 10.0, "rate_hz": 16000.0, "wet": "crunch"}},
		],
	},
	{
		"id": "intercom", "group": G_VOICE, "label": "Intercom",
		"blurb": "A building intercom or door buzzer speaker.",
		"params": [{"key": "crush", "label": "Crush", "default": 0.2, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [
			{"id": "band_limit", "p": {"lowpass_hz": 3500.0, "highpass_hz": 400.0, "crush": "crush"}},
			{"id": "compressor", "p": {"threshold_db": -24.0, "ratio": 6.0, "attack_ms": 2.0, "release_ms": 80.0}},
		],
	},
	{
		"id": "old_radio_broadcast", "group": G_VOICE, "label": "Old Radio Broadcast",
		"blurb": "A 1940s wireless: narrow, warm, mono and crackling.",
		"params": [{"key": "crackle", "label": "Crackle", "default": 0.3, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [
			{"id": "radio", "p": {"low_hz": 250.0, "high_hz": 4000.0, "static": 0.1}},
			{"id": "vinyl", "p": {"crackle": "crackle", "pops": 0.1}},
			{"id": "mono", "p": {"source": 0.0}},
		],
	},
	{
		"id": "giant_voice", "group": G_VOICE, "label": "Giant Voice",
		"blurb": "A huge slow voice with weight in the chest and a big space around it.",
		"params": [{"key": "semitones", "label": "Lower by", "default": -7.0, "min": -12.0, "max": -1.0, "step": 0.1, "unit": " st"}],
		"chain": [
			{"id": "deep_voice", "p": {"semitones": "semitones", "size": 0.9, "weight_db": 6.0}},
			{"id": "hall_reverb", "p": {"size": 0.9, "decay_s": 2.5, "mix": 0.2}},
		],
	},
	{
		"id": "tiny_voice", "group": G_VOICE, "label": "Tiny Voice",
		"blurb": "A small high voice in a small space, for toys, mice and fairies.",
		"params": [{"key": "semitones", "label": "Raise by", "default": 9.0, "min": 1.0, "max": 12.0, "step": 0.1, "unit": " st"}],
		"chain": [
			{"id": "chipmunk", "p": {"semitones": "semitones", "brightness_db": 4.0, "thin_hz": 300.0}},
			{"id": "room", "p": {"size": 0.1, "decay_s": 0.3, "mix": 0.12}},
		],
	},
	{
		"id": "villain_voice", "group": G_VOICE, "label": "Villain Voice",
		"blurb": "Lower, rougher and darker, with a cold room behind it.",
		"params": [{"key": "semitones", "label": "Lower by", "default": -4.0, "min": -12.0, "max": -1.0, "step": 0.1, "unit": " st"}],
		"chain": [
			{"id": "deep_voice", "p": {"semitones": "semitones", "size": 0.7}},
			{"id": "distortion", "p": {"drive": 3.0, "mode": 0.0, "tone_hz": 5000.0, "wet": 0.3}},
			{"id": "room", "p": {"size": 0.5, "decay_s": 0.9, "mix": 0.15}},
		],
	},
	{
		"id": "metal_robot", "group": G_VOICE, "label": "Metal Robot Voice",
		"blurb": "A harsh buzzing machine voice from ring modulation and a crushed signal.",
		"params": [{"key": "freq_hz", "label": "Buzz", "default": 30.0, "min": 5.0, "max": 200.0, "step": 0.5, "unit": " Hz"}],
		"chain": [
			{"id": "ring_mod", "p": {"freq_hz": "freq_hz", "shape": 0.0, "mix": 1.0}},
			{"id": "bitcrush", "p": {"bits": 10.0, "rate_hz": 16000.0, "wet": 0.6}},
			{"id": "flanger", "p": {"rate_hz": 0.2, "depth_ms": 1.5, "feedback": 0.6, "wet": 0.4}},
		],
	},
	{
		"id": "cyborg_voice", "group": G_VOICE, "label": "Cyborg Voice",
		"blurb": "Half human, half machine: the voice is still there with a metallic double around it.",
		"params": [{"key": "amount", "label": "Machine", "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [
			{"id": "robot_voice", "p": {"amount": "amount", "metal": 0.5, "mix": 1.0}},
			{"id": "flanger", "p": {"rate_hz": 0.15, "depth_ms": 2.0, "feedback": 0.5, "wet": 0.35}},
			{"id": "chorus", "p": {"wet": 0.25}},
		],
	},
	{
		"id": "inner_thoughts", "group": G_VOICE, "label": "Inner Thoughts",
		"blurb": "The voice inside someone's head: softer top, wide and close, with a gentle plate around it.",
		"params": [{"key": "mix", "label": "Space", "default": 0.3, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [
			{"id": "lowpass", "p": {"cutoff": 7000.0, "q": 0.7071}},
			{"id": "chorus", "p": {"rate_hz": 0.3, "depth_ms": 1.5, "wet": 0.2, "stereo": 1.0}},
			{"id": "plate", "p": {"decay_s": 1.8, "predelay_ms": 30.0, "mix": "mix"}},
			{"id": "stereo_width", "p": {"width": 1.4}},
		],
	},
	{
		"id": "dream_flashback", "group": G_VOICE, "label": "Dream or Flashback",
		"blurb": "A hazy, floating sound for memories and dream scenes.",
		"params": [{"key": "mix", "label": "Haze", "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [
			{"id": "lowpass", "p": {"cutoff": 5000.0, "q": 0.7071}},
			{"id": "chorus", "p": {"rate_hz": 0.4, "depth_ms": 5.0, "wet": 0.4, "stereo": 1.0}},
			{"id": "hall_reverb", "p": {"size": 0.8, "decay_s": 3.5, "mix": "mix"}},
		],
	},
	{
		"id": "haunted_voice", "group": G_VOICE, "label": "Haunted Voice",
		"blurb": "A ghostly whispering double in a cold stone space.",
		"params": [{"key": "mix", "label": "Space", "default": 0.35, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [
			{"id": "ghost_voice", "p": {"whisper": 0.6, "your_voice": 0.6, "float": 0.5, "echo": 0.4}},
			{"id": "cathedral", "p": {"decay_s": 5.0, "mix": "mix"}},
		],
	},
	{
		"id": "megaphone_street", "group": G_VOICE, "label": "Megaphone in the Street",
		"blurb": "A loudhailer outdoors, echoing between buildings.",
		"params": [{"key": "street", "label": "Street", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [
			{"id": "megaphone", "p": {}},
			{"id": "outdoors", "p": {"place": 2.0, "level": "street"}},
		],
	},
	{
		"id": "mission_control_radio", "group": G_VOICE, "label": "Mission Control Radio",
		"blurb": "A space radio link with a squelch beep at each end and soft static.",
		"params": [{"key": "static", "label": "Static", "default": 0.2, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [
			{"id": "helmet_comms", "p": {"beeps": 0.6, "static": "static"}},
			{"id": "compressor", "p": {"threshold_db": -26.0, "ratio": 5.0, "attack_ms": 3.0, "release_ms": 90.0}},
		],
	},
	{
		"id": "monster_cave", "group": G_VOICE, "label": "Monster in a Cave",
		"blurb": "A growling beast voice echoing out of a cave.",
		"params": [{"key": "mix", "label": "Cave", "default": 0.35, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [
			{"id": "monster_voice", "p": {}},
			{"id": "convolution_reverb", "p": {"space": 5.0, "mix": "mix"}},
		],
	},
	{
		"id": "announcer_voice", "group": G_VOICE, "label": "Radio Announcer",
		"blurb": "The close, full, polished sound of a radio presenter: heavy compression, extra chest and presence, smooth s sounds.",
		"params": [{"key": "amount", "label": "Amount", "default": 0.7, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [
			{"id": "highpass", "p": {"cutoff": 70.0, "q": 0.7071}},
			{"id": "compressor", "p": {"threshold_db": -26.0, "ratio": ["amount", 4.0, 1.5], "attack_ms": 5.0, "release_ms": 120.0, "makeup_db": ["amount", 4.0, 0.0]}},
			{"id": "low_shelf", "p": {"freq": 120.0, "gain": ["amount", 4.0, 0.0]}},
			{"id": "eq3", "p": {"low_db": 0.0, "mid_hz": 3500.0, "mid_db": ["amount", 4.0, 0.0], "mid_q": 0.9, "high_db": 0.0}},
			{"id": "de_esser", "p": {"freq": 6500.0, "threshold_db": -30.0}},
		],
	},
	{
		"id": "lofi_hip_hop", "group": G_CHAR, "label": "Lofi Hip Hop",
		"blurb": "Dusty, warm and slightly wobbly, like a sample off an old tape with vinyl crackle on top.",
		"params": [{"key": "amount", "label": "Amount", "default": 0.7, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [
			{"id": "lofi", "p": {"rate_hz": 22050.0, "bits": 12.0, "mix": "amount"}},
			{"id": "cassette", "p": {"wow": 0.35, "flutter": 0.2, "hiss": 0.15}},
			{"id": "vinyl", "p": {"crackle": ["amount", 0.4, 0.0], "pops": 0.1}},
			{"id": "lowpass", "p": {"cutoff": 7000.0, "q": 0.7071}},
		],
	},
	{
		"id": "old_film_audio", "group": G_CHAR, "label": "Old Film",
		"blurb": "The thin mono soundtrack of an old film print, with crackle.",
		"params": [{"key": "crackle", "label": "Crackle", "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [
			{"id": "band_limit", "p": {"lowpass_hz": 5000.0, "highpass_hz": 250.0}},
			{"id": "vinyl", "p": {"crackle": "crackle", "pops": 0.25, "wear": 0.4}},
			{"id": "mono", "p": {"source": 0.0}},
		],
	},
	{
		"id": "gramophone", "group": G_CHAR, "label": "Gramophone",
		"blurb": "A wind up record player: very narrow, horn coloured and full of surface noise.",
		"params": [{"key": "crackle", "label": "Surface noise", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [
			{"id": "band_limit", "p": {"lowpass_hz": 3500.0, "highpass_hz": 400.0}},
			{"id": "eq3", "p": {"low_db": 0.0, "mid_hz": 1500.0, "mid_db": 5.0, "mid_q": 1.2, "high_db": 0.0}},
			{"id": "vinyl", "p": {"crackle": "crackle", "pops": 0.3, "wear": 0.6}},
			{"id": "distortion", "p": {"drive": 2.0, "mode": 0.0, "wet": 0.3}},
			{"id": "mono", "p": {"source": 0.0}},
		],
	},
	{
		"id": "podcast_voice", "group": G_PRESETS, "label": "Podcast Voice",
		"blurb": "Low cut, a soft gate, compression, a clarity EQ and a de-esser: a full podcast voice chain.",
		"params": [OUT],
		"chain": [
			{"id": "highpass", "p": {"cutoff": 80.0, "q": 0.7071}},
			{"id": "noise_gate", "p": {"threshold_db": -50.0, "floor_db": -18.0}},
			{"id": "compressor", "p": {"threshold_db": -22.0, "ratio": 3.0, "attack_ms": 8.0, "release_ms": 140.0, "makeup_db": 3.0}},
			{"id": "eq3", "p": {"low_hz": 220.0, "low_db": -2.0, "low_q": 1.0, "mid_hz": 3500.0, "mid_db": 2.5, "mid_q": 0.8, "high_hz": 10000.0, "high_db": 1.5, "high_q": 0.7}},
			{"id": "de_esser", "p": {"freq": 6500.0, "threshold_db": -28.0}},
			GAIN_OUT,
		],
	},
	{
		"id": "gaming_mic_cleanup", "group": G_PRESETS, "label": "Gaming Mic Clean Up",
		"blurb": "For a headset or desk microphone while playing: cuts fan noise and keyboard clatter, shuts off between lines and catches shouts.",
		"params": [OUT],
		"chain": [
			{"id": "highpass", "p": {"cutoff": 100.0, "q": 0.7071}},
			{"id": "noise_reduction", "p": {"reduction_db": 12.0}},
			{"id": "keyboard_softener", "p": {"reduction_db": 12.0}},
			{"id": "voice_gate", "p": {"floor_db": -30.0}},
			{"id": "compressor", "p": {"threshold_db": -20.0, "ratio": 4.0, "attack_ms": 3.0, "release_ms": 120.0, "makeup_db": 2.0}},
			GAIN_OUT,
		],
	},
	{
		"id": "voice_chat_fix", "group": G_PRESETS, "label": "Voice Chat Audio Fix",
		"blurb": "For voices recorded off a voice chat app or a stream: restores some of the lost top end, smooths the harsh compression and evens the level.",
		"params": [OUT],
		"chain": [
			{"id": "bandwidth_restore", "p": {"cutoff": 7000.0, "amount": 0.5}},
			{"id": "harshness_softener", "p": {"depth": 0.5}},
			{"id": "dropout_filler", "p": {}},
			{"id": "leveler", "p": {"target": -20.0, "speed": 3.0}},
			GAIN_OUT,
		],
	},
	{
		"id": "streaming_voice", "group": G_PRESETS, "label": "Streaming Voice",
		"blurb": "A bright, forward voice that sits over game audio and music on a live stream.",
		"params": [OUT],
		"chain": [
			{"id": "highpass", "p": {"cutoff": 90.0, "q": 0.7071}},
			{"id": "noise_gate", "p": {"threshold_db": -48.0, "floor_db": -24.0}},
			{"id": "compressor", "p": {"threshold_db": -20.0, "ratio": 4.0, "attack_ms": 5.0, "release_ms": 100.0, "makeup_db": 3.0}},
			{"id": "eq3", "p": {"low_hz": 250.0, "low_db": -2.0, "low_q": 1.0, "mid_hz": 4000.0, "mid_db": 3.0, "mid_q": 0.8, "high_hz": 11000.0, "high_db": 2.0, "high_q": 0.7}},
			{"id": "de_esser", "p": {"freq": 6500.0, "threshold_db": -28.0}},
			GAIN_OUT,
		],
	},
	{
		"id": "youtube_voiceover", "group": G_PRESETS, "label": "YouTube Voiceover",
		"blurb": "A clean, warm, even voiceover that sits on top of B-roll and music.",
		"params": [OUT],
		"chain": [
			{"id": "highpass", "p": {"cutoff": 80.0, "q": 0.7071}},
			{"id": "mouth_click_softener", "p": {}},
			{"id": "compressor", "p": {"threshold_db": -22.0, "ratio": 3.0, "attack_ms": 10.0, "release_ms": 150.0, "makeup_db": 3.0}},
			{"id": "eq3", "p": {"low_hz": 160.0, "low_db": 1.5, "low_q": 0.8, "mid_hz": 3500.0, "mid_db": 2.5, "mid_q": 0.8, "high_hz": 11000.0, "high_db": 1.5, "high_q": 0.7}},
			{"id": "de_esser", "p": {"freq": 6500.0, "threshold_db": -28.0}},
			{"id": "leveler", "p": {"target": -18.0, "max_boost": 6.0, "max_cut": 6.0, "speed": 2.0}},
			GAIN_OUT,
		],
	},
	{
		"id": "lav_mic_cleanup", "group": G_PRESETS, "label": "Lavalier Mic Clean Up",
		"blurb": "For a clip on microphone: cuts chest boom and clothing thumps and brings back the top a shirt muffles.",
		"params": [OUT],
		"chain": [
			{"id": "highpass", "p": {"cutoff": 100.0, "q": 0.7071}},
			{"id": "plosive_softener", "p": {}},
			{"id": "click_remover", "p": {"sensitivity": 0.5}},
			{"id": "eq3", "p": {"low_hz": 300.0, "low_db": -3.0, "low_q": 1.0, "mid_hz": 5000.0, "mid_db": 3.0, "mid_q": 0.8, "high_hz": 11000.0, "high_db": 2.0, "high_q": 0.7}},
			{"id": "compressor", "p": {"threshold_db": -22.0, "ratio": 2.5, "attack_ms": 10.0, "release_ms": 150.0, "makeup_db": 2.0}},
			GAIN_OUT,
		],
	},
	{
		"id": "phone_recording_fix", "group": G_PRESETS, "label": "Phone Recording Fix",
		"blurb": "For speech recorded on a phone: less boxiness, a little more top, steadier level and less background noise.",
		"params": [OUT],
		"chain": [
			{"id": "highpass", "p": {"cutoff": 120.0, "q": 0.7071}},
			{"id": "noise_reduction", "p": {"reduction_db": 10.0}},
			{"id": "bandwidth_restore", "p": {"cutoff": 8000.0, "amount": 0.4}},
			{"id": "eq3", "p": {"low_hz": 350.0, "low_db": -3.0, "low_q": 1.0, "mid_hz": 3000.0, "mid_db": 2.0, "mid_q": 0.8, "high_db": 0.0}},
			{"id": "leveler", "p": {"target": -20.0, "speed": 3.0}},
			GAIN_OUT,
		],
	},
	{
		"id": "asmr_soft", "group": G_PRESETS, "label": "ASMR Soft",
		"blurb": "Keeps every soft detail close and airy: gentle slow compression, extra air, less hiss, no harsh s sounds.",
		"params": [OUT],
		"chain": [
			{"id": "highpass", "p": {"cutoff": 40.0, "q": 0.7071}},
			{"id": "de_hiss", "p": {"reduction_db": 6.0}},
			{"id": "compressor", "p": {"threshold_db": -32.0, "ratio": 2.0, "attack_ms": 30.0, "release_ms": 300.0, "makeup_db": 4.0}},
			{"id": "eq3", "p": {"low_db": 0.0, "mid_db": 0.0, "high_hz": 12000.0, "high_db": 2.5, "high_q": 0.7}},
			{"id": "de_esser", "p": {"freq": 7000.0, "threshold_db": -34.0, "range_db": 6.0}},
			GAIN_OUT,
		],
	},
	{
		"id": "outdoor_vlog_fix", "group": G_PRESETS, "label": "Outdoor Vlog Fix",
		"blurb": "For walking and talking outside: wind and traffic rumble down, the voice brought forward and evened out.",
		"params": [OUT],
		"chain": [
			{"id": "wind_reducer", "p": {"amount": 0.7}},
			{"id": "highpass", "p": {"cutoff": 120.0, "q": 0.7071}},
			{"id": "noise_reduction", "p": {"reduction_db": 8.0}},
			{"id": "eq3", "p": {"low_db": 0.0, "mid_hz": 3500.0, "mid_db": 3.0, "mid_q": 0.8, "high_db": 0.0}},
			{"id": "leveler", "p": {"target": -18.0, "speed": 4.0}},
			GAIN_OUT,
		],
	},
	{
		"id": "noisy_room_cleanup", "group": G_PRESETS, "label": "Noisy Room Clean Up",
		"blurb": "For a voice over air conditioning, a fridge or a computer fan.",
		"params": [OUT],
		"chain": [
			{"id": "noise_reduction", "p": {"reduction_db": 15.0}},
			{"id": "voice_gate", "p": {"floor_db": -20.0}},
			{"id": "eq3", "p": {"low_db": 0.0, "mid_hz": 3500.0, "mid_db": 2.0, "mid_q": 0.8, "high_db": 0.0}},
			{"id": "compressor", "p": {"threshold_db": -22.0, "ratio": 2.5, "makeup_db": 2.0}},
			GAIN_OUT,
		],
	},
	{
		"id": "camera_mic_fix", "group": G_PRESETS, "label": "Camera Mic Fix",
		"blurb": "For the microphone on top of a camera: less room, less hiss, more voice.",
		"params": [OUT],
		"chain": [
			{"id": "highpass", "p": {"cutoff": 120.0, "q": 0.7071}},
			{"id": "noise_reduction", "p": {"reduction_db": 12.0}},
			{"id": "dereverb", "p": {"amount": 0.4}},
			{"id": "eq3", "p": {"low_hz": 300.0, "low_db": -2.0, "low_q": 1.0, "mid_hz": 3500.0, "mid_db": 3.0, "mid_q": 0.8, "high_db": 0.0}},
			{"id": "leveler", "p": {"target": -20.0, "speed": 3.0}},
			GAIN_OUT,
		],
	},
	{
		"id": "audiobook_voice", "group": G_PRESETS, "label": "Audiobook Narration",
		"blurb": "A natural, quiet, even narration voice with mouth noise and big breaths softened.",
		"params": [OUT],
		"chain": [
			{"id": "highpass", "p": {"cutoff": 70.0, "q": 0.7071}},
			{"id": "mouth_click_softener", "p": {}},
			{"id": "breath_reducer", "p": {"reduction_db": 6.0}},
			{"id": "compressor", "p": {"threshold_db": -24.0, "ratio": 2.0, "attack_ms": 15.0, "release_ms": 200.0, "makeup_db": 2.0}},
			{"id": "de_esser", "p": {"freq": 6500.0, "threshold_db": -30.0}},
			GAIN_OUT,
		],
	},
	{
		"id": "music_under_voice", "group": G_PRESETS, "label": "Music Bed Under Voice",
		"blurb": "Turns music down and scoops out the voice range so speech sits clearly on top of it.",
		"params": [{"key": "output_db", "label": "Music level", "default": -12.0, "min": -40.0, "max": 0.0, "step": 0.5, "unit": " dB"}],
		"chain": [
			{"id": "eq3", "p": {"low_db": 0.0, "mid_hz": 2500.0, "mid_db": -4.0, "mid_q": 0.7, "high_db": 0.0}},
			GAIN_OUT,
		],
	},
	{
		"id": "music_for_youtube", "group": G_PRESETS, "label": "Music Master for YouTube",
		"blurb": "A one step master to -14 LUFS with a balanced tone and safe peaks.",
		"params": [{"key": "intensity", "label": "Intensity", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01}],
		"chain": [{"id": "quick_master", "p": {"target": 1.0, "intensity": "intensity"}}],
	},
]
