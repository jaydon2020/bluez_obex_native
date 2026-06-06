// codec.dart - GlazeCodec for decoding BlueZ OBEX native payloads.
// Matches the binary encoding in glaze_meta.h (little-endian, length-prefixed).

import 'dart:convert';
import 'dart:typed_data';

import 'types.dart';

/// Decodes glaze binary payloads from the native bridge.
class GlazeCodec {
  GlazeCodec._();

  static T decode<T>(Uint8List data, int offset) {
    final r = _Reader(data, offset);

    if (T == BlueZObexProperty) {
      return _decodeObexProperty(r) as T;
    } else if (T == BlueZObexSessionProps) {
      return _decodeObexSessionProps(r) as T;
    } else if (T == BlueZObexTransferProps) {
      return _decodeObexTransferProps(r) as T;
    } else if (T == BlueZObexPhonebookProps) {
      return _decodeObexPhonebookProps(r) as T;
    } else if (T == BlueZObexPhonebookEntry) {
      return _decodeObexPhonebookEntry(r) as T;
    } else if (T == BlueZObexMessageFolder) {
      return _decodeObexMessageFolder(r) as T;
    } else if (T == BlueZObexMessageProps) {
      return _decodeObexMessageProps(r) as T;
    } else if (T == BlueZObexTransferResult) {
      return _decodeObexTransferResult(r) as T;
    } else if (T == BlueZObexManagedObjects) {
      return _decodeObexManagedObjects(r) as T;
    } else if (T == BlueZObexObjectRemoved) {
      return _decodeObexObjectRemoved(r) as T;
    } else if (T == BlueZObexError) {
      return _decodeObexError(r) as T;
    }
    throw ArgumentError('Unknown type: $T');
  }

  static BlueZObexProperty _decodeObexProperty(_Reader r) {
    return BlueZObexProperty(key: r.readString(), value: r.readString());
  }

  static BlueZObexSessionProps _decodeObexSessionProps(_Reader r) {
    return BlueZObexSessionProps(
      objectPath: r.readString(),
      source: r.readString(),
      destination: r.readString(),
      channel: r.readUint8(),
      target: r.readString(),
      root: r.readString(),
    );
  }

  static BlueZObexTransferProps _decodeObexTransferProps(_Reader r) {
    return BlueZObexTransferProps(
      objectPath: r.readString(),
      status: r.readString(),
      session: r.readString(),
      name: r.readString(),
      type: r.readString(),
      time: r.readUint64(),
      size: r.readUint64(),
      transferred: r.readUint64(),
      filename: r.readString(),
    );
  }

  static BlueZObexPhonebookProps _decodeObexPhonebookProps(_Reader r) {
    return BlueZObexPhonebookProps(
      objectPath: r.readString(),
      folder: r.readString(),
      databaseIdentifier: r.readString(),
      primaryCounter: r.readString(),
      secondaryCounter: r.readString(),
      fixedImageSize: r.readBool(),
    );
  }

  static BlueZObexPhonebookEntry _decodeObexPhonebookEntry(_Reader r) {
    return BlueZObexPhonebookEntry(vcard: r.readString(), name: r.readString());
  }

  static BlueZObexMessageFolder _decodeObexMessageFolder(_Reader r) {
    return BlueZObexMessageFolder(name: r.readString());
  }

  static BlueZObexMessageProps _decodeObexMessageProps(_Reader r) {
    return BlueZObexMessageProps(
      objectPath: r.readString(),
      folder: r.readString(),
      subject: r.readString(),
      timestamp: r.readString(),
      sender: r.readString(),
      senderAddress: r.readString(),
      replyTo: r.readString(),
      recipient: r.readString(),
      recipientAddress: r.readString(),
      type: r.readString(),
      size: r.readUint64(),
      text: r.readBool(),
      status: r.readString(),
      attachmentSize: r.readUint64(),
      priority: r.readBool(),
      read: r.readBool(),
      deleted: r.readBool(),
      sent: r.readBool(),
      protected: r.readBool(),
    );
  }

  static BlueZObexTransferResult _decodeObexTransferResult(_Reader r) {
    return BlueZObexTransferResult(
      transferPath: r.readString(),
      properties: r.readObexPropertyList(),
    );
  }

  static BlueZObexManagedObjects _decodeObexManagedObjects(_Reader r) {
    return BlueZObexManagedObjects(
      sessions: r.readStringList(),
      transfers: r.readStringList(),
      phonebooks: r.readStringList(),
      messageAccesses: r.readStringList(),
      messages: r.readStringList(),
    );
  }

  static BlueZObexObjectRemoved _decodeObexObjectRemoved(_Reader r) {
    return BlueZObexObjectRemoved(
      objectPath: r.readString(),
      interfaceName: r.readString(),
    );
  }

  static BlueZObexError _decodeObexError(_Reader r) {
    return BlueZObexError(
      objectPath: r.readString(),
      name: r.readString(),
      message: r.readString(),
    );
  }
}

class _Reader {
  final ByteData _data;
  final int _length;
  int _offset;

  _Reader(Uint8List bytes, int offset)
    : _data = bytes.buffer.asByteData(bytes.offsetInBytes),
      _length = bytes.length,
      _offset = offset;

  void _checkBounds(int needed) {
    if (_offset + needed > _length) {
      throw RangeError(
        'Codec read overrun: need $needed bytes at offset $_offset, '
        'but buffer is $_length bytes',
      );
    }
  }

  bool readBool() {
    _checkBounds(1);
    final v = _data.getUint8(_offset) != 0;
    _offset += 1;
    return v;
  }

  int readUint8() {
    _checkBounds(1);
    final v = _data.getUint8(_offset);
    _offset += 1;
    return v;
  }

  int readUint64() {
    _checkBounds(8);
    final v = _data.getUint64(_offset, Endian.little);
    _offset += 8;
    return v;
  }

  String readString() {
    final len = _readUint32();
    _checkBounds(len);
    final bytes = Uint8List.view(
      _data.buffer,
      _data.offsetInBytes + _offset,
      len,
    );
    _offset += len;
    return utf8.decode(bytes);
  }

  List<BlueZObexProperty> readObexPropertyList() {
    final count = _readUint32();
    return List.generate(
      count,
      (_) => BlueZObexProperty(key: readString(), value: readString()),
    );
  }

  List<String> readStringList() {
    final count = _readUint32();
    return List.generate(count, (_) => readString());
  }

  int _readUint32() {
    _checkBounds(4);
    final v = _data.getUint32(_offset, Endian.little);
    _offset += 4;
    return v;
  }
}
