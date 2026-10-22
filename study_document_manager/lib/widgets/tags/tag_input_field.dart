import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TagInputField extends StatefulWidget {
  const TagInputField({
    super.key,
    required this.initialTags,
    required this.onChanged,
    this.suggestions = const <String>[
      '#GiaoTrinh',
      '#DeThi',
      '#Slide',
      '#ThucHanh',
      '#Flutter',
      '#Firebase',
      '#AI',
      '#Mobile',
    ],
    this.maxTags = 10,
  });

  final List<String> initialTags;
  final ValueChanged<List<String>> onChanged;
  final List<String> suggestions;
  final int maxTags;

  @override
  State<TagInputField> createState() => _TagInputFieldState();
}

class _TagInputFieldState extends State<TagInputField> {
  final TextEditingController _controller = TextEditingController();

  final FocusNode _focusNode = FocusNode();

  late List<String> _tags;

  @override
  void initState() {
    super.initState();

    _tags = <String>[];

    for (final String initialTag in widget.initialTags) {
      final String normalizedTag = _normalizeTag(initialTag);

      if (normalizedTag.isEmpty || _containsTag(normalizedTag)) {
        continue;
      }

      _tags.add(normalizedTag);
    }
  }

  @override
  void didUpdateWidget(covariant TagInputField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialTags == widget.initialTags) {
      return;
    }

    final List<String> updatedTags = <String>[];

    for (final String initialTag in widget.initialTags) {
      final String normalizedTag = _normalizeTag(initialTag);

      if (normalizedTag.isEmpty) {
        continue;
      }

      final bool duplicated = updatedTags.any(
        (String tag) => tag.toLowerCase() == normalizedTag.toLowerCase(),
      );

      if (!duplicated) {
        updatedTags.add(normalizedTag);
      }
    }

    _tags = updatedTags;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _normalizeTag(String value) {
    final String trimmed = value.trim();

    if (trimmed.isEmpty) {
      return '';
    }

    final String withoutHash = trimmed.startsWith('#')
        ? trimmed.substring(1)
        : trimmed;

    final String normalized = withoutHash.replaceAll(RegExp(r'\s+'), '').trim();

    if (normalized.isEmpty) {
      return '';
    }

    return '#$normalized';
  }

  bool _containsTag(String value) {
    final String normalizedValue = _normalizeTag(value).toLowerCase();

    return _tags.any((String tag) => tag.toLowerCase() == normalizedValue);
  }

  void _notifyParent() {
    widget.onChanged(List<String>.unmodifiable(_tags));
  }

  void _addTags(String rawValue) {
    final String input = rawValue.trim();

    if (input.isEmpty) {
      return;
    }

    final List<String> inputTags = input.split(',');

    bool hasChanged = false;
    bool reachedLimit = false;

    for (final String inputTag in inputTags) {
      final String normalizedTag = _normalizeTag(inputTag);

      if (normalizedTag.isEmpty || _containsTag(normalizedTag)) {
        continue;
      }

      if (_tags.length >= widget.maxTags) {
        reachedLimit = true;
        break;
      }

      _tags.add(normalizedTag);
      hasChanged = true;
    }

    _controller.clear();

    if (hasChanged) {
      setState(() {});
      _notifyParent();
    }

    if (reachedLimit && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Chỉ được nhập tối đa '
              '${widget.maxTags} Tag.',
            ),
          ),
        );
    }

    _focusNode.requestFocus();
  }

  void _removeTag(String tag) {
    final bool removed = _tags.remove(tag);

    if (!removed) {
      return;
    }

    setState(() {});
    _notifyParent();
  }

  void _toggleSuggestion(String suggestion, bool selected) {
    if (selected) {
      _addTags(suggestion);
      return;
    }

    final String normalizedSuggestion = _normalizeTag(suggestion).toLowerCase();

    String? tagToRemove;

    for (final String tag in _tags) {
      if (tag.toLowerCase() == normalizedSuggestion) {
        tagToRemove = tag;
        break;
      }
    }

    if (tagToRemove != null) {
      _removeTag(tagToRemove);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Thẻ phân loại',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        TextField(
          controller: _controller,
          focusNode: _focusNode,
          textInputAction: TextInputAction.done,
          inputFormatters: <TextInputFormatter>[
            LengthLimitingTextInputFormatter(100),
          ],
          decoration: InputDecoration(
            hintText: 'Nhập Tag rồi nhấn Enter hoặc dấu phẩy',
            prefixIcon: const Icon(Icons.tag_rounded),
            suffixIcon: IconButton(
              tooltip: 'Thêm Tag',
              onPressed: () {
                _addTags(_controller.text);
              },
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
            border: const OutlineInputBorder(),
          ),
          onSubmitted: _addTags,
          onChanged: (String value) {
            if (value.endsWith(',')) {
              _addTags(value);
            }
          },
        ),

        if (_tags.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((String tag) {
              return InputChip(
                label: Text(tag),
                avatar: const Icon(Icons.tag_rounded, size: 18),
                deleteIcon: const Icon(Icons.close_rounded, size: 18),
                onDeleted: () {
                  _removeTag(tag);
                },
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: 14),

        Text('Gợi ý phổ biến', style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: widget.suggestions.map((String suggestion) {
              final bool selected = _containsTag(suggestion);

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(suggestion),
                  avatar: const Icon(Icons.tag_rounded, size: 17),
                  selected: selected,
                  onSelected: (bool value) {
                    _toggleSuggestion(suggestion, value);
                  },
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 6),

        Text(
          '${_tags.length}/${widget.maxTags} Tag',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
