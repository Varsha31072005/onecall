import 'package:http/http.dart' as http;
import 'dart:convert';


class DoctorService{
  static const String baseUrl = 'http://10.0.2.2:8000';

  Future<String> checkStatus() async{
    final url = Uri.parse('$baseUrl/');
    try{
      final response = await http.get(url);
      if (response.statusCode == 200){
        final data = json.decode(response.body);
        return data['status'];
      }else{
        return 'Error: ${response.statusCode}';
      }

    } catch (e){
      return 'Error';
    }
  }
}
