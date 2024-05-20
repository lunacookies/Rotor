@interface
MainView () <CALayerDelegate>
@end

typedef struct Box Box;
struct Box
{
	V4 color;
	V2 origin;
	V2 size;
	V2 texture_origin;
	V2 texture_size;
	F32 border_thickness;
	F32 corner_radius;
	F32 softness;
	V2 cutout_origin;
	V2 cutout_size;
	B32 invert;
};

typedef struct EffectsBox EffectsBox;
struct EffectsBox
{
	V2 origin;
	V2 size;
	F32 corner_radius;
	F32 blur_radius;
};

typedef struct RenderChunk RenderChunk;
struct RenderChunk
{
	RenderChunk *next;
	U64 start;
	U64 count;
	V2 clip_origin;
	V2 clip_size;
};

typedef struct RenderPass RenderPass;
struct RenderPass
{
	RenderPass *next;
	RenderChunk *first_render_chunk;
	RenderChunk *last_render_chunk;
	B32 is_effects;
};

typedef struct Render Render;
struct Render
{
	Box *boxes;
	EffectsBox *effects_boxes;
	U64 box_count;
	U64 box_capacity;
	U64 effects_box_count;
	U64 effects_box_capacity;

	RenderPass *first_render_pass;
	RenderPass *last_render_pass;
};

function RenderPass *
MatchingRenderPass(Arena *arena, Render *render, B32 is_effects)
{
	RenderPass *new_render_pass = 0;

	if (render->first_render_pass == 0)
	{
		Assert(render->last_render_pass == 0);
		new_render_pass = PushStruct(arena, RenderPass);
		render->first_render_pass = new_render_pass;
	}
	else
	{
		if (render->last_render_pass->is_effects == is_effects)
		{
			return render->last_render_pass;
		}
		new_render_pass = PushStruct(arena, RenderPass);
		render->last_render_pass->next = new_render_pass;
	}

	render->last_render_pass = new_render_pass;
	new_render_pass->is_effects = is_effects;
	return new_render_pass;
}

function RenderChunk *
MatchingRenderChunk(Arena *arena, Render *render, V2 clip_origin, V2 clip_size, B32 is_effects)
{
	RenderPass *render_pass = MatchingRenderPass(arena, render, is_effects);

	RenderChunk *new_render_chunk = 0;

	if (render_pass->first_render_chunk == 0)
	{
		Assert(render_pass->last_render_chunk == 0);
		new_render_chunk = PushStruct(arena, RenderChunk);
		render_pass->first_render_chunk = new_render_chunk;
		render_pass->last_render_chunk = new_render_chunk;
	}
	else
	{
		V2 current_clip_origin = render_pass->last_render_chunk->clip_origin;
		V2 current_clip_size = render_pass->last_render_chunk->clip_size;

		B32 clip_origin_matches = current_clip_origin.x == clip_origin.x &&
		                          current_clip_origin.y == clip_origin.y;
		B32 clip_size_matches =
		        current_clip_size.x == clip_size.x && current_clip_size.y == clip_size.y;

		if (clip_origin_matches && clip_size_matches)
		{
			return render_pass->last_render_chunk;
		}

		new_render_chunk = PushStruct(arena, RenderChunk);
		render_pass->last_render_chunk->next = new_render_chunk;
		render_pass->last_render_chunk = new_render_chunk;
	}

	if (is_effects)
	{
		new_render_chunk->start = render->effects_box_count;
	}
	else
	{
		new_render_chunk->start = render->box_count;
	}

	new_render_chunk->clip_origin = clip_origin;
	new_render_chunk->clip_size = clip_size;
	return new_render_chunk;
}

function Box *
AddBox(Arena *arena, Render *render, V2 clip_origin, V2 clip_size)
{
	Assert(render->box_count < render->box_capacity);
	RenderChunk *render_chunk = MatchingRenderChunk(arena, render, clip_origin, clip_size, 0);
	Box *box = render->boxes + render->box_count;
	render->box_count++;
	render_chunk->count++;
	return box;
}

function EffectsBox *
AddEffectsBox(Arena *arena, Render *render, V2 clip_origin, V2 clip_size)
{
	Assert(render->effects_box_count < render->effects_box_capacity);
	RenderChunk *render_chunk = MatchingRenderChunk(arena, render, clip_origin, clip_size, 1);
	EffectsBox *effects_box = render->effects_boxes + render->effects_box_count;
	render->effects_box_count++;
	render_chunk->count++;
	return effects_box;
}

typedef struct RasterizedLine RasterizedLine;
struct RasterizedLine
{
	V2 bounds;
	U64 glyph_count;
	V2 *positions;
	GlyphAtlasSlot **slots;
};

typedef U32 SignalFlags;
enum : SignalFlags
{
	SignalFlags_Clicked = (1 << 0),
	SignalFlags_Pressed = (1 << 1),
	SignalFlags_Hovered = (1 << 2),
	SignalFlags_Dragged = (1 << 3),
	SignalFlags_Scrolled = (1 << 4),
};

typedef struct Signal Signal;
struct Signal
{
	V2 location;
	SignalFlags flags;
	V2 drag_distance;
	V2 scroll_distance;
};

function B32
Clicked(Signal signal)
{
	return signal.flags & SignalFlags_Clicked;
}

function B32
Pressed(Signal signal)
{
	return signal.flags & SignalFlags_Pressed;
}

function B32
Hovered(Signal signal)
{
	return signal.flags & SignalFlags_Hovered;
}

function B32
Dragged(Signal signal)
{
	return signal.flags & SignalFlags_Dragged;
}

function B32
Scrolled(Signal signal)
{
	return signal.flags & SignalFlags_Scrolled;
}

function U64
KeyFromString(String8 string, U64 seed)
{
	// DJB2 hash
	U64 result = seed;
	for (U64 i = 0; i < string.count; i++)
	{
		result = ((result << 5) + result) + string.data[i];
	}
	return result;
}

typedef struct View View;
struct View
{
	String8 string;

	V2 padding;
	V2 size_minimum;
	F32 child_gap;
	Axis2 child_layout_axis;
	V2 child_offset;

	V4 color;
	V4 text_color;

	V4 border_color;
	F32 border_thickness;

	F32 corner_radius;

	V4 drop_shadow_color;
	F32 drop_shadow_softness;
	V2 drop_shadow_offset;

	V4 inner_shadow_color;
	F32 inner_shadow_softness;
	V2 inner_shadow_offset;

	V4 text_shadow_color;
	V2 text_shadow_offset;

	F32 blur_radius;

	B32 clip;
};

typedef struct ViewState ViewState;
struct ViewState
{
	ViewState *next;
	ViewState *first;
	ViewState *last;
	ViewState *parent;

	U64 key;
	ViewState *hash_next;
	ViewState *hash_prev;

	View view;

	V2 origin;
	V2 origin_target;
	V2 origin_velocity;
	V2 size;
	V2 size_target;
	V2 size_velocity;

	RasterizedLine rasterized_line;

	B32 is_first_frame;
	U64 last_touched_build_index;

	B32 pressed;
	B32 hovered;
};

typedef enum EventKind
{
	EventKind_MouseUp = 1,
	EventKind_MouseDown,
	EventKind_MouseMoved,
	EventKind_MouseDragged,
	EventKind_Scroll,
} EventKind;

typedef struct Event Event;
struct Event
{
	Event *next;
	V2 location;
	V2 scroll_distance;
	EventKind kind;
};

