import 'package:flutter/material.dart';

import 'package:graphql_flutter/graphql_flutter.dart';

import './mutations/addStar.dart' as mutations;
import './queries/readRepositories.dart' as queries;

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final HttpLink link = HttpLink(
      uri: 'https://api.github.com/graphql',
      headers: <String, String>{
        'Authorization': 'Bearer <YOUR_PERSONAL_ACCESS_TOKEN>',
      },
    );

    final ValueNotifier<GraphQLClient> client = ValueNotifier<GraphQLClient>(
      GraphQLClient(
        cache: InMemoryCache(),
        link: link,
      ),
    );

    return GraphQLProvider(
      client: client,
      child: CacheProvider(
        child: MaterialApp(
          title: 'GraphQL Flutter Demo',
          theme: ThemeData(
            primarySwatch: Colors.blue,
          ),
          home: const MyHomePage(title: 'GraphQL Flutter Home Page'),
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    Key key,
    this.title,
  }) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Query(
        options: QueryOptions(
          document: queries.readRepositories,
          pollInterval: 4,
          // you can optionally override some http options through the contexts
          context: <String, dynamic>{
            'headers': <String, String>{
              'Authorization': 'Bearer <YOUR_PERSONAL_ACCESS_TOKEN>',
            },
          },
        ),
        builder: (QueryResult result) {
          if (result.errors != null) {
            return Text(result.errors.toString());
          }

          if (result.loading) {
            return const Text('Loading');
          }

          // result.data can be either a Map or a List
          final List<Map<String, dynamic>> repositories =
              result.data['viewer']['repositories']['nodes'];

          return ListView.builder(
            itemCount: repositories.length,
            itemBuilder: (BuildContext context, int index) {
              final Map<String, dynamic> repository = repositories[index];

              return Mutation(
                options: MutationOptions(
                  document: mutations.addStar,
                ),
                builder: (
                  RunMutation addStar,
                  QueryResult addStarResult,
                ) {
                  if (addStarResult.data != null &&
                      addStarResult.data.isNotEmpty) {
                    repository['viewerHasStarred'] = addStarResult
                        .data['addStar']['starrable']['viewerHasStarred'];
                  }

                  return ListTile(
                    leading: repository['viewerHasStarred']
                        ? const Icon(Icons.star, color: Colors.amber)
                        : const Icon(Icons.star_border),
                    title: Text(repository['name']),
                    // optimistic ui updates are not implemented yet, therefore changes may take some time to show
                    onTap: () {
                      addStar(<String, dynamic>{
                        'starrableId': repository['id'],
                      });
                    },
                  );
                },
                onCompleted: (QueryResult onCompleteResult) {
                  showDialog<AlertDialog>(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Thanks for your star!'),
                        actions: <Widget>[
                          SimpleDialogOption(
                            child: const Text('Dismiss'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          )
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
