const std = @import("std");

const Vec2D = @import("vector").Vec2D;
const KdTree = @import("kdTree").KdTree(Vec2D, 2);
const Icp = @import("icp.zig").Icp(Vec2D);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("../../MultipleSlowConstantRounds.csv", .{});
    defer file.close();

    var file_buffer: [4096]u8 = undefined;
    var reader = file.reader(&file_buffer);

    var destination = try std.ArrayList(Vec2D).initCapacity(allocator, 1000);
    var source = try std.ArrayList(Vec2D).initCapacity(allocator, 1000);
    
    var sourceFound: bool = false;
    var destinationFound: bool = false;
    while (try reader.interface.takeDelimiter('\n')) |line| {
        if (std.mem.eql(u8, line, "source")) {
            sourceFound = true; 
            continue;
        }
        if (std.mem.eql(u8, line, "destination")) {
            destinationFound = true; 
            continue;
        }
        if (std.mem.eql(u8, line, "end")) {
            break;
        }

        if (!sourceFound and !destinationFound) {
            continue;
        }

        var tokenizer = std.mem.tokenizeScalar(u8, line, ',');
        var val = tokenizer.next().?;
        const value1 = try std.fmt.parseFloat(f64, val);
        val = tokenizer.next().?;
        const value2 = try std.fmt.parseFloat(f64, val);

        if (destinationFound) {
            try destination.append(allocator, Vec2D.init(value1, value2));
        } else if (sourceFound) {
            try source.append(allocator, Vec2D.init(value1, value2));
        }
    }


    std.debug.print("len dest: {d}; len source: {d}\n", .{destination.items.len, source.items.len});
    const destinationKdTree = try KdTree.init(allocator, destination.items);
    const icp = try Icp.init(source.items, &destinationKdTree, 5);
    std.debug.print("offset: {d}\n", .{icp.icp()});
}


