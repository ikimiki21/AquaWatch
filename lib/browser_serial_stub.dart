Future<void> connect(
  void Function(List<int>) onData,
  void Function() onClose,
) => Future.error(
  UnsupportedError('Web Serial requires desktop Chrome or Edge.'),
);
Future<void> disconnect() async {}
Future<void> write(String text) async {}
