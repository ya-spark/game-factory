/// Minimal CSV reader (RFC 4180 style) for files exported from Excel or Google
/// Sheets: quoted cells, doubled quotes, commas and line breaks inside quotes,
/// CRLF or LF, and an optional byte-order mark.
library;

List<List<String>> parseCsv(String input) {
  final text = input.startsWith('﻿') ? input.substring(1) : input;
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;
  var any = false; // something seen on this row

  void endCell() {
    row.add(cell.toString());
    cell.clear();
  }

  void endRow() {
    endCell();
    rows.add(row);
    row = <String>[];
    any = false;
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cell.write(c);
      }
      continue;
    }
    switch (c) {
      case '"':
        inQuotes = true;
        any = true;
      case ',':
        endCell();
        any = true;
      case '\r':
        if (i + 1 < text.length && text[i + 1] == '\n') i++;
        endRow();
      case '\n':
        endRow();
      default:
        cell.write(c);
        any = true;
    }
  }
  if (inQuotes) throw const FormatException('CSV ends inside a quoted cell');
  if (any || cell.isNotEmpty) endRow();
  return rows;
}
