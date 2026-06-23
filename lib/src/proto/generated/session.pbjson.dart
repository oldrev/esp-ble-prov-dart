// This is a generated file - do not edit.
//
// Generated from session.proto.

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

@$core.Deprecated('Use secSchemeVersionDescriptor instead')
const SecSchemeVersion$json = {
  '1': 'SecSchemeVersion',
  '2': [
    {'1': 'SecScheme0', '2': 0},
    {'1': 'SecScheme1', '2': 1},
    {'1': 'SecScheme2', '2': 2},
  ],
};

/// Descriptor for `SecSchemeVersion`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List secSchemeVersionDescriptor = $convert.base64Decode(
    'ChBTZWNTY2hlbWVWZXJzaW9uEg4KClNlY1NjaGVtZTAQABIOCgpTZWNTY2hlbWUxEAESDgoKU2'
    'VjU2NoZW1lMhAC');

@$core.Deprecated('Use sessionDataDescriptor instead')
const SessionData$json = {
  '1': 'SessionData',
  '2': [
    {
      '1': 'sec_ver',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.session.SecSchemeVersion',
      '10': 'secVer'
    },
    {
      '1': 'sec0',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.security0.Sec0Payload',
      '9': 0,
      '10': 'sec0'
    },
    {
      '1': 'sec1',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.security1.Sec1Payload',
      '9': 0,
      '10': 'sec1'
    },
    {
      '1': 'sec2',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.security2.Sec2Payload',
      '9': 0,
      '10': 'sec2'
    },
  ],
  '8': [
    {'1': 'proto'},
  ],
};

/// Descriptor for `SessionData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionDataDescriptor = $convert.base64Decode(
    'CgtTZXNzaW9uRGF0YRIyCgdzZWNfdmVyGAIgASgOMhkuc2Vzc2lvbi5TZWNTY2hlbWVWZXJzaW'
    '9uUgZzZWNWZXISLAoEc2VjMBgKIAEoCzIWLnNlY3VyaXR5MC5TZWMwUGF5bG9hZEgAUgRzZWMw'
    'EiwKBHNlYzEYCyABKAsyFi5zZWN1cml0eTEuU2VjMVBheWxvYWRIAFIEc2VjMRIsCgRzZWMyGA'
    'wgASgLMhYuc2VjdXJpdHkyLlNlYzJQYXlsb2FkSABSBHNlYzJCBwoFcHJvdG8=');
