import 'package:fluent_ui/fluent_ui.dart';

class DashboardColumnHeader extends StatelessWidget {
  const DashboardColumnHeader({
    required this.title,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String title;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 265,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: FluentTheme.of(context).typography.bodyStrong,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(icon),
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}
