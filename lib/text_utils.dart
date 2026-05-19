String decodeHtmlEntities(dynamic value) {
  var text = value?.toString() ?? '';
  const named = {
    '&quot;': '"',
    '&ldquo;': '"',
    '&rdquo;': '"',
    '&ldqou;': '"',
    '&rdqou;': '"',
    '&lsquo;': "'",
    '&rsquo;': "'",
    '&#39;': "'",
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&nbsp;': ' ',
  };
  named.forEach((from, to) {
    text = text.replaceAll(from, to);
  });
  text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
    final code = int.tryParse(match.group(1) ?? '');
    if (code == null) return match.group(0) ?? '';
    return String.fromCharCode(code);
  });
  return text;
}
