module pymeshio;
import python;
import std::io;
import std::core::mem;

alias p = module python;
alias PyMath_sqrt_fn = fn double(double);

struct PyPymeshioModule {
	PyModule pmx_reader;
}

const ZString SCRIPT =
`
from pymeshio.pmd import reader as pmd_reader

model = pmd_reader.read_from_file(path)
vlist = []
if model:
	print(f"Название модели: {model.name}")
	print(f"Количество вершин: {len(model.vertices)}")
	print(f"Количество костей: {len(model.bones)}")

	for index in model.indices:
		v = model.vertices[index]
		vlist.extend((v.pos.x, v.pos.y, v.pos.z, v.normal.x, v.normal.y, v.normal.z, v.uv.x, v.uv.y))
`;

fn int PyPymeshioModule.init(&this, PyMachine* m) {
	this.pmx_reader.init(m, "pymeshio.pmx.reader", null);
	return 0;
}

fn double[] PyPymeshioModule.getVertices(&this, ZString path) {
	if(!this.pmx_reader.isInit) { return {}; }

	PyObject* pDict = p::pyModule_GetDict(this.pmx_reader.pModule);
	if (!pDict) {
		p::pyErr_Print();
		return {};
	}

	PyObject* pPath = p::pyUnicode_FromStringAndSize(path, path.len());
	p::pyDict_SetItemString(pDict, "path", pPath);
	p::py_DecRef(pPath);

	PyObject* pRes = p::pyRun_String(SCRIPT, p::PY_FILE_INPUT, pDict, pDict);
	if (!pRes) {
		p::pyErr_Print();
		return {};
	}
	p::py_DecRef(pRes);

	PyObject* pList = p::pyRun_String("vlist", 258, pDict, pDict);
	if (!pList) {
		p::pyErr_Print();
		return {};
	}
	defer p::py_DecRef(pList);

	sz count = p::pyList_Size(pList);
	if (count <= 0) {
		p::pyErr_Print();
		return {};
	}

	double[] vertices = mem::new_array(double, count);
	for (sz i = 0; i < count; i++) {
		PyObject* item = p::pyList_GetItem(pList, i);
		if (!item) {
			p::pyErr_Print();
			mem::free(vertices.ptr);
			return {};
		}
		vertices[i] = p::pyFloat_AsDouble(item);
		if (p::pyErr_Occurred()) {
			p::pyErr_Print();
			mem::free(vertices.ptr);
			return {};
		}
	}

	return vertices;
}

/*
fn double PyMathModule.sqrt(&this, double num) {
	if (!this.base.isInit) return -1.0;

	PyFunc* f = this.base.funcs.get("sqrt")!!;
	PyObject* pValue = f.call(&num);
	if (!pValue) {
		p::pyErr_Print();
		return -1.0;
	}

	double result = p::pyFloat_AsDouble(pValue);
	p::py_DecRef(pValue);
	return result;
}
*/