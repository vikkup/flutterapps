import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'World of Robots!',
      theme: ThemeData(
        // This is the theme of your application.
        primarySwatch: Colors.green,
      ),
      home: const MyHomePage(title: 'World of Robots!'),
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
  ScrollController controller = ScrollController();
  
  int lazyLen = 1; //starting with one image
  List<bool> _list = [];
  Future<List<ImageData>>? futureData;
  final firestoreInstance = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    controller.addListener(_scrollListener);
    _list = []; 
    futureData = getCloudFirestoreImageData();
  }

  @override
  void dispose() {
    controller.removeListener(_scrollListener);
    super.dispose();
  }

  updateCloudFirestoreImageData(ImageData imageData, int index) async {
    CollectionReference collRef = firestoreInstance.collection('imgData');
    DocumentReference ref = collRef.doc(imageData.id);
    await ref.update({
      'liked' : _list[index]
    });
  }

  Future<List<ImageData>> getCloudFirestoreImageData() async {
    List<ImageData> images = [];
    await firestoreInstance.collection("imgData").get().then((querySnapshot) {
      querySnapshot.docs.forEach((value) {
        var id = value.id;
        var imageName = value.data()['name'];
        var imageTitle = value.data()['title'];
        var imageLiked = value.data()['liked'];
        var description = value.data()['description'];
        images.add(ImageData(id, imageName, imageTitle, imageLiked, description));
        _list.add(imageLiked);
      });
    }).catchError((onError) {
      print("getCloudFirestoreImageData: ERROR");
      print(onError);
    });

    for(var i = 0; i < images.length; i++) {
      final ref = FirebaseStorage.instance.ref().child(images[i].name);
      String url = (await ref.getDownloadURL()).toString();
      images[i].url = url; 
    }
  
    return images;
  }

  void _showcontent(String title, String desc) {
    showDialog(
      context: context, barrierDismissible: false, // user must tap button!

      builder: (BuildContext context) {
        return new AlertDialog(
          title: new Text("You clicked on $title"),
          content: new SingleChildScrollView(
            child: new ListBody(
              children: [
                new Text(desc),
              ],
            ),
          ),
          actions: [
            new FlatButton(
              child: new Text('Ok'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  
  Card buildCard(ImageData imageData, int index) {
    var heading = imageData.title;
    var supportingText = imageData.name;
    
    return Card(
        elevation: 4.0,
        child: Column(
          children: [
            ListTile(
              title: Text(heading),
              trailing: IconButton(
              icon: Icon(_list[index] ? Icons.favorite : Icons.favorite_outline,
              color: _list[index]? Colors.red : Colors.grey),
              onPressed: () {
                setState(() {
                 _list[index] = !_list[index];
                });
                updateCloudFirestoreImageData(imageData, index);
              }),
            ),
            InkWell(
              onTap: () => _showcontent(imageData.title, imageData.description),
              child: Image.network(
                imageData.url,
                fit: BoxFit.fill,
              ),
            ),
            ButtonBar(
              children: [
                TextButton(
                  child: const Text('LEARN MORE'),
                  onPressed: () => _showcontent(imageData.title, imageData.description),
                )
              ],
            )
          ],
        ));
    }

  void _scrollListener() {
    //lazy loading images one after another upon scrolling to the bottom
    if (controller.position.extentAfter == 0) { 
      setState(() {
        lazyLen = lazyLen < _list.length? lazyLen + 1 : lazyLen;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
          child: FutureBuilder<List<ImageData>>(
            future: futureData,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                List<ImageData>? data = snapshot.data;
                var length = data?.length;

                return 
                ListView.builder(
                controller: controller,
                itemCount: lazyLen,
                itemBuilder: (BuildContext context, int index) {
                  if (index == lazyLen) {
                    return CircularProgressIndicator();
                  }
                  var imageData = data == null ? ImageData("1","Default","Default",false,"Default") : data[index];
                  return buildCard(imageData, index);
                }
              );
              } else if (snapshot.hasError) {
                print("snapshot has error");
                return Text("${snapshot.error}");
              } 
              // By default show a loading spinner.
              return CircularProgressIndicator();
            },
          ),
        ),
    );
  }
}

class ImageData {
  String id;
  String name;
  String title;
  bool isLiked;
  String description;
  String url = "";

  ImageData(this.id, this.name, this.title, this.isLiked, this.description);
}
