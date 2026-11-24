import '../domain/client.dart';

abstract interface class ClientRepository {
  List<Client> getAll();

  void save(Client client);

  void delete(String clientId);
}

class InMemoryClientRepository implements ClientRepository {
  InMemoryClientRepository({List<Client>? initialClients})
      : _clients = List.of(initialClients ?? demoClients);

  final List<Client> _clients;

  static const demoClients = <Client>[
    Client(
      id: 'demo-1',
      name: 'شركة النور للتجارة',
      type: ClientType.company,
    ),
    Client(
      id: 'demo-2',
      name: 'مؤسسة الأمل',
      type: ClientType.company,
    ),
    Client(
      id: 'demo-3',
      name: 'دلتا للخدمات',
      type: ClientType.company,
    ),
    Client(
      id: 'demo-4',
      name: 'أحمد محمود',
      type: ClientType.individual,
    ),
  ];

  @override
  List<Client> getAll() => List.unmodifiable(_clients);

  @override
  void save(Client client) {
    final index = _clients.indexWhere((item) => item.id == client.id);
    if (index == -1) {
      _clients.add(client);
    } else {
      _clients[index] = client;
    }
  }

  @override
  void delete(String clientId) {
    _clients.removeWhere((client) => client.id == clientId);
  }
}
