import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:express_car/User/AddressPicker.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:express_car/theme/app_theme.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final String userEmail = FirebaseAuth.instance.currentUser!.email!;
  final double deliveryFee = 30.0;

  final TextEditingController _addressController = TextEditingController();
  double pickedLat = 0.0;
  double pickedLng = 0.0;

  late Razorpay _razorpay;
  String selectedPaymentMethod = "COD";
  // remember last attempted payment (including delivery fee) for retry/debug
  double? _lastAttemptAmount; // in rupees
  int? _lastAttemptAmountPaise;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _addressController.dispose();
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    // Debug log
    debugPrint(
      'Razorpay SUCCESS: paymentId=${response.paymentId}, orderId=${response.orderId}, signature=${response.signature}',
    );
    // Payment succeeded — save order and pass payment id
    final snap = await FirebaseFirestore.instance
        .collection('Carts')
        .doc(userEmail)
        .collection('Items')
        .get();
    double total = 0;
    for (var d in snap.docs) {
      var data = d.data() as Map<String, dynamic>;
      total += (data['price'] * data['qty']);
    }
    placeOrder(snap.docs, total, paymentId: response.paymentId);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint(
      'Razorpay ERROR: code=${response.code}, message=${response.message}',
    );
    final details = 'code=${response.code}\nmessage=${response.message}';
    if (!mounted) return;

    // Show a dialog with details and option to retry the last amount
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Payment Failed'),
        content: Text('Payment failed with:\n$details'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
          if (_lastAttemptAmount != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // retry using last attempted amount (minus delivery fee passed to openRazorpay expects base amount)
                final baseAmount = (_lastAttemptAmount! - deliveryFee);
                openRazorpay(baseAmount);
              },
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('Razorpay EXTERNAL WALLET: wallet=${response.walletName}');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("External Wallet Selected: ${response.walletName}"),
      ),
    );
  }

  void openRazorpay(double amount) {
    String finalAddress = _addressController.text.trim();
    if (finalAddress.isEmpty ||
        finalAddress == "Select your delivery address") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide an address first")),
      );
      return;
    }

    // NOTE: Using test key from project functions/.env; replace with your own test key if needed
    const razorpayTestKey = 'rzp_test_SlCHgjb14m72d1';

    int amountInPaise = ((amount + deliveryFee) * 100).toInt();
    // save attempt for retry/debug
    _lastAttemptAmount = amount + deliveryFee;
    _lastAttemptAmountPaise = amountInPaise;

    var options = {
      'key': razorpayTestKey,
      'amount': amountInPaise,
      'name': 'Express Car',
      'description': 'Payment for Order',
      'prefill': {
        'contact':
            FirebaseAuth.instance.currentUser?.phoneNumber ?? '9327077276',
        'email': userEmail,
      },
      'theme': {'color': '#0A6EBD'},
    };

    try {
      debugPrint('Opening Razorpay with options: $options');
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error opening Razorpay: $e")));
      }
    }
  }

  void placeOrder(
    List<DocumentSnapshot> cartItems,
    double total, {
    String? paymentId,
  }) async {
    String finalAddress = _addressController.text.trim();
    if (finalAddress.isEmpty ||
        finalAddress == "Select your delivery address") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide a delivery address")),
      );
      return;
    }

    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) =>
            Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );

      await FirebaseFirestore.instance.collection('Orders').add({
        'customerEmail': userEmail,
        'items': cartItems.map((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return {
            'name': data['name'],
            'price': data['price'],
            'qty': data['qty'],
            'size': data['size'] ?? "Small",
            'sugar': data['sugar'] ?? "Normal",
          };
        }).toList(),
        'totalAmount': total + deliveryFee,
        'status': 'Processing',
        'orderDate': FieldValue.serverTimestamp(),
        'address_text': finalAddress,
        'latitude': pickedLat,
        'longitude': pickedLng,
        'paymentMethod': selectedPaymentMethod,
        'paymentId': paymentId ?? "COD_ORDER",
      });

      for (var cartItemDoc in cartItems) {
        var cartData = cartItemDoc.data() as Map<String, dynamic>;
        var productQuery = await FirebaseFirestore.instance
            .collection('Products')
            .where('name', isEqualTo: cartData['name'])
            .get();
        if (productQuery.docs.isNotEmpty) {
          var pDoc = productQuery.docs.first;
          await pDoc.reference.update({
            'quantity': (pDoc['quantity'] ?? 0) - cartData['qty'],
          });
        }
      }

      var cartItemsRef = FirebaseFirestore.instance
          .collection('Carts')
          .doc(userEmail)
          .collection('Items');
      var snapshots = await cartItemsRef.get();
      for (var doc in snapshots.docs) {
        await doc.reference.delete();
      }

      if (mounted) Navigator.pop(context);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
          content: const Text(
            "Order Placed Successfully! ",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Text(
                  "OK",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5E6D3),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 70,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF0A6EBD)),
        title: const Text(
          "Checkout",
          style: TextStyle(
            color: Color(0xFF0A6EBD),
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('Carts')
            .doc(userEmail)
            .collection('Items')
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          var items = snapshot.data!.docs;
          double subtotal = 0;
          for (var d in items) {
            var data = d.data() as Map<String, dynamic>;
            subtotal += (data['price'] * data['qty']);
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Delivery Address",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0A6EBD),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final dynamic result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => const AddressPicker(),
                        ),
                      );
                      if (!mounted) return;
                      if (result != null && result is Map) {
                        setState(() {
                          _addressController.text = result['address'];
                          pickedLat = result['lat'];
                          pickedLng = result['lng'];
                        });
                      }
                    },
                    icon: const Icon(
                      Icons.map_rounded,
                      color: Color(0xFF0A6EBD),
                      size: 20,
                    ),
                    label: const Text(
                      "Use Map",
                      style: TextStyle(
                        color: Color(0xFF0A6EBD),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0A6EBD).withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _addressController,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: "Click 'Use Map'...",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(20),
                    prefixIcon: Icon(
                      Icons.location_on_rounded,
                      color: Colors.brown,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              const Text(
                "Payment Method",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0A6EBD),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    RadioListTile(
                      title: const Text("Cash on Delivery"),
                      value: "COD",
                      groupValue: selectedPaymentMethod,
                      activeColor: const Color(0xFF0A6EBD),
                      onChanged: (val) => setState(
                        () => selectedPaymentMethod = val.toString(),
                      ),
                    ),
                    RadioListTile(
                      title: const Text("Online Payment"),
                      value: "ONLINE",
                      groupValue: selectedPaymentMethod,
                      activeColor: const Color(0xFF0A6EBD),
                      onChanged: (val) => setState(
                        () => selectedPaymentMethod = val.toString(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
              const Text(
                "Order Summary",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0A6EBD),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0A6EBD).withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: items.map((doc) {
                    var item = doc.data() as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${item["name"]} x${item["qty"]}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "${item['size']} • ${item['sugar']}",
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "₹${item["price"] * item["qty"]}",
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0A6EBD),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0A6EBD).withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Subtotal"),
                        Text(
                          "₹$subtotal",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text("Delivery Fee"), Text("₹30")],
                    ),
                    const Divider(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Grand Total",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: Color(0xFF0A6EBD),
                          ),
                        ),
                        Text(
                          "₹${subtotal + 30}",
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            color: Color(0xFF0A6EBD),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100),
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A6EBD).withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('Carts')
                  .doc(userEmail)
                  .collection('Items')
                  .get()
                  .then((snap) {
                    double total = 0;
                    for (var d in snap.docs) {
                      var data = d.data() as Map<String, dynamic>;
                      total += (data['price'] * data['qty']);
                    }

                    if (selectedPaymentMethod == "ONLINE") {
                      openRazorpay(total);
                    } else {
                      placeOrder(snap.docs, total);
                    }
                  });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: Text(
              selectedPaymentMethod == "ONLINE" ? "Pay Now" : "Confirm Order",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
