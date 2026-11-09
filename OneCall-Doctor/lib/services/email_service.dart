import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  final String _username = 'anirudhnaginayanicheruvu.05@gmail.com';
  final String _password = 'oaxeqiujpibotbek'; // App Password provided

  Future<void> sendPrescriptionEmail({
    required String userEmail,
    required String appointmentId,
    required String doctorName,
    required String prescription,
    required String date,
  }) async {
    if (userEmail.isEmpty) {
      print('Skipping email: User email is empty.');
      return;
    }

    final smtpServer = gmail(_username, _password);

    final message = Message()
      ..from = Address(_username, 'OneCall Doctor')
      ..recipients.add(userEmail)
      ..subject = 'Prescription from $doctorName - OneCall'
      ..text = 'Hello,\n\n'
          'Here is your prescription from Dr. $doctorName for the appointment on $date.\n\n'
          'Prescription:\n$prescription\n\n'
          'Appointment ID: $appointmentId\n\n'
          'Take care,\nOneCall Team';

    try {
      await send(message, smtpServer);
      print('Prescription email sent to $userEmail');
    } catch (e) {
      print('Failed to send prescription email: $e');
      throw e;
    }
  }
  Future<void> sendCancellationEmail({
    required String userEmail,
    required String appointmentId,
    required String doctorName,
    required String date,
  }) async {
    if (userEmail.isEmpty) return;

    final smtpServer = gmail(_username, _password);

    final message = Message()
      ..from = Address(_username, 'OneCall Doctor')
      ..recipients.add(userEmail)
      ..subject = 'Appointment Cancelled - OneCall'
      ..text = 'Hello,\n\n'
          'We regret to inform you that Dr. $doctorName has cancelled your appointment scheduled for $date.\n\n'
          'Appointment ID: $appointmentId\n\n'
          'A full refund has been initiated to your wallet.\n\n'
          'We apologize for the inconvenience.\n\n'
          'OneCall Team';

    try {
      await send(message, smtpServer);
      print('Cancellation email sent to $userEmail');
    } catch (e) {
      print('Failed to send cancellation email: $e');
    }
  }
}
