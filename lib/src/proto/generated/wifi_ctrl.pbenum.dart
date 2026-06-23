// This is a generated file - do not edit.
//
// Generated from wifi_ctrl.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class WiFiCtrlMsgType extends $pb.ProtobufEnum {
  static const WiFiCtrlMsgType TypeCtrlReserved =
      WiFiCtrlMsgType._(0, _omitEnumNames ? '' : 'TypeCtrlReserved');
  static const WiFiCtrlMsgType TypeCmdCtrlReset =
      WiFiCtrlMsgType._(1, _omitEnumNames ? '' : 'TypeCmdCtrlReset');
  static const WiFiCtrlMsgType TypeRespCtrlReset =
      WiFiCtrlMsgType._(2, _omitEnumNames ? '' : 'TypeRespCtrlReset');
  static const WiFiCtrlMsgType TypeCmdCtrlReprov =
      WiFiCtrlMsgType._(3, _omitEnumNames ? '' : 'TypeCmdCtrlReprov');
  static const WiFiCtrlMsgType TypeRespCtrlReprov =
      WiFiCtrlMsgType._(4, _omitEnumNames ? '' : 'TypeRespCtrlReprov');

  static const $core.List<WiFiCtrlMsgType> values = <WiFiCtrlMsgType>[
    TypeCtrlReserved,
    TypeCmdCtrlReset,
    TypeRespCtrlReset,
    TypeCmdCtrlReprov,
    TypeRespCtrlReprov,
  ];

  static final $core.List<WiFiCtrlMsgType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static WiFiCtrlMsgType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const WiFiCtrlMsgType._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