typedef struct State State;
struct State
{
	ViewState *root;
	ViewState *current;

	ViewState *first_view_state;
	ViewState *last_view_state;
	ViewState *first_free_view_state;

	Event *first_event;
	Event *last_event;
	V2 last_mouse_down_location;
	V2 last_mouse_drag_location;

	Arena *arena;
	Arena *frame_arena;
	GlyphAtlas *glyph_atlas;
	CTFontRef font;
	U64 build_index;

	B32 make_next_current;
};

function void
RasterizeLine(
        Arena *arena, RasterizedLine *result, String8 text, GlyphAtlas *glyph_atlas, CTFontRef font)
{
	CFStringRef string = CFStringCreateWithBytes(
	        kCFAllocatorDefault, text.data, (CFIndex)text.count, kCFStringEncodingUTF8, 0);

	CFDictionaryRef attributes = (__bridge CFDictionaryRef)
	        @{(__bridge NSString *)kCTFontAttributeName : (__bridge NSFont *)font};

	CFAttributedStringRef attributed =
	        CFAttributedStringCreate(kCFAllocatorDefault, string, attributes);
	CTLineRef line = CTLineCreateWithAttributedString(attributed);
	result->glyph_count = (U64)CTLineGetGlyphCount(line);

	CGRect cg_bounds = CTLineGetBoundsWithOptions(line, 0);
	result->bounds.x = (F32)cg_bounds.size.width;
	result->bounds.y = (F32)cg_bounds.size.height;

	result->positions = PushArray(arena, V2, result->glyph_count);
	result->slots = PushArray(arena, GlyphAtlasSlot *, result->glyph_count);

	CFArrayRef runs = CTLineGetGlyphRuns(line);
	U64 run_count = (U64)CFArrayGetCount(runs);
	U64 glyph_index = 0;

	for (U64 i = 0; i < run_count; i++)
	{
		CTRunRef run = CFArrayGetValueAtIndex(runs, (CFIndex)i);
		U64 run_glyph_count = (U64)CTRunGetGlyphCount(run);

		CFDictionaryRef run_attributes = CTRunGetAttributes(run);
		const void *run_font_raw =
		        CFDictionaryGetValue(run_attributes, kCTFontAttributeName);
		Assert(run_font_raw != NULL);

		// Ensure we actually have a CTFont instance.
		CFTypeID ct_font_type_id = CTFontGetTypeID();
		CFTypeID run_font_attribute_type_id = CFGetTypeID(run_font_raw);
		Assert(ct_font_type_id == run_font_attribute_type_id);

		CTFontRef run_font = run_font_raw;

		CFRange range = {0};
		range.length = (CFIndex)run_glyph_count;

		CGGlyph *glyphs = PushArray(arena, CGGlyph, run_glyph_count);
		CGPoint *glyph_positions = PushArray(arena, CGPoint, run_glyph_count);
		CTRunGetGlyphs(run, range, glyphs);
		CTRunGetPositions(run, range, glyph_positions);

		for (U64 j = 0; j < run_glyph_count; j++)
		{
			F32 x = (F32)glyph_positions[j].x * glyph_atlas->scale_factor;
			F32 y = (F32)glyph_positions[j].y * glyph_atlas->scale_factor;
			F32 subpixel_offset = x - FloorF32(x);
			F32 subpixel_resolution = 4;
			F32 rounded_subpixel_offset =
			        FloorF32(subpixel_offset * subpixel_resolution) /
			        subpixel_resolution;

			GlyphAtlasSlot *slot = GlyphAtlasGet(
			        glyph_atlas, run_font, glyphs[j], rounded_subpixel_offset);

			result->positions[glyph_index].x = FloorF32(x);
			result->positions[glyph_index].y = FloorF32(y - slot->baseline);
			result->slots[glyph_index] = slot;

			glyph_index++;
		}
	}

	CFRelease(line);
	CFRelease(attributed);
	CFRelease(string);
}

global State *state;

function void
StateInit(Arena *frame_arena, GlyphAtlas *glyph_atlas)
{
	Arena *arena = ArenaAlloc();
	state = PushStruct(arena, State);
	state->arena = arena;
	state->frame_arena = frame_arena;
	state->glyph_atlas = glyph_atlas;
	state->font = (__bridge CTFontRef)[NSFont systemFontOfSize:14 weight:NSFontWeightRegular];
}

function void
MakeNextCurrent(void)
{
	state->make_next_current = 1;
}

function void
MakeParentCurrent(void)
{
	state->current = state->current->parent;
}

function ViewState *
ViewStateAlloc(void)
{
	ViewState *result = state->first_free_view_state;
	if (result == 0)
	{
		result = PushStruct(state->arena, ViewState);
	}
	else
	{
		state->first_free_view_state = state->first_free_view_state->hash_next;
		MemoryZeroStruct(result);
	}

	if (state->first_view_state == 0)
	{
		state->first_view_state = result;
	}
	else
	{
		state->last_view_state->hash_next = result;
	}

	result->hash_prev = state->last_view_state;
	state->last_view_state = result;
	return result;
}

function void
ViewStateRelease(ViewState *view_state)
{
	if (state->first_view_state == view_state)
	{
		state->first_view_state = view_state->hash_next;
	}

	if (state->last_view_state == view_state)
	{
		state->last_view_state = view_state->hash_prev;
	}

	if (view_state->hash_prev != 0)
	{
		view_state->hash_prev->hash_next = view_state->hash_next;
	}

	if (view_state->hash_next != 0)
	{
		view_state->hash_next->hash_prev = view_state->hash_prev;
	}

	view_state->hash_next = state->first_free_view_state;
	state->first_free_view_state = view_state;
}

function void
ViewStatePush(ViewState *view_state)
{
	view_state->last_touched_build_index = state->build_index;

	MemoryZeroStruct(&view_state->view);
	view_state->view.child_layout_axis = Axis2_Y;

	view_state->next = 0;
	view_state->first = 0;
	view_state->last = 0;
	view_state->parent = 0;

	// Push view state onto the list of children of the current view state.
	view_state->parent = state->current;
	if (state->current->first == 0)
	{
		Assert(state->current->last == 0);
		state->current->first = view_state;
	}
	else
	{
		state->current->last->next = view_state;
	}
	state->current->last = view_state;

	if (state->make_next_current)
	{
		state->current = view_state;
		state->make_next_current = 0;
	}
}

function View *
ViewFromString(String8 string)
{
	ViewState *result = 0;
	U64 key = KeyFromString(string, state->current->key);

	for (ViewState *view_state = state->first_view_state; view_state != 0;
	        view_state = view_state->hash_next)
	{
		if (view_state->key == key)
		{
			result = view_state;
			result->is_first_frame = 0;
			break;
		}
	}

	if (result == 0)
	{
		result = ViewStateAlloc();
		result->key = key;
		result->is_first_frame = 1;
	}

	ViewStatePush(result);

	return &result->view;
}

