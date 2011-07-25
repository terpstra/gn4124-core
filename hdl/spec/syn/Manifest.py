target = "xilinx"
action = "synthesis"

modules = { "local" : "../rtl" }

syn_device = "xc6slx45t"
syn_grade = "-3"
syn_package = "fgg484"
syn_top = "spec_gn4124_test"
syn_project = "spec_gn4124_test.xise"

files = ["../spec_gn4124_test.ucf"]
