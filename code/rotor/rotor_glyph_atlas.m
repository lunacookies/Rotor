const V2U64 glyph_atlas_padding = {2, 2};

function void
GlyphAtlasInit(GlyphAtlas *atlas, Arena *arena, id<MTLDevice> device, F32 scale_factor)
{
	atlas->size.x = (U64)CeilF32(1024 * scale_factor);
	atlas->size.y = (U64)CeilF32(1024 * scale_factor);
	atlas->scale_factor = scale_factor;

	atlas->pixels = PushArray(arena, U32, atlas->size.x * atlas->size.y);
	CGColorSpaceRef colorspace = CGColorSpaceCreateWithName(kCGColorSpaceLinearGray);
	atlas->context = CGBitmapContextCreate(atlas->pixels, atlas->size.x, atlas->size.y, 8,
	        atlas->size.x, colorspace, kCGImageAlphaOnly);
	CGContextScaleCTM(atlas->context, scale_factor, scale_factor);

	MTLTextureDescriptor *descriptor = [[MTLTextureDescriptor alloc] init];
	descriptor.width = atlas->size.x;
	descriptor.height = atlas->size.y;
	descriptor.pixelFormat = MTLPixelFormatR8Unorm;
	descriptor.storageMode = MTLStorageModeShared;
	atlas->texture = [device newTextureWithDescriptor:descriptor];

	atlas->slot_count = 1 << 16;
	atlas->slots = PushArray(arena, GlyphAtlasSlot, atlas->slot_count);
}

function void
GlyphAtlasAdd(
        GlyphAtlas *atlas, CTFontRef font, CGGlyph glyph, F32 subpixel_offset, GlyphAtlasSlot *slot)
{
	if (atlas->used_slot_count == atlas->slot_count)
	{
		return;
	}
	atlas->used_slot_count++;

	CGRect bounding_rect;
	CTFontGetBoundingRectsForGlyphs(font, kCTFontOrientationDefault, &glyph, &bounding_rect, 1);

	V2U64 glyph_size = {0};
	glyph_size.x = (U64)CeilF64(bounding_rect.size.width * atlas->scale_factor);
	glyph_size.y = (U64)CeilF64(bounding_rect.size.height * atlas->scale_factor);

	if (subpixel_offset > 0)
	{
		glyph_size.x += 1;
	}

	F64 glyph_baseline =
	        (bounding_rect.size.height + bounding_rect.origin.y) * atlas->scale_factor;

	U64 x_step = glyph_size.x + glyph_atlas_padding.x;

	U64 remaining_x_in_row = atlas->size.x - atlas->current_row.x;
	if (remaining_x_in_row < x_step)
	{
		U64 y_step = atlas->tallest_this_row + glyph_atlas_padding.y;
		atlas->current_row.y += y_step;
		atlas->tallest_this_row = 0;
		atlas->current_row.x = 0;
	}

	CFRetain(font);
	slot->font = font;
	slot->glyph = glyph;
	slot->origin = atlas->current_row;
	slot->size = glyph_size;
	slot->baseline = (U64)glyph_baseline;
	slot->subpixel_offset = subpixel_offset;

	CGPoint position = {0};
	position.x = (atlas->current_row.x + subpixel_offset -
	                     bounding_rect.origin.x * atlas->scale_factor) /
	             atlas->scale_factor;
	position.y =
	        (atlas->size.y - (atlas->current_row.y + glyph_baseline)) / atlas->scale_factor;

	CTFontDrawGlyphs(font, &glyph, &position, 1, atlas->context);

	atlas->current_row.x += x_step;
	atlas->tallest_this_row = Max(atlas->tallest_this_row, glyph_size.y);

	[atlas->texture replaceRegion:MTLRegionMake2D(0, 0, atlas->size.x, atlas->size.y)
	                  mipmapLevel:0
	                    withBytes:atlas->pixels
	                  bytesPerRow:atlas->size.x];
}

function GlyphAtlasSlot *
GlyphAtlasGet(GlyphAtlas *atlas, CTFontRef font, CGGlyph glyph, F32 subpixel_offset)
{
	U64 slot_count_mask = atlas->slot_count - 1;
	U64 slot_index = glyph & slot_count_mask;
	for (;;)
	{
		GlyphAtlasSlot *slot = atlas->slots + slot_index;

		if (slot->glyph == glyph && CFEqual(slot->font, font) &&
		        slot->subpixel_offset == subpixel_offset)
		{
			return slot;
		}

		if (slot->glyph == 0)
		{
			GlyphAtlasAdd(atlas, font, glyph, subpixel_offset, slot);
			return slot;
		}

		slot_index = (slot_index + 1) & slot_count_mask;
	}
}
