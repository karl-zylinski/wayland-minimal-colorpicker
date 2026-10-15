package minimal_colorpicker

import "base:runtime"
import "core:c/libc"
import "core:sys/linux"

BTN_LEFT :: 0x110
KEY_ESC :: 1
SIGPIPE :: 13
CROSS :: 27
CROSS_HALF :: CROSS / 2
LABEL_OFFSET :: 16
MAX_SCALE :: 3
LABEL_MAX_W :: 184 * MAX_SCALE
LABEL_MAX_H :: 24 * MAX_SCALE
CURSOR_MAX_W :: LABEL_MAX_W + (CROSS_HALF + LABEL_OFFSET) * MAX_SCALE + 1
CURSOR_MAX_H :: LABEL_MAX_H + (CROSS_HALF + LABEL_OFFSET) * MAX_SCALE + 1
CURSOR_MAX_SIZE :: CURSOR_MAX_W * CURSOR_MAX_H * 4
PIXEL_OFFSET :: CURSOR_MAX_SIZE * 2
SCREENCOPY_OFFSET :: PIXEL_OFFSET + 4
POOL_SIZE :: SCREENCOPY_OFFSET + SCREENCOPY_SIZE

GLYPH_CHARS := "0123456789ABCDEF#, "
GLYPHS := [19][7]u8{
	{0b01110, 0b10001, 0b10011, 0b10101, 0b11001, 0b10001, 0b01110},
	{0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110},
	{0b01110, 0b10001, 0b00001, 0b00010, 0b00100, 0b01000, 0b11111},
	{0b11111, 0b00010, 0b00100, 0b00010, 0b00001, 0b10001, 0b01110},
	{0b00010, 0b00110, 0b01010, 0b10010, 0b11111, 0b00010, 0b00010},
	{0b11111, 0b10000, 0b11110, 0b00001, 0b00001, 0b10001, 0b01110},
	{0b00110, 0b01000, 0b10000, 0b11110, 0b10001, 0b10001, 0b01110},
	{0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000},
	{0b01110, 0b10001, 0b10001, 0b01110, 0b10001, 0b10001, 0b01110},
	{0b01110, 0b10001, 0b10001, 0b01111, 0b00001, 0b00010, 0b01100},
	{0b01110, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001},
	{0b11110, 0b10001, 0b10001, 0b11110, 0b10001, 0b10001, 0b11110},
	{0b01110, 0b10001, 0b10000, 0b10000, 0b10000, 0b10001, 0b01110},
	{0b11100, 0b10010, 0b10001, 0b10001, 0b10001, 0b10010, 0b11100},
	{0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111},
	{0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b10000},
	{0b01010, 0b01010, 0b11111, 0b01010, 0b11111, 0b01010, 0b01010},
	{0b00000, 0b00000, 0b00000, 0b00000, 0b01100, 0b00100, 0b01000},
	{0, 0, 0, 0, 0, 0, 0},
}

display: ^WL_Display
compositor: ^WL_Proxy
shm: ^WL_Proxy
seat: ^WL_Proxy
data_device_manager: ^WL_Proxy
viewporter: ^WL_Proxy
layer_shell: ^WL_Proxy
fractional_scale_manager: ^WL_Proxy

Output :: struct {
	proxy: ^WL_Proxy,
	x, y:  i32,
}
outputs: [16]Output
output_count: int
output_x, output_y: i32
current_output: ^WL_Proxy
shm_pool: ^WL_Proxy

surface: ^WL_Proxy
layer_surface: ^WL_Proxy
viewport: ^WL_Proxy
cursor_surface: ^WL_Proxy
cursor_viewport: ^WL_Proxy
pixel_buffer: ^WL_Proxy
cursor_buffers: [2]^WL_Proxy
cursor_busy: [2]bool
pool_memory: [^]u32
pointer: ^WL_Proxy
enter_serial: u32
hot_x, hot_y: i32 = CROSS_HALF, CROSS_HALF

scale120: u32 = 120
scale_changed: bool
font_px, pad_x, text_x, advance, char_gap: int
label_lw, label_lh, label_bw, label_bh: int
box_lw, box_lh, box_bw, box_bh: int
cross_px, cross_half, cross_gap: int

width, height: i32
cursor_x, cursor_y: i32
cursor_fx, cursor_fy: f32
moved: bool
dirty: bool
frame_pending: bool
color: u32
text: [16]u8
text_len: int
rgb_mode: bool
toggle_socket: linux.Fd
state_path: [256]u8
state_dir_len: int
running := true
picked: bool
pick_pending: bool
pick_serial: u32
selection_seen: bool

