extends RefCounted

const CURRENT_VERSION := 1


static func steps() -> Dictionary:
	return {
		0: _from_0_to_1,
	}


static func version_of(d: Dictionary) -> int:
	var v: Variant = d.get("format_version", 0)
	if v is int or v is float:
		return int(v)
	return 0


static func migrate(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var v: int = version_of(out)
	var table: Dictionary = steps()
	while v < CURRENT_VERSION:
		if not table.has(v):
			print("Migrations: no step from format version " + str(v) + ", the file is loaded as is")
			break
		var step: Callable = table[v]
		out = step.call(out)
		v += 1
		out["format_version"] = v
	if v > CURRENT_VERSION:
		print("Migrations: the file is format version " + str(v) + " and this build reads " + str(CURRENT_VERSION) + ", unknown fields are kept")
	out["format_version"] = v
	return out


static func _from_0_to_1(d: Dictionary) -> Dictionary:
	return d
