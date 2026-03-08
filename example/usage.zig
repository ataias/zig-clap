pub fn main(init: std.process.Init) !void {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help         Display this help and exit.
        \\-v, --version      Output version information and exit.
        \\    --value <str>  An option parameter, which takes a value.
        \\
    );

    if (try clap.complete.generateIfRequested(init, "usage", &params, &.{})) {
        return;
    }

    var res = try clap.parse(clap.Help, &params, clap.parsers.default, init.minimal.args, .{ .allocator = init.gpa });
    defer res.deinit();

    if (res.args.help != 0) {
        return clap.usageToFile(init.io, .stdout(), clap.Help, &params);
    }

    if (res.args.version != 0) {
        var buf: [4096]u8 = undefined;
        var writer = std.Io.File.stdout().writer(init.io, &buf);
        try writer.interface.print("usage v0.1.0\n", .{});
        try writer.interface.flush();
        return;
    }

    if (res.args.value) |v| {
        std.debug.print("--value = {s}\n", .{v});
    }
}

const clap = @import("clap");
const std = @import("std");
