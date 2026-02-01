// ignore_for_file: constant_identifier_names

import 'package:firebase_database/firebase_database.dart';

class TimeSlot {
  final String startTime;
  final String endTime;
  final bool isRecess;

  const TimeSlot(
      {required this.startTime, required this.endTime, this.isRecess = false});

  @override
  String toString() {
    return '$startTime - $endTime';
  }
}

const List<TimeSlot> HORARIOS = [
  TimeSlot(startTime: '07:00', endTime: '07:50'),
  TimeSlot(startTime: '07:50', endTime: '08:40'),
  TimeSlot(startTime: '08:40', endTime: '09:30'),
  TimeSlot(startTime: '09:30', endTime: '09:50', isRecess: true),
  TimeSlot(startTime: '09:50', endTime: '10:40'),
  TimeSlot(startTime: '10:40', endTime: '11:30'),
  TimeSlot(startTime: '11:30', endTime: '12:20'),
  TimeSlot(startTime: '12:20', endTime: '13:10'),
  TimeSlot(startTime: '13:10', endTime: '14:00'),
];

const List<String> DIAS_SEMANA = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes'
];

class ClassAssignment {
  String key;
  String subjectId;
  String teacherId;
  String groupId;
  String classroomId;

  // For display purposes, not stored in this object directly
  String? subjectName;
  String? teacherName;
  String? groupName;
  String? classroomName;

  ClassAssignment({
    required this.key,
    required this.subjectId,
    required this.teacherId,
    required this.groupId,
    required this.classroomId,
    this.subjectName,
    this.teacherName,
    this.groupName,
    this.classroomName,
  });

  factory ClassAssignment.fromSnapshot(DataSnapshot snapshot) {
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return ClassAssignment(
      key: snapshot.key!,
      subjectId: data['subjectId'] ?? '',
      teacherId: data['teacherId'] ?? '',
      groupId: data['groupId'] ?? '',
      classroomId: data['classroomId'] ?? '',
    );
  }
}
