# -*- coding: utf-8 -*-
import helics as h
import time
import struct

fed = h.helicsCreateCombinationFederateFromConfig("receiver.json")
sub = h.helicsFederateGetSubscription(fed, "data")
h.helicsFederateEnterExecutingMode(fed)
granted_time = -1
request_time = 1000
while granted_time < 10:
    granted_time = h.helicsFederateRequestTime(fed, request_time)
    data = h.helicsInputGetDouble(sub)
    print(f"{granted_time}: Message : {data}  requested time: {request_time}")

h.helicsFederateDisconnect(fed)
h.helicsFederateFree(fed)
h.helicsCloseLibrary()
