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

  return cleaned.trim();
}
