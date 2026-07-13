import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../features/customer/data/customer_providers.dart';
import '../data/auth_repository.dart';

ButtonStyle _authOutlineStyle({Size? minimumSize}) => FilledButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.primary,
      disabledBackgroundColor: AppColors.background,
      disabledForegroundColor: AppColors.muted,
      minimumSize: minimumSize ?? const Size.fromHeight(50),
      side: const BorderSide(color: AppColors.primary, width: 1.3),
      elevation: 0,
    );

class CustomerLoginPage extends ConsumerStatefulWidget {
  const CustomerLoginPage({super.key});

  @override
  ConsumerState<CustomerLoginPage> createState() => _CustomerLoginPageState();
}

class _CustomerLoginPageState extends ConsumerState<CustomerLoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  bool _passwordMode = false;
  bool _showPassword = false;
  bool _otpSent = false;
  bool _loading = false;
  String? _verificationId;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _submitPassword() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      _snack('Please enter email and password');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .signInWithPassword(_email.text.trim(), _password.text);
      ref.invalidate(customerAuthStateProvider);
      if (mounted) context.go(_returnTo);
    } catch (e) {
      _snack(_friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendOtp() async {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      _snack('Please enter a valid 10-digit phone number');
      return;
    }
    if (Firebase.apps.isEmpty) {
      _snack(
        'Firebase is not configured. Add SHA fingerprints in Firebase Console and replace android/app/google-services.json, then rebuild the app.',
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await firebase.FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$digits',
        verificationCompleted: (credential) async {
          await _signInWithCredential(credential);
        },
        verificationFailed: (error) {
          if (!mounted) return;
          setState(() => _loading = false);
          _snack(_friendly(error));
        },
        codeSent: (verificationId, _) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _otpSent = true;
            _loading = false;
          });
        },
        codeAutoRetrievalTimeout: (verificationId) =>
            _verificationId = verificationId,
      );
    } catch (e) {
      _snack(_friendly(e));
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_verificationId == null || _otp.text.length != 6) {
      _snack('Enter the 6-digit OTP');
      return;
    }
    setState(() => _loading = true);
    try {
      final credential = firebase.PhoneAuthProvider.credential(
          verificationId: _verificationId!, smsCode: _otp.text);
      await _signInWithCredential(credential);
    } catch (e) {
      _snack(_friendly(e));
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithCredential(
      firebase.PhoneAuthCredential credential) async {
    final auth = firebase.FirebaseAuth.instance;
    try {
      final result = await auth.signInWithCredential(credential);
      final token = await result.user?.getIdToken(true);
      if (token == null) throw StateError('Missing Firebase ID token');
      await ref.read(authRepositoryProvider).signInWithFirebaseIdToken(token);
      ref.invalidate(customerAuthStateProvider);
      if (mounted) context.go(_returnTo);
    } catch (e) {
      _snack(_friendly(e));
    } finally {
      await auth.signOut().catchError((_) {});
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _returnTo {
    final value = GoRouterState.of(context).uri.queryParameters['returnTo'];
    if (value == null || value.isEmpty) return '/app';
    if (!value.startsWith('/app')) return '/app';
    if (value.startsWith('/app/login') || value.startsWith('/app/register')) {
      return '/app';
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(customerAuthStateProvider, (_, next) {
      if (next.valueOrNull != null && mounted) context.go(_returnTo);
    });
    return Scaffold(
      body: Container(
        color: AppColors.background,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const SizedBox(height: 18),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
                          decoration: const BoxDecoration(color: Colors.white),
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: AppColors.productSurface,
                                    border: Border.all(color: AppColors.border),
                                    borderRadius: BorderRadius.circular(18)),
                                child: Image.asset('assets/images/p4u-logo.png',
                                    fit: BoxFit.contain),
                              ),
                              const SizedBox(height: 12),
                              const Text('Welcome back',
                                  style: TextStyle(
                                      color: AppColors.brandDark,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              const Text('Sign in to continue to Planext4u',
                                  style: TextStyle(
                                      color: AppColors.muted, fontSize: 12)),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                          child: Column(
                            children: [
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Choose sign-in method',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.muted,
                                        fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(height: 10),
                              _modeSwitch(),
                              const SizedBox(height: 16),
                              if (_passwordMode) ...[
                                TextField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                      prefixIcon:
                                          Icon(Icons.mail_outline_rounded),
                                      hintText: 'Enter E-mail ID'),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _password,
                                  obscureText: !_showPassword,
                                  decoration: InputDecoration(
                                    prefixIcon:
                                        const Icon(Icons.lock_outline_rounded),
                                    hintText: 'Password',
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(
                                          () => _showPassword = !_showPassword),
                                      icon: Icon(_showPassword
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded),
                                    ),
                                  ),
                                  onSubmitted: (_) => _submitPassword(),
                                ),
                              ] else if (!_otpSent) ...[
                                TextField(
                                  controller: _phone,
                                  keyboardType: TextInputType.phone,
                                  maxLength: 10,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.phone_rounded),
                                      prefixText: '+91 ',
                                      hintText: 'Enter phone number',
                                      counterText: ''),
                                ),
                              ] else ...[
                                Text('Enter code sent to +91 ${_phone.text}',
                                    style: const TextStyle(
                                        color: AppColors.muted)),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _otp,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  textAlign: TextAlign.center,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 8),
                                  decoration: const InputDecoration(
                                      hintText: '000000', counterText: ''),
                                ),
                              ],
                              const SizedBox(height: 18),
                              FilledButton.icon(
                                onPressed: _loading
                                    ? null
                                    : (_passwordMode
                                        ? _submitPassword
                                        : (_otpSent ? _verifyOtp : _sendOtp)),
                                icon: _loading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primary))
                                    : Icon(_passwordMode
                                        ? Icons.login_rounded
                                        : (_otpSent
                                            ? Icons.verified_user_rounded
                                            : Icons.arrow_forward_rounded)),
                                label: Text(_loading
                                    ? 'Please wait...'
                                    : (_passwordMode
                                        ? 'Sign In'
                                        : (_otpSent
                                            ? 'Verify OTP'
                                            : 'Send OTP'))),
                                style: _authOutlineStyle(
                                    minimumSize: const Size.fromHeight(52)),
                              ),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                  child: TextButton(
                                      onPressed: () =>
                                          context.push('/app/forgot-password'),
                                      child: const Text('Forgot password?')),
                                ),
                                Container(
                                    width: 1,
                                    height: 18,
                                    color: AppColors.border),
                                Expanded(
                                  child: TextButton(
                                      onPressed: () =>
                                          context.push('/app/register'),
                                      child: const Text('Create account')),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeSwitch() {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
          color: AppColors.productSurface),
      child: Row(
        children: [
          _modeButton(
              label: 'Phone OTP',
              icon: Icons.phone_rounded,
              selected: !_passwordMode,
              onTap: () => setState(() => _passwordMode = false)),
          _modeButton(
              label: 'Password',
              icon: Icons.mail_outline_rounded,
              selected: _passwordMode,
              onTap: () => setState(() => _passwordMode = true)),
        ],
      ),
    );
  }

  Widget _modeButton(
      {required String label,
      required IconData icon,
      required bool selected,
      required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent),
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? const [BoxShadow(color: Colors.black12, blurRadius: 5)]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? AppColors.primary : AppColors.muted),
              const SizedBox(width: 6),
              Flexible(
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(label,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.brandDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w800)))),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}

