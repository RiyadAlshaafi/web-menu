import 'agent_log_stub.dart' if (dart.library.ui_web) 'agent_log_web.dart' as impl;

void agentLog(String hypothesisId, String location, String message, Map<String, Object?> data) =>
    impl.agentLog(hypothesisId, location, message, data);

void agentLogResources(String hypothesisId) => impl.agentLogResources(hypothesisId);
