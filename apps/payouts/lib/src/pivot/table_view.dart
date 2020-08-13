import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' hide TableColumnWidth;
import 'package:flutter/widgets.dart' hide TableColumnWidth;
import 'package:payouts/src/pivot/span.dart';

import 'basic_table_view.dart';
import 'scroll_pane.dart';
import 'sorting.dart';

/// Signature for a function that renders headers in a [ScrollableTableView].
///
/// Header renderers are properties of the [TableColumnController], so each
/// column specifies the renderer for that column's header.
///
/// See also:
///  * [TableCellRenderer], which renders table body cells.
typedef TableHeaderRenderer = Widget Function({
  BuildContext context,
  int columnIndex,
});

/// Signature for a function that renders cells in a [ScrollableTableView].
///
/// Cell renderers are properties of the [TableColumnController], so each
/// column specifies the cell renderer for cells in that column.
///
/// The `rowSelected` argument specifies whether the row is currently selected,
/// as indicated by the [TableViewSelectionController] that's associated with
/// the table view.
///
/// The `rowHighlighted` argument specifies whether the row is highlighted,
/// typically because the table view allows selection of rows, and a mouse
/// cursor is currently hovering over the row.
///
/// See also:
///  * [TableHeaderRenderer], which renders a column's header.
///  * [TableViewSelectionController.selectMode], which dictates whether rows
///    are eligible to become highlighted.
///  * [BasicTableCellRenderer], the equivalent cell renderer for a
///    [BasicTableView].
typedef TableCellRenderer = Widget Function({
  BuildContext context,
  int rowIndex,
  int columnIndex,
  bool rowSelected,
  bool rowHighlighted,
});

/// Controls the properties of a column in a [ScrollableTableView].
///
/// Mutable properties such as [width] and [sortDirection] will notify
/// listeners when changed.
///
/// See also:
///  * [BasicTableColumn]
class TableColumnController extends BasicTableColumn with ChangeNotifier {
  TableColumnController({
    @required this.name,
    @required this.headerRenderer,
    @required TableCellRenderer cellRenderer,
    TableColumnWidth width = const FlexTableColumnWidth(),
    SortDirection sortDirection,
  })  : assert(name != null),
        assert(cellRenderer != null),
        assert(headerRenderer != null),
        assert(width != null),
        _width = width,
        super(cellRenderer: cellRenderer);

  // TODO: do we need this?  How do we document it?
  final String name;

  /// The renderer responsible for the look & feel of the header for this column.
  final TableHeaderRenderer headerRenderer;

  @override
  TableCellRenderer get cellRenderer => super.cellRenderer as TableCellRenderer;

  TableColumnWidth _width;

  /// The width specification for the column.
  ///
  /// Instances of [ConstrainedTableColumnWidth] will cause a column to become
  /// resizable.
  ///
  /// Changing this value will notify listeners.
  @override
  TableColumnWidth get width => _width;
  set width(TableColumnWidth value) {
    assert(value != null);
    if (value == _width) return;
    _width = value;
    notifyListeners();
  }

  /// The sort direction of the column (may be null).
  ///
  /// Changing this value will notify listeners.
  ///
  /// This value does not directly control the sorting of the underlying table
  /// data. It's the responsibility of listeners to respond to the change
  /// notification by sorting the data.
  SortDirection _sortDirection;
  SortDirection get sortDirection => _sortDirection;
  set sortDirection(SortDirection value) {
    assert(value != null);
    if (value == _sortDirection) return;
    _sortDirection = value;
    notifyListeners();
  }
}

enum SelectMode {
  none,
  single,
  multi,
}

class TableViewSelectionController with ChangeNotifier {
  TableViewSelectionController({
    this.selectMode = SelectMode.none,
  }) : assert(selectMode != null);

  /// TODO: document
  final SelectMode selectMode;

  ListSelection _selectedRanges = ListSelection();
  RenderTableView _renderObject;

