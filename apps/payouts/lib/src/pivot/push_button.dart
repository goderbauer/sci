import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';

import 'colors.dart';
import 'sorting.dart';

class PushButton<T> extends StatefulWidget {
  const PushButton({
    Key key,
    this.icon,
    this.label,
    this.axis = Axis.horizontal,
    this.isToolbar = false,
    this.onPressed,
    this.menuItems,
    this.onMenuItemSelected,
    this.minimumAspectRatio,
    this.color = const Color(0xff000000),
    this.backgroundColor = const Color(0xffdddcd5),
    this.borderColor = const Color(0xff999999),
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    this.showTooltip = true,
  }) : super(key: key);

  final String icon;
  final String label;
  final Axis axis;
  final bool isToolbar;
  final VoidCallback onPressed;
  final List<PopupMenuEntry<T>> menuItems;
  final PopupMenuItemSelected<T> onMenuItemSelected;
  final double minimumAspectRatio;
  final Color color;
  final Color backgroundColor;
  final Color borderColor;
  final EdgeInsets padding;
  final bool showTooltip;

  @override
  _PushButtonState<T> createState() => _PushButtonState<T>();
}

class _PushButtonState<T> extends State<PushButton<T>> {
  bool hover;
  bool pressed;
  bool menuActive;

  LinearGradient get highlightGradient {
    return LinearGradient(
      begin: Alignment(0, 0.2),
      end: Alignment.topCenter,
      colors: <Color>[widget.backgroundColor, brighten(widget.backgroundColor)],
    );
  }

  LinearGradient get pressedGradient {
    return LinearGradient(
      begin: Alignment.center,
      end: Alignment.topCenter,
      colors: <Color>[widget.backgroundColor, darken(widget.backgroundColor)],
    );
  }

  @override
  void initState() {
    super.initState();
    hover = false;
    pressed = false;
    menuActive = false;
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;

    final List<Widget> buttonData = <Widget>[];
    if (widget.icon != null) {
      Widget iconImage = Image(image: AssetImage(widget.icon));
      if (!enabled) {
        iconImage = Opacity(
          opacity: 0.5,
          child: iconImage,
        );
      }
      buttonData..add(iconImage)..add(SizedBox(width: 4, height: 4));
    }

    if (widget.label != null) {
      TextStyle style = Theme.of(context).textTheme.bodyText2;
      if (enabled) {
        style = style.copyWith(color: widget.color);
      } else {
        style = style.copyWith(color: const Color(0xff999999));
      }
      buttonData.add(Text(widget.label, style: style));
    }

    Widget button = Center(
      child: Padding(
        padding: widget.padding,
        child: widget.axis == Axis.horizontal ? Row(children: buttonData) : Column(children: buttonData),
      ),
    );

    if (widget.menuItems != null) {
      button = Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: button,
          ),
          Spacer(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: CustomPaint(
              size: Size(7, 4),
              painter: SortIndicatorPainter(
                sortDirection: SortDirection.descending,
                color: Colors.black,
              ),
            ),
          )
        ],
      );
    }

    if (menuActive || hover || !widget.isToolbar) {
      final Border border = Border.fromBorderSide(BorderSide(color: widget.borderColor));
      Decoration decoration;
      if (enabled && (pressed || menuActive)) {
        decoration = BoxDecoration(border: border, gradient: pressedGradient);
      } else if (enabled) {
        decoration = BoxDecoration(border: border, gradient: highlightGradient);
      } else {
        decoration = BoxDecoration(border: border, color: Color(0xffdddcd5));
      }
      button = DecoratedBox(decoration: decoration, child: button);
    }

    GestureTapCallback callback = widget.onPressed;
    if (widget.menuItems != null) {
      callback = () {
        if (widget.onPressed != null) {
          widget.onPressed();
        }
        setState(() {
          menuActive = true;
        });
        final RenderBox button = context.findRenderObject() as RenderBox;
        final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
        final RelativeRect position = RelativeRect.fromRect(
          Rect.fromPoints(
            button.localToGlobal(button.size.bottomLeft(Offset.zero), ancestor: overlay),
            button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
          ),
          Offset.zero & overlay.size,
        );
        showMenu<T>(
          context: context,
          position: position,
          items: widget.menuItems,
        ).then((T value) {
          setState(() {
            menuActive = false;
          });
          if (widget.onMenuItemSelected != null) {
            widget.onMenuItemSelected(value);
          }
        });
      };
    }

    if (enabled) {
      if (widget.showTooltip) {
        button = Tooltip(
          message: widget.label,
          waitDuration: Duration(seconds: 1, milliseconds: 500),
          child: button,
        );
      }

      button = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (PointerEnterEvent event) {
          setState(() => hover = true);
        },
        onExit: (PointerExitEvent event) {
          setState(() => hover = false);
        },
        child: Listener(
          onPointerDown: (PointerDownEvent event) {
            setState(() => pressed = true);
          },
          onPointerUp: (PointerUpEvent event) {
            setState(() => pressed = false);
          },
          child: GestureDetector(
            onTap: callback,
            child: button,
          ),
        ),
      );
    }

    if (widget.minimumAspectRatio != null) {
      button = _MinimumAspectRatio(
        minimumAspectRatio: 3,
        child: button,
      );
    }

    return button;
  }
}

