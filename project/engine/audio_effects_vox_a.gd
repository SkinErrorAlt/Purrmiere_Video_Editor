extends RefCounted

# Voice characters: a voice turned into a believable someone or something else.
# All of them run natively (purrcore/src/dsp/vox_a_*.h), keep time on the absolute clock and so sound
# the same from any start point. Each one is only the voice transformed: nothing is laid on top of
# the words or plays in the pauses on its own. Controls removed for that reason (jaw clacks,
# clockwork, bellows, record noise, breathing, the backwards whisper, gurgle bubbles, chattering
# teeth, gasps, the air hose, bubbles, strain) are ignored when an old project still carries them.

const G_VOICE := "Voice"
const MIX := {"key": "mix", "label": "Mix", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01}

const DEFS: Array[Dictionary] = [
	{
		"id": "dummy_voice", "group": G_VOICE, "label": "Ventriloquist Dummy",
		"blurb": "The voice of a wooden dummy on a ventriloquist's knee: higher and smaller, squeezed through still lips and the nose, and ringing in a hollow wooden head. The sound comes out about 40 ms late.",
		"params": [
			{"key": "pitch_st", "label": "Voice up", "default": 3.0, "min": 0.0, "max": 7.0, "step": 0.1, "unit": " semitones"},
			{"key": "teeth", "label": "Still lips", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "wood", "label": "Wooden head", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "swarm_voice", "group": G_VOICE, "label": "Voice of Flies",
		"blurb": "The words are spoken by a swarm of buzzing flies: dozens of wings take on the shape of the voice, each drifting in pitch and swelling as it passes, all wandering around the listener. For plague bringers, haunted houses and hive minds.",
		"params": [
			{"key": "flies", "label": "Swarm", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "buzz_hz", "label": "Wing pitch", "default": 190.0, "min": 120.0, "max": 320.0, "step": 1.0, "unit": " Hz"},
			{"key": "swirl", "label": "Swirl", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "voice", "label": "Your voice", "default": 0.12, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "automaton_voice", "group": G_VOICE, "label": "Clockwork Automaton",
		"blurb": "A brass talking machine from a Victorian fairground: a pair of beating reeds follow your pitch in clockwork steps and are shaped into your words.",
		"params": [
			{"key": "steps", "label": "Reed notes", "default": 0.0, "choices": ["Semitones", "Whole tones", "One note"]},
			{"key": "voice", "label": "Your voice", "default": 0.1, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "talking_doll", "group": G_VOICE, "label": "Pull String Doll",
		"blurb": "A talking doll from the toy box: the words play off a tiny record through a palm sized plastic speaker. Each phrase starts a touch fast as the string snaps back and sags as the spring runs down, and the little disc wobbles. The sound comes out about 17 ms late.",
		"params": [
			{"key": "run_down", "label": "Running down", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "wobble", "label": "Wobble", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "speaker", "label": "Tiny speaker", "default": 0.8, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "gas_mask", "group": G_VOICE, "label": "Gas Mask",
		"blurb": "A voice inside a rubber gas mask: boxed in by the rubber, muffled at the top and honking through the metal speaking disc.",
		"params": [
			{"key": "mask", "label": "Mask", "default": 0.7, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "vent_voice", "group": G_VOICE, "label": "Through the Vents",
		"blurb": "A voice travelling through metal air ducts: hollow and tinny, fluttering down the length of the shaft with a springy metal shimmer and ringing in the sheet metal, as if someone is crawling in the vents.",
		"params": [
			{"key": "distance", "label": "How far in", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "metal", "label": "Metal ring", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "size", "label": "Duct size", "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "mimic_voice", "group": G_VOICE, "label": "The Mimic",
		"blurb": "Something copying a human voice and not quite getting it right: each syllable lands on a slightly wrong note, the throat slides about under the words, a second throat hums along an octave down, and now and then a syllable catches and is said again over the next one. The sound comes out about 40 ms late.",
		"params": [
			{"key": "wrong", "label": "Wrongness", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "undertone", "label": "Second throat", "default": 0.35, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "repeats", "label": "Repeats", "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "possessed_voice", "group": G_VOICE, "label": "Possessed",
		"blurb": "Someone fighting for control of their own voice: whole syllables are taken over by something deep and rasping, then snap back to the person. The sound comes out about 40 ms late.",
		"params": [
			{"key": "takeover", "label": "Takeover", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "depth_st", "label": "Depth", "default": -9.0, "min": -14.0, "max": -4.0, "step": 0.1, "unit": " semitones"},
			MIX,
		],
	},
	{
		"id": "spirit_box", "group": G_VOICE, "label": "Spirit Box",
		"blurb": "A ghost hunter's spirit box sweeping the radio dial: the voice breaks through in short, slightly off tune fragments, and between them the words are lost in static, as if answering from the other side.",
		"params": [
			{"key": "speed", "label": "Sweep speed", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "through", "label": "Voice breaks through", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "static", "label": "Static", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "zombie_voice", "group": G_VOICE, "label": "Zombie",
		"blurb": "A rotting undead throat: the voice sits in a slack, swollen throat and slurs, breaks into a broken fry and rasps, and wavers wetly through what is left of the windpipe. The sound comes out about 23 ms late.",
		"params": [
			{"key": "rasp", "label": "Rasp", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "gurgle", "label": "Wet throat", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "slack", "label": "Slack jaw", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "golem_voice", "group": G_VOICE, "label": "Stone Golem",
		"blurb": "A creature of living rock: the words are ground out of tumbling stone and gravel, with a huge throat and a deep rumble an octave below your voice.",
		"params": [
			{"key": "grind", "label": "Gravel", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "rumble", "label": "Rumble", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "size", "label": "Size", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "voice", "label": "Your voice", "default": 0.15, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "freezing_voice", "group": G_VOICE, "label": "Freezing Cold",
		"blurb": "Someone freezing half to death: the voice shivers unevenly in pitch and loudness as they try to get the words out. For snowbound horror and survival games.",
		"params": [
			{"key": "shiver", "label": "Shivering", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "tin_can_phone", "group": G_VOICE, "label": "Tin Can Telephone",
		"blurb": "Two tin cans and a taut string: the voice comes down the string thin and twangy, each echo along it coming back as a springy chirp, and rings in the tin can at the ear.",
		"params": [
			{"key": "length", "label": "String length", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "twang", "label": "Twang", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "can", "label": "Tin ring", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "diving_helmet", "group": G_VOICE, "label": "Diving Helmet",
		"blurb": "A deep sea diver in a heavy brass helmet: the voice booms and rings inside the copper dome behind the little glass port.",
		"params": [
			{"key": "ring", "label": "Brass ring", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "sewn_mouth", "group": G_VOICE, "label": "Mouth Sewn Shut",
		"blurb": "Someone trying to speak with their lips sewn or taped shut: every word is forced out through the nose as a muffled, desperate hum, the rhythm and the rise and fall still there but the mouth gone.",
		"params": [
			{"key": "seal", "label": "How shut", "default": 0.8, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
]