function Signal
SignalForView(View *view)
{
	ViewState *view_state = (ViewState *)((U8 *)view - offsetof(ViewState, view));

	Signal result = {0};
	if (view_state->pressed)
	{
		result.flags |= SignalFlags_Pressed;
	}
	if (view_state->hovered)
	{
		result.flags |= SignalFlags_Hovered;
	}

	for (Event *event = state->first_event; event != 0; event = event->next)
	{
		result.location = event->location;

		B32 in_bounds = event->location.x >= view_state->origin.x &&
		                event->location.y >= view_state->origin.y &&
		                event->location.x <= view_state->origin.x + view_state->size.x &&
		                event->location.y <= view_state->origin.y + view_state->size.y;

		B32 last_mouse_down_in_bounds =
		        state->last_mouse_down_location.x >= view_state->origin.x &&
		        state->last_mouse_down_location.y >= view_state->origin.y &&
		        state->last_mouse_down_location.x <=
		                view_state->origin.x + view_state->size.x &&
		        state->last_mouse_down_location.y <=
		                view_state->origin.y + view_state->size.y;

		if (in_bounds)
		{
			result.flags |= SignalFlags_Hovered;
		}
		else
		{
			result.flags &= ~SignalFlags_Hovered;
		}

		switch (event->kind)
		{
			case EventKind_MouseUp:
			{
				result.flags &= ~SignalFlags_Pressed;
				if (in_bounds && last_mouse_down_in_bounds)
				{
					result.flags |= SignalFlags_Clicked;
				}
			}
			break;

			case EventKind_MouseDown:
			{
				if (in_bounds)
				{
					result.flags |= SignalFlags_Pressed;
					state->last_mouse_drag_location = event->location;
				}
				state->last_mouse_down_location = event->location;
			}
			break;

			case EventKind_MouseMoved:
			{
			}
			break;

			case EventKind_MouseDragged:
			{
				if (last_mouse_down_in_bounds)
				{
					result.flags |= SignalFlags_Dragged;
					result.drag_distance.x += event->location.x -
					                          state->last_mouse_drag_location.x;
					result.drag_distance.y += event->location.y -
					                          state->last_mouse_drag_location.y;
					if (in_bounds)
					{
						result.flags |= SignalFlags_Pressed;
					}
					state->last_mouse_drag_location = event->location;
				}

				if (!in_bounds)
				{
					result.flags &= ~SignalFlags_Pressed;
				}
			}
			break;

			case EventKind_Scroll:
			{
				if (in_bounds)
				{
					result.flags |= SignalFlags_Scrolled;
					result.scroll_distance = event->scroll_distance;
				}
			}
			break;
		}
	}

	view_state->pressed = result.flags & SignalFlags_Pressed;
	view_state->hovered = result.flags & SignalFlags_Hovered;
	return result;
}

function Signal
Label(String8 string)
{
	View *view = ViewFromString(string);
	view->string = string;
	view->text_color = v4(1, 1, 1, 1);
	return SignalForView(view);
}

function Signal
Button(String8 string)
{
	View *view = ViewFromString(string);
	view->string = string;
	view->padding = v2(10, 3);
	view->color = v4(0.35f, 0.35f, 0.35f, 1);
	view->text_color = v4(1, 1, 1, 1);
	view->border_thickness = 1;
	view->border_color = v4(0, 0, 0, 1);
	view->corner_radius = 4;
	view->drop_shadow_color = v4(0, 0, 0, 0.25f);
	view->drop_shadow_softness = 4;
	view->drop_shadow_offset.y = 2;
	view->inner_shadow_color = v4(1, 1, 1, 0.2f);
	view->inner_shadow_offset.y = 1;
	view->text_shadow_color = v4(0, 0, 0, 1);
	view->text_shadow_offset = v2(0, -0.5f);

	Signal signal = SignalForView(view);

	if (Hovered(signal))
	{
		view->color = v4(0.45f, 0.45f, 0.45f, 1);
	}

	if (Pressed(signal))
	{
		view->color = v4(0.15f, 0.15f, 0.15f, 1);
		view->text_color = v4(0.9f, 0.9f, 0.9f, 1);
		view->drop_shadow_color = v4(1, 1, 1, 0.2f);
		view->drop_shadow_softness = 1;
		view->drop_shadow_offset.y = 1;
		view->inner_shadow_color = v4(0, 0, 0, 0.5f);
		view->inner_shadow_softness = 4;
		view->inner_shadow_offset.y = 2;
	}

	return signal;
}

function Signal
Checkbox(B32 *value, String8 string)
{
	MakeNextCurrent();
	View *view = ViewFromString(string);

	MakeNextCurrent();
	View *box = ViewFromString(Str8Lit("box"));
	View *mark = ViewFromString(Str8Lit("mark"));
	MakeParentCurrent();

	View *label = ViewFromString(Str8Lit("label"));
	MakeParentCurrent();

	view->child_layout_axis = Axis2_X;
	view->child_gap = 5;
	box->border_thickness = 1;
	box->corner_radius = 2;
	box->drop_shadow_color = v4(1, 1, 1, 0.1f);
	box->drop_shadow_softness = 1;
	box->drop_shadow_offset.y = 1;
	mark->corner_radius = 2;
	mark->color = v4(1, 1, 1, 1);
	mark->drop_shadow_color = v4(0, 0, 0, 0.5);
	mark->drop_shadow_softness = 4;
	mark->drop_shadow_offset.y = 2;
	label->string = string;
	label->text_color = v4(1, 1, 1, 1);

	Signal signal = SignalForView(view);
	if (Clicked(signal))
	{
		*value = !*value;
	}

	if (*value)
	{
		if (Pressed(signal))
		{
			box->color = v4(0.2f, 0.7f, 1, 1);
			box->padding = v2(6, 6);
			mark->padding = v2(4, 4);
		}
		else
		{
			box->color = v4(0, 0.5f, 1, 1);
			box->padding = v2(5, 5);
			mark->padding = v2(5, 5);
		}
		box->border_color = v4(0, 0, 0, 0.5f);
	}
	else
	{
		if (Pressed(signal))
		{
			box->color = v4(0.4f, 0.4f, 0.4f, 1);
			box->padding = v2(8, 8);
			mark->padding = v2(2, 2);
		}
		else
		{
			box->color = v4(0.1f, 0.1f, 0.1f, 1);
			box->padding = v2(10, 10);
			mark->padding = v2(0, 0);
		}
		box->border_color = v4(0, 0, 0, 1);
	}

	return signal;
}

function Signal
RadioButton(U32 *selection, U32 option, String8 string)
{
	MakeNextCurrent();
	View *view = ViewFromString(string);

	MakeNextCurrent();
	View *box = ViewFromString(Str8Lit("box"));
	View *mark = ViewFromString(Str8Lit("mark"));
	MakeParentCurrent();

	View *label = ViewFromString(Str8Lit("label"));
	MakeParentCurrent();

	view->child_layout_axis = Axis2_X;
	view->child_gap = 5;
	box->border_thickness = 1;
	box->corner_radius = 10;
	box->drop_shadow_color = v4(1, 1, 1, 0.1f);
	box->drop_shadow_softness = 1;
	box->drop_shadow_offset.y = 1;
	mark->color = v4(1, 1, 1, 1);
	mark->corner_radius = 10;
	mark->drop_shadow_color = v4(0, 0, 0, 0.5);
	mark->drop_shadow_softness = 4;
	mark->drop_shadow_offset.y = 2;
	label->string = string;
	label->text_color = v4(1, 1, 1, 1);

	Signal signal = SignalForView(view);
	if (Clicked(signal))
	{
		*selection = option;
	}

	if (*selection == option)
	{
		if (Pressed(signal))
		{
			box->color = v4(0.2f, 0.7f, 1, 1);
			box->padding = v2(6, 6);
			mark->padding = v2(4, 4);
		}
		else
		{
			box->color = v4(0, 0.5f, 1, 1);
			box->padding = v2(5, 5);
			mark->padding = v2(5, 5);
		}
		box->border_color = v4(0, 0, 0, 0.5f);
	}
	else
	{
		if (Pressed(signal))
		{
			box->color = v4(0.4f, 0.4f, 0.4f, 1);
			box->padding = v2(8, 8);
			mark->padding = v2(2, 2);
		}
		else
		{
			box->color = v4(0.1f, 0.1f, 0.1f, 1);
			box->padding = v2(10, 10);
			mark->padding = v2(0, 0);
		}
		box->border_color = v4(0, 0, 0, 1);
	}

	return signal;
}

