using SIIPExamples

using PowerSystems
const PSY = PowerSystems
using PowerSimulations
const PSI = PowerSimulations
using PowerSystemCaseBuilder

using Dates
using DataFrames
using CSV

using CPLEX

import PowerSystemCaseBuilder:  filter_kwargs,get_raw_data

function build_modified_RTS_GMLC_DA_sys(; kwargs...)
    sys_kwargs = filter_kwargs(; kwargs...)
    RTS_GMLC_DIR = get_raw_data(; kwargs...)
    RTS_SRC_DIR = joinpath(RTS_GMLC_DIR, "RTS_Data", "SourceData")
    RTS_SIIP_DIR = joinpath(RTS_GMLC_DIR, "RTS_Data", "FormattedData", "SIIP")
    rawsys = PSY.PowerSystemTableData(
        RTS_SRC_DIR,
        100.0,
        joinpath(RTS_SIIP_DIR, "user_descriptors.yaml"),
        timeseries_metadata_file = joinpath(RTS_SIIP_DIR, "timeseries_pointers.json"),
        generator_mapping_file = joinpath(RTS_SIIP_DIR, "generator_mapping.yaml"),
    )

    sys = PSY.System(rawsys; time_series_resolution = Dates.Hour(1), sys_kwargs...)
    PSY.set_units_base_system!(sys, "SYSTEM_BASE")
    res_up = PSY.get_component(PSY.VariableReserve{PSY.ReserveUp}, sys, "Flex_Up")
    res_dn = PSY.get_component(PSY.VariableReserve{PSY.ReserveDown}, sys, "Flex_Down")
    PSY.remove_component!(sys, res_dn)
    PSY.remove_component!(sys, res_up)
    reg_reserve_up = PSY.get_component(PSY.VariableReserve, sys, "Reg_Up")
    PSY.set_requirement!(reg_reserve_up, 1.75 * PSY.get_requirement(reg_reserve_up))
    reg_reserve_dn = PSY.get_component(PSY.VariableReserve, sys, "Reg_Down")
    PSY.set_requirement!(reg_reserve_dn, 1.75 * PSY.get_requirement(reg_reserve_dn))
    spin_reserve_R1 = PSY.get_component(PSY.VariableReserve, sys, "Spin_Up_R1")
    spin_reserve_R2 = PSY.get_component(PSY.VariableReserve, sys, "Spin_Up_R2")
    spin_reserve_R3 = PSY.get_component(PSY.VariableReserve, sys, "Spin_Up_R3")

    for g in PSY.get_components(
        PSY.ThermalStandard,
        sys,
        x -> PSY.get_prime_mover(x) in [PSY.PrimeMovers.CT, PSY.PrimeMovers.CC],
    )
        if PSY.get_fuel(g) == PSY.ThermalFuels.DISTILLATE_FUEL_OIL
            PSY.remove_component!(sys, g)
            continue
        end
        g.operation_cost.shut_down = g.operation_cost.start_up / 2.0
        if PSY.get_base_power(g) > 3
            continue
        end
        PSY.clear_services!(g)
        PSY.add_service!(g, reg_reserve_dn)
        PSY.add_service!(g, reg_reserve_up)
    end
    #Remove units that make no sense to include
    names = [
        "114_SYNC_COND_1",
        "314_SYNC_COND_1",
        "313_STORAGE_1",
        "214_SYNC_COND_1",
        "212_CSP_1",
    ]
    for d in PSY.get_components(PSY.Generator, sys, x -> x.name ∈ names)
        PSY.remove_component!(sys, d)
    end
    for d in PSY.get_components(PSY.Storage, sys)
        PSY.remove_component!(sys, d)
    end
    # Remove large Coal and Nuclear from reserves
    for d in PSY.get_components(
        PSY.ThermalStandard,
        sys,
        x -> (occursin(r"STEAM|NUCLEAR", PSY.get_name(x))),
    )
        PSY.get_fuel(d) == PSY.ThermalFuels.COAL &&
            (PSY.set_ramp_limits!(d, (up = 0.001, down = 0.001)))
        if PSY.get_fuel(d) == PSY.ThermalFuels.DISTILLATE_FUEL_OIL
            PSY.remove_component!(sys, d)
            continue
        end
        PSY.get_operation_cost(d).shut_down = PSY.get_operation_cost(d).start_up / 2.0
        if PSY.get_rating(d) < 3
            PSY.set_status!(d, false)
            PSY.set_status!(d, false)
            PSY.set_active_power!(d, 0.0)
            continue
        end
        PSY.clear_services!(d)
        if PSY.get_fuel(d) == PSY.ThermalFuels.NUCLEAR
            PSY.set_ramp_limits!(d, (up = 0.0, down = 0.0))
            PSY.set_time_limits!(d, (up = 4380.0, down = 4380.0))
        end
    end
    for d in PSY.get_components(PSY.RenewableDispatch, sys)
        PSY.clear_services!(d)
    end

    # Add Hydro to regulation reserves
    for d in PSY.get_components(PSY.HydroEnergyReservoir, sys)
        PSY.remove_component!(sys, d)
    end

    for d in PSY.get_components(PSY.HydroDispatch, sys)
        PSY.clear_services!(d)
    end

    PSY.transform_single_time_series!(sys, 48, Hour(24))
    return sys
end

