import 'HandleBussiness.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:express_car/services/car_image_widget.dart';

class ManageCarsPage extends StatefulWidget {
  const ManageCarsPage({Key? key}) : super(key: key);

  @override
  State<ManageCarsPage> createState() => _ManageCarsPageState();
}

class _ManageCarsPageState extends State<ManageCarsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> cars = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOwnerCars();
  }

  Future<void> _loadOwnerCars() async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      QuerySnapshot snapshot;

      if (user == null) {
        snapshot = await _firestore.collection('cars').get();
      } else {
        // First try server-side filter by owner_email for efficiency.
        snapshot = await _firestore
            .collection('cars')
            .where('owner_email', isEqualTo: user.email)
            .get();
      }

      List<QueryDocumentSnapshot> docs = snapshot.docs;

      // If no docs returned for a signed-in user, fallback to fetching all cars and filter client-side.
      if (docs.isEmpty && user != null) {
        print(
          'No cars found with owner_email == ${user.email}. Falling back to full collection scan.',
        );
        final allSnap = await _firestore.collection('cars').get();
        docs = allSnap.docs.where((d) {
          final data = d.data();
          final owner =
              (data['owner_email'] ?? data['owner'] ?? data['ownerEmail'])
                  ?.toString();
          final ownerId =
              (data['owner_id'] ?? data['ownerId'] ?? data['owner_uid'])
                  ?.toString();
          return owner == user.email || ownerId == user.uid;
        }).toList();
      }

      final List<Map<String, dynamic>> loaded = docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final carIdVal = data['car_id'] ?? data['id'];
        final intCarId = carIdVal is int
            ? carIdVal
            : int.tryParse(carIdVal?.toString() ?? '') ?? 0;
        final priceVal = data['price_per_day'] ?? data['price'];
        return {
          'doc_id': doc.id,
          'car_id': intCarId,
          'name': data['name']?.toString() ?? 'Unknown',
          'model': data['model']?.toString() ?? '',
          'type': data['type']?.toString() ?? '',
          'number_plate': data['number_plate']?.toString() ?? '',
          'description': data['description']?.toString() ?? '',
          'price': priceVal?.toString() ?? '0',
          'image_url': data['image_url']?.toString() ?? '',
        };
      }).toList();

      setState(() {
        cars = loaded;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load cars: $e')));
    }
  }

  Future<bool> _deleteCar(String docId, int carId) async {
    try {
      // Delete car document
      await _firestore.collection('cars').doc(docId).delete();

      // Delete all bookings with this car_id
      final bookingsSnap = await _firestore
          .collection('bookings')
          .where('car_id', isEqualTo: carId)
          .get();

      final batch = _firestore.batch();
      for (final b in bookingsSnap.docs) {
        batch.delete(b.reference);
      }
      await batch.commit();

      setState(() {
        cars.removeWhere((c) => c['doc_id'] == docId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Car and related bookings deleted successfully'),
        ),
      );

      // Refresh the car list from the server
      await _loadOwnerCars();
      return true;
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      return false;
    }
  }

  Future<void> _showEditCarDialog(Map<String, dynamic> car) async {
    final nameController = TextEditingController(
      text: car['name']?.toString() ?? '',
    );
    final modelController = TextEditingController(
      text: car['model']?.toString() ?? '',
    );
    final typeController = TextEditingController(
      text: car['type']?.toString() ?? '',
    );
    final plateController = TextEditingController(
      text: car['number_plate']?.toString() ?? '',
    );
    final priceController = TextEditingController(
      text: car['price']?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: car['description']?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Car'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Car Name'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Car name required'
                      : null,
                ),
                TextFormField(
                  controller: modelController,
                  decoration: const InputDecoration(labelText: 'Model'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Model required'
                      : null,
                ),
                TextFormField(
                  controller: typeController,
                  decoration: const InputDecoration(labelText: 'Type'),
                ),
                TextFormField(
                  controller: plateController,
                  decoration: const InputDecoration(labelText: 'Number Plate'),
                ),
                TextFormField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Price / day'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Price required';
                    }
                    if (double.tryParse(value.trim()) == null) {
                      return 'Enter valid number';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: descriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true) {
      nameController.dispose();
      modelController.dispose();
      typeController.dispose();
      plateController.dispose();
      priceController.dispose();
      descriptionController.dispose();
      return;
    }

    try {
      await _firestore.collection('cars').doc(car['doc_id'] as String).update({
        'name': nameController.text.trim(),
        'model': modelController.text.trim(),
        'type': typeController.text.trim(),
        'number_plate': plateController.text.trim(),
        'price_per_day': double.parse(priceController.text.trim()),
        'description': descriptionController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Car updated successfully')));
      await _loadOwnerCars();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      nameController.dispose();
      modelController.dispose();
      typeController.dispose();
      plateController.dispose();
      priceController.dispose();
      descriptionController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Manage Cars",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HandleBusinessPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 10),
              const Text(
                "Your listed cars",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : (cars.isEmpty
                          ? const Center(child: Text('No cars found'))
                          : ListView.builder(
                              itemCount: cars.length,
                              itemBuilder: (context, index) {
                                final car = cars[index];
                                final price = car['price']?.toString() ?? '0';
                                final imageUrl =
                                    car['image_url'] as String? ?? '';

                                return Dismissible(
                                  key: ValueKey(car['doc_id']),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade400,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.white,
                                    ),
                                  ),
                                  confirmDismiss: (_) async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete car'),
                                        content: const Text(
                                          'Are you sure you want to delete this car and its bookings?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm != true) return false;
                                    return _deleteCar(
                                      car['doc_id'] as String,
                                      (car['car_id'] as int),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
                                          blurRadius: 5,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        // Car Image
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: SizedBox(
                                            height: 50,
                                            width: 70,
                                            child: CarApiImage(
                                              imageUrl: imageUrl,
                                              fallbackAssetPath:
                                                  'assets/images/Honda City.jpg',
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),

                                        const SizedBox(width: 12),

                                        // Car Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                car['name'] ?? 'Unknown',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                "${car['model'] ?? ''} - ₹$price/day",
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              const Text(
                                                'Swipe left to delete',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            color: Colors.blue,
                                          ),
                                          onPressed: () =>
                                              _showEditCarDialog(car),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
