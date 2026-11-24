enum ClientType { company, individual }

class Client {
  const Client({
    required this.id,
    required this.name,
    required this.type,
    this.taxId = '',
    this.vatNumber = '',
    this.contactName = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.notes = '',
  });

  final String id;
  final String name;
  final ClientType type;
  final String taxId;
  final String vatNumber;
  final String contactName;
  final String phone;
  final String email;
  final String address;
  final String notes;
}