function RunScenario(problems,DA_RT_sequence,sys::System,run_name_base::String,num_steps::Int,month::Int)

    if us == false
        run_name = "rts-test_"*run_name_base*string(month)
        year = 2020
    else
        run_name = run_name_base*string(month)
        year = 2016
    end
    start_day = DateTime("1/"*string(month)*"/"*string(year)*"  00:00:00", "d/m/y  H:M:S")

    if month == 1
        sim = Simulation(
            name = run_name,
            steps = num_steps,
            problems = problems,
            sequence = DA_RT_sequence,
            simulation_folder = simulation_folder_base,
        )
    else
        sim = Simulation(
            name = run_name,
            steps = num_steps,
            problems = problems,
            sequence = DA_RT_sequence,
            simulation_folder = simulation_folder_base,
            initial_time = start_day
        )
    end
    build!(sim)
    execute!(sim)

    results = SimulationResults(sim);
    uc_results = get_problem_results(results, "UC");

    timestamps = get_realized_timestamps(uc_results)
    variables = read_realized_variables(uc_results)
    parameters = read_realized_parameters(uc_results)
    objective = read_optimizer_stats(uc_results)

    simulation_folder = joinpath(simulation_folder_base, run_name)
    simulation_folder =
       joinpath(simulation_folder,  "$(maximum(parse.(Int64,readdir(simulation_folder))))")
    save_path = mkdir(joinpath(simulation_folder,"plots"))
    folder_path = save_path

    "Replaces the string in `char` with the string`replacement`"
    function replace_chars(s::String, char::String, replacement::String)
        return replace(s, Regex("[$char]") => replacement)
    end

    function write_data(vars_results::Dict, save_path::String; kwargs...)
        if :duals in keys(kwargs)
            name = "dual_"
        elseif :params in keys(kwargs)
            name = "parameter_"
        else
            name = ""
        end
        for (k, v) in vars_results
            file_path = joinpath(save_path, "$name$k.csv")
            if isempty(vars_results[k])
                @debug "$name$k is empty, not writing $file_path"
            else
                CSV.write(file_path, vars_results[k])
            end
        end
    end

    export_variables = Dict()
    for (k, v) in variables
        export_variables[k] = v
    end
    write_data(export_variables, folder_path)

    if !isempty(get_duals(uc_results))
        write_data(get_duals(uc_results), folder_path; duals = true)
    end

    export_parameters = Dict()
    if !isempty(parameters)
        for (p, v) in parameters
            export_parameters[p] =  v
        end
        write_data(export_parameters, folder_path; params = true)
    end

    CSV.write(joinpath(folder_path,"objective.csv"), objective)

    return simulation_folder
end

function run_sim(run_name_base,copper1,lp1,i)

    template_uc = OperationsProblemTemplate()

    if lp1 == true
        horizon = 24;
    else
        horizon = 48;
    end
    interval = Dates.Hour(24);

    if us == true
        sys = System(joinpath(data_base,"US-data", run_name_base, "SIIP", "sys.json"))
        transform_single_time_series!(sys, horizon, interval);
    else
        raw_data_path = joinpath(data_base, "data", "RTS-GMLC-master_"*run_name_base)
        sys = build_modified_RTS_GMLC_DA_sys(; raw_data = raw_data_path)

        transform_single_time_series!(sys, horizon, interval);

        set_service_model!(template_uc, VariableReserve{ReserveUp}, RangeReserve)
        set_service_model!(template_uc, VariableReserve{ReserveDown}, RangeReserve)
    end


    if lp1 == true
        set_device_model!(template_uc, ThermalStandard, ThermalDispatch)
    else
        set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment) #ThermalStandardUnitCommitment #ThermalDispatchNoMin
        set_device_model!(template_uc, HydroEnergyReservoir, HydroDispatchRunOfRiver)
    end
    set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
    set_device_model!(template_uc, HydroDispatch, FixedOutput)
    set_device_model!(template_uc, RenewableFix, FixedOutput)

    if copper1 == false
        @info "Not copperplate"
        set_device_model!(template_uc, TapTransformer, StaticBranch)
        set_device_model!(template_uc, Line, StaticBranch)
        set_device_model!(template_uc, HVDCLine, HVDCDispatch)
        set_device_model!(template_uc, Transformer2W, StaticBranch)
        set_transmission_model!(template_uc, DCPPowerModel)
    else
        set_transmission_model!(template_uc, CopperPlatePowerModel)
    end

    problems = SimulationProblems(
        UC = OperationsProblem(template_uc, sys, optimizer = solver,balance_slack_variables = true),
    )

    DA_RT_sequence = SimulationSequence(
        problems = problems,
        intervals = intervals,
        ini_cond_chronology = IntraProblemChronology(),
    )
    run_folder = mkpath(joinpath(simulation_folder_base, run_name_base))

    for month in months
        if us ==false
            run_name = "rts-test_"*run_name_base*string(month)
        else
            run_name = run_name_base*string(month)
        end
        run_folder2 = mkpath(joinpath(run_folder,run_name))

        num_steps = days[month]
        simulation_folder = RunScenario(problems,DA_RT_sequence,sys,run_name_base, num_steps,month)
        mv(simulation_folder,joinpath(run_folder2,string(i)),force=true)
        rm(joinpath(simulation_folder_base, run_name),force=true,recursive=true)
    end
end
