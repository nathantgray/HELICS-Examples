% HELICS_MATPWR matlab function for basic matpower-helics-python with optional plot 
%
% Usage:
%  1. In MATLAB: 
%     >> helics_matpwr(true)
%  3. At a terminal/command line:
%     $ python hmp_load.py


%% Initialize 
% HELICS library in MATLAB
helicsStartup()
% MATPOWER paths (for this run only)
if not(exist('case5','file'))
    fprintf('MATPOWER case5.m file not found in path, setting up MATPOWER temporarily\n')
    install_matpower(1, 0, 0); %options: temp update, permanant, verbose, remove first
end

%Various
idx.LMP = 14;
idx.P_load = 3;


%% Configuration
%Local setup
my_fed_name = 'HMP_MATLAB';
my_endpt_name = 'ISO';

%Timing
deltat = 60;  %Base time interval (seconds)
sced_interval = 15*60;    %Time in sec, must be >0
response_delay = 3*60;   %Time in sec after receiving loads to publish LMPs
sim_duration = 24*60*60;    %Total simulation time in sec
n_t_step = round(sim_duration/sced_interval);

response_timeout = 60;  %Maximum wall clock time to wait for other federate response

%Setup powerflow case, and load info for co-simulation
mp_case = 'case5';
pf_case = loadcase(mp_case);
base_loads = pf_case.bus(:, idx.P_load);
n_bus = length(base_loads);
bus_names = cell(n_bus, 1);
for b = 1:n_bus
    bus_names{b,1} = sprintf('b%d', b);
end
load_idx = find(base_loads > 0);
load_node_map = [bus_names(load_mask), num2cell(load_idx)];
n_loads = size(load_node_map,1);

init_load_scale = 0.4825 * ones(n_bus, 1);

%Information about the other federate
their_fed_name = 'HMP_python';
their_endpt_name = 'Loads_all';
their_endpt_fullname = sprintf('%s/%s', their_fed_name, their_endpt_name);

% % IMPORTANT, Message federates are not granted times
% % earlier than they request, so the final time request must match that of
% % the other federate or the federate requesting the later time will
% % hang. As a work around we ensure we use the same delay for this final
% % request.
% %TODO: more gracefully handle 2 federates requesting unequal final times
% their_response_delay = 1*60;

% HELICS options
% Optionally start the broker from this federate
hmp_start_broker = true;

%% Provide summary information
helicsversion = helics.helicsGetVersion();

fprintf('%s: Helics version = %s\n', my_fed_name, helicsversion)

%% Create broker (if desired)
if hmp_start_broker
    broker=hmp_broker_setup();
end

%% Create HELICS Federate
my_fed = hmp_fed_setup(my_fed_name, deltat);

%% Add message endpoints and value data pub/sub
%Register our endpoint (where we will publish LMPs)
% Note that by default, an Endpoint's name is prepended with the federate
% name and a separator ('/') to create unique names within the federation
my_endpt = helics.helicsFederateRegisterEndpoint(my_fed, my_endpt_name, 'string');
fprintf('%s: Our Endpoint registered as "%s/%s"\n', my_fed_name, my_fed_name, my_endpt_name);

% Subscribe to the load node(s) publications
for node_idx = 1:n_loads
    sub_name = [load_node_map{node_idx, 1}, '/P'];
    sub(node_idx) = helics.helicsFederateRegisterSubscription(my_fed, sub_name, ''); %#ok<SAGROW>
    fprintf('%s: subscribe to "%s"\n', my_fed_name, sub_name);
end


%% Start execution
% Warning, entering execution will hang if the other federates don't join
fprintf('%s: Attempting to entering execution mode...',my_fed_name);
helics.helicsFederateEnterExecutingMode(my_fed);
fprintf('SUCCESS\n');

%% Pre-execution
% Initialize time
granted_time = 0;
next_t = 0;
% Initialize data storage
lmp = zeros(n_bus, n_t_step);
P_load = zeros(n_bus, n_t_step);

% Compute initial loads and first lmp
P_load(:, next_t+1) = base_loads .* init_load_scale;

% Setup plot 


%% Execution Loop
for next_t = sced_interval:sced_interval:sim_duration
    % Run OPF and compute prices 
    lmp(:, next_t+1) = hmp_run_opf(pf_case, P_load(:, next_t+1));
    str_to_send = hmp_lmp2json(lmp(:, next_t+1), load_node_map);

    %Send current prices
    fprintf('%s: Sending message "%s" from "%s" to "%s" at time %4.1f... ', ...
        my_fed_name, str_to_send, my_endpt_name, their_endpt_fullname, granted_time);
    helics.helicsEndpointSendMessageRaw(my_endpt, their_endpt_fullname, str_to_send);
    fprintf('DONE \n');

    %Wait for other federate to send the load data via multiple subscriptions (with timeout)
    timeout_clock = tic;
    data_rx = false(n_loads,1);
    while toc(timeout_clock) < response_timeout
        for node_idx = 1:n_loads
            % Update the record of which data has been received
            data_rx(node_idx) = data_rx(node_idx) || helicsInputIsUpdated(sub(node_idx));
        end
        
        % Check if we have gotten all of the load data
        if all(data_rx)
            break 
        else
            %If any has not been updated, wait a bit more then keep looping
            pause(0.01)
        end
    end
    
    %Gather sent data
    for node_idx = 1:n_loads
        value = helicsInputGetDouble(sub(node_idx));
        fprintf('PI RECEIVER: Received value = %g at time %4.1f from PI SENDER\n', value, granted_time);
    end
    
    %Wait for desired next time
    while granted_time < next_t
        granted_time = helics.helicsFederateRequestTime(my_fed, next_t);
    end

end


% %% Send a final message so audience knows to stop
% to_send = 'Goodbye';
% fprintf('KNOCK KNOCK: Sending message "%s" to "%s" at time %4.1f... ', to_send, their_endpt_fullname, granted_time);
% helics.helicsEndpointSendMessageRaw(my_endpt, their_endpt_fullname, to_send);
% fprintf('DONE \n');
% %Important: The message will not actually be made available to the receiver
% %until we advance the time
% granted_time = helics.helicsFederateRequestTime(my_fed, granted_time + their_response_delay);
% fprintf('KNOCK KNOCK: Shutting Down (Final time granted= %4.1f)\n', granted_time);


%% Shutdown

if hmp_start_broker
    % If we started the broker in this thread, we have to be careful
    % sequencing the shutdown in hopes of doing so cleanly
    helics.helicsFederateFinalize(my_fed);
    disp([my_fed_name, ': Federate finalized']);

    %Make sure the broker is gone in case we have a lingering low-level
    %reference (to avoid memory leaks)
    helics.helicsBrokerWaitForDisconnect(broker,-1);
    
    disp([my_fed_name, ': Broker disconnected']);

    helics.helicsFederateFree(my_fed);
    helics.helicsCloseLibrary();
else
    %But if we just setup the federate, we can simply call endFederate
    helics.helicsFederateDestroy(my_fed); %#ok<UNRCH>  
    disp([my_fed_name, ': Federate finalized']);
end



