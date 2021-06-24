const std = @import("std");

const sg    = @import("sokol").gfx;
const sgl   = @import("sokol").gl;
const sapp  = @import("sokol").app;
const sgapp = @import("sokol").app_gfx_glue;
const stm   = @import("sokol").time;
const chip8 = @import("chip8.zig");

const zoom = 12;
const speed_multiplier = 5;

const State = struct {
    pass_action: sg.PassAction = .{},
    img: sg.Image = .{},
    pip: sgl.Pipeline = .{}
};

var state: State = .{};

export fn init() void {
    sg.setup(.{
        .context = sgapp.context()
    });
    sgl.setup(.{
        .sample_count = sgapp.context().sample_count
    });
    stm.setup();

    state.pip = sgl.makePipeline(.{
        .cull_mode = sg.CullMode.BACK,
        .depth = .{
            .write_enabled = true,
            .compare = sg.CompareFunc.LESS_EQUAL
        }
    });

    state.pass_action.colors[0] = .{
        .action = sg.Action.CLEAR,
        .value = .{ .r=0.2, .g=0.71, .b=0.92, .a=1 }
    };
}

export fn frame() void {
    var i: u32 = 0;
    while(i < speed_multiplier) : (i += 1)
        chip8.update();

    sgl.viewport(0, 0, sapp.width(), sapp.height(), true);
    sgl.defaults();

    chip8.render();

    sg.beginDefaultPass(state.pass_action, sapp.width(), sapp.height());
    sgl.draw();
    sg.endPass();
    sg.commit();
}

export fn input(e: ?*const sapp.Event) void {
    const event = e.?;
    
}

export fn cleanup() void {
    sg.shutdown();
}

pub fn main() anyerror!void {
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .event_cb = input,
        .cleanup_cb = cleanup,
        .width = 64 * zoom,
        .height = 32 * zoom,
        .window_title = "chip8-zig"
    });
}
