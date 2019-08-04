function [prices, pf_case] = hmp_run_opf(pf_case, loads)
% HMP_RUN_OPF core helper function to actually solve the OPF based on updated loads 

idx.LMP = 14;
idx.P_load = 3;

% Update loads
pf_case.bus(:,idx.P_load) = loads;
% Actually run powerflow
pf_case = runopf(pf_case);

% Extract LMP
prices = pf_case.bus(:, idx.LMP);