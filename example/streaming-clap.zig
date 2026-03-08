// Param(Help) definitions used for completion generation and help output.
// The streaming parser below uses Param(u8) for dispatch, so we maintain
// both in parallel.
const help_params = [_]clap.Param(clap.Help){
    .{
        .id = .{ .desc = "Display this help and exit." },
        .names = .{ .short = 'h', .long = "help" },
    },
    .{
        .id = .{ .desc = "An option parameter, which takes a value.", .val = "usize" },
        .names = .{ .short = 'n', .long = "number" },
        .takes_value = .one,
    },
};

pub fn main(init: std.process.Init) !void {
    if (try clap.complete.generateIfRequested(init, "streaming-clap", &help_params, &.{})) {
        return;
    }

    const params = [_]clap.Param(u8){
        .{
            .id = 'h',
            .names = .{ .short = 'h', .long = "help" },
        },
        .{
            .id = 'n',
            .names = .{ .short = 'n', .long = "number" },
            .takes_value = .one,
        },
        .{ .id = 'f', .takes_value = .one },
    };

    var iter = try init.minimal.args.iterateAllocator(init.gpa);
    defer iter.deinit();

    _ = iter.next();

    var diag = clap.Diagnostic{};
    var parser = clap.streaming.Clap(u8, std.process.Args.Iterator){
        .params = &params,
        .iter = &iter,
        .diagnostic = &diag,
    };

    while (parser.next() catch |err| {
        try diag.reportToFile(init.io, .stderr(), err);
        return err;
    }) |arg| {
        switch (arg.param.id) {
            'h' => {
                return clap.helpToFile(init.io, .stderr(), clap.Help, &help_params, .{});
            },
            'n' => std.debug.print("--number = {s}\n", .{arg.value.?}),
            'f' => std.debug.print("{s}\n", .{arg.value.?}),
            else => unreachable,
        }
    }
}

const clap = @import("clap");
const std = @import("std");
