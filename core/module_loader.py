from pathlib import Path
from typing import Dict, Set, List
import re
import pickle
from core.lexer import tokenize
from core.flux_parser import parse
from core.flux_ast import Program, ImportStmt, FromImportStmt

class ImportError(Exception):
    pass

def _fast_deepcopy(obj):
    return pickle.loads(pickle.dumps(obj, -1))

def _resolve_module_path(module_name: str, base_dir: Path) -> Path:
    p = Path(module_name)
    if not p.is_absolute():
        candidate = (base_dir / module_name)
    else:
        candidate = p
    if candidate.exists():
        return candidate.resolve()
    if not candidate.suffix:
        cand2 = candidate.with_suffix('.cbl')
        if cand2.exists():
            return cand2.resolve()
    raise ImportError(f"Imported file not found: {module_name} (from {base_dir})")

def inline_imports(program: Program, source_path: str | Path, cache: Dict[Path, Program] | None = None,
                   included: Set[Path] | None = None, stack: List[Path] | None = None) -> Program:
    if cache is None: cache = {}
    if included is None: included = set()
    if stack is None: stack = []

    src_path = Path(source_path).resolve()
    base_dir = src_path.parent

    funcs_names = {f.name for f in program.functions}
    structs_names = {s.name for s in program.structs}
    globals_names = {g.name for g in program.global_vars}

    imports = list(program.imports) if getattr(program, 'imports', None) else []
    new_imports = []

    for imp in imports:
        if imp is None or isinstance(imp, tuple):
            continue

        cname = imp.__class__.__name__

        if cname == 'ImportStmt':
            new_imports.append(imp) 
            module_name = imp.module_name
            mod_path = _resolve_module_path(module_name, base_dir)
            
            if mod_path in stack:
                path_chain = ' -> '.join(str(p) for p in stack + [mod_path])
                raise ImportError(f"Circular import detected: {path_chain}")

            if mod_path not in cache:
                src = Path(mod_path).read_text(encoding='utf-8')
                tokens = tokenize(src, str(mod_path))
                imported_prog = parse(tokens)
                cache[mod_path] = imported_prog
                inline_imports(imported_prog, mod_path, cache, included, stack + [mod_path])
            
            imported_prog = _fast_deepcopy(cache[mod_path]) 
            if mod_path in included: continue

            exports = {f.name for f in imported_prog.functions} | \
                      {s.name for s in imported_prog.structs} | \
                      {g.name for g in imported_prog.global_vars}
    
            prefix = re.sub(r'[^a-zA-Z0-9_]', '_', mod_path.stem)
            
            def rename_type(t):
                if isinstance(t, str):
                    stars, base = "", t
                    while base.startswith('*'):
                        stars += "*"
                        base = base[1:]
                    if base in exports:
                        return f"{stars}{prefix}__{base}"
                elif hasattr(t, 'name') and t.name in exports:
                    t.name = f"{prefix}__{t.name}"
                elif t.__class__.__name__ == 'GenericType':
                    t.args = [rename_type(a) for a in t.args]
                elif t.__class__.__name__ == 'PointerType':
                    t.base_type = rename_type(t.base_type)
                return t

            def rename_node(node):
                if isinstance(node, list):
                    for n in node: rename_node(n)
                elif hasattr(node, '__dict__'):
                    ncname = node.__class__.__name__
                    if ncname == 'Variable' and node.name in exports:
                        node.name = f"{prefix}__{node.name}"
                    if ncname == 'Assign' and isinstance(node.target, str) and node.target in exports:
                        node.target = f"{prefix}__{node.target}"
                    elif ncname == 'Call':
                        if isinstance(node.func_name, str) and node.func_name in exports:
                            node.func_name = f"{prefix}__{node.func_name}"
                        elif hasattr(node.func_name, 'name') and node.func_name.name in exports:
                            node.func_name.name = f"{prefix}__{node.func_name.name}"
                    
                    for k, v in vars(node).items():
                        if k in ('var_type', 'return_type', 'target_type', 'array_type') and v is not None:
                            setattr(node, k, rename_type(v))
                        elif k == 'type_args' and v is not None:
                            setattr(node, k, [rename_type(a) for a in v])
                        else:
                            rename_node(v)

            for f in imported_prog.functions:
                new_name = f"{prefix}__{f.name}"
                if new_name in funcs_names: continue
                f.name = new_name
                if f.params: f.params = [(pname, rename_type(ptype)) for pname, ptype in f.params]
                f.return_type = rename_type(f.return_type)
                rename_node(f.body)
                program.functions.append(f)
                funcs_names.add(f.name)

            for s in imported_prog.structs:
                new_name = f"{prefix}__{s.name}"
                if new_name in structs_names: continue
                s.name = new_name
                if isinstance(s.fields, list): s.fields = [(fname, rename_type(ftype)) for fname, ftype in s.fields]
                program.structs.append(s)
                structs_names.add(s.name)

            for g in imported_prog.global_vars:
                new_name = f"{prefix}__{g.name}"
                if new_name in globals_names: continue
                g.name = new_name
                g.var_type = rename_type(g.var_type)
                rename_node(g.value)
                program.global_vars.append(g)
                globals_names.add(g.name)

            included.add(mod_path)

        elif cname == 'FromImportStmt':
            new_imports.append(imp)
            module_name = imp.module_name
            mod_path = _resolve_module_path(module_name, base_dir)
            if mod_path in stack: raise ImportError(f"Circular import: {mod_path}")

            if mod_path not in cache:
                src = Path(mod_path).read_text(encoding='utf-8')
                imported_prog = parse(tokenize(src, str(mod_path)))
                cache[mod_path] = imported_prog
                inline_imports(imported_prog, mod_path, cache, included, stack + [mod_path])
            
            imported_prog = _fast_deepcopy(cache[mod_path])

            for item in imp.items or []:
                found = False
                for f in imported_prog.functions:
                    if f.name == item:
                        if item in funcs_names: 
                            found = True; break
                        program.functions.append(f)
                        funcs_names.add(item)
                        found = True; break
                if found: continue
                for s in imported_prog.structs:
                    if s.name == item:
                        if item in structs_names: 
                            found = True; break
                        program.structs.append(s)
                        structs_names.add(item)
                        found = True; break
                if found: continue
                for g in imported_prog.global_vars:
                    if g.name == item:
                        if item in globals_names: 
                            found = True; break
                        program.global_vars.append(g)
                        globals_names.add(item)
                        found = True; break
                if not found:
                    raise ImportError(f"Item '{item}' not found in module {mod_path}")

    program.imports = new_imports
    return program