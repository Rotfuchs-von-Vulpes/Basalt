package skeewb

import "core:c/libc"
import "core:c"
import "core:fmt"
import "core:time"
import "core:os"
import "base:runtime"



shared_object :: struct{}
function_pointer :: struct{}
interface :: struct{}
event :: struct{}
module :: struct{}


log_category :: enum c.int {CRITICAL, ERROR, WARNING, INFO, VERBOSE, DEBUG}
config_type  :: enum c.int {EMPTY, BOOLEAN, INTEGER, REAL, STRING}

event_callback :: proc"c"(context_data : rawptr)

version :: struct{
    major : u16,
    minor : u16,
    patch : u16,
}

module_desc :: struct{ 
    modid     : string,   //todo: change string_t to use signed
    version   : version,
    interface :^interface,
}

config_value :: struct #raw_union {
    boolean : b8,
    integer : i64,
    real    : f64,
    string  : cstring,
}

config :: struct{
    name  : string,
    type  : config_type,
    value : config_value,
}

resource :: struct{
    name : string,
    path : string,
    file :^libc.FILE
}

core_interface :: struct{
    version : version,
    console_log_:       proc"c"(category: log_category, format: string, #c_vararg args: ..any),
    event_register:     proc"c"(name: string), 
    event_trigger:      proc"c"(name: string, context_data: rawptr),
    event_listen:       proc"c"(name: string, callback: event_callback),
    quit:               proc"c"(status: c.int),
    resource_load:      proc"c"(name: string, path: string) -> ^resource,
    resource_overload:  proc"c"(name: string, path: string) -> ^resource,
    resource_string:    proc"c"(resource: ^resource) -> string,
    config_set:         proc"c"(config: config),
    config_get:         proc"c"(name: string) -> config,
    module_get_version: proc"c"(modid: string) -> version,
    module_get_interface:proc"c"(modid: string) -> ^interface,
    module_get_function:proc"c"(modid: string) -> ^function_pointer,
    list_directory:     proc"c"(path: string, directories: bool) -> [^]string,
}

    
    
    
console_log :: proc(category: log_category, format: string, args: ..any, location := #caller_location) {
    output_file := os.stderr
    prefix := ""
    hour, min, second := time.clock(time.now())
      
    switch category {
      case log_category.VERBOSE: prefix = "[\033[34mVERBSE\033[0m]["
      case log_category.INFO:    prefix = "[\033[34mINFO\033[0m]  ["
      case log_category.WARNING: prefix = "[\033[93mWARN\033[0m]  ["
      case log_category.ERROR:   prefix = "[\033[31mERROR\033[0m] ["
      case log_category.CRITICAL:prefix = "[\033[31mCRTCAL\033[0m]["
      case log_category.DEBUG:   prefix = "[\033[35mDEBUG\033[0m] ["
    }
    fmt.fprint(output_file, prefix)
    fmt.fprintf(output_file, "%02i:%02i:%02i] ", hour, min, second);
    fmt.fprintf(output_file, "[\033[34m%s | %s:\033[35m%d \033[93m%s()\033[0m] ", "receba", location.file_path, location.line, location.procedure)
    fmt.fprintfln(output_file, format, ..args)
}


