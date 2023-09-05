#!/bin/bash
tailscaled &
tailscale up --authkey=$TS_AUTHKEY --hostname=$TS_HOSTNAME --accept-routes &
/usr/sbin/sshd -D -e &
exec "$@"
