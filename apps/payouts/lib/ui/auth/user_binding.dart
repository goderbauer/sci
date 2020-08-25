import 'package:flutter/widgets.dart';

import 'package:payouts/src/model/user.dart';

class UserBinding extends StatefulWidget {
  const UserBinding({
    Key key,
    this.child,
  }) : super(key: key);

  final Widget child;

  @override
  State<StatefulWidget> createState() {
    return _UserBindingState();
  }

  static User of(BuildContext context) {
    _UserBindingScope scope = context.inheritFromWidgetOfExactType(_UserBindingScope);
    assert(scope != null, 'UserBinding not found in ancestry');
    return scope.userBindingState.user;
  }

  static void update(
    BuildContext context,
    String username,
    String password, {
    int lastInvoiceId,
    bool passwordRequiresReset = false,
  }) {
//    _UserBindingScope scope = context.inheritFromWidgetOfExactType(_UserBindingScope);
//    assert(scope != null, 'UserBinding not found in ancestry');
//    scope.userBindingState._updateUser(User(
//      username,
//      password,
//      lastInvoiceId,
//      passwordRequiresReset,
//    ));
  }

  static void clear(BuildContext context) {
    _UserBindingScope scope = context.inheritFromWidgetOfExactType(_UserBindingScope);
    assert(scope != null, 'UserBinding not found in ancestry');
    scope.userBindingState._updateUser(null);
  }
}

class _UserBindingState extends State<UserBinding> {
  User user;

  void _updateUser(User newUser) {
    if (user != newUser) {
      setState(() {
        user = newUser;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _UserBindingScope(userBindingState: this, child: widget.child);
  }
}

class _UserBindingScope extends InheritedWidget {
  const _UserBindingScope({
    Key key,
    this.userBindingState,
    Widget child,
  }) : super(key: key, child: child);

  final _UserBindingState userBindingState;

  @override
  bool updateShouldNotify(_UserBindingScope old) {
    // TODO figure out why the old scope getting passed here has the new credentials
    //return userBindingState.user != old.userBindingState.user;
    return true;
  }
}
