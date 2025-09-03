// File: lib/app/main_init.dart
// Initialize app pipelines (alerts/devices). Keep as-is; MQTT connects in Splash.

import '../features/data/topic_store.dart';
import '../features/alerts/alert_service.dart';
import '../features/devices/device_registry.dart';

void initAppPipelines() {
  TopicStore.I.start();
  AlertService.I.setRules(const [
    AlertRule(topic: 'esp32server/{device}/temp', warnHigh: 50, max: 60),
  ]);
  AlertService.I.start();
  DeviceRegistry.I.configure(prefix: 'esp32server', deviceIndex: 1);
  DeviceRegistry.I.start();
}
