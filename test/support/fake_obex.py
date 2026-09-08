import dbus, dbus.service, dbus.mainloop.glib
from gi.repository import GLib
import time

dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
name = dbus.service.BusName('org.bluez.obex', bus)
path = '/org/bluez/obex/client/session0/transfer0'
iface = 'org.bluez.obex.Transfer1'
class Root(dbus.service.Object):
 @dbus.service.method('org.freedesktop.DBus.ObjectManager', out_signature='a{oa{sa{sv}}}')
 def GetManagedObjects(self):
  return {path:{iface:{'Status':'active','Session':dbus.ObjectPath('/org/bluez/obex/client/session0')}}}
 @dbus.service.signal('org.freedesktop.DBus.ObjectManager', signature='oas')
 def InterfacesRemoved(self, path, interfaces): pass
class Transfer(dbus.service.Object):
 @dbus.service.signal('org.freedesktop.DBus.Properties', signature='sa{sv}as')
 def PropertiesChanged(self, interface, changed, invalidated): pass
 @dbus.service.method(iface)
 def Cancel(self):
  self.PropertiesChanged(iface, {'Status':'complete'}, [])
  self.remove_from_connection()
  root.InterfacesRemoved(path,[iface])
class Session(dbus.service.Object):
 @dbus.service.method('org.bluez.obex.Session1', out_signature='s')
 def GetCapabilities(self):
  time.sleep(0.25)
  return 'capabilities'
session = Session(bus, '/org/bluez/obex/client/session0')
root = Root(bus, '/')
transfer = Transfer(bus,path)
print('ready',flush=True)
GLib.MainLoop().run()
