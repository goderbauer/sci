// @dart=2.9

import 'dart:io';

bool debugUseFakeHttpLayer = true;

Duration debugHttpLatency = const Duration(seconds: 1);

int debugHttpStatusCode = HttpStatus.ok;
