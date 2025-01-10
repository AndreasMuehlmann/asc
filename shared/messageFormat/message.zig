pub const TestMessage = struct {
    x: f32,
    y: i32,
    z: u64,
};

pub const Orientation = struct {
    heading: f32,
    roll: f32,
    pitch: f32,
};

pub const MessageEnum = enum(u8) {
    testMessage,
    orientation,
};

pub const Message = union(MessageEnum) {
    testMessage: TestMessage,
    orientation: Orientation,
};
