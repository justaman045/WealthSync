import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/colors.dart';

/// A search box plus a horizontally scrolling row of selectable pills.
///
/// This is the app's house picker (the shape `add_transaction.dart` uses for
/// categories): a dropdown hides options and cannot show the selected state at
/// a glance, which is why the recurring-payment sheet moved off
/// `DropdownButtonFormField`. Search only appears once the list is long enough
/// to need it.
class SelectableChipRow<T> extends StatefulWidget {
  const SelectableChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.iconOf,
    this.searchHint = 'Search categories...',
    this.searchThreshold = 8,
  });

  final List<T> options;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;
  final IconData? Function(T value)? iconOf;
  final String searchHint;
  final int searchThreshold;

  @override
  State<SelectableChipRow<T>> createState() => _SelectableChipRowState<T>();
}

class _SelectableChipRowState<T> extends State<SelectableChipRow<T>> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _searchable => widget.options.length > widget.searchThreshold;

  List<T> get _visible {
    if (_query.isEmpty) return widget.options;
    final q = _query.toLowerCase();
    return widget.options
        .where((o) => widget.labelOf(o).toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_searchable) ...[
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: theme.cardColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
            ),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                hintStyle: AppType.bodyMedium(
                  theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4) ??
                      AppColors.lightTextSecondary,
                ),
                border: InputBorder.none,
                prefixIcon: Icon(
                  Icons.search,
                  size: 18.sp,
                  color: theme.iconTheme.color,
                ),
                isDense: true,
              ),
              style: AppType.bodyMedium(
                theme.textTheme.bodyLarge?.color ??
                    AppColors.lightTextPrimary,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(height: 10.h),
        ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final option in visible)
                Padding(
                  padding: EdgeInsets.only(right: 10.w),
                  child: _chip(theme, option),
                ),
              // An empty filtered list needs no copy: the search field already
              // shows the query, and adding a localized "no matches" string
              // only for this one picker would be new UI debt.
              if (visible.isEmpty) SizedBox(height: 12.h),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(ThemeData theme, T option) {
    final isSelected = option == widget.selected;
    final icon = widget.iconOf?.call(option);
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: () => widget.onSelected(option),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.18)
                : theme.cardColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : theme.dividerColor.withValues(alpha: 0.3),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16.sp,
                  color: isSelected
                      ? AppColors.primary
                      : theme.textTheme.bodyMedium?.color,
                ),
                SizedBox(width: 6.w),
              ],
              Text(
                widget.labelOf(option),
                style: isSelected
                    ? AppType.labelLarge(AppColors.primary)
                    : AppType.labelLarge(
                        theme.textTheme.bodyMedium?.color ??
                            AppColors.lightTextSecondary,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
