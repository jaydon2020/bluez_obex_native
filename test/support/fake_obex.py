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
  return {path:{iface:{'Status':'active','Session':dbus.ObjectPath('/org/bluez/obex/client/session0')}},
          '/org/bluez/obex/client/foreign': {'org.bluez.obex.Session1': {
              'Destination': 'AA:BB:CC:DD:EE:FF',
              'Target': '0000112f-0000-1000-8000-00805f9b34fb'}}}
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
class Client(dbus.service.Object):
 @dbus.service.method('org.bluez.obex.Client1', in_signature='sa{sv}', out_signature='o')
 def CreateSession(self, destination, args):
  if args.get('Target') != 'pbap':
   raise dbus.exceptions.DBusException('Target required', name='org.bluez.obex.Error.InvalidArguments')
  return dbus.ObjectPath('/org/bluez/obex/client/session0')
client = Client(bus, '/org/bluez/obex')
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
