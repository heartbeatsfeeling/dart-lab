import './index.css'
import * as monaco from 'monaco-editor'
import { MonacoLanguageClient } from 'monaco-languageclient'
import { WebSocketMessageReader, WebSocketMessageWriter, toSocket } from 'vscode-ws-jsonrpc'
import { initServices } from 'monaco-languageclient/vscode/services'

const initWebSocketAndStartClient = (url: string): WebSocket => {
  const webSocket = new WebSocket(url);
  webSocket.onopen = () => {
    const socket = toSocket(webSocket);
    const reader = new WebSocketMessageReader(socket);
    const writer = new WebSocketMessageWriter(socket);
    reader.listen(() => {
      console.log('Received message from server:');
    });
    const languageClient = createLanguageClient({
        reader,
        writer
    });
    languageClient.start()
    reader.onClose(() => {
      console.log('close')
      languageClient.stop()
    });
  };
  webSocket.onmessage = (msg) => {
    console.log(msg)
  }
  webSocket.onerror = (error) => {
    console.error('WebSocket error:', error);
  };
  return webSocket;
};

const createLanguageClient = (transports: any): MonacoLanguageClient => {
  return new MonacoLanguageClient({
      name: 'Sample Language Client',
      clientOptions: {
        documentSelector: ['dart'],
        errorHandler: {
          error: () => ({ action: 1 }),
          closed: () => ({ action: 1 })
        }
      },
      connectionProvider: {
          get: () => {
              return Promise.resolve(transports);
          }
      }
  });
};

async function initEditor () {
  await initServices({})
  const editor = monaco.editor.create(document.getElementById('editor')!, {
    value: `
void main() {
  int a = 1;
  int b = 2;
  print('a: $a, b:$b');
}`,
    language: 'dart',
    theme: 'vs-dark',
    automaticLayout: true,
    wordBasedSuggestions: 'off'
  })
  editor.onDidChangeModelContent(() => {
    // console.log('Editor content changed');
  });
  initWebSocketAndStartClient('ws://0.0.0.0:8085')
}
initEditor()