  /// True if this controller is associated with a [ScrollableTableView].
  ///
  /// A selection controller may only be associated with one table view at a
  /// time.
  bool get isAttached => _renderObject != null;

  void _attach(RenderTableView renderObject) {
    assert(!isAttached);
    _renderObject = renderObject;
  }

  void _detach() {
    assert(isAttached);
    _renderObject = null;
  }

  /// TODO: document
  int get selectedIndex {
    assert(selectMode == SelectMode.single);
    return _selectedRanges.isEmpty ? -1 : _selectedRanges[0].start;
  }

  set selectedIndex(int index) {
    if (index == -1) {
      clearSelection();
    } else {
      selectedRange = Span.single(index);
    }
  }

  /// TODO: document
  Span get selectedRange {
    assert(_selectedRanges.length <= 1);
    return _selectedRanges.isEmpty ? null : _selectedRanges[0];
  }

  set selectedRange(Span range) {
    selectedRanges = <Span>[range];
  }

  /// TODO: document
  Iterable<Span> get selectedRanges {
    return _selectedRanges.data;
  }

  set selectedRanges(Iterable<Span> ranges) {
    assert(ranges != null);
    assert(selectMode != SelectMode.none, 'Selection is not enabled');
    assert(() {
      if (selectMode == SelectMode.single) {
        if (ranges.length > 1) {
          return false;
        }
        if (ranges.isNotEmpty) {
          final Span range = ranges.single;
          if (range.length > 1) {
            return false;
          }
        }
      }
      return true;
    }());

    final ListSelection selectedRanges = ListSelection();
    for (Span range in ranges) {
      assert(range != null);
      assert(range.start >= 0 && (!isAttached || range.end < _renderObject.length));
      _selectedRanges.addRange(range.start, range.end);
    }
    _selectedRanges = selectedRanges;
    notifyListeners();
  }

  int get firstSelectedIndex => _selectedRanges.isNotEmpty ? _selectedRanges.first.start : -1;

  int get lastSelectedIndex => _selectedRanges.isNotEmpty ? _selectedRanges.last.end : -1;

  bool addSelectedIndex(int index) {
    final List<Span> addedRanges = addSelectedRange(index, index);
    return addedRanges.isNotEmpty;
  }

  List<Span> addSelectedRange(int start, int end) {
    assert(selectMode == SelectMode.multi);
    assert(start >= 0 && (!isAttached || end < _renderObject.length));
    final List<Span> addedRanges = _selectedRanges.addRange(start, end);
    notifyListeners();
    return addedRanges;
  }

  bool removeSelectedIndex(int index) {
    List<Span> removedRanges = removeSelectedRange(index, index);
    return removedRanges.isNotEmpty;
  }

  List<Span> removeSelectedRange(int start, int end) {
    assert(selectMode == SelectMode.multi);
    assert(start >= 0 && (!isAttached || end < _renderObject.length));
    final List<Span> removedRanges = _selectedRanges.removeRange(start, end);
    notifyListeners();
    return removedRanges;
  }

  void selectAll() {
    assert(isAttached);
    selectedRange = Span(0, _renderObject.length - 1);
  }

  void clearSelection() {
    if (_selectedRanges.isNotEmpty) {
      _selectedRanges = ListSelection();
      notifyListeners();
    }
  }

  bool isRowSelected(int rowIndex) {
    assert(rowIndex >= 0 && isAttached && rowIndex < _renderObject.length);
    return _selectedRanges.containsIndex(rowIndex);
  }
}

class ConstrainedTableColumnWidth extends TableColumnWidth {
  const ConstrainedTableColumnWidth({
    double width,
    this.minWidth = 0.0,
    this.maxWidth = double.infinity,
  })  : assert(width != null),
        assert(width >= 0),
        assert(width < double.infinity),
        assert(minWidth != null),
        assert(minWidth >= 0),
        assert(maxWidth != null),
        assert(maxWidth >= minWidth),
        super(width);

