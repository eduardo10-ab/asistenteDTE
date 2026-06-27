// lib/profile_avatar_menu.dart
import 'package:flutter/material.dart';
import 'core/ui/app_colors.dart';
import 'models.dart';
import 'configuracion_screen.dart';

/// Widget reutilizable del menú avatar que aparece en todas las pantallas.
/// Muestra: perfil activo, crear perfil, cambiar perfil, configuración.
class ProfileAvatarMenu extends StatelessWidget {
  final String perfilActivo;
  final List<String> perfiles;
  final ActivationStatus activationStatus;

  /// Callback opcional para crear un nuevo perfil. Si es null, la opción no aparece.
  final VoidCallback? onCrearPerfil;

  /// Callback para cambiar de perfil. Recibe el nombre del perfil seleccionado.
  final Future<void> Function(String?)? onCambiarPerfil;

  /// Callback opcional para cuando se cierra ConfiguracionScreen (para refrescar estado).
  final VoidCallback? onAfterConfiguracion;

  /// Callback para cerrar sesión (opcional).
  final VoidCallback? onCerrarSesion;

  const ProfileAvatarMenu({
    super.key,
    required this.perfilActivo,
    required this.perfiles,
    required this.activationStatus,
    this.onCrearPerfil,
    this.onCambiarPerfil,
    this.onAfterConfiguracion,
    this.onCerrarSesion,
  });

  String get _statusLabel {
    switch (activationStatus) {
      case ActivationStatus.pro:
        return 'PRO';
      case ActivationStatus.demo:
        return 'DEMO';
      case ActivationStatus.none:
        return 'Inactiva';
    }
  }

  Color get _statusColor {
    switch (activationStatus) {
      case ActivationStatus.pro:
        return Colors.green;
      case ActivationStatus.demo:
        return Colors.orange;
      case ActivationStatus.none:
        return Colors.grey;
    }
  }

  void _showProfileSwitchDialog(BuildContext context) {
    showDialog<String>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: theme.cardTheme.color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Cambiar Perfil'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: perfiles.length,
              itemBuilder: (_, i) {
                final p = perfiles[i];
                final isActive = p == perfilActivo;
                return ListTile(
                  dense: true,
                  leading: Icon(
                    isActive
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isActive ? colorAzulActivo : theme.disabledColor,
                    size: 20,
                  ),
                  title: Text(
                    p,
                    style: TextStyle(
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx, p);
                    onCambiarPerfil?.call(p);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopupMenuButton<int>(
      tooltip: 'Cuenta y Perfiles',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
      elevation: 8,
      icon: CircleAvatar(
        radius: 17,
        backgroundColor: colorCelestePastel.withValues(alpha: 0.15),
        child: const Icon(
          Icons.person_rounded,
          color: colorAzulActivo,
          size: 20,
        ),
      ),
      onSelected: (value) async {
        switch (value) {
          case 2:
            onCrearPerfil?.call();
            break;
          case 3:
            _showProfileSwitchDialog(context);
            break;
          case 4:
            if (!context.mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConfiguracionScreen()),
            );
            onAfterConfiguracion?.call();
            break;
          case 5:
            // Cerrar sesión
            onCerrarSesion?.call();
            break;
        }
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<int>>[];

        // --- Encabezado: perfil activo (no seleccionable) ---
        items.add(
          PopupMenuItem<int>(
            value: 1,
            enabled: false,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorAzulActivo.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_circle_outlined,
                    size: 20,
                    color: colorAzulActivo,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Perfil en Uso',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : colorTextoPrincipal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              perfilActivo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white54
                                    : colorTextoSecundario,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _statusLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        items.add(const PopupMenuDivider(height: 1));

        // --- Crear Perfil ---
        if (onCrearPerfil != null) {
          items.add(
            _buildMenuItem(
              value: 2,
              icon: Icons.add_circle_outline_rounded,
              label: 'Crear Perfil',
              isDark: isDark,
            ),
          );
        }

        // --- Cambiar Perfil ---
        if (onCambiarPerfil != null) {
          items.add(
            _buildMenuItem(
              value: 3,
              icon: Icons.swap_horiz_rounded,
              label: 'Cambiar Perfil',
              isDark: isDark,
            ),
          );
        }

        items.add(const PopupMenuDivider(height: 1));

        // --- Configuración ---
        items.add(
          _buildMenuItem(
            value: 4,
            icon: Icons.settings_outlined,
            label: 'Configuración',
            isDark: isDark,
          ),
        );

        // --- Cerrar sesión (debajo de Configuración) ---
        if (onCerrarSesion != null) {
          items.add(const PopupMenuDivider(height: 1));
          items.add(
            _buildMenuItem(
              value: 5,
              icon: Icons.logout_outlined,
              label: 'Cerrar sesión',
              isDark: isDark,
            ),
          );
        }

        return items;
      },
    );
  }

  PopupMenuItem<int> _buildMenuItem({
    required int value,
    required IconData icon,
    required String label,
    required bool isDark,
    Color? iconColor,
  }) {
    final color = iconColor ?? (isDark ? Colors.white70 : colorTextoPrincipal);
    return PopupMenuItem<int>(
      value: value,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 14),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : colorTextoPrincipal,
            ),
          ),
        ],
      ),
    );
  }
}
