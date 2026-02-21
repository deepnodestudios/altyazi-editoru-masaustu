/// Windows single-instance enforcement via a named kernel mutex.
///
/// Call [ensureSingleInstance] early in `main()`. If another instance already
/// holds the mutex the function returns `false` and the caller should exit.
library;

import 'dart:ffi';
import 'package:ffi/ffi.dart';

// --- Win32 bindings (minimal) ---

typedef _CreateMutexWNative = IntPtr Function(
    Pointer<Void> lpMutexAttributes, Int32 bInitialOwner, Pointer<Utf16> lpName);
typedef _CreateMutexWDart = int Function(
    Pointer<Void> lpMutexAttributes, int bInitialOwner, Pointer<Utf16> lpName);

typedef _GetLastErrorNative = Uint32 Function();
typedef _GetLastErrorDart = int Function();

typedef _CloseHandleNative = Int32 Function(IntPtr hObject);
typedef _CloseHandleDart = int Function(int hObject);

const int _errorAlreadyExists = 183; // ERROR_ALREADY_EXISTS

final DynamicLibrary _kernel32 = DynamicLibrary.open('kernel32.dll');

final _CreateMutexWDart _createMutexW = _kernel32
    .lookupFunction<_CreateMutexWNative, _CreateMutexWDart>('CreateMutexW');

final _GetLastErrorDart _getLastError = _kernel32
    .lookupFunction<_GetLastErrorNative, _GetLastErrorDart>('GetLastError');

// We intentionally never close the mutex handle so it stays alive for the
// entire process lifetime. If we ever need to release it:
// ignore: unused_element
final _CloseHandleDart _closeHandle = _kernel32
    .lookupFunction<_CloseHandleNative, _CloseHandleDart>('CloseHandle');

// ---

/// Tries to acquire a process-wide named mutex.
///
/// Returns `true` if this is the first (and only) instance.
/// Returns `false` if another instance already holds the mutex.
bool ensureSingleInstance() {
  const mutexName = 'Global\\DeepNodeAltyaziEditoru_SingleInstance';
  final lpName = mutexName.toNativeUtf16();
  try {
    final handle = _createMutexW(nullptr, 1, lpName);
    if (handle == 0) {
      // CreateMutexW failed entirely — let the app run anyway.
      return true;
    }
    final lastError = _getLastError();
    if (lastError == _errorAlreadyExists) {
      // Another instance owns this mutex.
      return false;
    }
    // We are the first instance. Keep the handle open (process lifetime).
    return true;
  } finally {
    calloc.free(lpName);
  }
}
