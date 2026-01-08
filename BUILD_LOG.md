# Build Log
**Generated at:** 2026-01-09 01:22:50
**Command:** \lutter build web --release --no-tree-shake-icons\

## Execution Result
```text
Compiling lib\main.dart for the Web...                          
Wasm dry run succeeded. Consider building and testing your application with the `--wasm` flag. See docs for more info: https://docs.flutter.dev/platform-integration/web/wasm
Use --no-wasm-dry-run to disable these warnings.
Target dart2js failed: ProcessException: Process exited abnormally with exit code 1:
lib/pages/emergency_meeting_page.dart:31:41:
Error: The argument type 'List<Object>' can't be assigned to the parameter type 'Iterable<Future<dynamic>>'.
 - 'List' is from 'dart:core'.
 - 'Object' is from 'dart:core'.
 - 'Iterable' is from 'dart:core'.
 - 'Future' is from 'dart:async'.
      final results = await Future.wait([
                                        ^
Error: Compilation failed.
  Command: C:\app\flutter\bin\cache\dart-sdk\bin\dart.exe compile js --platform-binaries=C:\app\flutter\bin\cache\flutter_web_sdk\kernel --invoker=flutter_tool -Ddart.vm.product=true -DFLUTTER_VERSION=3.38.3 -DFLUTTER_CHANNEL=stable -DFLUTTER_GIT_URL=https://github.com/flutter/flutter.git -DFLUTTER_FRAMEWORK_REVISION=19074d12f7 -DFLUTTER_ENGINE_REVISION=13e658725d -DFLUTTER_DART_VERSION=3.10.1 -DFLUTTER_WEB_USE_SKIA=true -DFLUTTER_WEB_USE_SKWASM=false -DFLUTTER_WEB_CANVASKIT_URL=https://www.gstatic.com/flutter-canvaskit/13e658725ddaa270601426d1485636157e38c34c/ --native-null-assertions --no-source-maps -O4 --minify -o C:\Users\kanta\GitHub\my_web_app\.dart_tool\flutter_build\d87d8babb9a6652cd282d76a3a7bbacd\app.dill --packages=C:\Users\kanta\GitHub\my_web_app\.dart_tool\package_config.json --cfe-only C:\Users\kanta\GitHub\my_web_app\.dart_tool\flutter_build\d87d8babb9a6652cd282d76a3a7bbacd\main.dart
#0      RunResult.throwException (package:flutter_tools/src/base/process.dart:153:5)
#1      _DefaultProcessUtils.run (package:flutter_tools/src/base/process.dart:379:19)
<asynchronous suspension>
#2      Dart2JSTarget.build (package:flutter_tools/src/build_system/targets/web.dart:207:5)
<asynchronous suspension>
#3      _BuildInstance._invokeInternal (package:flutter_tools/src/build_system/build_system.dart:873:9)
<asynchronous suspension>
#4      Future.wait.<anonymous closure> (dart:async/future.dart:546:21)
<asynchronous suspension>
#5      _BuildInstance.invokeTarget (package:flutter_tools/src/build_system/build_system.dart:811:32)
<asynchronous suspension>
#6      Future.wait.<anonymous closure> (dart:async/future.dart:546:21)
<asynchronous suspension>
#7      _BuildInstance.invokeTarget (package:flutter_tools/src/build_system/build_system.dart:811:32)
<asynchronous suspension>
#8      FlutterBuildSystem.build (package:flutter_tools/src/build_system/build_system.dart:631:16)
<asynchronous suspension>
#9      WebBuilder.buildWeb (package:flutter_tools/src/web/compile.dart:94:34)
<asynchronous suspension>
#10     BuildWebCommand.runCommand (package:flutter_tools/src/commands/build_web.dart:296:5)
<asynchronous suspension>
#11     FlutterCommand.run.<anonymous closure> (package:flutter_tools/src/runner/flutter_command.dart:1559:27)
<asynchronous suspension>
#12     AppContext.run.<anonymous closure> (package:flutter_tools/src/base/context.dart:154:19)
<asynchronous suspension>
#13     CommandRunner.runCommand (package:args/command_runner.dart:212:13)
<asynchronous suspension>
#14     FlutterCommandRunner.runCommand.<anonymous closure> (package:flutter_tools/src/runner/flutter_command_runner.dart:487:9)
<asynchronous suspension>
#15     AppContext.run.<anonymous closure> (package:flutter_tools/src/base/context.dart:154:19)
<asynchronous suspension>
#16     FlutterCommandRunner.runCommand (package:flutter_tools/src/runner/flutter_command_runner.dart:422:5)
<asynchronous suspension>
#17     run.<anonymous closure>.<anonymous closure> (package:flutter_tools/runner.dart:104:11)
<asynchronous suspension>
#18     AppContext.run.<anonymous closure> (package:flutter_tools/src/base/context.dart:154:19)
<asynchronous suspension>
#19     main (package:flutter_tools/executable.dart:103:3)
<asynchronous suspension>

Compiling lib\main.dart for the Web...                             45.3s
Error: Failed to compile application for the Web.
```