  final double minWidth;
  final double maxWidth;

  ConstrainedTableColumnWidth copyWith({
    double width,
    double minWidth,
    double maxWidth,
  }) {
    minWidth ??= this.minWidth;
    maxWidth ??= this.maxWidth;
    width ??= this.width;
    width = width.clamp(minWidth, maxWidth);
    return ConstrainedTableColumnWidth(
      width: width,
      minWidth: minWidth,
      maxWidth: maxWidth,
    );
  }

  @override
  @protected
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('minWidth', minWidth));
    properties.add(DoubleProperty('maxWidth', maxWidth));
  }
}

typedef TableColumnResizeCallback = void Function(int columnIndex, double delta);

class TableViewHeader extends StatelessWidget {
  const TableViewHeader({
    Key key,
    this.rowHeight,
    this.columns,
    this.headerRenderers,
    this.roundColumnWidthsToWholePixel,
    this.handleColumnResize,
  }) : super(key: key);

  final double rowHeight;
  final List<BasicTableColumn> columns;
  final List<TableHeaderRenderer> headerRenderers;
  final bool roundColumnWidthsToWholePixel;
  final TableColumnResizeCallback handleColumnResize;

  Widget _renderHeader({
    BuildContext context,
    int rowIndex,
    int columnIndex,
  }) {
    final BasicTableColumn column = columns[columnIndex];
    final bool isColumnResizable = column.width is ConstrainedTableColumnWidth;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: <Color>[
            const Color(0xffdfded7),
            const Color(0xfff6f4ed),
          ],
        ),
        border: Border(
          bottom: const BorderSide(color: const Color(0xff999999)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 3),
              child: headerRenderers[columnIndex](context: context, columnIndex: columnIndex),
            ),
          ),
          if (handleColumnResize != null && isColumnResizable)
            SizedBox(
              width: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    right: const BorderSide(color: const Color(0xff999999)),
                  ),
                ),
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: GestureDetector(
                    key: Key('$this dividerKey $columnIndex'),
                    behavior: HitTestBehavior.translucent,
                    dragStartBehavior: DragStartBehavior.down,
                    onHorizontalDragUpdate: (DragUpdateDetails details) {
                      handleColumnResize(columnIndex, details.primaryDelta);
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BasicTableView(
      rowHeight: rowHeight,
      length: 1,
      roundColumnWidthsToWholePixel: roundColumnWidthsToWholePixel,
      columns: List<BasicTableColumn>.generate(columns.length, (int index) {
        return BasicTableColumn(
          width: columns[index].width,
          cellRenderer: _renderHeader,
        );
      }),
    );
  }
}

class ScrollableTableView extends StatefulWidget {
  const ScrollableTableView({
    Key key,
    @required this.rowHeight,
    @required this.length,
    @required this.columns,
    this.selectionController,
    this.roundColumnWidthsToWholePixel = false,
  })  : assert(rowHeight != null),
        assert(length != null),
        assert(columns != null),
        assert(roundColumnWidthsToWholePixel != null),
        super(key: key);

  final double rowHeight;
  final int length;
  final List<TableColumnController> columns;
  final TableViewSelectionController selectionController;
  final bool roundColumnWidthsToWholePixel;

  @override
  _ScrollableTableViewState createState() => _ScrollableTableViewState();
}

class _ScrollableTableViewState extends State<ScrollableTableView> {
  List<TableHeaderRenderer> _headerRenderers;

  void _updateColumns() {
    setState(() {
      _headerRenderers = List<TableHeaderRenderer>.generate(widget.columns.length, (int index) {
        return widget.columns[index].headerRenderer;
      });
    });
  }

  void _addColumnListener(TableColumnController column) {
    column.addListener(_updateColumns);
  }

  void _removeColumnListener(TableColumnController column) {
    column.removeListener(_updateColumns);
  }

  @override
  void initState() {
    super.initState();
    _updateColumns();
    widget.columns.forEach(_addColumnListener);
  }

