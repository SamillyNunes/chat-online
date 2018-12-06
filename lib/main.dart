import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';



void main() async{
  runApp(MyApp());
}

final ThemeData kIOSTheme = ThemeData(
  primarySwatch: Colors.orange,
  primaryColor: Colors.grey[100],
  primaryColorBrightness: Brightness.light
);

final ThemeData kDefaultTheme  = ThemeData(
  primarySwatch: Colors.purple,
  accentColor: Colors.orangeAccent[400]
);

final googleSignIn = GoogleSignIn(); //uma instancia p tudo
final auth = FirebaseAuth.instance; //apenas uma instancia o tempo todo

Future<Null> _ensureloggedIn() async{
  GoogleSignInAccount user = googleSignIn.currentUser; //pegando o usuario do google

  if(user==null){
    user = await googleSignIn.signInSilently(); //logar silenciosamente, sem mostrar nada ao user
  }
  if (user==null){ //se demorar e ele nao logar
    user = await googleSignIn.signIn(); // de forma nao silenciosa
  }

  if(await auth.currentUser()==null){ //verificando se o user no firebase eh nulo
    GoogleSignInAuthentication credentials = await googleSignIn.currentUser.authentication; //pega as credenciais do google
    await auth.signInWithGoogle(idToken: credentials.idToken, accessToken: credentials.accessToken); //passa as credenciais p o firebase
  }
}

_handleSubmited(String text) async{ //pega um texto e envia
  await _ensureloggedIn();
  _sendMessage(text: text);
}

void _sendMessage({String text, String imgUrl}){
  Firestore.instance.collection("messages").add(
      {
        "text":text,
        "imgUrl":imgUrl,
        "senderName":googleSignIn.currentUser.displayName, //nome do usuario
        "senderPhotoUrl":googleSignIn.currentUser.photoUrl, //foto do usuario do google
      }
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Chat App", //titulo que aparece quando ve todas as telas de app rodando
      debugShowCheckedModeBanner: false, //tira o nome debug
      theme: Theme.of(context).platform== TargetPlatform.iOS?
      kIOSTheme : kDefaultTheme,
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return SafeArea( //ignora uns itens do iphone
      bottom: false, //nao ignora
      top:false,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Chat App"),
          centerTitle: true,
          elevation: Theme.of(context).platform == TargetPlatform.iOS?
          0.0 : 4.0, //elevacao que da uma sombra
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: StreamBuilder( //le os dados sempre quando tiver um dado novo
                stream: Firestore.instance.collection("messages").snapshots(), //snapshot devolve um stream
                builder: (context,snapshot){
                    switch(snapshot.connectionState){
                      case ConnectionState.none:
                      case ConnectionState.waiting:
                        return Center(
                          child: CircularProgressIndicator(),
                        );
                      default:
                        return ListView.builder(
                            reverse: true, //as msgns vao vir de cima pra baixo
                            itemCount: snapshot.data.documents.length, //pega o tam
                            itemBuilder: (context,index){
                              List r = snapshot.data.documents.reversed.toList(); //inverte a ordem dos dados pra que as msgns fique de cima p baixo
                              return ChatMessage(r[index].data);
                            }
                        );
                    }
                  },
              ),
            ),
            Divider( //linha de divisao
              height: 1.0,
            ),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor, //cor de acordo com a plataforma
              ),
              child: TextComposer(),
            ),
          ],
        ),
      ),

    );
  }
}

class TextComposer extends StatefulWidget {
  @override
  _TextComposerState createState() => _TextComposerState();
}

class _TextComposerState extends State<TextComposer> {

  bool _isComposing = false;

  final _msgController = TextEditingController();

  void _reset(){
    _msgController.clear();
    setState(() {
      _isComposing=false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconTheme( //quando um tema eh aplicado apenas numa parte do app
      data: IconThemeData(color: Theme.of(context).accentColor), //todos os filhos desse widget tera a accentColor
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0), //margem simetricamente do lado horizontal. |Eh constante pqnao vai mudar e deixa o app um pouco mais leve
        decoration: Theme.of(context).platform==TargetPlatform.iOS?
        BoxDecoration(
          border: Border(top:BorderSide(color: Colors.grey[200]))

        ) :
        null, //se nao for um ios nao vai ter essa decoracao
        child: Row(
          children: <Widget>[
            Container(
              child: IconButton(
                  icon: Icon(Icons.photo_camera),
                  onPressed: () async {
                    await _ensureloggedIn(); //certificar de que estar logado
                    File imgFile = await ImagePicker.pickImage(source: ImageSource.camera);
                    if(imgFile==null) return;
                    // .ref eh a referencia, da pra fazer um grande sistema de pastas com child (se quisesse fazer isso era so dar varios .childd
                    StorageUploadTask task = FirebaseStorage.instance.ref().
                      child(googleSignIn.currentUser.id.toString() + DateTime.now().millisecondsSinceEpoch.toString()).putFile(imgFile); //como o caminho tem que ser unico, ta clocando o nome dele como o id do user mais os ms

                    String downloadUrl;
                    await task.onComplete.then((s) async{
                      downloadUrl = await s.ref.getDownloadURL();
                    });
                    _sendMessage(imgUrl: downloadUrl);

                  },
              ),
            ),
            Expanded(
              child: TextField(
                controller: _msgController,
                decoration: InputDecoration.collapsed(
                    hintText: "Enviar uma mensagem",
                ),
                onChanged: (text){
                  setState(() {
                    _isComposing=text.length>0; //se tiver mais que 0 caracteres vai ser verdadeiro
                  });
                },
                onSubmitted: (text){ //enviando pelo botao do tec
                  _handleSubmited(text);
                  _reset();
                },
              ),

            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Theme.of(context).platform== TargetPlatform.iOS
              ? CupertinoButton(
                child: Text("Enviar"),
                onPressed: _isComposing ? (){
                  _handleSubmited(_msgController.text);
                  _reset();
                } : null,
              )
              : IconButton(
                icon: Icon(Icons.send),
                onPressed: _isComposing ? (){
                  _handleSubmited(_msgController.text);
                  _reset();
                } : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {

  final Map<String,dynamic>data;

  ChatMessage(this.data);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10.0,vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundImage: NetworkImage(data["senderPhotoUrl"]),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  data["senderName"],
                  style: Theme.of(context).textTheme.subhead, //tema padrao p texto, nesse caso o subhead
                ),
                Container(
                  margin: const EdgeInsets.only(top:5.0),
                  child: data["imgUrl"] != null ?
                    Image.network(data["imgUrl"],width: 250.0,)
                    : Text(data["text"]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



