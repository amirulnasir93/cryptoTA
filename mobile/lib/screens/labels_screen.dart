import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repository.dart';
import '../models.dart';
import '../widgets/common.dart';

/// There's no separate Labels table now that the Sheet is the database -- a
/// label only exists by being listed in some token's "Labels" cell. So this
/// screen shows the distinct set already in use (add a new one from a
/// token's own Overview tab) and can remove a label from every token at once.
class LabelsScreen extends StatefulWidget {
  const LabelsScreen({super.key});

  @override
  State<LabelsScreen> createState() => _LabelsScreenState();
}

class _LabelsScreenState extends State<LabelsScreen> {
  late Future<List<Label>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppRepository>().listLabels();
  }

  void _reload() {
    setState(() => _future = context.read<AppRepository>().listLabels());
  }

  Future<void> _delete(Label l) async {
    await context.read<AppRepository>().deleteLabelEverywhere(l.name);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Labels')),
      body: FutureBuilder<List<Label>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorRetry(message: 'Could not load labels: ${snapshot.error}', onRetry: _reload);
          }
          final labels = snapshot.data!;
          return ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottomSafePadding(context)),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: scheme.onPrimaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Add a new label from a token's Overview tab -- it shows up here once at least one token has it.",
                        style: TextStyle(fontSize: 12.5, color: scheme.onPrimaryContainer, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (labels.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text('No labels yet.', style: TextStyle(color: scheme.onSurfaceVariant)),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < labels.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: scheme.secondaryContainer,
                            child: Icon(Icons.label_rounded, size: 16, color: scheme.onSecondaryContainer),
                          ),
                          title: Text(labels[i].name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline_rounded, color: scheme.onSurfaceVariant),
                            onPressed: () => _delete(labels[i]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
