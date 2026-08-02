#scope_file

#import "String";

autoedit_scrolls : Table(u64, float);

loc_to_key :: (line: s32) -> string {
	log_debug("Creating key: %", line);
	return tprint("%", line);
}

Autoedit_Conf :: struct {
	Kind :: enum {
		COLOR;
		SLIDER;
		DEFAULT;
	}

	kind: Kind = .DEFAULT;

	min: string = "0";
	max: string = "100";
	step: string = "1";
}

note_to_autoedit_conf :: (notes: []string) -> Autoedit_Conf {
	if notes.count == 0 {
		return .{kind = .DEFAULT};
	}

	note := notes[0];
	note_parts := split(note,",");

	assert(note_parts.count > 0, "Note has to have a part");
	if note_parts[0] == "Slider" {
		assert(note_parts.count == 4, "Slider must have min, max and step.");
		return .{
			kind = .SLIDER,
			min = note_parts[1],
			max = note_parts[2],
			step = note_parts[3]
		};
	} else if note_parts[0] == "Color" {
		return .{kind = .COLOR};
	} else if note_parts[0] == "Input" {
		if note_parts.count == 1 {
			return .{
				kind = .DEFAULT
			};
		} else if note_parts.count == 3 {
			return .{
				kind = .DEFAULT,
				min = note_parts[1],
				max = note_parts[2]
			};
		}
		assert(false, "Input must have either 1 or 3 parts");
	}
	return .{};
} 

// Types we can generate an editor widget for. Anything else (nested structs,
// arrays, the '#as using base' of an entity, ...) is skipped entirely.
autoedit_supports_type :: (type: *Type_Info) -> bool {
	return type == type_info(float) || type == type_info(s32) || type == type_info(bool)
	    || type == type_info(Vector3) || type == type_info(string);
}

// Widgets that need a GetRect id get one per field. Two autoedit panels can be
// on screen at once (the world config and an entity's fields), so the id is
// namespaced by the caller's identifier to keep the two sets apart.
autoedit_widget_id :: (identifier: s32, field_index: int) -> s32 {
	return identifier * 1000 + cast(s32) field_index;
}

// A text input hands back a view into the widget's own buffer, so the value has
// to be copied out on every keystroke. The previous copy is freed only when this
// same helper allocated it and the field still points at it: a field's starting
// value is usually a literal from the struct definition, which must not be freed.
autoedit_owned_text : Table(*string, string);

autoedit_set_text :: (field: *string, text: string) -> string {
	found, previous := table_find(*autoedit_owned_text, field);
	if found && previous.data == field.data  free(previous);
	result := copy_string(text);
	table_set(*autoedit_owned_text, field, result);
	return result;
}