registry_global :: proc "c" (data: rawptr, registry: ^WL_Proxy, name: u32, interface: cstring, version: u32) {
	context = runtime.default_context()
	switch string(interface) {
	case "wl_compositor":
		compositor = wl_bind(registry, name, &wl_compositor_interface, version)
	case "wl_shm":
		shm = wl_bind(registry, name, &wl_shm_interface, version)
	case "wl_seat":
		seat = wl_bind(registry, name, &wl_seat_interface, version)
		wl_listen(seat, &seat_listener)
	case "wl_data_device_manager":
		data_device_manager = wl_bind(registry, name, &wl_data_device_manager_interface, version)
	case "wp_viewporter":
		viewporter = wl_bind(registry, name, &wl_viewporter_interface, version)
	case "zwlr_layer_shell_v1":
		layer_shell = wl_bind(registry, name, &wl_layer_shell_interface, version)
	case "wp_fractional_scale_manager_v1":
		fractional_scale_manager = wl_bind(registry, name, &wl_fractional_scale_manager_interface, version)
	case "zwlr_screencopy_manager_v1":
		screencopy_manager = wl_bind(registry, name, &wl_screencopy_manager_interface, version)
	case "wl_output":
		if output_count < len(outputs) {
			o := wl_bind(registry, name, &wl_output_interface, version)
			outputs[output_count].proxy = o
			output_count += 1
			wl_listen(o, &output_listener)
		}
	}
}
registry_listener := WL_Registry_Listener{
	global = registry_global,
}

seat_capabilities: u32

seat_on_capabilities :: proc "c" (data: rawptr, s: ^WL_Proxy, capabilities: u32) {
	seat_capabilities = capabilities
}
seat_listener := WL_Seat_Listener {
	capabilities = seat_on_capabilities,
}

output_geometry :: proc "c" (data: rawptr, o: ^WL_Proxy, x, y, physical_width, physical_height, subpixel: i32, make, model: cstring, transform: i32) {
	for &out in outputs[:output_count] {
		if out.proxy == o {
			out.x = x
			out.y = y
		}
	}
}
output_listener := WL_Output_Listener{
	geometry = output_geometry,
}

surface_enter :: proc "c" (data: rawptr, s: ^WL_Proxy, o: ^WL_Proxy) {
	for out in outputs[:output_count] {
		if out.proxy == o {
			output_x = out.x
			current_output = o
			output_y = out.y
			moved = true
		}
	}
}
surface_listener := WL_Surface_Listener{
	enter = surface_enter,
}

layer_configure :: proc "c" (data: rawptr, ls: ^WL_Proxy, serial: u32, w: u32, h: u32) {
	width = i32(w)
	height = i32(h)
	wl_proxy_marshal_flags(ls, WL_LAYER_SURFACE_ACK_CONFIGURE, nil, wl_proxy_get_version(ls), 0, serial)
	wl_proxy_marshal_flags(viewport, WL_VIEWPORT_SET_DESTINATION, nil, wl_proxy_get_version(viewport), 0, width, height)
	wl_proxy_marshal_flags(surface, WL_SURFACE_ATTACH, nil, wl_proxy_get_version(surface), 0, pixel_buffer, i32(0), i32(0))
	wl_proxy_marshal_flags(surface, WL_SURFACE_DAMAGE_BUFFER, nil, wl_proxy_get_version(surface), 0, i32(0), i32(0), i32(1), i32(1))
	wl_proxy_marshal_flags(surface, WL_SURFACE_COMMIT, nil, wl_proxy_get_version(surface), 0)
}

layer_closed :: proc "c" (data: rawptr, ls: ^WL_Proxy) {
	running = false
}
layer_surface_listener := WL_Layer_Surface_Listener{
	configure = layer_configure,
	closed    = layer_closed,
}

fractional_preferred_scale :: proc "c" (data: rawptr, fs: ^WL_Proxy, scale: u32) {
	clamped := clamp(scale, 120, MAX_SCALE * 120)
	if clamped != scale120 {
		scale120 = clamped
		scale_changed = true
	}
}
fractional_scale_listener := WL_Fractional_Scale_Listener {
	preferred_scale = fractional_preferred_scale,
}

