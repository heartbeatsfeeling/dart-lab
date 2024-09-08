import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf_static/shelf_static.dart' as shelf_static;

late Process languageServerProcess;
Future<void> main() async {
  final httpPort = 8084;
  final wsPort = 8085;
  final cascade = Cascade().add(_staticHandler).add(_router.call);
  final server = await shelf_io.serve(
    logRequests().addHandler(cascade.handler),
    InternetAddress.anyIPv4, // Allows external connections
    httpPort,
  );
  print('Serving at http://${server.address.host}:${server.port}');
  _watch.start();

  var socketHandler = webSocketHandler((webSocket) async {
    webSocket.stream.listen((message) {
      print('收到了消息');
      languageServerProcess.stdin.writeln(message);
    });
    languageServerProcess.stdout.transform(utf8.decoder).listen((data) {
      print('发送');
      webSocket.add(data);
    });
    languageServerProcess.stderr.transform(utf8.decoder).listen((data) {
      print('error');
    });
  });
  shelf_io.serve(socketHandler, InternetAddress.anyIPv4, wsPort).then((server) {
    print('Serving at ws://${server.address.host}:${server.port}');
  });
  languageServerProcess = await startLanguageServer();
}

final _staticHandler = shelf_static.createStaticHandler('renderer/dist',
    defaultDocument: 'index.html');
final _router = shelf_router.Router()
  ..get('/helloworld', _pingTest)
  ..post('/run', exec);

Response _pingTest(Request request) => Response.ok('Hello, World!');

Future<Response> exec(Request request) async {
  final payload = await request.readAsString();
  final data = jsonDecode(payload);
  final tempFile = File('temp.dart');
  await tempFile.writeAsString(data);
  final result = await Process.run(
    'dart',
    [tempFile.path],
  );
  // await tempFile.delete();
  return Response.ok(
    jsonEncode({
      'err': result.stderr,
      'exitCode': result.exitCode,
      'stdout': result.stdout
    }),
    headers: {'Content-Type': 'application/json'},
  );
}

Future<Process> startLanguageServer() async {
  var process = await Process.start('dart', ['lib/language-server.dart'],
      workingDirectory: Directory.current.path);
  return process;
}

final _watch = Stopwatch();
