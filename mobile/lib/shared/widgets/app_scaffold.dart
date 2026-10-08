import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Barra superior estándar (azul oscuro UNBOUND).
///
/// Se usa en pantallas internas: [← Atrás] [Título] [Acción/Icono].
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final double? toolbarHeight;

  const AppTopBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.toolbarHeight,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(toolbarHeight ?? (kToolbarHeight + MediaQueryData().padding.top));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      title: Text(title),
      actions: actions,
      toolbarHeight: toolbarHeight,
    );
  }
}

/// Notificación con badge para la barra superior.
class NotificationIconButton extends StatelessWidget {
  final int count;
  final VoidCallback onPressed;

  const NotificationIconButton({
    super.key,
    required this.count,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          tooltip: 'Notificaciones',
          onPressed: onPressed,
        ),
        if (count > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.coralRed,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

/// Menú de cuenta para la barra superior.
class AccountMenuButton extends StatelessWidget {
  final List<PopupMenuEntry<String>> items;
  final void Function(String value) onSelected;

  const AccountMenuButton({
    super.key,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.account_circle_outlined),
      tooltip: 'Mi cuenta',
      onSelected: onSelected,
      itemBuilder: (_) => items,
    );
  }
}

/// Elemento de menú de cuenta con icono.
class AccountMenuEntry extends PopupMenuEntry<String> {
  final String value;
  final IconData icon;
  final String label;
  final Color? iconColor;

  const AccountMenuEntry({
    super.key,
    required this.value,
    required this.icon,
    required this.label,
    this.iconColor,
  });

  @override
  final double height = 48;

  @override
  State<AccountMenuEntry> createState() => _AccountMenuEntryState();

  @override
  bool represents(String? value) => value == this.value;
}

class _AccountMenuEntryState extends State<AccountMenuEntry> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(widget.icon, color: widget.iconColor),
      title: Text(
        widget.label,
        style: TextStyle(
          color: widget.iconColor,
        ),
      ),
      contentPadding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).pop(widget.value),
    );
  }
}

/// Separador para el menú de cuenta.
class AccountMenuDivider extends PopupMenuEntry<String> {
  const AccountMenuDivider({super.key});

  @override
  final double height = 1;

  @override
  State<AccountMenuDivider> createState() => _AccountMenuDividerState();

  @override
  bool represents(String? value) => false;
}

class _AccountMenuDividerState extends State<AccountMenuDivider> {
  @override
  Widget build(BuildContext context) {
    return const PopupMenuDivider();
  }
}

/// Navegación inferior persistente con la identidad UNBOUND.
///
/// Activo: azul oscuro. Inactivo: gris neutro.
/// Superficie blanca separada del contenido.
class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final void Function(int index) onTap;
  final List<NavigationItem> items;

  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
      items: [
        for (final item in items)
          BottomNavigationBarItem(
            icon: Icon(item.icon),
            activeIcon: Icon(item.activeIcon ?? item.icon),
            label: item.label,
            tooltip: item.label,
          ),
      ],
    );
  }
}

/// Elemento de la navegación inferior.
class NavigationItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  const NavigationItem({
    required this.icon,
    required this.label,
    this.activeIcon,
  });
}
