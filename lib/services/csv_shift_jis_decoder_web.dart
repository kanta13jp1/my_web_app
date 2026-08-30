import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

String decodeShiftJis(Uint8List bytes) =>
    web.TextDecoder('shift_jis').decode(bytes.toJS);
