const std = @import("std");

const Vec2D = @import("vector").Vec2D;
const KdTree = @import("kdTree").KdTree(Vec2D, 2);


pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const file_path = "../../MultipleSlowConstantRounds.csv";

    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    const buffer = reader.reader();

    var destination = std.ArrayList(Vec2D).init(allocator);
    var source = std.ArrayList(Vec2D).init(allocator);
    
    var sourceFound: bool = false;
    var destinationFound: bool = false;
    while (true) {
        const line = buffer.readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(usize)) catch break;
        defer allocator.free(line);

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

        var tokenizer = std.mem.tokenizeScalar(u8, line, ",");
        var val = tokenizer.next().?;
        const value1 = try std.fmt.parseFloat(f64, val);
        val = tokenizer.next().?;
        const value2 = try std.fmt.parseFloat(f64, val);

        if (destinationFound) {
            try destination.append(Vec2D.init(value1, value2));
        } else if (sourceFound) {
            try source.append(Vec2D.init(value1, value2));
        }
    }


    std.debug.print("len dest: {d}; len source: {d}\n", .{destination.items.len, source.items.len});
    const destinationKdTree = try KdTree.init(allocator, destination.items);
    const icp = try Icp.init(source, destinationKdTree, 5);
    std.debug.print("offset: {d}\n", .{icp.icp()});
    defer icp.deinit();
}


const Icp = struct {
    source: std.ArrayList(Vec2D),
    destination: KdTree,
    iterations: usize,

    const Self = @This();

    pub fn init(source: std.ArrayList(Vec2D), destination: KdTree, iterations: usize) !Self {
        return .{
            .source = source,
            .destination = destination,
            .iterations = iterations,
        };
    }

    pub fn icp(self: Self) f64 {
        var totalOffset: f64 = 0;
        for (0..self.iterations) |_| {
            var offsetSum: f64 = 0;
            for (self.source.items) |p| {
                const point = Vec2D.init(p.getX() + totalOffset, p.getY());
                const nn: Vec2D = self.destination.nearestNeighbor(point).?;
                offsetSum += nn.getX() - point.getX();
            }
            const floatLen: f64 = @floatFromInt(self.source.items.len);
            totalOffset += offsetSum / floatLen;
        }
        return totalOffset;
    }

    pub fn deinit(self: Self) void {
        self.source.deinit();
        self.destination.deinit();
    }
};
