// lib/screens/nearby_screen_gplaces.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../secrets.dart'; // Ensure this path is correct (e.g., lib/secrets.dart or lib/config/secrets.dart)
import 'package:url_launcher/url_launcher.dart';
// Model for Places API (New)
class NearbyPlaceG {
  final String placeId;
  final String name;
  final String? formattedAddress; 
  final double latitude;
  final double longitude;
  final List<String>? types; 
  double? distanceInKm;

  NearbyPlaceG({
    required this.placeId,
    required this.name,
    this.formattedAddress,
    required this.latitude,
    required this.longitude,
    this.types,
    this.distanceInKm,
  });

  factory NearbyPlaceG.fromJson(Map<String, dynamic> json, {Position? userLocation}) {
    final loc = json['location'] ?? {'latitude': 0.0, 'longitude': 0.0};
    double lat = (loc['latitude'] as num?)?.toDouble() ?? 0.0;
    double lng = (loc['longitude'] as num?)?.toDouble() ?? 0.0;
    double? distance;

    if (userLocation != null) {
      distance = Geolocator.distanceBetween(
        userLocation.latitude,
        userLocation.longitude,
        lat,
        lng,
      ) / 1000; // Convert to km
    }

    return NearbyPlaceG(
      placeId: json['id'] ?? 'N/A', 
      name: json['displayName']?['text'] ?? json['name'] ?? 'N/A', 
      formattedAddress: json['formattedAddress'],
      latitude: lat,
      longitude: lng,
      types: (json['types'] as List<dynamic>?)?.map((type) => type.toString()).toList(),
      distanceInKm: distance,
    );
  }
}

class NearbyScreenWithGooglePlaces extends StatefulWidget {
  const NearbyScreenWithGooglePlaces({super.key});

  @override
  State<NearbyScreenWithGooglePlaces> createState() =>
      _NearbyScreenWithGooglePlacesState();
}

