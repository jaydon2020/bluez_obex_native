# OBEX Phone Studio

Flutter Linux control surface for the complete PBAP, MAP, and Transfer1 API
exposed by `bluez_obex_native`.

The app lists Bluetooth devices already connected to this computer and selects
the first one automatically. Choose another connected device on **Overview**
or refresh after connecting a phone in system settings. PBAP and MAP sessions
open when you use their controls; the phone must advertise the matching UUID.

## Workspaces

- **Overview** — connected device selection, managed objects, Session1
  properties, and capabilities.
- **Contacts** — Select, List, Search, PullAll, Pull, GetSize, UpdateVersion,
  ListFilterFields, all PhonebookAccess1 properties, and parsed vCard fields.
- **Messages** — SetFolder, ListFolders, ListMessages, UpdateInbox,
  PushMessage, ListFilterFields, SupportedTypes, every Message1 property,
  download attachment selection, and read/deleted writes.
- **Transfers** — every Transfer1 property plus Cancel, Suspend, and Resume.
- **Activity** — live typed ObjectManager property, addition, removal, transfer,
  and error events.

Event ownership is scoped to the endpoint. Switching endpoints or closing the
widget aborts transfer waiters, cancels the event subscription, removes both
OBEX sessions, disposes the client, and finally deletes temporary files.

Run and test:

```sh
flutter run -d linux
flutter test
```

Build:

```sh
flutter build linux
```
