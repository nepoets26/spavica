import 'package:flutter/material.dart';
import '../services/deck_service.dart';
import '../services/auth_service.dart';
import '../services/video_card_service.dart';
import 'video_study_screen.dart';
import '/widgets/edit_card_dialog.dart';

class DeckManagementScreen extends StatefulWidget {
  const DeckManagementScreen({Key? key}) : super(key: key);

  @override
  _DeckManagementScreenState createState() => _DeckManagementScreenState();
}

class _DeckManagementScreenState extends State<DeckManagementScreen> {

  final DeckService _deckService = DeckService();
  final TextEditingController _newDeckController = TextEditingController();
  final VideoCardService _videoCardService = VideoCardService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Decks'),
      ),
      body: StreamBuilder<List<Deck>>(
        stream: _deckService.getDecks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No decks found'));
          }
          return StreamBuilder<Map<String, DueCardInfo>>(
            stream: _videoCardService.getDueCardsInfoForDecks(),
            builder: (context, dueCardsSnapshot) {
              if (dueCardsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final dueCardsInfo = dueCardsSnapshot.data ?? {};
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  Deck deck = snapshot.data![index];
                  final dueInfo = dueCardsInfo[deck.id] ?? DueCardInfo();
                  return ListTile(
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(deck.name),
                        ),
                        _buildDueCardCount(dueInfo),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VideoStudyScreen(deckId: deck.id, deckName: deck.name, isSpeedDeck:deck.isSpeedDeck,),
                        ),
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

  Widget _buildDueCardCount(DueCardInfo dueInfo) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dueInfo.shortTermCount > 0)
          _buildCountText(dueInfo.shortTermCount, Colors.red),
        if (dueInfo.mediumTermCount > 0)
          _buildCountText(dueInfo.mediumTermCount, Colors.blue),
        if (dueInfo.longTermCount > 0)
          _buildCountText(dueInfo.longTermCount, Colors.green),
      ],
    );
  }

  Widget _buildCountText(int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        count.toString(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, Deck deck) {
    final TextEditingController controller = TextEditingController(text: deck.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Deck Name'),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Save'),
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                try {
                  await _deckService.updateDeck(deck.id, controller.text);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Deck updated successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update deck: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Deck deck) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Deck'),
        content: Text('Are you sure you want to delete "${deck.name}"?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Delete'),
            onPressed: () async {
              try {
                await _deckService.deleteDeck(deck.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Deck deleted successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete deck: $e')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}