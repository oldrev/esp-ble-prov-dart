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

import 'constants.pbenum.dart' as $0;
import 'wifi_ctrl.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'wifi_ctrl.pbenum.dart';

class CmdCtrlReset extends $pb.GeneratedMessage {
  factory CmdCtrlReset() => create();

  CmdCtrlReset._();

  factory CmdCtrlReset.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CmdCtrlReset.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CmdCtrlReset',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ctrl'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdCtrlReset clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdCtrlReset copyWith(void Function(CmdCtrlReset) updates) =>
      super.copyWith((message) => updates(message as CmdCtrlReset))
          as CmdCtrlReset;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CmdCtrlReset create() => CmdCtrlReset._();
  @$core.override
  CmdCtrlReset createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CmdCtrlReset getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CmdCtrlReset>(create);
  static CmdCtrlReset? _defaultInstance;
}

class RespCtrlReset extends $pb.GeneratedMessage {
  factory RespCtrlReset() => create();

  RespCtrlReset._();

  factory RespCtrlReset.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RespCtrlReset.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RespCtrlReset',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ctrl'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespCtrlReset clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespCtrlReset copyWith(void Function(RespCtrlReset) updates) =>
      super.copyWith((message) => updates(message as RespCtrlReset))
          as RespCtrlReset;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RespCtrlReset create() => RespCtrlReset._();
  @$core.override
  RespCtrlReset createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RespCtrlReset getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RespCtrlReset>(create);
  static RespCtrlReset? _defaultInstance;
}

class CmdCtrlReprov extends $pb.GeneratedMessage {
  factory CmdCtrlReprov() => create();

  CmdCtrlReprov._();

  factory CmdCtrlReprov.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CmdCtrlReprov.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CmdCtrlReprov',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ctrl'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdCtrlReprov clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdCtrlReprov copyWith(void Function(CmdCtrlReprov) updates) =>
      super.copyWith((message) => updates(message as CmdCtrlReprov))
          as CmdCtrlReprov;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CmdCtrlReprov create() => CmdCtrlReprov._();
  @$core.override
  CmdCtrlReprov createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CmdCtrlReprov getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CmdCtrlReprov>(create);
  static CmdCtrlReprov? _defaultInstance;
}

class RespCtrlReprov extends $pb.GeneratedMessage {
  factory RespCtrlReprov() => create();

  RespCtrlReprov._();

  factory RespCtrlReprov.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RespCtrlReprov.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RespCtrlReprov',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ctrl'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespCtrlReprov clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespCtrlReprov copyWith(void Function(RespCtrlReprov) updates) =>
      super.copyWith((message) => updates(message as RespCtrlReprov))
          as RespCtrlReprov;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RespCtrlReprov create() => RespCtrlReprov._();
  @$core.override
  RespCtrlReprov createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RespCtrlReprov getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RespCtrlReprov>(create);
  static RespCtrlReprov? _defaultInstance;
}

enum WiFiCtrlPayload_Payload {
  cmdCtrlReset,
  respCtrlReset,
  cmdCtrlReprov,
  respCtrlReprov,
  notSet
}

class WiFiCtrlPayload extends $pb.GeneratedMessage {
  factory WiFiCtrlPayload({
    WiFiCtrlMsgType? msg,
    $0.Status? status,
    CmdCtrlReset? cmdCtrlReset,
    RespCtrlReset? respCtrlReset,
    CmdCtrlReprov? cmdCtrlReprov,
    RespCtrlReprov? respCtrlReprov,
  }) {
    final result = create();
    if (msg != null) result.msg = msg;
    if (status != null) result.status = status;
    if (cmdCtrlReset != null) result.cmdCtrlReset = cmdCtrlReset;
    if (respCtrlReset != null) result.respCtrlReset = respCtrlReset;
    if (cmdCtrlReprov != null) result.cmdCtrlReprov = cmdCtrlReprov;
    if (respCtrlReprov != null) result.respCtrlReprov = respCtrlReprov;
    return result;
  }

  WiFiCtrlPayload._();