class CustomerRegisterPage extends ConsumerStatefulWidget {
  const CustomerRegisterPage({super.key});

  @override
  ConsumerState<CustomerRegisterPage> createState() =>
      _CustomerRegisterPageState();
}

class _CustomerRegisterPageState extends ConsumerState<CustomerRegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _occupation = TextEditingController();
  final _referral = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _accepted = false;
  bool _otpSent = false;
  bool _verified = false;
  bool _loading = false;
  String? _verificationId;
  String? _firebaseToken;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _mobile.dispose();
    _occupation.dispose();
    _referral.dispose();
    _otp.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final digits = _mobile.text.replaceAll(RegExp(r'\D'), '');
    if (_name.text.trim().isEmpty) return _snack('Name is required');
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      return _snack('Please enter a valid 10-digit mobile number');
    }
    if (!_email.text.contains('@')) return _snack('Please enter a valid email');
    if (!_accepted) return _snack('Please accept terms and privacy policy');
    if (Firebase.apps.isEmpty) {
      return _snack('Firebase is not configured for this native app yet.');
    }
    setState(() => _loading = true);
    try {
      await firebase.FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$digits',
        verificationCompleted: (credential) async => _completeOtp(credential),
        verificationFailed: (error) {
          if (!mounted) return;
          setState(() => _loading = false);
          _snack(_friendly(error));
        },
        codeSent: (verificationId, _) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _otpSent = true;
            _loading = false;
          });
        },
        codeAutoRetrievalTimeout: (verificationId) =>
            _verificationId = verificationId,
      );
    } catch (e) {
      _snack(_friendly(e));
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_verificationId == null || _otp.text.length != 6) {
      return _snack('Enter the 6-digit OTP');
    }
    setState(() => _loading = true);
    try {
      final credential = firebase.PhoneAuthProvider.credential(
          verificationId: _verificationId!, smsCode: _otp.text);
      await _completeOtp(credential);
    } catch (e) {
      _snack(_friendly(e));
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _completeOtp(firebase.PhoneAuthCredential credential) async {
    final auth = firebase.FirebaseAuth.instance;
    final result = await auth.signInWithCredential(credential);
    _firebaseToken = await result.user?.getIdToken(true);
    await auth.signOut();
    if (_firebaseToken == null) throw StateError('Missing Firebase ID token');
    if (mounted) {
      setState(() {
        _verified = true;
        _loading = false;
      });
    }
  }

  Future<void> _register() async {
    if (_firebaseToken == null) return _snack('Please verify OTP first');
    if (_password.text.length < 8) {
      return _snack('Password must be at least 8 characters');
    }
    if (_password.text != _confirmPassword.text) {
      return _snack('Passwords do not match');
    }
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).registerWithFirebaseIdToken(
            firebaseIdToken: _firebaseToken!,
            name: _name.text.trim(),
            email: _email.text.trim(),
            mobile: '+91${_mobile.text}',
            occupation: _occupation.text.trim().isEmpty
                ? null
                : _occupation.text.trim(),
            referralCode:
                _referral.text.trim().isEmpty ? null : _referral.text.trim(),
          );
      await ref.read(authRepositoryProvider).updatePassword(_password.text);
      ref.invalidate(customerAuthStateProvider);
      if (mounted) context.go('/app/set-location');
    } catch (e) {
      _snack(_friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
              child: Image.asset('assets/images/p4u-logo.png',
                  width: 86, height: 86)),
          const SizedBox(height: 14),
          const Text('Join Planext4u',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Create one account for shopping, services and homes',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 18),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your details',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text('Fields marked with * are required',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 16),
                TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person_rounded),
                        hintText: 'Full Name *')),
                const SizedBox(height: 12),
                TextField(
                    controller: _mobile,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.phone_rounded),
                        prefixText: '+91 ',
                        hintText: 'Mobile Number *',
                        counterText: '')),
                const SizedBox(height: 12),
                TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.mail_rounded),
                        hintText: 'Email *')),
                const SizedBox(height: 12),
                TextField(
                    controller: _occupation,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.work_rounded),
                        hintText: 'Occupation')),
                const SizedBox(height: 12),
                TextField(
                    controller: _referral,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.card_giftcard_rounded),
                        hintText: 'Referral Code')),
                CheckboxListTile(
                  value: _accepted,
                  onChanged: (value) =>
                      setState(() => _accepted = value ?? false),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('I accept Terms & Privacy Policy'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (_otpSent && !_verified) ...[
                  TextField(
                      controller: _otp,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          hintText: 'Enter OTP', counterText: '')),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                      onPressed: _loading ? null : _verifyOtp,
                      icon: const Icon(Icons.verified_user_rounded),
                      label: const Text('Verify OTP'),
                      style: _authOutlineStyle()),
                ] else if (!_verified) ...[
                  FilledButton.icon(
                      onPressed: _loading ? null : _sendOtp,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(_loading ? 'Please wait...' : 'Send OTP'),
                      style: _authOutlineStyle()),
                ] else ...[
                  const StatusBadge('phone verified'),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.lock_rounded),
                          hintText: 'Create password')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _confirmPassword,
                      obscureText: true,
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                          hintText: 'Confirm password')),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                      onPressed: _loading ? null : _register,
                      icon: const Icon(Icons.person_add_rounded),
                      label: Text(_loading ? 'Creating...' : 'Create Account'),
                      style: _authOutlineStyle()),
                ],
              ],
            ),
          ),
          TextButton(
              onPressed: () => context.push('/app/login'),
              child: const Text('Already registered? Login')),
        ],
      ),
    );
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _email = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return _SimpleAuthShell(
      title: 'Forgot Password',
      child: Column(
        children: [
          TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.mail_rounded),
                  hintText: 'Email address')),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _loading
                ? null
                : () async {
                    setState(() => _loading = true);
                    try {
                      await ref
                          .read(authRepositoryProvider)
                          .sendPasswordReset(_email.text.trim());
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Password reset email sent.')));
                      }
                    } finally {
                      if (mounted) setState(() => _loading = false);
                    }
                  },
            child: Text(_loading ? 'Sending...' : 'Send Reset Link'),
          ),
        ],
      ),
    );
  }
}

