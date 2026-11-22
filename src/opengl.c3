import std::os::win32;
alias Hglrc	= usz;

const uint GL_COLOR_BUFFER_BIT	= 0x00004000;
const uint GL_TRIANGLES			= 0x0004;

extern fn bool wglMakeCurrent(
	Win32_HDC hdc,
	Hglrc hglrc
)
@cname("wglMakeCurrent");

extern fn Hglrc wglCreateContext(
	Win32_HDC hdc
)
@cname("wglCreateContext");

extern fn bool wglDeleteContext(
	Hglrc hglrc
)
@cname("wglDeleteContext");

extern fn void* wglGetProcAddress(
	char* funcname
)
@cname("wglGetProcAddress");

extern fn void glViewport
(
	int x,
	int y,
	int h,
	int w
)
@cname("glViewport");

extern fn void glClear(
	uint mask
)
@cname("glClear");

extern fn void glBegin(
	uint mode
)
@cname("glBegin");

extern fn void glColor3f(
	float red,
	float green,
	float blue
)
@cname("glColor3f");

extern fn void glVertex2i(
	int x,
	int y
)
@cname("glVertex2i");

extern fn void glEnd()
@cname("glEnd");

extern fn void glFlush()
@cname("glFlush");