import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:express_car/Handle_Car/Add_Car.dart';
import 'package:express_car/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class FleetDriverManagerPage extends StatefulWidget {
  const FleetDriverManagerPage({super.key});

  @override
  State<FleetDriverManagerPage> createState() =>
      _FleetDriverManagerPageState();
}

class _FleetDriverManagerPageState
    extends State<FleetDriverManagerPage>
    with SingleTickerProviderStateMixin {
  late final TabController tab;

  final fleetKey = GlobalKey<FormState>(),
      driverKey = GlobalKey<FormState>();

  final picker = ImagePicker();

  final cloudinary =
      CloudinaryPublic('dstlqyncg', 'carimages18', cache: false);

  bool savingFleet = false, savingDriver = false;

  String fleetType = 'driverless',
      fleetApproval = 'pending',
      driverStatus = 'available',
      driverApproval = 'pending';

  final fleetCtrls = {
    'name': TextEditingController(),
    'model': TextEditingController(),
    'location': TextEditingController(),
    'notes': TextEditingController(),
  };

  final driverCtrls = {
    'name': TextEditingController(),
    'phone': TextEditingController(),
    'aadhaar': TextEditingController(),
    'license': TextEditingController(),
    'rc': TextEditingController(),
    'insurance': TextEditingController(),
    'permit': TextEditingController(),
  };

  final Map<String, File?> files = {
    'Aadhaar Front': null,
    'Aadhaar Back': null,
    'License Image': null,
    'RC Image': null,
    'Insurance Image': null,
    'Permit Image': null,
  };

  final docs = [
    ['Aadhaar Card', 'Driver identity verification', Icons.badge_outlined],
    ['Driving License', 'Valid transport license', Icons.car_rental],
    ['RC Book', 'Vehicle registration proof', Icons.description_outlined],
    ['Insurance', 'Active policy document', Icons.verified_outlined],
    ['Permit', 'Commercial/local permit', Icons.policy_outlined],
    ['PUC / Fitness', 'Pollution & fitness', Icons.health_and_safety],
  ];

  @override
  void initState() {
    super.initState();
    tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    tab.dispose();

    for (var c in [...fleetCtrls.values, ...driverCtrls.values]) {
      c.dispose();
    }

    super.dispose();
  }

  Future<File?> pickImage() async {
    final x = await picker.pickImage(source: ImageSource.gallery);
    return x == null ? null : File(x.path);
  }

  Future<String?> upload(File? file, String folder) async {
    if (file == null) return null;

    final res = await cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        file.path,
        folder: folder,
        resourceType: CloudinaryResourceType.Image,
      ),
    );

    return res.secureUrl;
  }

  Future<void> saveFleet() async {
    if (!fleetKey.currentState!.validate()) return;

    setState(() => savingFleet = true);

    try {
      await FirebaseFirestore.instance.collection('fleet_items').add({
        'name': fleetCtrls['name']!.text.trim(),
        'model': fleetCtrls['model']!.text.trim(),
        'location': fleetCtrls['location']!.text.trim(),
        'notes': fleetCtrls['notes']!.text.trim(),
        'fleetType': fleetType,
        'approvalStatus': fleetApproval,
        'createdAt': FieldValue.serverTimestamp(),
      });

      fleetCtrls.values.forEach((e) => e.clear());

      snack('Fleet item added successfully.');
    } catch (e) {
      snack('Error : $e');
    }

    setState(() => savingFleet = false);
  }

  Future<void> saveDriver() async {
    if (!driverKey.currentState!.validate()) return;

    setState(() => savingDriver = true);

    try {
      await FirebaseFirestore.instance
          .collection('driver_documents')
          .add({
        'driverName': driverCtrls['name']!.text.trim(),
        'phone': driverCtrls['phone']!.text.trim(),
        'aadhaarNumber': driverCtrls['aadhaar']!.text.trim(),
        'licenseNumber': driverCtrls['license']!.text.trim(),
        'rcNumber': driverCtrls['rc']!.text.trim(),
        'insuranceNumber': driverCtrls['insurance']!.text.trim(),
        'permitNumber': driverCtrls['permit']!.text.trim(),
        'availability': driverStatus,
        'approvalStatus': driverApproval,

        'aadhaarFrontUrl':
            await upload(files['Aadhaar Front'], 'driver_docs/aadhaar_front'),

        'aadhaarBackUrl':
            await upload(files['Aadhaar Back'], 'driver_docs/aadhaar_back'),

        'licenseUrl':
            await upload(files['License Image'], 'driver_docs/license'),

        'rcUrl':
            await upload(files['RC Image'], 'driver_docs/rc'),

        'insuranceUrl':
            await upload(files['Insurance Image'], 'driver_docs/insurance'),

        'permitUrl':
            await upload(files['Permit Image'], 'driver_docs/permit'),

        'createdAt': FieldValue.serverTimestamp(),
      });

      driverCtrls.values.forEach((e) => e.clear());

      files.updateAll((key, value) => null);

      snack('Driver documents saved.');
    } catch (e) {
      snack('Error : $e');
    }

    setState(() => savingDriver = false);
  }

  void snack(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: const Text('Fleet & Driver Management'),
        bottom: TabBar(
          controller: tab,
          labelColor: AppTheme.primary,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Fleet'),
            Tab(text: 'Drivers'),
            Tab(text: 'Docs'),
            Tab(text: 'Vehicle Add'),
          ],
        ),
      ),
      body: TabBarView(
        controller: tab,
        children: [
          fleetTab(),
          driverTab(),
          docsTab(),
          vehicleTab(),
        ],
      ),
    );
  }

  Widget fleetTab() => scroll(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header(
              'Driverless or With Driver',
              'Create car categories and manage fleet.',
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: choice(
                    'Driverless',
                    'Self-drive fleet',
                    Icons.directions_car,
                    fleetType == 'driverless',
                    () => setState(() => fleetType = 'driverless'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: choice(
                    'With Driver',
                    'Driver included',
                    Icons.person_pin,
                    fleetType == 'with_driver',
                    () => setState(() => fleetType = 'with_driver'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            card(
              Form(
                key: fleetKey,
                child: Column(
                  children: [
                    field(fleetCtrls['name']!, 'Car Name',
                        Icons.directions_car),

                    field(fleetCtrls['model']!, 'Model / Variant',
                        Icons.confirmation_number),

                    field(fleetCtrls['location']!, 'Location',
                        Icons.location_on_outlined),

                    field(
                      fleetCtrls['notes']!,
                      'Notes',
                      Icons.notes,
                      max: 3,
                    ),

                    dropdown(
                      fleetApproval,
                      'Approval Status',
                      Icons.verified_user_outlined,
                      ['pending', 'approved', 'rejected'],
                      (v) => setState(() => fleetApproval = v!),
                    ),

                    btn(
                      savingFleet,
                      'Save Fleet Item',
                      Icons.save_outlined,
                      saveFleet,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            liveList('fleet_items', 'No fleet items yet.')
          ],
        ),
      );

  Widget driverTab() => scroll(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header(
              'Driver Documents',
              'Store Aadhaar, license, RC and insurance.',
            ),

            const SizedBox(height: 16),

            card(
              Form(
                key: driverKey,
                child: Column(
                  children: [
                    ...[
                      ['name', 'Driver Name', Icons.person],
                      ['phone', 'Phone Number', Icons.phone],
                      ['aadhaar', 'Aadhaar Number',
                        Icons.badge_outlined],
                      ['license', 'License Number',
                        Icons.credit_card],
                      ['rc', 'RC Number',
                        Icons.description_outlined],
                      ['insurance', 'Insurance Number',
                        Icons.verified_outlined],
                      ['permit', 'Permit Number',
                        Icons.policy_outlined],
                    ].map(
                      (e) => field(
                        driverCtrls[e[0]] as TextEditingController,
                        e[1] as String,
                        e[2] as IconData,
                      ),
                    ),

                    ...files.entries.map(
                      (e) => uploadRow(e.key, e.value),
                    ),

                    dropdown(
                      driverStatus,
                      'Availability',
                      Icons.toggle_on,
                      ['available', 'busy', 'inactive'],
                      (v) => setState(() => driverStatus = v!),
                    ),

                    const SizedBox(height: 12),

                    dropdown(
                      driverApproval,
                      'Approval Status',
                      Icons.verified_user_outlined,
                      ['pending', 'approved', 'rejected'],
                      (v) => setState(() => driverApproval = v!),
                    ),

                    btn(
                      savingDriver,
                      'Save Driver Documents',
                      Icons.badge_outlined,
                      saveDriver,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            liveList(
              'driver_documents',
              'No driver documents saved yet.',
            ),
          ],
        ),
      );

  Widget docsTab() => scroll(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header(
              'Required Documents',
              'Checklist for verification.',
            ),

            const SizedBox(height: 16),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              itemBuilder: (_, i) {
                final d = docs[i];

                return card(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: AppTheme.primarySoft,
                        child: Icon(
                          d[2] as IconData,
                          color: AppTheme.primary,
                        ),
                      ),

                      const Spacer(),

                      Text(
                        d[0] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        d[1] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );

  Widget vehicleTab() => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header(
              'Vehicle Add Form',
              'Use existing add car form.',
            ),

            const SizedBox(height: 16),

            card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add new vehicle to Firestore.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Open Add Vehicle Form'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddCarPage(),
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      );

  Widget liveList(String col, String empty) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(col)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (_, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!s.hasData || s.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Center(child: Text(empty)),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (_, __) =>
              const SizedBox(height: 10),
          itemCount: s.data!.docs.length,
          itemBuilder: (_, i) {
            final d =
                s.data!.docs[i].data() as Map<String, dynamic>;

            final title =
                d['name'] ?? d['driverName'] ?? 'Untitled';

            final sub =
                d['fleetType'] ?? d['availability'] ?? '';

            final status =
                d['approvalStatus'] ?? 'pending';

            return card(
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primarySoft,
                    child: Icon(
                      col == 'fleet_items'
                          ? Icons.directions_car
                          : Icons.badge,
                      color: AppTheme.primary,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(sub),

                        const SizedBox(height: 6),

                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(50),
                            border: Border.all(
                              color: AppTheme.border,
                            ),
                          ),
                          child: Text(
                            status.toString().toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget uploadRow(String label, File? file) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FBFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.upload_file,
              color: AppTheme.primary,
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Text(
                file == null
                    ? label
                    : '$label selected',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            TextButton(
              child: const Text('Choose'),
              onPressed: () async {
                files[label] = await pickImage();
                setState(() {});
              },
            )
          ],
        ),
      );

  Widget field(
    TextEditingController c,
    String label,
    IconData icon, {
    int max = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          maxLines: max,
          validator: (v) =>
              v == null || v.trim().isEmpty
                  ? 'Please enter $label'
                  : null,
          decoration: input(label, icon),
        ),
      );

  Widget dropdown(
    String value,
    String label,
    IconData icon,
    List<String> items,
    Function(String?) onChanged,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          value: value,
          decoration: input(label, icon),
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    e[0].toUpperCase() + e.substring(1),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      );

  Widget btn(
    bool loading,
    String text,
    IconData icon,
    VoidCallback onTap,
  ) =>
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: loading ? null : onTap,
          icon: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(icon),
          label: Text(loading ? 'Saving...' : text),
        ),
      );

  Widget scroll(Widget child) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      );

  Widget card(Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: child,
      );

  Widget header(String t, String s) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [
              AppTheme.primary,
              AppTheme.primaryDark,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              s,
              style: const TextStyle(
                color: Colors.white70,
              ),
            ),
          ],
        ),
      );

  Widget choice(
    String title,
    String sub,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:
                selected ? AppTheme.primarySoft : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? AppTheme.primary
                  : AppTheme.border,
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  icon,
                  color: AppTheme.primary,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                sub,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      );

  InputDecoration input(
    String label,
    IconData icon,
  ) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          color: AppTheme.primary,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FBFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppTheme.primary,
            width: 1.5,
          ),
        ),
      );
}