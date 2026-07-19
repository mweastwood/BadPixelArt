String cleanJsonString(String input) {
  var cleaned = input.trim();

  // First, strip markdown code block wrappers if present at start/end
  if (cleaned.startsWith('```')) {
    final lines = cleaned.split('\n');
    if (lines.first.startsWith('```')) {
      lines.removeAt(0);
    }
    if (lines.isNotEmpty && lines.last.startsWith('```')) {
      lines.removeLast();
    }
    cleaned = lines.join('\n').trim();
  }

  // Next, if there is still surrounding conversational text, locate the first JSON object or array block
  final firstCurly = cleaned.indexOf('{');
  final firstBracket = cleaned.indexOf('[');
  int startIdx = -1;
  int endIdx = -1;

  if (firstCurly != -1 && (firstBracket == -1 || firstCurly < firstBracket)) {
    startIdx = firstCurly;
    endIdx = cleaned.lastIndexOf('}');
  } else if (firstBracket != -1) {
    startIdx = firstBracket;
    endIdx = cleaned.lastIndexOf(']');
  }

  if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
    cleaned = cleaned.substring(startIdx, endIdx + 1);
  }

  // Finally, run the stack-based repair logic in case the JSON was truncated mid-generation
  return repairTruncatedJson(cleaned);
}

String repairTruncatedJson(String jsonStr) {
  final lastCurlyClose = jsonStr.lastIndexOf('}');
  final lastBracketClose = jsonStr.lastIndexOf(']');
  final cutIdx = lastCurlyClose > lastBracketClose
      ? lastCurlyClose
      : lastBracketClose;

  if (cutIdx == -1) return jsonStr;

  final sub = jsonStr.substring(0, cutIdx + 1);

  final List<String> stack = [];
  bool inString = false;

  for (int i = 0; i < sub.length; i++) {
    final char = sub[i];

    if (char == '"') {
      if (i > 0 && sub[i - 1] == '\\') {
        // Escaped quote
      } else {
        inString = !inString;
      }
      continue;
    }

    if (inString) continue;

    if (char == '{') {
      stack.add('}');
    } else if (char == '[') {
      stack.add(']');
    } else if (char == '}' || char == ']') {
      if (stack.isNotEmpty && stack.last == char) {
        stack.removeLast();
      }
    }
  }

  final buffer = StringBuffer(sub);
  for (final closeChar in stack.reversed) {
    buffer.write(closeChar);
  }

  return buffer.toString().trim();
}
