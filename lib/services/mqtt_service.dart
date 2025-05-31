import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:firebase_database/firebase_database.dart';

class MqttService {
  MqttServerClient? _client;
  final String _identifier = 'ecoGestionApp';
  final String _host = 'broker.hivemq.com'; // Public MQTT broker
  final String _topic = 'compteur/data';
  final int _port = 1883;

  final DatabaseReference _meterRef =
      FirebaseDatabase.instance.ref('compteurs');

  // Singleton pattern
  static final MqttService _instance = MqttService._internal();

  factory MqttService() {
    return _instance;
  }

  MqttService._internal();

  Future<bool> connect() async {
    _client = MqttServerClient(_host, _identifier);
    _client!.port = _port;
    _client!.keepAlivePeriod = 60;
    _client!.onDisconnected = _onDisconnected;
    _client!.onConnected = _onConnected;
    _client!.onSubscribed = _onSubscribed;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(_identifier)
        .withWillTopic('willtopic')
        .withWillMessage('Connexion perdue')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    _client!.connectionMessage = connMess;

    try {
      await _client!.connect();
      return true;
    } catch (e) {
      print('Exception: $e');
      _client!.disconnect();
      return false;
    }
  }

  void subscribe() {
    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      _client!.subscribe(_topic, MqttQos.atLeastOnce);
    }
  }

  void _onConnected() {
    print('Connecté au broker MQTT');
    subscribe();

    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (var message in messages) {
        final MqttPublishMessage recMess =
            message.payload as MqttPublishMessage;
        final String payload =
            MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        print('Message reçu: $payload du topic: ${message.topic}');

        // Traiter les données et les envoyer à Firebase
        _processData(payload);
      }
    });
  }

  void _processData(String payload) {
    try {
      // Supposons que le payload est au format JSON
      final data = jsonDecode(payload);
      final String meterId = data['meterId'];

      // Mettre à jour Firebase avec les nouvelles données
      _meterRef.child(meterId).update({
        'frequency': data['frequency'],
        'powerFactor': data['powerFactor'],
        'current': data['current'],
        'power': data['power'],
        'energy': data['energy'],
        'voltage': data['voltage'],
        'isOnline': true,
        'lastUpdate': ServerValue.timestamp,
      });
    } catch (e) {
      print('Erreur lors du traitement des données: $e');
    }
  }

  void _onDisconnected() {
    print('Déconnecté du broker MQTT');
  }

  void _onSubscribed(String topic) {
    print('Abonné au topic: $topic');
  }

  void disconnect() {
    _client?.disconnect();
  }

  void publishMessage(String topic, String message) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);

    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!,
          retain: true);
    }
  }

  // Méthode pour envoyer une commande au compteur
  void sendCommand(String meterId, String command, dynamic value) {
    final commandTopic = 'compteur/$meterId/command';
    final message = jsonEncode({
      'command': command,
      'value': value,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    publishMessage(commandTopic, message);
  }
}
