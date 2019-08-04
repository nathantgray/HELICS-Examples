# -*- coding: utf-8 -*-
import helics as h
import numpy as np

# ---Setup---
# Local setup
fedinitstring = "--federates=1"  # Note: In this example, the MATPOWER federate also starts the broker
deltat = 60
my_fed_name = "HMP_python"
my_endpt_name = "Loads_all"

ed_interval = 15*60    # Time in sec, must be >0
response_delay = 3*60   # Time in sec after receiving loads to publish LMPs
timeout = ed_interval*10
sim_duration = 24*60*60    # Total simulation time in sec

load_node_map = {'b2': 2, 'b3': 3, 'b4': 4}

# Information about other federate
their_fed_name = 'HMP_MATLAB'
their_endpt_name = 'LMP'

# Display summary information
helicsversion = h.helicsGetVersion()
print("HMP_PYLOAD: Helics version = {}".format(helicsversion))

# ---Setup Core Federate---
# TODO: convert to reading setup from a file

# Create Federate Info object that describes the federate properties #
fedinfo = h.helicsCreateFederateInfo()

# Set Federate name #
h.helicsFederateInfoSetCoreName(fedinfo, my_fed_name)

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
my_fed = h.helicsCreateCombinationFederate(my_fed_name, fedinfo)
print("HMP_PYLOAD: Combo federate created")

# Register our endpoint for receiving LMPs from market
# Note that by default, an Endpoint's name is prepended with the federate
# name and a separator ('/') to create unique names within the federation
my_endpt = h.helicsFederateRegisterEndpoint(my_fed, my_endpt_name, 'string')
print('HMP_PYLOAD: Our Endpoint registered as "{}/{}"\n'.format(my_fed_name, my_endpt_name))


# Register our publications. Use global publications b/c we are using a single federate
# to represent multiple federates
pubs = {}
for load_bus in load_node_map:
    this_pub_name: str = load_bus + "/P"
    pubs[load_bus] = h.helicsFederateRegisterGlobalTypePublication(my_fed, this_pub_name, "double", "")
    print("HMP_PYLOAD: Publication registered: {}".format(this_pub_name))

# Enter execution mode #
h.helicsFederateEnterExecutingMode(my_fed)
print("HMP_PYLOAD: Entering execution mode")

# # This federate will be publishing deltat*pi for numsteps steps #
# this_time = 0.0
#
# for t in range(5, 10):
#     val = value
#
#     currenttime = h.helicsFederateRequestTime(my_fed, t)
#
#     h.helicsPublicationPublishDouble(pub, val)
#     print(
#         "HMP_PYLOAD: Sending value pi = {} at time {} to PI RECEIVER".format(
#             val, currenttime
#         )
#     )
#
#     time.sleep(1)

h.helicsFederateFinalize(my_fed)
h.helicsFederateFree(my_fed)
h.helicsCloseLibrary()

print("HMP_PYLOAD: Federate finalized")
