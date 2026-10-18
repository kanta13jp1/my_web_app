import 'package:web/web.dart' as web;

/// Read at each move so a browser preference change applies to the next door.
bool get prefersReducedMotion =>
    web.window.matchMedia('(prefers-reduced-motion: reduce)').matches;
