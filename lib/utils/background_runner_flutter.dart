import 'package:flutter/foundation.dart';

Future<R> runInBackground<Q, R>(R Function(Q) fn, Q message) {
  return compute(fn, message);
}
