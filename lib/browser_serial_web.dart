import 'dart:js_interop';

@JS('aquaSerial.connect')
external JSPromise<JSAny?> _connect(JSFunction onData, JSFunction onClose);
@JS('aquaSerial.disconnect')
external JSPromise<JSAny?> _disconnect();
@JS('aquaSerial.write')
external JSPromise<JSAny?> _write(JSString text);

Future<void> connect(
  void Function(List<int>) onData,
  void Function() onClose,
) async {
  await _connect(
    ((JSUint8Array bytes) => onData(bytes.toDart)).toJS,
    (() => onClose()).toJS,
  ).toDart;
}

Future<void> disconnect() async {
  await _disconnect().toDart;
}

Future<void> write(String text) async {
  await _write(text.toJS).toDart;
}
