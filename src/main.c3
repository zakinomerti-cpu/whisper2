import python;
import pyscene;
import pymeshio;
import std::io;
import std::core::mem;
import libc;

bool keep_running = true;

fn void handle_sigint(int sig)
{
	io::printn("ctrl+c pressed");
	keep_running = false;
}

fn ZString get_python_lib_name()
{
    $if env::WIN32:
        return "python314.dll";
    $else
        return "libpython3.14.so";
    $endif
}

fn int main(String[] args)
{
	PyMachine m;
	if (m.init(get_python_lib_name()) != 0) {
		io::printn("Failed to initialize Python");
		return 1;
	}

	PySceneModule scene;
	if (scene.init(&m) != 0) {
		io::printn("Failed to initialize scene server");
		m.shutDown();
		return 1;
	}

	PyPymeshioModule pmio;
	if(pmio.init(&m) != 0) {
		io::printn("Failed to initialize pymeshio");
		scene.shutDown();
		m.shutDown();
		return 1;
	}

	double[] vertices = pmio.getVertices("C://projects//whisper//resources//miku.pmd");
	defer mem::free(vertices.ptr);
	if (!vertices.len || vertices.len % 24 != 0) {
		io::printn("Failed to load PMD vertices");
		scene.shutDown();
		m.shutDown();
		return 1;
	}

	if (scene.set_vertices(vertices) != 0) {
		io::printn("Failed to send PMD vertices");
		scene.shutDown();
		m.shutDown();
		return 1;
	}

	libc::signal(libc::SIGINT, &handle_sigint);

	io::printfn("PMD loaded: %d vertices. Open http://127.0.0.1:8000", vertices.len / 8);
	io::printn("Press Ctrl + C to stop the scene server");

	int exit_code = 0;
	while (keep_running) {
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
