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
    return Scaffold(
      appBar: AppBar(title: const Text('Labels')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Add a new label from a token\'s Overview tab -- it shows up here once at least one token has it.',
              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Label>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return ErrorRetry(message: 'Could not load labels: ${snapshot.error}', onRetry: _reload);
                }
                final labels = snapshot.data!;
                if (labels.isEmpty) {
                  return Center(child: Text('No labels yet.', style: TextStyle(color: Theme.of(context).hintColor)));
                }
                return ListView.separated(
                  itemCount: labels.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final l = labels[i];
                    return ListTile(
                      title: Text(l.name),
                      trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(l)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
