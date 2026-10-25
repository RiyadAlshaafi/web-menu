import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Sends [bytes] to the Windows printer named [printer] as a RAW print job, past the driver, so
/// an ESC/POS command reaches the printer as it is. False off Windows or when any step fails.
Future<bool> sendRaw(String printer, List<int> bytes) async {
  if (!Platform.isWindows) return false;
  return using((arena) {
    final handle = arena<IntPtr>();
    if (OpenPrinter(printer.toNativeUtf16(allocator: arena), handle, nullptr) == 0) return false;
    try {
      final doc = arena<DOC_INFO_1>()
        ..ref.pDocName = 'Cash drawer'.toNativeUtf16(allocator: arena)
        ..ref.pOutputFile = nullptr
        ..ref.pDatatype = 'RAW'.toNativeUtf16(allocator: arena);
      if (StartDocPrinter(handle.value, 1, doc) == 0) return false;
      try {
        if (StartPagePrinter(handle.value) == 0) return false;
        final buffer = arena<Uint8>(bytes.length)..asTypedList(bytes.length).setAll(0, bytes);
        final written = arena<Uint32>();
        final ok = WritePrinter(handle.value, buffer, bytes.length, written) != 0 && written.value == bytes.length;
        EndPagePrinter(handle.value);
        return ok;
      } finally {
        EndDocPrinter(handle.value);
      }
    } finally {
      ClosePrinter(handle.value);
    }
  });
}
