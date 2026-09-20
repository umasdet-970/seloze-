import 'dart:math';

/// Great-circle distance between two lat/lng points, in kilometers
/// (spec section 4/15: real geo-distance in Discover). Standard
/// haversine formula — accurate enough for "how far away is this
/// person" at the precision a dating app needs; no need for a more
/// exact ellipsoidal (Vincenty) calculation here.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  final dLat = _degToRad(lat2 - lat1);
  final dLng = _degToRad(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_degToRad(lat1)) * cos(_degToRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusKm * c;
}

double _degToRad(double deg) => deg * pi / 180;

/// Display text for a profile's distance, or null when the distance isn't
/// known. `Profile.distanceKm` is 0 when either person has no saved
/// location (see FirestoreProfileRepository) — showing that as "0.0 km"
/// told viewers the person was standing next to them.
String? formatDistanceKm(double km) {
  if (km <= 0) return null;
  if (km < 1) return '<1 km';
  return '${km.round()} km';
}
