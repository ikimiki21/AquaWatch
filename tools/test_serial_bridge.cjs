const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');

function setup() {
  const pending = [];
  const writes = [];
  let closed = false;
  let released = false;
  let opens = 0;
  const reader = {
    read: () => new Promise(resolve => pending.push(resolve)),
    cancel: async () => pending.shift()?.({ done: true }),
    releaseLock: () => { released = true; }
  };
  const port = {
    open: async options => { assert.equal(options.baudRate, 9600); opens++; },
    close: async () => { closed = true; },
    setSignals: async () => {},
    readable: { getReader: () => reader },
    writable: { getWriter: () => ({
      write: async bytes => writes.push(new TextDecoder().decode(bytes)),
      releaseLock: () => {}
    }) }
  };
  const sandbox = { window: {}, navigator: { serial: { requestPort: async () => port } }, TextEncoder };
  vm.runInNewContext(fs.readFileSync('web/serial_bridge.js', 'utf8'), sandbox);
  return { api: sandbox.window.aquaSerial, pending, writes,
    get closed() { return closed; }, get released() { return released; }, get opens() { return opens; } };
}

test('streams readings, writes settings, and releases the port on disconnect', async () => {
  const fixture = setup();
  const frames = [];
  let unexpectedClose = false;
  await fixture.api.connect(bytes => frames.push(new TextDecoder().decode(bytes)), () => { unexpectedClose = true; });
  fixture.pending.shift()({ value: new TextEncoder().encode('AQ,1,321\r\n'), done: false });
  await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(frames, ['AQ,1,321\r\n']);
  await fixture.api.write('CFG,400,1\n');
  assert.deepEqual(fixture.writes, ['CFG,400,1\n']);
  await fixture.api.disconnect();
  assert.equal(fixture.closed, true);
  assert.equal(fixture.released, true);
  assert.equal(unexpectedClose, false);
  assert.equal(fixture.opens, 1);
});

test('unplug closes the port and notifies the Flutter controller', async () => {
  const fixture = setup();
  let notified = false;
  await fixture.api.connect(() => {}, () => { notified = true; });
  fixture.pending.shift()({ done: true });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(notified, true);
  assert.equal(fixture.closed, true);
  assert.equal(fixture.released, true);
  await assert.rejects(() => fixture.api.write('CFG,400,1\n'), /Not connected/);
});
