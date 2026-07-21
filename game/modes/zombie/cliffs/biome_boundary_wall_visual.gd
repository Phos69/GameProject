extends Node2D
class_name BiomeBoundaryWallVisual

const BIOME_OBSTACLE_PAINTER := preload(
	"res://game/modes/zombie/biome_obstacle_painter.gd"
)
const PERIMETER_CLIFF_PROFILE := preload(
	"res://game/modes/zombie/cliffs/perimeter_cliff_visual_profile.gd"
)
const GENERATED_TEXTURE_TOOLS := preload(
	"res://game/modes/zombie/generated_biome_texture_tools.gd"
)
const BORDER_GENERATOR := preload(
	"res://game/procedural/world_generation/border_generator.gd"
)

var wall_size: Vector2 = Vector2.ZERO
var wall_height: float = 0.0
var boundary_side: StringName = &""
var uv_origin: Vector2 = Vector2.ZERO
var primary_color: Color = Color.WHITE
var accent_color: Color = Color.WHITE
var primary_profile := PERIMETER_CLIFF_PROFILE.new()
var secondary_profile := PERIMETER_CLIFF_PROFILE.new()
var transition_top_texture: Texture2D

func configure(
	next_wall_size: Vector2,
	next_side: StringName,
	next_uv_origin: Vector2,
	height_cells: int,
	logical_tile_scale: float,
	primary_biome_id: StringName,
	primary_palette: BiomePalette,
	secondary_biome_id: StringName,
	secondary_palette: BiomePalette
) -> void:
	wall_size = next_wall_size
	boundary_side = next_side
	uv_origin = next_uv_origin
	wall_height = maxf(
		float(height_cells) * logical_tile_scale,
		logical_tile_scale
	)
	primary_color = primary_palette.prop_color
	accent_color = primary_palette.hazard_color
	primary_profile.configure(
		BiomeEnvironmentLayout.PERIMETER_VISUAL_RAISED_CLIFF,
		boundary_side,
		uv_origin,
		height_cells,
		logical_tile_scale,
		primary_palette.prop_color,
		primary_palette.hazard_color,
		primary_biome_id
	)
	secondary_profile.configure(
		BiomeEnvironmentLayout.PERIMETER_VISUAL_RAISED_CLIFF,
		BORDER_GENERATOR.get_opposite_side(boundary_side),
		uv_origin,
		height_cells,
		logical_tile_scale,
		secondary_palette.prop_color,
		secondary_palette.hazard_color,
		secondary_biome_id
	)
	transition_top_texture = (
		GENERATED_TEXTURE_TOOLS.blend_biome_wall_transition_texture(
			primary_profile.top_texture,
			secondary_profile.top_texture,
			boundary_side,
			"%s|%s" % [String(primary_biome_id), String(secondary_biome_id)]
		)
	)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	set_meta("unified_biome_wall", true)
	set_meta("primary_biome_id", primary_biome_id)
	set_meta("secondary_biome_id", secondary_biome_id)
	set_meta("boundary_side", boundary_side)
	set_meta(
		"wall_thickness_world",
		wall_size.y
		if boundary_side == &"north" or boundary_side == &"south"
		else wall_size.x
	)
	queue_redraw()

func has_transition_art() -> bool:
	return (
		primary_profile.has_raised_cliff_art()
		and secondary_profile.has_raised_cliff_art()
		and transition_top_texture != null
	)

func _draw() -> void:
	if wall_size.x <= 0.0 or wall_size.y <= 0.0:
		return
	if has_transition_art():
		BIOME_OBSTACLE_PAINTER.draw_raised_perimeter_cliff(
			self,
			wall_size,
			boundary_side,
			wall_height,
			primary_profile.face_texture,
			transition_top_texture,
			uv_origin,
			secondary_profile.face_texture,
			boundary_side
		)
		return
	BIOME_OBSTACLE_PAINTER.draw_perimeter_wall(
		self,
		wall_size,
		primary_color,
		accent_color,
		&"boundary",
		wall_height
	)