  @override
  void didUpdateWidget(ScrollableTableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateColumns();
    oldWidget.columns.forEach(_removeColumnListener);
    widget.columns.forEach(_addColumnListener);
  }

  @override
  void dispose() {
    widget.columns.forEach(_removeColumnListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollPane(
      horizontalScrollBarPolicy: ScrollBarPolicy.expand,
      verticalScrollBarPolicy: ScrollBarPolicy.auto,
      columnHeader: TableViewHeader(
        rowHeight: widget.rowHeight,
        columns: widget.columns,
        headerRenderers: _headerRenderers,
        roundColumnWidthsToWholePixel: widget.roundColumnWidthsToWholePixel,
        handleColumnResize: (int columnIndex, double delta) {
          final TableColumnController column = widget.columns[columnIndex];
          assert(column.width is ConstrainedTableColumnWidth);
          final ConstrainedTableColumnWidth width = column.width;
          column.width = width.copyWith(width: width.width + delta);
        },
      ),
      view: TableView(
        length: widget.length,
        rowHeight: widget.rowHeight,
        columns: widget.columns,
        roundColumnWidthsToWholePixel: widget.roundColumnWidthsToWholePixel,
        selectionController: widget.selectionController,
      ),
    );
  }
}

class TableView extends StatefulWidget {
  const TableView({
    Key key,
    @required this.rowHeight,
    @required this.length,
    @required this.columns,
    this.selectionController,
    this.roundColumnWidthsToWholePixel = false,
  })  : assert(rowHeight != null),
        assert(length != null),
        assert(columns != null),
        assert(roundColumnWidthsToWholePixel != null),
        super(key: key);

  final double rowHeight;
  final int length;
  final List<TableColumnController> columns;
  final TableViewSelectionController selectionController;
  final bool roundColumnWidthsToWholePixel;

  @override
  _TableViewState createState() => _TableViewState();
}

class _TableViewState extends State<TableView> {
  StreamController<PointerEvent> _pointerEvents;

  @override
  void initState() {
    super.initState();
    _pointerEvents = StreamController();
  }

  @override
  void dispose() {
    _pointerEvents.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget result = _RawTableView(
      rowHeight: widget.rowHeight,
      length: widget.length,
      columns: widget.columns,
      selectionController: widget.selectionController,
      roundColumnWidthsToWholePixel: widget.roundColumnWidthsToWholePixel,
      pointerEvents: _pointerEvents.stream,
    );

    if (widget.selectionController.selectMode != SelectMode.none) {
      result = MouseRegion(
        onEnter: _pointerEvents.add,
        onExit: _pointerEvents.add,
        onHover: _pointerEvents.add,
        child: result,
      );
    }

    return result;
  }
}

class _RawTableView extends BasicTableView {
  const _RawTableView({
    Key key,
    @required double rowHeight,
    @required int length,
    @required List<TableColumnController> columns,
    bool roundColumnWidthsToWholePixel = false,
    this.selectionController,
    @required this.pointerEvents,
  }) : super(
          key: key,
          rowHeight: rowHeight,
          length: length,
          columns: columns,
          roundColumnWidthsToWholePixel: roundColumnWidthsToWholePixel,
        );

  final TableViewSelectionController selectionController;
  final Stream<PointerEvent> pointerEvents;

  @override
  List<TableColumnController> get columns => super.columns as List<TableColumnController>;

  @override
  BasicTableViewElement createElement() => TableViewElement(this);

  @override
  RenderTableView createRenderObject(BuildContext context) {
    return RenderTableView(
      rowHeight: rowHeight,
      length: length,
      columns: columns,
      roundColumnWidthsToWholePixel: roundColumnWidthsToWholePixel,
      selectionController: selectionController,
      pointerEvents: pointerEvents,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderTableView renderObject) {
    super.updateRenderObject(context, renderObject);
    renderObject
      ..selectionController = selectionController
      ..pointerEvents = pointerEvents;
  }
}

class TableViewElement extends BasicTableViewElement {
  TableViewElement(_RawTableView tableView) : super(tableView);

