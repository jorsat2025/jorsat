#!/bin/bash

# Aprobacion de todos los CSR en estado pending

for i in `oc get csr --no-headers | grep -i pending |  awk '{ print $1 }'`; do oc adm certificate approve $i; done
