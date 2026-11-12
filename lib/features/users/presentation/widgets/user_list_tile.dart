import 'package:flutter/material.dart';

class UserListTile extends StatelessWidget {
  const UserListTile({
    super.key,
    required this.name,
    required this.email,
  });

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
      title: Text(name),
      subtitle: Text(email),
    );
  }
}
