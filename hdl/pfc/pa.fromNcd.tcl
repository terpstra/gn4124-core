
# PlanAhead Launch Script for Post PAR Floorplanning, created by Project Navigator

create_project -name pfc_wrapper -dir "/home/mcattin/projects/GN4124_core/hdl/pfc/planAhead_run_1" -part xc6slx150tfgg676-3
set srcset [get_property srcset [current_run -impl]]
set_property design_mode GateLvl $srcset
set_property edif_top_file "/home/mcattin/projects/GN4124_core/hdl/pfc/pfc_wrapper.ngc" [ get_property srcset [ current_run ] ]
add_files -norecurse { {/home/mcattin/projects/GN4124_core/hdl/pfc} {ip_cores} }
add_files "ip_cores/fifo_32x512.ncf" "ip_cores/fifo_64x512.ncf" "ip_cores/ram_2048x32.ncf" -fileset [get_property constrset [current_run]]
set_param project.paUcfFile  "pfc_wrapper.ucf"
add_files "pfc_wrapper.ucf" -fileset [get_property constrset [current_run]]
open_netlist_design
read_xdl -file "/home/mcattin/projects/GN4124_core/hdl/pfc/pfc_wrapper.ncd"
if {[catch {read_twx -name results_1 -file "/home/mcattin/projects/GN4124_core/hdl/pfc/pfc_wrapper.twx"} eInfo]} {
   puts "WARNING: there was a problem importing \"/home/mcattin/projects/GN4124_core/hdl/pfc/pfc_wrapper.twx\": $eInfo"
}
