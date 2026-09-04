import 'package:flutter/material.dart';

const appGold = Color(0xfff4b500);
const appNavy = Color(0xff172b4d);
const appGreen = Color(0xff16815d);
const appRed = Color(0xffc84242);

const avatars = <String, String>{
  'merchant_purple': 'assets/avatars/avatar_merchant_purple.png',
  'merchant_turquoise': 'assets/avatars/avatar_merchant_turquoise.png',
  'trader_traditional': 'assets/avatars/avatar_trader_traditional.png',
  'captain': 'assets/avatars/avatar_captain.png',
  'businessman': 'assets/avatars/avatar_businessman.png',
  'traveler_white': 'assets/avatars/avatar_traveler_white.png',
};

String avatarAsset(String avatarId) =>
    avatars[avatarId] ?? avatars['merchant_purple']!;

String persianDigits(Object value) {
  const en = '0123456789';
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  return value.toString().split('').map((char) {
    final index = en.indexOf(char);
    return index == -1 ? char : fa[index];
  }).join();
}

String money(int value) {
  final raw = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index++) {
    if (index > 0 && (raw.length - index) % 3 == 0) buffer.write('٬');
    buffer.write(raw[index]);
  }
  return '${value < 0 ? '-' : ''}${persianDigits(buffer)}';
}

class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    super.key,
    required this.avatarId,
    this.size = 44,
    this.borderColor,
  });

  final String avatarId;
  final double size;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: borderColor ?? appGold, width: 2),
      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 5)],
    ),
    child: ClipOval(
      child: Image.asset(avatarAsset(avatarId), fit: BoxFit.cover),
    ),
  );
}

class ScreenBackground extends StatelessWidget {
  const ScreenBackground({
    super.key,
    required this.child,
    this.image = 'assets/images/merchants-row-background.png',
  });

  final Widget child;
  final String image;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset(image, fit: BoxFit.cover),
      const ColoredBox(color: Color(0xA6FFFFFF)),
      child,
    ],
  );
}

Future<void> showFailure(BuildContext context, Object error) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('عملیات انجام نشد'),
      content: Text(error.toString()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('بستن'),
        ),
      ],
    ),
  );
}
