# API guide

Import `package:bluez_obex_native/bluez_obex_native.dart`. Linux is the supported
platform. Install the [native prerequisites](../README.md#linux-prerequisites)
before running or compiling an application.

## Client and service lifetime

`await BlueZObexClient.connect()` starts one worker isolate and one session-bus
connection. Always `await client.dispose()` in a `finally` block. Calls submitted
before disposal drain in order; later calls fail. Native calls use D-Bus timeouts,
so disposal during an unresponsive operation can take time.

`BlueZObexClient.devices()` queries `org.bluez` on the system bus. It reads device
metadata and does not change pairing, trust, or connection policy.

`client.getManagedObjects()` returns current object paths.
`client.events` reports initial discovery, additions, removals, properties,
errors, and stream completion. Subscribe immediately after connecting and use
an explicit snapshot to establish current state when needed. Slow/paused
listeners can buffer events; cancel subscriptions when finished.

Bus failure or an OBEX owner change terminates the client's event stream.
Dispose that client and create a new one. Wrappers hold paths and optional last
explicitly read properties; they are not live client-owned caches. Discard
wrappers on removal, including when the service later reuses the same path.
Missing properties currently decode to empty/zero/false defaults.

## Profile operations

- `createSession(address, target: 'pbap')` creates a PBAP session; `target: 'map'`
  selects MAP. Use `session.remove()` when finished, or dispose the owning client.
- `session.phonebook` exposes select, list, search, size, version, filter fields,
  and whole/individual vCard pulls. Select a supported location/book such as
  `select('int', 'pb')` first. Search fields are phone/service dependent.
- `session.messageAccess` exposes folder navigation/listing, message listing,
  filter fields, inbox update, and push. Listing `telecom/msg/inbox` navigates
  from the service's root before listing `inbox`.
- Message wrappers expose properties, download, and read/deleted setters.
  Setters affect the paired phone; deleted-message behavior depends on the phone.
- `client.transfer(path)` exposes properties and cancel/suspend/resume.

Methods unsupported by the phone may return a typed `BlueZObexNativeException`.
Its `operation`, `code`, and optional D-Bus `name`/`message` distinguish remote
failure from input validation errors (`ArgumentError`) and disposal (`StateError`).

## Transfer completion and files

Pull/download/push replies describe a started transfer, not completed data.
Subscribe before issuing the method, because completion may arrive before its
reply. Record statuses until the returned transfer path is known; require
`Status == 'complete'`. Error/cancellation, stream loss, timeout, and removal
without a confirmed complete status are failures. The
[CLI examples](../example/README.md) share this behavior with the Flutter demo.

Pass absolute paths. Files are read or written by the OBEX service running as
the application user; it needs directory/file permissions. Use a private
application directory and a fresh destination filename, and verify the completed
file exists before reading it. Do not assume the service resolves relative paths
against your application's working directory. Contacts/messages contain private
data: retain, display, and delete them only as appropriate for your application.

## Filter maps

The initial API accepts `Map<String, Object?>` filters/arguments. Supported
numeric keys `MaxCount`, `Offset`, `ListStartOffset`, and `StartOffset` encode
as uint16; `SubjectLength` as byte; `Read`, `Priority`, `Transparent`, `Retry`,
and `ResetNewMissedCalls` as bool. `Fields`, `Filter`, `FilterAll`, `FilterAny`,
and `Types` encode as arrays of strings. Other keys encode as strings.
String-array values currently use comma separation, so do not include commas
inside individual items. This is not a general arbitrary-D-Bus-variant API.

Ranges and malformed numeric/boolean values fail before D-Bus dispatch.
Embedded NUL characters in any native string, map key, or map value are rejected.
Check filter support against the service/phone rather than assuming all keys
are accepted by every profile.

## Simulation and raw FFI

`BlueZObexClient.simulated()` provides sample contacts/messages without hardware.
It is a development fixture, not evidence of phone interoperability. Its writes
use the supplied destination path, so use a temporary/private output directory.

Raw FFI declarations are in `bluez_obex_native_bindings_generated.dart`. Initialize
Dart API DL before creating clients. Byte-returning C calls allocate the result
once, return its byte length or a negative status, and require `bluez_obex_free`.
Handles are opaque tokens; never dereference them. Error strings are borrowed
thread-local values and must be copied immediately after a failing call.
