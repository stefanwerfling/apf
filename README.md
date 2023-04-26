# APF - Android port forwarding

The app can also be used for all other port forwarding.


I needed it to update an app remotely with Android Debugging via OpenVPN with "Wlan Debugging".

1. ```cd ~/Android/Sdk/platform-tools/```
2. ```./adb connect 10.8.0.6:6666```

It would have been easy if I could set the IP, but that's not possible in the Android device. My cell phone can automatically switch to openvpn IP but the tablet cannot. It's probably a problem from different manufacturers or Android versions.
