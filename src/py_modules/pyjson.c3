module pyjson;
import python;
import std::io;
import std::core::mem;

alias p = module python;

const int PY_FILE_INPUT = 257;

const ZString JSON_SCRIPT =
`
import json

def parse_and_format(raw_str):
    try:
        data = json.loads(raw_str)
        # Разбираем на составляющие в зависимости от типа
        if isinstance(data, dict):
            parts = [f"{k} ({type(v).__name__}): {v}" for k, v in data.items()]
            return "DICT -> " + "; ".join(parts)
        elif isinstance(data, list):
            parts = [f"[{i}]={v}" for i, v in enumerate(data)]
            return "LIST -> " + ", ".join(parts)
        else:
            return f"VALUE ({type(data).__name__}) -> {data}"
    except Exception as e:
        return f"JSON_ERROR: {str(e)}"
`;

struct PyJsonModule {
	PyModule base;
}

fn int PyJsonModule.init(&this, PyMachine* m) {
	if (this.base.init(m, "json", null) != 0) {
		return -1;
	}

	PyObject* pDict = p::pyModule_GetDict(this.base.pModule);
	if (!pDict) {
		p::pyErr_Print();
		return -1;
	}

	PyObject* pRes = p::pyRun_String(JSON_SCRIPT, PY_FILE_INPUT, pDict, pDict);
	if (!pRes) {
		p::pyErr_Print();
		return -1;
	}
	p::py_DecRef(pRes);

	PyObject* pFuncObj = p::pyObject_GetAttrString(this.base.pModule, "parse_and_format");
	if (!pFuncObj || !p::pyCallable_Check(pFuncObj)) {
		p::pyErr_Print();
		return -1;
	}

	PyFunc* custom_func = mem::new(PyFunc);
	custom_func.name = "parse_and_format";
	custom_func.pf = pFuncObj;
	custom_func.func = null;
	custom_func.isInit = 1;

	this.base.funcs.set("parse_and_format", custom_func);

	return 0;
}

fn ZString PyJsonModule.parse_json(&this, String raw_json) {
	if (!this.base.isInit) { 
		return null; 
	}

	ZString result = null;

	PyFunc* f = this.base.funcs.get("parse_and_format")!!;
	if (!f || !f.isInit) {
		return null;
	}

	PyObject* pFunc = f.pf;
	PyObject* pArgs = p::pyTuple_New(1);
	PyObject* pArg0 = p::pyUnicode_FromStringAndSize(raw_json.ptr, raw_json.len);
	p::pyTuple_SetItem(pArgs, 0, pArg0);

	PyObject* pValue = p::pyObject_CallObject(pFunc, pArgs);
	if (pValue) {
		char* utf8_ptr = p::pyUnicode_AsUTF8(pValue);
		if (utf8_ptr) {

			result = (ZString)mem::malloc(((ZString)utf8_ptr).len()+1);
			mem::copy(result, utf8_ptr, ((ZString)utf8_ptr).len()+1);
		}
		p::py_DecRef(pValue);
	} else {
		p::pyErr_Print();
	}

	p::py_DecRef(pArgs);
	return result;
}
