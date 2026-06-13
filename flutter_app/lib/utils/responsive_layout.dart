import 'package:flutter/material.dart';
import 'responsive.dart';

/// Responsive table and grid utilities for adaptive layouts.
/// 
/// These helpers ensure data tables and grids are properly constrained
/// and adapt their column widths based on available space.

/// Responsive data table column configuration
class ResponsiveDataColumn {
  final String label;
  final double? width;
  final Alignment alignment;
  final bool numeric;

  ResponsiveDataColumn({
    required this.label,
    this.width,
    this.alignment = Alignment.centerLeft,
    this.numeric = false,
  });

  DataColumn toDataColumn() {
    return DataColumn(
      label: Expanded(
        child: Text(label),
      ),
      numeric: numeric,
    );
  }
}

/// Responsive wrapper for data tables with automatic column sizing
class ResponsiveDataTable extends StatelessWidget {
  final List<ResponsiveDataColumn> columns;
  final List<DataRow> rows;
  final bool showCheckboxColumn;
  final bool isHorizontalScrollBarVisible;
  final EdgeInsetsGeometry scrollPadding;
  final double? minWidth;

  const ResponsiveDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.showCheckboxColumn = false,
    this.isHorizontalScrollBarVisible = true,
    this.scrollPadding = const EdgeInsets.all(16),
    this.minWidth,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive(context);
    final columnCount = columns.length;
    
    // Calculate total available width
    double availableWidth = responsive.width - (responsive.pagePadding * 2);
    if (!responsive.isCompact) {
      availableWidth -= responsive.sidebarExpandedWidth;
    }

    // Calculate minimum width needed
    final minTableWidth = minWidth ?? 
        (columnCount * 100 + (columnCount - 1) * 16);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: availableWidth > minTableWidth ? availableWidth : minTableWidth,
        child: DataTable(
          columns: columns.map((col) => col.toDataColumn()).toList(),
          rows: rows,
          showCheckboxColumn: showCheckboxColumn,
          horizontalMargin: responsive.tableHorizontalPadding,
          columnSpacing: 16,
          dataRowMinHeight: responsive.tableRowHeight,
          dataRowMaxHeight: responsive.tableRowHeight + 8,
          headingRowHeight: responsive.tableRowHeight + 4,
          dividerThickness: 1,
        ),
      ),
    );
  }
}

/// Responsive grid view builder with adaptive column counts
class ResponsiveGridView extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry padding;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final ScrollController? controller;

  const ResponsiveGridView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.all(16),
    this.mainAxisSpacing = 12,
    this.crossAxisSpacing = 12,
    this.shrinkWrap = false,
    this.physics,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive(context);
    final columnCount = responsive.gridColumns;

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnCount,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: responsive.cardAspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      controller: controller,
    );
  }
}

/// Responsive grid view with adaptive column widths
class ResponsiveAdaptiveGridView extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double minChildWidth;
  final EdgeInsetsGeometry padding;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final ScrollController? controller;

  const ResponsiveAdaptiveGridView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.minChildWidth = 160,
    this.padding = const EdgeInsets.all(16),
    this.mainAxisSpacing = 12,
    this.crossAxisSpacing = 12,
    this.shrinkWrap = false,
    this.physics,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive(context);

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: minChildWidth,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: responsive.cardAspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      controller: controller,
    );
  }
}

/// Responsive list view with adaptive item sizing
class ResponsiveListView extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double? itemHeight;
  final Axis scrollDirection;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  final bool reverse;
  final EdgeInsetsGeometry itemMargin;

  const ResponsiveListView({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(16),
    this.itemHeight,
    this.scrollDirection = Axis.vertical,
    this.shrinkWrap = false,
    this.physics,
    this.controller,
    this.reverse = false,
    this.itemMargin = const EdgeInsets.symmetric(vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: children.length,
      itemBuilder: (context, index) {
        return Container(
          margin: itemMargin,
          child: children[index],
        );
      },
      padding: padding,
      scrollDirection: scrollDirection,
      shrinkWrap: shrinkWrap,
      physics: physics,
      controller: controller,
      reverse: reverse,
    );
  }
}

/// Responsive table-to-card layout switcher
/// Shows table on desktop, cards on mobile
class ResponsiveTableOrCards extends StatelessWidget {
  final List<ResponsiveDataColumn> columns;
  final List<DataRow> rows;
  final List<Widget> cardItems;
  final bool showCheckboxColumn;
  final EdgeInsetsGeometry padding;

  const ResponsiveTableOrCards({
    super.key,
    required this.columns,
    required this.rows,
    required this.cardItems,
    this.showCheckboxColumn = false,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive(context);

    if (responsive.useCardLayout) {
      // Show card-based layout on mobile
      return SingleChildScrollView(
        child: Padding(
          padding: padding,
          child: Column(
            children: cardItems,
          ),
        ),
      );
    } else {
      // Show table on desktop
      return ResponsiveDataTable(
        columns: columns,
        rows: rows,
        showCheckboxColumn: showCheckboxColumn,
      );
    }
  }
}

/// Responsive column wrapper that adapts column count based on screen size
class ResponsiveColumnBuilder extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;

  const ResponsiveColumnBuilder({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.padding = const EdgeInsets.all(16),
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive(context);

    if (responsive.isCompact) {
      // Single column on mobile
      return Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: crossAxisAlignment,
          mainAxisAlignment: mainAxisAlignment,
          children: children,
        ),
      );
    } else if (responsive.isMedium) {
      // Two columns on tablet
      return Padding(
        padding: padding,
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.start,
          children: children
              .map(
                (child) => SizedBox(
                  width: (responsive.width - padding.horizontal) / 2 - 8,
                  child: child,
                ),
              )
              .toList(),
        ),
      );
    } else {
      // Three columns on desktop
      return Padding(
        padding: padding,
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.start,
          children: children
              .map(
                (child) => SizedBox(
                  width: (responsive.width - padding.horizontal) / 3 - 10,
                  child: child,
                ),
              )
              .toList(),
        ),
      );
    }
  }
}

/// Extension on BoxConstraints for responsive grid calculations
extension ResponsiveGridExtension on Responsive {
  /// Calculate optimal column count for a grid with given item width
  int calculateGridColumns(double minItemWidth) {
    final availableWidth = width - (pagePadding * 2);
    return (availableWidth / minItemWidth).floor().clamp(1, 10);
  }

  /// Calculate actual column width for a grid
  double calculateActualColumnWidth(int columnCount) {
    final availableWidth = width - (pagePadding * 2);
    final spacing = 12 * (columnCount - 1);
    return (availableWidth - spacing) / columnCount;
  }
}
