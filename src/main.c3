import python;
import pyscene;
import std::io;
import std::os::win32;

const CInt VK_ESCAPE = 0x1B;

extern fn short getAsyncKeyState(CInt vKey) @cname("GetAsyncKeyState");

fn void onChromiumAction(ZString a)
{
	io::printfn("action: %s", a);
}

fn int main(String[] args)
{
	PyMachine m;
	if (m.init("C:/Python314/python314.dll") != 0) {
		io::printn("Failed to initialize Python");
		return 1;
	}

	PySceneModule scene;
	if (scene.init(&m) != 0) {
		io::printn("Failed to initialize scene server");
		m.shutDown();
		return 1;
	}

	double[] triangle = {
		-0.5, -0.5, 2.0,  0.0, 0.0, 1.0,  0.0, 0.0,
		 0.5, -0.5, 2.0,  0.0, 0.0, 1.0,  1.0, 0.0,
		 0.0,  0.12, 2.0,  0.0, 0.0, 1.0,  0.5, 1.0,
	};

	if (scene.add_vertices(triangle) != 0) {
		io::printn("Failed to add triangle");
		scene.shutDown();
		m.shutDown();
		return 1;
	}

	io::printn("Triangle added. Open http://127.0.0.1:8000");
	io::printn("Press Escape to stop the scene server");

	int exit_code = 0;
	while ((getAsyncKeyState(VK_ESCAPE) & 0x8000) == 0) {
		if (scene.think() != 0) {
			io::printn("Scene server think failed");
			exit_code = 1;
			break;
		}
	}

	scene.shutDown();
	m.shutDown();
	return exit_code;
}
