import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:express_car/theme/app_theme.dart';

class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _surchargeController = TextEditingController();
  final _deliveryFeeController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _surchargeController.dispose();
    _deliveryFeeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('global_config')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _surchargeController.text =
            data['driverless_surcharge_percentage']?.toString() ?? '15';
        _deliveryFeeController.text = data['delivery_fee']?.toString() ?? '30';
      } else {
        // Defaults if document doesn't exist yet
        _surchargeController.text = '15';
        _deliveryFeeController.text = '30';
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      _surchargeController.text = '15';
      _deliveryFeeController.text = '30';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('global_config')
          .set({
            'driverless_surcharge_percentage':
                double.tryParse(_surchargeController.text.trim()) ?? 15.0,
            'delivery_fee':
                double.tryParse(_deliveryFeeController.text.trim()) ?? 30.0,
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Global settings saved successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save settings: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: const Text('Global App Settings')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primary, AppTheme.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dynamic Pricing',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Configure global fees and surcharges applied during user checkout.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Settings Form
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Driverless Surcharge (%)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Extra percentage charged on the base rental price when a user selects the "Driverless" option (to cover insurance/risk).',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _surchargeController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _inputDecoration(
                                'e.g. 15',
                                Icons.percent,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a percentage';
                                }
                                if (double.tryParse(value.trim()) == null) {
                                  return 'Please enter a valid number';
                                }
                                return null;
                              },
                            ),
                            const Divider(height: 32),

                            const Text(
                              'Delivery Fee (₹)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Flat fee applied to bookings for car delivery/pickup services.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _deliveryFeeController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _inputDecoration(
                                'e.g. 30',
                                Icons.currency_rupee,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a delivery fee';
                                }
                                if (double.tryParse(value.trim()) == null) {
                                  return 'Please enter a valid number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton.icon(
                                onPressed: _isSaving ? null : _saveSettings,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save),
                                label: Text(
                                  _isSaving ? 'Saving...' : 'Save Settings',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppTheme.primary),
      filled: true,
      fillColor: const Color(0xFFF8FBFF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
    );
  }
}