frame_done :: proc "c" (data: rawptr, cb: ^WL_Proxy, time: u32) {
	wl_proxy_destroy(cb)
	frame_pending = false
}
frame_listener := WL_Callback_Listener {
	done = frame_done,
}

buffer_release :: proc "c" (data: rawptr, b: ^WL_Proxy) {
	for cb, i in cursor_buffers {
		if cb == b {
			cursor_busy[i] = false
		}
	}
}
buffer_listener := WL_Buffer_Listener{
	release = buffer_release,
}

pointer_enter :: proc "c" (data: rawptr, p: ^WL_Proxy, serial: u32, s: ^WL_Proxy, x, y: WL_Fixed) {
	pointer = p
	enter_serial = serial
	frame_pending = false
	wl_proxy_marshal_flags(p, WL_POINTER_SET_CURSOR, nil, wl_proxy_get_version(p), 0, serial, cursor_surface, hot_x, hot_y)
	set_cursor_position(x, y)
}

pointer_motion :: proc "c" (data: rawptr, p: ^WL_Proxy, time: u32, x, y: WL_Fixed) {
	set_cursor_position(x, y)
}

set_cursor_position :: proc "contextless" (x, y: WL_Fixed) {
	cursor_x = x >> 8
	cursor_y = y >> 8
	cursor_fx = f32(x & 255) / 256
	cursor_fy = f32(y & 255) / 256
	moved = true
}

pointer_button :: proc "c" (data: rawptr, p: ^WL_Proxy, serial: u32, time: u32, button: u32, state: u32) {
	if state != WL_POINTER_BUTTON_STATE_PRESSED || picked {
		return
	}
	if button == BTN_LEFT {
		pick_pending = true
		pick_serial = serial
	} else {
		running = false
	}
}
pointer_listener := WL_Pointer_Listener{
	enter  = pointer_enter,
	motion = pointer_motion,
	button = pointer_button,
}

keyboard_keymap :: proc "c" (data: rawptr, k: ^WL_Proxy, format: u32, fd: i32, size: u32) {
	linux.close(linux.Fd(fd))
}

keyboard_key :: proc "c" (data: rawptr, k: ^WL_Proxy, serial: u32, time: u32, key: u32, state: u32) {
	if key == KEY_ESC && state == WL_KEYBOARD_KEY_STATE_PRESSED && !picked {
		running = false
	}
}
keyboard_listener := WL_Keyboard_Listener{
	keymap = keyboard_keymap,
	key    = keyboard_key,
}

source_send :: proc "c" (data: rawptr, s: ^WL_Proxy, mime: cstring, fd: i32) {
	linux.write(linux.Fd(fd), text[:text_len])
	linux.close(linux.Fd(fd))
}

source_cancelled :: proc "c" (data: rawptr, s: ^WL_Proxy) {
	running = false
}
source_listener := WL_Data_Source_Listener{
	send      = source_send,
	cancelled = source_cancelled,
}

data_device: ^WL_Proxy

data_device_selection :: proc "c" (data: rawptr, dd: ^WL_Proxy, offer: ^WL_Proxy) {
	if offer != nil {
		selection_seen = true
		wl_proxy_marshal_flags(offer, WL_DATA_OFFER_DESTROY, nil, wl_proxy_get_version(offer), WL_MARSHAL_FLAG_DESTROY)
	}
}
data_device_listener := WL_Data_Device_Listener {
	selection = data_device_selection,
}

pick :: proc(serial: u32) {
	picked = true
	linux.close(toggle_socket)
	write_text(color)
	source := wl_proxy_marshal_flags(data_device_manager, WL_DATA_DEVICE_MANAGER_CREATE_DATA_SOURCE, &wl_data_source_interface, wl_proxy_get_version(data_device_manager), 0, nil)
	wl_listen(source, &source_listener)
	wl_proxy_marshal_flags(source, WL_DATA_SOURCE_OFFER, nil, wl_proxy_get_version(source), 0, cstring("text/plain;charset=utf-8"))
	wl_proxy_marshal_flags(source, WL_DATA_SOURCE_OFFER, nil, wl_proxy_get_version(source), 0, cstring("text/plain"))
	wl_proxy_marshal_flags(source, WL_DATA_SOURCE_OFFER, nil, wl_proxy_get_version(source), 0, cstring("UTF8_STRING"))
	selection_seen = false
	wl_proxy_marshal_flags(data_device, WL_DATA_DEVICE_SET_SELECTION, nil, wl_proxy_get_version(data_device), 0, source, serial)
	wl_display_roundtrip(display)
	if !selection_seen {
		running = false
	}
	wl_proxy_marshal_flags(layer_surface, WL_LAYER_SURFACE_DESTROY, nil, wl_proxy_get_version(layer_surface), WL_MARSHAL_FLAG_DESTROY)
	wl_proxy_marshal_flags(surface, WL_SURFACE_DESTROY, nil, wl_proxy_get_version(surface), WL_MARSHAL_FLAG_DESTROY)
}

