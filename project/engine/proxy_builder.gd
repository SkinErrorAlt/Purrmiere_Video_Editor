extends Node

signal segment_done(index: int, ok: bool, message: String)

const Proxies := preload("res://engine/proxies.gd")
const CHUNK := 8
const PUSH_TIMEOUT_MS := 30000
const DONE_TIMEOUT_MS := 120000
const PART := ".part"

var cancelled: bool = false
var built: int = 0
var failed: int = 0
var last_error: String = ""
var _done: Dictionary = {}
var _job_id: int = -1
var pause_check: Callable = Callable()
var use_native: bool = true
static var native_builds: int = 0


func _bridge() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("PurrBridge")
	return null


func cancel() -> void:
	cancelled = true


func _on_job_done(id: int, ok: bool, message: String) -> void:
	if id == _job_id:
		_done = {"ok": ok, "message": message}


func build_segment(handle: int, root: String, index: int, fps: float, duration: float, source_w: int, source_h: int, width: int, crf: int, codec: String) -> Dictionary:
	var out: Dictionary = {"ok": false, "frames": 0, "bytes": 0, "why": ""}
	var bridge: Node = _bridge()
	if bridge == null or not bool(bridge.get("available")):
		out["why"] = "the engine is not loaded"
		return out
	if handle < 0 or codec.is_empty():
		out["why"] = "no file or no codec to build with"
		return out
	var times: PackedFloat64Array = Proxies.times_for(index, fps, duration)
	if times.is_empty():
		out["why"] = "that segment is past the end of the file"
		return out
	if Proxies.have(root, index):
		out["ok"] = true
		out["why"] = "already built"
		return out
	DirAccess.make_dir_recursive_absolute(root)
	var size_v: Vector2i = Proxies.proxy_size(source_w, source_h, width)
	var final_path: String = Proxies.segment_path(root, index)
	var part_path: String = final_path + PART
	if FileAccess.file_exists(part_path):
		DirAccess.remove_absolute(part_path)
	var job: Dictionary = Proxies.job_for(part_path, size_v.x, size_v.y, fps, times.size(), crf, codec)
	_done = {}
	if not bridge.is_connected("job_done", _on_job_done):
		bridge.connect("job_done", _on_job_done)
	_job_id = int(bridge.call("export_begin", job))
	if _job_id < 0:
		out["why"] = "the engine refused to encode the proxy"
		return out
	var sent: int = 0
	var at: int = 0
	var shown_pts: PackedFloat64Array = PackedFloat64Array()
	var shown_starts: PackedFloat64Array = PackedFloat64Array()
	var all_listed: bool = true
	var native_id: int = -1
	if use_native and bridge.has_method("has_proxy_build") and bool(bridge.call("has_proxy_build")):
		native_id = int(bridge.call("proxy_build_begin", handle, _job_id, times, size_v.x, size_v.y))
	if native_id >= 0:
		native_builds += 1
		at = times.size()
		while true:
			var st: Dictionary = bridge.call("proxy_build_state", native_id)
			var state: String = String(st.get("state", "failed"))
			if cancelled or (_done.has("ok") and not bool(_done["ok"])):
				bridge.call("proxy_build_cancel", native_id)
			if state != "running":
				if state == "pushed":
					shown_pts = st.get("pts", PackedFloat64Array())
					shown_starts = st.get("starts", PackedFloat64Array())
					sent = shown_pts.size()
					for v: float in shown_pts:
						if v < 0.0:
							all_listed = false
				bridge.call("proxy_build_forget", native_id)
				if state != "pushed":
					bridge.call("export_abort", _job_id)
					out["why"] = "cancelled" if cancelled else (String(_done.get("message", "")) if _done.has("ok") and not String(_done.get("message", "")).is_empty() else String(st.get("why", "the engine could not build the proxy")))
					_forget(part_path)
					return out
				break
			await get_tree().process_frame
			while pause_check.is_valid() and bool(pause_check.call()) and not cancelled:
				await get_tree().create_timer(0.25).timeout
	while at < times.size():
		if cancelled:
			bridge.call("export_abort", _job_id)
			out["why"] = "cancelled"
			_forget(part_path)
			return out
		var slice_to: int = mini(at + CHUNK, times.size())
		var chunk: PackedFloat64Array = times.slice(at, slice_to)
		var images: Array = bridge.call("snapshot_run", handle, chunk, size_v.x)
		if images.size() != chunk.size():
			bridge.call("export_abort", _job_id)
			out["why"] = "the engine could not decode that part of the file"
			_forget(part_path)
			return out
		for raw: Variant in images:
			var img: Image = raw as Image
			if img == null:
				bridge.call("export_abort", _job_id)
				out["why"] = "a frame came back empty"
				_forget(part_path)
				return out
			if not img.has_meta("pts") or float(img.get_meta("pts", -1.0)) < 0.0:
				all_listed = false
			shown_pts.append(float(img.get_meta("pts", -1.0)))
			shown_starts.append(float(img.get_meta("start", -1.0)))
			if img.get_width() != size_v.x or img.get_height() != size_v.y:
				img.resize(size_v.x, size_v.y, Image.INTERPOLATE_BILINEAR)
			if img.get_format() != Image.FORMAT_RGBA8:
				img.convert(Image.FORMAT_RGBA8)
			var bytes: PackedByteArray = img.get_data()
			var t0: int = Time.get_ticks_msec()
			while not bool(bridge.call("export_push_frame", _job_id, bytes, size_v.x, size_v.y)):
				if cancelled or _done.has("ok") or Time.get_ticks_msec() - t0 > PUSH_TIMEOUT_MS:
					break
				await get_tree().process_frame
			sent += 1
		at = slice_to
		await get_tree().process_frame
		while pause_check.is_valid() and bool(pause_check.call()) and not cancelled:
			await get_tree().create_timer(0.25).timeout
	bridge.call("export_finish", _job_id)
	var t1: int = Time.get_ticks_msec()
	while not _done.has("ok"):
		if Time.get_ticks_msec() - t1 > DONE_TIMEOUT_MS:
			break
		await get_tree().process_frame
	var ok: bool = bool(_done.get("ok", false))
	if not ok:
		out["why"] = String(_done.get("message", "the encoder did not finish"))
		_forget(part_path)
		failed += 1
		last_error = String(out["why"])
		segment_done.emit(index, false, String(out["why"]))
		return out
	if not FileAccess.file_exists(part_path):
		out["why"] = "the encoder wrote nothing"
		failed += 1
		segment_done.emit(index, false, String(out["why"]))
		return out
	var listed: bool = all_listed and shown_pts.size() == sent and sent > 0
	if listed:
		listed = Proxies.write_frames(final_path, shown_pts, shown_starts)
	var moved: Error = DirAccess.rename_absolute(part_path, final_path)
	if moved != OK:
		if listed:
			DirAccess.remove_absolute(Proxies.frames_path(final_path))
		out["why"] = "the finished proxy could not be put in place"
		_forget(part_path)
		failed += 1
		segment_done.emit(index, false, String(out["why"]))
		return out
	Proxies.note_built(final_path)
	out["ok"] = true
	out["frames"] = sent
	out["bytes"] = Proxies.bytes_used(root, duration)
	built += 1
	segment_done.emit(index, true, "")
	return out


func _forget(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
