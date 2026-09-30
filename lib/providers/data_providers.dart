import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/error_mapper.dart';
import '../models/expense_model.dart';
import '../models/friend_request_model.dart';
import '../models/settlement_model.dart';
import '../models/user_model.dart';
import '../repositories/expense_repository.dart';
import '../repositories/friend_request_repository.dart';
import '../repositories/friendship_repository.dart';
import '../repositories/settlement_repository.dart';
import '../repositories/user_repository.dart';
import '../services/balance_service.dart';
import '../services/user_cache.dart';

/// Exposes friends (live), friend requests (incoming/outgoing), search,
/// and request actions.
class FriendsProvider extends ChangeNotifier {
  FriendsProvider(
    this._friendshipRepo,
    this._userRepo,
    this._cache,
    FriendRequestRepository requestRepo,
  ) : _requestRepo = requestRepo;

  final FriendshipRepository _friendshipRepo;
  final UserRepository _userRepo;
  final UserCache _cache;
  final FriendRequestRepository _requestRepo;

  StreamSubscription<List<UserModel>>? _sub;
  StreamSubscription<List<FriendRequestModel>>? _incomingSub;
  StreamSubscription<List<FriendRequestModel>>? _outgoingSub;

  List<UserModel> _friends = const [];
  List<FriendRequestModel> _incoming = const [];
  List<FriendRequestModel> _outgoing = const [];
  bool _loading = true;
  bool _disposed = false;
  String? _error;

  List<UserModel> get friends => _friends;
  List<FriendRequestModel> get incomingRequests => _incoming;
  List<FriendRequestModel> get outgoingRequests => _outgoing;
  bool get loading => _loading;
  String? get error => _error;

  Set<String> get _incomingUids =>
      _incoming.map((r) => r.senderId).toSet();

  Set<String> get _outgoingUids =>
      _outgoing.map((r) => r.receiverId).toSet();

  void start() {
    _sub?.cancel();
    _incomingSub?.cancel();
    _outgoingSub?.cancel();
    _loading = true;
    _error = null;
    _sub = _friendshipRepo.watchFriends().listen(
      (friends) {
        _cache.putAll(friends);
        _friends = friends..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _loading = false;
        notifyListeners();
      },
      onError: (Object e) {
        _error = ErrorMapper.map(e).message;
        _loading = false;
        notifyListeners();
      },
    );
    _incomingSub = _requestRepo.watchIncoming().listen(
      (list) {
        _incoming = list;
        // Resolve sender profiles into the cache so the UI can show names.
        for (final r in list) {
          if (_cache.get(r.senderId) == null) {
            getUser(r.senderId).then((_) {
              if (!_disposed) notifyListeners();
            });
          }
        }
        notifyListeners();
      },
      onError: (Object e) {
        _error = ErrorMapper.map(e).message;
        notifyListeners();
      },
    );
    _outgoingSub = _requestRepo.watchOutgoing().listen(
      (list) {
        _outgoing = list;
        notifyListeners();
      },
      onError: (Object e) {
        _error = ErrorMapper.map(e).message;
        notifyListeners();
      },
    );
  }

  void stop() {
    _sub?.cancel();
    _incomingSub?.cancel();
    _outgoingSub?.cancel();
    _sub = null;
    _incomingSub = null;
    _outgoingSub = null;
  }

  Future<List<UserModel>> search(String query) async {
    final uid = _friendshipRepo.currentUid;
    if (uid == null) return [];
    final friendIds = _friends.map((f) => f.uid).toSet();
    final results = await _userRepo.search(
      query: query,
      excludeUid: uid,
      friendUids: friendIds,
    );
    _cache.putAll(results);
    return results;
  }

  /// Returns the [UserModel] for [uid], from cache or Firestore.
  Future<UserModel?> getUser(String uid) async {
    final cached = _cache.get(uid);
    if (cached != null) return cached;
    final user = await _userRepo.getById(uid);
    if (user != null) _cache.put(user);
    return user;
  }

  /// Synchronous display name: 'You' for self, cached name, else fallback.
  String displayName(String uid, {String fallback = 'Someone'}) {
    if (uid == _friendshipRepo.currentUid) return 'You';
    return _cache.get(uid)?.name ?? fallback;
  }

  /// Send a friend request. Returns the outcome for UI messaging.
  Future<SendRequestOutcome> sendRequest(UserModel user) async {
    final outcome = await _requestRepo.send(user.uid);
    _cache.put(user);
    return outcome;
  }

  Future<void> acceptRequest(FriendRequestModel request) async {
    await _requestRepo.accept(request);
    // Friendship + request streams update the UI live.
  }

  Future<void> declineRequest(FriendRequestModel request) async {
    await _requestRepo.decline(request);
  }

  /// UI state for a searched user relative to the current user.
  SearchUserState searchStateFor(String uid) {
    if (_friends.any((f) => f.uid == uid)) return SearchUserState.friends;
    if (_outgoingUids.contains(uid)) return SearchUserState.requestSent;
    if (_incomingUids.contains(uid)) return SearchUserState.incomingRequest;
    return SearchUserState.none;
  }