write_text :: proc "contextless" (rgb: u32) {
	digits := GLYPH_CHARS
	if !rgb_mode {
		text[0] = '#'
		for i in 0 ..< 6 {
			text[1 + i] = digits[(rgb >> (20 - 4 * u32(i))) & 0xF]
		}
		text_len = 7
		return
	}
	text_len = 0
	for shift in ([3]u32{16, 8, 0}) {
		v := (rgb >> shift) & 0xFF
		if v >= 100 {
			text[text_len] = digits[v / 100]
			text_len += 1
		}
		if v >= 10 {
			text[text_len] = digits[v / 10 % 10]
			text_len += 1
		}
		text[text_len] = digits[v % 10]
		text_len += 1
		if shift != 0 {
			text[text_len] = ','
			text[text_len + 1] = ' '
			text_len += 2
		}
	}
}

scaled :: proc(v: int) -> int {
	return (v * int(scale120) + 60) / 120
}

logical :: proc(px: int) -> int {
	return (px * 120 + int(scale120) - 1) / int(scale120)
}

setup_scale :: proc() {
	font_px = max(1, scaled(2))
	pad_x = scaled(5)
	char_gap = scaled(2)
	text_x = pad_x + 7 * font_px + scaled(6)
	advance = 5 * font_px + char_gap
	label_lw = logical(text_x + 13 * advance - char_gap + pad_x)
	label_lh = logical(7 * font_px + 2 * scaled(5))
	label_bw = min(scaled(label_lw), LABEL_MAX_W)
	label_bh = min(scaled(label_lh), LABEL_MAX_H)

	cross_px = scaled(CROSS)
	cross_half = max(1, scaled(1))
	cross_gap = max(scaled(2), cross_half + 1)

	box_lw = CROSS_HALF + LABEL_OFFSET + label_lw
	box_lh = CROSS_HALF + LABEL_OFFSET + label_lh
	box_bw = min(scaled(box_lw), CURSOR_MAX_W)
	box_bh = min(scaled(box_lh), CURSOR_MAX_H)

	for i in 0 ..< 2 {
		if cursor_buffers[i] != nil {
			wl_proxy_marshal_flags(cursor_buffers[i], WL_BUFFER_DESTROY, nil, wl_proxy_get_version(cursor_buffers[i]), WL_MARSHAL_FLAG_DESTROY)
		}
		cursor_buffers[i] = wl_proxy_marshal_flags(shm_pool, WL_SHM_POOL_CREATE_BUFFER, &wl_buffer_interface, wl_proxy_get_version(shm_pool), 0, nil, i32(i * CURSOR_MAX_SIZE), i32(box_bw), i32(box_bh), i32(box_bw * 4), u32(WL_SHM_FORMAT_ARGB8888))
		wl_listen(cursor_buffers[i], &buffer_listener)
		cursor_busy[i] = false
	}
	wl_proxy_marshal_flags(cursor_viewport, WL_VIEWPORT_SET_DESTINATION, nil, wl_proxy_get_version(cursor_viewport), 0, i32(box_lw), i32(box_lh))
	hot_x = -1
}

put_px :: proc(px: [^]u32, x, y: int, c: u32) {
	if x >= 0 && x < box_bw && y >= 0 && y < box_bh {
		px[y * box_bw + x] = c
	}
}

