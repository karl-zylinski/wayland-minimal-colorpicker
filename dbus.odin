package minimal_colorpicker

import "core:c/libc"
import "core:strings"
import "core:sys/linux"

DBUS_MESSAGE_TYPE_METHOD_RETURN :: 2
DBUS_MESSAGE_TYPE_ERROR :: 3
DBUS_HEADER_FIELD_PATH :: 1
DBUS_HEADER_FIELD_INTERFACE :: 2
DBUS_HEADER_FIELD_MEMBER :: 3
DBUS_HEADER_FIELD_REPLY_SERIAL :: 5
DBUS_HEADER_FIELD_DESTINATION :: 6
DBUS_HEADER_FIELD_SIGNATURE :: 8
DBUS_HEADER_FIELD_UNIX_FDS :: 9
QIMAGE_FORMAT_RGB32 :: 4
QIMAGE_FORMAT_ARGB32 :: 5
QIMAGE_FORMAT_ARGB32_PREMULTIPLIED :: 6

dbus_socket: linux.Fd = -1
dbus_serial: u32
dbus_out: [512]u8
dbus_out_len: int
dbus_in: [8192]u8
dbus_in_len: int

dbus_read :: proc(fd: linux.Fd, buf: []u8) -> int {
	pfd := [1]linux.Poll_Fd{{fd = fd, events = {.IN}}}
	if ready, _ := linux.poll(pfd[:], 1000); ready <= 0 {
		return -1
	}
	n, err := linux.read(fd, buf)
	if err != .NONE {
		return -1
	}
	return n
}

dbus_disconnect :: proc() {
	if dbus_socket >= 0 {
		linux.close(dbus_socket)
	}
	dbus_socket = -1
	dbus_in_len = 0
}

dbus_align :: proc(p: int, n: int) -> int {
	return (p + n - 1) & ~(n - 1)
}

dbus_put_u8 :: proc(v: u8) {
	dbus_out[dbus_out_len] = v
	dbus_out_len += 1
}

dbus_put_pad :: proc(n: int) {
	for dbus_out_len % n != 0 {
		dbus_put_u8(0)
	}
}

dbus_put_u32 :: proc(v: u32) {
	dbus_put_pad(4)
	(^u32)(&dbus_out[dbus_out_len])^ = v
	dbus_out_len += 4
}

dbus_put_bytes :: proc(s: string) {
	copy(dbus_out[dbus_out_len:], s)
	dbus_out_len += len(s)
}

dbus_put_str :: proc(s: string) {
	dbus_put_u32(u32(len(s)))
	dbus_put_bytes(s)
	dbus_put_u8(0)
}

dbus_put_sig :: proc(s: string) {
	dbus_put_u8(u8(len(s)))
	dbus_put_bytes(s)
	dbus_put_u8(0)
}

dbus_put_field :: proc(code: u8, sig: string, value: string) {
	dbus_put_pad(8)
	dbus_put_u8(code)
	dbus_put_sig(sig)
	if sig == "g" {
		dbus_put_sig(value)
	} else {
		dbus_put_str(value)
	}
}

dbus_begin_call :: proc(dest, path, iface, member, signature: string, fds: u32) -> int {
	dbus_out_len = 0
	dbus_put_bytes("l\x01\x00\x01")
	dbus_put_u32(0)
	dbus_serial += 1
	dbus_put_u32(dbus_serial)
	dbus_put_u32(0)
	dbus_put_pad(8)
	fields_start := dbus_out_len
	dbus_put_field(DBUS_HEADER_FIELD_PATH, "o", path)
	dbus_put_field(DBUS_HEADER_FIELD_INTERFACE, "s", iface)
	dbus_put_field(DBUS_HEADER_FIELD_MEMBER, "s", member)
	dbus_put_field(DBUS_HEADER_FIELD_DESTINATION, "s", dest)
	if signature != "" {
		dbus_put_field(DBUS_HEADER_FIELD_SIGNATURE, "g", signature)
	}
	if fds > 0 {
		dbus_put_pad(8)
		dbus_put_u8(DBUS_HEADER_FIELD_UNIX_FDS)
		dbus_put_sig("u")
		dbus_put_u32(fds)
	}
	(^u32)(&dbus_out[12])^ = u32(dbus_out_len - fields_start)
	dbus_put_pad(8)
	return dbus_out_len
}

