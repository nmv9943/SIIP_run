
days = [31,29,31,30,31,30,31,31,30,31,30,30]

months = [7,8,9,10,11,12,1,2,3,4,5,6]


name_base = "US-System2019_coup_then_top"
name_base = "US-System2019_coup"

name_base1 = "US-System2019"
name_base2 = "US-System2019_copper"


l = [0.05,0.1]

us = true
local_save = false
run_idx = 1

SIIP_base = "/Users/ninavincent/Desktop/Git/SIIP_run"
if local_save
   base = SIIP_base
else
   base = "/Users/ninavincent/Google Drive/Reduction_research"
data_base = joinpath(base,"data")


if us == true
    simulation_folder_base = joinpath(data_base,"Texas-sim")
else
    simulation_folder_base = joinpath(data_base,"runs")
end

include(
    joinpath(SIIP_base,"Julia", "SIIP_functions.jl"),
)

solver = optimizer_with_attributes(CPLEX.Optimizer, "CPX_PARAM_EPGAP" => 0.1)
intervals = Dict("UC" => (Hour(24), Consecutive()))
lp1 = true
copper2 = false

function all_scens(i)
    for nbus in l
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

end

#for i in 1:20
for i in 1
    all_scens(i)
end
