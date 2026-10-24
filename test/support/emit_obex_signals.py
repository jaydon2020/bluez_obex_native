#!/usr/bin/env python3

import dbus
import dbus.lowlevel


TRANSFER_PATH = "/org/bluez/obex/client/session0/transfer0"
TRANSFER_IFACE = "org.bluez.obex.Transfer1"
PROPERTIES = "org.freedesktop.DBus.Properties"


def main():
    bus = dbus.SessionBus()
    foreign = dbus.lowlevel.SignalMessage(
        TRANSFER_PATH, PROPERTIES, "PropertiesChanged"
    )
    foreign.append(
        TRANSFER_IFACE,
        {"Status": dbus.String("foreign")},
        [],
        signature="sa{sv}as",
    )
    bus.send_message(foreign)
    bus.flush()

    control = bus.get_object("org.bluez.obex", "/org/bluez/obex/test")
    control.RunLifecycleSignals(dbus_interface="org.bluez.obex.Test1")


if __name__ == "__main__":
    main()
