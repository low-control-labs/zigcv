const std = @import("std");
const cv = @import("zigcv");
const cv_c_api = cv.c_api;

pub fn main(init: std.process.Init) anyerror!void {
    var args = try init.minimal.args.iterateAllocator(std.heap.page_allocator);
    defer args.deinit();
    const prog = args.next();
    const img_PATH = args.next() orelse {
        std.log.err("usage: {s} [image_PATH]", .{prog.?});
        std.process.exit(1);
    };

    // open display window
    const window_name = "Show Image";
    var window = cv.Window.init(std.heap.page_allocator, window_name);
    defer window.deinit();

    var img = try cv.imRead(init.io, img_PATH, .unchanged);
    defer img.deinit();
    window.show(img) catch |err| switch (err) {
        error.WindowClosed => return,
        else => return err,
    };
    // Static image: just keep the window alive until a key press or close.
    _ = window.waitKey(0) catch |err| switch (err) {
        error.WindowClosed => return,
        else => return err,
    };
}
