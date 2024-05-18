import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/standalone.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:url_launcher/url_launcher.dart';


void main() {
  tz.initializeTimeZones();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hourly News (from RNZ)',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Hourly News (from RNZ)'),
    );

  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  loadSet() {
    var sp = SharedPreferences.getInstance().then((value)
    {

      var m = value.getBool("msg");
      var h = value.getString("host");

      setState(() {
        if (m != null) displayMsg = m;
        if (h != null) mpdHost = h;
      });

    });

  }

  _MyHomePageState() {
    loadSet();
  }

  late Info timeStamps;
  var displayMsg = true;
  var mpdHost = "localhost";

  @override
  void initState() {
    super.initState();
    timeStamps = getCandidateTimeStamps(context);
  }


  _refreshLocationsFromNetwork() {
    setState(() {
      timeStamps = getCandidateTimeStamps(context);
    });
  }

  FutureOr onBackLoadSettings(dynamic d) {
    loadSet();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(onPressed: () {
            Navigator.push(context,
              MaterialPageRoute(builder: (context) => SettingsPage("Settings")),
            ).then(onBackLoadSettings);
          }, icon: Icon(Icons.settings)),
        ],
    ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (displayMsg) Text("""Radio New Zealand publishes the latest news bulletin every hour.
            
You can play it on RNZ website by navigating through several screens. Or you can play it nearly instantaneously by tapping a button below. 

Playing locally will launch a browser or media player that you already have installed on your device.

""") ,
            if (displayMsg) ElevatedButton(
                child: Text('Hide this message'),
                onPressed: () {
                  setState(() {
                    displayMsg = false;
                  });
                  var sp = SharedPreferences.getInstance().then((value)
                  {
                    value.setBool("msg", false);
                  });
                }),
            ElevatedButton(
                child: Text('Play latest RNZ news locally'),
                onPressed: () { playRNZNews(context, "", false);
                }),

            ElevatedButton(
              child: Text('Play latest RNZ news on Moode player'),
              onPressed: () { playRNZNews(context, mpdHost, true);
            }),

          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshLocationsFromNetwork,
        tooltip: 'Increment',
        child: const Icon(Icons.cached),
      ),
    );
  }
}

Info getCandidateTimeStamps(BuildContext context) {
  Info r = new Info();

  var nz = getLocation('Pacific/Auckland');
  var now = TZDateTime.now(nz);
  var earlier = now.subtract(Duration(hours: 1));
  
  r.currentHour = fullTimeStampFormat.format(now);
  r.pastHour = fullTimeStampFormat.format(earlier);

  return r;
}

class Info {
  late String currentHour;
  late String pastHour;
}

void playURLLocally(String url, BuildContext context) async {
  launch(url);
}


void playURL(String url, String mpdHost, BuildContext context) async {

  var zc = await http.get(Uri.parse("http://${mpdHost}/command?cmd=clear"));
  if (zc.statusCode != 200) {
    snack(context, "Could not clear Moode queue");
  }

  var url1 = "http://${mpdHost}/command?cmd=add%20${url}";
  var z = await http.get(Uri.parse(url1));
  if (z.statusCode == 200) {
    var pl = await http.get(Uri.parse("http://${mpdHost}/command?cmd=play"));
    if (pl.statusCode != 200) {
      snack(context, "Could not initiate play on Moode");
    }
  } else {
    snack(context, "Could not add news to Moode");
  }

}


void snack(BuildContext context, String msg) {
  final snackbarController = ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg)),
  );

}

void playRNZNews(BuildContext context, String host, bool mpd) async {

  var i = getCandidateTimeStamps(context);
  var chu = "https://on-demand.radionz.co.nz/news/${i.currentHour}00-064.mp3";
  var cpu = "https://on-demand.radionz.co.nz/news/${i.pastHour}00-064.mp3";

  var z = await http.head(Uri.parse(chu));
  if (z.statusCode == 200) {
    if (mpd) {
      playURL(chu, host, context);
    } else {
      playURLLocally(chu, context);
    }
    snack(context, "Playing current hour's news: ${chu}");
  } else if (z.statusCode == 404) {
    if (mpd) {
      playURL(cpu, host, context);
    } else {
      playURLLocally(cpu, context);
    }

    snack(context, "Playing last hour's news: ${cpu}");
  }

}



var fullTimeStampFormat = DateFormat("yyyyMMdd-HH");

class SettingsPage extends StatefulWidget {
  final String _appBarTitle;

  SettingsPage(this._appBarTitle, { Key? key }) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState(_appBarTitle);
}


class _SettingsPageState extends State<SettingsPage> {
  final String _appBarTitle;

  TextEditingController nameController = TextEditingController();
  bool displayMsg = false;

  @override
  void initState() {
    super.initState();
  }

  _SettingsPageState(this._appBarTitle) {

    var spf = SharedPreferences.getInstance();
    spf.then(
            (prefs)  {
              var n = prefs.getString("host");
              var m = prefs.getBool("msg");
              setState(() {
                if (n != null) nameController.text = n;
                if (m != null) displayMsg = m;
              });

            }
    );

  }


  void save() async {
    var spf = await SharedPreferences.getInstance();
    spf.setString("host", nameController.text);
    spf.setBool("msg", displayMsg);
  }

  void _removeSettings() async {

    var sp = await SharedPreferences.getInstance();
    sp.clear();

    setState() {
      //citiesConfig = getCities();
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: Text(this._appBarTitle)
        ),
        body: Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children:<Widget>[
                Text("SETTINGS"),
                Container(
                  padding: EdgeInsets.fromLTRB(10, 10, 10, 0),
                  child: TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Moode Hostname',
                    ),
                    onChanged: (String s) {
                      save();
                    },
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(10, 10, 10, 0),
                  child: CheckboxListTile(
                      title: Text("Display the intro text on main screen"),
                      value: displayMsg,
                      onChanged: (v) {
                        setState(() {
                          displayMsg = !displayMsg;
                        });
                        save();
                      },
                    ),
                ),

                Text("""
                
                
ABOUT:
                
I am not associated with Radio New Zealand (RNZ), it's just a convenvience utility to quickly launch to their news stream.
I am using VLC Music player when I am playing news localy.

Moode is a smart music player system that you can run on a Raspbery Pi computers."""),

                ElevatedButton(
                    child: Text('https://moodeaudio.org/'),
                    onPressed: () {
                      launch('https://moodeaudio.org/');
                    }),

              ]
          ),
        ),
        // this is for debugging purposes only
        floatingActionButton: false ? FloatingActionButton(
            onPressed: _removeSettings,
            tooltip: 'Increment',
            child: Icon(Icons.add)
        ) : null

    );
  }
}
