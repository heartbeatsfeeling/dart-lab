
document.addEventListener('DOMContentLoaded', function () {
  let termDisabled = false
  // Monaco Editor Setup 
  let monacoEditor = null
  let editorContent = `void main() {\r  print('hello');\r}`;
  function run() {
    term.write('\x1b[2K\r');
    term.write('building...');
    termDisabled = true
    ws.send(JSON.stringify({
      type: 'run',
      data: editorContent
    }))
  }
  require.config({ paths: { 'vs': '/lib/monaco-editor/min/vs' } });
  require(['vs/editor/editor.main', 'vs/basic-languages/dart/dart'], function () {
    // remove loading
    const loadingEl = document.querySelector('#loading')
    const contenterEl = document.querySelector('#container')
    loadingEl.remove()
    contenterEl.classList.remove('hide')
    // 配置 Web Worker 路径
    window.MonacoEnvironment = {
      getWorkerUrl: function (workerId, label) {
        return `data:text/javascript;charset=utf-8,importScripts("${window.location.origin}/lib/monaco-editor/min/vs/base/worker/workerMain.js");`;
      }
    };
    monacoEditor = monaco.editor.create(document.getElementById('editor'), {
      value: editorContent,
      automaticLayout: true,
      language: 'dart',
      theme: 'vs-dark'
    });
    monacoEditor.onDidChangeModelContent((event) => {
      editorContent = monacoEditor.getValue()
    });
    monacoEditor.addAction({
      id: 'editor',
      label: 'Save',
      keybindings: [monaco.KeyMod.CtrlCmd | monaco.KeyCode.KeyS], // Ctrl+M or Cmd+M
      run: () => {
        run()
      }
    });
  });

  // Xterm.js Terminal Setup
  let command = ''
  const fitAddon = new FitAddon.FitAddon();
  const term = new Terminal({
    fontFamily: 'Consolas, courier-new, courier, monospace',
    fontSize: 12,
    rows: 14,
    cursorBlink: true,
    scrollback: 50000
  });
  term.loadAddon(fitAddon)
  term.open(document.getElementById('terminal'))
  fitAddon.fit()
  term.write('$ 欢迎来到 Dart lab, 输入\x1b[36m clear \x1b[0m回车后清空控制台，输入\x1b[32m run \x1b[0m 回车后执行文件\r\n');
  // If you need to send input from terminal to backend:
  term.onData(text => {
    if (termDisabled) {
      return
    }
    switch (text) {
      case '\u0003': // Ctrl+C
        term.write('^C');
        command = '';
        term.write('\r\n$ ');
        break;
      case '\r': // Enter
        const t = command.toLowerCase()
        command = '';
        if (t === 'run') {
          run()
        } else if (t === 'clear') {
          term.write('\x1b[2K\r');
          term.clear()
        } else {
          term.write('\x1b[2K\r');
          term.write(`${t}: command not found\r\n`)
        }
        break;
      case '\u007F': // Backspace (DEL)
        // Do not delete the prompt
        if (term._core.buffer.x >= 0) {
          term.write('\b \b');
          if (command.length > 0) {
            command = command.substr(0, command.length - 1);
          }
        }
        break;
      default: // Print all other characters for demo
        if (text >= String.fromCharCode(0x20) && text <= String.fromCharCode(0x7E) || text >= '\u00a0') {
          command += text;
          term.write(text);
        }
    }
  });
  const resizeObs = new ResizeObserver((e) => {
    fitAddon?.fit()
  })
  resizeObs.observe(document.body)

  const ws = new WebSocket(`ws://${location.hostname}:8085`);
  ws.onmessage = (event) => {
    const json = JSON.parse(event.data)
    if (json.type === 'run') {
      const data = json.data
      term.write('\x1b[2K\r');
      if (data.err) {
        term.write(`${data.err.replaceAll('\n', '\r\n')}\r`)
      } else {
        term.write(`${data.stdout.replaceAll('\n', '\r\n')}\r`)
      }
      termDisabled = false
    }
  };
  ws.onopen = () => {
    //
  };
  ws.onclose = () => {
    console.log('Connection closed');
  };
})
