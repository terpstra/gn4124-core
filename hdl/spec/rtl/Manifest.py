files = ["spec_gn4124_test.vhd"]

modules = {"local" : ["../../common/rtl",
                      "../../gn4124core/rtl"],
           "git" : "git://ohwr.org/hdl-core-lib/general-cores.git"}

fetchto = "../ip_cores"
