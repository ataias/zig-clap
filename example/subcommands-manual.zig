const main_params = [_]clap.Param(clap.Help){
    .{
        .id = .{ .desc = "Display this help and exit." },
        .names = .{ .short = 'h', .long = "help" },
    },
};

const math_params = [_]clap.Param(clap.Help){
    .{
        .id = .{ .desc = "Display this help and exit." },
        .names = .{ .short = 'h', .long = "help" },
    },
    .{
        .id = .{ .desc = "Add the two numbers" },
        .names = .{ .short = 'a', .long = "add" },
    },
    .{
        .id = .{ .desc = "Subtract the two numbers" },
        .names = .{ .short = 's', .long = "sub" },
    },
    .{
        .id = .{ .val = "isize" },
        .takes_value = .one,
    },
    .{
        .id = .{ .val = "isize" },
        .takes_value = .one,
    },
};

const subcommand_specs = [_]clap.SubcommandSpec{
    .{
        .name = "math",
        .description = "Perform arithmetic on two numbers",
        .params = &math_params,
    },
};

const Parser = clap.SubcommandParser(&main_params, &subcommand_specs);

pub fn main(init: std.process.Init) !void {
    if (try clap.complete.generateIfRequested(init, "subcommands-manual", &main_params, &subcommand_specs)) {
        return;
    }

    var diag = clap.Diagnostic{};
    var res = Parser.parse(init.minimal.args, .{
        .diagnostic = &diag,
        .allocator = init.gpa,
    }) catch |err| {
        if (err == error.MissingSubcommand) {
            return clap.helpWithSubcommandsToFile(init.io, .stderr(), clap.Help, &main_params, &subcommand_specs, .{});
        }
        try diag.reportToFile(init.io, .stderr(), err);
        return err;
    };
    defer res.deinit();

    if (res.root_args.help != 0) {
        return clap.helpWithSubcommandsToFile(init.io, .stderr(), clap.Help, &main_params, &subcommand_specs, .{});
    }

    switch (res.sub) {
        .math => |math| {
            if (math.args.help != 0) {
                return clap.helpForSubcommandToFile(init.io, .stderr(), "subcommands-manual", subcommand_specs[0], .{});
            }

            const a = math.positionals[0];
            const b = math.positionals[1];
            if (math.args.add != 0) {
                std.debug.print("added: {}\n", .{a + b});
            }
            if (math.args.sub != 0) {
                std.debug.print("subtracted: {}\n", .{a - b});
            }
        },
    }
}

const clap = @import("clap");
const std = @import("std");
