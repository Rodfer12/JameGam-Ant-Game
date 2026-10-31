class_name SpriteSheetUtil
extends RefCounted

## Downsamples a grid-based sprite sheet once, with proper filtering.
## Drawing 90x96 frames at ~0.25 scale with nearest filtering is what made the
## ants and bugs look noisy and shimmer while moving.
## Returns {"texture", "columns", "rows", "cell"}.

@warning_ignore("integer_division")
static func smooth_sheet(source: Texture2D, source_cell: Vector2i, target_cell: Vector2i) -> Dictionary:
	var result := {"texture": source, "columns": 1, "rows": 1, "cell": source_cell}
	if source == null:
		return result
	var columns: int = maxi(1, int(source.get_width() / source_cell.x))
	var rows: int = maxi(1, int(source.get_height() / source_cell.y))
	result["columns"] = columns
	result["rows"] = rows
	var image := source.get_image()
	if image == null or image.is_empty():
		return result
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	image.fix_alpha_edges()
	var sheet := Image.create_empty(columns * target_cell.x, rows * target_cell.y, false, Image.FORMAT_RGBA8)
	for row in rows:
		for column in columns:
			var cell_image := image.get_region(Rect2i(column * source_cell.x, row * source_cell.y, source_cell.x, source_cell.y))
			cell_image.resize(target_cell.x, target_cell.y, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(cell_image, Rect2i(Vector2i.ZERO, target_cell), Vector2i(column * target_cell.x, row * target_cell.y))
	result["texture"] = ImageTexture.create_from_image(sheet)
	result["cell"] = target_cell
	return result
