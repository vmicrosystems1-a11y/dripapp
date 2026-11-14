import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const IrrigationApp());
}

class IrrigationApp extends StatelessWidget {
  const IrrigationApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Smart Irrigation',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF168B64)),
          scaffoldBackgroundColor: const Color(0xFFF4F7F6),
        ),
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            return snapshot.data == null ? const LoginScreen() : const Dashboard();
          },
        ),
      );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool loading = false;
  bool hidePassword = true;
  String? error;

  @override
  void dispose() { email.dispose(); password.dispose(); super.dispose(); }

  Future<void> signIn() async {
    if (!formKey.currentState!.validate()) return;
    setState(() { loading = true; error = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(), password: password.text,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => error = switch (e.code) {
        'invalid-credential' || 'wrong-password' || 'user-not-found' => 'Invalid email or password.',
        'invalid-email' => 'Please enter a valid email address.',
        'too-many-requests' => 'Too many attempts. Try again later.',
        'network-request-failed' => 'Check your internet connection.',
        _ => 'Sign-in failed: ${e.message ?? e.code}',
      });
    } catch (e) {
      if (mounted) setState(() => error = 'Unable to sign in: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420),
        child: Card(child: Padding(padding: const EdgeInsets.all(24), child: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.eco, size: 62, color: Color(0xFF168B64)),
            const SizedBox(height: 14),
            const Text('Smart Irrigation', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Sign in to monitor and control your farm', textAlign: TextAlign.center),
            const SizedBox(height: 28),
            TextFormField(controller: email, keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
              validator: (v) => v == null || !v.contains('@') || !v.contains('.') ? 'Enter a valid email' : null),
            const SizedBox(height: 16),
            TextFormField(controller: password, obscureText: hidePassword,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(), suffixIcon: IconButton(
                  icon: Icon(hidePassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => hidePassword = !hidePassword))),
              validator: (v) => v == null || v.isEmpty ? 'Enter your password' : null,
              onFieldSubmitted: (_) => loading ? null : signIn()),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 14),
              child: Text(error!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 22),
            FilledButton.icon(onPressed: loading ? null : signIn,
              icon: loading ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login),
              label: const Text('Sign in')),
          ]),
        )))),
      ),
    )),
  );
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final DatabaseReference root = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://drip-f280e-default-rtdb.firebaseio.com',
  ).ref('irrigation');
  bool busy = false;
  static const mint = Color(0xFF55E0A6);
  static const surface = Color(0xFF10251C);
  static const panel = Color(0xFF1B3026);
  static const background = Color(0xFF06180F);
  static const muted = Color(0xFF9AA9A1);

  Map<String, dynamic> map(Object? value) => value is Map
      ? value.map((k, v) => MapEntry(k.toString(), v)) : {};
  bool flag(Object? value) => value == true || value == 1 || value == 'true';
  double? measure(Object? value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
  String timeValue(Object? value, String fallback) {
    final v = value?.toString();
    return v != null && RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(v) ? v : fallback;
  }
  Future<void> write(String path, Object value) async {
    if (busy) return;
    setState(() => busy = true);
    try { await root.child(path).set(value); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Firebase update failed: $e'))); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> editTime(String key, String current) async {
    final parts = current.split(':');
    final initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    final selected = await showTimePicker(context: context, initialTime: initial);
    if (selected == null || !mounted) return;
    final value = '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
    await write('schedule/$key', value);
  }
  Widget section(String title, Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: surface, border: Border.all(color: const Color(0xFF254536)), borderRadius: BorderRadius.circular(26)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: mint, fontWeight: FontWeight.bold, fontSize: 19, letterSpacing: 1)),
      const SizedBox(height: 22), child,
    ]),
  );
  Widget timeTile(String label, String key, String value) => Container(
    margin: const EdgeInsets.only(top: 14), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(color: panel, border: Border.all(color: const Color(0xFF345044)), borderRadius: BorderRadius.circular(17)),
    child: Row(children: [const Icon(Icons.access_time, color: mint), const SizedBox(width: 18),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: muted, fontSize: 13)), const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      ])), IconButton(onPressed: busy ? null : () => editTime(key, value), icon: const Icon(Icons.edit, color: muted)),
    ]),
  );
  Widget scheduleBlock(String title, IconData icon, String prefix, Map<String, dynamic> schedule) {
    final enabled = flag(schedule['${prefix}Enabled']);
    final on = timeValue(schedule['${prefix}On'], prefix == 'morning' ? '08:00' : '16:20');
    final off = timeValue(schedule['${prefix}Off'], prefix == 'morning' ? '08:02' : '16:22');
    return Column(children: [
      Row(children: [Icon(icon, color: mint), const SizedBox(width: 12),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
        Text(enabled ? 'ENABLED' : 'DISABLED', style: const TextStyle(color: mint, fontSize: 12, fontWeight: FontWeight.bold)),
        Switch(value: enabled, activeThumbColor: mint, onChanged: busy ? null : (v) => write('schedule/${prefix}Enabled', v)),
      ]),
      timeTile('ON TIME', '${prefix}On', on), timeTile('OFF TIME', '${prefix}Off', off),
    ]);
  }
  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData.dark(useMaterial3: true).copyWith(scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(primary: mint, surface: surface)),
    child: Scaffold(
      appBar: AppBar(backgroundColor: surface, title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SMART DRIP IRRIGATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
        Text('Monitoring & Control', style: TextStyle(fontSize: 13, color: muted)),
      ]), actions: [IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())]),
      body: StreamBuilder<DatabaseEvent>(stream: root.onValue, builder: (context, snapshot) {
        final data = map(snapshot.data?.snapshot.value);
        final sensors = map(data['sensors']); final controls = map(data['controls']);
        final schedule = map(data['schedule']); final device = map(data['device']);
        final auto = flag(controls['autoMode']); final valve = flag(controls['valveOn']);
        final moisture = measure(sensors['soilMoisture']);
        // Device online must come from ESP32; a Firebase connection alone does not prove device status.
        final online = flag(device['online']);
        final moisturePct = (moisture ?? 0).clamp(0.0, 100.0);
        final quality = moisture == null ? 'NO DATA' : moisturePct < 30 ? 'DRY' : moisturePct < 70 ? 'GOOD' : 'WET';
        final qualityColor = moisture == null ? muted : moisturePct < 30 ? const Color(0xFFFF575C) : mint;
        final email = FirebaseAuth.instance.currentUser?.email ?? 'Signed in';
        return ListView(padding: const EdgeInsets.all(20), children: [
          if (snapshot.hasError) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('Firebase error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent))),
          section('SYSTEM STATUS', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(Icons.circle, size: 15, color: online ? mint : muted), const SizedBox(width: 14),
              Text(online ? 'DEVICE ONLINE' : 'DEVICE OFFLINE', style: TextStyle(color: online ? mint : muted, fontWeight: FontWeight.bold, fontSize: 19)),
              const Spacer(), Icon(online ? Icons.cloud_done : Icons.cloud_off, color: online ? mint : muted)]),
            const SizedBox(height: 18), Row(children: [const Icon(Icons.account_circle_outlined, color: muted), const SizedBox(width: 12), Expanded(child: Text(email, style: const TextStyle(color: muted), overflow: TextOverflow.ellipsis))]),
            const SizedBox(height: 18), Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [const Icon(Icons.access_time, color: mint, size: 35), const SizedBox(width: 18), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('CONTROLLER TIME', style: TextStyle(color: muted, fontSize: 13)), const SizedBox(height: 7),
                Text(device['time']?.toString() ?? '--:--:--', style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
                Text(device['date']?.toString() ?? 'Waiting for ESP32', style: const TextStyle(color: muted)),
              ]))])),
          ])),
          section('SOIL HUMIDITY', Column(children: [
            SizedBox(height: 235, child: Stack(alignment: Alignment.center, children: [
              SizedBox(width: 215, height: 215, child: CircularProgressIndicator(value: moisturePct / 100, strokeWidth: 17, backgroundColor: const Color(0xFF30443A), valueColor: AlwaysStoppedAnimation(qualityColor))),
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.water_drop, color: Color(0xFF4A8BFF), size: 37),
                const SizedBox(height: 8), Text(moisture == null ? '--%' : '${moisturePct.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 43, fontWeight: FontWeight.bold)),
                Text(quality, style: TextStyle(color: qualityColor, fontSize: 22, fontWeight: FontWeight.bold)),
              ]),
            ])), const SizedBox(height: 10), LinearProgressIndicator(value: moisturePct / 100, minHeight: 10, borderRadius: BorderRadius.circular(10), color: qualityColor, backgroundColor: const Color(0xFF30443A)),
            const SizedBox(height: 10), const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('DRY', style: TextStyle(color: muted)), Text('GOOD', style: TextStyle(color: muted)), Text('WET', style: TextStyle(color: muted))]),
          ])),
          section('VALVE CONTROL', Column(children: [
            Container(width: double.infinity, padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: const Color(0xFF242820), borderRadius: BorderRadius.circular(18)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.water_drop_outlined, color: valve ? mint : const Color(0xFFFF575C)), const SizedBox(width: 12),
                Text(valve ? 'VALVE OPEN' : 'VALVE CLOSED', style: TextStyle(color: valve ? mint : const Color(0xFFFF575C), fontSize: 23, fontWeight: FontWeight.bold))])),
            const SizedBox(height: 20), Row(children: [
              Expanded(child: FilledButton.icon(onPressed: busy || auto || !snapshot.hasData ? null : () => write('controls/valveOn', true), icon: const Icon(Icons.play_arrow), label: const Text('VALVE ON'))),
              const SizedBox(width: 12), Expanded(child: FilledButton.icon(onPressed: busy || auto || !snapshot.hasData ? null : () => write('controls/valveOn', false), icon: const Icon(Icons.stop), label: const Text('VALVE OFF'))),
            ]), if (auto) const Padding(padding: EdgeInsets.only(top: 12), child: Text('Manual buttons are disabled in AUTO mode.', style: TextStyle(color: Color(0xFFFFB74D)))),
          ])),
          section('CONTROL MODE', Row(children: [
            Expanded(child: _modeButton('MANUAL', Icons.touch_app, !auto, busy || !snapshot.hasData, () => write('controls/autoMode', false))),
            const SizedBox(width: 14), Expanded(child: _modeButton('AUTO', Icons.access_time, auto, busy || !snapshot.hasData, () => write('controls/autoMode', true))),
          ])),
          section('IRRIGATION SCHEDULE', Column(children: [
            scheduleBlock('MORNING', Icons.wb_sunny_outlined, 'morning', schedule),
            const Divider(height: 44, color: Color(0xFF345044)),
            scheduleBlock('EVENING', Icons.nightlight_outlined, 'evening', schedule),
            const SizedBox(height: 22), SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: busy || !snapshot.hasData ? null : () async {
                // Times and switches are already saved immediately to Firebase.
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedule saved in Firebase')));
              }, icon: const Icon(Icons.cloud_upload), label: const Text('SAVE SCHEDULE'))),
          ])),
        ]);
      }),
    ),
  );
  Widget _modeButton(String title, IconData icon, bool selected, bool disabled, VoidCallback onTap) =>
    OutlinedButton(onPressed: disabled ? null : onTap,
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 26),
        backgroundColor: selected ? const Color(0xFF1A3D29) : panel,
        side: BorderSide(color: selected ? mint : const Color(0xFF345044)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
      child: Column(children: [Icon(icon, color: selected ? mint : muted, size: 30), const SizedBox(height: 12),
        Text(title, style: TextStyle(color: selected ? mint : muted, fontWeight: FontWeight.bold, fontSize: 20))]));
}
