import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../session/session_controller.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MapSelectorPage extends ConsumerStatefulWidget {
  final String driverId;
  const MapSelectorPage({super.key, required this.driverId});

  @override
  ConsumerState<MapSelectorPage> createState() => _MapSelectorPageState();
}

class _MapSelectorPageState extends ConsumerState<MapSelectorPage> {
  final Completer<GoogleMapController> _controller = Completer();
  LatLng? _currentPosition;
  LatLng? _destination;
  String? _destinationName; // New field for destination name
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final TextEditingController _destinationController = TextEditingController();
  List<dynamic> _suggestions = [];
  bool _isSearching = false;
  String? _errorMessage;
  bool _showInstructions = true;
  Timer? _instructionTimer;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _debugApiKey();

    _instructionTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showInstructions = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _instructionTimer?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _debugApiKey() {
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    debugPrint('API Key loaded: ${apiKey != null ? 'Yes' : 'No'}');
    if (apiKey != null) {
      debugPrint('API Key length: ${apiKey.length}');
    }
  }

  Future<void> _determinePosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final newPermission = await Geolocator.requestPermission();
        if (newPermission == LocationPermission.denied ||
            newPermission == LocationPermission.deniedForever) {
          setState(() {
            _errorMessage = 'Location permission denied';
          });
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _markers.add(
          Marker(
            markerId: const MarkerId('origin'),
            position: _currentPosition!,
            infoWindow: const InfoWindow(title: 'You are here'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
          ),
        );
      });

