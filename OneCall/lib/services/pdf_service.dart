import 'package:callone/data/models/appointment.dart';
import 'package:callone/data/models/doctor.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfService {
  Future<void> generatePrescriptionPdf({
    required Doctor doctor,
    required AppointmentModel appointment,
    required String patientName,
    required String patientEmail,
  }) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    // Parse medicines from prescription string
    // Assuming format: "MedicineName | Dosage | Frequency | Duration" per line
    final List<List<String>> medicineTableData = [];
    if (appointment.prescription != null && appointment.prescription!.isNotEmpty) {
      final lines = appointment.prescription!.split('\n');
      for (var line in lines) {
        if (line.trim().isEmpty) continue;
        final parts = line.split('|').map((e) => e.trim()).toList();
        if (parts.length >= 4) {
          medicineTableData.add(parts.sublist(0, 4));
        } else {
          // If not in pipe format, add as single row with empty details
          medicineTableData.add([line, "-", "-", "-"]);
        }
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ONECALL',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 28,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.Text('Digital Healthcare Platform', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Dr. ${doctor.name}', style: pw.TextStyle(font: fontBold, fontSize: 16)),
                      pw.Text(doctor.specialization, style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700)),
                      pw.Text('Exp: ${doctor.experience} Years', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 2, color: PdfColors.blue900),
              pw.SizedBox(height: 20),

              // Patient Info Section
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.RichText(text: pw.TextSpan(children: [
                          pw.TextSpan(text: 'Patient: ', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                          pw.TextSpan(text: patientName, style: pw.TextStyle(font: font, fontSize: 12)),
                        ])),
                        pw.RichText(text: pw.TextSpan(children: [
                          pw.TextSpan(text: 'Email: ', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                          pw.TextSpan(text: patientEmail, style: pw.TextStyle(font: font, fontSize: 12)),
                        ])),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Date: ${DateFormat('dd-MM-yyyy').format(appointment.date)}', style: pw.TextStyle(font: font, fontSize: 12)),
                        pw.Text('Time: ${appointment.time}', style: pw.TextStyle(font: font, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Clinical Observations
              pw.Text('Clinical Observations:', style: pw.TextStyle(font: fontBold, fontSize: 14)),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  _infoBox('Concern', appointment.concernId, font, fontBold),
                  pw.SizedBox(width: 15),
                  _infoBox('Severity', '${(appointment.severity + 1).toInt()}/3', font, fontBold),
                  pw.SizedBox(width: 15),
                  _infoBox('Duration', '${appointment.duration} ${appointment.durationType}', font, fontBold),
                ],
              ),
              pw.SizedBox(height: 30),

              // Rx Section
              pw.Row(
                children: [
                  pw.Text('Rx', style: pw.TextStyle(font: fontBold, fontSize: 24, color: PdfColors.blue900)),
                  pw.SizedBox(width: 10),
                  pw.Expanded(child: pw.Divider(thickness: 1, color: PdfColors.grey300)),
                ],
              ),
              pw.SizedBox(height: 15),

              // Medicines Table
              if (medicineTableData.isNotEmpty)
                pw.TableHelper.fromTextArray(
                  context: context,
                  headerStyle: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
                  cellHeight: 30,
                  cellStyle: pw.TextStyle(font: font, fontSize: 11),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(1),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(1.5),
                  },
                  headers: ['Medicine Name', 'Dosage', 'Frequency', 'Duration'],
                  data: medicineTableData,
                )
              else
                pw.Text('No medications prescribed.', style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey600)),

              pw.SizedBox(height: 30),
              
              // Doctor's Note
              if (appointment.description != null && appointment.description!.isNotEmpty) ...[
                pw.Text('Advice / Notes:', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                pw.SizedBox(height: 8),
                pw.Text(appointment.description!, style: pw.TextStyle(font: font, fontSize: 12, lineSpacing: 4)),
              ],

              pw.Spacer(),

              // Footer with Sign and Seal
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Generated via OneCall Digital App', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey500)),
                      pw.Text('This is a computer-generated prescription.', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey500)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 120,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(top: pw.BorderSide(color: PdfColors.black, width: 1)),
                        ),
                        padding: const pw.EdgeInsets.only(top: 4),
                        child: pw.Center(child: pw.Text('Doctor\'s Signature', style: pw.TextStyle(font: font, fontSize: 10))),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Prescription_${patientName.replaceAll(' ', '_')}_${DateFormat('ddMMyy').format(appointment.date)}.pdf',
    );
  }

  pw.Widget _infoBox(String label, String value, pw.Font font, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600)),
          pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 11)),
        ],
      ),
    );
  }
}
