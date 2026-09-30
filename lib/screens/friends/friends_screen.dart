import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/error_mapper.dart';
import '../../models/friend_request_model.dart';
import '../../models/user_model.dart';
import '../../providers/data_providers.dart';
import '../../repositories/friend_request_repository.dart' show SendRequestOutcome;
import '../../widgets/empty_state.dart';
import '../../widgets/friend_tile.dart';
import '../../widgets/loading.dart';
import 'friend_details_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  List<UserModel> _results = const [];
  String? _error;
  String? _busyUid;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String q) async {
    final trimmed = q.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
        _error = null;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final friends = context.read<FriendsProvider>();
      final results = await friends.search(trimmed);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
        _error = null;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _searching = false;
        _error = e.message;
      });
    }
  }

  Future<void> _sendRequest(UserModel user) async {
    setState(() => _busyUid = user.uid);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final outcome =
          await context.read<FriendsProvider>().sendRequest(user);
      if (!mounted) return;
      setState(() => _busyUid = null);
      final message = switch (outcome) {
        SendRequestOutcome.sent => 'Friend request sent to ${user.name} 📨',
        SendRequestOutcome.requestAlreadySent =>
          'Request already sent to ${user.name.split(' ').first}',
        SendRequestOutcome.incomingRequestExists =>
          '${user.name.split(' ').first} already sent you a request — accept it below 👇',
        SendRequestOutcome.alreadyFriends =>
          'You\'re already friends with ${user.name.split(' ').first}',
      };
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _busyUid = null);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _accept(FriendRequestModel request) async {
    setState(() => _busyUid = request.senderId);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<FriendsProvider>().acceptRequest(request);
      if (!mounted) return;
      setState(() => _busyUid = null);
      messenger.showSnackBar(
        const SnackBar(content: Text('Friend added 🎉')),
      );
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _busyUid = null);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _decline(FriendRequestModel request) async {
    setState(() => _busyUid = request.senderId);
    try {
      await context.read<FriendsProvider>().declineRequest(request);
      if (!mounted) return;
      setState(() => _busyUid = null);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _busyUid = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsProvider = context.watch<FriendsProvider>();
    final expenses = context.watch<ExpensesProvider>();

    final incoming = friendsProvider.incomingRequests;

    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.m, AppSpacing.s, AppSpacing.m, AppSpacing.s),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _runSearch,
              decoration: InputDecoration(
                hintText: 'Search by name or exact email...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          _runSearch('');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: _searching
                ? const LoadingView(message: 'Searching users...')
                : _error != null
                    ? ErrorView(message: _error!)
                    : _results.isNotEmpty
                        ? _SearchResults(
                            results: _results,
                            busyUid: _busyUid,
                            onSend: _sendRequest,
                            onAccept: _accept,
                            onDecline: _decline,
                          )
                        : friendsProvider.loading
                            ? const LoadingView(message: 'Loading friends...')
                            : (friendsProvider.friends.isEmpty &&
                                    incoming.isEmpty)
                                ? EmptyState(
                                    emoji: '👥',
                                    title: 'No friends yet',
                                    message:
                                        'Search a friend by name or email and send them a request to start splitting.',
                                  )
                                : _FriendsList(
                                    provider: friendsProvider,
                                    expenses: expenses,
                                    incoming: incoming,
                                    busyUid: _busyUid,
                                    onAccept: _accept,
                                    onDecline: _decline,
                                  ),
          ),
        ],
      ),
    );
  }
}

class _FriendsList extends StatelessWidget {
  const _FriendsList({
    required this.provider,
    required this.expenses,
    required this.incoming,
    required this.busyUid,
    required this.onAccept,
    required this.onDecline,
  });

  final FriendsProvider provider;
  final ExpensesProvider expenses;
  final List<FriendRequestModel> incoming;
  final String? busyUid;
  final void Function(FriendRequestModel) onAccept;
  final void Function(FriendRequestModel) onDecline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, 0, AppSpacing.m, 96),
      children: [
        if (incoming.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.mark_email_unread_rounded,
                  size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Text('Pending Requests',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${incoming.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          for (final request in incoming)
            _PendingRequestTile(
              request: request,
              name: provider.displayName(request.senderId,
                  fallback: 'Someone'),
              busy: busyUid == request.senderId,
              onAccept: () => onAccept(request),
              onDecline: () => onDecline(request),
            ),
          const SizedBox(height: AppSpacing.l),
        ],
        Text('My Friends', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.s),
        if (provider.friends.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
            child: Text(
              'No friends yet — send a request above.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          )
        else
          for (final friend in provider.friends)
            FriendTile(
              friend: friend,
              balance: expenses.pairBalanceWith(friend.uid),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FriendDetailsScreen(friend: friend),
                ),
              ),
            ),
      ],
    );
  }
}

class _PendingRequestTile extends StatelessWidget {
  const _PendingRequestTile({
    required this.request,
    required this.name,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final FriendRequestModel request;
  final String name;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.coral,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    'wants to add you',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton.tonal(
                        onPressed: onDecline,
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Decline'),
                      ),
                      const SizedBox(width: 6),
                      FilledButton(
                        onPressed: onAccept,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.positive,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Accept'),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.results,
    required this.busyUid,
    required this.onSend,
    required this.onAccept,
    required this.onDecline,
  });

  final List<UserModel> results;
  final String? busyUid;
  final void Function(UserModel) onSend;
  final void Function(FriendRequestModel) onAccept;
  final void Function(FriendRequestModel) onDecline;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FriendsProvider>();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, 0, AppSpacing.m, 16),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final user = results[i];
        final state = provider.searchStateFor(user.uid);
        final busy = busyUid == user.uid;

        Widget action;
        if (busy) {
          action = const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        } else {
          action = switch (state) {
            SearchUserState.friends => const Chip(label: Text('Already friends')),
            SearchUserState.requestSent =>
              const Chip(label: Text('Request Sent')),
            SearchUserState.incomingRequest => Builder(
                builder: (context) {
                  final request = provider.incomingRequestFrom(user.uid)!;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton.tonal(
                        onPressed: () => onDecline(request),
                        child: const Text('Decline'),
                      ),
                      const SizedBox(width: 6),
                      FilledButton(
                        onPressed: () => onAccept(request),
                        child: const Text('Accept'),
                      ),
                    ],
                  );
                },
              ),
            SearchUserState.none => FilledButton(
                onPressed: () => onSend(user),
                child: const Text('Add Friend'),
              ),
          };
        }

        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.s),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.indigo,
              child: Text(
                user.initials,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
            title: Text(user.name),
            subtitle: Text(user.email),
            trailing: action,
          ),
        );
      },
    );
  }
}