function Signal
SliderF32(F32 *value, F32 minimum, F32 maximum, String8 string)
{
	MakeNextCurrent();
	View *view = ViewFromString(string);

	MakeNextCurrent();
	View *track = ViewFromString(Str8Lit("track"));
	View *thumb = ViewFromString(Str8Lit("thumb"));
	MakeParentCurrent();

	View *label = ViewFromString(Str8Lit("label"));

	MakeParentCurrent();

	V2 size = v2(200, 20);

	view->child_layout_axis = Axis2_X;
	view->child_gap = 10;
	track->size_minimum = size;
	track->color = v4(0, 0, 0, 1);
	track->corner_radius = size.y;
	track->drop_shadow_color = v4(1, 1, 1, 0.1f);
	track->drop_shadow_softness = 1;
	track->drop_shadow_offset.y = 1;
	thumb->size_minimum = size;
	thumb->size_minimum.x *= (*value - minimum) / (maximum - minimum);
	thumb->corner_radius = size.y;
	label->text_color = v4(1, 1, 1, 1);

	Signal signal = SignalForView(view);

	if (Pressed(signal))
	{
		thumb->color = v4(1, 1, 1, 1);
	}
	else
	{
		thumb->color = v4(0.7f, 0.7f, 0.7f, 1);
	}

	if (Dragged(signal))
	{
		*value += MixF32(0, maximum - minimum, signal.drag_distance.x / size.x);
		*value = Clamp(*value, minimum, maximum);
	}

	label->string = String8Format(state->frame_arena, "%.5f", *value);

	return signal;
}

function Signal
Scrollable(String8 string, V2 *scroll_position)
{
	View *view = ViewFromString(string);
	view->color = v4(0.1f, 0.1f, 0.1f, 0.5f);
	view->size_minimum = v2(200, 200);
	view->clip = 1;

	Signal signal = SignalForView(view);
	if (Scrolled(signal))
	{
		scroll_position->x += signal.scroll_distance.x;
		scroll_position->y += signal.scroll_distance.y;
	}

	view->child_offset = *scroll_position;

	return signal;
}

function void
PruneUnusedViewStates(void)
{
	ViewState *next = 0;

	for (ViewState *view_state = state->first_view_state; view_state != 0; view_state = next)
	{
		next = view_state->hash_next;

		if (view_state->last_touched_build_index < state->build_index)
		{
			ViewStateRelease(view_state);
		}
	}
}

global B32 use_springs = 1;
global B32 use_animations = 1;

function void
StepAnimation(F32 *x, F32 *dx, F32 x_target, B32 is_size)
{
	if (!use_animations)
	{
		*x = x_target;
		return;
	}

	if (!use_springs)
	{
		*x += (x_target - *x) * 0.1f;
		return;
	}

	F32 tension = 1;
	F32 friction = 5;
	F32 mass = 20;

	F32 displacement = *x - x_target;
	F32 tension_force = -tension * displacement;
	F32 friction_force = -friction * *dx;
	F32 ddx = (tension_force + friction_force) * (1.f / mass);
	*dx += ddx;
	*x += *dx;

	if (is_size && *x < 0)
	{
		*dx = 0;
		*x = 0;
		return;
	}
}

function void
LayoutViewState(ViewState *view_state, V2 origin)
{
	MemoryZeroStruct(&view_state->rasterized_line);
	if (view_state->view.text_color.a > 0)
	{
		RasterizeLine(state->frame_arena, &view_state->rasterized_line,
		        view_state->view.string, state->glyph_atlas, state->font);
	}

	V2 start_position = origin;
	V2 current_position = origin;
	current_position.x += view_state->view.padding.x + view_state->view.child_offset.x;
	current_position.y += view_state->view.padding.y + view_state->view.child_offset.y;

	current_position.y += RoundF32(view_state->rasterized_line.bounds.y);

	V2 content_size_max = {0};
	content_size_max.x = RoundF32(view_state->rasterized_line.bounds.x);
	content_size_max.y = RoundF32(view_state->rasterized_line.bounds.y);

	for (ViewState *child = view_state->first; child != 0; child = child->next)
	{
		if (child != view_state->first)
		{
			switch (view_state->view.child_layout_axis)
			{
				case Axis2_X:
				{
					current_position.x += view_state->view.child_gap;
				}
				break;

				case Axis2_Y:
				{
					current_position.y += view_state->view.child_gap;
				}
				break;
			}
		}

		LayoutViewState(child, current_position);
		content_size_max.x = Max(content_size_max.x, child->size_target.x);
		content_size_max.y = Max(content_size_max.y, child->size_target.y);

		switch (view_state->view.child_layout_axis)
		{
			case Axis2_X:
			{
				current_position.x += child->size_target.x;
			}
			break;

			case Axis2_Y:
			{
				current_position.y += child->size_target.y;
			}
			break;
		}
	}

	current_position.y += view_state->view.padding.y;

	// Update origin and size targets.
	view_state->origin_target = origin;
	switch (view_state->view.child_layout_axis)
	{
		case Axis2_X:
		{
			view_state->size_target.x = current_position.x - start_position.x;
			view_state->size_target.y =
			        content_size_max.y + view_state->view.padding.y * 2;
		}
		break;

		case Axis2_Y:
		{
			view_state->size_target.x =
			        content_size_max.x + view_state->view.padding.x * 2;
			view_state->size_target.y = current_position.y - start_position.y;
		}
		break;
	}
	view_state->size_target.x = Max(view_state->size_target.x, view_state->view.size_minimum.x);
	view_state->size_target.y = Max(view_state->size_target.y, view_state->view.size_minimum.y);

	// Step origin and size animations towards their targets.
	if (view_state->is_first_frame)
	{
		view_state->origin = view_state->origin_target;
		view_state->size = view_state->size_target;
	}
	else
	{
		StepAnimation(&view_state->origin.x, &view_state->origin_velocity.x,
		        view_state->origin_target.x, 0);
		StepAnimation(&view_state->origin.y, &view_state->origin_velocity.y,
		        view_state->origin_target.y, 0);
		StepAnimation(&view_state->size.x, &view_state->size_velocity.x,
		        view_state->size_target.x, 1);
		StepAnimation(&view_state->size.y, &view_state->size_velocity.y,
		        view_state->size_target.y, 1);
	}
}

function void
LayoutUI(V2 viewport_size)
{
	LayoutViewState(state->root, v2(0, 0));
}

function void
StartBuild(void)
{
	state->root = ViewStateAlloc();
	state->root->is_first_frame = 1;
	state->root->view.color = v4(0.1f, 0.1f, 0.1f, 0.7f);
	state->root->view.padding = v2(20, 20);
	state->root->view.child_gap = 10;
	state->root->view.child_layout_axis = Axis2_Y;
	state->root->view.blur_radius = 10;
	state->current = state->root;
	state->build_index++;
}

