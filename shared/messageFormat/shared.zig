pub const MAX_MESSAGE_LENGTH = 1000;
pub const TERMINATION_BYTE = 0xAA;

pub const MessageFormatError = error{
    MessageToLong,
    ListTooLong,
    WrongTerminationByte,
};

fn calculateParityByte(buffer: []u8) u8 {
    var parity: u8 = 0;
    for (buffer) |element| {
        parity = (parity + (element % 2)) % 256;
    }
}
