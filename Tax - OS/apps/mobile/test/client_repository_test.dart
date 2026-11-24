import 'package:flutter_test/flutter_test.dart';
import 'package:taxos/features/clients/data/client_repository.dart';
import 'package:taxos/features/clients/domain/client.dart';

void main() {
  test('repository creates, updates, and deletes a client', () {
    final repository = InMemoryClientRepository(initialClients: const []);
    const client = Client(
      id: 'client-1',
      name: 'شركة تجريبية',
      type: ClientType.company,
      taxId: '123456789',
    );

    repository.save(client);
    expect(repository.getAll(), hasLength(1));
    expect(repository.getAll().single.name, 'شركة تجريبية');

    repository.save(
      const Client(
        id: 'client-1',
        name: 'شركة تجريبية بعد التعديل',
        type: ClientType.company,
        taxId: '123456789',
      ),
    );
    expect(repository.getAll(), hasLength(1));
    expect(repository.getAll().single.name, 'شركة تجريبية بعد التعديل');

    repository.delete('client-1');
    expect(repository.getAll(), isEmpty);
  });

  test('repository exposes an unmodifiable client collection', () {
    final repository = InMemoryClientRepository();
    expect(
      () => repository.getAll().clear(),
      throwsUnsupportedError,
    );
  });
}
