import 'dart:js_interop';

import 'package:web/web.dart' as web;

void installProbeToolbar({
  required void Function() enable,
  required void Function() release,
  required void Function() audit,
}) {
  final toolbar = web.document.createElement('div') as web.HTMLDivElement;
  toolbar.id = 'probe-public-toolbar';
  toolbar.style.cssText =
      'position:fixed;left:0;top:0;width:100%;height:76px;z-index:2147483647;'
      'background:white;color:black;font:12px monospace;';
  for (final entry in <String, void Function()>{
    'Browser probe enable semantics': enable,
    'Browser probe release data': release,
    'Browser probe audit transport': audit,
  }.entries) {
    final button =
        web.document.createElement('button') as web.HTMLButtonElement;
    button.textContent = entry.key;
    button.addEventListener('click', ((web.Event event) => entry.value()).toJS);
    toolbar.appendChild(button);
  }
  final status = web.document.createElement('div') as web.HTMLDivElement;
  status.id = 'probe-public-status';
  status.setAttribute('role', 'status');
  status.textContent = 'probe-status:boot';
  toolbar.appendChild(status);
  web.document.body!.appendChild(toolbar);
}

void setProbeToolbarStatus(String status) {
  web.document.getElementById('probe-public-status')?.textContent = status;
}