  FriendRequestModel? incomingRequestFrom(String uid) {
    for (final r in _incoming) {
      if (r.senderId == uid) return r;
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}

/// Holds live expenses + settlements and derives balances through
/// [BalanceService]. No balance is ever persisted.
class ExpensesProvider extends ChangeNotifier {
  ExpensesProvider(
    this._expenseRepo,
    this._settlementRepo,
    this._balanceService,
    this._userRepo,
    this._cache,
  );

  final ExpenseRepository _expenseRepo;
  final SettlementRepository _settlementRepo;
  final BalanceService _balanceService;
  final UserRepository _userRepo;
  final UserCache _cache;

  StreamSubscription<List<ExpenseModel>>? _expSub;
  StreamSubscription<List<SettlementModel>>? _stlSub;

  List<ExpenseModel> _expenses = const [];
  List<SettlementModel> _settlements = const [];
  bool _loadingExpenses = true;
  bool _loadingSettlements = true;
  String? _error;
  String _myUid = '';

  List<ExpenseModel> get expenses => _expenses;
  List<SettlementModel> get settlements => _settlements;
  bool get loading => _loadingExpenses || _loadingSettlements;
  String? get error => _error;
  String get myUid => _myUid;

  void start(String uid) {
    if (_myUid == uid && _expSub != null) return;
    stop();
    _myUid = uid;
    _loadingExpenses = true;
    _loadingSettlements = true;
    _error = null;

    _expSub = _expenseRepo.watchMyExpenses().listen(
      (list) {
        _expenses = list;
        _loadingExpenses = false;
        _collectParticipants(list.map((e) => e.participantIds));
        notifyListeners();
      },
      onError: (Object e) {
        _error = ErrorMapper.map(e).message;
        _loadingExpenses = false;
        notifyListeners();
      },
    );

    _stlSub = _settlementRepo.watchMySettlements().listen(
      (list) {
        _settlements = list;
        _loadingSettlements = false;
        _collectParticipants([
          for (final s in list) [s.from, s.to]
        ]);
        notifyListeners();
      },
      onError: (Object e) {
        _error = ErrorMapper.map(e).message;
        _loadingSettlements = false;
        notifyListeners();
      },
    );
  }

  void stop() {
    _expSub?.cancel();
    _stlSub?.cancel();
    _expSub = null;
    _stlSub = null;
  }

  // ---- balance engine façade (always derived, never stored) ----

  List<PairBalance> pairBalances() => _balanceService.computePairBalances(
        myUid: _myUid,
        expenses: _expenses,
        settlements: _settlements,
      );

  NetBalance netBalance() => _balanceService.computeNetBalance(
        myUid: _myUid,
        expenses: _expenses,
        settlements: _settlements,
      );

  PairBalance? pairBalanceWith(String uid) {
    for (final p in pairBalances()) {
      if (p.otherUid == uid) return p;
    }
    return null;
  }

  List<Transfer> smartSettlement() => _balanceService.computeSmartSettlement(
        expenses: _expenses,
        settlements: _settlements,
      );

  List<ExpenseModel> expensesWith(String uid) => _expenses
      .where((e) => e.participants.containsKey(uid))
      .toList(growable: false);

  List<SettlementModel> settlementsWith(String uid) => _settlements
      .where((s) =>
          (s.from == _myUid && s.to == uid) ||
          (s.from == uid && s.to == _myUid))
      .toList(growable: false);

  /// Create expense via the repo (validation happens there).
  Future<void> addExpense({
    required String title,
    required num amount,
    required String category,
    required String paidBy,
    required Map<String, num> participants,
  }) async {
    await _expenseRepo.createExpense(
      title: title,
      amount: amount,
      category: category,
      paidBy: paidBy,
      participants: participants,
    );
    // Live snapshot updates the UI.
  }

  /// Record a settlement. Throws if it exceeds the outstanding balance.
  Future<void> settleUp({
    required String otherUid,
    required num amount,
  }) async {
    final pair = pairBalanceWith(otherUid);
    final outstanding = pair?.settlementAmount ?? 0;
    if (outstanding <= AppConstants.epsilon) {
      throw const AppException('You\'re already settled up with this person.');
    }
    final theyOweMe = (pair?.net ?? 0) > 0;
    await _settlementRepo.recordSettlement(
      from: theyOweMe ? otherUid : _myUid,
      to: theyOweMe ? _myUid : otherUid,
      amount: amount,
      outstanding: outstanding,
    );
  }

  /// Shared-expense recap for one friend (uses live list; no extra reads).
  List<ExpenseModel> sharedExpenseHistory(String uid) => expensesWith(uid);

  void _collectParticipants(Iterable<List<String>> idLists) {
    final all = <String>{};
    for (final ids in idLists) {
      all.addAll(ids);
    }
    // Resolve any participants missing from the cache (bounded, batched).
    final missing =
        all.where((id) => id != _myUid && _cache.get(id) == null).toList();
    if (missing.isNotEmpty) {
      _userRepo.getByIds(missing).then((users) => _cache.putAll(users));
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// Relationship state between the current user and a searched user.
enum SearchUserState {
  none,
  friends,
  requestSent,
  incomingRequest,
}
