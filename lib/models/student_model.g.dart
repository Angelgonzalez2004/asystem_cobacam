// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'student_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StudentAdapter extends TypeAdapter<Student> {
  @override
  final int typeId = 0;

  @override
  Student read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Student(
      id: fields[0] as String,
      fullName: fields[1] as String,
      guardianFullName: fields[2] as String,
      age: fields[3] as int,
      guardianPhone: fields[4] as String,
      studentPhone: fields[5] as String?,
      gender: fields[6] as String,
      placeOfResidence: fields[7] as String,
      schoolCycle: fields[8] as String,
      group: fields[9] as String,
      institutionalEmail: fields[10] as String,
      studentId: fields[11] as String,
      isActive: fields[12] as bool,
      deactivationReason: fields[13] as String?,
      allergies: fields[14] as String?,
      healthConditions: fields[15] as String?,
      generalHealthStatus: fields[16] as String?,
      nss: fields[17] as String?,
      medicalAlert: fields[18] as bool,
      canEditProfile: fields[19] as bool,
      userId: fields[20] as String,
      registeredByUserId: fields[21] as String,
      profileImageUrl: fields[22] as String?,
      guardianUserIds: (fields[23] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Student obj) {
    writer
      ..writeByte(24)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fullName)
      ..writeByte(2)
      ..write(obj.guardianFullName)
      ..writeByte(3)
      ..write(obj.age)
      ..writeByte(4)
      ..write(obj.guardianPhone)
      ..writeByte(5)
      ..write(obj.studentPhone)
      ..writeByte(6)
      ..write(obj.gender)
      ..writeByte(7)
      ..write(obj.placeOfResidence)
      ..writeByte(8)
      ..write(obj.schoolCycle)
      ..writeByte(9)
      ..write(obj.group)
      ..writeByte(10)
      ..write(obj.institutionalEmail)
      ..writeByte(11)
      ..write(obj.studentId)
      ..writeByte(12)
      ..write(obj.isActive)
      ..writeByte(13)
      ..write(obj.deactivationReason)
      ..writeByte(14)
      ..write(obj.allergies)
      ..writeByte(15)
      ..write(obj.healthConditions)
      ..writeByte(16)
      ..write(obj.generalHealthStatus)
      ..writeByte(17)
      ..write(obj.nss)
      ..writeByte(18)
      ..write(obj.medicalAlert)
      ..writeByte(19)
      ..write(obj.canEditProfile)
      ..writeByte(20)
      ..write(obj.userId)
      ..writeByte(21)
      ..write(obj.registeredByUserId)
      ..writeByte(22)
      ..write(obj.profileImageUrl)
      ..writeByte(23)
      ..write(obj.guardianUserIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
