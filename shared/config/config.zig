const std = @import("std");

pub const Config = struct {
    const Self = @This();

    maxPwm: f32,
    gyroBrakeMultiplier: f32,
    accelBrakeMultiplier: f32,
    iirFilterRiseCoefficient: f32,
    iirFilterFallCoefficient: f32,
    configAssumedVelocityMPerS: f32,
    pulsesPerRotation: f32,
    tireCircumferenceMm: f32,
    userDriveMaxPwm: f32,

    pub fn init() Self {
        return .{
            .maxPwm = 1000.0,
            .userDriveMaxPwm = 1000.0,
            .gyroBrakeMultiplier = 1.5,
            .accelBrakeMultiplier = 0.01,
            .iirFilterRiseCoefficient = 0.5,
            .iirFilterFallCoefficient = 0.01,
            .configAssumedVelocityMPerS = 1.0,
            .pulsesPerRotation = 5.0,
            .tireCircumferenceMm = 74.01,
        };
    }

    pub fn handleConfigCommands(self: *Self, configCommands: @typeInfo(configCommand()).@"struct".fields[0].type) void {
        const tagName = @tagName(configCommands);
        // TODO: send response for getters
        if (std.mem.eql(u8, "get ", tagName[0..3])) {
            return;
        }
        const typeInfo = @typeInfo(Config);
        inline for (typeInfo.@"struct".fields) |field| {
            const upperFirst: [1]u8 = comptime .{ std.ascii.toUpper(field.name[0]) };
            const setterName = "set" ++ upperFirst ++ field.name[1..];
            if (std.mem.eql(u8, tagName, setterName)) {
                @field(self, field.name) = @field(@field(configCommands, setterName), field.name);
                break;
            }
        }
    }
};

pub fn configCommand() type {
    const typeInfo = @typeInfo(Config).@"struct";

    var unionFields: [2 * typeInfo.fields.len]std.builtin.Type.UnionField = undefined;
    var enumFields: [2 * typeInfo.fields.len]std.builtin.Type.EnumField  = undefined;

    inline for (typeInfo.fields, 0..) |field, i| {
        const upperFirst: [1]u8 = .{ std.ascii.toUpper(field.name[0]) };
        const setterName = "set" ++ upperFirst ++ field.name[1..];
        const getterName = "get" ++ upperFirst ++ field.name[1..];

        const setterStruct = @Type(.{
            .@"struct" = .{
                .layout = .auto,
                .fields = &[_]std.builtin.Type.StructField{
                    .{
                        .name = field.name,
                        .type = field.type,
                        .default_value_ptr = null,
                        .is_comptime = false,
                        .alignment = @alignOf(field.type),
                    },
                },
                .decls = &[_]std.builtin.Type.Declaration{},
                .is_tuple = false,
            },
        });

        const getterStruct = @Type(.{
            .@"struct" = .{
                .layout = .auto,
                .fields = &[_]std.builtin.Type.StructField{
                    .{
                        .name = field.name,
                        .type = field.type,
                        .default_value_ptr = null,
                        .is_comptime = false,
                        .alignment = @alignOf(field.type),
                    },
                },
                .decls = &[_]std.builtin.Type.Declaration{},
                .is_tuple = false,
            },
        });

        enumFields[2 * i] = .{
            .name = setterName,
            .value = 2 * i,
        };

        enumFields[2 * i + 1] = .{
            .name = getterName,
            .value = 2 * i + 1,
        };

        unionFields[2 * i] = .{
            .name = setterName,
            .type = setterStruct,
            .alignment = @alignOf(setterStruct),
        };

        unionFields[2 * i + 1] = .{
            .name = getterName,
            .type = getterStruct,
            .alignment = @alignOf(getterStruct),
        };
    }

    const TagEnum = @Type(.{
        .@"enum" = .{
            .tag_type = u8,
            .fields = &enumFields,
            .decls = &.{},
            .is_exhaustive = true,
        },
    });

    const CommandsUnion = @Type(.{
        .@"union" = .{
            .layout = .auto,
            .tag_type = TagEnum,
            .fields = &unionFields,
            .decls = &.{},
        },
    });

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &[_]std.builtin.Type.StructField{
                .{
                    .name = "configCommands",
                    .type = CommandsUnion,
                    .default_value_ptr = null,
                    .is_comptime = false,
                    .alignment = @alignOf(CommandsUnion),
                },
            },
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}
