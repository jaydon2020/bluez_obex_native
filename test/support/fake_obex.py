#!/usr/bin/env python3

import time

import dbus
import dbus.lowlevel
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib


SERVICE = "org.bluez.obex"
OBJECT_MANAGER = "org.freedesktop.DBus.ObjectManager"
PROPERTIES = "org.freedesktop.DBus.Properties"
TRANSFER_IFACE = "org.bluez.obex.Transfer1"
SESSION_IFACE = "org.bluez.obex.Session1"
PHONEBOOK_IFACE = "org.bluez.obex.PhonebookAccess1"
MESSAGE_ACCESS_IFACE = "org.bluez.obex.MessageAccess1"
TRANSFER_PATH = "/org/bluez/obex/client/session0/transfer0"
SESSION_PATH = "/org/bluez/obex/client/session0"


def transfer_properties(status="active"):
    return {
        "Status": dbus.String(status),
        "Session": dbus.ObjectPath(SESSION_PATH),
    }


class Root(dbus.service.Object):
    def __init__(self, bus):
        super().__init__(bus, "/")
        self.transfer_present = True

    @dbus.service.method(OBJECT_MANAGER, out_signature="a{oa{sa{sv}}}")
    def GetManagedObjects(self):
        objects = {
            "/org/bluez/obex/client/foreign": {
                SESSION_IFACE: {
                    "Destination": "AA:BB:CC:DD:EE:FF",
                    "Target": "0000112f-0000-1000-8000-00805f9b34fb",
                }
            }
        }
        if self.transfer_present:
            objects[TRANSFER_PATH] = {TRANSFER_IFACE: transfer_properties()}
        return objects

    @dbus.service.signal(OBJECT_MANAGER, signature="oa{sa{sv}}")
    def InterfacesAdded(self, path, interfaces):
        pass

    @dbus.service.signal(OBJECT_MANAGER, signature="oas")
    def InterfacesRemoved(self, path, interfaces):
        pass


