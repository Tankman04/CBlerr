import sys
import os
import platform
import configparser
import subprocess
from pathlib import Path
from typing import Optional

root_path = Path(__file__).parent.parent
sys.path.insert(0, str(root_path))
sys.path.insert(0, str(Path(__file__).parent))

try:
    from build_standalone import StandaloneCompiler
except ImportError:
    from build.build_standalone import StandaloneCompiler

def get_closest_filename(target_path: str) -> Optional[str]:
    p = Path(target_path)
    directory = p.parent if p.parent.exists() and p.parent.is_dir() else Path('.')
    filename = p.name
    
    def levenshtein(s1: str, s2: str) -> int:
        if len(s1) < len(s2):
            return levenshtein(s2, s1)
        if len(s2) == 0:
            return len(s1)
        previous_row = range(len(s2) + 1)
        for i, c1 in enumerate(s1):
            current_row = [i + 1]
            for j, c2 in enumerate(s2):
                insertions = previous_row[j + 1] + 1
                deletions = current_row[j] + 1
                substitutions = previous_row[j] + (c1 != c2)
                current_row.append(min(insertions, deletions, substitutions))
            previous_row = current_row
        return previous_row[-1]

    best_match = None
    best_dist = float('inf')
    
    try:
        for f in directory.iterdir():
            if f.is_file() and f.suffix in ('.cbl', '.cblproj'):
                dist = levenshtein(filename.lower(), f.name.lower())
                if dist <= 4 and dist < best_dist:
                    best_match = f.name
                    best_dist = dist
    except Exception:
        pass
        
    if best_match:
        return str(directory / best_match) if p.parent.name else best_match
    return None

def print_help():
    print(r"""
    ┏━╸┏┓ ╻  ┏━╸┏━┓┏━┓
    ┃  ┣┻┓┃  ┣╸ ┣┳┛┣┳┛
    ┗━╸┗━┛┗━╸┗━╸╹┗╸╹┗╸
          """)
    print("\033[1;36m--------------------------------------------------------\033[0m")
    print("\033[1;36m             CBlerr Compiler (CCC)                      \033[0m")
    print("\033[1;36m--------------------------------------------------------\033[0m\n")
    print("\033[1;33mUsage:\033[0m python build/cli.py <source_file.cbl | project.cblproj> [options]\n")
    print("\033[1;31mREQUIRED OPTIMIZATION FLAGS (pick one):\033[0m")
    print("  \033[1;32m-fast\033[0m       Build for maximum performance (fastest binary)")
    print("  \033[1;32m-small\033[0m      Build for the smallest file size (still fast, but optimized for size over raw speed)\n")
    print("\033[1;34mEXTRA OPTIONS:\033[0m")
    print("  \033[32m-run\033[0m        Run the compiled executable immediately after a successful build")
    print("  \033[32m-asm\033[0m        Generate assembly code instead of an executable")
    print("  \033[32m-o <file>\033[0m   Set the name of the output executable")
    print("  \033[32m-t <os>\033[0m     Target OS: windows, linux, wasm, winlib (for DLLs), winsaver (for .scr screensavers)")
    print("  \033[32m-q, --quiet\033[0m Hide detailed compilation logs")
    print("  \033[32m-static\033[0m     Use static linking for libraries")
    print("  \033[32m-dynamic\033[0m    Use dynamic linking")
    print("  \033[32m-m32\033[0m        Build a 32-bit (x86) version")
    print("  \033[32m--gcc\033[0m       Force the use of GCC/MinGW")
    print("  \033[32m--clang\033[0m     Force the use of Clang")
    print("  \033[32m--lld\033[0m       Use the LLD linker")
    print("  \033[32m--stack-size\033[0m Set custom stack size (e.g., 1M, 512K)")
    print("  \033[32m-c\033[0m          Keep the generated C code")
    print("  \033[32m-h, --help\033[0m  Show this menu")
    print("  \033[32m-gen-h\033[0m      Generate a C header file (.h) for the compiled code")
    print("  \033[32m-native\033[0m     Optimize code specifically for your current CPU architecture ")
    print("  \033[32m-v3\033[0m         Build with x86-64-v3. A modern baseline for CPUs from 2015 and newer.")
    print("  \033[32m-avx512\033[0m     Enable AVX-512. Extreme 512-bit vectorization for modern CPUs. A lot of CPU's don't support it.")
    print("  \033[32m-avx256\033[0m     Enable AVX2 (256-bit). Blazing fast, but some CPUs may throttle (downclock) to save power & prevent overheating.")
    print("  \033[32m-avx128\033[0m     Enable AVX (128-bit). A safer speed boost avoiding severe CPU frequency drops.")
    print("  \033[32m--time\033[0m      Show detailed profiling (execution time of compiler stages)")
    print("  \033[32m--verbose\033[0m   \033[1;30m[DEPRECATED]\033[0m Show detailed logs and enable memory dumps (-derr)")
    print("  \033[32m-derr\033[0m       Enable detailed memory dump on compiler crashes\n")

