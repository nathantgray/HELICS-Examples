function broker = hmp_broker_setup(helics_core_type, broker_initstring)
% HMP_BROKER_SETUP configure broker for HELICS_MATPOWER demo

if nargin <1 || isempty(helics_core_type)
    helics_core_type = 'zmq';
end
if nargin <2 || isempty(broker_initstring)
    broker_initstring = '-f 2 --name=mainbroker';
end


%% Create broker
disp('Creating Broker');
broker = helics.helicsCreateBroker(helics_core_type, '', broker_initstring);
disp('Created Broker');

fprintf('Checking if Broker is connected...');
isconnected = helics.helicsBrokerIsConnected(broker);

if isconnected == 1
    fprintf('SUCCESS, Broker created and connected\n');
else
    fprintf('\n')
    error('NOT CONNECTED (helicsBrokerIsConnected return = %d)', isconnected)
end