  factory WiFiCtrlPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WiFiCtrlPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, WiFiCtrlPayload_Payload>
      _WiFiCtrlPayload_PayloadByTag = {
    11: WiFiCtrlPayload_Payload.cmdCtrlReset,
    12: WiFiCtrlPayload_Payload.respCtrlReset,
    13: WiFiCtrlPayload_Payload.cmdCtrlReprov,
    14: WiFiCtrlPayload_Payload.respCtrlReprov,
    0: WiFiCtrlPayload_Payload.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WiFiCtrlPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ctrl'),
      createEmptyInstance: create)
    ..oo(0, [11, 12, 13, 14])
    ..aE<WiFiCtrlMsgType>(1, _omitFieldNames ? '' : 'msg',
        enumValues: WiFiCtrlMsgType.values)
    ..aE<$0.Status>(2, _omitFieldNames ? '' : 'status',
        enumValues: $0.Status.values)
    ..aOM<CmdCtrlReset>(11, _omitFieldNames ? '' : 'cmdCtrlReset',
        subBuilder: CmdCtrlReset.create)
    ..aOM<RespCtrlReset>(12, _omitFieldNames ? '' : 'respCtrlReset',
        subBuilder: RespCtrlReset.create)
    ..aOM<CmdCtrlReprov>(13, _omitFieldNames ? '' : 'cmdCtrlReprov',
        subBuilder: CmdCtrlReprov.create)
    ..aOM<RespCtrlReprov>(14, _omitFieldNames ? '' : 'respCtrlReprov',
        subBuilder: RespCtrlReprov.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WiFiCtrlPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WiFiCtrlPayload copyWith(void Function(WiFiCtrlPayload) updates) =>
      super.copyWith((message) => updates(message as WiFiCtrlPayload))
          as WiFiCtrlPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WiFiCtrlPayload create() => WiFiCtrlPayload._();
  @$core.override
  WiFiCtrlPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WiFiCtrlPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WiFiCtrlPayload>(create);
  static WiFiCtrlPayload? _defaultInstance;

  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  WiFiCtrlPayload_Payload whichPayload() =>
      _WiFiCtrlPayload_PayloadByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  void clearPayload() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  WiFiCtrlMsgType get msg => $_getN(0);
  @$pb.TagNumber(1)
  set msg(WiFiCtrlMsgType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasMsg() => $_has(0);
  @$pb.TagNumber(1)
  void clearMsg() => $_clearField(1);

  @$pb.TagNumber(2)
  $0.Status get status => $_getN(1);
  @$pb.TagNumber(2)
  set status($0.Status value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);

  @$pb.TagNumber(11)
  CmdCtrlReset get cmdCtrlReset => $_getN(2);
  @$pb.TagNumber(11)
  set cmdCtrlReset(CmdCtrlReset value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasCmdCtrlReset() => $_has(2);
  @$pb.TagNumber(11)
  void clearCmdCtrlReset() => $_clearField(11);
  @$pb.TagNumber(11)
  CmdCtrlReset ensureCmdCtrlReset() => $_ensure(2);

  @$pb.TagNumber(12)
  RespCtrlReset get respCtrlReset => $_getN(3);
  @$pb.TagNumber(12)
  set respCtrlReset(RespCtrlReset value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasRespCtrlReset() => $_has(3);
  @$pb.TagNumber(12)
  void clearRespCtrlReset() => $_clearField(12);
  @$pb.TagNumber(12)
  RespCtrlReset ensureRespCtrlReset() => $_ensure(3);

  @$pb.TagNumber(13)
  CmdCtrlReprov get cmdCtrlReprov => $_getN(4);
  @$pb.TagNumber(13)
  set cmdCtrlReprov(CmdCtrlReprov value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasCmdCtrlReprov() => $_has(4);
  @$pb.TagNumber(13)
  void clearCmdCtrlReprov() => $_clearField(13);
  @$pb.TagNumber(13)
  CmdCtrlReprov ensureCmdCtrlReprov() => $_ensure(4);

  @$pb.TagNumber(14)
  RespCtrlReprov get respCtrlReprov => $_getN(5);
  @$pb.TagNumber(14)
  set respCtrlReprov(RespCtrlReprov value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasRespCtrlReprov() => $_has(5);
  @$pb.TagNumber(14)
  void clearRespCtrlReprov() => $_clearField(14);
  @$pb.TagNumber(14)
  RespCtrlReprov ensureRespCtrlReprov() => $_ensure(5);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
