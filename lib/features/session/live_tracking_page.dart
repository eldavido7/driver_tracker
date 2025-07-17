import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../config/env.dart';
import '../session/session_controller.dart';
import 'package:share_plus/share_plus.dart';

class LiveTrackingPage extends ConsumerStatefulWidget {
  final String sessionId;

  const LiveTrackingPage({super.key, required this.sessionId});

  @override
  ConsumerState<LiveTrackingPage> createState() => _LiveTrackingPageState();
}

class _LiveTrackingPageState extends ConsumerState<LiveTrackingPage>
    with WidgetsBindingObserver {
  final Completer<GoogleMapController> _mapController = Completer();
  LatLng? _driverLocation;
  LatLng? _destination;
  Map? _sessionData;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  Timer? _pollingTimer;
  String? _etaText;
  final Location _location = Location();
  bool _isSessionActive = true;

  Future<void> _storeSessionId(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_session_id', sessionId);
    debugPrint('Stored sessionId: $sessionId');
  }

  void _shareSession() async {
    final shareUrl = '${Env.apiUrl}/track?sessionId=${widget.sessionId}';
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    final result = await SharePlus.instance.share(
      ShareParams(
        text: 'Track my trip live: $shareUrl',
        subject: 'Live Trip Tracking',
        sharePositionOrigin: origin,
      ),
    );

    if (result.status == ShareResultStatus.success) {
      debugPrint('Share successful');
    } else if (result.status == ShareResultStatus.dismissed) {
      debugPrint('Share dismissed');
    } else {
      debugPrint('Share not available');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _storeSessionId(widget.sessionId);
    _fetchInitialSessionData();
    _initLocationService();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('AppLifecycleState: $state');
    if (state == AppLifecycleState.resumed && mounted && _isSessionActive) {
      if (_pollingTimer == null || !_pollingTimer!.isActive) {
        _startPolling();
        debugPrint('Restarted polling timer on app resume');
      }
    } else if (state == AppLifecycleState.paused) {
      _pollingTimer?.cancel();
      debugPrint('App paused, polling stopped');
    }
  }

  Future<void> _initLocationService() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          debugPrint('Location service disabled');
          return;
        }
      }

      PermissionStatus permission = await _location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _location.requestPermission();
        if (permission != PermissionStatus.granted) {
          debugPrint('Location permission denied');
          return;
        }
      }

      _startPolling();
    } catch (e) {
      debugPrint('Error initializing location service: $e');
    }
  }

  Future<void> _fetchInitialSessionData() async {
    try {
      final session = await ApiService.get(
        '/api/sessions/${widget.sessionId}',
        useAuth: true,
      );
      final destinationParts = session['destination']
          .split(',')
          .map(double.parse)
          .toList();

      setState(() {
        _sessionData = session;
        _destination = LatLng(destinationParts[0], destinationParts[1]);
        _markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: _destination!,
            infoWindow: const InfoWindow(title: 'Destination'),
          ),
        );
      });

      _fetchLocation();
    } catch (e) {
      debugPrint('Failed to load session data: $e');
      setState(() {
        _isSessionActive = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load session data: $e')),
        );
      }
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel(); // Prevent duplicate timers
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (mounted && _isSessionActive) {
        await _fetchLocation();
      } else {
        _pollingTimer?.cancel();
        debugPrint('Polling stopped: widget unmounted or session inactive');
      }
    });
    debugPrint('Started polling timer');
  }

  Future<void> _fetchLocation() async {
    try {
      // Verify session status
      final session = await ApiService.get(
        '/api/sessions/${widget.sessionId}',
        useAuth: true,
      );
      if (session['status'] != 'active') {
        debugPrint('Session is not active: ${session['status']}');
        setState(() {
          _isSessionActive = false;
        });
        _pollingTimer?.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session is no longer active')),
          );
        }
        return;
      }

      // Post location
      try {
        final locationData = await _location.getLocation();
        if (locationData.latitude != null && locationData.longitude != null) {
          final response = await ApiService.post('/api/location', {
            'sessionId': widget.sessionId,
            'latitude': locationData.latitude,
            'longitude': locationData.longitude,
          }, useAuth: true);
          debugPrint(
            'Posted location for sessionId: ${widget.sessionId}, Response: ${response.statusCode}',
          );
          if (response.statusCode != 200) {
            debugPrint(
              'Location post failed with status: ${response.statusCode}, Body: ${response.body}',
            );
          }
        }
      } catch (e) {
        debugPrint('Error posting location: $e');
      }

      // Get latest location
      try {
        final loc = await ApiService.get(
          '/api/location?sessionId=${widget.sessionId}',
          useAuth: false,
        );
        if (loc['latitude'] != null && loc['longitude'] != null) {
          final newLoc = LatLng(loc['latitude'], loc['longitude']);

          setState(() {
            _driverLocation = newLoc;
            _markers.removeWhere((m) => m.markerId.value == 'driver');
            _markers.add(
              Marker(
                markerId: const MarkerId('driver'),
                position: newLoc,
                infoWindow: const InfoWindow(title: 'Driver'),
              ),
            );
          });

          if (_destination != null) {
            await _drawRouteAndEstimateETA(newLoc, _destination!);

            final distance = _calculateDistance(newLoc, _destination!);
            if (distance < 0.005) {
              await _endSession();
            }
          }

          final controller = await _mapController.future;
          controller.animateCamera(CameraUpdate.newLatLng(newLoc));
        }
      } catch (e) {
        debugPrint('Error fetching location: $e');
      }
    } catch (e) {
      debugPrint('Error in fetchLocation: $e');
      if (e.toString().contains('410')) {
        setState(() {
          _isSessionActive = false;
        });
        _pollingTimer?.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session expired or invalid')),
          );
        }
      }
    }
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371; // km
    final double dLat = (end.latitude - start.latitude) * pi / 180;
    final double dLon = (end.longitude - start.longitude) * pi / 180;
    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(start.latitude * pi / 180) *
            cos(end.latitude * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c; // Distance in km
  }

  Future<void> _endSession() async {
    try {
      double distance = 0.0;
      String duration = 'N/A';
      try {
        final response = await http.get(
          Uri.parse(
            'https://maps.googleapis.com/maps/api/directions/json'
            '?origin=${_sessionData!['origin'].split(',')[0]},${_sessionData!['origin'].split(',')[1]}'
            '&destination=${_destination!.latitude},${_destination!.longitude}'
            '&mode=driving'
            '&key=${Env.mapsApiKey}',
          ),
        );
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          distance =
              data['routes'][0]['legs'][0]['distance']['value'] / 1000.0; // km
        }
      } catch (e) {
        debugPrint('Error fetching Directions API for distance: $e');
      }

      final createdAt = DateTime.tryParse(_sessionData!['createdAt'] ?? '');
      if (createdAt != null) {
        final elapsed = DateTime.now().difference(createdAt);
        duration = elapsed.inSeconds < 60
            ? '${elapsed.inSeconds} sec${elapsed.inSeconds != 1 ? 's' : ''}'
            : '${elapsed.inMinutes} min${elapsed.inMinutes != 1 ? 's' : ''}';
      }

      debugPrint(
        'Calling endSession with distance: $distance, duration: $duration',
      );
      if (!mounted) return;
      await ref
          .read(sessionControllerProvider.notifier)
          .endSession(
            context: context,
            sessionId: widget.sessionId,
            distance: distance,
            duration: duration,
          );

      setState(() {
        _isSessionActive = false;
      });
      _pollingTimer?.cancel();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_session_id');
      await _showTripSummary(distance, duration);
    } catch (e) {
      debugPrint('Error ending session: $e');
    }
  }

  Future<void> _showTripSummary(double distance, String duration) async {
    if (_sessionData == null ||
        _driverLocation == null ||
        _destination == null) {
      return;
    }
    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Trip Summary'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Start Point: ${_sessionData!['origin']}'),
              Text('Destination: ${_sessionData!['destinationName']}'),
              Text('Driver: ${_sessionData!['driver']['name']}'),
              Text('Distance: ${distance.toStringAsFixed(2)} km'),
              Text('Duration: $duration'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _drawRouteAndEstimateETA(LatLng from, LatLng to) async {
    try {
      final polylinePoints = PolylinePoints();
      final result = await polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: Env.mapsApiKey,
        request: PolylineRequest(
          origin: PointLatLng(from.latitude, from.longitude),
          destination: PointLatLng(to.latitude, to.longitude),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isNotEmpty) {
        final polylineCoordinates = result.points
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();

        setState(() {
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              color: Colors.blue,
              width: 5,
              points: polylineCoordinates,
            ),
          );
        });
      }

      _etaText = "En route";
    } catch (e) {
      debugPrint('Error drawing route or fetching ETA: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _driverLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _driverLocation!,
                    zoom: 15,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: false,
                  onMapCreated: (controller) =>
                      _mapController.complete(controller),
                ),
                if (_etaText != null)
                  Positioned(
                    top: 40,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 6),
                        ],
                      ),
                      child: Text(
                        "Estimated arrival: $_etaText",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 80,
                  left: 20,
                  right: 20,
                  child: ElevatedButton(
                    onPressed: _endSession,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Stop Sharing',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: ElevatedButton.icon(
                    onPressed: _shareSession,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.share, size: 20),
                    label: const Text(
                      'Share Trip',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
