const clap = @import("clap");
const std = @import("std");

const help_param = clap.Param(clap.Help){
    .id = .{ .desc = "Display this help and exit." },
    .names = .{ .short = 'h', .long = "help" },
    .takes_value = .none,
};

const root_params = [_]clap.Param(clap.Help){
    help_param,
    .{
        .id = .{ .desc = "Enable verbose output." },
        .names = .{ .short = 'v', .long = "verbose" },
        .takes_value = .none,
    },
};

const up_params = [_]clap.Param(clap.Help){
    help_param,
    .{
        .id = .{ .desc = "Path to workspace", .val = "str" },
        .names = .{ .long = "workspace-folder" },
        .takes_value = .one,
        .completion = .dir_path,
    },
};

const exec_params = [_]clap.Param(clap.Help){
    help_param,
    .{
        .id = .{ .desc = "Path to workspace", .val = "str" },
        .names = .{ .long = "workspace-folder" },
        .takes_value = .one,
        .completion = .dir_path,
    },
    .{
        .id = .{ .desc = "Environment variable (KEY=VAL)", .val = "str" },
        .names = .{ .long = "remote-env" },
        .takes_value = .many,
        .completion = .none_opaque,
    },
};

const subcommand_specs = [_]clap.SubcommandSpec{
    .{
        .name = "up",
        .description = "Start a dev container",
        .params = &up_params,
    },
    .{
        .name = "exec",
        .description = "Execute inside container",
        .params = &exec_params,
        .allow_passthrough = true,
    },
};

const Parser = clap.SubcommandParser(&root_params, &subcommand_specs);

pub fn main(init: std.process.Init) !void {
    if (try clap.complete.generateIfRequested(init, "complete-demo", &root_params, &subcommand_specs)) {
        return;
    }

    var diag = clap.Diagnostic{};
    var res = Parser.parse(init.minimal.args, .{
        .diagnostic = &diag,
        .allocator = init.gpa,
    }) catch |err| {
        if (err == error.MissingSubcommand) {
            return clap.helpWithSubcommandsToFile(init.io, .stderr(), clap.Help, &root_params, &subcommand_specs, .{});
        }
        try diag.reportToFile(init.io, .stderr(), err);
        return err;
    };
    defer res.deinit();

    switch (res.sub) {
        .none => {
            return clap.helpWithSubcommandsToFile(init.io, .stdout(), clap.Help, &root_params, &subcommand_specs, .{});
        },
        .up => |up| {
            if (up.args.help != 0) {
                return clap.helpForSubcommandToFile(init.io, .stdout(), "complete-demo", subcommand_specs[0], .{});
            }
            std.debug.print("up: workspace={s}\n", .{up.args.@"workspace-folder" orelse "(default)"});
        },
        .exec => |exec| {
            if (exec.args.help != 0) {
                return clap.helpForSubcommandToFile(init.io, .stdout(), "complete-demo", subcommand_specs[1], .{});
            }
            std.debug.print("exec: workspace={s}\n", .{exec.args.@"workspace-folder" orelse "(default)"});
        },
    }
}
