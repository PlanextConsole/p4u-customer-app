class CustomerUser {
  const CustomerUser({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    this.customerId,
    this.supabaseUid,
    this.justLoggedIn = false,
  });

  final String id;
  final String name;
  final String email;
  final String mobile;
  final String? customerId;
  final String? supabaseUid;
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
    );
  }

  factory CustomerUser.fromApi(Map<String, dynamic> profile,
      {String? fallbackId, String? userId}) {
    final profileId = (profile['id'] ??
            profile['customerId'] ??
            profile['customer_id'] ??
            '')
        .toString()
        .trim();
    // Prefer JWT commerce identity (web parity) when provided as fallbackId.
    final commerceId = (fallbackId ?? userId ?? '').toString().trim();
    final id = commerceId.isNotEmpty
        ? commerceId
        : (profileId.isNotEmpty ? profileId : '');
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
      customerId: profileId.isNotEmpty ? profileId : id,
      supabaseUid: userId,
      name: name,
      email: email,
      mobile: mobile,
    );
  }
}
