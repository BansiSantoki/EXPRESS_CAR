import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../Authentication/signin_page.dart';
import '../HomeDetails/Home_Page/home_page.dart';
import 'package:express_car/services/user_presence_service.dart';
import '../HomeDetails/Home_Page/car_data.dart';
import '../HomeDetails/Home_Page/car_model.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Car? _left;
  Car? _right;

  void _openHome() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HomePage()),
    );
  }

  void _logout() async {
    await UserPresenceService.markCurrentUserOffline();
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => SignInPage()),
      (route) => false,
    );
  }

  void _showCarPicker(bool isLeft) async {
    final selected = await showModalBottomSheet<Car?>(
      context: context,
      builder: (ctx) {
        final list = cars;
        return SafeArea(
          child: ListView.separated(
            padding: EdgeInsets.all(12),
            itemBuilder: (c, i) {
              final car = list[i];
              return ListTile(
                leading: SizedBox(
                  width: 72,
                  height: 48,
                  child: car.imageUrl != null
                      ? Image.network(car.imageUrl!, fit: BoxFit.cover)
                      : Image.asset(car.fallbackAssetPath, fit: BoxFit.cover),
                ),
                title: Text(car.name),
                subtitle: Text('Rs ${car.pricePerDay.toStringAsFixed(0)}/day'),
                onTap: () => Navigator.of(ctx).pop(car),
              );
            },
            separatorBuilder: (_, __) => Divider(),
            itemCount: list.length,
          ),
        );
      },
    );

    if (selected == null) return;
    setState(() {
      if (isLeft)
        _left = selected;
      else
        _right = selected;
    });
  }

  void _compareNow() {
    if (_left == null && _right == null) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Compare'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_left != null)
                Text('${_left!.name} — Rs ${_left!.pricePerDay}/day'),
              if (_right != null)
                Text('${_right!.name} — Rs ${_right!.pricePerDay}/day'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _compareCard(Car? car, bool isLeft) {
    return Expanded(
      child: InkWell(
        onTap: () => _showCarPicker(isLeft),
        child: Container(
          height: 110,
          margin: EdgeInsets.all(8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (car == null) ...[
                Icon(
                  Icons.directions_car_outlined,
                  size: 36,
                  color: Colors.teal,
                ),
                SizedBox(height: 8),
                Text('Select Car', style: TextStyle(color: Colors.blue)),
              ] else ...[
                SizedBox(
                  height: 48,
                  child: car.imageUrl != null
                      ? Image.network(car.imageUrl!, fit: BoxFit.contain)
                      : Image.asset(car.fallbackAssetPath, fit: BoxFit.contain),
                ),
                SizedBox(height: 6),
                Text(car.name, style: TextStyle(fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPopularComparisons() {
    final List<Widget> tiles = [];
    final list = cars;
    for (var i = 0; i + 1 < list.length && tiles.length < 6; i += 2) {
      final a = list[i];
      final b = list[i + 1];
      tiles.add(
        Container(
          margin: EdgeInsets.symmetric(vertical: 8),
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 60,
                      child: a.imageUrl != null
                          ? Image.network(a.imageUrl!, fit: BoxFit.cover)
                          : Image.asset(a.fallbackAssetPath, fit: BoxFit.cover),
                    ),
                    SizedBox(height: 6),
                    Text(a.name, style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      'Rs ${a.pricePerDay.toStringAsFixed(0)}',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.orange[50],
                  child: Text('VS'),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 60,
                      child: b.imageUrl != null
                          ? Image.network(b.imageUrl!, fit: BoxFit.cover)
                          : Image.asset(b.fallbackAssetPath, fit: BoxFit.cover),
                    ),
                    SizedBox(height: 6),
                    Text(b.name, style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      'Rs ${b.pricePerDay.toStringAsFixed(0)}',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Log Out',
            onPressed: _logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good ${DateTime.now().hour < 12 ? 'Morning' : 'Evening'},',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 4),
            Text(
              user?.email ?? 'No email',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _openHome,
              child: const Text('Go to Home'),
            ),
            SizedBox(height: 28),

            // Compare area
            Text(
              'Compare Cars',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                _compareCard(_left, true),
                _compareCard(_right, false),
              ],
            ),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    // Add car action placeholder - keep visual like original
                  },
                  icon: Icon(Icons.add),
                  label: Text('Add Car'),
                ),
                SizedBox(width: 12),
                ElevatedButton(onPressed: _compareNow, child: Text('Compare')),
              ],
            ),
            SizedBox(height: 20),
            Text(
              'Popular Car Comparisons',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            ..._buildPopularComparisons(),
            SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
