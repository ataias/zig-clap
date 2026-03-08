const std = @import("std");
const clap = @import("../../clap.zig");

/// Write fish completion directives for the given command.
pub fn generate(
    writer: *std.Io.Writer,
    comptime cmd_name: []const u8,
    comptime root_params: []const clap.Param(clap.Help),
    comptime subcommands: []const clap.SubcommandSpec,
) !void {
    if (subcommands.len > 0) {
        // Root-level flags: only shown when no subcommand has been typed yet
        try writeParams(writer, cmd_name, root_params, "__fish_use_subcommand");

        // Subcommand name completions
        for (subcommands) |spec| {
            try writer.print(
                "complete -c {s} -n '__fish_use_subcommand' -f -a {s} -d '{s}'\n",
                .{ cmd_name, spec.name, spec.description },
            );
        }

        // Per-subcommand flags
        inline for (subcommands) |spec| {
            try writeParams(writer, cmd_name, spec.params, "__fish_seen_subcommand_from " ++ spec.name);
        }
    } else {
        // No subcommands: all flags are root-level
        try writeParams(writer, cmd_name, root_params, null);
    }
}

fn writeParams(
    writer: *std.Io.Writer,
    comptime cmd_name: []const u8,
    comptime params: []const clap.Param(clap.Help),
    comptime condition: ?[]const u8,
) !void {
    for (params) |param| {
        const longest = param.names.longest();
        if (longest.kind == .positional) continue;

        try writer.print("complete -c {s}", .{cmd_name});

        if (condition) |cond| {
            try writer.print(" -n '{s}'", .{cond});
        }

        if (param.names.short) |short| {
            try writer.print(" -s {c}", .{short});
        }
        if (param.names.long) |long| {
            try writer.print(" -l {s}", .{long});
        }

        if (param.takes_value != .none) {
            try writer.print(" -r", .{});
        } else {
            try writer.print(" -f", .{});
        }

        const desc = param.id.description();
        if (desc.len > 0) {
            try writer.print(" -d '{s}'", .{desc});
        }

        try writeCompletionHint(writer, param.completion);

        try writer.print("\n", .{});
    }
}

/// Maps a `CompletionHint` to the corresponding fish `complete` flag:
///
///   .file_path   => `-F`            (fish built-in: complete with files)
///   .dir_path    => `-a '(...)'`    (calls `__fish_complete_directories`)
///   .executable  => `-a '(...)'`    (calls `__fish_complete_command`)
///   .values      => `-a 'v1 v2'`    (space-separated literal list)
///   .from_command      => `-a '(cmd)'`    (shell command whose stdout lines become candidates)
///   .none / .none_opaque => nothing (use fish's default or suppress completion)
fn writeCompletionHint(writer: *std.Io.Writer, hint: clap.CompletionHint) !void {
    switch (hint) {
        .none, .none_opaque => {},
        .file_path => try writer.print(" -F", .{}),
        .dir_path => try writer.print(" -a '(__fish_complete_directories)'", .{}),
        .executable => try writer.print(" -a '(__fish_complete_command)'", .{}),
        .values => |vals| {
            try writer.print(" -a '", .{});
            for (vals, 0..) |val, i| {
                if (i > 0) try writer.print(" ", .{});
                try writer.print("{s}", .{val});
            }
            try writer.print("'", .{});
        },
        .from_command => |cmd| try writer.print(" -a '({s})'", .{cmd}),
    }
}

test "fish: root flags only, no subcommands" {
    const params = [_]clap.Param(clap.Help){
        .{
            .id = .{ .desc = "Display this help and exit." },
            .names = .{ .short = 'h', .long = "help" },
            .takes_value = .none,
        },
        .{
            .id = .{ .desc = "Output directory" },
            .names = .{ .short = 'o', .long = "output" },
            .takes_value = .one,
            .completion = .dir_path,
        },
        .{
            .id = .{ .desc = "Output format" },
            .names = .{ .short = 'f', .long = "format" },
            .takes_value = .one,
            .completion = .{ .values = &.{ "json", "text" } },
        },
    };

    var buf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);

    try generate(&writer, "simple", &params, &.{});

    const expected =
        \\complete -c simple -s h -l help -f -d 'Display this help and exit.'
        \\complete -c simple -s o -l output -r -d 'Output directory' -a '(__fish_complete_directories)'
        \\complete -c simple -s f -l format -r -d 'Output format' -a 'json text'
        \\
    ;

    try std.testing.expectEqualStrings(expected, writer.buffered());
}

test "fish: all completion hint types" {
    const params = [_]clap.Param(clap.Help){
        .{
            .id = .{ .desc = "Input file" },
            .names = .{ .short = 'i', .long = "input" },
            .takes_value = .one,
            .completion = .file_path,
        },
        .{
            .id = .{ .desc = "Shell to use" },
            .names = .{ .long = "shell" },
            .takes_value = .one,
            .completion = .executable,
        },
        .{
            .id = .{ .desc = "Container name" },
            .names = .{ .long = "name" },
            .takes_value = .one,
            .completion = .{ .from_command = "docker ps --format '{{.Names}}'" },
        },
    };

    var buf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);

    try generate(&writer, "tool", &params, &.{});

    const expected =
        \\complete -c tool -s i -l input -r -d 'Input file' -F
        \\complete -c tool -l shell -r -d 'Shell to use' -a '(__fish_complete_command)'
        \\complete -c tool -l name -r -d 'Container name' -a '(docker ps --format '{{.Names}}')'
        \\
    ;

    try std.testing.expectEqualStrings(expected, writer.buffered());
}

test "fish: with subcommands" {
    const root_params = [_]clap.Param(clap.Help){
        .{
            .id = .{ .desc = "Display this help and exit." },
            .names = .{ .short = 'h', .long = "help" },
            .takes_value = .none,
        },
    };

    const add_params = [_]clap.Param(clap.Help){
        .{
            .id = .{ .desc = "Name of the item" },
            .names = .{ .short = 'n', .long = "name" },
            .takes_value = .one,
        },
        .{
            .id = .{ .desc = "Force add" },
            .names = .{ .short = 'f', .long = "force" },
            .takes_value = .none,
        },
    };

    const remove_params = [_]clap.Param(clap.Help){
        .{
            .id = .{ .desc = "Force removal" },
            .names = .{ .short = 'f', .long = "force" },
            .takes_value = .none,
        },
    };

    const subcommands = [_]clap.SubcommandSpec{
        .{
            .name = "add",
            .description = "Add items",
            .params = &add_params,
        },
        .{
            .name = "remove",
            .description = "Remove items",
            .params = &remove_params,
        },
    };

    var buf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);

    try generate(&writer, "mycli", &root_params, &subcommands);

    const expected =
        \\complete -c mycli -n '__fish_use_subcommand' -s h -l help -f -d 'Display this help and exit.'
        \\complete -c mycli -n '__fish_use_subcommand' -f -a add -d 'Add items'
        \\complete -c mycli -n '__fish_use_subcommand' -f -a remove -d 'Remove items'
        \\complete -c mycli -n '__fish_seen_subcommand_from add' -s n -l name -r -d 'Name of the item'
        \\complete -c mycli -n '__fish_seen_subcommand_from add' -s f -l force -f -d 'Force add'
        \\complete -c mycli -n '__fish_seen_subcommand_from remove' -s f -l force -f -d 'Force removal'
        \\
    ;

    try std.testing.expectEqualStrings(expected, writer.buffered());
}
