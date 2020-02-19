import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../net/google_auth.dart';
import 'find_experiments_page.dart';
import 'welcome_page.dart';

class LoginPage extends StatefulWidget {
  static const routeName = '/login';


  LoginPage({Key key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}


class _LoginPageState extends State<LoginPage> {
  var url;

  urlCallback(url) {
    this.url = url;
  }

  @override
  void initState() {
    super.initState();
    final gAuth = GoogleAuth();
    gAuth.onAuthChanged.listen((bool success) {
      if (success) {
        Navigator.pushReplacementNamed(context, FindExperimentsPage.routeName);
      }
    });
    gAuth.authenticate(urlCallback);
  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
        backgroundColor: Colors.indigo,
      ),
      body: Container(
        padding: EdgeInsets.all(8.0),
        //margin: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
        child: ListView(
          padding: EdgeInsets.all(4.0),
          children: <Widget>[
            buildWelcomeTextWidget(),
            Divider(
              height: 16.0,
              color: Colors.black,
            ),
            Row(children: <Widget>[
            buildLoginButtonWidget(context),
            buildCancelButtonWidget(context)]),
            //Divider(),
            //Divider(),
          ],
        ),
      ),
    );
  }

  Text buildWelcomeTextWidget() {
    return Text(
      "Click the Login button to be taken to Google's login page in your browser",
    );
  }

  RaisedButton buildCancelButtonWidget(BuildContext context) {
    return RaisedButton(
      onPressed: () {
        Navigator.pushNamed(context, WelcomePage.routeName);
      },
      child: const Text('Cancel'),
    );
  }

  RaisedButton buildLoginButtonWidget(BuildContext context) {
    return RaisedButton(
      onPressed: () {
        _launchInBrowser(url);
      },
      child: const Text('Login'),
    );
  }

  Future<void> _launchInBrowser(String url) async {
    if (await canLaunch(url)) {
      await launch(url, forceSafariVC: false, forceWebView: false);
    } else {
      throw 'Could not launch $url';
    }
  }
}