  @override
  _RawTableView get widget => super.widget as _RawTableView;

  @override
  RenderTableView get renderObject => super.renderObject as RenderTableView;

  @override
  @protected
  Widget renderCell(covariant TableColumnController column, int rowIndex, int columnIndex) {
    return column.cellRenderer(
      context: this,
      rowIndex: rowIndex,
      columnIndex: columnIndex,
      rowHighlighted: renderObject.highlightedRow == rowIndex,
    );
  }
}

class RenderTableView extends RenderBasicTableView {
  RenderTableView({
    double rowHeight,
    int length,
    List<TableColumnController> columns,
    bool roundColumnWidthsToWholePixel = false,
    TableViewSelectionController selectionController,
    Stream<PointerEvent> pointerEvents,
  })  : assert(selectionController != null),
        assert(pointerEvents != null),
        _selectionController = selectionController,
        super(
          rowHeight: rowHeight,
          length: length,
          columns: columns,
          roundColumnWidthsToWholePixel: roundColumnWidthsToWholePixel,
        ) {
    // Set this here to ensure that we listen to the stream.
    this.pointerEvents = pointerEvents;
  }

  TableViewSelectionController _selectionController;
  TableViewSelectionController get selectionController => _selectionController;
  set selectionController(TableViewSelectionController value) {
    assert(value != null);
    if (_selectionController == value) return;
    if (_selectionController != null && attached) {
      _selectionController._detach();
    }
    _selectionController = value;
    if (_selectionController != null && attached) {
      _selectionController._attach(this);
    }
    markNeedsBuild();
  }

  StreamSubscription<PointerEvent> _pointerEventsSubscription;
  Stream<PointerEvent> _pointerEvents;
  Stream<PointerEvent> get pointerEvents => _pointerEvents;
  set pointerEvents(Stream<PointerEvent> value) {
    assert(value != null);
    if (_pointerEvents == value) return;
    if (_pointerEvents != null) {
      assert(_pointerEventsSubscription != null);
      _pointerEventsSubscription.cancel();
    }
    _pointerEvents = value;
    _pointerEventsSubscription = _pointerEvents.listen(_onPointerEvent);
  }

  int _highlightedRow;
  int get highlightedRow => _highlightedRow;
  set highlightedRow(int value) {
    if (_highlightedRow == value) return;
    _highlightedRow = value;
    // TODO: only mark the old and new highlighted row as needing build
    markNeedsBuild();
  }

  void _onPointerExit(PointerExitEvent event) {
    highlightedRow = null;
  }

  void _onPointerScroll(PointerScrollEvent event) {
    if (event.scrollDelta != Offset.zero) {
      highlightedRow = null;
    }
  }

  void _onPointerHover(PointerHoverEvent event) {
    final TableCellOffset cellOffset = metrics.hitTest(event.localPosition);
    if (cellOffset != null) {
      highlightedRow = cellOffset.rowIndex;
    }
  }

  void _onPointerEvent(PointerEvent event) {
    if (event is PointerExitEvent) return _onPointerExit(event);
    if (event is PointerScrollEvent) return _onPointerScroll(event);
    if (event is PointerHoverEvent) return _onPointerHover(event);
  }

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    assert(debugHandleEvent(event, entry));
    _onPointerEvent(event);
    super.handleEvent(event, entry);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (_selectionController != null) {
      _selectionController._attach(this);
    }
  }

  @override
  void detach() {
    if (_selectionController != null) {
      _selectionController._detach();
    }
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_highlightedRow != null) {
      final Rect rowBounds = metrics.getRowBounds(_highlightedRow);
      Paint paint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xffdddcd5);
      context.canvas.drawRect(rowBounds.shift(offset), paint);
    }
    super.paint(context, offset);
  }
}
