extends VBoxContainer

const EditClock := preload("res://host/edit_clock.gd")
const DataText := preload("res://doc/data_text.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmWindow := preload("res://ui/kit/pm_window.gd")
const SELF_PATH := "res://ui/editor/stats_window.gd"
const WINDOW_KEY := "help.stats"

var rows: Dictionary = {}


static func open(host: Node) -> Control:
	var body: Control = (load(SELF_PATH) as GDScript).new()
	var root: Node = host if host != null and host.is_inside_tree() else (Engine.get_main_loop() as SceneTree).root
	return PmWindow.open(root, "Statistics", body, Vector2(float(Tk.px(420.0)), float(Tk.px(420.0))), WINDOW_KEY)


static func lines(sum: Dictionary, current: Object) -> Array[Array]:
	var out: Array[Array] = []
	out.append(["Editing today", DataText.duration_text(float(sum["today"]), "words")])
	out.append(["This week", DataText.duration_text(float(sum["week"]), "words")])
	out.append(["This month", DataText.duration_text(float(sum["month"]), "words")])
	out.append(["This year", DataText.duration_text(float(sum["year"]), "words")])
	out.append(["All time", DataText.duration_text(float(sum["all"]), "words")])
	out.append(["A normal editing day", DataText.duration_text(float(sum["per_day"]), "words") + " (" + str(int(sum["days"])) + " days)"])
	out.append(["Projects finished (exported)", str(int(sum["finished"]))])
	out.append(["Projects not finished yet", str(int(sum["unfinished"]))])
	if int(sum["finished"]) > 0:
		out.append(["Likely time to finish a project", DataText.duration_text(float(sum["to_finish"]), "words")])
	if not String(sum["most"]).is_empty():
		out.append(["Most worked on", String(sum["most"]) + ", " + DataText.duration_text(float(sum["most_seconds"]), "words")])
	if current != null:
		out.append(["This project so far", DataText.duration_text(float(current.call("edit_seconds")), "words")])
		out.append(["This project's exports", str(int(EditClock.project_record(current).get("exports", 0)))])
	return out


func _ready() -> void:
	name = "Statistics"
	add_theme_constant_override("separation", Tk.px(4.0))
	var session: Node = get_node_or_null("/root/Session")
	var current: Object = session.get("doc") if session != null else null
	var head: Label = PmLabel.dim("Counted only while you work in Purrmiere (any input in the last minute, or playing). Nothing leaves this computer.")
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(head)
	for pair: Array in lines(EditClock.summary(), current):
		var row: HBoxContainer = PmUI.hbox(Tk.px(8.0))
		var l: Label = PmLabel.body(String(pair[0]))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var v: Label = PmLabel.mono(String(pair[1]), "text")
		row.add_child(v)
		rows[String(pair[0])] = v
		add_child(row)
	var tip: Label = PmLabel.dim("Put these in a video with a text: {edit_time}, {clips}, {cuts}, {project}. The Data button under a title's text lists them.")
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(tip)
