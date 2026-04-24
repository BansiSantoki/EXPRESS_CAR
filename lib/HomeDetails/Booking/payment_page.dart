import 'package:flutter/material.dart';

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
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Cash on Pickup Confirmed'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Note: Please pay at pickup. Admin will mark your booking as paid after receiving payment.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
