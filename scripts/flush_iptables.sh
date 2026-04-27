#!/bin/bash

# Clear and save iptables rules
iptables --flush
service iptables save

