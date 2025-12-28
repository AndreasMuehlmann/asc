const std = @import("std");
const serverContract = @import("serverContract.zig");
const encode = @import("encode.zig");
const decode = @import("decode.zig");

const TestHandlerServerContract = struct {
    pub fn handleCommand(_: *TestHandlerServerContract, command: serverContract.command) !void {
        std.debug.print("speed: {d}\n", .{command.setSpeed.speed});
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    
    const allocator = gpa.allocator();
    const timestampU64: u64 = @intCast(std.time.nanoTimestamp());
    var rng = std.Random.DefaultPrng.init(timestampU64);

    const Encoder = encode.Encoder(serverContract.ServerContract);

    var handler: TestHandlerServerContract = .{};


    var decoder = decode.Decoder(serverContract.ServerContractEnum, serverContract.ServerContract, TestHandlerServerContract).init(allocator, &handler);

    var stream_buffer: [1024]u8 = undefined;
    var stream_len: usize = 0;
    const fill_target: usize = 800;

    while (true) {
        while (stream_len < fill_target) {
           const command: serverContract.command = serverContract.command{ .setSpeed = serverContract.setSpeed{
               .speed = (0 + 1.0) / 2.0,
           } };

            const encoded = try Encoder.encode(serverContract.command, command);
            @memcpy(stream_buffer[stream_len..stream_len + encoded.len], encoded);
            stream_len += encoded.len;
        }

        var offset: usize = 0;
        while (offset < stream_len) {
            const remaining = stream_len - offset;
            
            const chunk_size = @min(rng.random().intRangeLessThan(usize, 1, 128), remaining);
            const chunk = stream_buffer[offset .. offset + chunk_size];

            std.debug.print("chunk size: {d}\n", .{chunk_size});
            try decoder.decode(chunk);
            offset += chunk_size;
        }

        stream_len = 0;
    }
}
