package minimal_colorpicker

import "core:c"

foreign import wl "system:libwayland-client.so.0"

WL_Proxy :: struct {}
WL_Display :: struct {}
WL_Fixed :: i32

WL_Message :: struct {
	name:      cstring,
	signature: cstring,
	types:     [^]^WL_Interface,
}

WL_Interface :: struct {
	name:         cstring,
	version:      c.int,
	method_count: c.int,
	methods:      [^]WL_Message,
	event_count:  c.int,
	events:       [^]WL_Message,
}

WL_OUTPUT_MODE_CURRENT :: 1
WL_SEAT_CAPABILITY_POINTER :: 1
WL_SEAT_CAPABILITY_KEYBOARD :: 2
WL_POINTER_BUTTON_STATE_PRESSED :: 1
WL_KEYBOARD_KEY_STATE_PRESSED :: 1
WL_LAYER_SHELL_LAYER_OVERLAY :: 3
WL_LAYER_SURFACE_ANCHOR_TOP :: 1
WL_LAYER_SURFACE_ANCHOR_BOTTOM :: 2
WL_LAYER_SURFACE_ANCHOR_LEFT :: 4
WL_LAYER_SURFACE_ANCHOR_RIGHT :: 8
WL_LAYER_SURFACE_KEYBOARD_INTERACTIVITY_EXCLUSIVE :: 1
WL_SCREENCOPY_FRAME_FLAGS_Y_INVERT :: 1
WL_SHM_FORMAT_ARGB8888 :: 0
WL_SHM_FORMAT_XRGB8888 :: 1
WL_SHM_FORMAT_ABGR8888 :: 0x34324241
WL_SHM_FORMAT_XBGR8888 :: 0x34324258
WL_SHM_FORMAT_ARGB2101010 :: 0x30335241
WL_SHM_FORMAT_XRGB2101010 :: 0x30335258
WL_SHM_FORMAT_ABGR2101010 :: 0x30334241
WL_SHM_FORMAT_XBGR2101010 :: 0x30334258
WL_MARSHAL_FLAG_DESTROY :: 1
WL_DISPLAY_GET_REGISTRY :: 1

