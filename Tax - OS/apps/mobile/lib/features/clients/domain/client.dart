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
    this.responsibleEmployeeId = '',
    this.isArchived = false,
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
  final String responsibleEmployeeId;
  final bool isArchived;

  Client copyWith({bool? isArchived}) => Client(
        id: id,
        name: name,
        type: type,
        taxId: taxId,
        vatNumber: vatNumber,
        contactName: contactName,
        phone: phone,
        email: email,
        address: address,
        notes: notes,
        responsibleEmployeeId: responsibleEmployeeId,
        isArchived: isArchived ?? this.isArchived,
      );
}
