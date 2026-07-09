class CustomerUser {
  const CustomerUser({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    this.customerId,
    this.supabaseUid,
    this.passwordSet = false,
    this.justLoggedIn = false,
  });

  final String id;
  final String name;
  final String email;
  final String mobile;
  final String? customerId;
  final String? supabaseUid;
  final bool passwordSet;
  final bool justLoggedIn;

  factory CustomerUser.fromRole(
      Map<String, dynamic> role,
      Map<String, dynamic>? customer,
      String supabaseUid,
      String fallbackEmail) {
    final id = role['customer_id']?.toString() ??
        customer?['id']?.toString() ??
        supabaseUid;
    final rawEmail = customer?['email']?.toString() ?? fallbackEmail;
    final email = rawEmail.contains('@phone.planext4u.local') ? '' : rawEmail;
    return CustomerUser(
      id: customer?['id']?.toString() ?? id,
      customerId: id,
      supabaseUid: supabaseUid,
      name: customer?['name']?.toString() ?? 'Customer',
      email: email,
      mobile: customer?['mobile']?.toString() ?? '',
      passwordSet: role['password_set'] == true,
    );
  }

  factory CustomerUser.fromApi(Map<String, dynamic> profile,
      {String? fallbackId, String? userId}) {
    final id = (profile['id'] ??
            profile['customerId'] ??
            profile['customer_id'] ??
            fallbackId ??
            userId ??
            '')
        .toString();
    final name = (profile['fullName'] ??
            profile['full_name'] ??
            profile['name'] ??
            profile['displayName'] ??
            'Customer')
        .toString();
    final email = (profile['email'] ?? '').toString();
    final mobile = (profile['mobile'] ?? profile['phone'] ?? '').toString();
    return CustomerUser(
      id: id,
      customerId: id,
      supabaseUid: userId,
      name: name,
      email: email,
      mobile: mobile,
      passwordSet: true,
    );
  }
}
