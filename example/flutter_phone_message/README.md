# OBEX Phone Studio

Flutter Linux control surface for the complete PBAP, MAP, and Transfer1 API
exposed by `bluez_obex_native`.

The app starts with a deterministic simulated phone. Select **System BlueZ**
to use a connected physical phone. The phone must advertise the PBAP or MAP
UUID before the matching workspace is enabled.

## Workspaces

- **Overview** — endpoint selection, BlueZ devices, managed objects, Session1
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