function void
EndBuild(V2 viewport_size)
{
	PruneUnusedViewStates();
	LayoutUI(viewport_size);
	state->first_event = 0;
	state->last_event = 0;
}

function void
BuildUI(void)
{
	if (Clicked(Button(Str8Lit("Button 1"))))
	{
		printf("button 1!\n");
	}

	Signal button_2_signal = Button(Str8Lit("Toggle Button 3"));
	local_persist B32 show_button_3 = 0;

	if (Clicked(button_2_signal))
	{
		printf("button 2!\n");
		show_button_3 = !show_button_3;
	}

	if (show_button_3)
	{
		if (Clicked(Button(Str8Lit("Button 3"))))
		{
			printf("button 3!\n");
		}
	}

	if (Pressed(button_2_signal))
	{
		Label(Str8Lit("Button 2 is currently pressed."));
	}

	Button(Str8Lit("Another Button"));

	Checkbox(&show_button_3, Str8Lit("Button 3?"));

	local_persist B32 checked = 0;
	Checkbox(&checked, Str8Lit("Another Checkbox"));
	Signal springs_signal = Checkbox(&use_springs, Str8Lit("Animate Using Springs"));
	Checkbox(&use_animations, Str8Lit("Animate"));
	if (Clicked(springs_signal) && use_springs)
	{
		use_animations = 1;
	}

	local_persist F32 value = 15;
	SliderF32(&value, 10, 20, Str8Lit("Slider"));

	local_persist U32 selection = 0;
	RadioButton(&selection, 0, Str8Lit("Foo"));
	RadioButton(&selection, 1, Str8Lit("Bar"));
	RadioButton(&selection, 2, Str8Lit("Baz"));

	MakeNextCurrent();
	local_persist V2 scroll_position = {0};
	Scrollable(Str8Lit("scrollable"), &scroll_position);
	Button(Str8Lit("some button 1"));
	Button(Str8Lit("some button 2"));
	Button(Str8Lit("some button 3"));
	Button(Str8Lit("some button 4"));
	Button(Str8Lit("some button 5"));
	Button(Str8Lit("some button 6"));
	Button(Str8Lit("some button 7"));
	Button(Str8Lit("some button 8"));
	Button(Str8Lit("some button 9"));
	Button(Str8Lit("some button 10"));
	Button(Str8Lit("some button 11"));
	MakeParentCurrent();
}

function void
RenderViewState(
        ViewState *view_state, V2 clip_origin, V2 clip_size, F32 scale_factor, Render *render)
{
	if (view_state->view.clip)
	{
		V2 parent_clip_origin = clip_origin;
		V2 parent_clip_size = clip_size;
		clip_origin.x = Max(parent_clip_origin.x, view_state->origin.x);
		clip_origin.y = Max(parent_clip_origin.y, view_state->origin.y);
		clip_size.x = Min(parent_clip_origin.x + parent_clip_size.x,
		                      view_state->origin.x + view_state->size.x) -
		              clip_origin.x;
		clip_size.y = Min(parent_clip_origin.y + parent_clip_size.y,
		                      view_state->origin.y + view_state->size.y) -
		              clip_origin.y;
	}

	V2 inside_border_origin = view_state->origin;
	inside_border_origin.x += view_state->view.border_thickness;
	inside_border_origin.y += view_state->view.border_thickness;

	V2 inside_border_size = view_state->size;
	inside_border_size.x -= view_state->view.border_thickness * 2;
	inside_border_size.y -= view_state->view.border_thickness * 2;

	F32 inside_border_corner_radius =
	        view_state->view.corner_radius - view_state->view.border_thickness;

	if (view_state->view.blur_radius > 0)
	{
		EffectsBox *box = AddEffectsBox(state->frame_arena, render, clip_origin, clip_size);
		box->origin = inside_border_origin;
		box->origin.x *= scale_factor;
		box->origin.y *= scale_factor;
		box->size = inside_border_size;
		box->size.x *= scale_factor;
		box->size.y *= scale_factor;
		box->corner_radius = inside_border_corner_radius * scale_factor;
		box->blur_radius = view_state->view.blur_radius * scale_factor;
	}

	if (view_state->view.color.a > 0)
	{
		Box *box = AddBox(state->frame_arena, render, clip_origin, clip_size);
		box->origin = inside_border_origin;
		box->origin.x *= scale_factor;
		box->origin.y *= scale_factor;
		box->size = inside_border_size;
		box->size.x *= scale_factor;
		box->size.y *= scale_factor;
		box->color = view_state->view.color;
		box->corner_radius = inside_border_corner_radius * scale_factor;
	}

	if (view_state->view.text_color.a > 0)
	{
		V2 text_origin = view_state->origin;
		text_origin.x += view_state->view.padding.x;
		text_origin.y += view_state->view.padding.y;
		text_origin.x *= scale_factor;
		text_origin.y *= scale_factor;
		text_origin.y += RoundF32((view_state->rasterized_line.bounds.y +
		                                  (F32)CTFontGetCapHeight(state->font)) *
		                          scale_factor * 0.5f);

		if (view_state->view.text_shadow_color.a > 0)
		{
			V2 text_shadow_origin = text_origin;
			text_shadow_origin.x +=
			        view_state->view.text_shadow_offset.x * scale_factor;
			text_shadow_origin.y +=
			        view_state->view.text_shadow_offset.y * scale_factor;

			for (U64 glyph_index = 0;
			        glyph_index < view_state->rasterized_line.glyph_count;
			        glyph_index++)
			{
				GlyphAtlasSlot *slot =
				        view_state->rasterized_line.slots[glyph_index];

				Box *box =
				        AddBox(state->frame_arena, render, clip_origin, clip_size);
				box->origin = view_state->rasterized_line.positions[glyph_index];
				box->origin.x += text_shadow_origin.x;
				box->origin.y += text_shadow_origin.y;
				box->texture_origin.x = slot->origin.x;
				box->texture_origin.y = slot->origin.y;
				box->size.x = slot->size.x;
				box->size.y = slot->size.y;
				box->texture_size.x = slot->size.x;
				box->texture_size.y = slot->size.y;
				box->color = view_state->view.text_shadow_color;
			}
		}

		for (U64 glyph_index = 0; glyph_index < view_state->rasterized_line.glyph_count;
		        glyph_index++)
		{
			GlyphAtlasSlot *slot = view_state->rasterized_line.slots[glyph_index];

			Box *box = AddBox(state->frame_arena, render, clip_origin, clip_size);
			box->origin = view_state->rasterized_line.positions[glyph_index];
			box->origin.x += text_origin.x;
			box->origin.y += text_origin.y;
			box->texture_origin.x = slot->origin.x;
			box->texture_origin.y = slot->origin.y;
			box->size.x = slot->size.x;
			box->size.y = slot->size.y;
			box->texture_size.x = slot->size.x;
			box->texture_size.y = slot->size.y;
			box->color = view_state->view.text_color;
		}
	}

	for (ViewState *child = view_state->first; child != 0; child = child->next)
	{
		if (child->view.drop_shadow_color.a > 0)
		{
			Box *box = AddBox(state->frame_arena, render, clip_origin, clip_size);
			box->origin = child->origin;
			box->origin.x += child->view.drop_shadow_offset.x;
			box->origin.y += child->view.drop_shadow_offset.y;
			box->origin.x *= scale_factor;
			box->origin.y *= scale_factor;
			box->size = child->size;
			box->size.x *= scale_factor;
			box->size.y *= scale_factor;
			box->color = child->view.drop_shadow_color;
			box->corner_radius = child->view.corner_radius * scale_factor;
			box->softness = child->view.drop_shadow_softness * scale_factor;
			box->cutout_origin = child->origin;
			box->cutout_origin.x *= scale_factor;
			box->cutout_origin.y *= scale_factor;
			box->cutout_size = child->size;
			box->cutout_size.x *= scale_factor;
			box->cutout_size.y *= scale_factor;
		}
	}

	for (ViewState *child = view_state->first; child != 0; child = child->next)
	{
		RenderViewState(child, clip_origin, clip_size, scale_factor, render);
	}

	if (view_state->view.inner_shadow_color.a > 0)
	{
		Box *box = AddBox(state->frame_arena, render, clip_origin, clip_size);
		box->origin = inside_border_origin;
		box->origin.x += view_state->view.inner_shadow_offset.x;
		box->origin.y += view_state->view.inner_shadow_offset.y;
		box->origin.x *= scale_factor;
		box->origin.y *= scale_factor;
		box->size = inside_border_size;
		box->size.x *= scale_factor;
		box->size.y *= scale_factor;
		box->color = view_state->view.inner_shadow_color;
		box->corner_radius = inside_border_corner_radius * scale_factor;
		box->softness = view_state->view.inner_shadow_softness * scale_factor;
		box->cutout_origin = inside_border_origin;
		box->cutout_origin.x *= scale_factor;
		box->cutout_origin.y *= scale_factor;
		box->cutout_size = inside_border_size;
		box->cutout_size.x *= scale_factor;
		box->cutout_size.y *= scale_factor;
		box->invert = 1;
	}

	if (view_state->view.border_thickness > 0)
	{
		Box *box = AddBox(state->frame_arena, render, clip_origin, clip_size);
		box->origin = view_state->origin;
		box->origin.x *= scale_factor;
		box->origin.y *= scale_factor;
		box->size = view_state->size;
		box->size.x *= scale_factor;
		box->size.y *= scale_factor;
		box->color = view_state->view.border_color;
		box->border_thickness = view_state->view.border_thickness * scale_factor;
		box->corner_radius = view_state->view.corner_radius * scale_factor;
	}
}