dbus_end_call :: proc(body_start: int) {
	(^u32)(&dbus_out[4])^ = u32(dbus_out_len - body_start)
}

dbus_send :: proc(fd: linux.Fd) -> bool {
	iov := linux.IO_Vec{raw_data(dbus_out[:]), uint(dbus_out_len)}
	control: [3]u64
	hdr := linux.Msg_Hdr {
		iov = ([^]linux.IO_Vec)(&iov)[:1],
	}
	if fd >= 0 {
		control[0] = 20
		control[1] = 1 | (1 << 32)
		control[2] = u64(u32(fd))
		hdr.control = ([^]u8)(&control[0])[:24]
	}
	n, err := linux.sendmsg(dbus_socket, &hdr, {.NOSIGNAL})
	return err == .NONE && n == dbus_out_len
}

dbus_read_line :: proc() -> string {
	dbus_in_len = 0
	for dbus_in_len < len(dbus_in) {
		n := dbus_read(dbus_socket, dbus_in[dbus_in_len:])
		if n <= 0 {
			return ""
		}
		dbus_in_len += n
		if dbus_in[dbus_in_len - 1] == '\n' {
			break
		}
	}
	s := string(dbus_in[:dbus_in_len])
	dbus_in_len = 0
	return s
}

dbus_connect :: proc() -> bool {
	address := string(libc.getenv("DBUS_SESSION_BUS_ADDRESS"))
	if !strings.has_prefix(address, "unix:path=") {
		return false
	}
	path := address[len("unix:path="):]
	if i := strings.index_byte(path, ','); i >= 0 {
		path = path[:i]
	}

	addr := linux.Sock_Addr_Un{sun_family = .UNIX}
	copy(addr.sun_path[:107], path)
	dbus_socket, _ = linux.socket(.UNIX, .STREAM, {.CLOEXEC}, .HOPOPT)
	if linux.connect(dbus_socket, &addr) != .NONE {
		dbus_disconnect()
		return false
	}

	digits := "0123456789"
	hex_digits := "0123456789abcdef"
	uid_text: [16]u8
	uid_len := 0
	uid := u32(linux.getuid())
	for {
		uid_text[uid_len] = digits[uid % 10]
		uid_len += 1
		uid /= 10
		if uid == 0 {
			break
		}
	}

	dbus_out_len = 0
	dbus_put_bytes("\x00AUTH EXTERNAL ")
	for i := uid_len - 1; i >= 0; i -= 1 {
		dbus_put_u8(hex_digits[uid_text[i] >> 4])
		dbus_put_u8(hex_digits[uid_text[i] & 0xF])
	}
	dbus_put_bytes("\r\n")
	if !dbus_send(-1) || !strings.has_prefix(dbus_read_line(), "OK") {
		dbus_disconnect()
		return false
	}

	dbus_out_len = 0
	dbus_put_bytes("NEGOTIATE_UNIX_FD\r\n")
	if !dbus_send(-1) || !strings.has_prefix(dbus_read_line(), "AGREE_UNIX_FD") {
		dbus_disconnect()
		return false
	}

	dbus_out_len = 0
	dbus_put_bytes("BEGIN\r\n")
	if !dbus_send(-1) {
		dbus_disconnect()
		return false
	}

	body := dbus_begin_call("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "Hello", "", 0)
	dbus_end_call(body)
	if !dbus_send(-1) {
		dbus_disconnect()
		return false
	}
	return true
}

dbus_get_u32 :: proc(p: int) -> u32 {
	return (^u32)(&dbus_in[p])^
}

dbus_skip_value :: proc(p: int, sig: u8) -> (next: int, value: u32, ok: bool) {
	switch sig {
	case 'u', 'i', 'b', 'h':
		q := dbus_align(p, 4)
		return q + 4, dbus_get_u32(q), true
	case 'd', 'x', 't':
		return dbus_align(p, 8) + 8, 0, true
	case 's', 'o':
		q := dbus_align(p, 4)
		return q + 4 + int(dbus_get_u32(q)) + 1, 0, true
	case 'g':
		return p + 1 + int(dbus_in[p]) + 1, 0, true
	}
	return p, 0, false
}

dbus_wait_reply :: proc(serial: u32) -> (format: u32, ok: bool) {
	for {
		for dbus_in_len < 16 || dbus_in_len < dbus_align(16 + int(dbus_get_u32(12)), 8) + int(dbus_get_u32(4)) {
			if dbus_in_len >= 16 && dbus_align(16 + int(dbus_get_u32(12)), 8) + int(dbus_get_u32(4)) > len(dbus_in) {
				return 0, false
			}
			n := dbus_read(dbus_socket, dbus_in[dbus_in_len:])
			if n <= 0 {
				return 0, false
			}
			dbus_in_len += n
		}

		msg_type := dbus_in[1]
		fields_end := 16 + int(dbus_get_u32(12))
		body := dbus_align(fields_end, 8)
		total := body + int(dbus_get_u32(4))

		reply_serial: u32
		p := 16
		for p < fields_end {
			p = dbus_align(p, 8)
			code := dbus_in[p]
			sig_len := int(dbus_in[p + 1])
			sig := dbus_in[p + 2]
			v: u32
			value_ok: bool
			p, v, value_ok = dbus_skip_value(p + 3 + sig_len, sig)
			if !value_ok {
				break
			}
			if code == DBUS_HEADER_FIELD_REPLY_SERIAL {
				reply_serial = v
			}
		}

		found := reply_serial == serial && (msg_type == DBUS_MESSAGE_TYPE_METHOD_RETURN || msg_type == DBUS_MESSAGE_TYPE_ERROR)
		if found && msg_type == DBUS_MESSAGE_TYPE_METHOD_RETURN {
			p = dbus_align(body + 4, 8)
			end := p + int(dbus_get_u32(body))
			for p < end {
				p = dbus_align(p, 8)
				key_len := int(dbus_get_u32(p))
				key := string(dbus_in[p + 4:p + 4 + key_len])
				p += 4 + key_len + 1
				sig_len := int(dbus_in[p])
				sig := dbus_in[p + 1]
				v: u32
				value_ok: bool
				p, v, value_ok = dbus_skip_value(p + 2 + sig_len, sig)
				if !value_ok {
					break
				}
				if key == "format" {
					format = v
				}
			}
		}

		copy(dbus_in[:], dbus_in[total:dbus_in_len])
		dbus_in_len -= total
		if found {
			return format, msg_type == DBUS_MESSAGE_TYPE_METHOD_RETURN
		}
	}
}

dbus_kde_capture_pixel :: proc(x, y: i32) -> (rgb: u32, ok: bool) {
	if dbus_socket < 0 && !dbus_connect() {
		return 0, false
	}

	fds: [2]linux.Fd
	if linux.pipe2(&fds, {.CLOEXEC}) != .NONE {
		return 0, false
	}
	defer linux.close(fds[0])

	body := dbus_begin_call("org.kde.KWin", "/org/kde/KWin/ScreenShot2", "org.kde.KWin.ScreenShot2", "CaptureArea", "iiuua{sv}h", 1)
	dbus_put_u32(transmute(u32)x)
	dbus_put_u32(transmute(u32)y)
	dbus_put_u32(1)
	dbus_put_u32(1)
	dbus_put_u32(0)
	dbus_put_pad(8)
	dbus_put_u32(0)
	dbus_end_call(body)
	sent := dbus_send(fds[1])
	linux.close(fds[1])
	if !sent {
		dbus_disconnect()
		return 0, false
	}

	format, reply_ok := dbus_wait_reply(dbus_serial)
	if !reply_ok {
		dbus_disconnect()
		return 0, false
	}

	buf: [64]u8
	n := 0
	for n < len(buf) {
		r := dbus_read(fds[0], buf[n:])
		if r <= 0 {
			break
		}
		n += r
	}
	if n < 4 {
		return 0, false
	}

	switch format {
	case QIMAGE_FORMAT_RGB32, QIMAGE_FORMAT_ARGB32, QIMAGE_FORMAT_ARGB32_PREMULTIPLIED:
		rgb = (u32(buf[2]) << 16) | (u32(buf[1]) << 8) | u32(buf[0])
	case:
		rgb = (u32(buf[0]) << 16) | (u32(buf[1]) << 8) | u32(buf[2])
	}
	return rgb, true
}
