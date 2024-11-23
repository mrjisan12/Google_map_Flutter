import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

const String GOOGLE_MAPS_API_KEY = 'YOUR_GOOGLE_MAPS_API_KEY_HERE';

class GoogleMapPage extends StatefulWidget {
  const GoogleMapPage({Key? key}) : super(key: key);

  @override
  State<GoogleMapPage> createState() => _GoogleMapPageState();
}

class _GoogleMapPageState extends State<GoogleMapPage> {
  final Location _locationController = Location();
  final Completer<GoogleMapController> _mapController = Completer();

  static const LatLng dhaka = LatLng(23.8041, 90.4152);
  static const LatLng sirajganj = LatLng(24.4616, 89.7053);

  LatLng? _currentPosition;
  Map<PolylineId, Polyline> polylines = {};
  bool isCameraMoved = false;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _checkLocationPermissions();
    final polylineCoordinates = await _getPolylinePoints();
    _generatePolylineFromPoints(polylineCoordinates);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
        onMapCreated: (GoogleMapController controller) {
          _mapController.complete(controller);
        },
        initialCameraPosition: const CameraPosition(
          target: dhaka,
          zoom: 13,
        ),
        markers: _createMarkers(),
        polylines: Set<Polyline>.of(polylines.values),
      ),
    );
  }

  Set<Marker> _createMarkers() {
    return {
      if (_currentPosition != null)
        Marker(
          markerId: const MarkerId("_currentLocation"),
          icon: BitmapDescriptor.defaultMarker,
          position: _currentPosition!,
        ),
      const Marker(
        markerId: MarkerId("_sourceLocation"),
        icon: BitmapDescriptor.defaultMarker,
        position: dhaka,
      ),
      const Marker(
        markerId: MarkerId("_destinationLocation"),
        icon: BitmapDescriptor.defaultMarker,
        position: sirajganj,
      ),
    };
  }

  Future<void> _moveCameraToPosition(LatLng position) async {
    if (!isCameraMoved) {
      final GoogleMapController controller = await _mapController.future;
      final CameraPosition newPosition = CameraPosition(
        target: position,
        zoom: 13,
      );
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(newPosition),
      );
      setState(() {
        isCameraMoved = true;
      });
    }
  }

  Future<void> _checkLocationPermissions() async {
    bool serviceEnabled = await _locationController.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _locationController.requestService();
      if (!serviceEnabled) {
        debugPrint("Location services disabled.");
        return;
      }
    }

    PermissionStatus permissionGranted = await _locationController.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _locationController.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        debugPrint("Location permissions denied.");
        return;
      }
    }

    _locationController.onLocationChanged.listen((LocationData currentLocation) {
      if (currentLocation.latitude != null && currentLocation.longitude != null) {
        final position = LatLng(currentLocation.latitude!, currentLocation.longitude!);
        setState(() {
          _currentPosition = position;
        });
        _moveCameraToPosition(position);
      }
    });
  }

  Future<List<LatLng>> _getPolylinePoints() async {
    final List<LatLng> polylineCoordinates = [];
    final PolylinePoints polylinePoints = PolylinePoints();

    try {
      final PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: GOOGLE_MAPS_API_KEY,
        request: PolylineRequest(
          origin: PointLatLng(dhaka.latitude, dhaka.longitude),
          destination: PointLatLng(sirajganj.latitude, sirajganj.longitude),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isNotEmpty) {
        for (var point in result.points) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        }
      } else {
        debugPrint('Error retrieving polyline: ${result.errorMessage}');
      }
    } catch (e) {
      debugPrint('Error in fetching polyline: $e');
    }

    return polylineCoordinates;
  }

  void _generatePolylineFromPoints(List<LatLng> polylineCoordinates) {
    final PolylineId id = PolylineId("polyline");
    final Polyline polyline = Polyline(
      polylineId: id,
      color: Colors.blue,
      points: polylineCoordinates,
      width: 5,
    );

    setState(() {
      polylines[id] = polyline;
    });
  }
}

// Updated code and using Google Map API
