class AppointmentModel {
  final int id;
  final String appointmentNumber;
  final String tokenDisplay;
  final int tokenNumber;
  final String appointmentDate;
  final String status;
  final String patientType;
  final double totalPaid;
  final String paymentStatus;
  final String? doctorName;
  final String? chamberName;
  final String? patientName;
  final String? estimatedConsultationTime;
  final String? expectedArrivalTime;
  final String? arrivalNote;

  AppointmentModel({
    required this.id,
    required this.appointmentNumber,
    required this.tokenDisplay,
    required this.tokenNumber,
    required this.appointmentDate,
    required this.status,
    required this.patientType,
    required this.totalPaid,
    required this.paymentStatus,
    this.doctorName,
    this.chamberName,
    this.patientName,
    this.estimatedConsultationTime,
    this.expectedArrivalTime,
    this.arrivalNote,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      appointmentNumber: json['appointment_number'] ?? '',
      tokenDisplay: json['token_display'] ?? '',
      tokenNumber: json['token_number'] is int ? json['token_number'] : int.parse(json['token_number'].toString()),
      appointmentDate: json['appointment_date'] ?? '',
      status: json['status'] ?? 'BOOKED',
      patientType: json['patient_type'] ?? 'NEW',
      totalPaid: double.tryParse(json['total_paid'].toString()) ?? 0.0,
      paymentStatus: json['payment_status'] ?? 'PENDING',
      doctorName: json['doctor_name'],
      chamberName: json['chamber_name'],
      patientName: json['patient_name'],
      estimatedConsultationTime: json['estimated_consultation_time'],
      expectedArrivalTime: json['expected_arrival_time'],
      arrivalNote: json['arrival_note'],
    );
  }
}

