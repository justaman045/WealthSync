// Stub for geocoding on web
class Placemark {
  final String? street;
  final String? subLocality;
  final String? locality;
  final String? administrativeArea;
  final String? subAdministrativeArea;
  final String? postalCode;
  final String? country;
  Placemark({
    this.street,
    this.subLocality,
    this.locality,
    this.administrativeArea,
    this.subAdministrativeArea,
    this.postalCode,
    this.country,
  });
}

Future<List<Placemark>> placemarkFromCoordinates(double latitude, double longitude) async => [];
