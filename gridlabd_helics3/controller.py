# -*- coding: utf-8 -*-
import helics as h
import time
import struct
import matplotlib.pyplot as plt


initstring = "-f 2 --name=mainbroker"
broker = h.helicsCreateBroker("zmq", "", initstring)

fed = h.helicsCreateCombinationFederateFromConfig("controller_config.json")
sub_n3_va = h.helicsFederateGetSubscription(fed, "gld/node_3_A")
sub_n5_va = h.helicsFederateGetSubscription(fed, "gld/node_5_A")
sub_sw23_p = h.helicsFederateGetSubscription(fed, "gld/switch_2_3")
sub_sw45_p = h.helicsFederateGetSubscription(fed, "gld/switch_4_5")
pub_load3_a = h.helicsFederateGetPublication(fed, "node_3_load_A")
pub_load3_b = h.helicsFederateGetPublication(fed, "node_3_load_B")
pub_load3_c = h.helicsFederateGetPublication(fed, "node_3_load_C")
pub_load5_a = h.helicsFederateGetPublication(fed, "node_5_load_A")
pub_load5_b = h.helicsFederateGetPublication(fed, "node_5_load_B")
pub_load5_c = h.helicsFederateGetPublication(fed, "node_5_load_C")

h.helicsFederateEnterExecutingMode(fed)
granted_time = -1
request_time = 1000
n3_va = []
n5_va = []
sw23_p = []
sw45_p = []
while granted_time < request_time:
    granted_time = h.helicsFederateRequestTime(fed, request_time)
    print(granted_time)
    n3_va.append(abs(h.helicsInputGetComplex(sub_n3_va)))
    n5_va.append(abs(h.helicsInputGetComplex(sub_n5_va)))
    sw23_p.append(h.helicsInputGetComplex(sub_sw23_p).imag)
    sw45_p.append(h.helicsInputGetComplex(sub_sw45_p).imag)
    if granted_time == 3:
        h.helicsPublicationPublishRaw(pub_load3_a, "400000.0+0.0j")
        h.helicsPublicationPublishRaw(pub_load3_b, "400000.0+0.0j")
        h.helicsPublicationPublishRaw(pub_load3_c, "400000.0+0.0j")
        print(f"{granted_time}: sending publication")
    # print(f"{granted_time}: Message : {data}  requested time: {request_time}")


h.helicsFederateFinalize(fed)
h.helicsFederateFree(fed)
h.helicsCloseLibrary()

# https://matplotlib.org/devdocs/gallery/subplots_axes_and_figures/subplots_demo.html
fig, axs = plt.subplots(2)
fig.suptitle('Voltage and Power Plots')
axs[0].plot(n3_va)
axs[0].plot(n5_va)
axs[1].plot(sw23_p)
axs[1].plot(sw45_p)
plt.show()