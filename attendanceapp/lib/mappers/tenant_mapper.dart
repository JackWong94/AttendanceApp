import '../models/tenant_model.dart';

class TenantMapper {

  static TenantModel fromMap(
      Map<String, dynamic> map,
      ) {

    return TenantModel(
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? '',
      tenantId: map['tenantId'] ?? '',
    );

  }


  static Map<String, dynamic> toMap(
      TenantModel tenant,
      ) {

    return {
      'email': tenant.email,
      'name': tenant.name,
      'role': tenant.role,
      'tenantId': tenant.tenantId,
    };

  }
}