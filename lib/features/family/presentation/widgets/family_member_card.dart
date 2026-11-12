import 'package:flutter/material.dart';

class FamilyMemberCard extends StatelessWidget {
  const FamilyMemberCard({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(name),
        subtitle: const Text('Family member'),
      ),
    );
  }
}
