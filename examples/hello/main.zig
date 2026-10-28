const std = @import("std");
const cv = @import("zigcv");
const cv_c_api = cv.c_api;

pub fn main() anyerror!void {
    // open webcam
    var webcam = try cv.VideoCapture.init();
    try webcam.openDevice(0);
    defer webcam.deinit();

    // open display window
    const window_name = "Hello";
    var window = cv.Window.init(std.heap.page_allocator, window_name);
    defer window.deinit();

    var img = try cv.Mat.init();
    defer img.deinit();

    while (true) {
        webcam.read(&img) catch {
            std.debug.print("capture failed", .{});
            std.process.exit(1);
        };

        window.show(img) catch |err| switch (err) {
            error.WindowClosed => break,
            else => return err,
        };
        if (window.pollKey() != null) {
            break;
        }
    }
}
