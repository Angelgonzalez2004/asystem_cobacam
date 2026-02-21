import 'package:firebase_database/firebase_database.dart';
import 'package:hive/hive.dart';

part 'student_model.g.dart';

@HiveType(typeId: 0) // Unique typeId
class Student {
  @HiveField(0)
  String id; // Firebase key
  @HiveField(1)
  String fullName;
  @HiveField(2)
  String guardianFullName;
  @HiveField(3)
  int age;
  @HiveField(4)
  String guardianPhone;
  @HiveField(5)
  String? studentPhone; // Optional
  @HiveField(6)
  String gender; // Masculino/Femenino
  @HiveField(7)
  String placeOfResidence;
  @HiveField(8)
  String schoolCycle;
  @HiveField(9)
  String group;
  @HiveField(10)
  String institutionalEmail;
  @HiveField(11)
  String studentId; // Matricula
  @HiveField(12)
  bool isActive; // For soft delete, default to true
  @HiveField(13)
  String? deactivationReason; // New field for reason of deactivation
  @HiveField(14)
  String? allergies; // Medicamentos, comida, etc.
  @HiveField(15)
  String? healthConditions; // Visión, motricidad, etc.
  @HiveField(16)
  String? generalHealthStatus; // "Sano" por defecto
  @HiveField(17)
  String? nss; // Numero de Seguro Social
  @HiveField(18)
  bool medicalAlert; // Gatillo manual para alertas graves
  @HiveField(19)
  bool canEditProfile; // NEW FIELD: Allows student to edit their profile
  @HiveField(20)
  String userId; // Firebase User UID
  @HiveField(21)
  String registeredByUserId; // User ID of the prefect who registered the student
  @HiveField(22)
  String? profileImageUrl; // NEW

  Student({
    required this.id,
    required this.fullName,
    required this.guardianFullName,
    required this.age,
    required this.guardianPhone,
    this.studentPhone,
    required this.gender,
    required this.placeOfResidence,
    required this.schoolCycle,
    required this.group,
    required this.institutionalEmail,
    required this.studentId,
    this.isActive = true, // Default to true
    this.deactivationReason,
    this.allergies,
    this.healthConditions,
    this.generalHealthStatus = 'Sano',
    this.nss,
    this.medicalAlert = false, // Default false
    this.canEditProfile = false, // NEW: Default to false
    required this.userId, // NEW
    required this.registeredByUserId, // NEW
    this.profileImageUrl, // NEW
  });

  // Factory constructor for creating a Student from a Firebase DataSnapshot
  factory Student.fromSnapshot(DataSnapshot snapshot) {
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    data['id'] = snapshot.key!; // Add the ID from the snapshot key
    return Student.fromMap(data);
  }

  // Factory constructor for creating a Student from a Map (e.g., from Firebase .value as Map)
  factory Student.fromMap(Map<String, dynamic> data) {
    return Student(
      id: data['id'] ?? '', // Assuming 'id' is present if coming from a full snapshot.key
      fullName: data['fullName'] ?? '',
      guardianFullName: data['guardianFullName'] ?? '',
      age: data['age'] ?? 0,
      guardianPhone: data['guardianPhone'] ?? '',
      studentPhone: data['studentPhone'],
      gender: data['gender'] ?? '',
      placeOfResidence: data['placeOfResidence'] ?? '',
      schoolCycle: data['schoolCycle'] ?? '',
      group: data['group'] ?? '',
      institutionalEmail: data['institutionalEmail'] ?? '',
      studentId: data['studentId'] ?? '',
      isActive: data['isActive'] ?? true,
      deactivationReason: data['deactivationReason'],
      allergies: data['allergies'],
      healthConditions: data['healthConditions'],
      generalHealthStatus: data['generalHealthStatus'] ?? 'Sano',
      nss: data['nss'],
      medicalAlert: data['medicalAlert'] ?? false,
      canEditProfile: data['canEditProfile'] ?? false, // NEW
      userId: data['userId'] ?? '', // NEW
      registeredByUserId: data['registeredByUserId'] ?? '', // NEW
      profileImageUrl: data['profileImageUrl'], // NEW
    );
  }

  // Method for converting a Student object to a Map for Firebase
  Map<String, dynamic> toFirebaseMap() {
    return {
      'fullName': fullName,
      'guardianFullName': guardianFullName,
      'age': age,
      'guardianPhone': guardianPhone,
      'studentPhone': studentPhone,
      'gender': gender,
      'placeOfResidence': placeOfResidence,
      'schoolCycle': schoolCycle,
      'group': group,
      'institutionalEmail': institutionalEmail,
      'studentId': studentId,
      'isActive': isActive,
      'deactivationReason': deactivationReason,
      'allergies': allergies,
      'healthConditions': healthConditions,
      'generalHealthStatus': generalHealthStatus,
      'nss': nss,
      'medicalAlert': medicalAlert,
      'canEditProfile': canEditProfile, // NEW
      'userId': userId, // NEW
      'registeredByUserId': registeredByUserId, // NEW
      'profileImageUrl': profileImageUrl, // NEW
    };
  }}
