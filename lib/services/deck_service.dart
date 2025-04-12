import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/video_card_service.dart';


class Deck {
  final String id;
  final String name;
  final bool isSpeedDeck;
  final DateTime? deletedAt;

  Deck({
    required this.id, 
    required this.name,
    this.isSpeedDeck = false,
    this.deletedAt,
  });

  factory Deck.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Deck(
      id: doc.id,
      name: data['name'] ?? '',
      isSpeedDeck: data['isSpeedDeck'] ?? false,
      deletedAt: data['deletedAt'] != null ? (data['deletedAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isSpeedDeck': isSpeedDeck,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    };
  }
  
  Deck copyWith({
    String? id,
    String? name,
    bool? isSpeedDeck,
    DateTime? deletedAt,
  }) {
    return Deck(
      id: id ?? this.id,
      name: name ?? this.name,
      isSpeedDeck: isSpeedDeck ?? this.isSpeedDeck,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}

class DeckService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> createDeck(String name, {bool isSpeedDeck = false}) async {
    if (_auth.currentUser == null) {
      throw Exception('User must be logged in to create a deck');
    }

    try {
      String? userEmail = _auth.currentUser!.email;
      if (userEmail == null) {
        throw Exception('User email not found');
      }

      await _firestore
          .collection('users')
          .doc(userEmail)
          .collection('decks')
          .add({
        'name': name,
        'isSpeedDeck': isSpeedDeck,
        'deletedAt': null,
      });
      print('Deck created successfully');
    } catch (e) {
      print('Error creating deck: $e');
      throw Exception('Failed to create deck');
    }
  }

  Future<void> updateDeck(String deckId, String newName, {bool? isSpeedDeck}) async {
    if (_auth.currentUser == null) {
      throw Exception('User must be logged in to update a deck');
    }

    try {
      String? userEmail = _auth.currentUser!.email;
      if (userEmail == null) {
        throw Exception('User email not found');
      }

      Map<String, dynamic> updateData = {'name': newName};
      if (isSpeedDeck != null) {
        updateData['isSpeedDeck'] = isSpeedDeck;
      }

      await _firestore
          .collection('users')
          .doc(userEmail)
          .collection('decks')
          .doc(deckId)
          .update(updateData);
      print('Deck updated successfully');
    } catch (e) {
      print('Error updating deck: $e');
      throw Exception('Failed to update deck');
    }
  }

  Future<void> deleteDeckTemp(String deckId) async {
    if (_auth.currentUser == null) {
      throw Exception('User must be logged in to temporarily delete a deck');
    }

    try {
      String? userEmail = _auth.currentUser!.email;
      if (userEmail == null) {
        throw Exception('User email not found');
      }

      final now = Timestamp.now();
      
      await _firestore
          .collection('users')
          .doc(userEmail)
          .collection('decks')
          .doc(deckId)
          .update({
        'deletedAt': now,
      });

      print('Deck temporarily deleted successfully');
    } catch (e) {
      print('Error temporarily deleting deck: $e');
      throw Exception('Failed to temporarily delete deck');
    }
  }

  Future<void> restoreDeck(String deckId) async {
    if (_auth.currentUser == null) {
      throw Exception('User must be logged in to restore a deck');
    }

    try {
      String? userEmail = _auth.currentUser!.email;
      if (userEmail == null) {
        throw Exception('User email not found');
      }
      
      await _firestore
          .collection('users')
          .doc(userEmail)
          .collection('decks')
          .doc(deckId)
          .update({
        'deletedAt': null,
      });

      print('Deck restored successfully');
    } catch (e) {
      print('Error restoring deck: $e');
      throw Exception('Failed to restore deck');
    }
  }

  Future<void> deleteDeck(String deckId) async {
    if (_auth.currentUser == null) {
      throw Exception('User must be logged in to delete a deck');
    }

    try {
      String? userEmail = _auth.currentUser!.email;
      if (userEmail == null) {
        throw Exception('User email not found');
      }

      await _firestore.runTransaction((transaction) async {
        final cardsQuery = await _firestore
            .collection('users')
            .doc(userEmail)
            .collection('video_cards')
            .where('deckId', isEqualTo: deckId)
            .get();

        for (var cardDoc in cardsQuery.docs) {
          transaction.delete(cardDoc.reference);
        }

        final deckRef = _firestore
            .collection('users')
            .doc(userEmail)
            .collection('decks')
            .doc(deckId);
        transaction.delete(deckRef);
      });

      print('Deck and all associated cards deleted successfully');
    } catch (e) {
      print('Error deleting deck and cards: $e');
      throw Exception('Failed to delete deck and associated cards');
    }
  }

  Stream<void> getDeckChanges() {
    if (_auth.currentUser == null || _auth.currentUser!.email == null) {
      return Stream.empty();
    }

    return _firestore
        .collection('users')
        .doc(_auth.currentUser!.email)
        .collection('decks')
        .snapshots()
        .map((_) => null);
  }

  Stream<List<Deck>> getDecks() {
    if (_auth.currentUser == null || _auth.currentUser!.email == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(_auth.currentUser!.email)
        .collection('decks')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
        .map((doc) => Deck.fromFirestore(doc))
        .where((deck) => deck.deletedAt == null)
        .toList();
    });
  }
  
  Stream<List<Deck>> getDeletedDecks() {
    if (_auth.currentUser == null || _auth.currentUser!.email == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(_auth.currentUser!.email)
        .collection('decks')
        .snapshots()
        .map((snapshot) {
      final deletedDecks = snapshot.docs
        .map((doc) => Deck.fromFirestore(doc))
        .where((deck) => deck.deletedAt != null)
        .toList();
      
      deletedDecks.sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
      
      return deletedDecks;
    });
  }
  
  Future<List<VideoCard>> getCardsForDeck(String deckId) async {
    if (_auth.currentUser == null || _auth.currentUser!.email == null) {
      throw Exception('User must be logged in to get deck cards');
    }

    try {
      final userEmail = _auth.currentUser!.email!;
      final deckDoc = await _firestore
          .collection('users')
          .doc(userEmail)
          .collection('decks')
          .doc(deckId)
          .get();

      final cardRefs = deckDoc.data()?['cardRefs'] as List<dynamic>? ?? [];

      List<VideoCard> cards = [];
      for (var cardId in cardRefs) {
        final cardDoc = await _firestore
            .collection('users')
            .doc(userEmail)
            .collection('video_cards')
            .doc(cardId)
            .get();

        if (cardDoc.exists) {
          cards.add(VideoCard.fromFirestore(cardDoc.data()!, cardDoc.id));
        }
      }

      return cards;
    } catch (e) {
      print('Error getting cards for deck: $e');
      rethrow;
    }
  }

  Future<void> createDefaultDeckIfNeeded() async {
    if (_auth.currentUser == null) {
      throw Exception('User must be logged in');
    }

    try {
      String? userEmail = _auth.currentUser!.email;
      if (userEmail == null) {
        throw Exception('User email not found');
      }

      final decksSnapshot = await _firestore
          .collection('users')
          .doc(userEmail)
          .collection('decks')
          .limit(1)
          .get();

      if (decksSnapshot.docs.isEmpty) {
        await _firestore
            .collection('users')
            .doc(userEmail)
            .collection('decks')
            .add({
          'name': 'Default Deck',
          'isSpeedDeck': false,
          'deletedAt': null,
        });
      }
    } catch (e) {
      print('Error creating default deck: $e');
      throw Exception('Failed to create default deck');
    }
  }
}
