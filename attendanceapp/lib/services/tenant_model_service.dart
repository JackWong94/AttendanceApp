import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tenant_model.dart';

class TenantModelService {
  TenantModelService._internal();
  static final TenantModelService instance = TenantModelService._internal();

  final CollectionReference _tenantCollection =
  FirebaseFirestore.instance.collection('tenants');

  /// Save tenant with controlled docId, e.g. uid_dev, uid_dev_1, uid_dev_2...
  Future<void> setTenant(TenantModel tenant) async {
    String baseDocId = "uid_${tenant.tenantId}";
    String docId = baseDocId;

    // 🔄 Keep checking until we find an available ID
    int counter = 1;
    while (true) {
      final docSnapshot = await _tenantCollection.doc(docId).get();
      if (!docSnapshot.exists) {
        break; // free to use
      }
      docId = "${baseDocId}_$counter";
      counter++;
    }

    // ✅ Save the tenant
    await _tenantCollection.doc(docId).set(tenant.toMap());
  }

  Future<TenantModel?> getTenantByEmail(String email) async {
    final query = await _tenantCollection
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return TenantModel.fromMap(query.docs.first.data() as Map<String, dynamic>);
  }

  Future<String?> getTenantIdByEmail(String email) async {
    final tenant = await getTenantByEmail(email);
    return tenant?.tenantId;
  }
}
