import 'dart:io';
import 'package:collection/collection.dart';
import 'package:lsp_server/lsp_server.dart';

void main() async {
  var connection = Connection(stdin, stdout);
  connection.onInitialize((params) async {
    print('收到了消息$params 1111');
    return InitializeResult(
      capabilities: ServerCapabilities(
        textDocumentSync: const Either2.t1(TextDocumentSyncKind.Full),
      ),
    );
  });

  connection.onDidOpenTextDocument((params) async {
    print('open');
    var diagnostics = _validateTextDocument(
      params.textDocument.text,
      params.textDocument.uri.toString(),
    );
    connection.sendDiagnostics(
      PublishDiagnosticsParams(
        diagnostics: diagnostics,
        uri: params.textDocument.uri,
      ),
    );
  });

  connection.onDidChangeTextDocument((params) async {
    var contentChanges = params.contentChanges
        .map((e) => TextDocumentContentChangeEvent2.fromJson(
            e.toJson() as Map<String, dynamic>))
        .toList();

    var diagnostics = _validateTextDocument(
      contentChanges.last.text,
      params.textDocument.uri.toString(),
    );
    connection.sendDiagnostics(
      PublishDiagnosticsParams(
        diagnostics: diagnostics,
        uri: params.textDocument.uri,
      ),
    );
  });

  await connection.listen();
  print('s');
}

List<Diagnostic> _validateTextDocument(String text, String sourcePath) {
  RegExp pattern = RegExp(r'\b[A-Z]{2,}\b');

  final lines = text.split('\n');

  final matches = lines.map((line) => pattern.allMatches(line));

  final diagnostics = matches
      .mapIndexed(
        (line, lineMatches) => _convertPatternToDiagnostic(lineMatches, line),
      )
      .reduce((aggregate, diagnostics) => [...aggregate, ...diagnostics])
      .toList();

  return diagnostics;
}

Iterable<Diagnostic> _convertPatternToDiagnostic(
    Iterable<RegExpMatch> matches, int line) {
  return matches.map(
    (match) => Diagnostic(
      message:
          '${match.input.substring(match.start, match.end)} is all uppercase.',
      range: Range(
        start: Position(character: match.start, line: line),
        end: Position(character: match.end, line: line),
      ),
    ),
  );
}
