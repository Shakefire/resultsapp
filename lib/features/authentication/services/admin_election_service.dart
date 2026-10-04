import '../../../core/services/vercel_api_client.dart';

class AdminElection {
  const AdminElection({required this.id, required this.code, required this.name, required this.status, this.opensAt, this.closesAt});
  final String id;
  final String code;
  final String name;
  final String status;
  final String? opensAt;
  final String? closesAt;
  factory AdminElection.fromJson(Map<String, dynamic> json) => AdminElection(
    id: json['id'] as String, code: json['election_code'] as String,
    name: json['name'] as String, status: json['status'] as String,
    opensAt: json['opens_at'] as String?, closesAt: json['closes_at'] as String?,
  );
}

class AdminElectionService {
  AdminElectionService({VercelApiClient? api}) : _api = api ?? VercelApiClient.instance;
  final VercelApiClient _api;

  Future<List<AdminElection>> list() async {
    final response = await _api.get('/api/v1/admin/elections');
    return (response['items'] as List<dynamic>).map((item) => AdminElection.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<void> create({required String code, required String name}) async => _api.post('/api/v1/admin/elections', {'electionCode': code, 'name': name});
  Future<void> close(String id) async => _api.patch('/api/v1/admin/elections', {'electionId': id, 'status': 'closed'});
}
