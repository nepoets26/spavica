import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/video_card_service.dart';


class Deck {
  final String id;
  final String name;
  final bool isSpeedDeck;

  Deck({required this.id, required this.name,this.isSpeedDeck = false});

  factory Deck.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Deck(
      id: doc.id,
      name: data['name'] ?? '',
      isSpeedDeck: data['isSpeedDeck'] ?? false,  // Đọc giá trị từ Firestore
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isSpeedDeck': isSpeedDeck,
    };
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
        'isSpeedDeck': isSpeedDeck,  // Thêm trường mới
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

  Future<void> deleteDeck(String deckId) async {
    if (_auth.currentUser == null) {
      throw Exception('User must be logged in to delete a deck');
    }

    try {
      String? userEmail = _auth.currentUser!.email;
      if (userEmail == null) {
        throw Exception('User email not found');
      }

      // Bắt đầu một transaction để đảm bảo tính toàn vẹn của dữ liệu
      await _firestore.runTransaction((transaction) async {
        // 1. Lấy tất cả các card trong deck
        final cardsQuery = await _firestore
            .collection('users')
            .doc(userEmail)
            .collection('video_cards')
            .where('deckId', isEqualTo: deckId)
            .get();

        // 2. Xóa tất cả các card
        for (var cardDoc in cardsQuery.docs) {
          transaction.delete(cardDoc.reference);
        }

        // 3. Xóa deck
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
      return snapshot.docs.map((doc) => Deck.fromFirestore(doc)).toList();
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
}
