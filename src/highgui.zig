const std = @import("std");
const fenster = @import("fenster");
const core = @import("core.zig");
const imgproc = @import("imgproc.zig");
const Mat = core.Mat;

/// Window shows Mats in a window via fenster (X11/Cocoa/GDI) instead of
/// highgui, which this OpenCV build has no GUI backend for (GTK/Qt are off).
/// The window opens on the first `show` with that frame's size; later frames
/// of a different size are resized to fit it. 1/3/4-channel Mats of any depth
/// are accepted; non-8-bit ones are scaled the way highgui's imshow scales them.
pub const Window = struct {
    allocator: std.mem.Allocator,
    title: [:0]const u8,
    // Heap-allocated: fenster keeps pointers to both (XImage -> buf, Cocoa view -> f).
    f: ?*fenster.struct_fenster = null,
    buf: []u32 = &.{},
    depth8: ?Mat = null,
    bgra: ?Mat = null,
    scaled: ?Mat = null,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, title: [:0]const u8) Self {
        return .{ .allocator = allocator, .title = title };
    }

    pub fn deinit(self: *Self) void {
        if (self.f) |f| {
            fenster.fenster_close(f);
            self.allocator.destroy(f);
        }
        self.allocator.free(self.buf);
        if (self.depth8) |*m| m.deinit();
        if (self.bgra) |*m| m.deinit();
        if (self.scaled) |*m| m.deinit();
        self.* = undefined;
    }

    /// Converts `img` (1, 3 or 4 channel, any depth, BGR order) into the window
    /// framebuffer and processes window events.
    pub fn show(self: *Self, img: Mat) !void {
        if (img.isEmpty()) return error.EmptyImage;
        const f = self.f orelse try self.open(img.cols(), img.rows());

        var src = img;

        // MatType packs depth in bits 0-2 and channel count in bits 3+ (core/mat.zig);
        // 0 is CV_8U. highgui's imshow scales other depths rather than reinterpreting
        // their bytes: 16/32-bit ints to the 8-bit range, float as normalized [0,1].
        const depth = @intFromEnum(src.getType()) & 0b111;
        if (depth != 0) {
            const target: Mat.MatType = switch (src.channels()) {
                1 => .cv8uc1,
                3 => .cv8uc3,
                4 => .cv8uc4,
                else => return error.UnsupportedChannels,
            };
            if (self.depth8 == null) self.depth8 = try Mat.init();
            switch (depth) {
                5, 6 => src.convertToWithParams(&self.depth8.?, target, 255, 0), // float
                else => src.convertToWithParams(&self.depth8.?, target, 255.0 / 65535.0, 0), // 16/32-bit int
            }
            src = self.depth8.?;
        }

        if (src.cols() != f.width or src.rows() != f.height) {
            if (self.scaled == null) self.scaled = try Mat.init();
            imgproc.resize(src, &self.scaled.?, core.Size.init(f.width, f.height), 0, 0, .{ .type = .linear });
            src = self.scaled.?;
        }

        if (self.bgra == null) self.bgra = try Mat.init();
        switch (src.channels()) {
            1 => imgproc.cvtColor(src, &self.bgra.?, .gray_to_bgra),
            3 => imgproc.cvtColor(src, &self.bgra.?, .bgr_to_bgra),
            4 => src.copyTo(&self.bgra.?),
            else => return error.UnsupportedChannels,
        }

        // BGRA bytes read as a little-endian u32 are 0xAARRGGBB, which is
        // fenster's 0xRRGGBB pixel format with an ignored top byte.
        const bytes = try self.bgra.?.dataPtr(u8);
        @memcpy(std.mem.sliceAsBytes(self.buf), bytes[0 .. self.buf.len * 4]);

        if (fenster.fenster_loop(f) < 0) return error.WindowClosed;
    }

    /// Returns the next key press since the last call, if any (non-blocking).
    /// Presses are queued by `show`/`waitKey`, so quick taps between frames aren't lost.
    /// Letters are reported uppercase, arrows are 17..20 (see fenster.h).
    pub fn pollKey(self: *Self) ?u8 {
        const f = self.f orelse return null;
        if (f.keyq_len == 0) return null;
        const len: usize = @intCast(f.keyq_len);
        const key = f.keyq[0];
        std.mem.copyForwards(c_int, f.keyq[0 .. len - 1], f.keyq[1..len]);
        f.keyq_len -= 1;
        return @intCast(key);
    }

    /// Like highgui's waitKey: keeps the window responsive and waits up to
    /// `delay_ms` for a key press (forever if `delay_ms <= 0`).
    /// Returns null on timeout.
    pub fn waitKey(self: *Self, delay_ms: i32) !?u8 {
        const f = self.f orelse return error.WindowNotOpen;
        const deadline = fenster.fenster_time() + delay_ms;
        while (true) {
            if (self.pollKey()) |key| return key;
            if (delay_ms > 0 and fenster.fenster_time() >= deadline) return null;
            // fenster_loop re-uploads the whole frame (XPutImage), so don't spin at 1ms.
            fenster.fenster_sleep(@min(10, if (delay_ms > 0) delay_ms else 10));
            if (fenster.fenster_loop(f) < 0) return error.WindowClosed;
        }
    }

    /// Whether `key` is held down right now.
    pub fn isKeyDown(self: Self, key: u8) bool {
        const f = self.f orelse return false;
        return key < 128 and f.keys[key] != 0;
    }

    pub const Mouse = struct {
        x: i32,
        y: i32,
        left_down: bool,
    };

    /// Mouse position in window pixels and left button state.
    pub fn mouse(self: Self) ?Mouse {
        const f = self.f orelse return null;
        return .{ .x = f.x, .y = f.y, .left_down = f.mouse != 0 };
    }

    /// `title` must outlive the Window if the window isn't open yet
    /// (it's used when the window opens); an open window copies it.
    pub fn setTitle(self: *Self, title: [:0]const u8) void {
        self.title = title;
        if (self.f) |f| {
            f.title = title.ptr;
            fenster.fenster_set_title(f, title.ptr);
        }
    }

    /// Resizes the window to `width`x`height`. fenster's window size is fixed per
    /// instance, so this closes and reopens it (losing key/mouse state); frames are
    /// then scaled to fit the new size, same as any size mismatch in `show`.
    /// No-op if the window isn't open yet; use `show` to pick the initial size.
    pub fn resize(self: *Self, width: i32, height: i32) !void {
        const old = self.f orelse return;
        fenster.fenster_close(old);
        self.allocator.destroy(old);
        self.f = null;
        self.allocator.free(self.buf);
        self.buf = &.{};
        _ = try self.open(width, height);
    }

    fn open(self: *Self, width: i32, height: i32) !*fenster.struct_fenster {
        const n = @as(usize, @intCast(width)) * @as(usize, @intCast(height));
        self.buf = try self.allocator.alloc(u32, n);
        @memset(self.buf, 0);

        const f = try self.allocator.create(fenster.struct_fenster);
        f.* = std.mem.zeroes(fenster.struct_fenster);
        f.title = self.title.ptr;
        f.width = width;
        f.height = height;
        f.buf = self.buf.ptr;
        if (fenster.fenster_open(f) != 0) {
            self.allocator.destroy(f);
            return error.WindowOpenFailed;
        }
        self.f = f;
        return f;
    }
};
