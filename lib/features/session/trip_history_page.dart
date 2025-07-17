import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_controller.dart';
import '../../models/session.dart';

class TripHistoryPage extends ConsumerStatefulWidget {
  const TripHistoryPage({super.key});

  @override
  ConsumerState<TripHistoryPage> createState() => _TripHistoryPageState();
}

class _TripHistoryPageState extends ConsumerState<TripHistoryPage>
    with SingleTickerProviderStateMixin {
  int _currentPage = 0;
  final int _itemsPerPage = 10;
  String _sortBy = 'date'; // 'date', 'distance', 'duration'
  bool _sortAscending = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _hasFetched = false; // Track if fetch has been attempted

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    // Check sessions and fetch if empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authControllerProvider);
      if (authState.user?.sessions?.isEmpty ?? true) {
        _fetchSessions();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchSessions() async {
    if (_hasFetched) return; // Fetch only once
    setState(() {
      _hasFetched = true;
    });
  }

  List<SessionModel> _getSortedAndFilteredSessions(
    List<SessionModel> sessions,
  ) {
    // Filter sessions based on search query
    List<SessionModel> filteredSessions = sessions.where((session) {
      final destinationName = session.destinationName?.toLowerCase() ?? '';
      final origin = session.origin.toLowerCase();
      final destination = session.destination.toLowerCase();
      final query = _searchQuery.toLowerCase();

      return destinationName.contains(query) ||
          origin.contains(query) ||
          destination.contains(query);
    }).toList();

    // Sort sessions
    filteredSessions.sort((a, b) {
      int comparison = 0;

      switch (_sortBy) {
        case 'date':
          final dateA = DateTime.tryParse(a.createdAt ?? '') ?? DateTime.now();
          final dateB = DateTime.tryParse(b.createdAt ?? '') ?? DateTime.now();
          comparison = dateA.compareTo(dateB);
          break;
        case 'distance':
          final distanceA = a.distance ?? 0.0;
          final distanceB = b.distance ?? 0.0;
          comparison = distanceA.compareTo(distanceB);
          break;
        case 'duration':
          final durationA = _parseDuration(a.duration ?? '');
          final durationB = _parseDuration(b.duration ?? '');
          comparison = durationA.compareTo(durationB);
          break;
      }

      return _sortAscending ? comparison : -comparison;
    });

    return filteredSessions;
  }

  int _parseDuration(String duration) {
    // Simple duration parsing - adjust based on your duration format
    final parts = duration.split(':');
    if (parts.length >= 2) {
      final hours = int.tryParse(parts[0]) ?? 0;
      final minutes = int.tryParse(parts[1]) ?? 0;
      return hours * 60 + minutes;
    }
    return 0;
  }

  List<SessionModel> _getPaginatedSessions(List<SessionModel> sessions) {
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, sessions.length);

    if (startIndex >= sessions.length) return [];

    return sessions.sublist(startIndex, endIndex);
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';

    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildSortButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).toInt()),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: PopupMenuButton<String>(
        onSelected: (value) {
          setState(() {
            if (value == _sortBy) {
              _sortAscending = !_sortAscending;
            } else {
              _sortBy = value;
              _sortAscending = false;
            }
            _currentPage = 0;
          });
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'date',
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 8),
                Text('Date'),
                if (_sortBy == 'date') ...[
                  const Spacer(),
                  Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 16,
                  ),
                ],
              ],
            ),
          ),
          PopupMenuItem(
            value: 'distance',
            child: Row(
              children: [
                Icon(Icons.straighten, size: 16),
                const SizedBox(width: 8),
                Text('Distance'),
                if (_sortBy == 'distance') ...[
                  const Spacer(),
                  Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 16,
                  ),
                ],
              ],
            ),
          ),
          PopupMenuItem(
            value: 'duration',
            child: Row(
              children: [
                Icon(Icons.access_time, size: 16),
                const SizedBox(width: 8),
                Text('Duration'),
                if (_sortBy == 'duration') ...[
                  const Spacer(),
                  Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 16,
                  ),
                ],
              ],
            ),
          ),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              'Sort',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).toInt()),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _currentPage = 0;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search trips...',
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.search, color: Colors.blue.shade600, size: 20),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildTripCard(SessionModel session, int index) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 100)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.05 * 255).toInt()),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.location_on,
                      color: Colors.blue.shade600,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.destinationName ??
                              'Trip to ${session.destination}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'From: ${session.origin}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      Icons.straighten,
                      'Distance',
                      '${(session.distance ?? 0.0).toStringAsFixed(2)} km',
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoChip(
                      Icons.access_time,
                      'Duration',
                      session.duration ?? 'N/A',
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(session.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).toInt()),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withAlpha((0.7 * 255).toInt()),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls(int totalPages) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _currentPage > 0
                ? () => setState(() => _currentPage--)
                : null,
            icon: const Icon(Icons.chevron_left),
            style: IconButton.styleFrom(
              backgroundColor: _currentPage > 0
                  ? Colors.blue.shade50
                  : Colors.grey.shade100,
              foregroundColor: _currentPage > 0
                  ? Colors.blue.shade600
                  : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${_currentPage + 1} of $totalPages',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: _currentPage < totalPages - 1
                ? () => setState(() => _currentPage++)
                : null,
            icon: const Icon(Icons.chevron_right),
            style: IconButton.styleFrom(
              backgroundColor: _currentPage < totalPages - 1
                  ? Colors.blue.shade50
                  : Colors.grey.shade100,
              foregroundColor: _currentPage < totalPages - 1
                  ? Colors.blue.shade600
                  : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.history, size: 64, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isEmpty
                ? 'No trips found'
                : 'No trips match your search',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Start your journey and your trips will appear here'
                : 'Try adjusting your search terms',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final sessions = authState.user?.sessions ?? [];
    final sortedAndFilteredSessions = _getSortedAndFilteredSessions(sessions);
    final paginatedSessions = _getPaginatedSessions(sortedAndFilteredSessions);
    final totalPages = (sortedAndFilteredSessions.length / _itemsPerPage)
        .ceil();

    // Listen to authControllerProvider for updates
    // ref.listen(sessionControllerProvider, (previous, next) {
    //   if (previous != next) {
    //     // Tell the AuthController to refresh its state from the server.
    //     ref.read(authControllerProvider.notifier).checkAuth(context);
    //   }
    // });

    // Listen to sessionControllerProvider for session changes
    // ref.listen(sessionControllerProvider, (previous, next) {
    //   if (previous != next) {
    //     Future.microtask(() async {
    //       try {
    //         final userData = await ApiService.get(
    //           '/api/auth/me',
    //           useAuth: true,
    //         );
    //         if (mounted) {
    //           setState(() {
    //             _userData = userData['user'];
    //           });
    //         }
    //       } catch (e) {
    //         if (context.mounted) {
    //           ScaffoldMessenger.of(context).showSnackBar(
    //             SnackBar(content: Text('Error refreshing sessions: $e')),
    //           );
    //         }
    //       }
    //     });
    //   }
    // });

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          // Use the user from the provider directly
          "${authState.user?.name}'s ${_searchQuery.isEmpty ? "Trip History" : 'Trip History'}",
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.1 * 255).toInt()),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: authState.isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              )
            : Column(
                children: [
                  // Search and Sort Controls
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildSearchBar(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildSortButton(),
                            const Spacer(),
                            Text(
                              '${sortedAndFilteredSessions.length} trip${sortedAndFilteredSessions.length != 1 ? 's' : ''}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Trip List
                  Expanded(
                    child: sortedAndFilteredSessions.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: paginatedSessions.length,
                            itemBuilder: (context, index) {
                              return _buildTripCard(
                                paginatedSessions[index],
                                index,
                              );
                            },
                          ),
                  ),

                  // Pagination Controls
                  if (totalPages > 1) _buildPaginationControls(totalPages),
                ],
              ),
      ),
    );
  }
}
