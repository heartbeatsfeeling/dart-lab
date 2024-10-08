import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf_static/shelf_static.dart' as shelf_static;
import 'package:uuid/uuid.dart';

Future<void> main() async {
  final httpPort = 8084;
  final wsPort = 8085;
  final cascade = Cascade().add(_staticHandler);
  final server = await shelf_io.serve(
    logRequests().addHandler(cascade.handler),
    InternetAddress.anyIPv4, // Allows external connections
    httpPort,
  );
  print('Serving at http://${server.address.host}:${server.port}');
  _watch.start();

  var socketHandler = webSocketHandler((webSocket) async {
    var uuid = Uuid();
    var v1 = uuid.v1();

    // Listen to incoming WebSocket messages
    webSocket.stream.listen((message) {
      print('message${message}');
      var json = jsonDecode(message);
      if (json['type'] == 'run') {
        dartRun(body: jsonEncode(json['data']), uuid: v1)
            .then((response) async {
          String responseBody = await response.readAsString();
          var body = jsonDecode(responseBody);
          if (body['err'] != '') {
            body['err'] = (body['err'] as String).replaceAll('$v1-', '');
          }
          webSocket.sink.add(jsonEncode({'type': 'run', 'data': body}));
        });
      }
    });
  });
  shelf_io.serve(socketHandler, InternetAddress.anyIPv4, wsPort).then((server) {
    print('Serving at ws://${server.address.host}:${server.port}');
  });
}

final _staticHandler = shelf_static.createStaticHandler(
  'public',
  defaultDocument: 'index.html',
);

Future<Response> dartRun({required String body, required String uuid}) async {
  final data = jsonDecode(body);
  final tempFile = File('$uuid-temp.dart');
  await tempFile.writeAsString(data);
  final result = await Process.run(
    'dart',
    [tempFile.path],
  );
  await tempFile.delete();
  return Response.ok(
    jsonEncode({
      'err': result.stderr,
      'exitCode': result.exitCode,
      'stdout': result.stdout
    }),
    headers: {'Content-Type': 'application/json'},
  );
}

final _watch = Stopwatch();