draw_cursor :: proc(px: [^]u32, rgb: u32, used: int, left, above: bool) {
	for i in 0 ..< box_bw * box_bh {
		px[i] = 0
	}

	hx := scaled(int(hot_x))
	hy := scaled(int(hot_y))
	c := cross_px / 2
	for y in 0 ..< cross_px {
		for x in 0 ..< cross_px {
			dx := abs(x - c)
			dy := abs(y - c)
			if (dx <= cross_half && dy >= cross_gap) || (dy <= cross_half && dx >= cross_gap) {
				put_px(px, hx - c + x, hy - c + y, min(dx, dy) < cross_half ? 0x80808080 : 0x80000000)
			}
		}
	}

	lx := left ? hx - scaled(LABEL_OFFSET) - used : hx + scaled(LABEL_OFFSET)
	ly := above ? hy - scaled(LABEL_OFFSET) - label_bh : hy + scaled(LABEL_OFFSET)
	pad_y := (label_bh - 7 * font_px) / 2
	for y in 0 ..< label_bh {
		for x in 0 ..< used {
			put_px(px, lx + x, ly + y, 0x99000000)
		}
	}
	for y in 0 ..< 7 * font_px {
		for x in 0 ..< 7 * font_px {
			put_px(px, lx + pad_x + x, ly + pad_y + y, 0xFF000000 | rgb)
		}
	}
	pen := lx + text_x
	for ch in text[:text_len] {
		g := 18
		for k in 0 ..< len(GLYPH_CHARS) {
			if GLYPH_CHARS[k] == ch {
				g = k
			}
		}
		for row in 0 ..< 7 {
			for col in 0 ..< 5 {
				if GLYPHS[g][row] & (0b10000 >> u8(col)) == 0 {
					continue
				}
				for sy in 0 ..< font_px {
					for sx in 0 ..< font_px {
						put_px(px, pen + col * font_px + sx, ly + pad_y + row * font_px + sy, 0xFFFFFFFF)
					}
				}
			}
		}
		pen += advance
	}
}

redraw :: proc() {
	b := -1
	for i in 0 ..< 2 {
		if !cursor_busy[i] {
			b = i
			break
		}
	}
	if b < 0 {
		dirty = true
		return
	}

	write_text(color)
	used := min(text_x + text_len * advance - char_gap + pad_x, label_bw)
	left := cursor_x + LABEL_OFFSET + i32(logical(used)) > width
	above := cursor_y + LABEL_OFFSET + i32(label_lh) > height
	hx := left ? i32(LABEL_OFFSET + label_lw) : i32(CROSS_HALF)
	hy := above ? i32(LABEL_OFFSET + label_lh) : i32(CROSS_HALF)
	hot_changed := hx != hot_x || hy != hot_y
	hot_x = hx
	hot_y = hy

	draw_cursor(pool_memory[b * CURSOR_MAX_SIZE / 4:], color, used, left, above)
	cursor_busy[b] = true

	wl_proxy_marshal_flags(cursor_surface, WL_SURFACE_ATTACH, nil, wl_proxy_get_version(cursor_surface), 0, cursor_buffers[b], i32(0), i32(0))
	wl_proxy_marshal_flags(cursor_surface, WL_SURFACE_DAMAGE_BUFFER, nil, wl_proxy_get_version(cursor_surface), 0, i32(0), i32(0), i32(box_bw), i32(box_bh))
	if hot_changed && pointer != nil {
		wl_proxy_marshal_flags(pointer, WL_POINTER_SET_CURSOR, nil, wl_proxy_get_version(pointer), 0, enter_serial, cursor_surface, hot_x, hot_y)
	}
	frame := wl_proxy_marshal_flags(cursor_surface, WL_SURFACE_FRAME, &wl_callback_interface, wl_proxy_get_version(cursor_surface), 0, nil)
	wl_listen(frame, &frame_listener)
	frame_pending = true
	wl_proxy_marshal_flags(cursor_surface, WL_SURFACE_COMMIT, nil, wl_proxy_get_version(cursor_surface), 0)
}

capture :: proc() -> (rgb: u32, ok: bool) {
	if screencopy_manager != nil {
		return screencopy_pixel(current_output, cursor_x, cursor_y, cursor_fx, cursor_fy)
	}
	return dbus_kde_capture_pixel(output_x + cursor_x, output_y + cursor_y, cursor_fx, cursor_fy)
}

fail :: proc(msg: string) -> ! {
	linux.write(2, transmute([]u8)msg)
	linux.exit(1)
}

