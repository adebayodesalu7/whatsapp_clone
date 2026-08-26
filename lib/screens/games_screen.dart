import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';
import 'package:whatsapp_clone/services/chat_service.dart';
import 'dart:math' as math;

import 'package:whatsapp_clone/screens/ludo_game_screen.dart';

class GamesScreen extends StatefulWidget {
  final String? chatId;
  const GamesScreen({super.key, this.chatId});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    
    return Scaffold(
      backgroundColor: themeProvider.getColor('scaffold'),
      appBar: AppBar(
        title: const Text('Titan Game Center', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: themeProvider.getColor('appBar'),
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(20),
        crossAxisCount: 2,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        children: [
          _buildGameCard(
            'Nigerian Whot', 
            Icons.style, 
            Colors.orange, 
            () => _startChallenge('Whot'),
          ),
          _buildGameCard(
            'Chess Master', 
            Icons.grid_4x4, 
            Colors.brown, 
            () => _startChallenge('Chess'),
          ),
          _buildGameCard(
            'Ludo Club Elite', 
            Icons.apps, 
            Colors.red, 
            () => _startChallenge('Ludo'),
          ),
          _buildGameCard(
            '2048', 
            Icons.numbers, 
            Colors.blue, 
            () => _startChallenge('2048'),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: color),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            const Text('Play with Friend', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  void _startChallenge(String game) {
    if (widget.chatId != null) {
      if (game == 'Whot') {
        final chatService = ChatService();
        chatService.sendGameChallenge(widget.chatId!, "Nigerian Whot", isGroup: false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WhotGame(chatId: widget.chatId!),
          ),
        );
      } else if (game == 'Ludo') {
        final chatService = ChatService();
        chatService.sendGameChallenge(widget.chatId!, "Ludo Club Elite", isGroup: false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LudoGameScreen(chatId: widget.chatId!),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🎮 Challenging friend to a game of $game...')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Select a chat to start a $game challenge.')),
      );
    }
  }
}

// ===== Redesigned Nigerian Whot Game - Exact Screenshot Match =====

enum WhotShape { circle, triangle, cross, star, square, whot }

class WhotCard {
  final WhotShape shape;
  final int number;

  WhotCard(this.shape, this.number);
}

class WhotGame extends StatefulWidget {
  final String chatId;
  const WhotGame({super.key, required this.chatId});

  @override
  State<WhotGame> createState() => _WhotGameState();
}

class _WhotGameState extends State<WhotGame> {
  List<WhotCard> deck = [];
  List<WhotCard> playerHand = [];
  List<WhotCard> computerHand = [];
  WhotCard? topCard;
  WhotShape? requestedShape;
  String status = "Your turn";
  bool gameOver = false;
  bool isPlayerTurn = true;
  bool showRequestOverlay = false;
  int penaltyStack = 0;

  final Color maroon = const Color(0xFF8B0000);
  final Color woodColor = const Color(0xFF5D3A1A);

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  void _initializeGame() {
    deck = [];
    for (var shape in WhotShape.values) {
      if (shape == WhotShape.whot) {
        for (int i = 0; i < 5; i++) deck.add(WhotCard(shape, 20));
      } else {
        List<int> numbers = shape == WhotShape.star ? [1, 2, 3, 4, 5, 7, 8] : [1, 2, 3, 4, 5, 7, 8, 10, 11, 12, 13, 14];
        for (var n in numbers) deck.add(WhotCard(shape, n));
      }
    }
    deck.shuffle();

    playerHand = deck.sublist(0, 5);
    computerHand = deck.sublist(5, 10);
    topCard = deck[10];
    deck.removeRange(0, 11);
    
    gameOver = false;
    isPlayerTurn = true;
    showRequestOverlay = false;
    requestedShape = null;
    penaltyStack = 0;
    status = "Your turn";
  }

  void _playCard(int index) {
    if (gameOver || !isPlayerTurn) return;
    
    WhotCard card = playerHand[index];
    
    // Validate move
    bool canPlay = false;
    
    // Strict Rule: If there is a penalty (Pick 2/3), you MUST defend with the same number or draw
    if (penaltyStack > 0) {
      canPlay = (card.number == topCard!.number); 
    } else if (requestedShape != null) {
      canPlay = card.shape == requestedShape || card.shape == WhotShape.whot;
    } else {
      canPlay = card.shape == topCard!.shape || card.number == topCard!.number || card.shape == WhotShape.whot;
    }

    if (canPlay) {
      setState(() {
        topCard = card;
        playerHand.removeAt(index);
        requestedShape = null;
        
        if (playerHand.isEmpty) {
          status = "Check Up! You Win!";
          gameOver = true;
          return;
        }
        _handleSpecialCard(card, true);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid move!")));
    }
  }

  void _handleSpecialCard(WhotCard card, bool isPlayer) {
    bool nextTurn = true;

    switch (card.number) {
      case 1: 
        status = isPlayer ? "Play Again!" : "Zo plays again...";
        nextTurn = false;
        break;
      case 2: 
        penaltyStack += 2;
        status = isPlayer ? "Pick Two!" : "You pick two!";
        break;
      case 5: 
        penaltyStack += 3;
        status = isPlayer ? "Pick Three!" : "You pick three!";
        break;
      case 8: 
        status = isPlayer ? "Suspension!" : "You are suspended!";
        nextTurn = false;
        break;
      case 14: 
        // Nigerian Rule: General Market affects EVERYONE ELSE
        // In 2 player, it's just the computer/opponent
        if (isPlayer) {
          if (deck.isNotEmpty) computerHand.add(deck.removeLast());
        } else {
          if (deck.isNotEmpty) playerHand.add(deck.removeLast());
        }
        status = "GENERAL MARKET! 🛒";
        break;
      case 20: 
        if (isPlayer) {
          setState(() => showRequestOverlay = true);
          return; 
        } else {
          requestedShape = _getBestShape(computerHand);
          status = "Zo requested ${requestedShape!.name.toUpperCase()}";
        }
        break;
    }

    if (nextTurn) {
      isPlayerTurn = !isPlayerTurn;
      status = isPlayerTurn ? "Your turn" : "Zo's turn";
      if (!isPlayerTurn) _computerMove();
    } else {
      if (!isPlayerTurn) _computerMove();
    }
  }

  WhotShape _getBestShape(List<WhotCard> hand) {
    Map<WhotShape, int> counts = {};
    for (var c in hand) {
      if (c.shape != WhotShape.whot) {
        counts[c.shape] = (counts[c.shape] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return WhotShape.circle;
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  void _drawCard() {
    if (gameOver || !isPlayerTurn) return;
    
    setState(() {
      if (penaltyStack > 0) {
        for (int i = 0; i < penaltyStack; i++) {
          if (deck.isNotEmpty) playerHand.add(deck.removeLast());
        }
        penaltyStack = 0;
      } else {
        if (deck.isNotEmpty) playerHand.add(deck.removeLast());
      }
      isPlayerTurn = false;
      status = "Zo's turn";
      _computerMove();
    });
  }

  void _computerMove() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted || gameOver) return;

    int moveIndex = computerHand.indexWhere((c) {
      if (penaltyStack > 0) {
        return c.number == topCard!.number; 
      }
      if (requestedShape != null) {
        return c.shape == requestedShape || c.shape == WhotShape.whot;
      }
      return c.shape == topCard!.shape || c.number == topCard!.number || c.shape == WhotShape.whot;
    });

    setState(() {
      if (moveIndex != -1) {
        WhotCard card = computerHand[moveIndex];
        topCard = card;
        computerHand.removeAt(moveIndex);
        requestedShape = null;

        if (computerHand.isEmpty) {
          status = "Zo Wins!";
          gameOver = true;
        } else {
          _handleSpecialCard(card, false);
        }
      } else {
        if (penaltyStack > 0) {
          for (int i = 0; i < penaltyStack; i++) {
            if (deck.isNotEmpty) computerHand.add(deck.removeLast());
          }
          penaltyStack = 0;
        } else {
          if (deck.isNotEmpty) computerHand.add(deck.removeLast());
        }
        isPlayerTurn = true;
        status = "Your turn";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage("https://images.unsplash.com/photo-1590480335324-4f8115598687?q=80&w=2074&auto=format&fit=crop"),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.3)),
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _buildTopAvatar("Zo", computerHand.length, "https://i.pravatar.cc/150?u=zo"),
                    const SizedBox(height: 10),
                    _buildComputerHand(),
                    const Spacer(),
                    _buildCenterArea(),
                    const Spacer(),
                    _buildBottomHand(),
                    _buildTopAvatar("Me", playerHand.length, "https://i.pravatar.cc/150?u=me"),
                  ],
                ),
                if (showRequestOverlay) _buildRequestOverlay(),
                if (gameOver) _buildGameOverOverlay(),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopAvatar(String name, int count, String url) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: Colors.yellow, shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 1)),
          child: Stack(
            children: [
              CircleAvatar(radius: 27, backgroundImage: NetworkImage(url)),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.yellow, shape: BoxShape.circle),
                  child: Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black)),
                ),
              ),
            ],
          ),
        ),
        Text(name, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildComputerHand() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              computerHand.length,
              (index) => Align(
                widthFactor: 0.5,
                child: _buildBackCard(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          status, 
          style: const TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.bold, 
            fontSize: 24,
            fontStyle: FontStyle.italic,
            shadows: [Shadow(color: Colors.black, blurRadius: 4)]
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             _buildBackCard(isMarket: true),
            const SizedBox(width: 40),
            WhotCardWidget(card: topCard!),
          ],
        ),
        if (requestedShape != null)
           Padding(
             padding: const EdgeInsets.only(top: 10),
             child: Text(
               "WANTED: ${requestedShape!.name.toUpperCase()}", 
               style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 16),
             ),
           ),
      ],
    );
  }

  Widget _buildBottomHand() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text("Your Hand", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 40),
            itemCount: playerHand.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _playCard(index),
                child: Align(
                  widthFactor: 0.6,
                  child: WhotCardWidget(card: playerHand[index]),
                ),
              );
            },
          ),
        ),
        GestureDetector(
          onTap: _drawCard,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.yellow, width: 1)),
            child: const Text("GO TO MARKET", style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildBackCard({bool isMarket = false}) {
    return Container(
      width: 70,
      height: 100,
      decoration: BoxDecoration(
        color: maroon,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black54)],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             const Icon(Icons.style, color: Colors.white30, size: 40),
             Text(isMarket ? "MARKET" : "Whot", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF004D40),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.orange, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Request", style: TextStyle(color: Colors.orange, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _requestOption(WhotShape.circle),
                  _requestOption(WhotShape.cross),
                  _requestOption(WhotShape.square),
                  _requestOption(WhotShape.star),
                  _requestOption(WhotShape.triangle),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _requestOption(WhotShape shape) {
    return GestureDetector(
      onTap: () {
        setState(() {
          requestedShape = shape;
          showRequestOverlay = false;
          isPlayerTurn = false;
          _computerMove();
        });
      },
      child: Container(
        width: 80,
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: Center(child: Icon(_getShapeIconData(shape), color: maroon, size: 50)),
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              status.contains("Win") ? "CHECK UP!" : "GAME OVER",
              style: TextStyle(color: status.contains("Win") ? Colors.green : Colors.red, fontSize: 40, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _initializeGame,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              child: const Text("PLAY AGAIN"),
            ),
          ],
        ),
      ),
    );
  }
}