@(default_calling_convention = "c")
foreign wl {
	wl_display_connect :: proc(name: cstring) -> ^WL_Display ---
	wl_display_dispatch :: proc(display: ^WL_Display) -> c.int ---
	wl_display_roundtrip :: proc(display: ^WL_Display) -> c.int ---
	wl_display_flush :: proc(display: ^WL_Display) -> c.int ---
	wl_display_get_fd :: proc(display: ^WL_Display) -> c.int ---
	wl_display_prepare_read :: proc(display: ^WL_Display) -> c.int ---
	wl_display_read_events :: proc(display: ^WL_Display) -> c.int ---
	wl_display_cancel_read :: proc(display: ^WL_Display) ---
	wl_display_dispatch_pending :: proc(display: ^WL_Display) -> c.int ---
	wl_proxy_marshal_flags :: proc(proxy: ^WL_Proxy, opcode: u32, interface: ^WL_Interface, version: u32, flags: u32, #c_vararg args: ..any) -> ^WL_Proxy ---
	wl_proxy_add_listener :: proc(proxy: ^WL_Proxy, implementation: rawptr, data: rawptr) -> c.int ---
	wl_proxy_get_version :: proc(proxy: ^WL_Proxy) -> u32 ---
	wl_proxy_destroy :: proc(proxy: ^WL_Proxy) ---
}

wl_nils := [8]^WL_Interface{}
WL_NO_TYPES := raw_data(wl_nils[:])

wl_registry_interface := WL_Interface{"wl_registry", 1, 1, raw_data([]WL_Message{
	{"bind", "usun", WL_NO_TYPES},
}), 2, raw_data([]WL_Message{
	{"global", "usu", WL_NO_TYPES},
	{"global_remove", "u", WL_NO_TYPES},
})}

WL_REGISTRY_BIND :: 0

wl_callback_interface := WL_Interface{"wl_callback", 1, 0, nil, 1, raw_data([]WL_Message{
	{"done", "u", WL_NO_TYPES},
})}

wl_compositor_interface := WL_Interface{"wl_compositor", 4, 2, raw_data([]WL_Message{
	{"create_surface", "n", raw_data([]^WL_Interface{&wl_surface_interface})},
	{"create_region", "n", raw_data([]^WL_Interface{&wl_region_interface})},
}), 0, nil}

WL_COMPOSITOR_CREATE_SURFACE :: 0
WL_COMPOSITOR_CREATE_REGION :: 1

wl_region_interface := WL_Interface{"wl_region", 1, 3, raw_data([]WL_Message{
	{"destroy", "", WL_NO_TYPES},
	{"add", "iiii", WL_NO_TYPES},
	{"subtract", "iiii", WL_NO_TYPES},
}), 0, nil}

WL_REGION_DESTROY :: 0
WL_REGION_ADD :: 1
WL_REGION_SUBTRACT :: 2

wl_buffer_interface := WL_Interface{"wl_buffer", 1, 1, raw_data([]WL_Message{
	{"destroy", "", WL_NO_TYPES},
}), 1, raw_data([]WL_Message{
	{"release", "", WL_NO_TYPES},
})}

WL_BUFFER_DESTROY :: 0

wl_surface_interface := WL_Interface{"wl_surface", 4, 10, raw_data([]WL_Message{
	{"destroy", "", WL_NO_TYPES},
	{"attach", "?oii", raw_data([]^WL_Interface{&wl_buffer_interface, nil, nil})},
	{"damage", "iiii", WL_NO_TYPES},
	{"frame", "n", raw_data([]^WL_Interface{&wl_callback_interface})},
	{"set_opaque_region", "?o", raw_data([]^WL_Interface{&wl_region_interface})},
	{"set_input_region", "?o", raw_data([]^WL_Interface{&wl_region_interface})},
	{"commit", "", WL_NO_TYPES},
	{"set_buffer_transform", "2i", WL_NO_TYPES},
	{"set_buffer_scale", "3i", WL_NO_TYPES},
	{"damage_buffer", "4iiii", WL_NO_TYPES},
}), 2, raw_data([]WL_Message{
	{"enter", "o", raw_data([]^WL_Interface{&wl_output_interface})},
	{"leave", "o", raw_data([]^WL_Interface{&wl_output_interface})},
})}

WL_SURFACE_DESTROY :: 0
WL_SURFACE_ATTACH :: 1
WL_SURFACE_DAMAGE :: 2
WL_SURFACE_FRAME :: 3
WL_SURFACE_SET_OPAQUE_REGION :: 4
WL_SURFACE_SET_INPUT_REGION :: 5
WL_SURFACE_COMMIT :: 6
WL_SURFACE_SET_BUFFER_TRANSFORM :: 7
WL_SURFACE_SET_BUFFER_SCALE :: 8
WL_SURFACE_DAMAGE_BUFFER :: 9

wl_subcompositor_interface := WL_Interface{"wl_subcompositor", 1, 2, raw_data([]WL_Message{
	{"destroy", "", WL_NO_TYPES},
	{"get_subsurface", "noo", raw_data([]^WL_Interface{&wl_subsurface_interface, &wl_surface_interface, &wl_surface_interface})},
}), 0, nil}

WL_SUBCOMPOSITOR_DESTROY :: 0
WL_SUBCOMPOSITOR_GET_SUBSURFACE :: 1

wl_subsurface_interface := WL_Interface{"wl_subsurface", 1, 6, raw_data([]WL_Message{
	{"destroy", "", WL_NO_TYPES},
	{"set_position", "ii", WL_NO_TYPES},
	{"place_above", "o", raw_data([]^WL_Interface{&wl_surface_interface})},
	{"place_below", "o", raw_data([]^WL_Interface{&wl_surface_interface})},
	{"set_sync", "", WL_NO_TYPES},
	{"set_desync", "", WL_NO_TYPES},
}), 0, nil}

WL_SUBSURFACE_DESTROY :: 0
WL_SUBSURFACE_SET_POSITION :: 1
WL_SUBSURFACE_PLACE_ABOVE :: 2
WL_SUBSURFACE_PLACE_BELOW :: 3
WL_SUBSURFACE_SET_SYNC :: 4
WL_SUBSURFACE_SET_DESYNC :: 5

wl_shm_interface := WL_Interface{"wl_shm", 1, 1, raw_data([]WL_Message{
	{"create_pool", "nhi", raw_data([]^WL_Interface{&wl_shm_pool_interface, nil, nil})},
}), 1, raw_data([]WL_Message{
	{"format", "u", WL_NO_TYPES},
})}

WL_SHM_CREATE_POOL :: 0

wl_shm_pool_interface := WL_Interface{"wl_shm_pool", 1, 3, raw_data([]WL_Message{
	{"create_buffer", "niiiiu", raw_data([]^WL_Interface{&wl_buffer_interface, nil, nil, nil, nil, nil})},
	{"destroy", "", WL_NO_TYPES},
	{"resize", "i", WL_NO_TYPES},
}), 0, nil}

WL_SHM_POOL_CREATE_BUFFER :: 0
WL_SHM_POOL_DESTROY :: 1
WL_SHM_POOL_RESIZE :: 2

wl_seat_interface := WL_Interface{"wl_seat", 5, 4, raw_data([]WL_Message{
	{"get_pointer", "n", raw_data([]^WL_Interface{&wl_pointer_interface})},
	{"get_keyboard", "n", raw_data([]^WL_Interface{&wl_keyboard_interface})},
	{"get_touch", "n", raw_data([]^WL_Interface{&wl_touch_interface})},
	{"release", "5", WL_NO_TYPES},
}), 2, raw_data([]WL_Message{
	{"capabilities", "u", WL_NO_TYPES},
	{"name", "2s", WL_NO_TYPES},
})}

WL_SEAT_GET_POINTER :: 0
WL_SEAT_GET_KEYBOARD :: 1
WL_SEAT_GET_TOUCH :: 2
WL_SEAT_RELEASE :: 3

wl_pointer_interface := WL_Interface{"wl_pointer", 5, 2, raw_data([]WL_Message{
	{"set_cursor", "u?oii", raw_data([]^WL_Interface{nil, &wl_surface_interface, nil, nil})},
	{"release", "3", WL_NO_TYPES},
}), 9, raw_data([]WL_Message{
	{"enter", "uoff", raw_data([]^WL_Interface{nil, &wl_surface_interface, nil, nil})},
	{"leave", "uo", raw_data([]^WL_Interface{nil, &wl_surface_interface})},
	{"motion", "uff", WL_NO_TYPES},
	{"button", "uuuu", WL_NO_TYPES},
	{"axis", "uuf", WL_NO_TYPES},
	{"frame", "5", WL_NO_TYPES},
	{"axis_source", "5u", WL_NO_TYPES},
	{"axis_stop", "5uu", WL_NO_TYPES},
	{"axis_discrete", "5ui", WL_NO_TYPES},
})}

WL_POINTER_SET_CURSOR :: 0
WL_POINTER_RELEASE :: 1

wl_keyboard_interface := WL_Interface{"wl_keyboard", 5, 1, raw_data([]WL_Message{
	{"release", "3", WL_NO_TYPES},
}), 6, raw_data([]WL_Message{
	{"keymap", "uhu", WL_NO_TYPES},
	{"enter", "uoa", raw_data([]^WL_Interface{nil, &wl_surface_interface, nil})},
	{"leave", "uo", raw_data([]^WL_Interface{nil, &wl_surface_interface})},
	{"key", "uuuu", WL_NO_TYPES},
	{"modifiers", "uuuuu", WL_NO_TYPES},
	{"repeat_info", "4ii", WL_NO_TYPES},
})}

WL_KEYBOARD_RELEASE :: 0

wl_touch_interface := WL_Interface{"wl_touch", 5, 1, raw_data([]WL_Message{
	{"release", "3", WL_NO_TYPES},
}), 0, nil}

WL_TOUCH_RELEASE :: 0

wl_output_interface := WL_Interface{"wl_output", 3, 1, raw_data([]WL_Message{
	{"release", "3", WL_NO_TYPES},
}), 4, raw_data([]WL_Message{
	{"geometry", "iiiiissi", WL_NO_TYPES},
	{"mode", "uiii", WL_NO_TYPES},
	{"done", "2", WL_NO_TYPES},
	{"scale", "2i", WL_NO_TYPES},
})}

WL_OUTPUT_RELEASE :: 0

wl_data_device_manager_interface := WL_Interface{"wl_data_device_manager", 3, 2, raw_data([]WL_Message{
	{"create_data_source", "n", raw_data([]^WL_Interface{&wl_data_source_interface})},
	{"get_data_device", "no", raw_data([]^WL_Interface{&wl_data_device_interface, &wl_seat_interface})},
}), 0, nil}

WL_DATA_DEVICE_MANAGER_CREATE_DATA_SOURCE :: 0
WL_DATA_DEVICE_MANAGER_GET_DATA_DEVICE :: 1

wl_data_source_interface := WL_Interface{"wl_data_source", 3, 3, raw_data([]WL_Message{
	{"offer", "s", WL_NO_TYPES},
	{"destroy", "", WL_NO_TYPES},
	{"set_actions", "3u", WL_NO_TYPES},
}), 6, raw_data([]WL_Message{
	{"target", "?s", WL_NO_TYPES},
	{"send", "sh", WL_NO_TYPES},
	{"cancelled", "", WL_NO_TYPES},
	{"dnd_drop_performed", "3", WL_NO_TYPES},
	{"dnd_finished", "3", WL_NO_TYPES},
	{"action", "3u", WL_NO_TYPES},
})}

WL_DATA_SOURCE_OFFER :: 0
WL_DATA_SOURCE_DESTROY :: 1
WL_DATA_SOURCE_SET_ACTIONS :: 2

wl_data_offer_interface := WL_Interface{"wl_data_offer", 3, 5, raw_data([]WL_Message{
	{"accept", "u?s", WL_NO_TYPES},
	{"receive", "sh", WL_NO_TYPES},
	{"destroy", "", WL_NO_TYPES},
	{"finish", "3", WL_NO_TYPES},
	{"set_actions", "3uu", WL_NO_TYPES},
}), 3, raw_data([]WL_Message{
	{"offer", "s", WL_NO_TYPES},
	{"source_actions", "3u", WL_NO_TYPES},
	{"action", "3u", WL_NO_TYPES},
})}

WL_DATA_OFFER_ACCEPT :: 0
WL_DATA_OFFER_RECEIVE :: 1
WL_DATA_OFFER_DESTROY :: 2
WL_DATA_OFFER_FINISH :: 3
WL_DATA_OFFER_SET_ACTIONS :: 4

wl_data_device_interface := WL_Interface{"wl_data_device", 3, 3, raw_data([]WL_Message{
	{"start_drag", "?oo?ou", raw_data([]^WL_Interface{&wl_data_source_interface, &wl_surface_interface, &wl_surface_interface, nil})},
	{"set_selection", "?ou", raw_data([]^WL_Interface{&wl_data_source_interface, nil})},
	{"release", "2", WL_NO_TYPES},
}), 6, raw_data([]WL_Message{
	{"data_offer", "n", raw_data([]^WL_Interface{&wl_data_offer_interface})},
	{"enter", "uoff?o", raw_data([]^WL_Interface{nil, &wl_surface_interface, nil, nil, &wl_data_offer_interface})},
	{"leave", "", WL_NO_TYPES},
	{"motion", "uff", WL_NO_TYPES},
	{"drop", "", WL_NO_TYPES},
	{"selection", "?o", raw_data([]^WL_Interface{&wl_data_offer_interface})},
})}

WL_DATA_DEVICE_START_DRAG :: 0
WL_DATA_DEVICE_SET_SELECTION :: 1
WL_DATA_DEVICE_RELEASE :: 2

wl_viewporter_interface := WL_Interface{"wp_viewporter", 1, 2, raw_data([]WL_Message{
	{"destroy", "", WL_NO_TYPES},
	{"get_viewport", "no", raw_data([]^WL_Interface{&wl_viewport_interface, &wl_surface_interface})},
}), 0, nil}

WL_VIEWPORTER_DESTROY :: 0
WL_VIEWPORTER_GET_VIEWPORT :: 1

wl_viewport_interface := WL_Interface{"wp_viewport", 1, 3, raw_data([]WL_Message{
	{"destroy", "", WL_NO_TYPES},
	{"set_source", "ffff", WL_NO_TYPES},
	{"set_destination", "ii", WL_NO_TYPES},
}), 0, nil}

WL_VIEWPORT_DESTROY :: 0
WL_VIEWPORT_SET_SOURCE :: 1
WL_VIEWPORT_SET_DESTINATION :: 2

wl_layer_shell_interface := WL_Interface{"zwlr_layer_shell_v1", 4, 2, raw_data([]WL_Message{
	{"get_layer_surface", "no?ous", raw_data([]^WL_Interface{&wl_layer_surface_interface, &wl_surface_interface, &wl_output_interface, nil, nil})},
	{"destroy", "3", WL_NO_TYPES},
}), 0, nil}

WL_LAYER_SHELL_GET_LAYER_SURFACE :: 0
WL_LAYER_SHELL_DESTROY :: 1

wl_layer_surface_interface := WL_Interface{"zwlr_layer_surface_v1", 4, 9, raw_data([]WL_Message{
	{"set_size", "uu", WL_NO_TYPES},
	{"set_anchor", "u", WL_NO_TYPES},
	{"set_exclusive_zone", "i", WL_NO_TYPES},
	{"set_margin", "iiii", WL_NO_TYPES},
	{"set_keyboard_interactivity", "u", WL_NO_TYPES},
	{"get_popup", "o", raw_data([]^WL_Interface{nil})},
	{"ack_configure", "u", WL_NO_TYPES},
	{"destroy", "", WL_NO_TYPES},
	{"set_layer", "2u", WL_NO_TYPES},
}), 2, raw_data([]WL_Message{
	{"configure", "uuu", WL_NO_TYPES},
	{"closed", "", WL_NO_TYPES},
})}

WL_LAYER_SURFACE_SET_SIZE :: 0
WL_LAYER_SURFACE_SET_ANCHOR :: 1
WL_LAYER_SURFACE_SET_EXCLUSIVE_ZONE :: 2
WL_LAYER_SURFACE_SET_MARGIN :: 3
WL_LAYER_SURFACE_SET_KEYBOARD_INTERACTIVITY :: 4
WL_LAYER_SURFACE_GET_POPUP :: 5
WL_LAYER_SURFACE_ACK_CONFIGURE :: 6
WL_LAYER_SURFACE_DESTROY :: 7
WL_LAYER_SURFACE_SET_LAYER :: 8

wl_screencopy_manager_interface := WL_Interface{"zwlr_screencopy_manager_v1", 3, 3, raw_data([]WL_Message{
	{"capture_output", "nio", raw_data([]^WL_Interface{&wl_screencopy_frame_interface, nil, &wl_output_interface})},
	{"capture_output_region", "nioiiii", raw_data([]^WL_Interface{&wl_screencopy_frame_interface, nil, &wl_output_interface, nil, nil, nil, nil})},
	{"destroy", "", WL_NO_TYPES},
}), 0, nil}

WL_SCREENCOPY_MANAGER_CAPTURE_OUTPUT :: 0
WL_SCREENCOPY_MANAGER_CAPTURE_OUTPUT_REGION :: 1
WL_SCREENCOPY_MANAGER_DESTROY :: 2

wl_screencopy_frame_interface := WL_Interface{"zwlr_screencopy_frame_v1", 3, 3, raw_data([]WL_Message{
	{"copy", "o", raw_data([]^WL_Interface{&wl_buffer_interface})},
	{"destroy", "", WL_NO_TYPES},
	{"copy_with_damage", "2o", raw_data([]^WL_Interface{&wl_buffer_interface})},
}), 7, raw_data([]WL_Message{
	{"buffer", "uuuu", WL_NO_TYPES},
	{"flags", "u", WL_NO_TYPES},
	{"ready", "uuu", WL_NO_TYPES},
	{"failed", "", WL_NO_TYPES},
	{"damage", "2uuuu", WL_NO_TYPES},
	{"linux_dmabuf", "3uuu", WL_NO_TYPES},
	{"buffer_done", "3", WL_NO_TYPES},
})}

WL_SCREENCOPY_FRAME_COPY :: 0
WL_SCREENCOPY_FRAME_DESTROY :: 1
WL_SCREENCOPY_FRAME_COPY_WITH_DAMAGE :: 2

wl_fractional_scale_manager_interface := WL_Interface{"wp_fractional_scale_manager_v1", 1, 2, raw_data([]WL_Message{
	{"destroy", "", WL_NO_TYPES},
	{"get_fractional_scale", "no", raw_data([]^WL_Interface{&wl_fractional_scale_interface, &wl_surface_interface})},
}), 0, nil}

WL_FRACTIONAL_SCALE_MANAGER_DESTROY :: 0
WL_FRACTIONAL_SCALE_MANAGER_GET_FRACTIONAL_SCALE :: 1

wl_fractional_scale_interface := WL_Interface{"wp_fractional_scale_v1", 1, 1, raw_data([]WL_Message{
	{"destroy", "", WL_NO_TYPES},
}), 1, raw_data([]WL_Message{
	{"preferred_scale", "u", WL_NO_TYPES},
})}

WL_FRACTIONAL_SCALE_DESTROY :: 0

wl_bind :: proc(registry: ^WL_Proxy, name: u32, interface: ^WL_Interface, version: u32) -> ^WL_Proxy {
	v := min(version, u32(interface.version))
	return wl_proxy_marshal_flags(registry, WL_REGISTRY_BIND, interface, v, 0, name, interface.name, v, nil)
}

WL_Callback_Listener :: struct {
	done: proc "c" (data: rawptr, callback: ^WL_Proxy, callback_data: u32),
}

WL_Fractional_Scale_Listener :: struct {
	preferred_scale: proc "c" (data: rawptr, fractional_scale: ^WL_Proxy, scale: u32),
}

WL_Registry_Listener :: struct {
	global:        proc "c" (data: rawptr, registry: ^WL_Proxy, name: u32, interface: cstring, version: u32),
	global_remove: proc "c" (data: rawptr, registry: ^WL_Proxy, name: u32),
}

WL_Seat_Listener :: struct {
	capabilities: proc "c" (data: rawptr, seat: ^WL_Proxy, capabilities: u32),
	name:         proc "c" (data: rawptr, seat: ^WL_Proxy, name: cstring),
}

WL_Output_Listener :: struct {
	geometry: proc "c" (data: rawptr, output: ^WL_Proxy, x, y, physical_width, physical_height, subpixel: i32, make, model: cstring, transform: i32),
	mode:     proc "c" (data: rawptr, output: ^WL_Proxy, flags: u32, width, height, refresh: i32),
	done:     proc "c" (data: rawptr, output: ^WL_Proxy),
	scale:    proc "c" (data: rawptr, output: ^WL_Proxy, factor: i32),
}

WL_Surface_Listener :: struct {
	enter: proc "c" (data: rawptr, surface: ^WL_Proxy, output: ^WL_Proxy),
	leave: proc "c" (data: rawptr, surface: ^WL_Proxy, output: ^WL_Proxy),
}

WL_Layer_Surface_Listener :: struct {
	configure: proc "c" (data: rawptr, layer_surface: ^WL_Proxy, serial, width, height: u32),
	closed:    proc "c" (data: rawptr, layer_surface: ^WL_Proxy),
}

WL_Buffer_Listener :: struct {
	release: proc "c" (data: rawptr, buffer: ^WL_Proxy),
}

WL_Pointer_Listener :: struct {
	enter:         proc "c" (data: rawptr, pointer: ^WL_Proxy, serial: u32, surface: ^WL_Proxy, x, y: WL_Fixed),
	leave:         proc "c" (data: rawptr, pointer: ^WL_Proxy, serial: u32, surface: ^WL_Proxy),
	motion:        proc "c" (data: rawptr, pointer: ^WL_Proxy, time: u32, x, y: WL_Fixed),
	button:        proc "c" (data: rawptr, pointer: ^WL_Proxy, serial, time, button, state: u32),
	axis:          proc "c" (data: rawptr, pointer: ^WL_Proxy, time, axis: u32, value: WL_Fixed),
	frame:         proc "c" (data: rawptr, pointer: ^WL_Proxy),
	axis_source:   proc "c" (data: rawptr, pointer: ^WL_Proxy, axis_source: u32),
	axis_stop:     proc "c" (data: rawptr, pointer: ^WL_Proxy, time, axis: u32),
	axis_discrete: proc "c" (data: rawptr, pointer: ^WL_Proxy, axis: u32, discrete: i32),
}

WL_Keyboard_Listener :: struct {
	keymap:      proc "c" (data: rawptr, keyboard: ^WL_Proxy, format: u32, fd: i32, size: u32),
	enter:       proc "c" (data: rawptr, keyboard: ^WL_Proxy, serial: u32, surface: ^WL_Proxy, keys: rawptr),
	leave:       proc "c" (data: rawptr, keyboard: ^WL_Proxy, serial: u32, surface: ^WL_Proxy),
	key:         proc "c" (data: rawptr, keyboard: ^WL_Proxy, serial, time, key, state: u32),
	modifiers:   proc "c" (data: rawptr, keyboard: ^WL_Proxy, serial, depressed, latched, locked, group: u32),
	repeat_info: proc "c" (data: rawptr, keyboard: ^WL_Proxy, rate, delay: i32),
}

WL_Data_Device_Listener :: struct {
	data_offer: proc "c" (data: rawptr, data_device: ^WL_Proxy, offer: ^WL_Proxy),
	enter:      proc "c" (data: rawptr, data_device: ^WL_Proxy, serial: u32, surface: ^WL_Proxy, x, y: WL_Fixed, offer: ^WL_Proxy),
	leave:      proc "c" (data: rawptr, data_device: ^WL_Proxy),
	motion:     proc "c" (data: rawptr, data_device: ^WL_Proxy, time: u32, x, y: WL_Fixed),
	drop:       proc "c" (data: rawptr, data_device: ^WL_Proxy),
	selection:  proc "c" (data: rawptr, data_device: ^WL_Proxy, offer: ^WL_Proxy),
}

WL_Data_Source_Listener :: struct {
	target:             proc "c" (data: rawptr, source: ^WL_Proxy, mime_type: cstring),
	send:               proc "c" (data: rawptr, source: ^WL_Proxy, mime_type: cstring, fd: i32),
	cancelled:          proc "c" (data: rawptr, source: ^WL_Proxy),
	dnd_drop_performed: proc "c" (data: rawptr, source: ^WL_Proxy),
	dnd_finished:       proc "c" (data: rawptr, source: ^WL_Proxy),
	action:             proc "c" (data: rawptr, source: ^WL_Proxy, action: u32),
}

WL_Screencopy_Frame_Listener :: struct {
	buffer:       proc "c" (data: rawptr, frame: ^WL_Proxy, format, width, height, stride: u32),
	flags:        proc "c" (data: rawptr, frame: ^WL_Proxy, flags: u32),
	ready:        proc "c" (data: rawptr, frame: ^WL_Proxy, tv_sec_hi, tv_sec_lo, tv_nsec: u32),
	failed:       proc "c" (data: rawptr, frame: ^WL_Proxy),
	damage:       proc "c" (data: rawptr, frame: ^WL_Proxy, x, y, width, height: u32),
	linux_dmabuf: proc "c" (data: rawptr, frame: ^WL_Proxy, format, width, height: u32),
	buffer_done:  proc "c" (data: rawptr, frame: ^WL_Proxy),
}

wl_noop :: proc "c" () {}

wl_listen :: proc "contextless" (p: ^WL_Proxy, listener: ^$T) {
	fns := ([^]rawptr)(listener)
	for i in 0 ..< size_of(T) / size_of(rawptr) {
		if fns[i] == nil {
			fns[i] = rawptr(wl_noop)
		}
	}
	wl_proxy_add_listener(p, listener, nil)
}