main :: proc() {
	libc.signal(SIGPIPE, transmute(proc "c" (i32))libc.SIG_IGN)

	addr := linux.Sock_Addr_Un{sun_family = .UNIX}
	copy(addr.sun_path[1:], "minimal_colorpicker")
	toggle_socket, _ = linux.socket(.UNIX, .STREAM, {.CLOEXEC, .NONBLOCK}, .HOPOPT)
	if linux.bind(toggle_socket, &addr) != .NONE {
		linux.connect(toggle_socket, &addr)
		return
	}
	linux.listen(toggle_socket, 4)

	if xdg := string(libc.getenv("XDG_STATE_HOME")); len(xdg) > 0 && xdg[0] == '/' {
		state_dir_len = copy(state_path[:200], xdg)
	} else {
		state_dir_len = copy(state_path[:200], string(libc.getenv("HOME")))
		state_dir_len += copy(state_path[state_dir_len:200], "/.local/state")
	}
	copy(state_path[state_dir_len:255], "/minimal_colorpicker")
	if fd, err := linux.open(cstring(&state_path[0]), {}); err == .NONE {
		b: [1]u8
		linux.read(fd, b[:])
		linux.close(fd)
		rgb_mode = b[0] == '1'
	}

	display = wl_display_connect(nil)
	if display == nil {
		fail("no wayland display\n")
	}

	registry := wl_proxy_marshal_flags((^WL_Proxy)(display), WL_DISPLAY_GET_REGISTRY, &wl_registry_interface, wl_proxy_get_version((^WL_Proxy)(display)), 0, nil)
	wl_listen(registry, &registry_listener)
	wl_display_roundtrip(display)
	wl_display_roundtrip(display)

	if compositor == nil || shm == nil || seat == nil || data_device_manager == nil || viewporter == nil || layer_shell == nil {
		fail("missing wayland globals\n")
	}
	if output_count == 0 {
		fail("no outputs\n")
	}

	fd, err := linux.memfd_create("minimal_colorpicker", {.CLOEXEC})
	if err != .NONE {
		fail("memfd_create failed\n")
	}
	linux.ftruncate(fd, POOL_SIZE)
	mem, merr := linux.mmap(0, POOL_SIZE, {.READ, .WRITE}, {.SHARED}, fd)
	if merr != .NONE {
		fail("mmap failed\n")
	}
	pool_memory = ([^]u32)(mem)
	pool_memory[PIXEL_OFFSET / 4] = 0

	shm_pool = wl_proxy_marshal_flags(shm, WL_SHM_CREATE_POOL, &wl_shm_pool_interface, wl_proxy_get_version(shm), 0, nil, i32(fd), i32(POOL_SIZE))
	pixel_buffer = wl_proxy_marshal_flags(shm_pool, WL_SHM_POOL_CREATE_BUFFER, &wl_buffer_interface, wl_proxy_get_version(shm_pool), 0, nil, i32(PIXEL_OFFSET), i32(1), i32(1), i32(4), u32(WL_SHM_FORMAT_ARGB8888))
	linux.close(fd)

	current_output = outputs[0].proxy
	if _, ok := capture(); !ok {
		fail("screen capture failed\n")
	}

	if seat_capabilities & WL_SEAT_CAPABILITY_POINTER != 0 {
		seat_pointer := wl_proxy_marshal_flags(seat, WL_SEAT_GET_POINTER, &wl_pointer_interface, wl_proxy_get_version(seat), 0, nil)
		wl_listen(seat_pointer, &pointer_listener)
	}
	if seat_capabilities & WL_SEAT_CAPABILITY_KEYBOARD != 0 {
		keyboard := wl_proxy_marshal_flags(seat, WL_SEAT_GET_KEYBOARD, &wl_keyboard_interface, wl_proxy_get_version(seat), 0, nil)
		wl_listen(keyboard, &keyboard_listener)
	}
	data_device = wl_proxy_marshal_flags(data_device_manager, WL_DATA_DEVICE_MANAGER_GET_DATA_DEVICE, &wl_data_device_interface, wl_proxy_get_version(data_device_manager), 0, nil, seat)
	wl_listen(data_device, &data_device_listener)

	surface = wl_proxy_marshal_flags(compositor, WL_COMPOSITOR_CREATE_SURFACE, &wl_surface_interface, wl_proxy_get_version(compositor), 0, nil)
	wl_listen(surface, &surface_listener)
	viewport = wl_proxy_marshal_flags(viewporter, WL_VIEWPORTER_GET_VIEWPORT, &wl_viewport_interface, wl_proxy_get_version(viewporter), 0, nil, surface)
	if fractional_scale_manager != nil {
		fractional_scale := wl_proxy_marshal_flags(fractional_scale_manager, WL_FRACTIONAL_SCALE_MANAGER_GET_FRACTIONAL_SCALE, &wl_fractional_scale_interface, wl_proxy_get_version(fractional_scale_manager), 0, nil, surface)
		wl_listen(fractional_scale, &fractional_scale_listener)
	}

	cursor_surface = wl_proxy_marshal_flags(compositor, WL_COMPOSITOR_CREATE_SURFACE, &wl_surface_interface, wl_proxy_get_version(compositor), 0, nil)
	cursor_viewport = wl_proxy_marshal_flags(viewporter, WL_VIEWPORTER_GET_VIEWPORT, &wl_viewport_interface, wl_proxy_get_version(viewporter), 0, nil, cursor_surface)
	setup_scale()

	layer_surface = wl_proxy_marshal_flags(layer_shell, WL_LAYER_SHELL_GET_LAYER_SURFACE, &wl_layer_surface_interface, wl_proxy_get_version(layer_shell), 0, nil, surface, nil, u32(WL_LAYER_SHELL_LAYER_OVERLAY), cstring("dock"))
	wl_listen(layer_surface, &layer_surface_listener)
	wl_proxy_marshal_flags(layer_surface, WL_LAYER_SURFACE_SET_ANCHOR, nil, wl_proxy_get_version(layer_surface), 0, u32(WL_LAYER_SURFACE_ANCHOR_TOP | WL_LAYER_SURFACE_ANCHOR_BOTTOM | WL_LAYER_SURFACE_ANCHOR_LEFT | WL_LAYER_SURFACE_ANCHOR_RIGHT))
	wl_proxy_marshal_flags(layer_surface, WL_LAYER_SURFACE_SET_EXCLUSIVE_ZONE, nil, wl_proxy_get_version(layer_surface), 0, i32(-1))
	wl_proxy_marshal_flags(layer_surface, WL_LAYER_SURFACE_SET_KEYBOARD_INTERACTIVITY, nil, wl_proxy_get_version(layer_surface), 0, u32(WL_LAYER_SURFACE_KEYBOARD_INTERACTIVITY_EXCLUSIVE))
	wl_proxy_marshal_flags(surface, WL_SURFACE_COMMIT, nil, wl_proxy_get_version(surface), 0)

	fds := [2]linux.Poll_Fd{{fd = linux.Fd(wl_display_get_fd(display)), events = {.IN}}, {fd = toggle_socket, events = {.IN}}}
	for running {
		for wl_display_prepare_read(display) != 0 {
			wl_display_dispatch_pending(display)
		}
		wl_display_flush(display)
		fds[1].fd = picked ? -1 : toggle_socket
		linux.poll(fds[:], -1)
		if fds[0].revents & {.ERR, .HUP, .NVAL} != {} && .IN not_in fds[0].revents {
			wl_display_cancel_read(display)
			break
		}
		if .IN in fds[0].revents {
			if wl_display_read_events(display) == -1 {
				break
			}
		} else {
			wl_display_cancel_read(display)
		}
		wl_display_dispatch_pending(display)
		if .IN in fds[1].revents && !picked {
			client, _ := linux.accept(toggle_socket, (^linux.Sock_Addr_Un)(nil))
			linux.close(client)
			rgb_mode = !rgb_mode
			dirty = true
			for i in 1 ..= state_dir_len {
				if i == state_dir_len || state_path[i] == '/' {
					saved := state_path[i]
					state_path[i] = 0
					linux.mkdir(cstring(&state_path[0]), {.IRUSR, .IWUSR, .IXUSR})
					state_path[i] = saved
				}
			}
			if fd, err := linux.open(cstring(&state_path[0]), {.WRONLY, .CREAT, .TRUNC}, {.IRUSR, .IWUSR}); err == .NONE {
				linux.write(fd, rgb_mode ? []u8{'1'} : []u8{'0'})
				linux.close(fd)
			}
		}
		if picked || width == 0 {
			continue
		}
		if scale_changed {
			scale_changed = false
			setup_scale()
			dirty = true
		}
		if moved && !pick_pending && frame_pending {
			continue
		}
		if moved {
			moved = false
			if rgb, ok := capture(); ok {
				color = rgb
			}
			dirty = true
		}
		if pick_pending {
			pick_pending = false
			if moved {
				moved = false
				if rgb, ok := capture(); ok {
					color = rgb
				}
			}
			pick(pick_serial)
			continue
		}
		if dirty && !frame_pending {
			dirty = false
			redraw()
		}
	}
}
