import 'package:flutter_contacts/flutter_contacts.dart';

class ContactSaver {
  static Future<void> saveContact(String name, String phone) async {
    final newContact = Contact()
      ..name.first = name
      ..phones = [Phone(phone)];
    await newContact.insert();
  }
}
