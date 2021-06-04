



#l = ["lp_coupling_0.2","lp_topology_0.2","lp_topology_0.1","lp_topology_0.05","lp_coupling_0.1","lp_coupling_0.05","lp_copper","LP","LP_top2","LP_top1","lp_top1_307"]#["coupling_0.05"]
l =["feat_coupling_0.15","feat_coupling_0.2","feat_coupling_0.3","feat_coupling_0.4"]
#l =["lp_feat_0.15","lp_feat_0.2","lp_feat_0.3","lp_feat_0.4"]
l =["lp_bus_0.1","lp_bus_0.15","lp_bus_0.2","lp_bus_0.3"]
l =["Sub AreaInj_0.0","ZoneInj_0.0"]
#l = ["testing_cong_0.2"]
#l = ["rand_copper","rand_base"]
#l = ["US-System_LP_all"]


days = [31,29,31,30,31,30,31,31,30,31,30,30]

#days = [31,29,31,1,31,30,31,31,30,31,30,30]

#months = [1,2,3,5,6,7,8,9,10,11,12]
months = [7,8,9,10,11,12,1,2,3,4,5,6]
#months = [7,8,9,10,11]

#months = [4]

# l = ["US-System_copper","US-System_all"]
# lp = [false,false]
# copper = [true,false]
# us = true

# l = ["LP_rand","lp_rand_copper"]
# lp = [true,true]
# copper = [false,true]
# us = false



#l = ["lp_rand_top2_0.4","lp_rand_top2_0.3","lp_rand_top2_0.15","lp_rand_top2_0.2","lp_rand_top2_0.0","lp_rand_top2_0.1","lp_rand_coupling2_0.1","lp_rand_coupling2_0.2","lp_rand_coupling2_0.15","lp_rand_coupling2_0.3","lp_rand_coupling2_0.4"]
#l = ["lp_rand_top2_0.9","lp_rand_top2_0.12","lp_rand_coupling2_0.12"]
#l = ["lp_rand_cou_worst_0.2","lp_rand_cou_worst_0.15","lp_rand_cou_worst_0.3","lp_rand_cou_worst_0.4","lp_rand_cou_worst_0.05","lp_rand_cou_worst_0.6","lp_rand_cou_worst_0.8"]
#l = ["lp_rand_random1_15","lp_rand_random2_15","lp_rand_random3_15","lp_rand_random2_30","lp_rand_random1_30","lp_rand_random3_30","lp_rand_random1_67","lp_rand_random2_67","lp_rand_random3_67"]
#l = ["lp_rand_random1_39","lp_rand_random2_39","lp_rand_random3_39","lp_rand_random1_52","lp_rand_random2_52","lp_rand_random3_52","lp_rand_random1_58","lp_rand_random1_58","lp_rand_random2_58","lp_rand_random3_58","lp_rand_random1_64","lp_rand_random2_64","lp_rand_random3_64"]
#l = ["lp_rand_random1_69","lp_rand_random2_69","lp_rand_random3_69","lp_rand_random2_71","lp_rand_random1_71","lp_rand_random3_71","lp_rand_top3_0.0","lp_rand_top3_0.1","lp_rand_top3_0.15","lp_rand_top3_0.12","lp_rand_top3_0.2","lp_rand_top3_0.3","lp_rand_top3_0.4","lp_rand_top3_0.5","lp_rand_top3_0.6","lp_rand_top3_0.7"]

#name_base = "lp_rand_random4"
#name_base = "lp_rand_top2_vg"
#name_base = "lp_rand_vg_copper"
#name_base = "lp_rand_coupling3"
name_base1 = "lp_rand_base"
name_base2 = "lp_rand_copper"
#name_base = "lp_rand_top3"

#name_base = "lp_rand_top_last"
name_base = "lp_rand_top_lastonly"
name_base = "lp_rand_random"

name_base = "US-System2019_coup_then_top"
name_base = "US-System2019_coup"

#name_base1 = "US-System"
#name_base2 = "US-System_copper1"

name_base1 = "US-System2019"
name_base2 = "US-System2019_copper"
#name_base3 = "US-System2020_copper"


#l = fill.("hi", length(l))*str(15)
#l = [6,9,15,30,39,52,58,64,67,71]
#l = [41,54,60,66,69]
#l = [0.1,0.12,0.15,0.2,0.3,0.4,0.5,0.6,0.7]
#l = [0.0,0.1,0.12,0.15,0.2,0.3,0.4,0.5,0.6,0.7]
l = [0.05,0.1]

#l = [55,49,36,27,10]
#i = 4
#l = [0.0]

#lp = fill.(true, length(l))
#copper = fill.(false, length(l)+1)
us = true
local_save = false
run_idx = 1

SIIP_base = "/Users/ninavincent/Desktop/Git/SIIP_run"
if local_save
   #base = "/Users/ninavincent/Desktop/Git/SIIPExamples.jl"
   base = SIIP_base
else
   base = "/Users/ninavincent/Google Drive/Reduction_research"
data_base = joinpath(base,"data")


if us == true
    simulation_folder_base = joinpath(data_base,"Texas-sim")
else
    simulation_folder_base = joinpath(data_base,"runs")
end

#pkgpath = dirname(dirname(pathof(SIIPExamples)))
include(
    joinpath(SIIP_base,"Julia", "SIIP_functions.jl"),
)

using CPLEX

#solver = optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 1, "ratioGap" => 0.5)
solver = optimizer_with_attributes(CPLEX.Optimizer, "CPX_PARAM_EPGAP" => 0.1)
intervals = Dict("UC" => (Hour(24), Consecutive()))
lp1 = true
copper2 = false

function all_scens(i)
    for nbus in l
       #idx = findall(x->x==nbus, l)
       run_name_base = name_base*"_"*string(nbus)
       #run_name_base = name_base*string(i)*"_"*string(nbus)
       run_sim(run_name_base,copper2,lp1,i) #i
    end

    #base
    #run_name_base = name_base1
    #run_sim(run_name_base,copper2,lp1,i)

    #copperplate
    #run_name_base = name_base2
    #run_sim(run_name_base,true,lp1,i)

    #copperplate
    #run_name_base = name_base3
    #run_sim(run_name_base,true,lp1,i)

end

#for i in 1:20
for i in 1
    all_scens(i)
end