function void
RenderUI(V2 viewport_size, F32 scale_factor, Render *render)
{
	RenderViewState(state->root, v2(0, 0), viewport_size, scale_factor, render);
}

__attribute((constructor)) function void
MainViewInit(void)
{
	setenv("MTL_HUD_ENABLED", "1", 1);
	setenv("MTL_SHADER_VALIDATION", "1", 1);
	setenv("MTL_DEBUG_LAYER", "1", 1);
	setenv("MTL_DEBUG_LAYER_WARNING_MODE", "assert", 1);
	setenv("MTL_DEBUG_LAYER_VALIDATE_LOAD_ACTIONS", "1", 1);
	setenv("MTL_DEBUG_LAYER_VALIDATE_STORE_ACTIONS", "1", 1);
}

@implementation MainView

Arena *permanent_arena;
Arena *frame_arena;

CAMetalLayer *metal_layer;
id<MTLCommandQueue> command_queue;
id<MTLRenderPipelineState> pipeline_state;
id<MTLRenderPipelineState> effects_pipeline_state;
id<MTLTexture> offscreen_texture;

CVDisplayLinkRef display_link;

GlyphAtlas glyph_atlas;

id<MTLRenderPipelineState> game_pipeline_state;
U64 game_count;
V2 *game_positions;
V2 *game_velocities;
F32 *game_sizes;
V3 *game_colors;

- (instancetype)initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];

	self.wantsLayer = YES;
	self.layer = [CAMetalLayer layer];
	metal_layer = (CAMetalLayer *)self.layer;
	permanent_arena = ArenaAlloc();
	frame_arena = ArenaAlloc();

	metal_layer.delegate = self;
	metal_layer.device = MTLCreateSystemDefaultDevice();
	metal_layer.pixelFormat = MTLPixelFormatRGBA16Float;
	metal_layer.framebufferOnly = NO;
	command_queue = [metal_layer.device newCommandQueue];

	metal_layer.colorspace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
	Assert(metal_layer.colorspace);

	NSError *error = nil;

	NSBundle *bundle = [NSBundle mainBundle];
	NSURL *library_url = [bundle URLForResource:@"shaders" withExtension:@"metallib"];
	id<MTLLibrary> library = [metal_layer.device newLibraryWithURL:library_url error:&error];
	if (library == nil)
	{
		[[NSAlert alertWithError:error] runModal];
		abort();
	}

	MTLRenderPipelineDescriptor *descriptor = [[MTLRenderPipelineDescriptor alloc] init];
	descriptor.colorAttachments[0].pixelFormat = metal_layer.pixelFormat;
	descriptor.colorAttachments[0].blendingEnabled = YES;
	descriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
	descriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
	descriptor.colorAttachments[0].destinationRGBBlendFactor =
	        MTLBlendFactorOneMinusSourceAlpha;
	descriptor.colorAttachments[0].destinationAlphaBlendFactor =
	        MTLBlendFactorOneMinusSourceAlpha;

	descriptor.vertexFunction = [library newFunctionWithName:@"VertexShader"];
	descriptor.fragmentFunction = [library newFunctionWithName:@"FragmentShader"];

	pipeline_state = [metal_layer.device newRenderPipelineStateWithDescriptor:descriptor
	                                                                    error:&error];

	if (pipeline_state == nil)
	{
		[[NSAlert alertWithError:error] runModal];
		abort();
	}

	descriptor.vertexFunction = [library newFunctionWithName:@"EffectsVertexShader"];
	descriptor.fragmentFunction = [library newFunctionWithName:@"EffectsFragmentShader"];

	effects_pipeline_state = [metal_layer.device newRenderPipelineStateWithDescriptor:descriptor
	                                                                            error:&error];

	if (effects_pipeline_state == nil)
	{
		[[NSAlert alertWithError:error] runModal];
		abort();
	}

	descriptor.vertexFunction = [library newFunctionWithName:@"GameVertexShader"];
	descriptor.fragmentFunction = [library newFunctionWithName:@"GameFragmentShader"];

	game_pipeline_state = [metal_layer.device newRenderPipelineStateWithDescriptor:descriptor
	                                                                         error:&error];

	if (game_pipeline_state == nil)
	{
		[[NSAlert alertWithError:error] runModal];
		abort();
	}

	game_count = 256;
	game_positions = PushArray(permanent_arena, V2, game_count);
	game_velocities = PushArray(permanent_arena, V2, game_count);
	game_sizes = PushArray(permanent_arena, F32, game_count);
	game_colors = PushArray(permanent_arena, V3, game_count);

	for (U64 i = 0; i < game_count; i++)
	{
		game_positions[i].x = (F32)arc4random_uniform(1000) - 500;
		game_positions[i].y = (F32)arc4random_uniform(1000) - 500;

		game_velocities[i].x = ((F32)arc4random_uniform(1000) - 500) / 200;
		game_velocities[i].y = ((F32)arc4random_uniform(1000) - 500) / 200;

		game_sizes[i] = (F32)arc4random_uniform(100);

		game_colors[i].r = (F32)arc4random_uniform(1024) / 1024;
		game_colors[i].g = (F32)arc4random_uniform(1024) / 1024;
		game_colors[i].b = (F32)arc4random_uniform(1024) / 1024;
	}

	CVDisplayLinkCreateWithActiveCGDisplays(&display_link);
	CVDisplayLinkSetOutputCallback(display_link, DisplayLinkCallback, (__bridge void *)self);

	return self;
}

