import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Class that allows callers to measure the size of arbitrary widgets when
/// laid out with specific constraints.
///
/// The widget surveyor creates synthetic widget trees to hold the widgets it
/// measures. This is important because if the widgets (or any widgets in their
/// subtrees) depend on any inherited widgets (e.g. [Directionality]) that they
/// assume exist in their ancestry, those assumptions may hold true when the
/// widget is rendered by the application but prove false when the widget is
/// rendered via the widget surveyor. Due to this, callers are advised to
/// either:
///
///  1. pass in widgets that don't depend on inherited widgets, or
///  1. ensure all inherited widget dependencies exist in the widget tree
///     that's passed to the widget surveyor's measure methods.
class WidgetSurveyor {
  const WidgetSurveyor();

  /// Builds a widget from the specified builder, inserts the widget into a
  /// synthetic widget tree, lays out the resulting render tree, and returns
  /// the size of the laid-out render tree.
  ///
  /// The build context that's passed to the `builder` argument will represent
  /// the root of the synthetic tree.
  ///
  /// The `constraints` argument specify the constraints that will be passed
  /// to the render tree during layout. If unspecified, the widget will be laid
  /// out unconstrained.
  Size measureBuilder(
    WidgetBuilder builder, {
    BoxConstraints constraints = const BoxConstraints(),
  }) {
    return measureWidget(Builder(builder: builder), constraints: constraints);
  }

  /// Inserts the specified widget into a synthetic widget tree, lays out the
  /// resulting render tree, and returns the size of the laid-out render tree.
  ///
  /// The `constraints` argument specify the constraints that will be passed
  /// to the render tree during layout. If unspecified, the widget will be laid
  /// out unconstrained.
  Size measureWidget(
    Widget widget, {
    BoxConstraints constraints = const BoxConstraints(),
  }) {
    final _MeasurementView rendered = _render(widget, constraints);
    assert(rendered.hasSize);
    return rendered.size;
  }

  double measureDistanceToBaseline(
    Widget widget, {
    TextBaseline baseline = TextBaseline.alphabetic,
    BoxConstraints constraints = const BoxConstraints(),
  }) {
    final _MeasurementView rendered = _render(widget, constraints, baselineToCalculate: baseline);
    return rendered.childBaseline ?? rendered.size.height;
  }

  double? measureDistanceToActualBaseline(
    Widget widget, {
    TextBaseline baseline = TextBaseline.alphabetic,
    BoxConstraints constraints = const BoxConstraints(),
  }) {
    final _MeasurementView rendered = _render(widget, constraints, baselineToCalculate: baseline);
    return rendered.childBaseline;
  }

  _MeasurementView _render(
    Widget widget,
    BoxConstraints constraints, {
    TextBaseline? baselineToCalculate,
  }) {
    final PipelineOwner pipelineOwner = PipelineOwner(
      onNeedVisualUpdate: () {
        assert(() {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary('Visual update was requested during survey.'),
            ErrorDescription('WidgetSurveyor does not support a render object '
                'calling markNeedsLayout(), markNeedsPaint(), or '
                'markNeedsSemanticUpdate() while the widget is being surveyed.'),
          ]);
        }());
      },
    );
    final _MeasurementView rootView = pipelineOwner.rootNode = _MeasurementView();
    final BuildOwner buildOwner = _SurveyorBuildOwner();
    final RenderObjectToWidgetAdapter<RenderBox> adapter = RenderObjectToWidgetAdapter<RenderBox>(
      container: rootView,
      debugShortDescription: '[root]',
      child: widget,
    );
    final RenderObjectToWidgetElement element = adapter.createElement()..assignOwner(buildOwner);
    buildOwner.buildScope(element, () {
      element.mount(null /* parent */, null /* newSlot */);
    });
    try {
      rootView.baselineToCalculate = baselineToCalculate;
      rootView.childConstraints = constraints;
      rootView.scheduleInitialLayout();
      pipelineOwner.flushLayout();
      assert(rootView.child != null);
      return rootView;
    } finally {
      // Failing to clean up and un-mount the element will lead to leaking
      // global keys, which are referenced statically.
      pipelineOwner.rootNode = null;
      element.deactivate();
      element.unmount();
    }
  }
}

class _SurveyorBuildOwner extends BuildOwner {
  _SurveyorBuildOwner() : super(focusManager: _FailingFocusManager());
}

class _FailingFocusManager implements FocusManager {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }

  @override
  String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return '_FakeFocusManager';
  }
}

class _MeasurementView extends RenderBox with RenderObjectWithChildMixin<RenderBox> {
  BoxConstraints? childConstraints;
  TextBaseline? baselineToCalculate;
  double? childBaseline;

  @override
  void performLayout() {
    assert(child != null);
    assert(childConstraints != null);
    child!.layout(childConstraints!, parentUsesSize: true);
    if (baselineToCalculate != null) {
      childBaseline = child!.getDistanceToBaseline(baselineToCalculate!);
    }
    size = child!.size;
  }

  @override
  void debugAssertDoesMeetConstraints() => true;
}
