import 'package:flutter/foundation.dart';

const microSurveyKey = 'task_completion_v1';

enum MicroSurveyTrigger {
  deploymentMonitoringCreated('deployment_monitoring_created'),
  resourceCreated('resource_created');

  const MicroSurveyTrigger(this.databaseValue);

  final String databaseValue;
}

@immutable
class MicroSurveyContext {
  const MicroSurveyContext({
    required this.trigger,
    required this.route,
    required this.resourceType,
    this.completionStatus = 'succeeded',
    this.surveyKey = microSurveyKey,
  });

  final String surveyKey;
  final MicroSurveyTrigger trigger;
  final String route;
  final String resourceType;
  final String completionStatus;

  Map<String, Object> get claimParameters => <String, Object>{
        'p_survey_key': surveyKey,
        'p_trigger': trigger.databaseValue,
      };
}

@immutable
class MicroSurveyAnswer {
  const MicroSurveyAnswer({required this.rating, this.comment});

  final int rating;
  final String? comment;
}