class ResetPasswordPage extends StatelessWidget {
  const ResetPasswordPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const SetPasswordPage(title: 'Reset Password');
}

class SetPasswordPage extends ConsumerStatefulWidget {
  const SetPasswordPage({this.title = 'Set Password', super.key});

  final String title;

  @override
  ConsumerState<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends ConsumerState<SetPasswordPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return _SimpleAuthShell(
      title: widget.title,
      child: Column(
        children: [
          TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.lock_rounded),
                  hintText: 'New password')),
          const SizedBox(height: 12),
          TextField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                  hintText: 'Confirm password')),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _loading
                ? null
                : () async {
                    if (_password.text.length < 8 ||
                        _password.text != _confirm.text) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Check password and confirmation.')));
                      return;
                    }
                    setState(() => _loading = true);
                    try {
                      await ref
                          .read(authRepositoryProvider)
                          .updatePassword(_password.text);
                      if (context.mounted) context.go('/app');
                    } finally {
                      if (mounted) setState(() => _loading = false);
                    }
                  },
            child: Text(_loading ? 'Saving...' : 'Save Password'),
          ),
        ],
      ),
    );
  }
}

class SetLocationPage extends ConsumerStatefulWidget {
  const SetLocationPage({super.key});

  @override
  ConsumerState<SetLocationPage> createState() => _SetLocationPageState();
}

