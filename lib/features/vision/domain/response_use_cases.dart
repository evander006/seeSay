import 'package:seesay/core/storage/response_storage.dart';
import 'package:seesay/core/storage/saved_response.dart';

class SaveLastResponse {
  SaveLastResponse(this._storage);

  final ResponseStorage _storage;

  Future<void> call(SavedResponse response) => _storage.add(response);
}

class GetLastResponses {
  GetLastResponses(this._storage);

  final ResponseStorage _storage;

  Future<List<SavedResponse>> call() => _storage.getAll();
}
