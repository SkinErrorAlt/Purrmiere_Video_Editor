extends RefCounted

# Horror and supernatural voices (vox D). All of them run natively (purrcore/src/dsp/voxd_*.h), keep
# time on the absolute clock and so sound the same from any start point. Each one only changes the
# voice itself: nothing is added on top and nothing plays on its own in the pauses.

const G_VOICE := "Voice"
const MIX := {"key": "mix", "label": "Mix", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01}

const DEFS: Array[Dictionary] = [
	{
		"id": "banshee_wail", "group": G_VOICE, "label": "Banshee",
		"blurb": "A banshee's voice: each phrase climbs higher and thinner the longer it goes on, and when it ends its own last vowel is held and keened on as a wail that rises, wavers and dies away across a cold moor. The sound comes out about 0.2 s late, and the wail runs up to 2 s past the last word.",
		"params": [
			{"key": "rise_st", "label": "Climb over a phrase", "default": 12.0, "min": 0.0, "max": 19.0, "step": 0.5, "unit": " semitones"},
			{"key": "wail", "label": "Wail", "default": 0.7, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "shriek", "label": "Shriek", "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "moor", "label": "Cold moor", "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "mirror_voice", "group": G_VOICE, "label": "Behind the Mirror",
		"blurb": "Your reflection answers: it says the same words a moment after you, from behind silvered glass, but its melody is turned upside down (where you rise it falls) and its throat is a hair different, so it is you and not you. Halfway on Mirrored melody it speaks on one note. Your own voice comes out about 45 ms late.",
		"params": [
			{"key": "late_ms", "label": "How late", "default": 160.0, "min": 60.0, "max": 400.0, "step": 5.0, "unit": " ms"},
			{"key": "wrong", "label": "Mirrored melody", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "glass", "label": "Glass", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "voice", "label": "Your voice", "default": 0.75, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "cursed_tape", "group": G_VOICE, "label": "Cursed Tape",
		"blurb": "The voice on a cursed cassette that gets worse as it plays: every phrase is a little more worn than the one before, with more wow and flutter, dropouts in the words, a duller, more saturated and phasey sound, and late on the tape snags and drags the voice down and back up. Ruined over sets how long it takes to fall apart, counted from the start of the clip. The sound comes out about 25 ms late.",
		"params": [
			{"key": "ruin_s", "label": "Ruined over", "default": 10.0, "min": 3.0, "max": 120.0, "step": 0.5, "unit": " s"},
			{"key": "worst", "label": "How bad it gets", "default": 0.8, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "wow", "label": "Wow and flutter", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "sleep_paralysis", "group": G_VOICE, "label": "Sleep Paralysis",
		"blurb": "You cannot move and something is whispering your words as it circles the bed: the voice becomes a whisper that goes round your head and creeps closer as the clip goes on, and a second whisper says the words again a moment later, circling the other way. Best on headphones. The sound comes out about 21 ms late.",
		"params": [
			{"key": "circle", "label": "Circling speed", "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "closer", "label": "Creeps closer", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "second", "label": "Second whisper", "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "ghost_child_song", "group": G_VOICE, "label": "Ghost Child's Song",
		"blurb": "The words are sung by a small ghost child to a slow nursery tune in a minor key, one note to each syllable, gliding into each note with a little vibrato, in an empty room. Turned wrong drags the tune, sours the notes and slips in wrong ones. The tune keeps time from the start of the clip. The sound comes out about 45 ms late.",
		"params": [
			{"key": "key", "label": "Song key", "default": 2.0, "choices": ["C", "C sharp", "D", "E flat", "E", "F", "F sharp", "G", "A flat", "A", "B flat", "B"]},
			{"key": "pace", "label": "Note length", "default": 0.42, "min": 0.2, "max": 0.9, "step": 0.01, "unit": " s"},
			{"key": "wrong", "label": "Turned wrong", "default": 0.3, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "room", "label": "Empty room", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "poltergeist", "group": G_VOICE, "label": "Poltergeist",
		"blurb": "Something unseen is throwing the voice around the room: on syllables it is snatched to a new place, left, right, near, far or behind you, heard from there with the room around it, and it drifts back to the middle when the speaking stops. Best on headphones.",
		"params": [
			{"key": "thrown", "label": "How often", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "spread", "label": "How far", "default": 0.8, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "room", "label": "Room", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "vampire_voice", "group": G_VOICE, "label": "Vampire",
		"blurb": "A vampire speaking cold and close at your neck: the voice is lower and darker and sits right by one ear, and every s and sh is leant on and drawn out, the hiss of the word itself held on and fading, so \"yesss\" trails off into a long cold hiss. The sound comes out about 45 ms late.",
		"params": [
			{"key": "hiss", "label": "Drawn out s", "default": 0.65, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "close", "label": "At your neck", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "cold", "label": "Cold", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "evil_clown", "group": G_VOICE, "label": "Evil Clown",
		"blurb": "A sinister clown: the melody of the voice is blown up into a mocking, exaggerated sing-song, some stressed syllables swoop up into a squeal, and the throat is small and honks through the nose. The sound comes out about 45 ms late.",
		"params": [
			{"key": "singsong", "label": "Sing-song", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "squeal", "label": "Squeals", "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "honk", "label": "Honk", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "pitch_st", "label": "Voice up", "default": 2.0, "min": -3.0, "max": 7.0, "step": 0.1, "unit": " semitones"},
			MIX,
		],
	},
	{
		"id": "dust_voice", "group": G_VOICE, "label": "Crumbling to Dust",
		"blurb": "The words fall apart as they die away: the fading end of every word is eaten and turned into a cloud of tiny pieces of what was just said, each a little lower, scattered left and right and sinking away like dust for about half a second.",
		"params": [
			{"key": "crumble", "label": "Crumble", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "grain", "label": "Grain size", "default": 0.35, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "scatter", "label": "Blow away", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "weeping_woman", "group": G_VOICE, "label": "Weeping Woman",
		"blurb": "A woman crying as she speaks: the voice rises and quivers in pitch and loudness, and now and then a word catches in a sob, stopping dead for a moment and coming back broken upward. Far away puts her somewhere off in an empty house. The sound comes out about 45 ms late.",
		"params": [
			{"key": "sobs", "label": "Sobs", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "quiver", "label": "Quiver", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "pitch_st", "label": "Voice up", "default": 2.5, "min": 0.0, "max": 6.0, "step": 0.1, "unit": " semitones"},
			{"key": "far", "label": "Far away", "default": 0.35, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "abyss_voice", "group": G_VOICE, "label": "Into the Abyss",
		"blurb": "Every phrase falls away from you down a bottomless pit: from its first word the speaker drops, getting further away, the pitch sinking as they pull away (a real Doppler drop), the air taking the top off and the pit echoing more the deeper they go. In a long enough pause they are back at the top. Late in a long phrase the words arrive up to 1.5 s late, as falling sound would.",
		"params": [
			{"key": "fall", "label": "Falling speed", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "echo", "label": "Echo of the pit", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "dark", "label": "Darkness", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "skeleton_voice", "group": G_VOICE, "label": "Skeleton",
		"blurb": "A voice with no flesh left, speaking out of an empty skull: the shape of the mouth is kept but every resonance is sharpened and the dips between them hollowed out, so the words ring and whistle like air blown through bone. Skull size moves those resonances down or up. The sound comes out about 21 ms late.",
		"params": [
			{"key": "hollow", "label": "Hollow", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "skull", "label": "Skull size", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "melting_voice", "group": G_VOICE, "label": "Melting",
		"blurb": "The speaker is melting as they talk: every word sags as it goes on, its pitch sliding down and the mouth and throat drooping with it, the sag building through each phrase, and the voice wobbles more the further it has slumped. The sound comes out about 45 ms late.",
		"params": [
			{"key": "melt", "label": "Sag", "default": 6.0, "min": 0.0, "max": 12.0, "step": 0.1, "unit": " semitones"},
			{"key": "face", "label": "Face droops", "default": 0.7, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "wobble", "label": "Wobble", "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.01},
			MIX,
		],
	},
	{
		"id": "emotionless_voice", "group": G_VOICE, "label": "Emotionless",
		"blurb": "Something wearing a person's voice: every rise and fall of the melody is pressed flat, each syllable is evened out to the same loudness, and what is left is too steady and very slightly not the right throat. The sound comes out about 45 ms late.",
		"params": [
			{"key": "flatten", "label": "Flatten", "default": 0.9, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "even", "label": "Even loudness", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "pitch_st", "label": "Pitch", "default": 0.0, "min": -4.0, "max": 4.0, "step": 0.1, "unit": " semitones"},
			MIX,
		],
	},
]
