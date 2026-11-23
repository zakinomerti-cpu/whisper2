module python;
import std::collections::map;
import std::core::mem;
import std::io;
import std::os;
import std::io::file;
import libc;



//-----------------------------------------------------------------------------
// data types
//-----------------------------------------------------------------------------
alias PyObject = void*;
alias PyModule_DestroyFn = fn void();

struct PyFunc {
	ZString name;
	PyObject* pf;
	void* func;
	int isInit;
}

struct PyModule {
	ZString name;
	PyObject* pModule;
	PyMachine* machine;
	HashMap{ZString,PyFunc*} funcs;
	PyModule_DestroyFn df;
	int isInit;
}

struct PyMachine {
	ZString runtime_version;
	HashMap{ZString,PyModule*} mdls;
	int running;
	int isInit;
}



//-----------------------------------------------------------------------------
// globals
//-----------------------------------------------------------------------------
PyMachine* g_pPyMachine = null;
DylibHandle g_hPyDLL;
ZString[] pyFuncs = {
	"PyImport_ImportModule",
	"Py_Initialize",
};



//-----------------------------------------------------------------------------
// constants
//-----------------------------------------------------------------------------
const int PY_FILE_INPUT = 257;



//-----------------------------------------------------------------------------
// extern functions
//-----------------------------------------------------------------------------
<*

*>
macro py_validate_funcs(...)
{

	var $aliases = "";
	var $globals = "";
	var $body = "";

	$for var $i = 0; $i < $vaarg.len; $i += 3:
		var $c3_name = $vaarg[$i];
		var $sym_name = $vaarg[$i + 1];
		var $sig = $vaarg[$i + 2];

		$aliases = $aliases +++ @sprintf("alias %sFn = fn %s;\n", $sym_name, $sig);
		$globals = $globals +++ @sprintf("%sFn %s;\n", $sym_name, $c3_name);
		$body = $body +++ @sprintf(
			"\t%s = (%sFn)os::dlsym(g_hPyDLL, \"%s\");\n"
			"\tif (!%s) { io::printfn(\"Function %s not exits\"); return -1; }\n",
			$c3_name, $sym_name, $sym_name,
			$c3_name, $sym_name
		);
	$endfor

	return $aliases +++ $globals +++ "fn int pyFuncsValidate()\n{\n" +++ $body +++ "\treturn 0;\n}\n";
}


$expand(py_validate_funcs(

	//data types transformation
	"pyLong_FromLong", "PyLong_FromLong", "PyObject* (int)",
	"pyLong_FromLongLong", "PyLong_FromLongLong", "PyObject* (sz)",

	"pyLong_FromUnsignedLong", "PyLong_FromUnsignedLong", "PyObject* (uint)",
	"pyLong_FromUnsignedLongLong", "PyLong_FromUnsignedLongLong", "PyObject* (ulong)",




	"pyUnicode_FromStringAndSize", "PyUnicode_FromStringAndSize", "PyObject* (char*, sz)",
	"pyFloat_AsDouble", "PyFloat_AsDouble", "double (PyObject*)",
	"pyUnicode_AsUTF8", "PyUnicode_AsUTF8", "char* (PyObject*)",
	"pyFloat_FromDouble", "PyFloat_FromDouble", "PyObject* (double)",


	"pyDict_SetItemString", "PyDict_SetItemString", "int (PyObject*, char*, PyObject*)",


	"py_init", "Py_Initialize", "void()",
	"py_run", "PyRun_SimpleString", "int(char* command)",
	"py_finalize", "Py_Finalize", "void()",
	"pySys_GetObject", "PySys_GetObject", "void* (char*)",
	"pyUnicode_FromWideChar", "PyUnicode_FromWideChar", "void* (WString, sz)",
	"pyList_Append", "PyList_Append", "void* (void*, void*)",
	"pyList_New", "PyList_New", "PyObject* (sz)",
	"pyList_SetItem", "PyList_SetItem", "int (PyObject*, sz, PyObject *)",
	"pyImport_ImportModule", "PyImport_ImportModule", "PyObject* (char*)",
	"pyModule_GetDict", "PyModule_GetDict", "PyObject* (PyObject*)",
	"pyRun_String", "PyRun_String", "PyObject* (char*, int, PyObject*, PyObject*)",
	"pyList_Size", "PyList_Size", "sz (PyObject*)",
	"pyList_GetItem", "PyList_GetItem", "PyObject* (PyObject*, sz)",
	"pyObject_GetAttrString", "PyObject_GetAttrString", "PyObject* (PyObject*, char*)",
	"pyCallable_Check", "PyCallable_Check", "int (PyObject*)",
	"pyTuple_New", "PyTuple_New", "PyObject* (sz)",
	"pyTuple_SetItem", "PyTuple_SetItem", "int (PyObject*, sz, PyObject*)",
	"pyObject_CallObject", "PyObject_CallObject", "PyObject* (PyObject*, PyObject*)",
	"py_DecRef", "Py_DecRef", "void (PyObject*)",
	"pyErr_Print", "PyErr_Print", "void()",
	"pyErr_Occurred", "PyErr_Occurred", "PyObject* ()",

));




