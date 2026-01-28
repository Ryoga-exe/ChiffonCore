# project_core.tcl - Create Ultra96V2 (PYNQ) project for custom RISC-V core + draw/display IPs

# --- Project settings ----------------------------------
set project_dir  "./project"
set project_name "ChiffonCore"
set part "xczu3eg-sbva484-1-i"

set scripts_dir [file dirname [file normalize [info script]]]

create_project $project_name $project_dir -part $part -force

# --- IP Registry ---------------------------------------
set repo_list [list \
    [file normalize "ip"] \
]
set cur_repo [get_property IP_REPO_PATHS [current_project]]

foreach path $repo_list {
    if {![file isdirectory $path]} {
        puts "WARNING: IP repo not found: $path"
        continue
    }
    if {[lsearch -exact $cur_repo $path] < 0} {
        lappend cur_repo $path
        puts "INFO: Added IP repo: $path"
    } else {
        puts "INFO: IP repo already registered: $path"
    }
}
set_property IP_REPO_PATHS $cur_repo [current_project]
update_ip_catalog

# --- Add FIFO IP (XCI) ---------------------------------
import_ip core/ip/fifo_8in8out_1024depth.xci
update_ip_catalog

# --- Add RTL Sources (core as module-ref, not packaged IP) ---
# Veryl output
add_files -fileset sources_1 [glob -nocomplain core/target/*.sv]
add_files -fileset sources_1 [glob -nocomplain core/target/**/*.sv]
# Verilog top wrapper (module name: top)
add_files -fileset sources_1 core/target/top.v

# --- Boot ROM ------------------------------------------------
set bootrom_hex "core/bootrom.hex"
if {![file exists $bootrom_hex]} {
    puts "ERROR: bootrom.hex not found: $bootrom_hex"
    exit 1
}
add_files -fileset sources_1 -norecurse $bootrom_hex
# Mark as "Memory Initialization Files"
set_property file_type {Memory Initialization Files} [get_files -of_objects [get_filesets sources_1] $bootrom_hex]

update_compile_order -fileset sources_1

# --- Create Block Design (base: bd_base.tcl, then patch in core) ---
set base_design_tcl [file join $scripts_dir "bd_base.tcl"]
set patch_design_tcl [file join $scripts_dir "bd_core.tcl"]

if {![file exists $base_design_tcl]} {
    puts "ERROR: can't find base BD script: $base_design_tcl"
    puts "HINT: copy/symlink your existing pynq_draw.tcl next to this script, or edit base_design_tcl."
    exit 1
}
if {![file exists $patch_design_tcl]} {
    puts "ERROR: can't find core BD patch script: $patch_design_tcl"
    exit 1
}

# Build base BD (display+draw+regbus+PS etc)
puts "INFO: source $base_design_tcl"
source $base_design_tcl

# Patch BD: add core module + interconnect + wiring
puts "INFO: source $patch_design_tcl"
source $patch_design_tcl

# --- Generate wrapper / targets -------------------------
validate_bd_design
generate_target {synthesis implementation} [get_files design_1.bd]

set wrapper_files [make_wrapper -files [get_files design_1.bd] -top -force]
add_files -norecurse $wrapper_files
update_compile_order -fileset sources_1

# --- Add constraints ------------------------------------
add_files -fileset constrs_1 [glob -nocomplain constraints/*.xdc]

puts "INFO: Project created at $project_dir/$project_name.xpr"
puts "INFO: Next (GUI): open_project $project_dir/$project_name.xpr"
puts "INFO: Next (Tcl): launch_runs impl_1 -to_step write_bitstream; wait_on_run impl_1"
exit
