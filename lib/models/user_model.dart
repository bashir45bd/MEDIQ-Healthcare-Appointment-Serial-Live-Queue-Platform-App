class UserModel {
  final int id;
  final String role; // 'PATIENT', 'DOCTOR', 'PLATFORM_ADMIN'
  final String fullName;
  final String? email;
  final String phone;
  final String? profilePhoto;
  final int? doctorId;
  final int? patientId;
  final String? verificationStatus;

  UserModel({
    required this.id,
    required this.role,
    required this.fullName,
    this.email,
    required this.phone,
    this.profilePhoto,
    this.doctorId,
    this.patientId,
    this.verificationStatus,
  });

  static int? _parseInt(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    return int.tryParse(val.toString());
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    int? docId;
    String? vStatus;
    if (json['doctor'] != null && json['doctor'] is Map) {
      docId = _parseInt(json['doctor']['id']);
      vStatus = json['doctor']['verification_status']?.toString();
    } else if (json['doctor_id'] != null) {
      docId = _parseInt(json['doctor_id']);
      vStatus = json['verification_status']?.toString();
    }

    int? patId;
    if (json['patient'] != null && json['patient'] is Map) {
      patId = _parseInt(json['patient']['id']);
    } else if (json['patient_id'] != null) {
      patId = _parseInt(json['patient_id']);
    }

    return UserModel(
      id: _parseInt(json['id']) ?? 0,
      role: json['role']?.toString() ?? 'PATIENT',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString(),
      phone: json['phone']?.toString() ?? '',
      profilePhoto: json['profile_photo']?.toString(),
      doctorId: docId,
      patientId: patId,
      verificationStatus: vStatus,
    );
  }

  UserModel copyWith({
    int? id,
    String? role,
    String? fullName,
    String? email,
    String? phone,
    String? profilePhoto,
    int? doctorId,
    int? patientId,
    String? verificationStatus,
  }) {
    return UserModel(
      id: id ?? this.id,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      doctorId: doctorId ?? this.doctorId,
      patientId: patientId ?? this.patientId,
      verificationStatus: verificationStatus ?? this.verificationStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'profile_photo': profilePhoto,
      'doctor_id': doctorId,
      'patient_id': patientId,
      'verification_status': verificationStatus,
    };
  }

  bool get isDoctor => role == 'DOCTOR';
  bool get isPatient => role == 'PATIENT';
}
