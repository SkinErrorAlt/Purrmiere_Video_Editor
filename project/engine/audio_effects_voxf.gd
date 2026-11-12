extends RefCounted

# Pass 56, voxF: sci-fi, tech and strange physics voices. Each one runs natively (purrcore
# dsp/pack_voxf.h) and only changes the voice itself: its pitch, throat, timing, spectrum or copies of
# it. Nothing is laid on top and nothing plays on its own in the pauses.

const GROUP := "Voice"

const DEFS: Array[Dictionary] = [
	{
		"id": "teleport_voice",
		"label": "Teleporter",
		"group": GROUP,
		"blurb": "The voice beams in and out like a teleporter. Before each phrase the words about to be spoken arrive first as a cloud of sparkling grains, high and scattered, falling in pitch and gathering to the middle until the voice appears. At the end of the phrase the last syllable comes apart into grains that rise and drift away. In between the voice is clear. The sound comes out 0.3 s late so it can hear each phrase coming: slide the clip 0.3 s earlier.",
		"params": [
			{"key": "particles", "label": "Particles", "default": 0.8, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "beam_ms", "label": "Beam in time", "default": 200.0, "min": 80.0, "max": 260.0, "step": 1.0, "unit": " ms"},
			{"key": "sparkle", "label": "Sparkle pitch", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "mix", "label": "Mix", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
	{
		"id": "hologram_voice",
		"label": "Hologram",
		"group": GROUP,
		"blurb": "A voice projected as a hologram. Two light beams make the image, drifting in and out of step, so interference sweeps through the voice; when the projection wavers the voice dims, thins and flickers with the projector's refresh; and now and then a dropped frame freezes a syllable into a stuck, buzzing loop or drops it to a coarse low resolution.",
		"params": [
			{"key": "flicker", "label": "Flicker", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "interference", "label": "Interference", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "glitches", "label": "Dropped frames", "default": 0.35, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "mix", "label": "Mix", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
	{
		"id": "deep_space_signal",
		"label": "Deep Space Signal",
		"group": GROUP,
		"blurb": "A voice transmitted from far across space. Interstellar gas holds the low frequencies back, so every sound arrives as a falling chirp; the signal twinkles as its paths shift, drifts in frequency and fades in and out, and relay stations further out send the same words again more than one and two seconds later.",
		"params": [
			{"key": "distance", "label": "Distance", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "dispersion", "label": "Chirp", "default": 0.55, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "relay", "label": "Relay echoes", "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "mix", "label": "Mix", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
	{
		"id": "parallel_selves",
		"label": "Parallel Selves",
		"group": GROUP,
		"blurb": "The speaker slips between parallel universes: each phrase, or each word, is spoken by a different version of them, higher or lower, with a bigger or smaller throat, breathier, brighter or darker, livelier or flatter, standing somewhere else. At each slip the self being left behind lingers for a moment, sliding out of tune as it goes. Which self speaks is fixed to the timeline. The sound comes out about 45 ms late.",
		"params": [
			{"key": "when", "label": "Slips at", "default": 0.0, "choices": ["Each phrase", "Each word", "Every few seconds"]},
			{"key": "differ", "label": "How different", "default": 0.7, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "overlap", "label": "Overlap at slips", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "mix", "label": "Mix", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
	{
		"id": "clone_army",
		"label": "Clone Army",
		"group": GROUP,
		"blurb": "The voice copied a dozen times or more, every copy speaking in lockstep, filling ranks from the front to the back and out to the sides. They are near perfect copies, each wrong in its own small way: one flat and monotone, one snapping to notes, one overacting, one rough, one whose throat keeps changing, one a beat late, one that stutters on the first sound. The sound comes out about 45 ms late.",
		"params": [
			{"key": "size", "label": "Clones", "default": 12.0, "min": 2.0, "max": 24.0, "step": 1.0},
			{"key": "wrong", "label": "Wrongness", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "spread", "label": "Spread", "default": 0.8, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "leader", "label": "Original voice", "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "mix", "label": "Mix", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
	{
		"id": "wormhole_voice",
		"label": "Wormhole",
		"group": GROUP,
		"blurb": "A voice coming through a wormhole. It arrives several times over by paths of different lengths around the throat, a swirling resonance sweeps through it, and now and then the wormhole pulls: the words are stretched by tidal forces and sink in pitch, then snap back while the stretched moment plays again backwards as time folds over. Where the pulls fall is fixed to the timeline.",
		"params": [
			{"key": "gravity", "label": "Pull strength", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "images", "label": "Arrives again", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "swirl", "label": "Swirl", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "pulls", "label": "Pulls how often", "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "mix", "label": "Mix", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
	{
		"id": "low_battery",
		"label": "Low Battery",
		"group": GROUP,
		"blurb": "A robot or AI running out of power. Every loud word drains the supply, so the voice sags lower and slower as it talks and recovers a little in the pauses; as the voltage falls its electronics starve, losing bits and sample rate, and the voice browns out for moments. Turn the battery down across a clip for a machine dying. The sound comes out about 45 ms late.",
		"params": [
			{"key": "battery", "label": "Battery", "default": 0.45, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "drain", "label": "Drain when talking", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "dropouts", "label": "Brown outs", "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "mix", "label": "Mix", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
	{
		"id": "quantum_voice",
		"label": "Quantum Voice",
		"group": GROUP,
		"blurb": "A voice in superposition: it speaks in two pitches at once, a higher and a lower self that waver and trade places around your head, until a stressed syllable observes it and it collapses into just one of them, steady and centred, before blurring back into both. Which one it falls into is fixed to the timeline. The sound comes out about 45 ms late.",
		"params": [
			{"key": "split_st", "label": "Distance between states", "default": 5.0, "min": 1.0, "max": 12.0, "step": 0.1, "unit": " semitones"},
			{"key": "observe", "label": "How easily it collapses", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "uncertainty", "label": "Uncertainty", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "mix", "label": "Mix", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
	{
		"id": "ancient_ship_computer",
		"label": "Ancient Ship Computer",
		"group": GROUP,
		"blurb": "The computer of a very old starship, speaking the way the first digital speech did: the voice taken down to 8 kHz in 22.5 ms frames, each frame kept only as ten numbers for the shape of the mouth, a loudness and a pitch, then spoken again from a buzzing pulse or a hiss. Buzzy, stepped and robotic but clear. Coarseness throws away more bits; intonation keeps or flattens the speaker's melody. The sound comes out about 80 ms late.",
		"params": [
			{"key": "coarse", "label": "Coarseness", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "intonation", "label": "Intonation", "default": 0.3, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "grit", "label": "Converter grit", "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "mix", "label": "Mix", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
	{
		"id": "cloaked_voice",
		"label": "Cloaked Voice",
		"group": GROUP,
		"blurb": "A speaker behind active camouflage. Whatever holds still in the voice is bent out of sight, so the steady middles of vowels melt into a glassy, rippling haze, while every change (the starts of words, consonants, glides) still shows, like an outline moving through the air. Now and then the cloak falters and the whole voice flickers through. The sound comes out about 43 ms late.",
		"params": [
			{"key": "cloak", "label": "Cloak", "default": 0.75, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "shimmer", "label": "Haze", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "flicker", "label": "Cloak failing", "default": 0.3, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "mix", "label": "Mix", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
	{
		"id": "time_dilation",
		"label": "Time Dilation",
		"group": GROUP,
		"blurb": "Waves of slowed time roll over the voice. Time thickens and the words drag, drawn out and red shifted lower, then time rushes to catch up and the words hurry, blue shifted higher, until it runs normally again. Red shift at 0 keeps the voice's own pitch through it all. The voice never falls more than about 0.4 s behind. The sound comes out about 45 ms late.",
		"params": [
			{"key": "slow_to", "label": "Time slows to", "default": 0.5, "min": 0.25, "max": 0.9, "step": 0.01, "unit": " x"},
			{"key": "every_s", "label": "A wave every", "default": 4.5, "min": 2.5, "max": 10.0, "step": 0.1, "unit": " s"},
			{"key": "redshift", "label": "Red shift", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "mix", "label": "Mix", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
	{
		"id": "force_field",
		"label": "Force Field",
		"group": GROUP,
		"blurb": "A voice heard through an energy barrier. The field vibrates at its own pitch and the voice rides on it, every harmonic grown a buzzing electric edge that widens where the voice hits the field hardest, and the hard sounds of the words (consonants and starts) arc as they cross it.",
		"params": [
			{"key": "strength", "label": "Field strength", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "flare", "label": "Flares when loud", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "arcing", "label": "Arcing", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "field_hz", "label": "Field pitch", "default": 90.0, "min": 40.0, "max": 200.0, "step": 1.0, "unit": " Hz"},
			{"key": "mix", "label": "Mix", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
	{
		"id": "alien_translator",
		"label": "Alien Translator",
		"group": GROUP,
		"blurb": "A translator machine putting an alien's words into our language, badly. The alien's own deeper voice comes first, and the machine speaks a moment behind it like an interpreter: every word on one stiff, flat note, the stress on the wrong words, now and then hanging on a sound while it thinks and then rushing to catch up. The sound comes out about 45 ms late.",
		"params": [
			{"key": "stiff", "label": "Stiffness", "default": 0.7, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "stalls", "label": "Hang ups", "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "original", "label": "Alien underneath", "default": 0.35, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "mix", "label": "Mix", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
	{
		"id": "event_horizon",
		"label": "Event Horizon",
		"group": GROUP,
		"blurb": "A voice falling into a black hole, where the end of every phrase never quite leaves: its last sound freezes at the horizon and hangs there, red shifting lower and lower and dimming as it slows, while the speaker carries on. The sound comes out about 0.2 s late so it can hear each phrase ending: slide the clip 0.2 s earlier.",
		"params": [
			{"key": "fall_s", "label": "Falls for", "default": 1.6, "min": 0.5, "max": 2.5, "step": 0.1, "unit": " s"},
			{"key": "redshift", "label": "Red shift", "default": 0.7, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "level", "label": "Frozen sound level", "default": 0.7, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "mix", "label": "Mix", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
]
