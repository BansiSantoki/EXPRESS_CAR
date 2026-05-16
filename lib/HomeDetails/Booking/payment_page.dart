import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({
    super.key,
    required this.bookingId,
    required this.amount,
    required this.paymentMethod,
  });

  final String bookingId;
  final num amount;
  final String paymentMethod;

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  static const String _defaultCurrency = 'INR';
  static const String _fallbackRazorpayKeyId = 'rzp_test_SlCHgjb14m72d1';
  static const String _definedRazorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
  );
  static const String _createOrderUrl = String.fromEnvironment(
    'PAYMENT_CREATE_ORDER_URL',
  );
  static const String _verifyPaymentUrl = String.fromEnvironment(
    'PAYMENT_VERIFY_URL',
  );
  static const String _paymentFailureUrl = String.fromEnvironment(
    'PAYMENT_FAILURE_URL',
  );

  late final Razorpay _razorpay;
  bool _isProcessing = false;
  String? _createdOrderId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<String> _requireIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Sign in required before payment.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('Unable to get auth token for payment.');
    }
    return token;
  }

  int _toPaisa(num amount) {
    if (amount <= 0) return 0;
    return (amount * 100).round();
  }

  Future<Map<String, dynamic>> _postJson({
    required String url,
    required Map<String, dynamic> body,
  }) async {
    final token = await _requireIdToken();
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    final payload = response.body.trim().isEmpty
        ? <String, dynamic>{}
        : (jsonDecode(response.body) as Map<String, dynamic>);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          payload['error']?.toString() ??
          'Request failed with status ${response.statusCode}';
      throw Exception(message);
    }

    return payload;
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  String get _effectiveRazorpayKeyId {
    return _definedRazorpayKeyId.isNotEmpty
        ? _definedRazorpayKeyId
        : _fallbackRazorpayKeyId;
  }

  bool get _hasServerPaymentConfig =>
      _createOrderUrl.isNotEmpty &&
      _verifyPaymentUrl.isNotEmpty &&
      _paymentFailureUrl.isNotEmpty;

  Future<void> _openDirectRazorpay({String? orderId}) async {
    final user = FirebaseAuth.instance.currentUser;
    final options = {
      'key': _effectiveRazorpayKeyId,
      'amount': _toPaisa(widget.amount),
      'name': 'Express Car',
      'description': 'Booking ${widget.bookingId}',
      'currency': _defaultCurrency,
      'prefill': {
        'email': user?.email ?? '',
        'contact': user?.phoneNumber ?? '',
      },
      'notes': {
        'booking_id': widget.bookingId,
        if (orderId != null && orderId.isNotEmpty) 'order_id': orderId,
      },
    };

    debugPrint('Opening Razorpay directly with options: $options');
    _razorpay.open(options);
  }

  Future<void> _startOnlinePayment() async {
    if (_isProcessing) return;

    final bool hasServerUrls = _hasServerPaymentConfig;
    final createOrderUrl = _createOrderUrl;

    final amountInPaisa = _toPaisa(widget.amount);
    if (amountInPaisa <= 0) {
      _showMessage('Invalid payment amount.', isError: true);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (hasServerUrls) {
        // Create order on server and use returned order_id
        final orderPayload = await _postJson(
          url: createOrderUrl,
          body: {
            'booking_id': widget.bookingId,
            'amount': amountInPaisa,
            'currency': _defaultCurrency,
          },
        );

        final orderId = orderPayload['order_id']?.toString().trim() ?? '';
        final keyFromServer = orderPayload['key_id']?.toString().trim() ?? '';
        final effectiveKeyId = keyFromServer.isNotEmpty
            ? keyFromServer
            : _definedRazorpayKeyId;

        if (orderId.isEmpty || effectiveKeyId.isEmpty) {
          throw Exception('Payment configuration incomplete.');
        }

        _createdOrderId = orderId;

        final options = {
          'key': effectiveKeyId,
          'amount': amountInPaisa,
          'name': 'Express Car',
          'description': 'Booking ${widget.bookingId}',
          'order_id': orderId,
          'currency': _defaultCurrency,
          'prefill': {
            'email': user?.email ?? '',
            'contact': user?.phoneNumber ?? '',
          },
          'notes': {'booking_id': widget.bookingId},
        };

        _razorpay.open(options);
      } else {
        await _openDirectRazorpay();
      }
    } catch (error) {
      debugPrint(
        'Server payment failed, falling back to direct Razorpay: $error',
      );
      if (hasServerUrls) {
        try {
          await _openDirectRazorpay();
          return;
        } catch (fallbackError) {
          _showMessage(
            'Unable to start payment: $fallbackError',
            isError: true,
          );
        }
      } else {
        _showMessage('Unable to start payment: $error', isError: true);
      }
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final bool hasServerUrls = _hasServerPaymentConfig;
      final verifyPaymentUrl = _verifyPaymentUrl;

      if (hasServerUrls) {
        final orderId = response.orderId?.trim().isNotEmpty == true
            ? response.orderId!.trim()
            : (_createdOrderId ?? '');

        if (orderId.isEmpty) {
          throw Exception('Missing order id for verification.');
        }

        await _postJson(
          url: verifyPaymentUrl,
          body: {
            'booking_id': widget.bookingId,
            'razorpay_payment_id': response.paymentId ?? '',
            'razorpay_order_id': orderId,
            'razorpay_signature': response.signature ?? '',
          },
        );

        _showMessage('Payment verified successfully.');
        if (mounted) Navigator.pop(context, true);
      } else {
        _showMessage('Payment successful.');
        if (mounted) Navigator.pop(context, true);
      }
    } catch (error) {
      _showMessage('Payment verification failed: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _onPaymentError(PaymentFailureResponse response) async {
    try {
      final bool hasServerUrls = _hasServerPaymentConfig;
      if (hasServerUrls) {
        await _postJson(
          url: _paymentFailureUrl,
          body: {
            'booking_id': widget.bookingId,
            'payment_id': '',
            'reason': response.message ?? 'Payment failed',
          },
        );
      }
    } catch (_) {
      // UI already communicates failure; backend update best-effort.
    } finally {
      _showMessage('Payment failed. Please try again.', isError: true);
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    _showMessage(
      'External wallet selected: ${response.walletName ?? 'unknown'}',
    );
    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amountLabel = widget.amount.toStringAsFixed(0);

    return Scaffold(
      appBar: AppBar(title: const Text('Complete Payment')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Booking ID: ${widget.bookingId}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Amount: Rs $amountLabel',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Method: ${widget.paymentMethod}',
                    style: const TextStyle(color: Color(0xFF4B5563)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _startOnlinePayment,
              icon: _isProcessing
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.payment),
              label: Text(_isProcessing ? 'Processing...' : 'Pay Online'),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Use Cash on Pickup'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Online payment marks your booking as paid after backend verification. Cash on pickup keeps payment pending until manually confirmed.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
