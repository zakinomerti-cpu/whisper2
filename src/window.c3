module window;
import opengl;
import std::io;
import std::os::win32;

const uint WM_PAINT				= 15;
const uint WM_SIZE				= 5;
const uint WM_KEYDOWN			= 0x100;
const uint WM_DESTROY			= 2;
const uint COLOR_WINDOW			= 5;
const uint IDC_ARROW			= 32512;
const uint WS_OVERLAPPEDWINDOW	= 0x00cf0000;
const uint WS_VISIBLE			= 0x10000000;
const uint CW_USEDEFAULT		= 0x80000000;
const uint CS_OWNDC				= 0x20;

Win32_MSG msg;
void* raw_start_func = null;
void* raw_display_func = null;
alias RawFunc = fn void();


// global window handler
Window*	g_pWnd		= null;
Hglrc	g_hGlrc		= 0;



struct Mouse {
	int x;
	int y;
	int dx;
	int dy;
	int wheel;
	bool left;
	bool right;
	bool middle;
}

struct Window {
	uint posx;
	uint posy;
	uint width;
	uint height;
	Mouse mouse;
	ZString title;

	Win32_HDC hdc;
	Win32_HWND hwnd;
	bool shouldClose;
}

fn ushort loword(uptr value) {
	return (ushort)(value & 0xFFFF);
}
fn ushort hiword(uptr value) {
	return (ushort)((value >> 16) & 0xFFFF);
}

fn Win32_LRESULT wndproc
(
	Win32_HWND hwnd,
	Win32_UINT msg,
	Win32_WPARAM wp,
	Win32_LPARAM lp
)
{
	switch(msg) {
		case WM_DESTROY:
			win32::postQuitMessage(0);
			return 0;

		case WM_KEYDOWN:
			if(wp == 27) {
				win32::destroyWindow(hwnd);
				return 0;
			}

		case WM_SIZE:
			int width = loword((usz)lp);
			int height = hiword((usz)lp);
			opengl::glViewport(0, 0, width, height);


	}

	return win32::defWindowProcW(hwnd, msg, wp, lp);
}

fn int Window.create
(
	&this,
	uint width,
	uint height,
	ZString title
)
{

	if(g_pWnd) {
		io::printn("1 window per program!, error!");
		return 1;
	}

	Win32_WNDCLASSEXW wndclass;
	wndclass.style = CS_OWNDC;
	wndclass.cbSize = Win32_WNDCLASSEXW::size;
	wndclass.hInstance = win32::getModuleHandleW(null);
	wndclass.lpfnWndProc = &wndproc;
	wndclass.hbrBackground = (Win32_HBRUSH)(COLOR_WINDOW+1);
	wndclass.lpszClassName = @wstring("engine3");
	wndclass.hCursor = win32::loadCursorW((Win32_HINSTANCE)null, (Win32_LPCWSTR)IDC_ARROW);
	if(!win32::registerClassExW(&wndclass))
	{
		return 2;
	}

	this.hwnd = win32::createWindowExW(
		0,
		@wstring("engine3"),
		@wstring("приветственное окно"),
		win32::WS_OVERLAPPEDWINDOW|win32::WS_VISIBLE,
		(CInt)CW_USEDEFAULT,
		(CInt)CW_USEDEFAULT,
		800,
		800,
		null,
		null,
		null,
		null
	);

	Win32_PIXELFORMATDESCRIPTOR pfd;
	this.hdc =  win32::getDC((Win32_HWND)this.hwnd);
	pfd.nSize = Win32_PIXELFORMATDESCRIPTOR::size;
	pfd.nVersion = 1;
	pfd.cColorBits = 32;

	int pf = win32::choosePixelFormat(this.hdc, &pfd);
	win32::setPixelFormat(this.hdc, pf, &pfd);
	win32::describePixelFormat
	(
		this.hdc,
		pf,
		Win32_PIXELFORMATDESCRIPTOR::size,
		&pfd
	);

	g_hGlrc = opengl::wglCreateContext(this.hdc);
	opengl::wglMakeCurrent(this.hdc, g_hGlrc);
	g_pWnd = this;

	return 0;
}

fn void Window.update(&this) {
	while(win32::peekMessageW(&msg, null, 0, 0, 1)) {
		win32::translateMessage(&msg);
		win32::dispatchMessage(&msg);
		if(msg.message == win32::WM_QUIT) {
			this.shouldClose = true;
		}
	}
	if(raw_display_func) {
		RawFunc func = (RawFunc)raw_display_func;
		func();
	}
	win32::swapBuffers(this.hdc);
}

fn void Window.setDisplayFunc(&this, void* func) {
	raw_display_func = func;
}