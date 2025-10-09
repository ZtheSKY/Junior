start_gui
open_project Soc_Multiplier.xpr
update_compile_order -fileset sources_1
reset_project
launch_runs synth_1 -jobs 16
launch_runs impl_1 -jobs 16