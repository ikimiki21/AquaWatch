// Web Serial works on localhost in desktop Chrome/Edge. Android uses usb_serial.
// requestPort must run directly from the user's Connect button click.
window.aquaSerial = (() => {
  let session = null;
  async function disconnect() {
    const old = session;
    session = null;
    if (!old) return;
    old.stopping = true;
    try { await old.reader?.cancel(); } catch (_) {}
    try { await old.finished; } catch (_) {}
    try { await old.port.close(); } catch (_) {}
  }
  return {
    async connect(onData, onClose) {
      if (!navigator.serial) throw new Error('Web Serial requires desktop Chrome or Edge.');
      if (session) throw new Error('Already connected');
      const port = await navigator.serial.requestPort();
      await port.open({ baudRate: 9600, dataBits: 8, stopBits: 1, parity: 'none', flowControl: 'none' });
      try { await port.setSignals({ dataTerminalReady: true, requestToSend: true }); }
      catch (_) { /* Some serial adapters do not expose control signals. */ }
      const current = { port, reader: null, finished: null, stopping: false };
      session = current;
      current.finished = (async () => {
        try {
          current.reader = port.readable.getReader();
          while (!current.stopping) {
            const { value, done } = await current.reader.read();
            if (done) break;
            if (value) onData(value);
          }
        } catch (_) { /* Device unplug or read failure. */ }
        finally {
          current.reader?.releaseLock();
          if (!current.stopping) {
            session = null;
            try { await port.close(); } catch (_) {}
            onClose();
          }
        }
      })();
    },
    disconnect,
    async write(text) {
      const current = session;
      if (!current?.port.writable) throw new Error('Not connected');
      const writer = current.port.writable.getWriter();
      try { await writer.write(new TextEncoder().encode(text)); }
      finally { writer.releaseLock(); }
    }
  };
})();
