extends RefCounted

const ExportPresets := preload("res://modules/export/export_presets.gd")
const Sequence := preload("res://doc/sequence.gd")
const Project := preload("res://doc/project.gd")

const SHORT_PER_RUN := 6
const LONG_PER_RUN := 16
const RUNS := 3
const GOP_SECONDS := 2.0


static func run_starts(range_v: Vector2, fps: float, runs: int, per_run: int) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	if fps <= 0.0 or runs <= 0:
		return out
	var step: float = 1.0 / fps
	var span: float = maxf(range_v.y - range_v.x, 0.0)
	var room: float = maxf(span - float(per_run) * step, 0.0)
	for g: int in runs:
		var share: float = 0.0 if runs <= 1 else float(g) / float(runs)
		out.append(range_v.x + room * share)
	return out


static func times_for(starts: PackedFloat64Array, fps: float, per_run: int) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	if fps <= 0.0 or per_run <= 0:
		return out
	var step: float = 1.0 / fps
	for start: float in starts:
		for i: int in per_run:
			out.append(start + float(i) * step)
	return out


static func sample_times(range_v: Vector2, fps: float, frames: int, runs: int) -> PackedFloat64Array:
	var groups: int = maxi(mini(runs, frames), 1)
	var per: int = maxi(frames / groups, 1)
	var out: PackedFloat64Array = times_for(run_starts(range_v, fps, groups, per), fps, per)
	var step: float = 1.0 / maxf(fps, 0.001)
	while out.size() < frames and out.size() > 0:
		out.append(out[out.size() - 1] + step)
	return out.slice(0, frames) if out.size() > frames else out


static func frames_in(range_v: Vector2, fps: float) -> int:
	return int(round(maxf(range_v.y - range_v.x, 0.0) * fps))


static func from_two(short_frames: int, short_bytes: int, long_frames: int, long_bytes: int, total_frames: int, runs: int = 1, gop: int = 0) -> Dictionary:
	var out: Dictionary = {"ok": false, "bytes": 0, "per_frame": 0.0, "key_frame": 0.0, "fixed": 0.0, "keys": 0, "why": ""}
	if short_frames <= 0 or long_frames <= short_frames or short_bytes <= 0 or long_bytes <= 0:
		out["why"] = "the probe encodes did not produce two usable files"
		return out
	var per_frame: float = float(long_bytes - short_bytes) / float(long_frames - short_frames)
	if per_frame <= 0.0:
		per_frame = float(long_bytes) / float(long_frames)
	var jumps: int = maxi(mini(runs, short_frames), 1)
	var key_frame: float = (float(short_bytes) - per_frame * float(short_frames - jumps)) / float(jumps)
	if key_frame < per_frame:
		key_frame = per_frame
	var total: int = maxi(total_frames, 0)
	var keys: int = 1 if total > 0 else 0
	if gop > 0 and total > 0:
		keys = maxi(int(ceil(float(total) / float(gop))), 1)
	keys = mini(keys, total)
	out["ok"] = true
	out["per_frame"] = per_frame
	out["key_frame"] = key_frame
	out["fixed"] = 0.0
	out["keys"] = keys
	out["bytes"] = int(round(key_frame * float(keys) + per_frame * float(maxi(total - keys, 0))))
	return out


static func audio_bytes(settings: Dictionary, containers: Array[Dictionary], seconds: float) -> int:
	var container: Dictionary = ExportPresets.container_by_id(containers, String(settings.get("container", "mp4")))
	var audio: Dictionary = settings.get("audio", {})
	if not bool(audio.get("enabled", true)) or (container.get("audio_codecs", []) as Array).is_empty():
		return 0
	var kbps: int = ExportPresets.audio_kbps_of(String(audio.get("codec", "")), int(audio.get("bitrate_kbps", 0)), int(audio.get("sample_rate", 48000)), int(audio.get("channels", 2)))
	return int(round(float(kbps) * 1000.0 * maxf(seconds, 0.0) / 8.0))


static func text_for(bytes_v: int, measured: bool) -> String:
	var mb: float = float(bytes_v) / (1024.0 * 1024.0)
	var size_text: String = ExportPresets.fmt_mb(mb)
	if measured:
		return "Measured: about " + size_text + ", from a short test encode of the real footage"
	return "About " + size_text


