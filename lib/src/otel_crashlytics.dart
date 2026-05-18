// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_crashlytics_suppression.dart';

const _tracerName = 'dartastic_otel_libs_crashlytics';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class CrashlyticsResult {
  const CrashlyticsResult({
    this.firebaseAppName,
    this.googleAppId,
    this.recordKind,
    this.fatal,
    this.errorClass,
    this.userId,
    this.customKeyCount,
    this.breadcrumbCount,
    this.collectionEnabled,
    this.didCrashOnPreviousExecution,
    this.unsentReports,
    this.statusCode,
  });

  /// Firebase app instance name (`[DEFAULT]` or a secondary app).
  final String? firebaseAppName;

  /// Firebase `googleAppId` (per-platform GCM/Firebase project app).
  final String? googleAppId;

  /// `error` (recordError) / `flutter_error` (recordFlutterError) /
  /// `fatal_flutter` (recordFlutterFatalError) / `log` (log message)
  /// / `user_identifier` / `custom_key` / `crash` (forced crash).
  final String? recordKind;

  /// `true` for fatal crashes (counted as crash-free-users impact).
  final bool? fatal;

  /// Top exception class name when recording an error.
  final String? errorClass;

  /// `setUserId` value (id only, no PII).
  final String? userId;

  /// Number of custom keys set on the record.
  final int? customKeyCount;

  /// Number of breadcrumbs flushed with the record.
  final int? breadcrumbCount;

  /// `setCrashlyticsCollectionEnabled` last state.
  final bool? collectionEnabled;

  final bool? didCrashOnPreviousExecution;

  /// `unsentReports` count from `checkForUnsentReports`.
  final int? unsentReports;

  final int? statusCode;
}

class CrashlyticsCallResult<T> {
  const CrashlyticsCallResult({required this.value, this.result});
  final T value;
  final CrashlyticsResult? result;
}

/// Wraps a Crashlytics SDK call in a CLIENT span. [operation] is one
/// of `recordError`, `recordFlutterError`, `recordFlutterFatalError`,
/// `log`, `setUserIdentifier`, `setCustomKey`,
/// `setCrashlyticsCollectionEnabled`, `crash`,
/// `didCrashOnPreviousExecution`, `checkForUnsentReports`,
/// `sendUnsentReports`, `deleteUnsentReports`.
Future<T> tracedCrashlytics<T>({
  required String operation,
  required Future<CrashlyticsCallResult<T>> Function() invoke,
}) async {
  if (crashlyticsInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'crashlytics',
    'rpc.method': operation,
    'crashlytics.operation': operation,
  };

  final span = _tracer().startSpan(
    'crashlytics $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.firebaseAppName != null) {
        extras.add(OTel.attributeString(
          'crashlytics.firebase_app.name',
          r.result!.firebaseAppName!,
        ));
      }
      if (r.result!.googleAppId != null) {
        extras.add(OTel.attributeString(
          'crashlytics.google_app.id',
          r.result!.googleAppId!,
        ));
      }
      if (r.result!.recordKind != null) {
        extras.add(OTel.attributeString(
          'crashlytics.record.kind',
          r.result!.recordKind!,
        ));
      }
      if (r.result!.fatal != null) {
        extras.add(OTel.attributeBool(
          'crashlytics.record.fatal',
          r.result!.fatal!,
        ));
        if (r.result!.fatal!) {
          span.setStatus(SpanStatusCode.Error, 'Crashlytics fatal record');
        }
      }
      if (r.result!.errorClass != null) {
        extras.add(OTel.attributeString(
          'crashlytics.error.class',
          r.result!.errorClass!,
        ));
      }
      if (r.result!.userId != null) {
        extras.add(OTel.attributeString(
          'crashlytics.user.id',
          r.result!.userId!,
        ));
      }
      if (r.result!.customKeyCount != null) {
        extras.add(OTel.attributeInt(
          'crashlytics.custom_keys.count',
          r.result!.customKeyCount!,
        ));
      }
      if (r.result!.breadcrumbCount != null) {
        extras.add(OTel.attributeInt(
          'crashlytics.breadcrumbs.count',
          r.result!.breadcrumbCount!,
        ));
      }
      if (r.result!.collectionEnabled != null) {
        extras.add(OTel.attributeBool(
          'crashlytics.collection.enabled',
          r.result!.collectionEnabled!,
        ));
      }
      if (r.result!.didCrashOnPreviousExecution != null) {
        extras.add(OTel.attributeBool(
          'crashlytics.did_crash_previous',
          r.result!.didCrashOnPreviousExecution!,
        ));
      }
      if (r.result!.unsentReports != null) {
        extras.add(OTel.attributeInt(
          'crashlytics.unsent_reports.count',
          r.result!.unsentReports!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Crashlytics HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
