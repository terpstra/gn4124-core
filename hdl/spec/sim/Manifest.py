action = "simulation"
target = "xilinx"

files = ["testbench/gn412x_bfm.vhd",
         "testbench/cmd_router.vhd",
         "testbench/textutil.vhd",
         "testbench/util.vhd",
         "testbench/tb_spec.vhd",
         "testbench/cmd_router1.vhd"]

modules = { "local" : ["../rtl",
                       "testbench"]}
