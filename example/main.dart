// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_crashlytics/otel_crashlytics.dart';

/// Traces Crashlytics calls with OpenTelemetry.
///
/// `otel_crashlytics` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Crashlytics call in
/// [tracedCrashlytics]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'crashlytics-example');

  // Wraps a Crashlytics SDK call in a CLIENT span.
  final crashlyticsId = await tracedCrashlytics<String>(
    operation: 'create',
    invoke: () async {
      // Make the Crashlytics call here, then report what it returned.
      const id = 'crashlytics_8f3a2c';
      return const CrashlyticsCallResult(
          value: id,
          result: CrashlyticsResult(
              firebaseAppName: '[DEFAULT]',
              googleAppId: 'googleapp_8f3a2c',
              recordKind: 'error',
              fatal: true,
              errorClass: 'example',
              userId: 'setUserId',
              customKeyCount: 3,
              breadcrumbCount: 3,
              collectionEnabled: true,
              didCrashOnPreviousExecution: true,
              unsentReports: 443,
              statusCode: 201));
    },
  );
  OTelLog.info('tracedCrashlytics create returned $crashlyticsId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutCrashlyticsInstrumentationAsync.
  await runWithoutCrashlyticsInstrumentationAsync(
    () => tracedCrashlytics<String>(
      operation: 'create',
      invoke: () async {
        const id = 'crashlytics_8f3a2c';
        return const CrashlyticsCallResult(
            value: id,
            result: CrashlyticsResult(
                firebaseAppName: '[DEFAULT]',
                googleAppId: 'googleapp_8f3a2c',
                recordKind: 'error',
                fatal: true,
                errorClass: 'example',
                userId: 'setUserId',
                customKeyCount: 3,
                breadcrumbCount: 3,
                collectionEnabled: true,
                didCrashOnPreviousExecution: true,
                unsentReports: 443,
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
