
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MoniciApp());
}

class MoniciApp extends StatelessWidget {
  const MoniciApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monici',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF781F),
        ),
      ),
      home: const PinScreen(),
    );
  }
}

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  static const storage = FlutterSecureStorage();

  final controller = TextEditingController();

  bool loading = true;
  bool hasPin = false;
  bool confirming = false;
  bool unlocked = false;
  bool submitting = false;

  String firstPin = '';
  String salt = '';
  String message = '';

  @override
  void initState() {
    super.initState();
    loadPin();
  }

  Future<void> loadPin() async {
    final savedHash = await storage.read(key: 'pin_hash');
    final savedSalt = await storage.read(key: 'pin_salt');

    if (!mounted) return;

    setState(() {
      hasPin = savedHash != null && savedSalt != null;
      salt = savedSalt ?? '';
      loading = false;
    });
  }

  String hashPin(String pin, String currentSalt) {
    return sha256
        .convert(utf8.encode('$currentSalt:$pin'))
        .toString();
  }

  Future<void> submitPin() async {
    if (submitting) return;

    final pin = controller.text;

    if (!RegExp(r'^[0-9]{4}$').hasMatch(pin)) {
      setState(() {
        message = 'أدخل أربعة أرقام فقط';
      });
      return;
    }

    setState(() {
      submitting = true;
      message = '';
    });

    try {
      if (!hasPin) {
        if (!confirming) {
          firstPin = pin;

          setState(() {
            confirming = true;
            message = 'أعد كتابة كلمة المرور للتأكيد';
          });
        } else {
          if (pin != firstPin) {
            firstPin = '';

            setState(() {
              confirming = false;
              message = 'كلمتا المرور غير متطابقتين';
            });
          } else {
            final newSalt = List.generate(
              16,
              (_) => Random.secure()
                  .nextInt(256)
                  .toRadixString(16)
                  .padLeft(2, '0'),
            ).join();

            await storage.write(
              key: 'pin_salt',
              value: newSalt,
            );

            await storage.write(
              key: 'pin_hash',
              value: hashPin(pin, newSalt),
            );

            if (!mounted) return;

            setState(() {
              salt = newSalt;
              hasPin = true;
              unlocked = true;
              message = '';
            });
          }
        }
      } else {
        final savedHash =
            await storage.read(key: 'pin_hash');

        if (!mounted) return;

        if (savedHash == hashPin(pin, salt)) {
          setState(() {
            unlocked = true;
            message = '';
          });
        } else {
          setState(() {
            message = 'كلمة المرور غير صحيحة';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          message = 'حدث خطأ، حاول مرة أخرى';
        });
      }
    } finally {
      if (mounted) {
        controller.clear();

        setState(() {
          submitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: OrangeBackgroundPainter(),
              ),
            ),
            SafeArea(
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    )
                  : unlocked
                      ? const SizedBox.expand()
                      : Center(
                          child: passwordScreen(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget passwordScreen() {
    String heading;

    if (!hasPin) {
      heading = confirming
          ? 'تأكيد كلمة المرور'
          : 'إنشاء كلمة المرور';
    } else {
      heading = 'مرحباً بعودتك';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock_rounded,
            color: Colors.white,
            size: 75,
          ),
          const SizedBox(height: 20),

          const Text(
            'Monici',
            style: TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),

          const SizedBox(height: 45),

          Text(
            heading,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            hasPin
                ? 'أدخل كلمة المرور للدخول إلى التطبيق'
                : 'اختر كلمة مرور مكونة من أربعة أرقام',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
            ),
          ),

          const SizedBox(height: 30),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              style: const TextStyle(
                fontSize: 27,
                letterSpacing: 15,
                color: Color(0xFF333333),
              ),
              decoration: const InputDecoration(
                hintText: '••••',
                counterText: '',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(18),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (controller.text.length == 4) {
                  submitPin();
                }
              },
            ),
          ),

          const SizedBox(height: 18),

          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: controller.text.length == 4 &&
                      !submitting
                  ? submitPin
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFEF6817),
                disabledBackgroundColor:
                    Colors.white.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                submitting
                    ? 'يرجى الانتظار...'
                    : hasPin
                        ? 'دخول'
                        : confirming
                            ? 'تأكيد كلمة المرور'
                            : 'إنشاء كلمة المرور',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 25),

          const Text(
            'حماية خصوصيتك تبدأ من هنا',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class OrangeBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFF9A35),
          Color(0xFFFF761C),
          Color(0xFFE95B13),
        ],
      ).createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      background,
    );

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.17)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = -3; i < 10; i++) {
      final path = Path();
      final startX = i * 75.0;

      path.moveTo(startX, 0);
      path.cubicTo(
        startX + 120,
        size.height * 0.25,
        startX - 100,
        size.height * 0.65,
        startX + 90,
        size.height,
      );

      canvas.drawPath(path, linePaint);
    }

    final circlePaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.15),
      90,
      circlePaint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.05, size.height * 0.85),
      120,
      circlePaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}
