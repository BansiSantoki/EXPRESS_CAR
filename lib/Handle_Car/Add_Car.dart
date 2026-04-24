import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:express_car/Handle_Car/HandleBussiness.dart';
import 'package:express_car/HomeDetails/Home_Page/car_model.dart';
import 'package:express_car/services/imgbb_upload_service.dart';
import 'Done.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddCarPage extends StatefulWidget {
  const AddCarPage({Key? key}) : super(key: key);

  @override
  State<AddCarPage> createState() => _AddCarPageState();
}

class _AddCarPageState extends State<AddCarPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  static const String _fallbackAdminEmail = 'admin@expresscar.com';
  static const String _fallbackAdminUid = 'admin';

  final TextEditingController carNameController = TextEditingController();
  final TextEditingController modelController = TextEditingController();
  final TextEditingController numberPlateController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController priceWeekController = TextEditingController();
  final TextEditingController priceMonthController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  File? _carImage;
  String? _selectedAssetPath;
  final ImagePicker _picker = ImagePicker();

  String? _selectedCarType;
  List<String> _selectedFeatures = [];

  // Car features
  final List<String> carFeatures = [
    "Petrol engine",
    "Diesel engine",
    "CNG engine",
    "Hybrid engine",
    "Electric motor",
    "Manual gearbox",
    "Automatic gearbox",
    "Power steering",
    "Air conditioning",
    "Sunroof",
    "Alloy wheels",
    "Touchscreen",
    "Android Auto",
    "Apple CarPlay",
    "ABS",
    "Airbags",
    "Rear camera",
    "Cruise control",
    "Bluetooth",
    "Navigation",
  ];

  // Car types
  final List<String> carTypes = [
    "Hatchback",
    "Sedan",
    "SUV",
    "Luxury",
    "Electric (EV)",
    "Sports",
  ];

  String _canonicalCarType(String? selected) {
    final raw = (selected ?? '').trim();
    if (raw.isEmpty) return 'Sedan';

    final normalized = raw.toLowerCase();
    if (normalized.contains('hatch')) return 'Hatchback';
    if (normalized == 'sedan') return 'Sedan';
    if (normalized.contains('suv')) return 'SUV';
    if (normalized.contains('lux')) return 'Luxury';
    if (normalized.contains('electric') || normalized.contains('ev')) {
      return 'Electric (EV)';
    }
    if (normalized.contains('sport') ||
        normalized == 'coupe' ||
        normalized == 'convertible' ||
        normalized == 'roadster') {
      return 'Sports';
    }

    return 'Sedan';
  }

  // Pick image
  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _carImage = File(pickedFile.path);
          _selectedAssetPath = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error picking image: $e")));
    }
  }

  void _selectAssetImage(String assetPath) {
    setState(() {
      _selectedAssetPath = assetPath;
      _carImage = null;
    });
    Navigator.pop(context);
  }

  Future<void> _pickAssetImage() async {
    List<String> availableAssets = carFallbackAssetPaths;
    final excludedAssetNames = {
      'google.jpg',
      'profile.jpg',
      'changepassword.jpg',
      'forgotpassword.jpg',
      'complete_profile.jpg',
      'enter_otp1.png',
      'done.jpg',
      'splash.jpg',
      'startcar.jpg',
    }.map((s) => s.toLowerCase()).toSet();

    try {
      final manifest = await rootBundle.loadString('AssetManifest.json');
      final decoded = jsonDecode(manifest) as Map<String, dynamic>;
      final imageAssets = decoded.keys.where((asset) {
        if (!asset.startsWith('assets/images/')) {
          return false;
        }

        final lowerPath = asset.toLowerCase();
        final fileName = asset.split('/').last.toLowerCase();
        final hasImageExtension =
            lowerPath.endsWith('.jpg') ||
            lowerPath.endsWith('.jpeg') ||
            lowerPath.endsWith('.png') ||
            lowerPath.endsWith('.webp');

        return hasImageExtension && !excludedAssetNames.contains(fileName);
      }).toList()..sort();

      if (imageAssets.isNotEmpty) {
        availableAssets = imageAssets;
      }
    } catch (_) {
      // Fall back to the curated list when the asset manifest is unavailable.
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose a car image',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 420,
                  child: GridView.builder(
                    itemCount: availableAssets.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.25,
                        ),
                    itemBuilder: (context, index) {
                      final assetPath = availableAssets[index];
                      return GestureDetector(
                        onTap: () => _selectAssetImage(assetPath),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey),
                            image: DecorationImage(
                              image: AssetImage(assetPath),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Get the next car ID using a Firestore transaction
  Future<int> _getNextCarId() async {
    final counterRef = FirebaseFirestore.instance
        .collection('counters')
        .doc('car_counter');

    return FirebaseFirestore.instance.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(counterRef);

      if (!snapshot.exists) {
        transaction.set(counterRef, {'current_id': 1});
        return 1;
      }

      final newId = (snapshot.data()!['current_id'] as int) + 1;
      transaction.update(counterRef, {'current_id': newId});
      return newId;
    });
  }

  Map<String, String> _resolveOwnerIdentity() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return {'email': user.email ?? _fallbackAdminEmail, 'uid': user.uid};
    }

    return {'email': _fallbackAdminEmail, 'uid': _fallbackAdminUid};
  }

  String _safeStorageName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    return cleaned.isEmpty ? 'car_image' : cleaned;
  }

  Future<String> _uploadCarImage({required String imageName}) async {
    if (_selectedAssetPath != null) {
      return _selectedAssetPath!;
    }

    try {
      return await uploadFileToImgbb(_carImage!, fileName: imageName);
    } on ImgbbUploadException {
      rethrow;
    }
  }

  // Save car
  Future<void> _saveCar() async {
    if (_formKey.currentState!.validate() &&
        (_carImage != null || _selectedAssetPath != null) &&
        _selectedCarType != null &&
        _selectedFeatures.isNotEmpty) {
      setState(() => _isSaving = true);

      try {
        final imageName =
            '${carNameController.text.trim()}_${modelController.text.trim()}';
        final safeImageName = _safeStorageName(imageName);
        final imageUrl = await _uploadCarImage(imageName: safeImageName);
        if (imageUrl.trim().isEmpty) {
          throw Exception(
            'Image upload failed. Please try selecting the image again.',
          );
        }

        final owner = _resolveOwnerIdentity();

        final carId = await _getNextCarId();
        final canonicalCarType = _canonicalCarType(_selectedCarType);

        // 3. Prepare data for Firestore
        final carData = {
          'car_id': carId,
          'owner_email': owner['email'],
          'owner_uid': owner['uid'],
          'name': carNameController.text,
          'model': modelController.text,
          'type': canonicalCarType,
          'number_plate': numberPlateController.text,
          'features': _selectedFeatures,
          'price_per_day': double.tryParse(priceController.text),
          'price_per_week':
              double.tryParse(priceWeekController.text) ??
              ((double.tryParse(priceController.text) ?? 0) * 7),
          'price_per_month':
              double.tryParse(priceMonthController.text) ??
              ((double.tryParse(priceController.text) ?? 0) * 30),
          'description': descriptionController.text,
          'image_url': imageUrl,
          'created_at': FieldValue.serverTimestamp(),
        };

        // 4. Save to Firestore
        await FirebaseFirestore.instance
            .collection('cars')
            .doc(carId.toString())
            .set(carData);

        setState(() {
          _carImage = null;
          _selectedAssetPath = null;
          _selectedCarType = null;
          _selectedFeatures = [];
        });
        _formKey.currentState?.reset();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const FinalDonePage()),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to save car: $e")));
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fill all fields and selections!")),
      );
    }
  }

  // TextField builder
  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String? Function(String?) validator, {
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          hintText: label,
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildImagePickerCard() {
    final hasAssetImage = _selectedAssetPath != null;
    final hasFileImage = _carImage != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 160,
              child: hasAssetImage
                  ? Image.asset(_selectedAssetPath!, fit: BoxFit.cover)
                  : hasFileImage
                  ? Image.file(_carImage!, fit: BoxFit.cover)
                  : Container(
                      color: Colors.white,
                      child: const Center(child: Text('Upload car photo')),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickAssetImage,
                  icon: const Icon(Icons.collections_outlined),
                  label: const Text('Choose assets'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Searchable Car Type
  Widget _buildCarTypeField() {
    return GestureDetector(
      onTap: () {
        _openSearchDialog(
          title: "Select Car Type",
          items: carTypes,
          isMulti: false,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedCarType ?? "Select Car Type",
              style: TextStyle(
                color: _selectedCarType == null ? Colors.grey : Colors.black,
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  // Searchable Features
  Widget _buildFeatureField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            _openSearchDialog(
              title: "Select Car Features",
              items: carFeatures,
              isMulti: true,
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedFeatures.isEmpty
                      ? "Select Features"
                      : "${_selectedFeatures.length} Selected",
                  style: TextStyle(
                    color: _selectedFeatures.isEmpty
                        ? Colors.grey
                        : Colors.black,
                  ),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
        if (_selectedFeatures.isNotEmpty)
          Wrap(
            spacing: 8,
            children: _selectedFeatures
                .map(
                  (f) => Chip(
                    label: Text(f),
                    onDeleted: () {
                      setState(() {
                        _selectedFeatures.remove(f);
                      });
                    },
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  // Reusable search dialog
  void _openSearchDialog({
    required String title,
    required List<String> items,
    required bool isMulti,
  }) {
    List<String> filtered = List.from(items);
    List<String> tempSelected = List.from(_selectedFeatures);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: "Search...",
                      prefixIcon: Icon(Icons.search),
                      filled: true,
                      fillColor: Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        filtered = items
                            .where(
                              (i) =>
                                  i.toLowerCase().contains(val.toLowerCase()),
                            )
                            .toList();
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, index) {
                        final item = filtered[index];
                        final isSelected = isMulti
                            ? tempSelected.contains(item)
                            : _selectedCarType == item;
                        return ListTile(
                          title: Text(item),
                          trailing: isMulti
                              ? Checkbox(
                                  value: isSelected,
                                  onChanged: (val) {
                                    setModalState(() {
                                      if (val == true) {
                                        tempSelected.add(item);
                                      } else {
                                        tempSelected.remove(item);
                                      }
                                    });
                                  },
                                )
                              : isSelected
                              ? const Icon(Icons.check, color: Colors.green)
                              : null,
                          onTap: () {
                            if (isMulti) {
                              setModalState(() {
                                if (tempSelected.contains(item)) {
                                  tempSelected.remove(item);
                                } else {
                                  tempSelected.add(item);
                                }
                              });
                            } else {
                              setState(() {
                                _selectedCarType = item;
                              });
                              Navigator.pop(context);
                            }
                          },
                        );
                      },
                    ),
                  ),
                  if (isMulti)
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedFeatures = List.from(tempSelected);
                        });
                        Navigator.pop(context);
                      },
                      child: const Text("Done"),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ListView(
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    const Text(
                      "Add Car",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w500,
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
                const SizedBox(height: 20),

                _buildImagePickerCard(),
                const SizedBox(height: 20),

                // Input fields
                _buildTextField(
                  "Car Name",
                  carNameController,
                  (val) => val!.isEmpty ? "Car name required" : null,
                ),
                _buildTextField(
                  "Model",
                  modelController,
                  (val) => val!.isEmpty ? "Model required" : null,
                ),

                // Car Type dropdown
                _buildCarTypeField(),

                _buildTextField(
                  "Car Number Plate",
                  numberPlateController,
                  (val) => val!.isEmpty ? "Plate required" : null,
                ),

                // Features dropdown
                _buildFeatureField(),

                _buildTextField("Price / day", priceController, (value) {
                  if (value!.isEmpty) return "Price required";
                  if (double.tryParse(value) == null) {
                    return "Enter number";
                  }
                  return null;
                }),

                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        "Price / week",
                        priceWeekController,
                        (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null;
                          }
                          if (double.tryParse(value) == null) {
                            return "Enter number";
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        "Price / month",
                        priceMonthController,
                        (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null;
                          }
                          if (double.tryParse(value) == null) {
                            return "Enter number";
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                _buildTextField(
                  "Description",
                  descriptionController,
                  (val) => val!.isEmpty ? "Description required" : null,
                  maxLines: 3,
                ),

                const SizedBox(height: 20),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveCar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 63, 34, 26),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Save Car",
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
