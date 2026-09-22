class QueueLiveModel {
  final int appointmentId;
  final String doctorName;
  final String chamberName;
  final String chamberAddress;
  final String? chamberStartTime;
  final String appointmentDate;
  final String appointmentDateFormatted;
  final String dayNameEn;
  final String dayNameBn;
  final bool isToday;
  final bool isFuture;
  final String yourToken;
  final String currentToken;
  final bool isDoctorConsulting;
  final bool isBreak;
  final int patientsAhead;
  final int completedCount;
  final int doctorDelayMinutes;
  final String doctorStatus;
  final String? presenceStatus;
  final bool isBookingOpen;
  final String estimatedWait;
  final String recommendedArrival;
  final String status;
  final String? statusNote;
  final Map<String, dynamic>? ongoingPatient;
  final Map<String, dynamic>? nextPatient;
  final bool isYouOngoing;
  final bool isYouNext;
  final List<Map<String, dynamic>> queueRoster;
  final String lastUpdated;

  QueueLiveModel({
    required this.appointmentId,
    this.doctorName = 'Doctor',
    this.chamberName = 'Chamber',
    this.chamberAddress = '',
    this.chamberStartTime,
    this.appointmentDate = '',
    this.appointmentDateFormatted = '',
    this.dayNameEn = '',
    this.dayNameBn = '',
    this.isToday = true,
    this.isFuture = false,
    required this.yourToken,
    required this.currentToken,
    this.isDoctorConsulting = false,
    this.isBreak = false,
    required this.patientsAhead,
    required this.completedCount,
    required this.doctorDelayMinutes,
    required this.doctorStatus,
    this.presenceStatus,
    this.isBookingOpen = true,
    required this.estimatedWait,
    required this.recommendedArrival,
    required this.status,
    this.statusNote,
    this.ongoingPatient,
    this.nextPatient,
    this.isYouOngoing = false,
    this.isYouNext = false,
    this.queueRoster = const [],
    required this.lastUpdated,
  });

  factory QueueLiveModel.fromJson(Map<String, dynamic> json) {
    return QueueLiveModel(
      appointmentId: int.tryParse(json['appointment_id']?.toString() ?? '') ?? 0,
      doctorName: json['doctor_name']?.toString() ?? 'Doctor',
      chamberName: json['chamber_name']?.toString() ?? 'Chamber',
      chamberAddress: json['chamber_address']?.toString() ?? '',
      chamberStartTime: json['chamber_start_time']?.toString(),
      appointmentDate: json['appointment_date']?.toString() ?? '',
      appointmentDateFormatted: json['appointment_date_formatted']?.toString() ?? '',
      dayNameEn: json['day_name_en']?.toString() ?? '',
      dayNameBn: json['day_name_bn']?.toString() ?? '',
      isToday: json['is_today'] == true || json['is_today'] == 1,
      isFuture: json['is_future'] == true || json['is_future'] == 1,
      yourToken: json['your_token']?.toString() ?? '--',
      currentToken: json['current_token']?.toString() ?? 'None',
      isDoctorConsulting: json['is_doctor_consulting'] == true || json['is_doctor_consulting'] == 1,
      isBreak: json['is_break'] == true || json['is_break'] == 1,
      patientsAhead: int.tryParse(json['patients_ahead']?.toString() ?? '') ?? 0,
      completedCount: int.tryParse(json['completed_count']?.toString() ?? '') ?? 0,
      doctorDelayMinutes: int.tryParse(json['doctor_delay_minutes']?.toString() ?? '') ?? 0,
      doctorStatus: json['doctor_status']?.toString() ?? 'AVAILABLE',
      presenceStatus: json['presence_status']?.toString(),
      isBookingOpen: json['is_booking_open'] == null ? true : (json['is_booking_open'] == 1 || json['is_booking_open'] == true || json['is_booking_open'] == '1'),
      estimatedWait: json['estimated_wait']?.toString() ?? 'Calculating...',
      recommendedArrival: json['recommended_arrival']?.toString() ?? 'Calculating...',
      status: json['status']?.toString() ?? 'BOOKED',
      statusNote: json['status_note']?.toString(),
      ongoingPatient: json['ongoing_patient'] is Map<String, dynamic>
          ? json['ongoing_patient']
          : (json['ongoing_patient'] is Map ? Map<String, dynamic>.from(json['ongoing_patient']) : null),
      nextPatient: json['next_patient'] is Map<String, dynamic>
          ? json['next_patient']
          : (json['next_patient'] is Map ? Map<String, dynamic>.from(json['next_patient']) : null),
      isYouOngoing: json['is_you_ongoing'] == true || json['is_you_ongoing'] == 1,
      isYouNext: json['is_you_next'] == true || json['is_you_next'] == 1,
      queueRoster: (json['queue_roster'] is List)
          ? (json['queue_roster'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : [],
      lastUpdated: json['last_updated']?.toString() ?? '',
    );
  }
}
