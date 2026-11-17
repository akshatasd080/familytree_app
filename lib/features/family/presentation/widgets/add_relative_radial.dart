import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../data/models/family_models.dart';

class AddRelativeAction {
  const AddRelativeAction({
    required this.keyName,
    required this.label,
    required this.relationship,
    required this.gender,
    required this.x,
    required this.y,
    this.sub,
  });

  final String keyName;
  final String label;
  final String relationship;
  final String gender;
  final double x;
  final double y;
  final String? sub;
}

const addRelativeActions = <AddRelativeAction>[
  AddRelativeAction(
    keyName: 'father',
    label: 'Add father',
    relationship: 'Father',
    gender: 'male',
    x: 30,
    y: 8,
  ),
  AddRelativeAction(
    keyName: 'mother',
    label: 'Add mother',
    relationship: 'Mother',
    gender: 'female',
    x: 70,
    y: 8,
  ),
  AddRelativeAction(
    keyName: 'brother',
    label: 'Add brother',
    relationship: 'Brother',
    gender: 'male',
    x: 12,
    y: 28,
  ),
  AddRelativeAction(
    keyName: 'sister',
    label: 'Add sister',
    relationship: 'Sister',
    gender: 'female',
    x: 12,
    y: 58,
  ),
  AddRelativeAction(
    keyName: 'partner',
    label: 'Add partner',
    sub: 'Wife, ex-wife, partner…',
    relationship: 'Spouse',
    gender: 'female',
    x: 78,
    y: 42,
  ),
  AddRelativeAction(
    keyName: 'son',
    label: 'Add son',
    relationship: 'Son',
    gender: 'male',
    x: 34,
    y: 86,
  ),
  AddRelativeAction(
    keyName: 'daughter',
    label: 'Add daughter',
    relationship: 'Daughter',
    gender: 'female',
    x: 66,
    y: 86,
  ),
];

/// Mobile-safe relative picker (web radial adapted so nothing clips off-screen).
class AddRelativeRadial extends StatelessWidget {
  const AddRelativeRadial({
    super.key,
    required this.person,
    required this.onSelect,
    required this.onClose,
  });

  final FamilyMember person;
  final ValueChanged<AddRelativeAction> onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 700;

    return Material(
      color: const Color(0x590F172A),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
              ),
            ),
            if (narrow)
              Align(
                alignment: Alignment.bottomCenter,
                child: _MobilePickerSheet(
                  person: person,
                  onSelect: onSelect,
                  onClose: onClose,
                ),
              )
            else
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 520,
                    maxHeight: 560,
                  ),
                  child: AspectRatio(
                    aspectRatio: 4 / 3.2,
                    child: _DesktopRadial(
                      person: person,
                      onSelect: onSelect,
                      onClose: onClose,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet grid — always fits phone width.
class _MobilePickerSheet extends StatelessWidget {
  const _MobilePickerSheet({
    required this.person,
    required this.onSelect,
    required this.onClose,
  });

  final FamilyMember person;
  final ValueChanged<AddRelativeAction> onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add relative',
                      style: AppTheme.display(size: 18),
                    ),
                  ),
                  TextButton(
                    onPressed: onClose,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.muted,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: _CenterCard(person: person),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wideEnough = constraints.maxWidth >= 340;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final action in addRelativeActions)
                          SizedBox(
                            width: wideEnough
                                ? (constraints.maxWidth - 8) / 2
                                : constraints.maxWidth,
                            child: _ActionCard(
                              action: action,
                              personName: person.name,
                              onTap: () => onSelect(action),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopRadial extends StatelessWidget {
  const _DesktopRadial({
    required this.person,
    required this.onSelect,
    required this.onClose,
  });

  final FamilyMember person;
  final ValueChanged<AddRelativeAction> onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        const center = Offset(0.50, 0.48);
        const cardW = 150.0;
        const pad = 8.0;

        double clampLeft(double xPercent) {
          final raw = xPercent / 100 * w - cardW / 2;
          return raw.clamp(pad, w - cardW - pad);
        }

        double clampTop(double yPercent, {double cardH = 68}) {
          final raw = yPercent / 100 * h - cardH / 2;
          return raw.clamp(pad + 36, h - cardH - pad);
        }

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            CustomPaint(
              size: Size(w, h),
              painter: _SpokePainter(
                center: Offset(center.dx * w, center.dy * h),
                ends: [
                  for (final a in addRelativeActions)
                    Offset(
                      clampLeft(a.x) + cardW / 2,
                      clampTop(a.y) + 34,
                    ),
                ],
              ),
            ),
            Positioned(
              left: (center.dx * w - 95).clamp(pad, w - 190 - pad),
              top: (center.dy * h - 62).clamp(pad + 36, h - 130 - pad),
              width: 190,
              child: _CenterCard(person: person),
            ),
            for (final action in addRelativeActions)
              Positioned(
                left: clampLeft(action.x),
                top: clampTop(action.y),
                width: cardW,
                child: _ActionCard(
                  action: action,
                  personName: person.name,
                  onTap: () => onSelect(action),
                ),
              ),
            Positioned(
              top: pad,
              right: pad,
              child: TextButton(
                onPressed: onClose,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.muted,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CenterCard extends StatelessWidget {
  const _CenterCard({required this.person});

  final FamilyMember person;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBAE6FD)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8F4FC), Colors.white],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _AvatarFace(gender: _guessGender(person), size: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  person.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  person.relationship ?? 'Family',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.action,
    required this.personName,
    required this.onTap,
  });

  final AddRelativeAction action;
  final String personName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final female = action.gender == 'female';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: female ? const Color(0xFFFBCFE8) : const Color(0xFFBAE6FD),
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: female
                  ? const [Color(0xFFFCE7F3), Colors.white]
                  : const [Color(0xFFE0F2FE), Colors.white],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              _AvatarFace(gender: action.gender, size: 34),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      action.sub ?? 'of $personName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarFace extends StatelessWidget {
  const _AvatarFace({required this.gender, required this.size});

  final String gender;
  final double size;

  @override
  Widget build(BuildContext context) {
    final female = gender == 'female';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: female ? const Color(0xFFFCE7F3) : const Color(0xFFDBEAFE),
      ),
      alignment: Alignment.center,
      child: Icon(
        female ? Icons.woman : Icons.man,
        size: size * 0.55,
        color: female ? const Color(0xFFDB2777) : const Color(0xFF2563EB),
      ),
    );
  }
}

class _SpokePainter extends CustomPainter {
  _SpokePainter({required this.center, required this.ends});

  final Offset center;
  final List<Offset> ends;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final end in ends) {
      final mx = (center.dx + end.dx) / 2;
      final my = (center.dy + end.dy) / 2;
      final dx = end.dx - center.dx;
      final dy = end.dy - center.dy;
      final cx = mx - dy * 0.15;
      final cy = my + dx * 0.15;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..quadraticBezierTo(cx, cy, end.dx, end.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpokePainter oldDelegate) =>
      oldDelegate.center != center || oldDelegate.ends != ends;
}

String _guessGender(FamilyMember person) {
  final g = (person.gender ?? '').toLowerCase();
  if (g == 'female' || g == 'male') return g;
  final r = (person.relationship ?? '').toLowerCase();
  const female = {
    'mother',
    'sister',
    'daughter',
    'wife',
    'aunt',
    'grandmother',
    'spouse',
    'partner',
  };
  return female.contains(r) ? 'female' : 'male';
}
