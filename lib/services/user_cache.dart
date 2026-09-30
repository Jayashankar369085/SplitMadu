import '../models/user_model.dart';
import '../repositories/user_repository.dart';

/// Simple in-memory UID → UserModel cache shared across providers/screens so
/// the same user is fetched from Firestore once per session.
class UserCache {
  final _cache = <String, UserModel>{};

  UserModel? get(String uid) => _cache[uid];

  void put(UserModel user) => _cache[user.uid] = user;

  void putAll(Iterable<UserModel> users) {
    for (final u in users) {
      _cache[u.uid] = u;
    }
  }

  List<UserModel> getAll(Iterable<String> uids) => [
        for (final uid in uids)
          if (_cache[uid] != null) _cache[uid]!,
      ];

  bool hasAll(Iterable<String> uids) => uids.every(_cache.containsKey);

  void clear() => _cache.clear();
}

/// Convenience: resolve names for a list of UIDs, using cache first and
/// filling gaps from Firestore.
Future<Map<String, UserModel>> resolveUsers(
  UserRepository repo,
  UserCache cache,
  Iterable<String> uids,
) async {
  final result = <String, UserModel>{};
  final missing = <String>[];
  for (final uid in uids) {
    final cached = cache.get(uid);
    if (cached != null) {
      result[uid] = cached;
    } else {
      missing.add(uid);
    }
  }
  if (missing.isNotEmpty) {
    final fetched = await repo.getByIds(missing);
    cache.putAll(fetched);
    for (final u in fetched) {
      result[u.uid] = u;
    }
  }
  return result;
}
