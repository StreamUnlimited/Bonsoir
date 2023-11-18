import 'dart:async';

import 'package:bonsoir_linux/actions/discovery/discovery.dart';
import 'package:bonsoir_linux/avahi/constants.dart';
import 'package:bonsoir_linux/avahi/record_browser.dart';
import 'package:bonsoir_linux/avahi/server2.dart';
import 'package:bonsoir_linux/avahi/service_browser.dart';
import 'package:bonsoir_linux/avahi/service_resolver.dart';
import 'package:bonsoir_linux/bonsoir_linux.dart';
import 'package:bonsoir_platform_interface/bonsoir_platform_interface.dart';
import 'package:dbus/dbus.dart';

/// Uses newer Avahi versions to discover a given service [type].
class AvahiDiscoveryV2 extends AvahiHandler {
  /// The Avahi server instance.
  late final AvahiServer2 _server;

  /// Contains all org.freedesktop.Avahi.RecordBrowser.ItemNew subscriptions.
  Map<BonsoirService, StreamSubscription> _recordBrowserItemNewSubscriptions = {};
  /// Contains all org.freedesktop.Avahi.RecordBrowser.Failure subscriptions.
  Map<BonsoirService, StreamSubscription> _recordBrowserFailureSubscriptions = {};
  /// Contains all org.freedesktop.Avahi.ServiceResolver.Found subscriptions.
  Map<BonsoirService, StreamSubscription> _serviceResolverFoundSubscriptions = {};
  /// Contains all org.freedesktop.Avahi.ServiceResolver.Failure subscriptions.
  Map<BonsoirService, StreamSubscription> _serviceResolverFailureSubscriptions = {};

  /// Creates a new Avahi discovery v2 instance.
  AvahiDiscoveryV2({
    required super.busClient,
  });

  @override
  void initialize() {
    _server = AvahiServer2(busClient, AvahiBonsoir.avahi, DBusObjectPath('/'));
  }

  @override
  Future<String> getAvahiServiceBrowserPath(String serviceType) => _server.callServiceBrowserPrepare(
        AvahiIfIndexUnspecified,
        AvahiProtocolUnspecified,
        serviceType,
        '',
        0,
      );

  @override
  Future<AvahiRecordBrowser> createAvahiRecordBrowser(AvahiBonsoirDiscovery discovery, BonsoirService service) async {
    String recordBrowserPath = await _server.callRecordBrowserPrepare(
      AvahiIfIndexUnspecified,
      AvahiProtocolUnspecified,
      service.fqdn,
      0x01,
      0x10,
      0,
    );

    return AvahiRecordBrowser(busClient, AvahiBonsoir.avahi, DBusObjectPath(recordBrowserPath));
  }

  @override
  List<StreamSubscription> getSubscriptions(AvahiBonsoirDiscovery discovery, AvahiServiceBrowser serviceBrowser) => [
        serviceBrowser.itemNew.listen(discovery.onServiceFound),
        serviceBrowser.itemRemove.listen(discovery.onServiceLost),
        DBusSignalStream(
          busClient,
          sender: AvahiBonsoir.avahi,
          interface: '${AvahiBonsoir.avahi}.ServiceResolver',
          name: 'Failure',
        ).listen(discovery.onServiceResolveFailure),
        DBusSignalStream(
          busClient,
          sender: AvahiBonsoir.avahi,
          interface: '${AvahiBonsoir.avahi}.ServiceResolver',
          name: 'Found',
        ).listen(discovery.onServiceResolved),
        DBusSignalStream(
          busClient,
          sender: AvahiBonsoir.avahi,
          interface: '${AvahiBonsoir.avahi}.RecordBrowser',
          name: 'ItemNew',
        ).listen(discovery.onServiceTXTRecordFound),
        DBusSignalStream(
          busClient,
          sender: AvahiBonsoir.avahi,
          interface: '${AvahiBonsoir.avahi}.RecordBrowser',
          name: 'Failure',
        ).listen(discovery.onServiceTXTRecordNotFound),
      ];

  @override
  Future<void> resolveService(AvahiBonsoirDiscovery discovery, BonsoirService service, AvahiServiceBrowserItemNew event) async {
    String serviceResolverPath = await _server.callServiceResolverPrepare(
      event.interfaceValue,
      event.protocol,
      event.serviceName,
      event.type,
      event.domain,
      AvahiProtocolUnspecified,
      0,
    );
    AvahiServiceResolver resolver = AvahiServiceResolver(busClient, AvahiBonsoir.avahi, DBusObjectPath(serviceResolverPath));
    resolver.callStart();
  }

  /// Removes the service from the subscription map and cancel the subscription.
  void _removeAndCancelSubscription(Map<BonsoirService, StreamSubscription> subscriptions, BonsoirService service) {
    _serviceResolverFoundSubscriptions[service]?.cancel();
    _serviceResolverFoundSubscriptions.remove(service);
  }
}
