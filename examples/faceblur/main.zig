const std = @import("std");
const cv = @import("zigcv");
const cv_c_api = cv.c_api;

pub fn main(init: std.process.Init.Minimal) anyerror!void {
    const allocator = std.heap.page_allocator;
    var args = try init.args.iterateAllocator(allocator);
    defer args.deinit();
    const prog = args.next();
    const device_id_char = args.next() orelse {
        std.log.err("usage: {s} [cameraID] [cascade.xml]", .{prog.?});
        std.process.exit(1);
    };
    const cascade_path: [:0]const u8 = args.next() orelse "zig-out/share/haarcascade_frontalface_default.xml";
    const device_id = try std.fmt.parseUnsigned(c_int, device_id_char, 10);

    // open webcam
    var webcam = try cv.VideoCapture.init();
    try webcam.openDevice(device_id);
    defer webcam.deinit();

    // open display window
    const window_name = "Face Detect";
    var window = cv.Window.init(allocator, window_name);
    defer window.deinit();

    // prepare image matrix
    var img = try cv.Mat.init();
    defer img.deinit();

    // load classifier to recognize faces
    var classifier = try cv.CascadeClassifier.init();
    defer classifier.deinit();

    classifier.load(cascade_path) catch {
        std.debug.print("can't load cascade: {s}\n", .{cascade_path});
        std.process.exit(1);
    };

    const size = cv.Size{ .width = 75, .height = 75 };
    while (true) {
        webcam.read(&img) catch {
            std.debug.print("capture failed", .{});
            std.process.exit(1);
        };
        if (img.isEmpty()) {
            continue;
        }
        var rects = try classifier.detectMultiScale(img, allocator);
        defer rects.deinit(allocator);
        const found_num = rects.items.len;
        std.debug.print("found {d} faces\n", .{found_num});
        for (rects.items) |r| {
            std.debug.print("x:\t{}, y:\t{}, w:\t{}, h:\t{}\n", .{ r.x, r.y, r.width, r.height });
            cv.gaussianBlur(img, &img, size, 0, 0, .{});
        }

        window.show(img) catch |err| switch (err) {
            error.WindowClosed => break,
            else => return err,
        };
        if (window.pollKey() != null) {
            break;
        }
    }
}
