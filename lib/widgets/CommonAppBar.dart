import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;

  final bool isSearching;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchClosed;

  final double appBarHeight = AppBar().preferredSize.height;

  CommonAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.isSearching = false,
    this.searchController,
    this.onSearchChanged,
    this.onSearchClosed,
  });

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: preferredSize,
      child: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16.0),
          ),
        ),
        leading: leading,
        actions: actions,
        centerTitle: true,

        title: isSearching
            ? TextField(
          controller: searchController,
          textCapitalization: TextCapitalization.sentences,
          autofocus: true,
          onChanged: onSearchChanged,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
          ),
          decoration: InputDecoration(
            hintText: 'Rezept suchen...',
            hintStyle: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.6),
            ),
            border: InputBorder.none,
          ),
        )
            : Text(
          title,
          style: GoogleFonts.pacifico(
            fontSize: 26,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(appBarHeight);
}
