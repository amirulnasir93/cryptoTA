import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_client.dart';
import '../models.dart';
import '../widgets/common.dart';

class LabelsScreen extends StatefulWidget {
  const LabelsScreen({super.key});

  @override
  State<LabelsScreen> createState() => _LabelsScreenState();
}

class _LabelsScreenState extends State<LabelsScreen> {
  late Future<List<Label>> _future;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiClient>().listLabels();
  }

  void _reload() {
    setState(() => _future = context.read<ApiClient>().listLabels());
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    await context.read<ApiClient>().createLabel(name, null);
    _nameController.clear();
    _reload();
  }

  Future<void> _delete(Label l) async {
    await context.read<ApiClient>().deleteLabel(l.id);
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
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'New label name', border: OutlineInputBorder()),
                    onSubmitted: (_) => _create(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _create, child: const Text('Add')),
              ],
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
                    final color = l.color != null ? Color(int.parse(l.color!.replaceFirst('#', '0xFF'))) : Colors.grey;
                    return ListTile(
                      leading: CircleAvatar(backgroundColor: color, radius: 8),
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
