#scope_file

#import "String";

autoedit_scrolls : Table(u64, float);

loc_to_key :: (line: s32) -> string {
	print("Creating key: %\n", line);
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

input_code_from_type_and_notes :: (name: string, type: *Type_Info, notes: []string) -> string {
	autoconf := note_to_autoedit_conf(notes);
    builder : String_Builder;
	print_to_builder(*builder, "GR.label(r, \"%\", *t_label_left(theme));\n", name);
	print_to_builder(*builder, "r.y += r.h;\n");
	
	if type == type_info(float) || type == type_info(s32) {
		if autoconf.kind == .SLIDER {
			print_to_builder(*builder, "GR.slider(r, *value.%, %, %, %, *theme.slider_theme);\n", name, autoconf.min, autoconf.max, autoconf.step);
		} else {
			print_to_builder(*builder, "GR.number_input(r, tprint(\"\%\", value.%), *value.%, %, %, *number_theme);\n", name, name, autoconf.min, autoconf.max);
		}
	} else if type == type_info(Vector3) {
		if autoconf.kind == .DEFAULT {
			print_to_builder(*builder, "{\n");
			print_to_builder(*builder, "orig_w := r.w; orig_x := r.x; r.w = r.w / 3;\n");
			print_to_builder(*builder, "GR.number_input(r, tprint(\"\%\", value.%.x), *value.%.x, 0, 100, *number_theme);\n", name, name);
			print_to_builder(*builder, "r.x += r.w;\n");
			print_to_builder(*builder, "GR.number_input(r, tprint(\"\%\", value.%.y), *value.%.y, 0, 100, *number_theme);\n", name, name);
			print_to_builder(*builder, "r.x += r.w;\n");
			print_to_builder(*builder, "GR.number_input(r, tprint(\"\%\", value.%.z), *value.%.z, 0, 100, *number_theme);\n", name, name);
			print_to_builder(*builder, "r.w = orig_w; r.x = orig_x;\n");
			print_to_builder(*builder, "}\n");
		} else if autoconf.kind == .COLOR {
			print_to_builder(*builder, "if GR.button(r, \"Edit color\", *t_button_color(theme, .{value.%.x, value.%.y, value.%.z, 1.0})) then cur_edit_color = *value.%;\n", name, name, name, name);
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
			print_to_builder(*builder, "%\n", input_code_from_type_and_notes(it.name, it.type, it.notes));
        }
        return builder_to_string(*builder);
    }

	
    region, r := GR.begin_scrollable_region(rect, *theme.scrollable_region_theme);
	r.y -= scroll_val.*;
	r.h = ui_h(4,0);
	
	if !cur_edit_color {
	    #insert #run generate_autoedit_code();
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
