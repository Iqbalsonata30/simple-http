const std = @import("std");
const net = std.net;
const posix = std.posix;
const Allocator = std.mem.Allocator;

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

        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();

        const allocator = arena.allocator();

        const thread = try std.Thread.spawn(.{}, handleConnection, .{ conn, allocator });
        defer thread.join();
    }
}

fn handleConnection(conn: posix.socket_t, allocator: Allocator) !void {
    std.debug.print("client connected\n", .{});
    var buf: [1024]u8 = undefined;
    const response = "<h1>Hi, Your method is GET and Path /</h1>";

    const response_get = try std.fmt.allocPrint(allocator, "HTTP/1.1 200 OK\r\n" ++
        "Content-Type: text/html\r\n" ++
        "Content-Length: {d}\r\n" ++
        "\r\n" ++
        "{s}", .{ response.len, response });
    defer allocator.free(response_get);

    const data_received = posix.recv(conn, &buf, 0) catch |err| {
        std.debug.print("error read message : {?} \n", .{err});
        return err;
    };
    var req = std.mem.splitScalar(u8, buf[0..data_received], '\n');
    const header = Header.parseHeader(req.first());
    const method = header.method;

    if (std.mem.eql(u8, method, "GET")) {
        _ = try posix.write(conn, response_get);
    }
}

const Header = struct {
    method: []const u8,
    path: []const u8,
    protocolVersion: []const u8,

    pub fn parseHeader(buf: []const u8) Header {
        var first_line = std.mem.splitScalar(u8, buf, ' ');
        const method = first_line.first();
        const path = first_line.next().?;
        const proto_version = first_line.next().?;

        return Header{
            .method = method,
            .path = path,
            .protocolVersion = proto_version,
        };
    }
};

// the simple http server just accept 2 method, which is get and path \
// respoonse it method and path.

// i don't know how much the number of connections will be served.
// So,stores the heap in the stack is a bad idea.
// i need to allocate some memory :)
