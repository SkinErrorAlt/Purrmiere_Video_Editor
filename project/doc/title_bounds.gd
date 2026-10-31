extends RefCounted

const TitleStyle := preload("res://doc/title_style.gd")


static func rect(props: Dictionary, size: Vector2) -> Rect2:
	var text: String = String(props.get("text", ""))
	if bool(props.get("uppercase", false)):
		text = text.to_upper()
	if text.strip_edges().is_empty() or size.x < 2.0 or size.y < 2.0:
		return Rect2()
	var scale_f: float = size.y / 1080.0
	var font: Font = TitleStyle.font_for(String(props.get("font", "")), bool(props.get("bold", false)), bool(props.get("italic", false)))
	font = TitleStyle.spaced(font, int(round(float(props.get("letter_spacing", 0.0)) * scale_f)))
	var fs: int = maxi(int(round(float(props.get("size", 72.0)) * scale_f)), 4)
	var width_frac: float = clampf(float(props.get("width", 0.9)), 0.05, 1.0)
	var pad: float = float(props.get("box_pad", 12.0)) * scale_f
	var para: TextParagraph = TextParagraph.new()
	para.width = size.x * width_frac - pad * 2.0
	var align: String = String(props.get("align", "center"))
	para.alignment = HORIZONTAL_ALIGNMENT_LEFT if align == "left" else (HORIZONTAL_ALIGNMENT_RIGHT if align == "right" else HORIZONTAL_ALIGNMENT_CENTER)
	para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
	para.add_string(text, font, fs)
	var extra_line: float = float(props.get("line_spacing", 0.0)) * scale_f
	var lines: int = maxi(para.get_line_count(), 1)
	var block_h: float = para.get_size().y + extra_line * float(lines - 1)
	var widest: float = 0.0
	for i: int in para.get_line_count():
		widest = maxf(widest, para.get_line_width(i))
	var x0: float = (size.x - para.width) * 0.5
	if align == "left":
		x0 = size.x * (1.0 - width_frac) * 0.5 + pad
	elif align == "right":
		x0 = size.x - size.x * (1.0 - width_frac) * 0.5 - pad - para.width
	var y0: float = (size.y - block_h) * 0.5
	var valign: String = String(props.get("valign", "center"))
	if valign == "top":
		y0 = size.y * 0.06
	elif valign == "bottom":
		y0 = size.y - block_h - size.y * 0.06
	var lx: float = x0 + (para.width - widest) * (0.0 if align == "left" else (1.0 if align == "right" else 0.5))
	return Rect2(lx - pad, y0 - pad, widest + pad * 2.0, block_h + pad * 2.0)
