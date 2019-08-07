% HELICS_MATPWR matlab function for basic matpower-helics-python with optional plot 
%
% Usage:
%  1. In MATLAB: 
%     >> helics_matpwr(true)
%  3. At a terminal/command line:
%     $ python hmp_load.py


%% Configuration/Setup
% Local setup
my_fed_name = 'HMP_MATLAB';
my_endpt_name = 'ISO';

% Powerflow case
mp_case = 'case5';
init_load_scale = 0.4825;

% Timing
deltat = 60;  %Base time interval (seconds)
sced_interval = 15*60;    %Time in sec, must be >0
response_delay = 3*60;   %Time in sec after receiving loads to publish LMPs
sim_duration = 24*60*60;    %Total simulation time in sec

wait_timeout = 60;  %Maximum wall clock time to wait for other federate response (sec)

%Information about the other federate
their_fed_name = 'HMP_python';
their_endpt_name = 'Loads_all';

% HELICS options
hmp_start_broker = true;    % Optionally start the broker from this federate

%MATPOWER helpers
mp_idx.LMP = 14;
mp_idx.P_load = 3;


%% Initialize 
% MATPOWER paths (for this run only)
if not(exist('mpver','file'))
    fprintf('MATPOWER mpver.m file not found in path, adding MATPOWER to path for this session\n')
    install_matpower(1, 0, 0); %options: temp path update, permanant, verbose, remove first
end

% Compute derived quantities
n_t_step = round(sim_duration/sced_interval);

% Setup powerflow case
pf_case = loadcase(mp_case);
base_loads = pf_case.bus(:, mp_idx.P_load);
n_bus = length(base_loads);
bus_names = cell(n_bus, 1);
for b = 1:n_bus
    bus_names{b,1} = sprintf('b%d', b);
end

% Setup load
load_idx = find(base_loads > 0);
load_node_map = [bus_names(load_idx), num2cell(load_idx)];
n_loads = size(load_node_map,1);
init_load_scale = init_load_scale * ones(n_bus, 1);

% Configure Federate info, etc.
their_endpt_fullname = sprintf('%s/%s', their_fed_name, their_endpt_name);

%% HELICS-related startup
% Load HELICS library in MATLAB, funcations available via helics.*
helicsStartup()

% Provide summary information
helicsversion = helics.helicsGetVersion();

fprintf('%s: Helics version = %s\n', my_fed_name, helicsversion)

% Create broker (if desired)
if hmp_start_broker
    broker=hmp_broker_setup();
end

% Create HELICS Federate
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
% Use asynchronous execution start so we can run a time out
fprintf('%s: Attempting to entering execution mode (async)...',my_fed_name);

%Start Exectution mode and timeout timer
helics.helicsFederateEnterExecutingModeAsync(my_fed);
timeout_clock = tic;

while toc(timeout_clock) < wait_timeout && not(helics.helicsFederateIsAsyncOperationCompleted(my_fed))
        pause(0.01)
end

if helics.helicsFederateIsAsyncOperationCompleted(my_fed)
    helics.helicsFederateEnterExecutingModeComplete(my_fed)
    fprintf('SUCCESS\n')
else
    fprintf('TIMEOUT (%d sec)\n', wait_timeout)
    fprintf('Shutting down...')
    % Note: our federate is stuck so won't respond to graceful cleaning
    if hmp_start_broker
        helics.helicsBrokerDestroy(broker); 
        fprintf('Broker...')
    end
    try
        helics.helicsCloseLibrary();
        fprintf('Library...')
    catch
        fprintf('(Can''t close Library)...')
    end
    fprintf('Bye\n\n')
end

%% Pre-execution
% Initialize time
granted_time = 0;

% Initialize data storage
lmp = zeros(n_bus, n_t_step);
P_load = zeros(n_bus, n_t_step);

% Compute initial loads and first lmp
P_load(:, 1) = base_loads .* init_load_scale;

% Setup plot 


%% Execution Loop
for t_idx = 2:n_t_step+1    %SHift by one for period 0
    % Run OPF and compute prices 
    lmp(:, t_idx) = hmp_run_opf(pf_case, P_load(:, t_idx-1));
    str_to_send = hmp_lmp2json(lmp(:, t_idx), load_node_map);

    %Send current prices
    fprintf('%s: Sending message "%s" from "%s" to "%s" at time %4.1f... ', ...
        my_fed_name, str_to_send, my_endpt_name, their_endpt_fullname, granted_time);
    helics.helicsEndpointSendMessageRaw(my_endpt, their_endpt_fullname, str_to_send);
    fprintf('DONE \n');

    %Wait for other federate to send the load data via multiple subscriptions (with timeout)
    fprintf('Waiting for Data from load federate(s)...')
    timeout_clock = tic;
    data_rx = false(n_loads,1);
    while toc(timeout_clock) < wait_timeout
        for node_idx = 1:n_loads
            % Update the record of which data has been received
            data_rx(node_idx) = data_rx(node_idx) || helics.helicsInputIsUpdated(sub(node_idx));
        end
        
        % Check if we have gotten all of the load data
        if all(data_rx)
            break 
        else
            %If any has not been updated, wait a bit more then keep looping
            pause(0.01)
        end
    end
    
    if all(data_rx)
        fprintf('RECEIVED\n')
    else
        fprintf('TIMEOUT (%d sec)\n', wait_timeout)
        
    end
    
    %Gather sent data
    for node_idx = 1:n_loads
        P_load(node_idx, t_id) = helicsInputGetDouble(sub(node_idx));
        fprintf('%s: Received actual load of %gMW at time %4.1f from %s\n', ...
            my_fed_name, P_load(node_idx, t_id), granted_time, load_node_map{node_idx, 1});
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



