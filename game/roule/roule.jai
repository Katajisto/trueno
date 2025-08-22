// #scope_file

random :: #import "Random";

Color :: enum {
    RED;
    BLACK;
    GREEN;
};

RouleMode :: enum {
    WAITING;
    ANIMATING;
    DONE;
};

Slot :: struct {
    color  : Color;
    number : int;
};

RouleTable :: struct {
    animStart : float = -1;
    angle     : float = 0;
    slot      : Slot  = .{};
    mode      : RouleMode = .WAITING;
};

tableState : RouleTable;



rouleSlots : []Slot = .[
    .{.GREEN, 0},
    .{.RED, 32},
    .{.BLACK, 15},
    .{.RED, 19},
    .{.BLACK, 4},
    .{.RED, 21},
    .{.BLACK, 2},
    .{.RED, 25},
    .{.BLACK, 17},
    .{.RED, 34},
    .{.BLACK, 6},
    .{.RED, 27},
    .{.BLACK, 13},
    .{.RED, 36},
    .{.BLACK, 11},
    .{.RED, 30},
    .{.BLACK, 8},
    .{.RED, 23},
    .{.BLACK, 10},
    .{.RED, 5},
    .{.BLACK, 24},
    .{.RED, 16},
    .{.BLACK, 33},
    .{.RED, 1},
    .{.BLACK, 20},
    .{.RED, 14},
    .{.BLACK, 31},
    .{.RED, 9},
    .{.BLACK, 22},
    .{.RED, 18},
    .{.BLACK, 29},
    .{.RED, 7},
    .{.BLACK, 28},
    .{.RED, 12},
    .{.BLACK, 35},
    .{.RED, 3},
    .{.BLACK, 26},
];

get_roll_result :: () -> (Slot, float) {
    slot := random.random_get() % rouleSlots.count.(u64);
    return rouleSlots[xx slot], slot.(float) / rouleSlots.count.(float);
}

wheel_tex : Ui_Texture;
base_tex  : Ui_Texture;
ball_tex  : Ui_Texture;

WHEEL_SIZE :: 3.5;

get_ball :: () -> (ball_size: float, ball_speed: float) {
    if tableState.mode == .WAITING {
        return 4.7, -20;
    } else if tableState.mode == .ANIMATING {
        return lerp(4.7, 3, min(1.0, get_time().(float) - tableState.animStart.(float))), -20;
    }
}

#scope_export

table_roll :: () {
    tableState.animStart = get_time().(float);
    tableState.slot, tableState.angle = get_roll_result();
    tableState.mode = .ANIMATING;
}

table_init :: () {
    img := create_texture_from_pack("./game/resources/roule-spin.png");
    wheel_tex.tex = img;
    img = create_texture_from_pack("./game/resources/roule.png");
    base_tex.tex = img;
    img = create_texture_from_pack("./game/resources/roule-ball.png");
    ball_tex.tex = img;
}

draw_table :: () {
    w,h := get_window_size();
    uw := ui_w(10,0);

    ball_size, ball_speed := get_ball();

    diff := ball_size * uw - WHEEL_SIZE * uw;
    set_shader_for_images(*base_tex);
    immediate_rect((5-(WHEEL_SIZE/2)) * uw, 50,WHEEL_SIZE*uw,WHEEL_SIZE*uw);
    immediate_flush();
    set_shader_for_images(*wheel_tex);
    immediate_rect((5-(WHEEL_SIZE/2)) * uw, 50,WHEEL_SIZE*uw,WHEEL_SIZE*uw, cast(float) get_time());
    immediate_flush();
    set_shader_for_images(*ball_tex);
    immediate_rect((5-(ball_size/2)) * uw, 50 - diff/2 ,ball_size*uw,ball_size*uw, cast(float) (ball_size * -1 * get_time()));
    immediate_flush();
}
