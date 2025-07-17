class SessionModel {
  final String id;
  final String origin;
  final String destination;
  final String? destinationName;
  final String status;
  final double? distance;
  final String? duration;
  final String? createdAt;

  SessionModel({
    required this.id,
    required this.origin,
    required this.destination,
    this.destinationName,
    required this.status,
    this.distance,
    this.duration,
    this.createdAt,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'] ?? '',
      origin: json['origin'] ?? '',
      destination: json['destination'] ?? '',
      destinationName: json['destinationName'],
      status: json['status'] ?? '',
      distance: json['distance'] != null
          ? (json['distance'] as num).toDouble()
          : null,
      duration: json['duration'],
      createdAt: json['createdAt'],
    );
  }
}
