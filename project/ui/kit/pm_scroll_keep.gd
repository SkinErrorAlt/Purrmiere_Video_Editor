extends ScrollContainer

var _want: int = 0
var _guard: bool = false
var _armed: bool = false


func _init() -> void:
	pad_content()


func pad_content() -> void:
	var pad: float = float(Tk.px(Tk.sz("pad")))
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	add_theme_stylebox_override("panel", sb)


func _ready() -> void:
	if not Tk.tokens_changed.is_connected(pad_content):
		Tk.tokens_changed.connect(pad_content)
	var bar: VScrollBar = get_v_scroll_bar()
	if bar != null and not bar.value_changed.is_connected(_on_value):
		bar.value_changed.connect(_on_value)
	if not sort_children.is_connected(_on_sorted):
		sort_children.connect(_on_sorted)
	_armed = true


func _on_value(v: float) -> void:
	if not _guard:
		_want = int(v)


func _on_sorted() -> void:
	if not _armed or _want <= 0:
		return
	_restore.call_deferred()


func _restore() -> void:
	var bar: VScrollBar = get_v_scroll_bar()
	if bar == null:
		return
	var top: int = int(maxf(bar.max_value - bar.page, 0.0))
	var target: int = clampi(_want, 0, top)
	if int(bar.value) == target:
		return
	_guard = true
	scroll_vertical = target
	_guard = false


func go_to_top() -> void:
	_want = 0
	_guard = true
	scroll_vertical = 0
	_guard = false
