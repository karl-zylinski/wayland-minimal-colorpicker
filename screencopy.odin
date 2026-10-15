package minimal_colorpicker

SCREENCOPY_SIZE :: 1024

Screencopy_Frame_State :: enum {
	Waiting,
	Ready,
	Failed,
}

screencopy_manager: ^WL_Proxy
screencopy_frame_state: Screencopy_Frame_State
screencopy_format, screencopy_width, screencopy_height, screencopy_stride: u32
screencopy_has_shm: bool
screencopy_flags: u32
screencopy_buffer: ^WL_Proxy

screencopy_request_copy :: proc "c" (frame: ^WL_Proxy) {
	if !screencopy_has_shm || screencopy_stride * screencopy_height > SCREENCOPY_SIZE {
		screencopy_frame_state = .Failed
		return
	}
	screencopy_buffer = wl_proxy_marshal_flags(shm_pool, 0, &wl_buffer_interface, wl_proxy_get_version(shm_pool), 0, nil, i32(SCREENCOPY_OFFSET), i32(screencopy_width), i32(screencopy_height), i32(screencopy_stride), screencopy_format)
	wl_proxy_marshal_flags(frame, 0, nil, wl_proxy_get_version(frame), 0, screencopy_buffer)
}

screencopy_on_buffer :: proc "c" (data: rawptr, frame: ^WL_Proxy, format, width, height, stride: u32) {
	screencopy_format = format
	screencopy_width = width
	screencopy_height = height
	screencopy_stride = stride
	screencopy_has_shm = true
	if wl_proxy_get_version(frame) < 3 {
		screencopy_request_copy(frame)
	}
}

screencopy_on_flags :: proc "c" (data: rawptr, frame: ^WL_Proxy, flags: u32) {
	screencopy_flags = flags
}

screencopy_on_buffer_done :: proc "c" (data: rawptr, frame: ^WL_Proxy) {
	screencopy_request_copy(frame)
}

screencopy_on_ready :: proc "c" (data: rawptr, frame: ^WL_Proxy, tv_sec_hi, tv_sec_lo, tv_nsec: u32) {
	screencopy_frame_state = .Ready
}

screencopy_on_failed :: proc "c" (data: rawptr, frame: ^WL_Proxy) {
	screencopy_frame_state = .Failed
}

screencopy_frame_listener := WL_Screencopy_Frame_Listener {
	buffer      = screencopy_on_buffer,
	flags       = screencopy_on_flags,
	ready       = screencopy_on_ready,
	failed      = screencopy_on_failed,
	buffer_done = screencopy_on_buffer_done,
}

screencopy_pixel :: proc(output: ^WL_Proxy, x, y: i32, fx, fy: f32) -> (rgb: u32, ok: bool) {
	screencopy_frame_state = .Waiting
	screencopy_has_shm = false
	screencopy_flags = 0
	screencopy_buffer = nil

	frame := wl_proxy_marshal_flags(screencopy_manager, 1, &wl_screencopy_frame_interface, wl_proxy_get_version(screencopy_manager), 0, nil, i32(0), output, x, y, i32(1), i32(1))
	wl_listen(frame, &screencopy_frame_listener)

	for screencopy_frame_state == .Waiting {
		if wl_display_dispatch(display) == -1 {
			return 0, false
		}
	}

	wl_proxy_marshal_flags(frame, 1, nil, wl_proxy_get_version(frame), WL_MARSHAL_FLAG_DESTROY)
	if screencopy_buffer != nil {
		wl_proxy_marshal_flags(screencopy_buffer, 0, nil, wl_proxy_get_version(screencopy_buffer), WL_MARSHAL_FLAG_DESTROY)
	}
	if screencopy_frame_state != .Ready {
		return 0, false
	}

	ix := min(int(fx * f32(screencopy_width)), int(screencopy_width) - 1)
	iy := min(int(fy * f32(screencopy_height)), int(screencopy_height) - 1)
	if screencopy_flags & WL_SCREENCOPY_FRAME_FLAGS_Y_INVERT != 0 {
		iy = int(screencopy_height) - 1 - iy
	}
	px := pool_memory[(SCREENCOPY_OFFSET + iy * int(screencopy_stride) + ix * 4) / 4]
	switch screencopy_format {
	case WL_SHM_FORMAT_ARGB8888, WL_SHM_FORMAT_XRGB8888:
		rgb = px & 0xFFFFFF
	case WL_SHM_FORMAT_ABGR8888, WL_SHM_FORMAT_XBGR8888:
		rgb = ((px & 0xFF) << 16) | (px & 0xFF00) | ((px >> 16) & 0xFF)
	case WL_SHM_FORMAT_ARGB2101010, WL_SHM_FORMAT_XRGB2101010:
		rgb = (((px >> 22) & 0xFF) << 16) | (((px >> 12) & 0xFF) << 8) | ((px >> 2) & 0xFF)
	case WL_SHM_FORMAT_ABGR2101010, WL_SHM_FORMAT_XBGR2101010:
		rgb = (((px >> 2) & 0xFF) << 16) | (((px >> 12) & 0xFF) << 8) | ((px >> 22) & 0xFF)
	case:
		return 0, false
	}
	return rgb, true
}
