files = ["dma_controller.vhd",
         "dma_controller_wb_slave.vhd",
         "l2p_arbiter.vhd",
         "l2p_dma_master.vhd",
         "p2l_decode32.vhd",
         "p2l_dma_master.vhd",
         "wbmaster32.vhd"]

modules = { "local" : "spartan6",
            "git" : "git://ohwr.org/hdl-core-lib/general-cores.git" }

fetchto = "ip_cores"

