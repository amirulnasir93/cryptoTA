import 'package:flutter/material.dart';

/// A free-text field with filtered suggestions -- mirrors the web app's
/// SearchableSelect.tsx: still allows typing a custom value that doesn't
/// match any option (Chain/Cluster need that -- the watchlist has values no
/// static list would predict), while surfacing suggestions to reduce
/// typos/inconsistent free text. Built on Flutter's own Autocomplete rather
/// than a hand-rolled overlay, since it already handles positioning/keyboard
/// navigation correctly.
class SearchableField extends StatelessWidget {
  final String label;
  final String initialValue;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const SearchableField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: initialValue),
      optionsBuilder: (TextEditingValue value) {
        if (value.text.isEmpty) return options;
        final q = value.text.toLowerCase();
        return options.where((o) => o.toLowerCase().contains(q));
      },
      onSelected: onChanged,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(labelText: label),
          onChanged: onChanged,
        );
      },
      optionsViewBuilder: (context, onSelected, viewOptions) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 320),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: viewOptions.length,
                itemBuilder: (context, index) {
                  final option = viewOptions.elementAt(index);
                  return ListTile(dense: true, title: Text(option), onTap: () => onSelected(option));
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