class Transfer(dbus.service.Object):
    def __init__(self, bus, root):
        super().__init__(bus, TRANSFER_PATH)
        self.root = root
        self.status = "active"

    @dbus.service.method(PROPERTIES, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        return transfer_properties(self.status) if interface == TRANSFER_IFACE else {}

    @dbus.service.signal(PROPERTIES, signature="sa{sv}as")
    def PropertiesChanged(self, interface, changed, invalidated):
        pass

    def set_status(self, status):
        self.status = status
        self.PropertiesChanged(TRANSFER_IFACE, {"Status": status}, [])

    @dbus.service.method(TRANSFER_IFACE)
    def Cancel(self):
        self.set_status("complete")
        self.root.transfer_present = False
        self.root.InterfacesRemoved(TRANSFER_PATH, [TRANSFER_IFACE])

    @dbus.service.method(TRANSFER_IFACE)
    def Suspend(self):
        time.sleep(0.05)
        self.set_status("suspended")

    @dbus.service.method(TRANSFER_IFACE)
    def Resume(self):
        time.sleep(0.05)
        self.set_status("active")


class Client(dbus.service.Object):
    @dbus.service.method(
        "org.bluez.obex.Client1", in_signature="sa{sv}", out_signature="o"
    )
    def CreateSession(self, _destination, args):
        if args.get("Target") != "pbap":
            raise dbus.exceptions.DBusException(
                "Target required", name="org.bluez.obex.Error.InvalidArguments"
            )
        return dbus.ObjectPath(SESSION_PATH)


class Session(dbus.service.Object):
    calls = 0

    @dbus.service.method(SESSION_IFACE, out_signature="s")
    def GetCapabilities(self):
        self.calls += 1
        time.sleep(0.25)
        return "capabilities:" + str(self.calls)

    @dbus.service.method(PHONEBOOK_IFACE, out_signature="q")
    def GetSize(self):
        time.sleep(0.05)
        return dbus.UInt16(42)

    @dbus.service.method(MESSAGE_ACCESS_IFACE)
    def UpdateInbox(self):
        time.sleep(0.05)


class MessageAccess(dbus.service.Object):
    @dbus.service.method(MESSAGE_ACCESS_IFACE, in_signature="s")
    def SetFolder(self, _folder):
        raise dbus.exceptions.DBusException(
            "Folder unavailable", name="org.bluez.obex.Error.Failed"
        )

    @dbus.service.method(
        MESSAGE_ACCESS_IFACE, in_signature="sa{sv}", out_signature="a{oa{sv}}"
    )
    def ListMessages(self, _folder, _filters):
        return {
            dbus.ObjectPath(SESSION_PATH + "/message0"): {
                "Subject": "x" * (1024 * 1024 + 1)
            }
        }

    @dbus.service.method(MESSAGE_ACCESS_IFACE)
    def UpdateInbox(self):
        time.sleep(0.05)


class Navigation(dbus.service.Object):
    def __init__(self, bus, path):
        super().__init__(bus, path)
        self.folder = "/"

    @dbus.service.method(MESSAGE_ACCESS_IFACE, in_signature="s")
    def SetFolder(self, folder):
        if folder not in ("/telecom/msg", "/telecom/msg/inbox"):
            raise dbus.exceptions.DBusException(
                "Bad Request", name="org.bluez.obex.Error.Failed"
            )
        self.folder = folder

    @dbus.service.method(
        MESSAGE_ACCESS_IFACE, in_signature="sa{sv}", out_signature="a{oa{sv}}"
    )
    def ListMessages(self, folder, _filters):
        if self.folder != "/telecom/msg" or folder != "inbox":
            raise dbus.exceptions.DBusException(
                "Wrong folder", name="org.bluez.obex.Error.Failed"
            )
        return {
            dbus.ObjectPath("/org/bluez/obex/client/navigation/message0"): {
                "Subject": "Navigated inbox"
            }
        }


class TestControl(dbus.service.Object):
    def __init__(self, bus, root, transfer):
        super().__init__(bus, "/org/bluez/obex/test")
        self.bus = bus
        self.root = root
        self.transfer = transfer

    def malformed(self, path, interface, member, argument, signature):
        message = dbus.lowlevel.SignalMessage(path, interface, member)
        message.append(argument, signature=signature)
        self.bus.send_message(message)

    @dbus.service.method("org.bluez.obex.Test1")
    def RunLifecycleSignals(self):
        self.malformed(
            TRANSFER_PATH,
            PROPERTIES,
            "PropertiesChanged",
            TRANSFER_IFACE,
            "s",
        )
        self.malformed(
            "/",
            OBJECT_MANAGER,
            "InterfacesAdded",
            dbus.ObjectPath(TRANSFER_PATH),
            "o",
        )
        self.transfer.PropertiesChanged(
            TRANSFER_IFACE, {"Status": dbus.Int32(7)}, []
        )
        self.root.InterfacesAdded(
            TRANSFER_PATH, {TRANSFER_IFACE: transfer_properties("active")}
        )
        self.root.transfer_present = False
        self.root.InterfacesRemoved(TRANSFER_PATH, [TRANSFER_IFACE])
        self.root.InterfacesRemoved(TRANSFER_PATH, [TRANSFER_IFACE])
        self.transfer.set_status("stale")
        self.transfer.status = "queued"
        self.root.transfer_present = True
        self.root.InterfacesAdded(
            TRANSFER_PATH, {TRANSFER_IFACE: transfer_properties("queued")}
        )
        self.transfer.set_status("complete")
        self.bus.flush()


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    name = dbus.service.BusName(SERVICE, bus, do_not_queue=True)
    root = Root(bus)
    transfer = Transfer(bus, root)
    objects = [
        Client(bus, "/org/bluez/obex"),
        Session(bus, SESSION_PATH),
        MessageAccess(bus, "/org/bluez/obex/client/large"),
        Navigation(bus, "/org/bluez/obex/client/navigation"),
        TestControl(bus, root, transfer),
    ]
    print("ready", flush=True)
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