def main():
    if len(sys.argv) < 2 or sys.argv[1] in ('-h', '--help'):
        print_help()
        sys.exit(0)
        
    input_path = sys.argv[1]
    
    if input_path.startswith('-'):
        print("\n\033[1;31m[Oops!] You need to provide a source file (.cbl or .cblproj) as the first argument!\033[0m")
        print_help()
        sys.exit(1)
        
    if not Path(input_path).exists():
        closest_path = get_closest_filename(input_path)
        if closest_path:
            closest_name = Path(closest_path).name
            print(f"\n\033[1;33m[Oops!] The file '{input_path}' doesn't seem to exist.\033[0m")
            ans = input(f"\033[1;36mDo you want to compile \"{closest_name}\" or exit the CCC program? [y/N]: \033[0m").strip().lower()
            if ans in ('y', 'yes'):
                input_path = closest_path
            else:
                print("Exiting...")
                sys.exit(0)
        else:
            print(f"\n\033[1;31m[Oops!] The file '{input_path}' doesn't exist and no similar files were found.\033[0m")
            sys.exit(1)
        
    proj_cfg = {
        'name': Path(input_path).stem,
        'main_file': input_path,
        'ui': False,
        'icon': None,
        'files': []
    }

    if input_path.endswith('.cblproj'):
        parser = configparser.ConfigParser()
        try:
            with open(input_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            if not content.strip().startswith('['):
                content = '[project]\n' + content
            
            parser.read_string(content)
            
            section = 'project' if 'project' in parser else (parser.sections()[0] if parser.sections() else None)
            if section:
                s = parser[section]
                proj_cfg['name'] = s.get('name', proj_cfg['name'])
                proj_cfg['main_file'] = str(Path(input_path).parent / s.get('main_file', '')) if 'main_file' in s else proj_cfg['main_file']
                proj_cfg['ui'] = s.getboolean('ui', False)
                if 'icon' in s:
                    proj_cfg['icon'] = str(Path(input_path).parent / s.get('icon'))
                if 'files' in s:
                    proj_cfg['files'] = [str(Path(input_path).parent / f.strip()) for f in s.get('files').split(',') if f.strip()]
        except Exception as e:
            print(f"Oops, failed to parse the project file: {e}")

    source_file = Path(proj_cfg['main_file'])
    output_exe = proj_cfg['name']
    
    target = "windows" if platform.system() == "Windows" else "linux"
    
    verbose, link_mode, stack_size, compiler_type = True, None, None, None
    m32 = False
    opt_level = None
    run_after_compile = False
    asm_out = False
    profile_time = False
    gen_header = False
    native_mode = False
    v3_mode = False
    avx_mode = None
    keep_c = False
    derr_flag = False
    
    i = 2
    while i < len(sys.argv):
        arg = sys.argv[i]
        if arg == '-fast':
            opt_level = '-O3'
            i += 1
        elif arg == '-small':
            opt_level = '-Os'
            i += 1
        elif arg == '-run':
            run_after_compile = True
            i += 1
        elif arg == '-asm':
            asm_out = True
            i += 1
        elif arg == '--time':
            profile_time = True
            i += 1
        elif arg == '-gen-h':
            gen_header = True
            i += 1
        elif arg == '-native':
            native_mode = True
            i += 1
        elif arg == '-v3':
            v3_mode = True
            i += 1
        elif arg == '-avx512':
            avx_mode = '512'
            i += 1
        elif arg == '-avx256' or arg == '-avx':
            if arg == '-avx':
                print("\033[1;33m[Notice]\033[0m '-avx' is treated as '-avx256'. Consider using '-avx128' if you want cooler temps!")
            avx_mode = '256'
            i += 1
        elif arg == '-avx128':
            avx_mode = '128'
            i += 1
        elif arg in ('-h', '--help'):
            print_help()
            sys.exit(0)
        elif arg == '-o' and i + 1 < len(sys.argv):
            output_exe = sys.argv[i + 1]
            i += 2
        elif arg == '-t' and i + 1 < len(sys.argv):
            target = sys.argv[i + 1].lower()
            i += 2
        elif arg in ('-q', '--quiet'):
            verbose = False
            i += 1
        elif arg == '--verbose':
            print("\033[1;33m[Warning]\033[0m '--verbose' is deprecated. It now automatically enables detailed error dumps (-derr).")
            verbose = True
            derr_flag = True
            i += 1
        elif arg == '-static':
            link_mode = 'static'
            i += 1
        elif arg == '-dynamic':
            link_mode = 'dynamic'
            i += 1
        elif arg in ('--gcc', '--clang', '--lld', '--mingw'):
            compiler_type = arg[2:]
            i += 1
        elif arg in ('-m32', '--m32'):
            m32 = True
            i += 1
        elif arg == '--stack-size' and i + 1 < len(sys.argv):
            s = sys.argv[i + 1].strip().upper()
            stack_size = int(float(s[:-1]) * 1024 * 1024) if s.endswith('M') else (int(float(s[:-1]) * 1024) if s.endswith('K') else int(s))
            i += 2
        elif arg == '-c':
            keep_c = True
            i += 1
        elif arg == '-derr':
            derr_flag = True
            i += 1
        else:
            if arg.startswith('-'):
                print(f"\033[1;33m[Notice]\033[0m Unknown flag '{arg}' ignored. Continuing...")
            i += 1
            
    if opt_level is None:
        print("\n\033[1;41;37m [Hold on!] No optimization mode selected! \033[0m")
        print("\033[0;33mHey there! You need to explicitly tell the compiler how to optimize your code.\033[0m")
        print("What's more important for your build right now?")
        print("  \033[1;32m-fast\033[0m  — Make it run as fast as possible")
        print("  \033[1;32m-small\033[0m — Keep the file size as small as possible (still fast, but optimized for size over raw speed)\n")
        print("\033[90mHere's how to run it properly:\033[0m")
        print(f"  \033[1;37mpython build/cli.py {input_path} -fast\033[0m")
        print(f"  \033[1;37m(Note: Adjust the compiler path if you are running it from a different directory).\033[0m")
        sys.exit(1)

    if asm_out:
        if output_exe.lower().endswith('.exe') or output_exe.lower().endswith('.dll') or output_exe.lower().endswith('.wasm') or output_exe.lower().endswith('.scr'):
            output_exe = output_exe.rsplit('.', 1)[0] + '.s'
        elif not output_exe.lower().endswith('.s') and not output_exe.lower().endswith('.asm'):
            output_exe += '.s'
    else:
        if target == 'windows' and not output_exe.lower().endswith('.exe'):
            output_exe += '.exe'
        elif target == 'winlib' and not output_exe.lower().endswith('.dll'):
            output_exe += '.dll'
        elif target in ('winsaver', 'screensaver'):
            if not output_exe.lower().endswith('.scr'):
                output_exe += '.scr'
            target = 'winsaver'
        elif target == 'wasm' and not output_exe.lower().endswith('.wasm'):
            output_exe += '.wasm'
        
    compiler = StandaloneCompiler(
        source_file=str(source_file), 
        output_exe=output_exe,
        target=target,
        verbose=verbose, 
        link_mode=link_mode, 
        stack_reserve=stack_size, 
        compiler_type=compiler_type,
        icon_path=proj_cfg['icon'],
        extra_files=proj_cfg['files'],
        m32=m32,
        opt_level=opt_level,
        asm_out=asm_out,
        profile_time=profile_time,
        gen_header=gen_header,
        native_mode=native_mode,
        v3_mode=v3_mode,
        avx_mode=avx_mode,
        keep_c=keep_c,
        derr_flag=derr_flag
    )
    
    if proj_cfg['ui']:
        compiler.is_gui_app = True
    
    if compiler.compile():
        print(f"Output file: {output_exe}")
        
        if run_after_compile:
            if target in ('wasm', 'winlib') or asm_out:
                print(f"\n\033[1;33m[Notice]\033[0m Cannot directly execute '{target}' binaries or assembly files. Skipping run.\033[0m")
            else:
                print(f"\n\033[1;36m=== Running {output_exe} ===\033[0m\n")
                exe_path = str(Path(output_exe).resolve())
                try:
                    subprocess.run([exe_path])
                    print(f"\n\033[1;36m=== Program finished ===\033[0m")
                except KeyboardInterrupt:
                    print(f"\n\033[1;33m=== Program terminated by user ===\033[0m")
                except Exception as e:
                    print(f"\n\033[1;31m[Execution Error]\033[0m Could not run the program: {e}")
        
        sys.exit(0)
        
    sys.exit(1)

if __name__ == "__main__":
    main()