extends Container

const PREF_META := "pm_pref_w"

var separation: float = 4.0:
	set(v):
		separation = v
		queue_sort()
		update_minimum_size()
var wrap_from: int = -1:
	set(v):
		wrap_from = v
		queue_sort()
		update_minimum_size()
var trail: int = 0:
	set(v):
		trail = maxi(v, 0)
		queue_sort()
		update_minimum_size()
var indent: float = 0.0:
	set(v):
		indent = maxf(v, 0.0)
		queue_sort()
var line_gap: float = 2.0
var wraps: bool = true:
	set(v):
		wraps = v
		queue_sort()
		update_minimum_size()
var wrapped: bool = false


static func make(sep: float = -1.0) -> Container:
	var script: GDScript = load("res://ui/kit/pm_wrap_row.gd")
	var row: Container = script.new()
	row.set("separation", sep if sep >= 0.0 else float(Tk.px(Tk.sz("gap"))))
	row.set("line_gap", float(Tk.px(2.0)))
	return row


static func prefer(c: Control, want: float, least: float = -1.0) -> Control:
	var floor_w: float = least if least >= 0.0 else minf(want, float(Tk.px(28.0)))
	c.custom_minimum_size.x = floor_w
	c.set_meta(PREF_META, maxf(want, floor_w))
	c.update_minimum_size()
	return c


static func min_w(c: Control) -> float:
	return c.get_combined_minimum_size().x


static func adopt(box: Container, wrap_from_: int = -1, trail_: int = 0) -> Container:
	var sep: float = float(box.get_theme_constant("separation")) if box is BoxContainer else float(Tk.px(Tk.sz("gap")))
	var row: Container = make(sep)
	for k: Node in box.get_children():
		box.remove_child(k)
		row.add_child(k)
	row.set("wrap_from", wrap_from_)
	row.set("trail", trail_)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(row)
	return row


static func pref_of(c: Control) -> float:
	var own: float = c.get_combined_minimum_size().x
	if c.has_meta(PREF_META):
		return maxf(own, float(c.get_meta(PREF_META)))
	if c.has_method("one_line_need"):
		return maxf(own, float(c.call("one_line_need")))
	if c is HBoxContainer or c is HFlowContainer:
		var total: float = 0.0
		var n: int = 0
		for ch: Node in c.get_children():
			if ch is Control and (ch as Control).visible and not (ch as Control).top_level:
				total += pref_of(ch)
				n += 1
		var sep: float = float(c.get_theme_constant("separation")) if c is HBoxContainer else float(c.get_theme_constant("h_separation"))
		total += sep * float(maxi(n - 1, 0))
		return maxf(own, total)
	if c is MarginContainer or c is PanelContainer:
		var inner: float = 0.0
		for ch: Node in c.get_children():
			if ch is Control and (ch as Control).visible and not (ch as Control).top_level:
				inner = maxf(inner, pref_of(ch))
		return maxf(own, own - _min_of_children(c) + inner)
	return own


static func _min_of_children(c: Control) -> float:
	var m: float = 0.0
	for ch: Node in c.get_children():
		if ch is Control and (ch as Control).visible and not (ch as Control).top_level:
			m = maxf(m, (ch as Control).get_combined_minimum_size().x)
	return m


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _all() -> Array[Control]:
	var out: Array[Control] = []
	for n: Node in get_children():
		if n is Control and not (n as Control).top_level:
			out.append(n)
	return out


func _parts() -> Array:
	var all: Array[Control] = _all()
	var first_tail: int = wrap_from if wrap_from >= 0 else all.size()
	var first_trail: int = maxi(all.size() - trail, first_tail)
	var lead: Array[Control] = []
	var tail: Array[Control] = []
	var back: Array[Control] = []
	for i: int in all.size():
		var c: Control = all[i]
		if not c.visible:
			continue
		if i < first_tail:
			lead.append(c)
		elif i < first_trail:
			tail.append(c)
		else:
			back.append(c)
	return [lead, tail, back]


func _sum(list: Array[Control], preferred: bool) -> float:
	var total: float = 0.0
	for c: Control in list:
		total += pref_of(c) if preferred else min_w(c)
	return total + separation * float(maxi(list.size() - 1, 0))


