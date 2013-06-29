#!/bin/bash

sudo -u "$USER" launchctl remove org.gpgtools.Libmacgpg.jailfree 2>/dev/null
sudo -u "$USER" launchctl remove org.gpgtools.Libmacgpg.xpc 2>/dev/null
sudo -u "$USER" launchctl load /Library/LaunchAgents/org.gpgtools.Libmacgpg.xpc.plist
exit 0
