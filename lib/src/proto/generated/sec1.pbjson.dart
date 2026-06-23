// This is a generated file - do not edit.
//
// Generated from sec1.proto.

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

@$core.Deprecated('Use sec1MsgTypeDescriptor instead')
const Sec1MsgType$json = {
  '1': 'Sec1MsgType',
  '2': [
    {'1': 'Session_Command0', '2': 0},
    {'1': 'Session_Response0', '2': 1},
    {'1': 'Session_Command1', '2': 2},
    {'1': 'Session_Response1', '2': 3},
  ],
};

/// Descriptor for `Sec1MsgType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List sec1MsgTypeDescriptor = $convert.base64Decode(
    'CgtTZWMxTXNnVHlwZRIUChBTZXNzaW9uX0NvbW1hbmQwEAASFQoRU2Vzc2lvbl9SZXNwb25zZT'
    'AQARIUChBTZXNzaW9uX0NvbW1hbmQxEAISFQoRU2Vzc2lvbl9SZXNwb25zZTEQAw==');

@$core.Deprecated('Use sessionCmd1Descriptor instead')
const SessionCmd1$json = {
  '1': 'SessionCmd1',
  '2': [
    {
      '1': 'client_verify_data',
      '3': 2,
      '4': 1,
      '5': 12,
      '10': 'clientVerifyData'
    },
  ],
};

/// Descriptor for `SessionCmd1`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionCmd1Descriptor = $convert.base64Decode(
    'CgtTZXNzaW9uQ21kMRIsChJjbGllbnRfdmVyaWZ5X2RhdGEYAiABKAxSEGNsaWVudFZlcmlmeU'
    'RhdGE=');

@$core.Deprecated('Use sessionResp1Descriptor instead')
const SessionResp1$json = {
  '1': 'SessionResp1',
  '2': [
    {
      '1': 'status',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.constants.Status',
      '10': 'status'
    },
    {
      '1': 'device_verify_data',
      '3': 3,
      '4': 1,
      '5': 12,
      '10': 'deviceVerifyData'
    },
  ],
};

/// Descriptor for `SessionResp1`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionResp1Descriptor = $convert.base64Decode(
    'CgxTZXNzaW9uUmVzcDESKQoGc3RhdHVzGAEgASgOMhEuY29uc3RhbnRzLlN0YXR1c1IGc3RhdH'
    'VzEiwKEmRldmljZV92ZXJpZnlfZGF0YRgDIAEoDFIQZGV2aWNlVmVyaWZ5RGF0YQ==');

@$core.Deprecated('Use sessionCmd0Descriptor instead')
const SessionCmd0$json = {
  '1': 'SessionCmd0',
  '2': [
    {'1': 'client_pubkey', '3': 1, '4': 1, '5': 12, '10': 'clientPubkey'},
  ],
};

/// Descriptor for `SessionCmd0`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionCmd0Descriptor = $convert.base64Decode(
    'CgtTZXNzaW9uQ21kMBIjCg1jbGllbnRfcHVia2V5GAEgASgMUgxjbGllbnRQdWJrZXk=');

@$core.Deprecated('Use sessionResp0Descriptor instead')
const SessionResp0$json = {
  '1': 'SessionResp0',
  '2': [
    {
      '1': 'status',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.constants.Status',
      '10': 'status'
    },
    {'1': 'device_pubkey', '3': 2, '4': 1, '5': 12, '10': 'devicePubkey'},
    {'1': 'device_random', '3': 3, '4': 1, '5': 12, '10': 'deviceRandom'},
  ],
};

/// Descriptor for `SessionResp0`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionResp0Descriptor = $convert.base64Decode(
    'CgxTZXNzaW9uUmVzcDASKQoGc3RhdHVzGAEgASgOMhEuY29uc3RhbnRzLlN0YXR1c1IGc3RhdH'
    'VzEiMKDWRldmljZV9wdWJrZXkYAiABKAxSDGRldmljZVB1YmtleRIjCg1kZXZpY2VfcmFuZG9t'
    'GAMgASgMUgxkZXZpY2VSYW5kb20=');

@$core.Deprecated('Use sec1PayloadDescriptor instead')
const Sec1Payload$json = {
  '1': 'Sec1Payload',
  '2': [
    {
      '1': 'msg',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.security1.Sec1MsgType',
      '10': 'msg'
    },
    {
      '1': 'sc0',
      '3': 20,
      '4': 1,
      '5': 11,
      '6': '.security1.SessionCmd0',
      '9': 0,
      '10': 'sc0'
    },
    {
      '1': 'sr0',
      '3': 21,
      '4': 1,
      '5': 11,
      '6': '.security1.SessionResp0',
      '9': 0,
      '10': 'sr0'
    },
    {
      '1': 'sc1',
      '3': 22,
      '4': 1,
      '5': 11,
      '6': '.security1.SessionCmd1',
      '9': 0,
      '10': 'sc1'
    },
    {
      '1': 'sr1',
      '3': 23,
      '4': 1,
      '5': 11,
      '6': '.security1.SessionResp1',
      '9': 0,
      '10': 'sr1'
    },
  ],
  '8': [
    {'1': 'payload'},
  ],
};

/// Descriptor for `Sec1Payload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sec1PayloadDescriptor = $convert.base64Decode(
    'CgtTZWMxUGF5bG9hZBIoCgNtc2cYASABKA4yFi5zZWN1cml0eTEuU2VjMU1zZ1R5cGVSA21zZx'
    'IqCgNzYzAYFCABKAsyFi5zZWN1cml0eTEuU2Vzc2lvbkNtZDBIAFIDc2MwEisKA3NyMBgVIAEo'
    'CzIXLnNlY3VyaXR5MS5TZXNzaW9uUmVzcDBIAFIDc3IwEioKA3NjMRgWIAEoCzIWLnNlY3VyaX'
    'R5MS5TZXNzaW9uQ21kMUgAUgNzYzESKwoDc3IxGBcgASgLMhcuc2VjdXJpdHkxLlNlc3Npb25S'
    'ZXNwMUgAUgNzcjFCCQoHcGF5bG9hZA==');