//-----------------------------------------------------------------------------
// funcs
//-----------------------------------------------------------------------------
fn int PyMachine.init(&this, ZString py_dll_path) {
	if(g_pPyMachine) {
		io::printn("1 pymachine per program!");
		return 1;
	}
	this.mdls.init(mem);
	g_hPyDLL = os::dlopen(py_dll_path, { .global_symbols = true });
	if (!g_hPyDLL) {
		io::printn("Failed to load Python Dynamic lib");
		return 2;
	}

	pyFuncsValidate();
	py_init();
	g_pPyMachine = this;
	py_run("import sys; sys.path.append('..//scripts'); sys.path.append('scripts//'); import config; config.hello()");
	py_run("sys.path.append('..//third_party'); sys.path.append('third_party//');");
	/*py_run(
		"import pmx_test;"
		"pmx_test.run_test();"
	);
	*/

	return 0;
}


//-----------------------------------------------------------------------------
// PyMachine interface
//-----------------------------------------------------------------------------
fn int PyMachine.deepcopy_addModule
(
	&this,
	PyModule* mdl,
) 
{
	if(!g_pPyMachine) {
		io::printn("pymachine does not init!");
		return 1;
	}

	PyModule* module_copy = mem::malloc(PyModule::size);
	mem::copy(module_copy, mdl, PyModule::size);
	this.mdls.set(module_copy.name, module_copy);
	return 0;
}

fn PyModule* PyMachine.get(&this, ZString name) {
	return this.mdls.get(name)!!;
}

fn int PyMachine.shutDown(&this) {
	if(!g_pPyMachine) {
		io::printn("pymachine does not init!");
		return 1;
	}
	py_finalize();
	return 0;
}



//-----------------------------------------------------------------------------
// PyModule interface
//-----------------------------------------------------------------------------
fn int PyModule.init
(
	&this,
	PyMachine* m,
	ZString name,
	PyModule_DestroyFn df
)
{
	this.machine = m;
	this.name = name;
	this.funcs.init(mem);
	this.df = df;

	PyObject* pModule = pyImport_ImportModule(this.name);
	this.pModule = pModule;
	this.isInit = 1;

	PyObject* pModuleDict = pyModule_GetDict(this.pModule);
	ZString expr = "[name for name, obj in vars().items() if callable(obj)]";
	PyObject* funcsList = pyRun_String(expr, 258, pModuleDict, pModuleDict);


	for(sz i = 0; i < pyList_Size(funcsList); i++) {
		PyObject* item = pyList_GetItem(funcsList, i);
		ZString func_name = (ZString)pyUnicode_AsUTF8(item);

		PyObject* pf = pyObject_GetAttrString(pModule, func_name); // new ref
		if(pf) {
			PyFunc f;

			//си реализации может и не быть! поэтому первым
			//может быть null
			io::printf("%s\n", func_name);
			f.init(null, func_name, pf);
			this.deepcopy_addFunc(&f);
		}
		//py_DecRef(item)
	}

	py_DecRef(funcsList);
	return 0;
}

fn int PyModule.deepcopy_addFunc
(
	&this,
	PyFunc* f
)
{
	if(!this.isInit) {
		io::printf("module not init!");
		return -1;
	}

	PyFunc* nfunc = mem::malloc(PyFunc::size);
	mem::copy(nfunc, f, PyFunc::size);
	this.funcs.set(nfunc.name, nfunc);
	return 0;

}

