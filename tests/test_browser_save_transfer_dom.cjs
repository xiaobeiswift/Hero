'use strict';
const fs = require('node:fs');
const vm = require('node:vm');
const crypto = require('node:crypto');
const path = require('node:path');
const sourceRoot = process.argv[2] || path.resolve(__dirname, '..');
const htmlPath = path.join(sourceRoot, 'web/hero_shell.html');
const raw = fs.readFileSync(htmlPath, 'utf8');
const match = raw.match(/\/\/ HERO_SAVE_TRANSFER_BEGIN[^\n]*\n([\s\S]*?)\/\/ HERO_SAVE_TRANSFER_END/);
if (!match) throw new Error('Exact marked production adapter source unavailable');
const code = match[1];
const digest = b => crypto.createHash('sha256').update(b).digest('hex');
let checks = 0; const failures = []; const events = [];
function check(cond, name) { checks++; if (!cond) failures.push(name); console.log(`${cond ? 'PASS' : 'FAIL'} ${name}`); }
function env(options = {}) {
  const inputs = [], readers = [], calls = []; let clickStack = false;
  class MockFile { constructor(bytes, size = bytes.length) { this.bytes = Uint8Array.from(bytes); this.size = size; } }
  class Reader {
    constructor() { this.readyState = 0; readers.push(this); this.result = null; }
    readAsArrayBuffer(file) { calls.push(['read', file.size]); if (options.readThrows) throw Error('synthetic read failure'); this.file = file; this.readyState = 1; if (options.syncComplete) this.complete(file.bytes); }
    complete(bytes = this.file.bytes) { this.result = Uint8Array.from(bytes).buffer; this.readyState = 2; const f = this.onload; if (f) f(); }
    abort() { calls.push(['abort']); this.readyState = 2; const f = this.onabort; if (f) f(); }
  }
  const document = {body: {appendChild(input) { input.attached = true; }}, createElement(tag) {
    if (tag !== 'input') throw Error('Unexpected element');
    const input = { style: {}, files: [], attached: false, removed: false,
      click() { calls.push(['click', clickStack]); if (options.clickThrows) throw Error('synthetic picker exception'); },
      remove() { this.removed = true; this.attached = false; },
      select(files) { this.files = files; if (this.onchange) this.onchange(); },
      cancel() { if (this.oncancel) this.oncancel(); }
    }; inputs.push(input); return input;
  }};
  const context = vm.createContext({window: {}, document, File: MockFile, FileReader: Reader, ArrayBuffer, Uint8Array, Number, Object});
  vm.runInContext(code, context, {filename: htmlPath + ':HERO_SAVE_TRANSFER'});
  const api = context.window.HeroSaveTransfer;
  const replies = [];
  const choose = (token = 1, cb = (...args) => replies.push(args)) => {clickStack = true; const result = api.chooseFile(token, cb); clickStack = false; return result;};
  return {inputs, readers, calls, api, replies, choose, File: MockFile};
}
function one(name, run) { try {run();} catch(e) {check(false, name + ': ' + e.stack);} }
const LIMIT = 1048576;
one('happy path', () => { const e=env(); check(e.choose(), 'valid request accepted'); const i=e.inputs[0]; check(i.type==='file' && i.accept==='.json,application/json' && i.multiple===false, 'single JSON picker configured'); check(e.calls[0][0]==='click' && e.calls[0][1]===true, 'picker click synchronous within caller stack (mock only)'); const bytes=Buffer.from('{"name":"沈青·渡灯录","note":"本地测试，非玩家存档","hp":37}\n', 'utf8'); i.select([new e.File(bytes)]); const r=e.readers[0]; check(r.readyState===1 && e.replies.length===0, 'selection waits for FileReader completion'); r.complete(); check(e.replies.length===1 && e.replies[0][0]===1 && e.replies[0][1]==='selected', 'one selected callback with operation token'); check(Buffer.from(e.replies[0][2]).equals(bytes), 'UTF-8 Chinese bytes retained exactly, no text reinterpretation'); check(i.removed && i.onchange===null && i.oncancel===null && r.onload===null && r.onerror===null && r.onabort===null, 'terminal completion clears input and handlers'); });
one('cancel',()=>{const e=env();e.choose();e.inputs[0].cancel();check(e.replies.length===1&&e.replies[0][1]==='cancelled','picker cancel is terminal cancellation');check(e.readers.length===0&&e.inputs[0].removed,'cancel performs no read and removes picker');});
one('no selection',()=>{const e=env();e.choose();e.inputs[0].select([]);check(e.replies[0][1]==='cancelled'&&e.readers.length===0,'zero selected files cancelled before FileReader');});
for (const [name, make, expected] of [
 ['missing FileList',e=>null,'invalid'], ['multiple files',e=>[new e.File([1]),new e.File([2])],'invalid'], ['not File',e=>[{size:1}],'invalid'], ['empty File',e=>[new e.File([])],'invalid'], ['oversize File',e=>[new e.File([1],LIMIT+1)],'oversize']
]) one(name,()=>{const e=env();e.choose();e.inputs[0].select(make(e));check(e.replies[0][1]===expected,name+' rejected with '+expected);check(e.readers.length===0,name+' rejected before FileReader construction/read');});
one('max size',()=>{const e=env();e.choose();const b=new Uint8Array(LIMIT);b[0]=0xe6;b[LIMIT-1]=0xaa;e.inputs[0].select([new e.File(b)]);e.readers[0].complete();check(e.replies[0][1]==='selected'&&e.replies[0][2].byteLength===LIMIT,'exactly one MiB accepted at transport boundary');});
for (const [name,result] of [['null',null],['string','bad'],['Uint8Array',new Uint8Array([1])],['empty ArrayBuffer',new ArrayBuffer(0)],['size mismatch',new ArrayBuffer(2)],['oversize returned',new ArrayBuffer(LIMIT+1)]]) one(name,()=>{const e=env();e.choose();e.inputs[0].select([new e.File([1])]);const r=e.readers[0];r.result=result;r.readyState=2;r.onload();check(e.replies.length===1&&e.replies[0][1]==='invalid'&&e.replies[0].length===2,'returned '+name+' rejected after read without forwarding bytes');});
one('reader errors',()=>{for(const [event,status] of [['onerror','read_error'],['onabort','cancelled']]) {const e=env();e.choose();e.inputs[0].select([new e.File([1])]);e.readers[0][event]();check(e.replies.length===1&&e.replies[0][1]===status,'FileReader '+event+' one terminal '+status);check(e.inputs[0].removed&&e.readers[0].onload===null,'FileReader '+event+' clears callbacks');}});
one('read exception',()=>{const e=env({readThrows:true});e.choose();e.inputs[0].select([new e.File([1])]);check(e.replies.length===1&&e.replies[0][1]==='read_error','synchronous FileReader exception handled');});
one('picker exception',()=>{const e=env({clickThrows:true});check(e.choose()===false,'picker click exception returns false');check(e.inputs[0].removed&&e.inputs[0].onchange===null&&e.replies.length===0,'picker click exception cleans up without fabricated selection');});
one('synchronous reader',()=>{const e=env({syncComplete:true});e.choose();e.inputs[0].select([new e.File([1,2,3])]);check(e.replies.length===1&&e.replies[0][1]==='selected','synchronous completion remains safe');});
one('one in flight and stale handlers',()=>{const e=env();e.choose(10);const old=e.inputs[0];old.select([new e.File([1])]);const r=e.readers[0], staleLoad=r.onload, staleChange=old.onchange, staleCancel=old.oncancel, staleError=r.onerror, staleAbort=r.onabort;e.choose(11);check(old.removed&&r.onload===null&&e.calls.filter(x=>x[0]==='abort').length===1,'replacement cancels and detaches pending FileReader');r.result=new Uint8Array([1]).buffer;staleLoad();staleChange();staleCancel();staleError();staleAbort();check(e.replies.length===0,'all stale callbacks after replacement ignored');e.inputs[1].select([new e.File([2])]);e.readers[1].complete();check(e.replies.length===1&&e.replies[0][0]===11&&new Uint8Array(e.replies[0][2])[0]===2,'replacement alone returns new exact bytes');});
one('duplicate events',()=>{const e=env();e.choose();const i=e.inputs[0];const change=i.onchange;i.select([new e.File([1])]);change();check(e.readers.length===1,'duplicate change creates one FileReader');const r=e.readers[0],oldLoad=r.onload,oldCancel=i.oncancel;r.complete();oldLoad();oldCancel();check(e.replies.length===1,'duplicate terminal callbacks cannot finish twice');});
one('explicit cancel',()=>{const e=env();e.choose();e.inputs[0].select([new e.File([1])]);const old=e.readers[0].onload;e.api.cancel();e.api.cancel();e.readers[0].result=new Uint8Array([1]).buffer;old();check(e.replies.length===0&&e.inputs[0].removed,'explicit cancellation is idempotent and suppresses stale callback');});
one('same file reselect',()=>{const e=env(),f=new e.File([1,2]);for(const token of [1,2]) {e.choose(token);e.inputs.at(-1).select([f]);e.readers.at(-1).complete();}check(e.inputs.length===2&&e.inputs[0]!==e.inputs[1]&&e.replies.length===2,'same file can be reselected through fresh input');});
one('callback reentrancy',()=>{const e=env();e.choose(7,()=>e.choose(8));e.inputs[0].cancel();check(e.inputs.length===2&&!e.inputs[1].removed,'terminal cleanup precedes callback reentrancy');e.inputs[1].cancel();check(e.replies.length===1&&e.replies[0][0]===8,'reentrant choice remains active');});
one('malformed parameters',()=>{const e=env();for(const token of [null,NaN,Infinity,1.5,Number.MAX_SAFE_INTEGER+1,'1']) check(e.choose(token)===false,'invalid token rejected: '+String(token));check(e.choose(1, {})===false,'nonfunction callback rejected');check(e.inputs.length===0,'invalid requests create no input');});
one('closed data boundary',()=>{check(!/\b(fetch|XMLHttpRequest|sendBeacon|localStorage|indexedDB)\b/.test(code),'exact picker adapter includes no network or storage calls');});
const result={kind:'exact-source Node VM / mocked DOM+FileReader transport tests; not browser integration',timestamp:new Date().toISOString(),checks,failures,source:{path:htmlPath,sha256:digest(fs.readFileSync(htmlPath)),adapter_sha256:digest(code)},notVerified:['Actual browser file picker','Actual FileReader implementation','Godot JavaScriptBridge ArrayBuffer conversion','Browser download completion','User activation in a real browser','Fresh browser profile','Godot WebGL2 runtime','Cross-reload game persistence']};
if (process.env.HERO_BROWSER_QA_RESULT) fs.writeFileSync(process.env.HERO_BROWSER_QA_RESULT,JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify(result,null,2));process.exitCode=failures.length?1:0;
