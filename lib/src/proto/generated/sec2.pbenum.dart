// This is a generated file - do not edit.
//
// Generated from sec2.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// A message must be of type Cmd0 / Cmd1 / Resp0 / Resp1
class Sec2MsgType extends $pb.ProtobufEnum {
  static const Sec2MsgType S2Session_Command0 =
      Sec2MsgType._(0, _omitEnumNames ? '' : 'S2Session_Command0');
  static const Sec2MsgType S2Session_Response0 =
      Sec2MsgType._(1, _omitEnumNames ? '' : 'S2Session_Response0');
  static const Sec2MsgType S2Session_Command1 =
      Sec2MsgType._(2, _omitEnumNames ? '' : 'S2Session_Command1');
  static const Sec2MsgType S2Session_Response1 =
      Sec2MsgType._(3, _omitEnumNames ? '' : 'S2Session_Response1');

  static const $core.List<Sec2MsgType> values = <Sec2MsgType>[
    S2Session_Command0,
    S2Session_Response0,
    S2Session_Command1,
    S2Session_Response1,
  ];

  static final $core.List<Sec2MsgType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static Sec2MsgType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Sec2MsgType._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
