// lib/screens/nearby_screen_gplaces.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
// Option 1: If secrets.dart is in lib/config/
// import '../config/secrets.dart'; 
// Option 2: If secrets.dart is directly in lib/
import '../secrets.dart'; // Make sure this path is correct

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
      name: json['displayName']?['text'] ?? 'N/A', 
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
  // UI Display Name to Places API (New) type mapping
  final Map<String, List<String>> _typeMapping = {
    'Hospitals': ['hospital'],
    'Pharmacies': ['pharmacy'],
    // Corrected: Use a single, valid primary type for searching labs.
    // 'medical_laboratory' is a supported type for Nearby Search (New).
    'Labs': ['medical_laboratory'], 
  };
  final List<String> _displayTypes = ['Hospitals', 'Pharmacies', 'Labs'];
  String _selectedDisplayType = 'Hospitals'; 
  
  List<NearbyPlaceG> _places = [];
  bool _isLoading = false;
  String? _loadingError;
  Position? _currentUserLocation;

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
          _isLoading = false;
        });
      }
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
        });
      }
      _fetchDataForSelectedType(); 
    } catch (e) {
      debugPrint("Error getting location: $e");
      if (mounted) {
        setState(() {
          _loadingError = "Could not get current location.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchDataForSelectedType() async {
    if (_currentUserLocation == null) {
      if (mounted) {
        setState(() {
          _loadingError = _loadingError ?? "Current location not available to search nearby places.";
          _isLoading = false;
          _places = [];
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
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadingError = (_loadingError != null && _loadingError!.contains("location")) ? _loadingError : null;
      });
    }

    final List<String>? apiTypes = _typeMapping[_selectedDisplayType];
    if (apiTypes == null) {
      if(mounted) {
        setState(() {
          _loadingError = "Invalid category selected.";
          _isLoading = false;
        });
      }
      return;
    }

    const String url = 'https://places.googleapis.com/v1/places:searchNearby';
    final headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': googleMapsApiKey,
      'X-Goog-FieldMask': 'places.id,places.displayName,places.formattedAddress,places.location,places.types',
    };
    final body = json.encode({
      "includedTypes": apiTypes, // This will now be e.g., ["medical_laboratory"] for Labs
      "maxResultCount": 15, 
      "locationRestriction": {
        "circle": {
          "center": {
            "latitude": _currentUserLocation!.latitude,
            "longitude": _currentUserLocation!.longitude,
          },
          "radius": 5000.0 
        }
      },
    });
    
    debugPrint("Places API (New) URL: $url");
    debugPrint("Places API (New) Headers: $headers");
    debugPrint("Places API (New) Body: $body");

    try {
      final response = await http.post(Uri.parse(url), headers: headers, body: body);
      
      debugPrint("Places API (New) Response Status: ${response.statusCode}");
      debugPrint("Places API (New) Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> results = data['places'] ?? []; 
        List<NearbyPlaceG> fetchedPlaces = results
            .map((placeJson) => NearbyPlaceG.fromJson(placeJson, userLocation: _currentUserLocation))
            .toList();

        fetchedPlaces.sort((a, b) {
          if (a.distanceInKm == null && b.distanceInKm == null) return 0;
          if (a.distanceInKm == null) return 1;
          if (b.distanceInKm == null) return -1;
          return a.distanceInKm!.compareTo(b.distanceInKm!);
        });
          
        if (mounted) {
          setState(() {
            _places = fetchedPlaces;
            _isLoading = false;
          });
        }
      } else {
        final errorData = json.decode(response.body);
        // Try to get a more specific error message from the API response
        final apiErrorMessage = errorData['error']?['message'] ?? 'Failed to load places from API.';
        debugPrint("Google Places API Error Response: ${errorData['error']}");
        throw Exception(apiErrorMessage);
      }
    } catch (e) {
      debugPrint("Error fetching places from Google API (New): $e");
      if (mounted) {
        setState(() {
          _loadingError = "Failed to load places. ${e.toString()}";
          _isLoading = false;
          _places = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby', style: TextStyle(color: Color(0xFF00695C))),
        backgroundColor: Colors.white,
        elevation: 1.0,
        iconTheme: const IconThemeData(color: Color(0xFF00695C)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedDisplayType, 
                  icon: Icon(Icons.arrow_drop_down, color: Colors.grey[700]),
                  elevation: 16,
                  style: TextStyle(color: Colors.grey[800], fontSize: 16),
                  onChanged: (String? newValue) { 
                    if (newValue != null) {
                      setState(() {
                        _selectedDisplayType = newValue; 
                        _places = []; 
                      });
                      if (_currentUserLocation != null) { 
                        _fetchDataForSelectedType();
                      } else {
                         _determinePositionAndFetchData();
                      }
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sort By', 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[700]),
                ),
                IconButton(
                  icon: Icon(Icons.sort, color: Colors.grey[700]),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Currently sorted by distance (if location available).')),
                    );
                  },
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080)))),
            )
          else if (_loadingError != null)
             Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_loadingError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 16)),
                )
              ),
            )
          else if (_places.isEmpty)
            const Expanded(
              child: Center(
                child: Text('No places found nearby.', style: TextStyle(fontSize: 16, color: Colors.grey)),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _places.length,
                itemBuilder: (context, index) {
                  final place = _places[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    child: ListTile(
                      title: Text(place.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(place.formattedAddress ?? 'Address not available'),
                          if (place.distanceInKm != null) 
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                '${place.distanceInKm!.toStringAsFixed(1)} km away',
                                style: TextStyle(fontSize: 12, color: Theme.of(context).primaryColor),
                              ),
                            ),
                        ],
                      ),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Tapped on ${place.name} (ID: ${place.placeId})')),
                        );
                        // TODO: Implement navigation to a detail screen using place.placeId for Place Details API (New)
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
