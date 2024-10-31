const std = @import("std");
const net = std.net;
const posix = std.posix;

pub fn main() !void {
    var address = try net.Address.parseIp4("127.0.0.1", 8080);
    const listener = posix.socket(posix.AF.INET, posix.SOCK.STREAM, 0) catch |err| {
        std.debug.print("error created socket: {?}\n", .{err});
        return err;
    };
    defer posix.close(listener);

    try posix.setsockopt(listener, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));

    posix.bind(listener, @ptrCast(&address), address.getOsSockLen()) catch |err| {
        std.debug.print("failed to bind socket: {?}\n", .{err});
        return err;
    };
    posix.listen(listener, 10) catch |err| {
        std.debug.print("failed to listen socket: {?}\n", .{err});
        return err;
    };
    std.debug.print("server listening on {any}\n", .{address.in});

    var client_address: net.Address = undefined;
    var client_address_len: posix.socklen_t = @sizeOf(net.Address);

    while (true) {
        const conn = posix.accept(listener, @ptrCast(&client_address), &client_address_len, 0) catch |err| {
            std.debug.print("failed to accept connection: {?}\n", .{err});
            continue;
        };

        const thread = try std.Thread.spawn(.{}, handleConnection, .{conn});
        defer thread.join();
    }
}

fn handleConnection(conn: posix.socket_t) !void {
    std.debug.print("client connected\n", .{});
    var buf: [1024]u8 = undefined;
    const data_received = posix.recv(conn, &buf, 0) catch |err| {
        std.debug.print("error read message : {?} \n", .{err});
        return err;
    };
    var it = std.mem.splitScalar(u8, buf[0..data_received], '\n');
    const req = it.first();
    const header = readHeader(req);
    std.debug.print("method : {s}\npath : {s}\nproto version : {s}\n", .{ header.method, header.path, header.protoVersion });
}

fn readHeader(req_header: []const u8) Header {
    var it = std.mem.splitScalar(u8, req_header, ' ');
    const method = it.first();
    const path = it.next().?;
    const proto_version = it.next().?;

    return Header{
        .method = method,
        .path = path,
        .protoVersion = proto_version,
    };
}

const Header = struct {
    method: []const u8,
    path: []const u8,
    protoVersion: []const u8,
};

// i don't know how much the number of connections will be served.
// So,stores the heap in the stack is a bad idea.
// i need to allocate some memory :)