class _NearbyScreenWithGooglePlacesState
    extends State<NearbyScreenWithGooglePlaces> {
  
  final Map<String, List<String>> _typeMapping = {
    'Hospitals': ['hospital'],
    'Pharmacies': ['pharmacy'],
    'Labs': ['medical_laboratory'], 
  };
  final List<String> _displayTypes = ['Hospitals', 'Pharmacies', 'Labs'];
  String _selectedDisplayType = 'Hospitals'; 
  
  List<NearbyPlaceG> _places = [];
  bool _isLoading = false;
  String? _loadingError;
  Position? _currentUserLocation;

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  static const LatLng _defaultInitialPosition = LatLng(28.6139, 77.2090); // Default to Delhi if location fails

  @override
  void initState() {
    super.initState();
    _determinePositionAndFetchData();
  }

  Future<void> _determinePositionAndFetchData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadingError = null;
      });
    }

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _loadingError = 'Location services are disabled. Please enable them.';
          _isLoading = false; // Stop loading indicator
        });
      }
      _fetchDataForSelectedType(useDefaultLocation: true); // Attempt fetch with default location
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _loadingError = 'Location permissions are denied.';
            _isLoading = false;
          });
        }
         _fetchDataForSelectedType(useDefaultLocation: true);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _loadingError =
              'Location permissions are permanently denied, we cannot request permissions.';
          _isLoading = false;
        });
      }
      _fetchDataForSelectedType(useDefaultLocation: true);
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() {
          _currentUserLocation = position;
          _loadingError = null; // Clear previous location errors if successful
        });
        _animateMapToPosition(position); 
      }
      _fetchDataForSelectedType(); 
    } catch (e) {
      debugPrint("Error getting location: $e");
      if (mounted) {
        setState(() {
          _loadingError = "Could not get current location. Showing results for a default area.";
          _currentUserLocation = null; 
          _isLoading = false; // Stop loading if location fails before fetching data
        });
      }
      _fetchDataForSelectedType(useDefaultLocation: true);
    }
  }

  Future<void> _fetchDataForSelectedType({bool useDefaultLocation = false}) async {
    Position? searchLocation = _currentUserLocation;
    if (useDefaultLocation && _currentUserLocation == null) {
        searchLocation = Position(
            latitude: _defaultInitialPosition.latitude, 
            longitude: _defaultInitialPosition.longitude, 
            timestamp: DateTime.now(), 
            accuracy: 0, altitude: 0, altitudeAccuracy: 0, heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0
        );
        debugPrint("Using default location for search: $searchLocation");
        if(mounted && _mapController != null) { // Animate map to default if controller is ready
          _animateMapToPosition(searchLocation);
        }
    }

    if (searchLocation == null) {
      if (mounted) {
        setState(() {
          _loadingError = _loadingError ?? "Current location not available to search nearby places.";
          _isLoading = false;
          _places = [];
          _markers = {};
        });
      }
      return;
    }

    if (googleMapsApiKey == "YOUR_ACTUAL_GOOGLE_MAPS_API_KEY_HERE" || googleMapsApiKey.isEmpty) {
       if (mounted) {
        setState(() {
          _loadingError = "API Key not configured in secrets.dart or is invalid.";
          _isLoading = false;
          _places = [];
          _markers = {};
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        // Preserve location error if it occurred, otherwise clear API specific error
        _loadingError = (_loadingError != null && (_loadingError!.contains("location") || _loadingError!.contains("Location"))) ? _loadingError : null;
        _places = []; 
        _markers = {}; 
      });
    }
    // Add user's location marker (or default search location marker)
    _addUserMarker(searchLocation);


    final List<String>? apiTypes = _typeMapping[_selectedDisplayType];
    if (apiTypes == null) {
      if(mounted) {
        setState(() {
          _loadingError = "Invalid category selected in mapping.";
          _isLoading = false;
        });
      }
      return;
    }
    
    debugPrint("NearbyScreen: Fetching data for display type: $_selectedDisplayType, API types: $apiTypes");

    const String url = 'https://places.googleapis.com/v1/places:searchText';
    final headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': googleMapsApiKey,
      'X-Goog-FieldMask': 'places.id,places.displayName,places.formattedAddress,places.location,places.types',
    };
    final body = json.encode({
      "textQuery": "$_selectedDisplayType near current location", // More natural query
      "maxResultCount": 15, 
      "locationBias": { 
        "circle": {
          "center": {
            "latitude": searchLocation.latitude,
            "longitude": searchLocation.longitude,
          },
          "radius": 5000.0 
        }
      },
    });
    
    try {
      final response = await http.post(Uri.parse(url), headers: headers, body: body);
      
      debugPrint("Places API (New) Text Search Response Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> results = data['places'] ?? []; 
        List<NearbyPlaceG> fetchedPlaces = results
            .map((placeJson) => NearbyPlaceG.fromJson(placeJson, userLocation: _currentUserLocation)) // Calculate distance from actual user location
            .toList();

        fetchedPlaces.sort((a, b) {
          if (a.distanceInKm == null && b.distanceInKm == null) return 0;
          if (a.distanceInKm == null) return 1;
          if (b.distanceInKm == null) return -1;
          return a.distanceInKm!.compareTo(b.distanceInKm!);
        });
        
        Set<Marker> newMarkers = {};
        // Re-add user marker because _markers was cleared
        if (_currentUserLocation != null) { 
            newMarkers.add(
                Marker(
                    markerId: const MarkerId('user_location'),
                    position: LatLng(_currentUserLocation!.latitude, _currentUserLocation!.longitude),
                    infoWindow: const InfoWindow(title: 'Your Location'),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                )
            );
        } else if (useDefaultLocation) { // If using default, mark the search center
             newMarkers.add(
                Marker(
                    markerId: const MarkerId('search_center_location'),
                    position: LatLng(searchLocation.latitude, searchLocation.longitude),
                    infoWindow: const InfoWindow(title: 'Search Area Center'),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                )
            );
        }


        for (var place in fetchedPlaces) {
          newMarkers.add(
            Marker(
              markerId: MarkerId(place.placeId),
              position: LatLng(place.latitude, place.longitude),
              infoWindow: InfoWindow(
                title: place.name,
                snippet: place.formattedAddress ?? '',
              ),
            ),
          );
        }
          
        if (mounted) {
          setState(() {
            _places = fetchedPlaces;
            _markers = newMarkers;
            _isLoading = false;
          });
        }
      } else {
        final errorData = json.decode(response.body);
        final apiError = errorData['error'];
        String errorMessage = 'Failed to load places from API.';
        if (apiError is Map && apiError.containsKey('message')) {
            errorMessage = "Google Places API Error: ${apiError['message']}";
        }
        debugPrint(errorMessage); 
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint("Error fetching places from Google API (New Text Search): $e");
      if (mounted) {
        setState(() {
          _loadingError = "Failed to load places. ${e.toString().replaceFirst("Exception: ", "")}"; 
          _isLoading = false;
          _places = [];
          _markers = {}; // Clear markers on error too
           if (searchLocation != null) _addUserMarker(searchLocation, isSearchCenter: useDefaultLocation && _currentUserLocation == null);
        });
      }
    }
  }

  void onMapCreated(GoogleMapController controller) {
    _mapController = controller;
     if (_currentUserLocation != null) {
      _animateMapToPosition(_currentUserLocation!);
    } else if (mounted) { 
        _animateMapToPosition(Position(
            latitude: _defaultInitialPosition.latitude, longitude: _defaultInitialPosition.longitude, 
            timestamp: DateTime.now(), accuracy: 0, altitude: 0, altitudeAccuracy: 0, 
            heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0));
    }
  }

  void _animateMapToPosition(Position position) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 14.0, 
        ),
      ),
    );
  }

   void _addUserMarker(Position position, {bool isSearchCenter = false}) {
    if (!mounted) return;
    final markerId = isSearchCenter ? 'search_center_location' : 'user_location';
    final title = isSearchCenter ? 'Search Area Center' : 'Your Location';
    final hue = isSearchCenter ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueAzure;

    final userMarker = Marker(
        markerId: MarkerId(markerId),
        position: LatLng(position.latitude, position.longitude),
        infoWindow: InfoWindow(title: title),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
    );
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == markerId); 
      _markers.add(userMarker);
    });
  }

  void _onPlaceListItemTapped(NearbyPlaceG place) {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(place.latitude, place.longitude),
            zoom: 15.0, 
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 40, 20, 10),
            child: Text(
              'Nearby',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Color(0xFF008080),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedDisplayType,
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedDisplayType = newValue;
                        _places = [];
                        _markers = {};
                      });
                      _fetchDataForSelectedType(useDefaultLocation: _currentUserLocation == null);
                    }
                  },
                  items: _displayTypes.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sort By',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.sort, color: Colors.black54),
                  onPressed: () {
                    // Sort functionality remains the same
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080)),
                    ),
                  )
                : _loadingError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _loadingError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _places.length,
                        itemBuilder: (context, index) {
                          final place = _places[index];
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                color: Color(0xFFE0E0E0),
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          place.name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.directions,
                                              color: Color(0xFF008080),
                                            ),
                                            onPressed: () {
                                              _launchMapsDirections(place);
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.phone,
                                              color: Color(0xFF008080),
                                            ),
                                            onPressed: () {
                                              _makePhoneCall(place.placeId);
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    place.formattedAddress ?? 'Address not available',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  if (place.distanceInKm != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        '${place.distanceInKm!.toStringAsFixed(1)} km away',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF008080),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchMapsDirections(NearbyPlaceG place) async {
    final String query = Uri.encodeComponent('${place.name}, ${place.formattedAddress ?? ''}');
    final String mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$query';

    try {
      final Uri url = Uri.parse(mapsUrl);
      if (!await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication)) {
        // If external app launch fails, try browser
        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open maps')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error opening maps')),
        );
      }
    }
  }

  Future<void> _makePhoneCall(String placeId) async {
    try {
      final String url = 'https://places.googleapis.com/v1/places/$placeId';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'X-Goog-Api-Key': googleMapsApiKey,
          'X-Goog-FieldMask': 'id,displayName,internationalPhoneNumber',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String? phoneNumber = data['internationalPhoneNumber'];
        
        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          final cleanPhoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
          final phoneUri = Uri.parse('tel:$cleanPhoneNumber');
          
          if (await canLaunchUrl(phoneUri)) {
            await launchUrl(phoneUri);
          } else {
            _showCustomSnackBar(
              'Could not launch phone app',
              icon: Icons.error_outline,
            );
          }
        } else {
          _showCustomSnackBar(
            'No phone number available for this facility',
            icon: Icons.info_outline,
            duration: const Duration(seconds: 3),
          );
        }
      } else {
        _showCustomSnackBar(
          'Could not fetch contact information',
          icon: Icons.error_outline,
        );
      }
    } catch (e) {
      _showCustomSnackBar(
        'Error accessing contact information',
        icon: Icons.error_outline,
      );
    }
  }

  void _showCustomSnackBar(
    String message, {
    IconData icon = Icons.info_outline,
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        duration: duration,
        backgroundColor: const Color(0xFF008080),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(8),
      ),
    );
  }
}