class _SetLocationPageState extends ConsumerState<SetLocationPage> {
  final _location = TextEditingController();
  bool _locating = false;

  @override
  Widget build(BuildContext context) {
    return _SimpleAuthShell(
      title: 'Set Location',
      child: Column(
        children: [
          TextField(
              controller: _location,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.location_on_rounded),
                  hintText: 'Area, city or pincode')),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _locating ? null : _useLiveLocation,
            icon: _locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location_rounded),
            label:
                Text(_locating ? 'Picking location...' : 'Use live location'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () async {
              await ref.read(customerRepositoryProvider).saveSelectedLocation(
                  _location.text.trim().isEmpty
                      ? 'Set your location'
                      : _location.text.trim());
              ref.invalidate(selectedLocationProvider);
              if (context.mounted) context.go('/app');
            },
            icon: const Icon(Icons.check_rounded),
            label: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _useLiveLocation() async {
    setState(() => _locating = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _snack('Please enable location services on your phone.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _snack('Location permission is required to pick live location.');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final value =
          'Live location: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      _location.text = value;
      await ref.read(customerRepositoryProvider).saveSelectedLocation(value);
      ref.invalidate(selectedLocationProvider);
      if (mounted) _snack('Live location selected');
    } catch (e) {
      _snack('Unable to pick live location. Please try again.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const _TextPolicyPage(title: 'Terms of Service');
}

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const _TextPolicyPage(title: 'Privacy Policy');
}

class _TextPolicyPage extends StatelessWidget {
  const _TextPolicyPage({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Text(
              'Planext4u keeps customer data, orders, service bookings, social activity and property leads protected according to platform policy. Use the app responsibly and contact support for account or privacy requests.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleAuthShell extends StatelessWidget {
  const _SimpleAuthShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Center(
              child: Image.asset('assets/images/p4u-logo.png',
                  width: 82, height: 82)),
          const SizedBox(height: 18),
          AppCard(child: child),
        ],
      ),
    );
  }
}

String _friendly(Object e) {
  if (e is ApiException) return e.message;
  if (e is firebase.FirebaseAuthException) {
    if (e.code == 'invalid-verification-code') {
      return 'Incorrect OTP. Please try again.';
    }
    if (e.code == 'session-expired' || e.code == 'code-expired') {
      return 'OTP expired. Please request a new code.';
    }
    final message = e.message ?? '';
    if (e.code == 'app-not-authorized' ||
        message.toLowerCase().contains('missing a valid app identifier')) {
      return 'Firebase phone OTP is not authorized for this APK. Add this app package and SHA-1/SHA-256 fingerprints in Firebase Console, download google-services.json, then rebuild.';
    }
    return message.isNotEmpty ? message : 'OTP failed. Please try again.';
  }
  final raw = e.toString();
  return raw
      .replaceFirst('AuthException(message: ', '')
      .replaceFirst(', statusCode: null)', '')
      .replaceFirst('Exception: ', '');
}
