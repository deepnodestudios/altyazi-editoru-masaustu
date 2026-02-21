import 'dart:io';

void main(List<String> args) {
	if (args.isEmpty) {
		stderr.writeln('Usage: dart run tool/clean_srt_duplicate_indices.dart <input.srt> [--in-place] [--backup]');
		exitCode = 64;
		return;
	}

	final inputPath = args.first;
	final inPlace = args.contains('--in-place');
	final backup = args.contains('--backup');

	final inputFile = File(inputPath);
	if (!inputFile.existsSync()) {
		stderr.writeln('Input file not found: $inputPath');
		exitCode = 66;
		return;
	}

	final lines = inputFile.readAsLinesSync();
	final cleaned = <String>[];

	bool isIndexLine(String s) => RegExp(r'^\d+\s*$').hasMatch(s);
	bool isTimestampLine(String s) => s.contains('-->');

	int nextNonEmptyIndex(int start) {
		var i = start;
		while (i < lines.length && lines[i].trim().isEmpty) {
			i++;
		}
		return i;
	}

	int removed = 0;
	for (var i = 0; i < lines.length; i++) {
		final line = lines[i];
		final trimmed = line.trim();

		if (isIndexLine(trimmed)) {
			final j = nextNonEmptyIndex(i + 1);
			if (j < lines.length && isIndexLine(lines[j].trim())) {
				final a = trimmed;
				final b = lines[j].trim();

				// Pattern we want to fix:
				//   <subtitle text>
				//   70
				//
				//   70
				//   00:.. --> ..
				// Remove the first (stray) index line.
				if (a == b) {
					final k = nextNonEmptyIndex(j + 1);
					if (k < lines.length && isTimestampLine(lines[k])) {
						removed++;
						continue;
					}
				}
			}

			// If it looks like a normal index line (next non-empty is timestamp), keep it.
			// Otherwise keep it as-is; we don't want to aggressively mutate unknown formats.
		}

		cleaned.add(line);
	}

	final outputPath = inPlace
			? inputPath
			: (inputPath.toLowerCase().endsWith('.srt')
					? '${inputPath.substring(0, inputPath.length - 4)}.fixed.srt'
					: '$inputPath.fixed.srt');

	if (inPlace && backup) {
		final backupPath = '$inputPath.bak';
		File(backupPath).writeAsBytesSync(inputFile.readAsBytesSync());
	}

	// Preserve Windows-friendly line endings.
	File(outputPath).writeAsStringSync(cleaned.join('\r\n'));

	stdout.writeln('Done. Removed $removed stray duplicate index lines.');
	stdout.writeln('Output: $outputPath');
}

