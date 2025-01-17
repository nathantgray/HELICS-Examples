# -*- coding: utf-8 -*-
import time
import helics as h
from math import pi

initstring = "-f 2 --name=mainbroker"
fedinitstring = "--broker=mainbroker --federates=1"
deltat = 0.01

helicsversion = h.helicsGetVersion()

print("PI SENDER: Helics version = {}".format(helicsversion))

# Create broker #
print("Creating Broker")
broker = h.helicsCreateBroker("zmq", "", initstring)
print("Created Broker")

print("Checking if Broker is connected")
isconnected = h.helicsBrokerIsConnected(broker)
print("Checked if Broker is connected")

if isconnected == 1:
    print("Broker created and connected")

# Create Federate Info object that describes the federate properties #
fedinfo = h.helicsCreateFederateInfo()

# Set Federate name #
h.helicsFederateInfoSetCoreName(fedinfo, "TestA Federate")

# Set core type from string #
h.helicsFederateInfoSetCoreTypeFromString(fedinfo, "zmq")

# Federate init string #
h.helicsFederateInfoSetCoreInitString(fedinfo, fedinitstring)

# Set the message interval (timedelta) for federate. Note th#
# HELICS minimum message time interval is 1 ns and by default
# it uses a time delta of 1 second. What is provided to the
# setTimedelta routine is a multiplier for the default timedelta.

# Set one second message interval #
h.helicsFederateInfoSetTimeProperty(fedinfo, h.helics_property_time_delta, deltat)

# Create value federate #
vfed = h.helicsCreateCombinationFederate("TestA Federate", fedinfo)
print("PI SENDER: Value federate created")

# Register the publication #
pub = h.helicsFederateRegisterGlobalTypePublication(vfed, "testA", "double", "")
print("PI SENDER: Publication registered")


epid = h.helicsFederateRegisterGlobalEndpoint(vfed, "endpoint1", "")

# fid = h.helicsFederateRegisterFilter(vfed, h.helics_filter_type_delay, "filter1")
# h.helicsFilterAddSourceTarget(fid, "endpoint1")

# h.helicsFilterSet(fid, "delay", 2.0)

# Enter execution mode #
h.helicsFederateEnterExecutingMode(vfed)
print("PI SENDER: Entering execution mode")

# This federate will be publishing deltat*pi for numsteps steps #
this_time = 0.0
value = pi

for t in range(5, 10):
    val = value
    print(f"PI SENDER: Requesting t={t}")
    currenttime = h.helicsFederateRequestTime(vfed, t)
    print(f"PI SENDER: Granted t={currenttime}")
    h.helicsPublicationPublishDouble(pub, val)
    print(
        "PI SENDER: Sending value pi = {} at time {} to PI RECEIVER".format(
            val, currenttime
        )
    )
    print(f"PI SENDER: Sending value {str(t)} via endpoints")
    h.helicsEndpointSendEventRaw(epid, "endpoint2", str(t), t)
    print("PI SENDER: Sent value to endpoint successfully")
    # time.sleep(1)

h.helicsFederateFinalize(vfed)
print("PI SENDER: Federate finalized")

while h.helicsBrokerIsConnected(broker):
    time.sleep(1)

h.helicsFederateFree(vfed)
h.helicsCloseLibrary()

print("PI SENDER: Broker disconnected")
