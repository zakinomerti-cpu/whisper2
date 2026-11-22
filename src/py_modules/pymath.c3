module pymath;
import python;
import std::io;

alias p = module python;
alias PyMath_sqrt_fn = fn double(double);

struct PyMathModule {
	PyModule base;
}

fn int PyMathModule.init(&this, PyMachine* m) {
	this.base.init(m, "math", null);
	return 0;
}

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