      final mapController = await _controller.future;
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition!, 14),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      setState(() {
        _errorMessage = 'Error getting location: $e';
      });
    }
  }

  void _onSearchChanged(String input) {
    // Cancel any existing timer
    _debounceTimer?.cancel();

    // Clear error message when user starts typing (allows editing)
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }

    final trimmedInput = input.trim();

    if (trimmedInput.length < 3 || _currentPosition == null) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }

    // Debounce the search - only search after user stops typing for 300ms
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(trimmedInput);
    });
  }

  Future<void> _performSearch(String input) async {
    if (!mounted) return;

    setState(() {
      _isSearching = true;
    });

    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      setState(() {
        _errorMessage = 'Google Maps API key not configured';
        _isSearching = false;
      });
      return;
    }

    const url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';
    try {
      final response = await Dio().get(
        url,
        queryParameters: {
          'input': input,
          'key': apiKey,
          'location':
              '${_currentPosition!.latitude},${_currentPosition!.longitude}',
          'radius': 10000,
          'components': 'country:ng',
        },
      );

      final status = response.data['status'];
      debugPrint('Autocomplete API Response: ${response.data}');

      if (!mounted) return;

      if (status == 'OK') {
        // --- SUCCESS CASE ---
        setState(() {
          _suggestions = response.data['predictions'];
          _isSearching = false;
        });
      } else {
        // --- FAILURE CASE (ZERO_RESULTS, etc.) ---
        // Log the real error for debugging.
        debugPrint('Autocomplete failed with status: $status');

        // Update the UI with a user-friendly message and reset the state.
        setState(() {
          _errorMessage =
              "We can't find that location. Please search for or tap another location.";
          _suggestions = [];
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Search failed: $e';
        _suggestions = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _selectSuggestion(String placeId) async {
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    const url = 'https://maps.googleapis.com/maps/api/place/details/json';

    try {
      final response = await Dio().get(
        url,
        queryParameters: {'place_id': placeId, 'key': apiKey},
      );

      final location = response.data['result']['geometry']['location'];
      final latLng = LatLng(location['lat'], location['lng']);
      final placeName = response.data['result']['name'];

      setState(() {
        _destination = latLng;
        _destinationName = placeName; // Store destination name
        _suggestions = [];
        _destinationController.text = placeName;
        _isSearching = false;
        _errorMessage = null;

        _markers.removeWhere(
          (marker) => marker.markerId.value == 'destination',
        );
        _markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: latLng,
            infoWindow: InfoWindow(title: placeName),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
          ),
        );
      });

      if (!mounted) return;

      FocusScope.of(context).unfocus();
      _drawRoute(_currentPosition!, latLng);
    } catch (e) {
      debugPrint('Error selecting suggestion: $e');
      setState(() {
        _errorMessage = 'Error selecting location: $e';
      });
    }
  }

  Future<void> _onMapTap(LatLng position) async {
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    const url = 'https://maps.googleapis.com/maps/api/geocode/json';

    try {
      final response = await Dio().get(
        url,
        queryParameters: {
          'latlng': '${position.latitude},${position.longitude}',
          'key': apiKey,
        },
      );

      final status = response.data['status'];
      debugPrint('Geocode API Response: ${response.data}');

      if (status == 'OK' && response.data['results'].isNotEmpty) {
        // --- SUCCESS CASE ---
        final placeName = response.data['results'][0]['formatted_address'];

        setState(() {
          _destination = position;
          _destinationName = placeName;
          _errorMessage = null; // Clear any previous errors
          _suggestions = [];
          _isSearching = false;
          _destinationController.text = placeName;

          _markers.removeWhere(
            (marker) => marker.markerId.value == 'destination',
          );
          _markers.add(
            Marker(
              markerId: const MarkerId('destination'),
              position: position,
              infoWindow: InfoWindow(title: placeName),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
            ),
          );
        });

        if (!mounted) return;

        FocusScope.of(context).unfocus();
        if (_currentPosition != null) {
          _drawRoute(_currentPosition!, position);
        }
      } else {
        // --- FAILURE CASE (ZERO_RESULTS, etc.) ---
        // Log the real error for debugging
        debugPrint('Geocoding failed with status: $status');

        // Update the UI with a user-friendly message and reset the state
        setState(() {
          _errorMessage =
              "We can't find that location. Please search for or tap another location.";
          // Clear the invalid destination so the user can try again
          _destination = null;
          _destinationName = null;
          _polylines.clear();
          _markers.removeWhere(
            (marker) => marker.markerId.value == 'destination',
          );
          // Clear the text field and unfocus it
          _destinationController.clear();
          _suggestions = [];
          _isSearching = false;
        });

        // Unfocus the text field to prevent immediate re-triggering of search
        if (mounted) {
          FocusScope.of(context).unfocus();
        }
      }
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
      setState(() {
        _errorMessage = 'Error selecting map location: $e';
      });
    }
  }

  Future<void> _drawRoute(LatLng start, LatLng end) async {
    final polylinePoints = PolylinePoints();
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];

    try {
      final result = await polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: apiKey!,
        request: PolylineRequest(
          origin: PointLatLng(start.latitude, start.longitude),
          destination: PointLatLng(end.latitude, end.longitude),
          mode: TravelMode.driving,
        ),
      );

      debugPrint(
        'Directions API Response: ${result.errorMessage ?? result.points}',
      );

      if (result.points.isEmpty) {
        setState(() {
          _errorMessage =
              'No route found: ${result.errorMessage ?? "Unknown error"}';
        });
        return;
      }

      final polylineCoordinates = result.points
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      setState(() {
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId("route"),
            color: Colors.blue,
            width: 5,
            points: polylineCoordinates,
          ),
        );
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('Error drawing route: $e');
      setState(() {
        _errorMessage = 'Error drawing route: $e';
      });
    }
  }

  Future<void> _startTrip() async {
    debugPrint('Start trip called');
    debugPrint('Current position: $_currentPosition');
    debugPrint('Destination: $_destination');
    debugPrint('Destination Name: $_destinationName');
    debugPrint('Driver ID: ${widget.driverId}');

    if (_currentPosition == null || _destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a destination first')),
      );
      return;
    }

    try {
      final originString =
          '${_currentPosition!.latitude},${_currentPosition!.longitude}';
      final destinationString =
          '${_destination!.latitude},${_destination!.longitude}';

      debugPrint('Origin: $originString');
      debugPrint('Destination: $destinationString');

      setState(() {
        _errorMessage = null;
      });

      await ref
          .read(sessionControllerProvider.notifier)
          .startSession(
            context: context,
            driverId: widget.driverId,
            origin: originString,
            destination: destinationString,
            destinationName: _destinationName, // Pass destinationName
          );

      if (!mounted) return;

      debugPrint('Session start called successfully');
    } catch (e) {
      debugPrint('Error starting trip: $e');
      setState(() {
        _errorMessage = 'Error starting trip: $e';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error starting trip: $e')));
    }
  }

  Future<void> _recenterMap() async {
    if (_currentPosition == null) return;
    final mapController = await _controller.future;
    mapController.animateCamera(
      CameraUpdate.newLatLngZoom(_currentPosition!, 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(0, 0),
              zoom: 14,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            onMapCreated: (controller) => _controller.complete(controller),
            onTap: _onMapTap,
          ),
          if (_errorMessage != null)
            Positioned(
              bottom: 180,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _destinationController,
                          onChanged: _onSearchChanged,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 24,
                            ),
                            hintText: 'Enter destination or tap on map',
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      if (_isSearching)
                        const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    ],
                  ),
                  if (_suggestions.isNotEmpty)
                    Container(
                      color: Colors.white,
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _suggestions.length,
                        itemBuilder: (context, index) {
                          final item = _suggestions[index];
                          return ListTile(
                            title: Text(item['description']),
                            onTap: () => _selectSuggestion(item['place_id']),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_showInstructions)
            Positioned(
              bottom: 200,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha((0.3 * 255).toInt()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Tap on the map to select a destination or search above',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          Positioned(
            bottom: 120,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              onPressed: _recenterMap,
              child: const Icon(Icons.my_location, color: Colors.black),
            ),
          ),
          if (_destination != null)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text(
                  "Start Trip",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                onPressed: _startTrip,
              ),
            ),
        ],
      ),
    );
  }
}
