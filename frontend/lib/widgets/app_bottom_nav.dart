import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 4-item bottom bar: Home / Sell (raised center action) / Chat / Profile.
/// The center "Sell" item never shows as selected; it always just triggers
/// [onSell].
class AppBottomNav extends StatelessWidget {
  final int selectedIndex; // 0=Home, 2=Chat, 3=Profile
  final ValueChanged<int> onSelect;
  final VoidCallback onSell;
  final int chatUnreadCount;
  final int profileUnreadCount;

  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.onSell,
    this.chatUnreadCount = 0,
    this.profileUnreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                label: 'Home',
                selected: selectedIndex == 0,
                onTap: () => onSelect(0),
              ),
              _SellItem(onTap: onSell),
              _NavItem(
                icon: Icons.forum_outlined,
                selectedIcon: Icons.forum,
                label: 'Chat',
                selected: selectedIndex == 2,
                onTap: () => onSelect(2),
                badgeCount: chatUnreadCount,
              ),
              _NavItem(
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                label: 'Profile',
                selected: selectedIndex == 3,
                onTap: () => onSelect(3),
                badgeCount: profileUnreadCount,
                badgeColor: Colors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;
  final Color? badgeColor;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    Widget iconWidget = Icon(selected ? selectedIcon : icon, color: color, size: 24);
    if (badgeCount > 0) {
      iconWidget = Badge(
        label: Text('$badgeCount'),
        backgroundColor: badgeColor ?? AppColors.gold,
        textColor: badgeColor == null ? const Color(0xFF3A2200) : Colors.white,
        child: iconWidget,
      );
    }

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _SellItem extends StatelessWidget {
  final VoidCallback onTap;
  const _SellItem({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.translate(
              offset: const Offset(0, -14),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 26),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
