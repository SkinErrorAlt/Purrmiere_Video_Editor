extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const GroupTree := preload("res://doc/group_tree.gd")
const COMMANDS_PATH := "res://modules/core_panels/groups_commands.gd"


static func extend_tag_menu(s: Sequence, gid: String, items: Array) -> Array:
	var out: Array = items.duplicate()
	if GroupTree.is_slice(s, gid):
		out.insert(1, PmMenu.item("select_whole", "Select the whole group (" + GroupTree.title(s, GroupTree.root_of(s, gid)) + ")"))
	out.append(PmMenu.separator())
	out.append(PmMenu.item("panel", "Show in the Groups panel", Cmd.keys_text("group.panel")))
	return out


static func clip_items(s: Sequence, gid: String) -> Array:
	var out: Array = []
	if GroupTree.is_slice(s, gid):
		out.append(PmMenu.item("grp_select_whole", "Select the whole group (" + GroupTree.title(s, GroupTree.root_of(s, gid)) + ")"))
	out.append(PmMenu.item("grp_panel", "Show in the Groups panel", Cmd.keys_text("group.panel")))
	return out


static func apply(d: Project, s: Sequence, gid: String, id: String) -> int:
	if id == "select_whole":
		return 1 if GroupTree.select(d, s, GroupTree.root_of(s, gid)) else 0
	if id == "panel":
		var cmds: GDScript = load(COMMANDS_PATH)
		cmds.call("open_panel", gid)
		return 1
	return -1
