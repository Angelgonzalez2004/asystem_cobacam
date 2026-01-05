// ignore_for_file: constant_identifier_names

import 'package:firebase_database/firebase_database.dart';

class TimeSlot {
  final String start;
  final String end;
  final bool isRecess;

  const TimeSlot(
      {required this.start, required this.end, this.isRecess = false});

  @override
  String toString() {
    return '$start - $end';
  }
}

const List<TimeSlot> HORARIOS = [
  TimeSlot(start: '07:00', end: '07:50'),
  TimeSlot(start: '07:50', end: '08:40'),
  TimeSlot(start: '08:40', end: '09:30'),
  TimeSlot(start: '09:30', end: '09:50', isRecess: true),
  TimeSlot(start: '09:50', end: '10:40'),
  TimeSlot(start: '10:40', end: '11:30'),
  TimeSlot(start: '11:30', end: '12:20'),
  TimeSlot(start: '12:20', end: '13:10'),
  TimeSlot(start: '13:10', end: '14:00'),
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