class WhotCardWidget extends StatelessWidget {
  final WhotCard card;

  const WhotCardWidget({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final bool isWhot = card.shape == WhotShape.whot;
    final color = const Color(0xFF8B0000); 

    return Container(
      width: 85,
      height: 130,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(1, 1))],
      ),
      child: Stack(
        children: [
          // Corner Numbers & Small Icons
          _cornerInfo(card.number, card.shape, isTop: true),
          _cornerInfo(card.number, card.shape, isTop: false),
          
          // Large center shape
          Center(
            child: Icon(
              isWhot ? Icons.workspace_premium : _getShapeIconData(card.shape),
              size: 55,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cornerInfo(int number, WhotShape shape, {required bool isTop}) {
    final color = const Color(0xFF8B0000);
    return Positioned(
      top: isTop ? 4 : null,
      bottom: isTop ? null : 4,
      left: isTop ? 4 : null,
      right: isTop ? null : 4,
      child: RotatedBox(
        quarterTurns: isTop ? 0 : 2,
        child: Column(
          children: [
            Text(number.toString(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color, height: 1)),
            Icon(_getShapeIconData(shape), size: 12, color: color),
          ],
        ),
      ),
    );
  }
}

IconData _getShapeIconData(WhotShape shape) {
  switch (shape) {
    case WhotShape.circle: return Icons.circle;
    case WhotShape.triangle: return Icons.change_history;
    case WhotShape.cross: return Icons.add;
    case WhotShape.star: return Icons.star;
    case WhotShape.square: return Icons.crop_square;
    case WhotShape.whot: return Icons.workspace_premium;
  }
}
