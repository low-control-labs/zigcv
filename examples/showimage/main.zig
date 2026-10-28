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
    var window = try cv.Window.init(window_name);
    defer window.deinit();

    var img = try cv.imRead(init.io, img_PATH, .unchanged);
    defer img.deinit();
    while (true) {
        window.imShow(img);
        if (window.waitKey(1) >= 0) {
            break;
        }
    }
}
