const main_params = clap.parseParamsComptime(
    \\-h, --help  Display this help and exit.
    \\
);

const math_params = clap.parseParamsComptime(
    \\-h, --help  Display this help and exit.
    \\-a, --add   Add the two numbers
    \\-s, --sub   Subtract the two numbers
    \\<isize>
    \\<isize>
    \\
);

const subcommand_specs = [_]clap.SubcommandSpec{
    .{
        .name = "math",
        .description = "Perform arithmetic on two numbers",
        .params = &math_params,
    },
};

const Parser = clap.SubcommandParser(&main_params, &subcommand_specs);

pub fn main(init: std.process.Init) !void {
    if (try clap.complete.generateIfRequested(init, "subcommands", &main_params, &subcommand_specs)) {
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

    switch (res.sub) {
        .none => {
            return clap.helpWithSubcommandsToFile(init.io, .stderr(), clap.Help, &main_params, &subcommand_specs, .{});
        },
        .math => |math| {
            if (math.args.help != 0) {
                return clap.helpForSubcommandToFile(init.io, .stderr(), "subcommands", subcommand_specs[0], .{});
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
