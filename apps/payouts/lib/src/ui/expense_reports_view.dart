import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:payouts/src/actions.dart';
import 'package:payouts/src/model/constants.dart';
import 'package:payouts/src/model/invoice.dart';
import 'package:payouts/src/pivot.dart' as pivot;

class ExpenseReportsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        AddExpenseIntent: AddExpenseAction.instance,
        AddExpenseReportIntent: AddExpenseReportAction.instance,
      },
      child: const _RawExpenseReportsView(),
    );
  }
}

class _RawExpenseReportsView extends StatefulWidget {
  const _RawExpenseReportsView({Key? key}) : super(key: key);

  @override
  _RawExpenseReportsViewState createState() => _RawExpenseReportsViewState();
}

class _RawExpenseReportsViewState extends State<_RawExpenseReportsView> {
  late pivot.ListViewSelectionController _selectionController;
  ExpenseReport? _selectedExpenseReport;

  void _handleSelectedExpenseReportChanged() {
    final int selectedIndex = _selectionController.selectedIndex;
    setState(() {
      _selectedExpenseReport = InvoiceBinding.instance!.invoice!.expenseReports[selectedIndex];
    });
  }

  Widget _buildExpenseReportView() {
    if (_selectedExpenseReport == null) {
      return Container();
    } else {
      return _ExpenseReportView(
        expenseReport: _selectedExpenseReport!,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _selectionController = pivot.ListViewSelectionController();
    final ExpenseReports expenseReports = InvoiceBinding.instance!.invoice!.expenseReports;
    if (expenseReports.isNotEmpty) {
      _selectionController.selectedIndex = 0;
      _selectedExpenseReport = expenseReports.first;
    }
    _selectionController.addListener(_handleSelectedExpenseReportChanged);
  }

  @override
  void dispose() {
    _selectionController.removeListener(_handleSelectedExpenseReportChanged);
    _selectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          pivot.ActionLinkButton(
            image: AssetImage('assets/money_add.png'),
            text: 'Add expense report',
            intent: AddExpenseReportIntent(context: context),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: pivot.SplitPane(
              orientation: Axis.horizontal,
              initialSplitRatio: 0.25,
              roundToWholePixel: true,
              resizePolicy: pivot.SplitPaneResizePolicy.maintainBeforeSplitSize,
              before: ExpenseReportsListView(selectionController: _selectionController),
              after: DecoratedBox(
                decoration: BoxDecoration(border: Border.all(color: Color(0xFF999999))),
                child: _buildExpenseReportView(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseReportView extends StatelessWidget {
  const _ExpenseReportView({
    Key? key,
    required this.expenseReport,
  }) : super(key: key);

  final ExpenseReport expenseReport;

  TableRow _buildMetadataRow(String title, String value) {
    return TableRow(
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 4, right: 6),
          child: Text('$title:'),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text(value),
        ),
      ],
    );
  }

  String _buildDateRangeDisplay(DateRange dateRange) {
    StringBuffer buf = StringBuffer()
        ..write(pivot.CalendarDateFormat.iso8601.formatDateTime(dateRange.start))
        ..write(' to ')
      ..write(pivot.CalendarDateFormat.iso8601.formatDateTime(dateRange.end));
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(11, 11, 11, 9),
          child: DefaultTextStyle(
            style: Theme.of(context).textTheme.bodyText2!.copyWith(color: Colors.black),
            child: Table(
              columnWidths: {
                0: IntrinsicColumnWidth(),
                1: FlexColumnWidth(),
              },
              children: [
                _buildMetadataRow('Program', expenseReport.program.name),
                if (expenseReport.chargeNumber.isNotEmpty)
                  _buildMetadataRow('Charge number', expenseReport.chargeNumber),
                if (expenseReport.requestor.isNotEmpty)
                  _buildMetadataRow('Requestor', expenseReport.requestor),
                if (expenseReport.task.isNotEmpty)
                  _buildMetadataRow('Task', expenseReport.task),
                _buildMetadataRow('Dates', _buildDateRangeDisplay(expenseReport.period)),
                if (expenseReport.travelPurpose.isNotEmpty)
                  _buildMetadataRow('Purpose of travel', expenseReport.travelPurpose),
                if (expenseReport.travelDestination.isNotEmpty)
                  _buildMetadataRow('Destination (city)', expenseReport.travelDestination),
                if (expenseReport.travelParties.isNotEmpty)
                  _buildMetadataRow('Party or parties visited', expenseReport.travelParties),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: 9, left: 11),
          child: Row(
            children: [
              pivot.ActionLinkButton(
                image: AssetImage('assets/money_add.png'),
                text: 'Add expense line item',
                intent: AddExpenseIntent(
                  context: context,
                  expenseReport: expenseReport,
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: const Color(0xff999999),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(1),
            child: ColoredBox(
              color: const Color(0xffffffff),
              child: ExpensesTableView(expenseReport: expenseReport),
            ),
          ),
        ),
      ],
    );
  }
}

class ExpensesTableView extends StatefulWidget {
  const ExpensesTableView({
    Key? key,
    required this.expenseReport,
  }) : super(key: key);

  final ExpenseReport expenseReport;

  @override
  _ExpensesTableViewState createState() => _ExpensesTableViewState();
}

class _ExpensesTableViewState extends State<ExpensesTableView> {
  late pivot.TableViewSelectionController _selectionController;
  late pivot.TableViewSortController _sortController;
  late pivot.TableViewEditorController _editorController;

  pivot.TableHeaderRenderer _renderHeader(String name) {
    return ({
      required BuildContext context,
      required int columnIndex,
    }) {
      return Text(
        name,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
      );
    };
  }

  Widget _renderDate({
    required BuildContext context,
    required int rowIndex,
    required int columnIndex,
    required bool rowSelected,
    required bool rowHighlighted,
    required bool isEditing,
    required bool isRowDisabled,
  }) {
    final DateTime date = widget.expenseReport.expenses[rowIndex].date;
    final String formattedDate = DateFormats.iso8601Short.format(date);
    return ExpenseCellWrapper(
      rowIndex: rowIndex,
      rowHighlighted: rowHighlighted,
      rowSelected: rowSelected,
      content: formattedDate,
    );
  }

  Widget _renderType({
    required BuildContext context,
    required int rowIndex,
    required int columnIndex,
    required bool rowSelected,
    required bool rowHighlighted,
    required bool isEditing,
    required bool isRowDisabled,
  }) {
    final ExpenseType type = widget.expenseReport.expenses[rowIndex].type;
    if (isEditing) {
      return _renderTypeEditor(type);
    }
    return ExpenseCellWrapper(
      rowIndex: rowIndex,
      rowHighlighted: rowHighlighted,
      rowSelected: rowSelected,
      content: type.name,
    );
  }

  Widget _renderTypeEditor(ExpenseType type) {
    return pivot.PushButton<String>(
      onPressed: () {},
      label: type.name,
      menuItems: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'type1',
          height: 22,
          child: Text('Another type'),
        ),
        PopupMenuItem<String>(
          value: 'type2',
          height: 22,
          child: Text('Yet another type'),
        ),
      ],
      onMenuItemSelected: (String? value) {},
    );
  }

  Widget _renderAmount({
    required BuildContext context,
    required int rowIndex,
    required int columnIndex,
    required bool rowSelected,
    required bool rowHighlighted,
    required bool isEditing,
    required bool isRowDisabled,
  }) {
    final double amount = widget.expenseReport.expenses[rowIndex].amount;
    return ExpenseCellWrapper(
      rowIndex: rowIndex,
      rowHighlighted: rowHighlighted,
      rowSelected: rowSelected,
      content: NumberFormats.currency.format(amount),
    );
  }

  Widget _renderDescription({
    required BuildContext context,
    required int rowIndex,
    required int columnIndex,
    required bool rowSelected,
    required bool rowHighlighted,
    required bool isEditing,
    required bool isRowDisabled,
  }) {
    final String description = widget.expenseReport.expenses[rowIndex].description;
    return ExpenseCellWrapper(
      rowIndex: rowIndex,
      rowHighlighted: rowHighlighted,
      rowSelected: rowSelected,
      content: description,
    );
  }

  @override
  void initState() {
    super.initState();
    _selectionController = pivot.TableViewSelectionController(selectMode: pivot.SelectMode.multi);
    _sortController = pivot.TableViewSortController(sortMode: pivot.TableViewSortMode.singleColumn);
    _editorController = pivot.TableViewEditorController();
  }

  @override
  void didUpdateWidget(ExpensesTableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expenseReport != oldWidget.expenseReport) {
      _selectionController.selectedIndex = -1;
    }
  }

  @override
  void dispose() {
    _selectionController.dispose();
    _sortController.dispose();
    _editorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return pivot.ScrollableTableView(
      rowHeight: 19,
      length: widget.expenseReport.expenses.length,
      selectionController: _selectionController,
      sortController: _sortController,
      editorController: _editorController,
      roundColumnWidthsToWholePixel: false,
      columns: <pivot.TableColumnController>[
        pivot.TableColumnController(
          key: 'date',
          width: pivot.ConstrainedTableColumnWidth(width: 120, minWidth: 20),
          cellRenderer: _renderDate,
          headerRenderer: _renderHeader('Date'),
        ),
        pivot.TableColumnController(
          key: 'type',
          width: pivot.ConstrainedTableColumnWidth(width: 120, minWidth: 20),
          cellRenderer: _renderType,
          headerRenderer: _renderHeader('Type'),
        ),
        pivot.TableColumnController(
          key: 'amount',
          width: pivot.ConstrainedTableColumnWidth(width: 100, minWidth: 20),
          cellRenderer: _renderAmount,
          headerRenderer: _renderHeader('Amount'),
        ),
        pivot.TableColumnController(
          key: 'description',
          width: pivot.FlexTableColumnWidth(),
          cellRenderer: _renderDescription,
          headerRenderer: _renderHeader('Description'),
        ),
      ],
    );
  }
}

class ExpenseCellWrapper extends StatelessWidget {
  const ExpenseCellWrapper({
    Key? key,
    this.rowIndex = 0,
    this.rowHighlighted = false,
    this.rowSelected = false,
    required this.content,
  }) : super(key: key);

  final int rowIndex;
  final bool rowHighlighted;
  final bool rowSelected;
  final String content;

  static const List<Color> colors = <Color>[Color(0xffffffff), Color(0xfff7f5ee)];

  @override
  Widget build(BuildContext context) {
    TextStyle style = DefaultTextStyle.of(context).style;
    if (rowSelected) {
      style = style.copyWith(color: const Color(0xffffffff));
    }
    Widget result = Padding(
      padding: EdgeInsets.fromLTRB(2, 3, 2, 3),
      child: Text(
        content,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        style: style,
      ),
    );

    if (!rowHighlighted && !rowSelected) {
      result = ColoredBox(
        color: colors[rowIndex % 2],
        child: result,
      );
    }

    return result;
  }
}

class ExpenseReportsListView extends StatefulWidget {
  const ExpenseReportsListView({
    Key? key,
    required this.selectionController,
  }) : super(key: key);

  final pivot.ListViewSelectionController selectionController;

  @override
  _ExpenseReportsListViewState createState() => _ExpenseReportsListViewState();
}

class _ExpenseReportsListViewState extends State<ExpenseReportsListView> {
  late InvoiceListener _invoiceListener;
  late ExpenseReports _expenseReports;

  void _handleExpenseReportInserted(int expenseReportsIndex) {
    setState(() {
      // _expenseReports reference stays the same
    });
  }

  void _handleExpenseReportsRemoved(int expenseReportsIndex, Iterable<ExpenseReport> removed) {
    setState(() {
      // _expenseReports reference stays the same
    });
  }

  Widget _buildItem({
    required BuildContext context,
    required int index,
    required bool isSelected,
    required bool isHighlighted,
    required bool isDisabled,
  }) {
    final ExpenseReport data = _expenseReports[index];
    final StringBuffer buf = StringBuffer(data.program.name);

    final String chargeNumber = data.chargeNumber.trim();
    if (chargeNumber.isNotEmpty) {
      buf.write(' ($chargeNumber)');
    }

    final String task = data.task.trim();
    if (task.isNotEmpty) {
      buf.write(' ($task)');
    }

    final String title = buf.toString();
    final String total = '(${NumberFormats.currency.format(data.total)})';

    Widget result = Padding(
      padding: const EdgeInsets.all(2),
      child: Row(
        children: [
          Expanded(
              child: Text(
            title,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
          )),
          const SizedBox(width: 2),
          Text(total),
        ],
      ),
    );

    if (isSelected) {
      final TextStyle style = DefaultTextStyle.of(context).style;
      result = DefaultTextStyle(
        style: style.copyWith(color: const Color(0xffffffff)),
        child: result,
      );
    }

    return result;
  }

  @override
  void initState() {
    super.initState();
    _expenseReports = InvoiceBinding.instance!.invoice!.expenseReports;
    _invoiceListener = InvoiceListener(
      onExpenseReportInserted: _handleExpenseReportInserted,
      onExpenseReportsRemoved: _handleExpenseReportsRemoved,
    );
    InvoiceBinding.instance!.addListener(_invoiceListener);
  }

  @override
  void dispose() {
    InvoiceBinding.instance!.removeListener(_invoiceListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xffffffff),
        border: Border.fromBorderSide(BorderSide(color: Color(0xff999999))),
      ),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: pivot.ScrollableListView(
          itemHeight: 19,
          length: _expenseReports.length,
          itemBuilder: _buildItem,
          selectionController: widget.selectionController,
        ),
      ),
    );
  }
}