fn PyFunc* PyModule.get_func(&this, ZString name) {
	if(!this.isInit) {
		io::printf("module not init!");
		return null;
	}
	return this.funcs.get(name)!!;
}

fn int PyModule.destroy(&this) {
	if(!this.isInit) {
		io::printf("module not init!");
		return -1;
	}
	if(this.df) {
		this.df();
	}
	this.funcs.free();
	return 0;
}

//-----------------------------------------------------------------------------
// PyFunc interface
//-----------------------------------------------------------------------------
fn void PyFunc.init(&this, void* func, ZString name, PyObject* pf) {
	this.func	= func;
	this.pf		= pf;

	ZString new_name = (ZString)mem::malloc(name.len()+1);
	mem::copy(new_name, name, name.len()+1);
	this.name = new_name;
}



fn PyObject* float_cv(void* p)	=> pyFloat_FromDouble(*(float*)p);
fn PyObject* double_cv(void* p)	=> pyFloat_FromDouble(*(double*)p);
fn PyObject* int_cv(void* p)	=> pyLong_FromLong(*(int*)p);
fn PyObject* uint_cv(void* p)	=> pyLong_FromUnsignedLong(*(uint*)p);
fn PyObject* i64_cv(void* p)	=> pyLong_FromLongLong(*(long*)p);
fn PyObject* u64_cv(void* p)	=> pyLong_FromUnsignedLongLong(*(ulong*)p);
fn PyObject* str_cv(void* p) {
	String s = *(String*)p;
	return pyUnicode_FromStringAndSize(s, s.len);
}
fn PyObject* zstr_cv(void* p) {
	ZString s = *(ZString*)p;
	return pyUnicode_FromStringAndSize(s, s.len());
}

alias ElmentConv = fn PyObject* (void*);
fn PyObject* arr_to_py(any arg, ElmentConv conv) {

	char[] raw = *(char[]*)arg.ptr;
	usz esize = (usz)arg.type.inner.size;

	PyObject* item = pyTuple_New((sz)raw.len);
	for(usz i = 0; i < raw.len; i++) {
		PyObject* tmp = conv(raw.ptr + i*esize);
		pyTuple_SetItem(item, (sz)i, tmp);
	}
	return item;
}

fn PyObject* PyFunc.call(&this, any... args) {
	PyObject* pArgs = pyTuple_New(args.len);

	foreach(i, arg : args) {
		PyObject* item = null;
		switch(arg.type) {

			//float block
			case float: 	item = float_cv(arg.ptr);
			case float[]: 	item = arr_to_py(arg, &float_cv);

			// double block
			case double:	item = double_cv(arg.ptr);
			case double[]:	item = arr_to_py(arg, &double_cv);

			// int block
			case int: 		item = int_cv(arg.ptr);
			case int[]:		item = arr_to_py(arg, &int_cv);

			// uint block
			case uint: 		item = uint_cv(arg.ptr);
			case uint[]:	item = arr_to_py(arg, &uint_cv);

			// i64 block
			case long: 		item = i64_cv(arg.ptr);
			case long[]:	item = arr_to_py(arg, &i64_cv);

			// u64 block
			case ulong: 	item = u64_cv(arg.ptr);
			case ulong[]:	item = arr_to_py(arg, &u64_cv);

			// zstr block
			case ZString: 	item = zstr_cv(arg.ptr);
			case ZString[]:	item = arr_to_py(arg, &zstr_cv);

			// str block
			case String:	item = str_cv(arg.ptr);
			case String[]:	item = arr_to_py(arg, &str_cv);

			default:
				io::printf("unknown type!");
				py_DecRef(pArgs);
				return null;
		}

		pyTuple_SetItem(pArgs, i, item);
	}

	PyObject* out = pyObject_CallObject(this.pf, pArgs);
	py_DecRef(pArgs);
	return out;
}

fn void PyFunc.destroy(&this) {
	if(this.name) {
		mem::free(this.name);
	}
	if(this.pf) {
		py_DecRef(this.pf);
	}
}
