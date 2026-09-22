class DoctorModel {
  final int id;
  final String doctorName;
  final String bmdcNumber;
  final String designation;
  final int experienceYears;
  final double consultationFee;
  final double followUpFee;
  final String? bio;
  final double ratingAvg;
  final int ratingCount;
  final String specialties;
  final String? profilePhoto;
  final List<dynamic> chambers;

  DoctorModel({
    required this.id,
    required this.doctorName,
    required this.bmdcNumber,
    required this.designation,
    required this.experienceYears,
    required this.consultationFee,
    required this.followUpFee,
    this.bio,
    required this.ratingAvg,
    required this.ratingCount,
    required this.specialties,
    this.profilePhoto,
    required this.chambers,
  });

  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    return DoctorModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      doctorName: json['doctor_name']?.toString() ?? '',
      bmdcNumber: json['bmdc_number']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      experienceYears: int.tryParse(json['experience_years']?.toString() ?? '') ?? 0,
      consultationFee: double.tryParse(json['consultation_fee']?.toString() ?? '') ?? 0.0,
      followUpFee: double.tryParse(json['follow_up_fee']?.toString() ?? '') ?? 0.0,
      bio: json['bio']?.toString(),
      ratingAvg: double.tryParse(json['rating_avg']?.toString() ?? '') ?? 0.0,
      ratingCount: int.tryParse(json['rating_count']?.toString() ?? '') ?? 0,
      specialties: json['specialties']?.toString() ?? 'General',
      profilePhoto: json['profile_photo']?.toString(),
      chambers: json['chambers'] is List ? json['chambers'] : [],
    );
  }
}
