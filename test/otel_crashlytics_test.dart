// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_crashlytics/otel_crashlytics.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_crashlytics-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('recordFlutterFatalError marks fatal + sets span error', () async {
    await tracedCrashlytics<String>(
      operation: 'recordFlutterFatalError',
      invoke: () async => const CrashlyticsCallResult(
        value: 'ok',
        result: CrashlyticsResult(
          firebaseAppName: '[DEFAULT]',
          recordKind: 'fatal_flutter',
          fatal: true,
          errorClass: 'StateError',
          customKeyCount: 5,
          breadcrumbCount: 24,
        ),
      ),
    );
    final s = spans.findSpanByName('crashlytics recordFlutterFatalError')!;
    expect(s.status, SpanStatusCode.Error);
    expect(attrsOf(s)['crashlytics.record.fatal'], true);
  });

  test('non-fatal recordError does NOT set span error', () async {
    await tracedCrashlytics<String>(
      operation: 'recordError',
      invoke: () async => const CrashlyticsCallResult(
        value: 'ok',
        result: CrashlyticsResult(
          recordKind: 'error',
          fatal: false,
          errorClass: 'FormatException',
        ),
      ),
    );
    expect(
      spans.findSpanByName('crashlytics recordError')!.status,
      isNot(SpanStatusCode.Error),
    );
  });

  test('checkForUnsentReports records previous-crash signal', () async {
    await tracedCrashlytics<String>(
      operation: 'checkForUnsentReports',
      invoke: () async => const CrashlyticsCallResult(
        value: 'ok',
        result: CrashlyticsResult(
          didCrashOnPreviousExecution: true,
          unsentReports: 2,
        ),
      ),
    );
    final a = attrsOf(
      spans.findSpanByName('crashlytics checkForUnsentReports')!,
    );
    expect(a['crashlytics.did_crash_previous'], true);
    expect(a['crashlytics.unsent_reports.count'], 2);
  });

  test('suppression skips spans', () async {
    await runWithoutCrashlyticsInstrumentationAsync(() async {
      await tracedCrashlytics<String>(
        operation: 'log',
        invoke: () async => const CrashlyticsCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('crashlytics '), isEmpty);
  });
}
