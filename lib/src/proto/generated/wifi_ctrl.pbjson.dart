// This is a generated file - do not edit.
//
// Generated from wifi_ctrl.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use wiFiCtrlMsgTypeDescriptor instead')
const WiFiCtrlMsgType$json = {
  '1': 'WiFiCtrlMsgType',
  '2': [
    {'1': 'TypeCtrlReserved', '2': 0},
    {'1': 'TypeCmdCtrlReset', '2': 1},
    {'1': 'TypeRespCtrlReset', '2': 2},
    {'1': 'TypeCmdCtrlReprov', '2': 3},
    {'1': 'TypeRespCtrlReprov', '2': 4},
  ],
};

/// Descriptor for `WiFiCtrlMsgType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List wiFiCtrlMsgTypeDescriptor = $convert.base64Decode(
    'Cg9XaUZpQ3RybE1zZ1R5cGUSFAoQVHlwZUN0cmxSZXNlcnZlZBAAEhQKEFR5cGVDbWRDdHJsUm'
    'VzZXQQARIVChFUeXBlUmVzcEN0cmxSZXNldBACEhUKEVR5cGVDbWRDdHJsUmVwcm92EAMSFgoS'
    'VHlwZVJlc3BDdHJsUmVwcm92EAQ=');

@$core.Deprecated('Use cmdCtrlResetDescriptor instead')
const CmdCtrlReset$json = {
  '1': 'CmdCtrlReset',
};

/// Descriptor for `CmdCtrlReset`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cmdCtrlResetDescriptor =
    $convert.base64Decode('CgxDbWRDdHJsUmVzZXQ=');

@$core.Deprecated('Use respCtrlResetDescriptor instead')
const RespCtrlReset$json = {
  '1': 'RespCtrlReset',
};

/// Descriptor for `RespCtrlReset`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List respCtrlResetDescriptor =
    $convert.base64Decode('Cg1SZXNwQ3RybFJlc2V0');

@$core.Deprecated('Use cmdCtrlReprovDescriptor instead')
const CmdCtrlReprov$json = {
  '1': 'CmdCtrlReprov',
};

/// Descriptor for `CmdCtrlReprov`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cmdCtrlReprovDescriptor =
    $convert.base64Decode('Cg1DbWRDdHJsUmVwcm92');

@$core.Deprecated('Use respCtrlReprovDescriptor instead')
const RespCtrlReprov$json = {
  '1': 'RespCtrlReprov',
};

/// Descriptor for `RespCtrlReprov`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List respCtrlReprovDescriptor =
    $convert.base64Decode('Cg5SZXNwQ3RybFJlcHJvdg==');

@$core.Deprecated('Use wiFiCtrlPayloadDescriptor instead')
const WiFiCtrlPayload$json = {
  '1': 'WiFiCtrlPayload',
  '2': [
    {
      '1': 'msg',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.ctrl.WiFiCtrlMsgType',
      '10': 'msg'
    },
    {
      '1': 'status',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.constants.Status',
      '10': 'status'
    },
    {
      '1': 'cmd_ctrl_reset',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.ctrl.CmdCtrlReset',
      '9': 0,
      '10': 'cmdCtrlReset'
    },
    {
      '1': 'resp_ctrl_reset',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.ctrl.RespCtrlReset',
      '9': 0,
      '10': 'respCtrlReset'
    },
    {
      '1': 'cmd_ctrl_reprov',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.ctrl.CmdCtrlReprov',
      '9': 0,
      '10': 'cmdCtrlReprov'
    },
    {
      '1': 'resp_ctrl_reprov',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.ctrl.RespCtrlReprov',
      '9': 0,
      '10': 'respCtrlReprov'
    },
  ],
  '8': [
    {'1': 'payload'},
  ],
};

/// Descriptor for `WiFiCtrlPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wiFiCtrlPayloadDescriptor = $convert.base64Decode(
    'Cg9XaUZpQ3RybFBheWxvYWQSJwoDbXNnGAEgASgOMhUuY3RybC5XaUZpQ3RybE1zZ1R5cGVSA2'
    '1zZxIpCgZzdGF0dXMYAiABKA4yES5jb25zdGFudHMuU3RhdHVzUgZzdGF0dXMSOgoOY21kX2N0'
    'cmxfcmVzZXQYCyABKAsyEi5jdHJsLkNtZEN0cmxSZXNldEgAUgxjbWRDdHJsUmVzZXQSPQoPcm'
    'VzcF9jdHJsX3Jlc2V0GAwgASgLMhMuY3RybC5SZXNwQ3RybFJlc2V0SABSDXJlc3BDdHJsUmVz'
    'ZXQSPQoPY21kX2N0cmxfcmVwcm92GA0gASgLMhMuY3RybC5DbWRDdHJsUmVwcm92SABSDWNtZE'
    'N0cmxSZXByb3YSQAoQcmVzcF9jdHJsX3JlcHJvdhgOIAEoCzIULmN0cmwuUmVzcEN0cmxSZXBy'
    'b3ZIAFIOcmVzcEN0cmxSZXByb3ZCCQoHcGF5bG9hZA==');
