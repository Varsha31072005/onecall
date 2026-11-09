import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  final String _username = 'anirudhnaginayanicheruvu.05@gmail.com'; 
  final String _password = 'oaxeqiujpibotbek'; // App Password provided

  Future<void> sendAppointmentConfirmation({
    required String doctorEmail,
    required String userEmail,
    required String appointmentId,
    required String date,
    required String time,
    required String doctorName, // Pass doctor name if available, else generic
  }) async {
    if (doctorEmail.isEmpty || userEmail.isEmpty) {
      print('Skipping email: Doctor or User email is empty.');
      return;
    }

    final smtpServer = gmail(_username, _password);

    // Create the message for the User
    final userMessage = Message()
      ..from = Address(_username, 'OneCall Doctor')
      ..recipients.add(userEmail)
      ..subject = 'Appointment Confirmation - OneCall'
      ..text = 'Your appointment has been confirmed.\n\n'
          'Appointment ID: $appointmentId\n'
          'Date: $date\n'
          'Time: $time\n\n'
          'Thank you for using OneCall.';

    // Create the message for the Doctor
    final doctorMessage = Message()
      ..from = Address(_username, 'OneCall Doctor')
      ..recipients.add(doctorEmail)
      ..subject = 'New Appointment Booking - OneCall'
      ..text = 'You have a new appointment.\n\n'
          'Appointment ID: $appointmentId\n'
          'Date: $date\n'
          'Time: $time\n'
          'Patient Email: $userEmail\n\n'
          'Please check the app for details.';

    // Send emails individually to ensure one failure doesn't block the other
    try {
        await send(userMessage, smtpServer);
        print('User confirmation email sent to $userEmail');
    } catch (e) {
        print('Failed to send user email: $e');
    }

    try {
        await send(doctorMessage, smtpServer);
        print('Doctor notification email sent to $doctorEmail');
    } catch (e) {
        print('Failed to send doctor email: $e');
    }
    }

  Future<void> sendCancellationEmail({
    required String doctorEmail,
    required String appointmentId,
    required String patientName,
    required String date,
  }) async {
    if (doctorEmail.isEmpty) return;

    final smtpServer = gmail(_username, _password);

    final message = Message()
      ..from = Address(_username, 'OneCall Doctor')
      ..recipients.add(doctorEmail)
      ..subject = 'Appointment Cancelled - OneCall'
      ..text = 'Hello,\n\n'
          'Patient $patientName has cancelled the appointment scheduled for $date.\n\n'
          'Appointment ID: $appointmentId\n\n'
          'Cancellation Fee (50%) has been credited to your wallet.\n\n'
          'OneCall Team';

    try {
      await send(message, smtpServer);
      print('Cancellation email sent to $doctorEmail');
    } catch (e) {
      print('Failed to send cancellation email: $e');
    }
  }
}