func _height(list: Array[Control]) -> float:
	var h: float = 0.0
	for c: Control in list:
		h = maxf(h, c.get_combined_minimum_size().y)
	return h


func _joined(a: Array[Control], b: Array[Control]) -> Array[Control]:
	var out: Array[Control] = []
	out.append_array(a)
	out.append_array(b)
	return out


func _in_order() -> Array[Control]:
	var out: Array[Control] = []
	for c: Control in _all():
		if c.visible:
			out.append(c)
	return out


func one_line_need() -> float:
	return _sum(_in_order(), true)


func _should_wrap(width: float) -> bool:
	var parts: Array = _parts()
	var tail: Array[Control] = parts[1]
	if not wraps or tail.is_empty():
		return false
	return one_line_need() > width + 0.5


func _get_minimum_size() -> Vector2:
	var parts: Array = _parts()
	var lead: Array[Control] = parts[0]
	var tail: Array[Control] = parts[1]
	var back: Array[Control] = parts[2]
	var everything: Array[Control] = _in_order()
	if not wraps or tail.is_empty():
		return Vector2(_sum(everything, false), _height(everything))
	var first: Array[Control] = _joined(lead, back)
	var w: float = maxf(_sum(first, false), _sum(tail, false))
	if not wrapped:
		return Vector2(w, _height(everything))
	return Vector2(w, _height(first) + line_gap + _height(tail))


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_sort()


func _sort() -> void:
	var parts: Array = _parts()
	var lead: Array[Control] = parts[0]
	var tail: Array[Control] = parts[1]
	var back: Array[Control] = parts[2]
	for c: Control in _all():
		if not c.visible:
			fit_child_in_rect(c, Rect2())
	var wrap: bool = _should_wrap(size.x)
	if not wrap:
		_lay_line(_in_order(), 0.0, size.x, 0.0, size.y)
	else:
		var first: Array[Control] = _joined(lead, back)
		var h1: float = _height(first)
		var h2: float = maxf(size.y - h1 - line_gap, _height(tail))
		_lay_line(first, 0.0, size.x, 0.0, h1)
		var x_in: float = clampf(indent, 0.0, maxf(size.x - _sum(tail, false), 0.0))
		_lay_line(tail, x_in, size.x - x_in, h1 + line_gap, h2)
	if wrap != wrapped:
		wrapped = wrap
		update_minimum_size()


func _lay_line(list: Array[Control], x0: float, width: float, y: float, h: float) -> void:
	if list.is_empty():
		return
	var widths: PackedFloat32Array = PackedFloat32Array()
	var mins: float = 0.0
	for c: Control in list:
		var m: float = min_w(c)
		widths.append(m)
		mins += m
	var extra: float = width - mins - separation * float(list.size() - 1)
	if extra > 0.0:
		var wants: float = 0.0
		for i: int in list.size():
			wants += maxf(pref_of(list[i]) - widths[i], 0.0)
		if wants > 0.0:
			var k: float = minf(extra / wants, 1.0)
			for i: int in list.size():
				widths[i] += maxf(pref_of(list[i]) - widths[i], 0.0) * k
			extra -= minf(extra, wants)
	if extra > 0.0:
		var ratio: float = 0.0
		for c: Control in list:
			if c.size_flags_horizontal & Control.SIZE_EXPAND:
				ratio += c.size_flags_stretch_ratio
		if ratio > 0.0:
			for i: int in list.size():
				if list[i].size_flags_horizontal & Control.SIZE_EXPAND:
					widths[i] += extra * list[i].size_flags_stretch_ratio / ratio
	var x: float = x0
	for i: int in list.size():
		var c: Control = list[i]
		var w: float = floor(widths[i])
		var ch: float = h
		var cy: float = y
		if not (c.size_flags_vertical & Control.SIZE_FILL):
			ch = minf(c.get_combined_minimum_size().y, h)
			cy = y + (h - ch) * 0.5
		fit_child_in_rect(c, Rect2(x, cy, w, ch))
		x += w + separation
