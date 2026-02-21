import 'dart:isolate';

Future<R> runInBackground<Q, R>(R Function(Q) fn, Q message) {
  return Isolate.run(() => fn(message));
}
