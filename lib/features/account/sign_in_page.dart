import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

String accountError(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => 'Enter a valid email address.',
      'email-already-in-use' =>
        'This email already has an account. Sign in instead.',
      'weak-password' =>
        'Choose a stronger password with at least 6 characters.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'Email or password is incorrect.',
      'network-request-failed' => 'Check your connection and try again.',
      'too-many-requests' => 'Too many attempts. Wait a moment and try again.',
      'operation-not-allowed' =>
        'Email sign-in is not enabled yet. Contact the project owner.',
      'user-disabled' => 'This account is disabled. Contact the project owner.',
      _ => 'Could not complete the request. Please try again.',
    };
  }
  return 'Could not complete the request. Check your connection and try again.';
}

class SignInPage extends StatefulWidget {
  const SignInPage({
    super.key,
    required this.authenticate,
    required this.resetPassword,
  });
  final Future<void> Function(String email, String password, bool create)
  authenticate;
  final Future<void> Function(String email) resetPassword;
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _create = false, _busy = false, _hidden = true;
  String? _message;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _emailError(String? value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')
      ? null
      : 'Enter a valid email address.';

  Future<void> _submit({bool reset = false}) async {
    if (_busy) return;
    if (reset
        ? _emailError(_email.text) != null
        : !_form.currentState!.validate()) {
      if (reset) setState(() => _message = 'Enter your email address first.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (reset) {
        await widget.resetPassword(_email.text.trim());
        if (mounted) {
          setState(
            () => _message = 'If an account exists for this email, a reset link has been sent.',
          );
        }
      } else {
        await widget.authenticate(_email.text.trim(), _password.text, _create);
      }
    } catch (error) {
      if (mounted) setState(() => _message = accountError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.kitchen, size: 48),
              const SizedBox(height: 12),
              Text(
                'PantryPal',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _create ? 'Create your account' : 'Sign in to your household',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _email,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                validator: _emailError,
              ),
              TextFormField(
                controller: _password,
                enabled: !_busy,
                obscureText: _hidden,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    tooltip: _hidden ? 'Show password' : 'Hide password',
                    onPressed: _busy
                        ? null
                        : () => setState(() => _hidden = !_hidden),
                    icon: Icon(
                      _hidden ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
                validator: (value) => (value ?? '').isEmpty
                    ? 'Enter your password.'
                    : _create && value!.length < 6
                    ? 'Use at least 6 characters.'
                    : null,
              ),
              if (_create)
                TextFormField(
                  controller: _confirm,
                  enabled: !_busy,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                  ),
                  validator: (value) =>
                      value != _password.text ? 'Passwords must match.' : null,
                ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_message!, semanticsLabel: _message),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : () => _submit(),
                child: Text(
                  _busy
                      ? 'Please wait...'
                      : _create
                      ? 'Create account'
                      : 'Sign in',
                ),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _create = !_create;
                        _message = null;
                        _password.clear();
                        _confirm.clear();
                        _form.currentState!.reset();
                      }),
                child: Text(
                  _create
                      ? 'Already have an account? Sign in'
                      : 'Create an account',
                ),
              ),
              if (!_create)
                TextButton(
                  onPressed: _busy ? null : () => _submit(reset: true),
                  child: const Text('Forgot password?'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