- (void)displayLayer:(CALayer *)layer
{
	Render render = {0};
	render.box_capacity = 1024;
	render.effects_box_capacity = 128;

	id<MTLBuffer> box_buffer =
	        [metal_layer.device newBufferWithLength:render.box_capacity * sizeof(Box)
	                                        options:MTLResourceStorageModeShared];
	id<MTLBuffer> effects_box_buffer = [metal_layer.device
	        newBufferWithLength:render.effects_box_capacity * sizeof(EffectsBox)
	                    options:MTLResourceStorageModeShared];
	render.boxes = box_buffer.contents;
	render.effects_boxes = effects_box_buffer.contents;

	V2 viewport_size = {0};
	viewport_size.x = (F32)self.bounds.size.width;
	viewport_size.y = (F32)self.bounds.size.height;

	F32 scale_factor = (F32)self.window.backingScaleFactor;

	StartBuild();
	BuildUI();
	EndBuild(viewport_size);
	RenderUI(viewport_size, scale_factor, &render);

	for (U64 i = 0; i < game_count; i++)
	{
		game_positions[i].x += game_velocities[i].x;
		game_positions[i].y += game_velocities[i].y;

		if (game_positions[i].x < viewport_size.x * -0.5)
		{
			game_velocities[i].x = AbsF32(game_velocities[i].x);
		}

		if (game_positions[i].x > viewport_size.x * 0.5)
		{
			game_velocities[i].x = -AbsF32(game_velocities[i].x);
		}

		if (game_positions[i].y < viewport_size.y * -0.5)
		{
			game_velocities[i].y = AbsF32(game_velocities[i].y);
		}

		if (game_positions[i].y > viewport_size.y * 0.5)
		{
			game_velocities[i].y = -AbsF32(game_velocities[i].y);
		}
	}

	id<MTLCommandBuffer> command_buffer = [command_queue commandBuffer];
	id<CAMetalDrawable> drawable = [metal_layer nextDrawable];
	id<MTLTexture> drawable_texture = drawable.texture;

	{
		MTLRenderPassDescriptor *descriptor =
		        [MTLRenderPassDescriptor renderPassDescriptor];
		descriptor.colorAttachments[0].texture = drawable_texture;
		descriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
		descriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
		descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.5, 0.5, 0.5, 1);

		id<MTLRenderCommandEncoder> encoder =
		        [command_buffer renderCommandEncoderWithDescriptor:descriptor];

		[encoder setRenderPipelineState:game_pipeline_state];

		[encoder setVertexBytes:game_positions length:game_count * sizeof(V2) atIndex:0];
		[encoder setVertexBytes:game_sizes length:game_count * sizeof(F32) atIndex:1];
		[encoder setVertexBytes:game_colors length:game_count * sizeof(V3) atIndex:2];
		[encoder setVertexBytes:&viewport_size length:sizeof(viewport_size) atIndex:3];
		[encoder drawPrimitives:MTLPrimitiveTypeTriangle
		            vertexStart:0
		            vertexCount:6
		          instanceCount:game_count];

		[encoder endEncoding];
	}

	V2 viewport_size_pixels = viewport_size;
	viewport_size_pixels.x *= scale_factor;
	viewport_size_pixels.y *= scale_factor;

	for (RenderPass *render_pass = render.first_render_pass; render_pass != 0;
	        render_pass = render_pass->next)
	{
		if (render_pass->is_effects)
		{
			id<MTLBlitCommandEncoder> blit_encoder = [command_buffer
			        blitCommandEncoderWithDescriptor:[MTLBlitPassDescriptor
			                                                 blitPassDescriptor]];
			[blit_encoder copyFromTexture:drawable_texture toTexture:offscreen_texture];
			[blit_encoder endEncoding];

			for (B32 is_vertical = 0; is_vertical <= 1; is_vertical++)
			{
				MTLRenderPassDescriptor *descriptor =
				        [MTLRenderPassDescriptor renderPassDescriptor];

				if (is_vertical)
				{
					descriptor.colorAttachments[0].texture = drawable_texture;
				}
				else
				{
					descriptor.colorAttachments[0].texture = offscreen_texture;
				}

				descriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
				descriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;

				id<MTLRenderCommandEncoder> encoder = [command_buffer
				        renderCommandEncoderWithDescriptor:descriptor];

				[encoder setRenderPipelineState:effects_pipeline_state];

				[encoder setVertexBytes:&viewport_size_pixels
				                 length:sizeof(viewport_size_pixels)
				                atIndex:1];

				[encoder setVertexBytes:&is_vertical
				                 length:sizeof(is_vertical)
				                atIndex:2];

				if (is_vertical)
				{
					[encoder setFragmentTexture:offscreen_texture atIndex:0];
				}
				else
				{
					[encoder setFragmentTexture:drawable_texture atIndex:0];
				}

				for (RenderChunk *render_chunk = render_pass->first_render_chunk;
				        render_chunk != 0; render_chunk = render_chunk->next)
				{
					U64 offset = render_chunk->start * sizeof(EffectsBox);
					if (render_chunk == render_pass->first_render_chunk)
					{
						[encoder setVertexBuffer:effects_box_buffer
						                  offset:offset
						                 atIndex:0];
					}
					else
					{
						[encoder setVertexBufferOffset:offset atIndex:0];
					}

					V2 scissor_rect_p0 = render_chunk->clip_origin;
					scissor_rect_p0.x =
					        Clamp(scissor_rect_p0.x, 0, viewport_size.x);
					scissor_rect_p0.y =
					        Clamp(scissor_rect_p0.y, 0, viewport_size.y);

					V2 scissor_rect_p1 = render_chunk->clip_origin;
					scissor_rect_p1.x += render_chunk->clip_size.x;
					scissor_rect_p1.y += render_chunk->clip_size.y;
					scissor_rect_p1.x =
					        Clamp(scissor_rect_p1.x, 0, viewport_size.x);
					scissor_rect_p1.y =
					        Clamp(scissor_rect_p1.y, 0, viewport_size.y);

					V2 scissor_rect_origin = scissor_rect_p0;
					V2 scissor_rect_size = {0};
					scissor_rect_size.x = scissor_rect_p1.x - scissor_rect_p0.x;
					scissor_rect_size.y = scissor_rect_p1.y - scissor_rect_p0.y;

					MTLScissorRect scissor_rect = {0};
					scissor_rect.x =
					        (U64)(scissor_rect_origin.x * scale_factor);
					scissor_rect.y =
					        (U64)(scissor_rect_origin.y * scale_factor);
					scissor_rect.width =
					        (U64)(scissor_rect_size.x * scale_factor);
					scissor_rect.height =
					        (U64)(scissor_rect_size.y * scale_factor);

					[encoder setScissorRect:scissor_rect];

					[encoder drawPrimitives:MTLPrimitiveTypeTriangle
					            vertexStart:0
					            vertexCount:6
					          instanceCount:render_chunk->count];
				}

				[encoder endEncoding];
			}
		}
		else
		{
			MTLRenderPassDescriptor *descriptor =
			        [MTLRenderPassDescriptor renderPassDescriptor];
			descriptor.colorAttachments[0].texture = drawable_texture;
			descriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
			descriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;

			id<MTLRenderCommandEncoder> encoder =
			        [command_buffer renderCommandEncoderWithDescriptor:descriptor];

			[encoder setRenderPipelineState:pipeline_state];

			[encoder setVertexBytes:&viewport_size_pixels
			                 length:sizeof(viewport_size_pixels)
			                atIndex:1];

			V2 glyph_atlas_size = {0};
			glyph_atlas_size.x = (F32)glyph_atlas.size.x;
			glyph_atlas_size.y = (F32)glyph_atlas.size.y;
			[encoder setVertexBytes:&glyph_atlas_size
			                 length:sizeof(glyph_atlas_size)
			                atIndex:2];

			[encoder setFragmentTexture:glyph_atlas.texture atIndex:0];

			for (RenderChunk *render_chunk = render_pass->first_render_chunk;
			        render_chunk != 0; render_chunk = render_chunk->next)
			{
				U64 offset = render_chunk->start * sizeof(Box);
				if (render_chunk == render_pass->first_render_chunk)
				{
					[encoder setVertexBuffer:box_buffer
					                  offset:offset
					                 atIndex:0];
				}
				else
				{
					[encoder setVertexBufferOffset:offset atIndex:0];
				}

				V2 scissor_rect_p0 = render_chunk->clip_origin;
				scissor_rect_p0.x = Clamp(scissor_rect_p0.x, 0, viewport_size.x);
				scissor_rect_p0.y = Clamp(scissor_rect_p0.y, 0, viewport_size.y);

				V2 scissor_rect_p1 = render_chunk->clip_origin;
				scissor_rect_p1.x += render_chunk->clip_size.x;
				scissor_rect_p1.y += render_chunk->clip_size.y;
				scissor_rect_p1.x = Clamp(scissor_rect_p1.x, 0, viewport_size.x);
				scissor_rect_p1.y = Clamp(scissor_rect_p1.y, 0, viewport_size.y);

				V2 scissor_rect_origin = scissor_rect_p0;
				V2 scissor_rect_size = {0};
				scissor_rect_size.x = scissor_rect_p1.x - scissor_rect_p0.x;
				scissor_rect_size.y = scissor_rect_p1.y - scissor_rect_p0.y;

				MTLScissorRect scissor_rect = {0};
				scissor_rect.x = (U64)(scissor_rect_origin.x * scale_factor);
				scissor_rect.y = (U64)(scissor_rect_origin.y * scale_factor);
				scissor_rect.width = (U64)(scissor_rect_size.x * scale_factor);
				scissor_rect.height = (U64)(scissor_rect_size.y * scale_factor);

				[encoder setScissorRect:scissor_rect];

				[encoder drawPrimitives:MTLPrimitiveTypeTriangle
				            vertexStart:0
				            vertexCount:6
				          instanceCount:render_chunk->count];
			}

			[encoder endEncoding];
		}
	}

	[command_buffer presentDrawable:drawable];
	[command_buffer commit];

	ArenaClear(frame_arena);
}

