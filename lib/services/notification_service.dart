import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final DatabaseReference _alertsRef = FirebaseDatabase.instance.ref('alerts');

  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  Future<void> initialize() async {
    // Demander les permissions pour les notifications
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Configurer les gestionnaires de messages Firebase
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Configurer l'écouteur pour les alertes dans Firebase
    _setupAlertListener();
  }

  void _setupAlertListener() {
    _alertsRef.onChildAdded.listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);

        // Vérifier si l'alerte est nouvelle (moins de 5 minutes)
        final timestamp = data['timestamp'] as int;
        final now = DateTime.now().millisecondsSinceEpoch;

        if (now - timestamp < 5 * 60 * 1000) {
          // 5 minutes
          _sendNotification(
            data['title'] ?? 'Alerte',
            data['message'] ?? 'Une alerte a été détectée sur votre compteur',
            data['meterId'] ?? '',
          );
        }
      }
    });
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Message reçu en premier plan: ${message.notification?.title}');

    if (message.notification != null) {
      _sendNotification(
        message.notification!.title ?? 'Notification',
        message.notification!.body ?? '',
        message.data['meterId'] ?? '',
      );
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    print(
        'Application ouverte depuis la notification: ${message.notification?.title}');
    // Vous pouvez ajouter une logique de navigation ici
  }

  // Gestionnaire pour les messages en arrière-plan
  static Future<void> _firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    print('Message reçu en arrière-plan: ${message.notification?.title}');
  }

  Future<void> _sendNotification(
      String title, String body, String meterId) async {
    // Cette méthode sera utilisée pour envoyer des notifications via Firebase Cloud Messaging
    // Vous devrez implémenter la logique côté serveur pour envoyer les notifications
    print('Envoi de notification: $title - $body - $meterId');
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