static func _encode(parent: Node, settings: Dictionary, seq: Sequence, doc: Project, compositor: Node, handles: Dictionary, times: PackedFloat64Array) -> Dictionary:
	var ExportJob: GDScript = load("res://modules/export/export_job.gd")
	var job: Node = ExportJob.new()
	job.name = "SizeProbe"
	parent.add_child(job)
	job.call("setup", settings, seq, doc, compositor, handles)
	job.set("probe_times", times)
	job.call("start")
	var result: Array = await job.get("finished")
	var path: String = String(job.get("output_path"))
	var ok: bool = bool(result[0]) if result.size() > 0 else false
	var why: String = String(result[1]) if result.size() > 1 else ""
	var size_v: int = 0
	if ok and FileAccess.file_exists(path):
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if f != null:
			size_v = int(f.get_length())
			f.close()
	job.queue_free()
	return {"ok": ok and size_v > 0, "bytes": size_v, "path": path, "why": why}


static func _forget(path: String) -> void:
	if not path.is_empty() and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func run(parent: Node, settings: Dictionary, seq: Sequence, doc: Project, compositor: Node, handles: Dictionary, containers: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {"ok": false, "bytes": 0, "text": "", "why": "", "per_frame": 0.0}
	if parent == null or seq == null or doc == null or compositor == null:
		out["why"] = "there is nothing open to measure"
		return out
	var eff: Dictionary = ExportPresets.effective(ExportPresets.normalise(settings), containers)
	var container: Dictionary = ExportPresets.container_by_id(containers, String(eff.get("container", "mp4")))
	if ExportPresets.is_audio_only(container):
		var secs: float = maxf(ExportPresets.resolve_range(eff, seq).y - ExportPresets.resolve_range(eff, seq).x, 0.0)
		out["ok"] = true
		out["bytes"] = audio_bytes(eff, containers, secs)
		out["text"] = text_for(int(out["bytes"]), false)
		return out
	var range_v: Vector2 = ExportPresets.resolve_range(eff, seq)
	var fps: float = ExportPresets.resolve_fps(eff, seq.fps)
	var total: int = frames_in(range_v, fps)
	if total <= 0 or fps <= 0.0:
		out["why"] = "the range is empty"
		return out
	var runs: int = RUNS
	var long_per: int = LONG_PER_RUN
	var short_per: int = SHORT_PER_RUN
	while runs > 1 and runs * long_per > total:
		runs -= 1
	if runs * long_per > total:
		long_per = maxi(total, 2)
		short_per = maxi(long_per / 3, 1)
		runs = 1
	if short_per >= long_per:
		short_per = maxi(long_per - 1, 1)
	var starts: PackedFloat64Array = run_starts(range_v, fps, runs, long_per)
	var long_times: PackedFloat64Array = times_for(starts, fps, long_per)
	var short_times: PackedFloat64Array = times_for(starts, fps, short_per)
	if long_times.size() <= short_times.size() or short_times.is_empty():
		out["why"] = "the range is too short to measure"
		return out
	var a: Dictionary = await _encode(parent, eff, seq, doc, compositor, handles, short_times)
	if not bool(a["ok"]):
		_forget(String(a["path"]))
		out["why"] = String(a["why"]) if not String(a["why"]).is_empty() else "the first test encode did not finish"
		return out
	var b: Dictionary = await _encode(parent, eff, seq, doc, compositor, handles, long_times)
	_forget(String(a["path"]))
	if not bool(b["ok"]):
		_forget(String(b["path"]))
		out["why"] = String(b["why"]) if not String(b["why"]).is_empty() else "the second test encode did not finish"
		return out
	_forget(String(b["path"]))
	var gop: int = maxi(int(round(fps * GOP_SECONDS)), 1)
	var est: Dictionary = from_two(short_times.size(), int(a["bytes"]), long_times.size(), int(b["bytes"]), total, runs, gop)
	if not bool(est["ok"]):
		out["why"] = String(est["why"])
		return out
	var seconds: float = float(total) / fps
	var total_bytes: int = int(est["bytes"]) + audio_bytes(eff, containers, seconds)
	out["ok"] = true
	out["bytes"] = total_bytes
	out["per_frame"] = float(est["per_frame"])
	out["key_frame"] = float(est["key_frame"])
	out["keys"] = int(est["keys"])
	out["short_bytes"] = int(a["bytes"])
	out["long_bytes"] = int(b["bytes"])
	out["short_frames"] = short_times.size()
	out["long_frames"] = long_times.size()
	out["text"] = text_for(total_bytes, true)
	return out