- (void)viewDidChangeBackingProperties
{
	[super viewDidChangeBackingProperties];

	F32 scale_factor = (F32)self.window.backingScaleFactor;

	GlyphAtlasInit(&glyph_atlas, permanent_arena, metal_layer.device, scale_factor);
	StateInit(frame_arena, &glyph_atlas);
	metal_layer.contentsScale = self.window.backingScaleFactor;
	CVDisplayLinkStart(display_link);

	[self updateOffscreenTexture];
}

- (void)setFrameSize:(NSSize)size
{
	[super setFrameSize:size];
	F32 scale_factor = (F32)self.window.backingScaleFactor;
	size.width *= scale_factor;
	size.height *= scale_factor;

	if (size.width == 0 && size.height == 0)
	{
		return;
	}

	metal_layer.drawableSize = size;

	[self updateOffscreenTexture];
}

- (void)updateOffscreenTexture
{
	F32 scale_factor = (F32)self.window.backingScaleFactor;
	U64 width = (U64)(self.frame.size.width * scale_factor);
	U64 height = (U64)(self.frame.size.height * scale_factor);

	MTLTextureDescriptor *descriptor = [[MTLTextureDescriptor alloc] init];
	descriptor.pixelFormat = metal_layer.pixelFormat;
	descriptor.width = width;
	descriptor.height = height;
	descriptor.storageMode = MTLStorageModePrivate;
	descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;

	offscreen_texture = [metal_layer.device newTextureWithDescriptor:descriptor];
}

function CVReturn
DisplayLinkCallback(CVDisplayLinkRef _display_link, const CVTimeStamp *in_now,
        const CVTimeStamp *in_output_time, CVOptionFlags flags_in, CVOptionFlags *flags_out,
        void *display_link_context)
{
	MainView *view = (__bridge MainView *)display_link_context;
	dispatch_sync(dispatch_get_main_queue(), ^{
	  [view.layer setNeedsDisplay];
	});
	return kCVReturnSuccess;
}

- (void)updateTrackingAreas
{
	NSTrackingAreaOptions options = NSTrackingActiveAlways | NSTrackingMouseMoved;
	[self addTrackingArea:[[NSTrackingArea alloc] initWithRect:self.bounds
	                                                   options:options
	                                                     owner:self
	                                                  userInfo:nil]];
}

- (void)mouseUp:(NSEvent *)event
{
	[self handleEvent:event];
}
- (void)mouseDown:(NSEvent *)event
{
	[self handleEvent:event];
}
- (void)mouseMoved:(NSEvent *)event
{
	[self handleEvent:event];
}
- (void)mouseDragged:(NSEvent *)event
{
	[self handleEvent:event];
}
- (void)scrollWheel:(NSEvent *)event
{
	[self handleEvent:event];
}

- (void)handleEvent:(NSEvent *)ns_event
{
	EventKind kind = 0;

	switch (ns_event.type)
	{
		default: return;

		case NSEventTypeLeftMouseUp:
		{
			kind = EventKind_MouseUp;
		}
		break;

		case NSEventTypeLeftMouseDown:
		{
			kind = EventKind_MouseDown;
		}
		break;

		case NSEventTypeMouseMoved:
		{
			kind = EventKind_MouseMoved;
		}
		break;

		case NSEventTypeLeftMouseDragged:
		{
			kind = EventKind_MouseDragged;
		}
		break;

		case NSEventTypeScrollWheel:
		{
			kind = EventKind_Scroll;
		}
		break;
	}

	NSPoint location_ns_point = ns_event.locationInWindow;
	location_ns_point.y = self.bounds.size.height - location_ns_point.y;
	V2 location = {0};
	location.x = (F32)location_ns_point.x;
	location.y = (F32)location_ns_point.y;

	Event *event = PushStruct(frame_arena, Event);
	event->kind = kind;
	event->location = location;

	if (kind == EventKind_Scroll)
	{
		event->scroll_distance.x = (F32)ns_event.scrollingDeltaX;
		event->scroll_distance.y = (F32)ns_event.scrollingDeltaY;
	}

	if (state->first_event == 0)
	{
		Assert(state->last_event == 0);
		state->first_event = event;
	}
	else
	{
		state->last_event->next = event;
	}
	state->last_event = event;
}

@end