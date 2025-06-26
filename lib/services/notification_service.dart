import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _alertsRef = FirebaseDatabase.instance.ref('alerts');

  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  Future<void> initialize() async {
    // Demander la permission pour les notifications
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialiser les notifications locales
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(initializationSettings);

    // Configurer les notifications en arrière-plan
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Écouter les notifications en premier plan
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  // Gestionnaire de notifications en arrière-plan
  static Future<void> _firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    print('Message reçu en arrière-plan: ${message.notification?.title}');
  }

  // Gestionnaire de notifications en premier plan
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Message reçu en premier plan: ${message.notification?.title}');

    // Afficher la notification locale
    await _showLocalNotification(
      title: message.notification?.title ?? 'Nouvelle notification',
      body: message.notification?.body ?? '',
    );
  }

  // Afficher une notification locale
  Future<void> _showLocalNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'prepaid_system_channel',
      'Système Prépayé',
      channelDescription: 'Notifications du système prépayé',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
    );
  }

  // Envoyer une notification de crédit faible
  Future<void> sendLowCreditAlert(
      String meterId, double remainingEnergy) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final message = {
      'title': 'Alerte de crédit faible',
      'body':
          'Il vous reste ${remainingEnergy.toStringAsFixed(1)} kWh. Veuillez recharger votre compte.',
      'meterId': meterId,
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Sauvegarder la notification dans Firestore
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .add(message);

    // Envoyer la notification locale
    await _showLocalNotification(
      title: message['title'] as String,
      body: message['body'] as String,
    );
  }

  // Envoyer une notification de coupure
  Future<void> sendPowerCutAlert(String meterId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final message = {
      'title': 'Coupure de courant',
      'body': 'Votre crédit est épuisé. Le courant a été coupé.',
      'meterId': meterId,
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Sauvegarder la notification dans Firestore
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .add(message);

    // Envoyer la notification locale
    await _showLocalNotification(
      title: message['title'] as String,
      body: message['body'] as String,
    );
  }

  // Envoyer une notification de fraude
  Future<void> sendFraudAlert(String meterId, String details) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final message = {
      'title': 'Alerte de fraude détectée',
      'body': 'Une tentative de fraude a été détectée: $details',
      'meterId': meterId,
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Sauvegarder la notification dans Firestore
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .add(message);

    // Envoyer la notification locale
    await _showLocalNotification(
      title: message['title'] as String,
      body: message['body'] as String,
    );
  }

  Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }

  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
  }

  // Méthode pour créer une alerte dans Firebase
  Future<void> createAlert(String meterId, String title, String message) async {
    await _alertsRef.push().set({
      'meterId': meterId,
      'title': title,
      'message': message,
      'timestamp': ServerValue.timestamp,
      'read': false,
    });
  }
}
