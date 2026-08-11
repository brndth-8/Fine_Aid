import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/admin_shared_widgets.dart';

class AdminContentManagement extends StatefulWidget {
  const AdminContentManagement({super.key});

  @override
  State<AdminContentManagement> createState() => _AdminContentManagementState();
}

class _AdminContentManagementState extends State<AdminContentManagement> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _category = 'Emergency';
  bool _offlineAvailable = true;
  String? _editingId;

  final List<String> _categories = [
    'Emergency',
    'Injuries',
    'Wounds',
    'Skin',
    'Burns',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    final data = {
      'title': _titleController.text.trim(),
      'content': _contentController.text.trim(),
      'category': _category,
      'offlineAvailable': _offlineAvailable,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (_editingId != null) {
      await FirebaseFirestore.instance
          .collection('firstAidContent')
          .doc(_editingId)
          .update(data);
    } else {
      data['createdAt'] = FieldValue.serverTimestamp();
      data['status'] = 'Live';
      await FirebaseFirestore.instance.collection('firstAidContent').add(data);
    }
    _titleController.clear();
    _contentController.clear();
    setState(() => _editingId = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        AdminHeader(
          title: 'Content management',
          subtitle:
              'Update first aid instructions, add new emergency procedures, and modify health information to ensure accuracy.',
          action: ElevatedButton.icon(
            onPressed: () {
              _titleController.clear();
              _contentController.clear();
              setState(() => _editingId = null);
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New article'),
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Content library table
              Expanded(
                flex: 3,
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('firstAidContent')
                      .orderBy('updatedAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data!.docs;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              color: Colors.grey.shade50,
                              child: Row(
                                children: [
                                  _th('Title', flex: 3),
                                  _th('Category'),
                                  _th('Updated'),
                                  _th('Status'),
                                  _th('Action'),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            if (docs.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'No content yet.',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ...docs.map((doc) {
                              final data = doc.data();
                              final ts = data['updatedAt'] as Timestamp?;
                              final updated = ts != null
                                  ? 'Mar ${ts.toDate().day}'
                                  : '';
                              return Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            data['title'] ?? '',
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(color: Colors.black),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            data['category'] ?? '',
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  color: Colors.black87,
                                                ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            updated,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  color: Colors.black87,
                                                ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: const Text(
                                              'Live',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: TextButton(
                                            onPressed: () {
                                              _titleController.text =
                                                  data['title'] ?? '';
                                              _contentController.text =
                                                  data['content'] ?? '';
                                              setState(() {
                                                _editingId = doc.id;
                                                _category =
                                                    data['category'] ??
                                                    'Emergency';
                                              });
                                            },
                                            child: const Text(
                                              'Edit',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Edit panel
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _editingId != null ? 'Edit article' : 'New article',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Title',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            hintText: 'Enter title',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Category',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    initialValue: _category,
                                    items: _categories
                                        .map(
                                          (c) => DropdownMenuItem(
                                            value: c,
                                            child: Text(
                                              c,
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _category = v!),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Offline available',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.black,
                                  ),
                                ),
                                Switch(
                                  value: _offlineAvailable,
                                  onChanged: (v) =>
                                      setState(() => _offlineAvailable = v),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Content',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _contentController,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            hintText: 'Enter content',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _save,
                                child: const Text('Save changes'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {},
                                child: const Text(
                                  'Preview',
                                  style: TextStyle(color: Colors.black),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _th(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }
}
