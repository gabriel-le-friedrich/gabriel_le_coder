// ══════════════════════════════════════════════════════════════════════
// Pig model — Flutter port of the pig object shape used throughout
// index.html (getPigs()/setPigs()/savePig()). Stored locally as the
// `pigs` SQLite table's JSON `data` blob (see SqliteService), and mirrored
// to Supabase's `pigs` table (see supabase_schema.sql).
// ══════════════════════════════════════════════════════════════════════

class Pig {
  const Pig({
    required this.id,
    required this.name,
    this.gender = 'Male',
    this.breed = '',
    this.birthDate = '',
    required this.arrivalDate,
    required this.initialWeight,
    this.penNumber = '',
    this.notes = '',
    this.photoLocalPath,
    this.photoRemoteUrl,
    required this.createdAt,
  });

  final String
      id; // read-only after creation — see PigRepository.nextAvailablePigId()
  final String name;
  final String gender;
  final String breed;
  final String birthDate; // yyyy-MM-dd or ''
  final String arrivalDate; // yyyy-MM-dd
  final double
      initialWeight; // "Starting Weight" — editable only via the explicit Edit Starting Weight action
  final String penNumber;
  final String notes;
  final String? photoLocalPath;
  final String? photoRemoteUrl;
  final String createdAt; // ISO 8601

  Pig copyWith({
    String? name,
    String? gender,
    String? breed,
    String? birthDate,
    String? arrivalDate,
    double? initialWeight,
    String? penNumber,
    String? notes,
    String? photoLocalPath,
    String? photoRemoteUrl,
  }) {
    return Pig(
      id: id,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      breed: breed ?? this.breed,
      birthDate: birthDate ?? this.birthDate,
      arrivalDate: arrivalDate ?? this.arrivalDate,
      initialWeight: initialWeight ?? this.initialWeight,
      penNumber: penNumber ?? this.penNumber,
      notes: notes ?? this.notes,
      photoLocalPath: photoLocalPath ?? this.photoLocalPath,
      photoRemoteUrl: photoRemoteUrl ?? this.photoRemoteUrl,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'gender': gender,
        'breed': breed,
        'birthDate': birthDate,
        'arrivalDate': arrivalDate,
        'initialWeight': initialWeight,
        'penNumber': penNumber,
        'notes': notes,
        'photoLocalPath': photoLocalPath,
        'photoRemoteUrl': photoRemoteUrl,
        'createdAt': createdAt,
      };

  factory Pig.fromJson(Map<String, dynamic> json) => Pig(
        id: (json['id'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        gender: (json['gender'] as String?) ?? 'Male',
        breed: (json['breed'] as String?) ?? '',
        birthDate: (json['birthDate'] as String?) ?? '',
        arrivalDate: (json['arrivalDate'] as String?) ?? '',
        initialWeight: (json['initialWeight'] as num?)?.toDouble() ?? 0,
        penNumber: (json['penNumber'] as String?) ?? '',
        notes: (json['notes'] as String?) ?? '',
        photoLocalPath: json['photoLocalPath'] as String?,
        photoRemoteUrl: json['photoRemoteUrl'] as String?,
        createdAt:
            (json['createdAt'] as String?) ?? DateTime.now().toIso8601String(),
      );
}
