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

    _ = posix.bind(listener, @ptrCast(&address), address.getOsSockLen()) catch |err| {
        std.debug.print("failed to bind socket: {?}\n", .{err});
        return err;
    };
    _ = posix.listen(listener, 10) catch |err| {
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
    const response = "GET / HTTP/1.1 200 OK\r\n" ++
        "Content-Type: text/html\r\n" ++
        "Content-Length: 12\r\n" ++
        "Connection: keep-alive \r\n\r\n" ++
        "<h1>Hello World</h1>";
    const written_size = try posix.write(conn, response);
    std.debug.print("written size : {any}\n", .{written_size});
}
//var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
// defer arena.deinit();
// const allocator = arena.allocator();
// try allocator.alloc(posix.socket_t, client_sock);
// defer allocator.free(memory: anytype)
