pub fn main(init: std.process.Init) !void {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help     Display this help and exit.
        \\-v, --version  Output version information and exit.
        \\
    );

    if (try clap.complete.generateIfRequested(init, "help", &params, &.{})) {
        return;
    }

    var res = try clap.parse(clap.Help, &params, clap.parsers.default, init.minimal.args, .{ .allocator = init.gpa });
    defer res.deinit();

    // `clap.help` is a function that can print a simple help message. It can print any `Param`
    // where `Id` has a `description` and `value` method (`Param(Help)` is one such parameter).
    // The last argument contains options as to how `help` should print those parameters. Using
    // `.{}` means the default options.
    if (res.args.help != 0) {
        return clap.helpToFile(init.io, .stderr(), clap.Help, &params, .{});
    }

    if (res.args.version != 0) {
        var buf: [4096]u8 = undefined;
        var writer = std.Io.File.stdout().writer(init.io, &buf);
        try writer.interface.print("help v0.1.0\n", .{});
        try writer.interface.flush();
        return;
    }
}

const clap = @import("clap");
const std = @import("std");
