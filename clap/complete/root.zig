const std = @import("std");
const clap = @import("../../clap.zig");
pub const fish = @import("fish.zig");

pub const Shell = enum { fish, zsh, bash };

/// Write a completion script for the given shell to `writer`.
pub fn generate(
    writer: *std.Io.Writer,
    comptime cmd_name: []const u8,
    comptime root_params: []const clap.Param(clap.Help),
    comptime subcommands: []const clap.SubcommandSpec,
    shell: Shell,
) !void {
    switch (shell) {
        .fish => try fish.generate(writer, cmd_name, root_params, subcommands),
        .zsh => return error.NotImplemented,
        .bash => return error.NotImplemented,
    }
}

/// Scans process args for `--generate-completion-script <shell>`. If found,
/// writes the completion script to stdout and returns `true`. Otherwise
/// returns `false` without side effects, so normal parsing can proceed.
pub fn generateIfRequested(
    init: std.process.Init,
    comptime cmd_name: []const u8,
    comptime root_params: []const clap.Param(clap.Help),
    comptime subcommands: []const clap.SubcommandSpec,
) !bool {
    var iter = try init.minimal.args.iterateAllocator(init.gpa);
    defer iter.deinit();
    _ = iter.next(); // skip exe

    while (iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "--generate-completion-script")) {
            const shell_name = iter.next() orelse {
                std.debug.print("--generate-completion-script requires a shell name (fish, zsh, bash)\n", .{});
                return error.MissingArgument;
            };
            const shell = std.meta.stringToEnum(Shell, shell_name) orelse {
                std.debug.print("Unknown shell '{s}'. Expected: fish, zsh, bash\n", .{shell_name});
                return error.InvalidArgument;
            };
            var buf: [8192]u8 = undefined;
            var writer = std.Io.File.stdout().writer(init.io, &buf);
            try generate(&writer.interface, cmd_name, root_params, subcommands, shell);
            try writer.interface.flush();
            return true;
        }
    }
    return false;
}

test {
    _ = fish;
}
