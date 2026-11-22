module pyscene;
import python;

alias p = module python;

struct PySceneModule {
	PyModule base;
}

fn int PySceneModule.init(&this, PyMachine* m) {
	if (this.base.init(m, "scene_server", null) != 0) {
		return -1;
	}

	PyFunc* f = this.base.funcs.get("start")!!;
	PyObject* result = f.call();
	if (!result) {
		p::pyErr_Print();
		return -1;
	}

	p::py_DecRef(result);
	return 0;
}

fn int PySceneModule.think(&this) {
	if (!this.base.isInit) return -1;

	PyFunc* f = this.base.funcs.get("think")!!;
	PyObject* result = f.call();
	if (!result) {
		p::pyErr_Print();
		return -1;
	}

	p::py_DecRef(result);
	return 0;
}

fn int PySceneModule.add_vertices(&this, double[] vertices) {
	if (!this.base.isInit) return -1;

	PyFunc* f = this.base.funcs.get("add_vertices")!!;
	PyObject* result = f.call(&vertices);
	if (!result) {
		p::pyErr_Print();
		return -1;
	}

	p::py_DecRef(result);
	return 0;
}

fn int PySceneModule.shutDown(&this) {
	if (!this.base.isInit) return 0;

	PyFunc* f = this.base.funcs.get("stop")!!;
	PyObject* result = f.call();
	if (!result) {
		p::pyErr_Print();
		return -1;
	}

	p::py_DecRef(result);
	this.base.isInit = 0;
	return 0;
}
