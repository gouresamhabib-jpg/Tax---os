import 'client.dart';

abstract interface class ClientRepository {
  List<Client> getAll();

  void save(Client client);

  void archive(String clientId);

  void restore(String clientId);
}