class _MinimumAspectRatio extends SingleChildRenderObjectWidget {
  const _MinimumAspectRatio({
    Key key,
    Widget child,
    @required this.minimumAspectRatio,
  })  : assert(minimumAspectRatio != null),
        super(key: key, child: child);

  final double minimumAspectRatio;

  @override
  _RenderMinimumAspectRatio createRenderObject(BuildContext context) {
    return _RenderMinimumAspectRatio(minimumAspectRatio: minimumAspectRatio);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderMinimumAspectRatio renderObject) {
    renderObject..minimumAspectRatio = minimumAspectRatio;
  }
}

class _RenderMinimumAspectRatio extends RenderProxyBox {
  _RenderMinimumAspectRatio({
    RenderBox child,
    double minimumAspectRatio,
  })  : assert(minimumAspectRatio != null),
        _minimumAspectRatio = minimumAspectRatio,
        super(child);

  double _minimumAspectRatio;
  double get minimumAspectRatio => _minimumAspectRatio;
  set minimumAspectRatio(double value) {
    assert(value != null);
    if (value == _minimumAspectRatio) return;
    _minimumAspectRatio = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    if (child == null) {
      return 0.0;
    }
    if (!height.isFinite) {
      height = child.getMaxIntrinsicHeight(double.infinity);
    }
    assert(height.isFinite);
    return math.max(height * _minimumAspectRatio, child.getMinIntrinsicWidth(height));
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (child == null) {
      return 0.0;
    }
    if (!height.isFinite) {
      height = child.getMaxIntrinsicHeight(double.infinity);
    }
    assert(height.isFinite);
    return math.max(height * _minimumAspectRatio, child.getMaxIntrinsicWidth(height));
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return computeMaxIntrinsicHeight(width);
  }

  @override
  void performLayout() {
    if (child != null) {
      BoxConstraints childConstraints = constraints;
      if (!childConstraints.hasTightHeight) {
        final double height = child.getMaxIntrinsicHeight(childConstraints.maxWidth);
        assert(height.isFinite);
        childConstraints = childConstraints.tighten(height: height);
      }
      childConstraints = childConstraints.copyWith(
        minWidth: childConstraints.constrainWidth(childConstraints.maxHeight * _minimumAspectRatio),
      );
      child.layout(childConstraints, parentUsesSize: true);
      size = child.size;
    } else {
      performResize();
    }
  }
}

class CommandPushButton<T> extends StatelessWidget {
  const CommandPushButton({
    Key key,
    @required this.label,
    @required this.onPressed,
  })  : assert(label != null),
        assert(onPressed != null),
        super(key: key);

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PushButton<T>(
      color: Colors.white,
      backgroundColor: const Color(0xff3c77b2),
      borderColor: const Color(0xff2b5580),
      padding: EdgeInsets.fromLTRB(3, 4, 4, 5),
      showTooltip: false,
      minimumAspectRatio: 3,
      onPressed: onPressed,
      label: label,
    );
  }
}