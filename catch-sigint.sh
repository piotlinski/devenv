#!/bin/bash

trap "echo -e '\nCaught SIGINT, stopping...';exit 0" SIGINT

while :
do
    sleep 1
done
