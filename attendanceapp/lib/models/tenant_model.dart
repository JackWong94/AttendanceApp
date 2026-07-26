class TenantModel {
  final String email;
  final String name;
  final String role;
  final String tenantId;

  TenantModel({
    required this.email,
    required this.name,
    required this.role,
    required this.tenantId,
  });


  // Example static predefined tenants
  static final devTenant = TenantModel(
    email: "w.yuheng94@gmail.com",
    name: "Developer Jack",
    role: "admin",
    tenantId: "dev",
  );


  static final proTenant = TenantModel(
    email: "ckhw8888@gmail.com",
    name: "CK Hardware",
    role: "admin",
    tenantId: "pro_CKHW",
  );
}