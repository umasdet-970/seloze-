import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/utils/geo_distance.dart';

/// Captures the device's approximate location and stores it on
/// `users/{uid}` as `{lat, lng}` — real geo-distance in Discover (spec
/// section 4/15), replacing the old distanceKm=0 placeholder (see
/// FirestoreProfileRepository). Every failure mode here is handled by
/// simply not writing a location, never by throwing — this is an
/// enhancement to profile completion, not a requirement of it, so a
/// denied permission or disabled location service must never block
/// onboarding.
class LocationService {
  LocationService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Whether a location is currently saved for [uid] — used to pre-tick the
  /// "Use my approximate location" box when someone edits their profile.
  Future<bool> hasSavedLocation(String uid) async {
    if (uid.isEmpty) return false;
    try {
      final data = (await _firestore.collection('users').doc(uid).get()).data();
      return data?['lat'] != null && data?['lng'] != null;
    } catch (_) {
      return false;
    }
  }

  /// Removes the saved location, for when someone switches "Use my
  /// approximate location" off. Never throws.
  Future<void> clearSavedLocation(String uid) async {
    if (uid.isEmpty) return;
    try {
      await _firestore.collection('users').doc(uid).update({
        'lat': FieldValue.delete(),
        'lng': FieldValue.delete(),
      });
    } catch (_) {}
  }

  /// Returns true if a location was captured and saved, false if not
  /// (permission denied, location services off, or any other failure) —
  /// callers can use this for optional UI feedback but must not treat
  /// `false` as an error.
  Future<bool> captureAndSaveLocation(String uid) async {
    if (uid.isEmpty) return false;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        // deniedForever specifically means the OS won't show the
        // permission prompt again — the user would have to grant it from
        // system settings. Nothing to do here but accept "no location".
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          // Coarse precision is all this app asks the OS permission for
          // (ACCESS_COARSE_LOCATION on Android — see AndroidManifest.xml)
          // and all a "how many km away" display needs.
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );

      await _firestore.collection('users').doc(uid).set({
        // Rounded to ~1 km before storing (see roundCoordinate).
        'lat': roundCoordinate(position.latitude),
        'lng': roundCoordinate(position.longitude),
      }, SetOptions(merge: true));
      return true;
    } catch (_) {
      // Timeout, platform exception, Firestore write failure — all
      // equally "couldn't get a location this time", not fatal to
      // anything else the caller is doing.
      return false;
    }
  }
}