input_code_from_type_and_notes :: (name: string, type: *Type_Info, notes: []string, index: int) -> string {
	autoconf := note_to_autoedit_conf(notes);
    builder : String_Builder;
	// Each field resets the row height, so a field that wants a taller widget can
	// just set it and let the trailing advance pick it up.
	print_to_builder(*builder, "r.h = ui_h(4,0);\n");
	print_to_builder(*builder, "GR.label(r, \"%\", *t_label_left(theme));\n", name);
	print_to_builder(*builder, "r.y += r.h;\n");

	if type == type_info(bool) {
		print_to_builder(*builder, "if GR.button(r, ifx value.% then \"true\" else \"false\", *t_button_selectable(theme, value.%), autoedit_widget_id(identifier, %)) then value.% = !value.%;\n",
			name, name, index, name, name);
	} else if type == type_info(float) || type == type_info(s32) {
		if autoconf.kind == .SLIDER {
			print_to_builder(*builder, "GR.slider(r, *value.%, %, %, %, *theme.slider_theme);\n", name, autoconf.min, autoconf.max, autoconf.step);
		} else {
			print_to_builder(*builder, "GR.number_input(r, tprint(\"\%\", value.%), *value.%, %, %, *number_theme);\n", name, name, autoconf.min, autoconf.max);
		}
	} else if type == type_info(string) {
		// Roomier than the other widgets: text fields hold a sentence, not a number.
		print_to_builder(*builder, "r.h = ui_h(7,0);\n");
		print_to_builder(*builder, "{\n");
		print_to_builder(*builder, "action, _, text_state := GR.text_input(r, value.%, *theme.text_input_theme, autoedit_widget_id(identifier, %));\n", name, index);
		print_to_builder(*builder, "if (action & .TEXT_MODIFIED) || (action & .ENTERED)  value.% = autoedit_set_text(*value.%, text_state.text);\n", name, name);
		print_to_builder(*builder, "}\n");
	} else if type == type_info(Vector3) {
		if autoconf.kind == .DEFAULT {
			print_to_builder(*builder, "{\n");
			print_to_builder(*builder, "orig_w := r.w; orig_x := r.x; r.w = r.w / 3;\n");
			print_to_builder(*builder, "GR.number_input(r, tprint(\"\%\", value.%.x), *value.%.x, -100, 100, *number_theme);\n", name, name);
			print_to_builder(*builder, "r.x += r.w;\n");
			print_to_builder(*builder, "GR.number_input(r, tprint(\"\%\", value.%.y), *value.%.y, -100, 100, *number_theme);\n", name, name);
			print_to_builder(*builder, "r.x += r.w;\n");
			print_to_builder(*builder, "GR.number_input(r, tprint(\"\%\", value.%.z), *value.%.z, -100, 100, *number_theme);\n", name, name);
			print_to_builder(*builder, "r.w = orig_w; r.x = orig_x;\n");
			print_to_builder(*builder, "}\n");
		} else if autoconf.kind == .COLOR {
			print_to_builder(*builder, "if GR.button(r, \"Edit color\", *t_button_color(theme, .{value.%.x, value.%.y, value.%.z, 1.0}), autoedit_widget_id(identifier, %)) then cur_edit_color = *value.%;\n", name, name, name, index, name);
		}

	}
	print_to_builder(*builder, "r.y += r.h;\n");
	return builder_to_string(*builder);
}

cur_edit_color : *Vector3 = null;
color_edit_already_active : bool = false;
	
#scope_export
// Generates code automatically to edit a struct consisting of simple fields.
autoedit :: (rect: GR.Rect, value: *$T, theme: *GR.Overall_Theme, identifier: s32 = 0, loc := #caller_location) {
	hash := GR.get_hash(loc, identifier);
	scroll_val := find_or_add(*autoedit_scrolls, hash);

	number_theme : GR.Number_Input_Theme;
    generate_autoedit_code :: () -> string {
        builder : String_Builder;
        ti := type_info(T);
		#assert #run type_info(T).type == .STRUCT "Autoedit only works for structs";
        for ti.members {
			if it.flags & .CONSTANT continue;
			if it.flags & .USING    continue;  // e.g. an entity's Entity base
			if !autoedit_supports_type(it.type) continue;
			print_to_builder(*builder, "%\n", input_code_from_type_and_notes(it.name, it.type, it.notes, it_index));
        }
        return builder_to_string(*builder);
    }

	
    region, r := GR.begin_scrollable_region(rect, *theme.scrollable_region_theme);
	r.y -= scroll_val.*;
	r.h = ui_h(4,0);
	
	if !cur_edit_color {
	    #insert #run,stallable generate_autoedit_code();
		color_edit_already_active = false;
	} else {
		r.h = ui_h(50,0);
		applied, drag, state := GR.color_picker(r, cur_edit_color);

		if !color_edit_already_active {
			GR.set_original_and_current_color_rgb(state, cur_edit_color.*);
			color_edit_already_active = true;
		}
		
		if applied then cur_edit_color = null;
	}
	r.y += ui_h(8,0);
    GR.end_scrollable_region(region, r.x + r.w, r.y, scroll_val);
}
