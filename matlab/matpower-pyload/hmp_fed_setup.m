function combo_fed = hmp_fed_setup(hmp_fed_name, deltat, helics_core_type, fed_initstring)
% HMP_FED_SETUP Setup the federate itself for HELICS-MATPOWER-Pyload demo 

if nargin <3 || isempty(helics_core_type)
    helics_core_type = 'zmq';
end
if nargin <4 || isempty(fed_initstring)
    fed_initstring = '--broker=mainbroker --federates=1';
end

%% Create Federate Info object that describes the federate properties
fedinfo = helics.helicsCreateFederateInfo();
assert(not(isempty(fedinfo)))

% Set core type from string
helics.helicsFederateInfoSetCoreTypeFromString(fedinfo, helics_core_type);

% Federate init string
helics.helicsFederateInfoSetCoreInitString(fedinfo, fed_initstring);


% Note:
% HELICS minimum message time interval is 1 ns and by default
% it uses a time delta of 1 second. What is provided to the
% setTimedelta routine is a multiplier for the default timedelta 
% (default unit = seconds).

% Set one message interval
helics.helicsFederateInfoSetTimeProperty(fedinfo,helics.helics_property_time_delta,deltat);
helics.helicsFederateInfoSetIntegerProperty(fedinfo,helics.helics_property_int_log_level,helics.helics_log_level_warning);

%% Actually create combination federate
combo_fed = helics.helicsCreateCombinationFederate(hmp_fed_name,fedinfo);
disp([hmp_fed_name, ': Combo federate created']);

