import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tenant_model.dart';
import '../mappers/tenant_mapper.dart';

class TenantModelService {
  TenantModelService._internal();
  static final TenantModelService instance = TenantModelService._internal();

  final CollectionReference _tenantCollection =
  FirebaseFirestore.instance.collection('tenants');

  TenantModel? _currentTenant; // ✅ keep current tenant in memory

  /// Save tenant with controlled docId, e.g. uid_dev, uid_dev_1, uid_dev_2...
  Future<void> setTenant(TenantModel tenant) async {
    String baseDocId = "uid_${tenant.tenantId}";
    String docId = baseDocId;

    int counter = 1;
    while (true) {
      final docSnapshot = await _tenantCollection.doc(docId).get();
      if (!docSnapshot.exists) {
        break;
      }
      docId = "${baseDocId}_$counter";
      counter++;
    }

    await _tenantCollection.doc(docId).set(TenantMapper.toMap(_currentTenant!));
  }

  Future<TenantModel?> getTenantByEmail(String email) async {
    final query =
    await _tenantCollection.where('email', isEqualTo: email).limit(1).get();

    if (query.docs.isEmpty) return null;
    final tenant =
    TenantMapper.fromMap(query.docs.first.data() as Map<String, dynamic>);

    _currentTenant = tenant; // ✅ set as current tenant
    return tenant;
  }

  Future<String?> getTenantIdByEmail(String email) async {
    final tenant = await getTenantByEmail(email);
    return tenant?.tenantId;
  }

  /// ✅ Explicit setter (use this if you already have the tenant after login)
  void setCurrentTenant(TenantModel tenant) {
    _currentTenant = tenant;
  }

  /// ✅ Getter for current tenant name
  String get currentTenantName => _currentTenant?.name ?? "Unknown Tenant";

  /// ✅ Getter for current tenant ID
  String? get currentTenantId => _currentTenant?.tenantId;

  /// ✅ Getter for current tenant role
  String? get getCurrentTenantRole => _currentTenant?.role;

  /// ✅ Clear current tenant (e.g., on logout)
  void clearCurrentTenant() {
    _currentTenant = null;
  }
}
