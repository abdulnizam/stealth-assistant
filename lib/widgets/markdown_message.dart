import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class MarkdownMessage extends StatelessWidget {
  const MarkdownMessage({
    super.key,
    required this.text,
    required this.isUser,
  });

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg =
        isUser ? theme.colorScheme.primary.withOpacity(0.3) : Colors.white;
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
      bottomRight:
          isUser ? const Radius.circular(4) : const Radius.circular(16),
    );

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: borderRadius,
          border: Border.all(
            color: isUser
                ? theme.colorScheme.primary.withOpacity(0.3)
                : theme.dividerColor,
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 16, isUser ? 16 : 48, 16),
              child: _SelectableMarkdown(text: text, isUser: isUser),
            ),
            if (!isUser)
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Helper widget to render selectable markdown as SelectableText.rich
// (basic markdown: bold, italic, code, links)
class _SelectableMarkdown extends StatelessWidget {
  final String text;
  final bool isUser;
  const _SelectableMarkdown({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    // Split text into blocks: code blocks (```...```) and normal markdown
    final blocks = _splitMarkdownBlocks(text);
    List<Widget> widgets = [];
    for (final block in blocks) {
      if (block['type'] == 'code') {
        final code = block['text'] as String;
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[400]!, width: 1),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 40, 12),
                  child: SelectableText(
                    code,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 15,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Copy code',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied')),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        // Normal markdown (inline code, bold, italic, links)
        widgets.add(
          SelectableText.rich(
            TextSpan(
              children: _parseMarkdown(block['text'] as String, context),
            ),
            style: TextStyle(
              color: isUser
                  ? Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.blueGrey
                  : Colors.black,
              fontSize: 16,
            ),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }
}

// Splits markdown into blocks: {type: 'code'|'text', text: ...}
List<Map<String, Object>> _splitMarkdownBlocks(String text) {
  final List<Map<String, Object>> blocks = [];
  final codeBlock = RegExp(r'```([\s\S]*?)```');
  int last = 0;
  final matches = codeBlock.allMatches(text);
  for (final m in matches) {
    if (m.start > last) {
      blocks.add({'type': 'text', 'text': text.substring(last, m.start)});
    }
    final code = m.group(1) ?? '';
    blocks.add({'type': 'code', 'text': code.trimRight()});
    last = m.end;
  }
  if (last < text.length) {
    blocks.add({'type': 'text', 'text': text.substring(last)});
  }
  return blocks;
}

List<InlineSpan> _parseMarkdown(String text, BuildContext context) {
  final List<InlineSpan> spans = [];
  final RegExp exp =
      RegExp(r'(\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`|\[[^\]]+\]\([^\)]+\))');
  int last = 0;
  final matches = exp.allMatches(text);
  for (final m in matches) {
    if (m.start > last) {
      spans.add(TextSpan(text: text.substring(last, m.start)));
    }
    final match = text.substring(m.start, m.end);
    if (match.startsWith('**') && match.endsWith('**')) {
      spans.add(TextSpan(
          text: match.substring(2, match.length - 2),
          style: const TextStyle(fontWeight: FontWeight.bold)));
    } else if (match.startsWith('*') && match.endsWith('*')) {
      spans.add(TextSpan(
          text: match.substring(1, match.length - 1),
          style: const TextStyle(fontStyle: FontStyle.italic)));
    } else if (match.startsWith('`') && match.endsWith('`')) {
      spans.add(TextSpan(
          text: match.substring(1, match.length - 1),
          style: const TextStyle(
              fontFamily: 'monospace', color: Colors.deepPurple)));
    } else if (match.startsWith('[') &&
        match.contains('](') &&
        match.endsWith(')')) {
      final labelEnd = match.indexOf('](');
      final label = match.substring(1, labelEnd);
      final url = match.substring(labelEnd + 2, match.length - 1);
      spans.add(
        WidgetSpan(
          child: GestureDetector(
            onTap: () async {
              final uri = Uri.tryParse(url);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      );
    } else {
      spans.add(TextSpan(text: match));
    }
    last = m.end;
  }
  if (last < text.length) {
    spans.add(TextSpan(text: text.substring(last)));
  }
  return spans;
}
