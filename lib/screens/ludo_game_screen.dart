import 'package:flutter/material.dart';
import 'dart:math' as math;

enum LudoColor { red, green, yellow, blue }

class LudoPiece {
  final LudoColor color;
  final int id;
  int position; // -1: Base, 0-51: Path, 52-57: Home Path/Goal

  LudoPiece({required this.color, required this.id, this.position = -1});
}

class LudoGameScreen extends StatefulWidget {
  final String chatId;
  const LudoGameScreen({super.key, required this.chatId});

  @override
  State<LudoGameScreen> createState() => _LudoGameScreenState();
}

class _LudoGameScreenState extends State<LudoGameScreen> with TickerProviderStateMixin {
  int _dice1 = 1;
  int _dice2 = 1;
  bool _isRolling = false;
  late AnimationController _diceController;
  
  List<LudoPiece> _pieces = [];
  LudoColor _currentTurn = LudoColor.red;
  bool _canRoll = true;
  List<int> _availableMoves = [];

  // Path coordinates for a 15x15 Ludo board
  static const List<Offset> _mainPath = [
    Offset(1, 6), Offset(2, 6), Offset(3, 6), Offset(4, 6), Offset(5, 6),
    Offset(6, 5), Offset(6, 4), Offset(6, 3), Offset(6, 2), Offset(6, 1), Offset(6, 0),
    Offset(7, 0), Offset(8, 0),
    Offset(8, 1), Offset(8, 2), Offset(8, 3), Offset(8, 4), Offset(8, 5),
    Offset(9, 6), Offset(10, 6), Offset(11, 6), Offset(12, 6), Offset(13, 6), Offset(14, 6),
    Offset(14, 7), Offset(14, 8),
    Offset(13, 8), Offset(12, 8), Offset(11, 8), Offset(10, 8), Offset(9, 8),
    Offset(8, 9), Offset(8, 10), Offset(8, 11), Offset(8, 12), Offset(8, 13), Offset(8, 14),
    Offset(7, 14), Offset(6, 14),
    Offset(6, 13), Offset(6, 12), Offset(6, 11), Offset(6, 10), Offset(6, 9),
    Offset(5, 8), Offset(4, 8), Offset(3, 8), Offset(2, 8), Offset(1, 8), Offset(0, 8),
    Offset(0, 7), Offset(0, 6),
  ];

  @override
  void initState() {
    super.initState();
    _diceController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _initializePieces();
  }

  void _initializePieces() {
    _pieces = [];
    for (var color in LudoColor.values) {
      for (int i = 0; i < 4; i++) {
        _pieces.add(LudoPiece(color: color, id: i));
      }
    }
  }

  void _rollDice() async {
    if (!_canRoll || _isRolling) return;
    
    setState(() => _isRolling = true);
    _diceController.repeat();
    
    await Future.delayed(const Duration(milliseconds: 800));
    
    setState(() {
      _dice1 = math.Random().nextInt(6) + 1;
      _dice2 = math.Random().nextInt(6) + 1;
      _isRolling = false;
      _canRoll = false;
      _availableMoves = [_dice1, _dice2];
      _checkMovablePieces();
    });
    _diceController.stop();
  }

  void _checkMovablePieces() {
    bool hasValidMove = false;
    for (int move in _availableMoves) {
      if (_pieces.where((p) => p.color == _currentTurn).any((p) {
        if (p.position == -1 && move == 6) return true;
        if (p.position >= 0 && p.position + move <= 57) return true;
        return false;
      })) {
        hasValidMove = true;
        break;
      }
    }

    if (!hasValidMove) {
      _nextTurn();
    }
  }

  void _movePiece(LudoPiece piece) {
    if (_availableMoves.isEmpty || piece.color != _currentTurn) return;

    int move = -1;
    // Simple logic: pick the first available die that can move this piece
    for (int m in _availableMoves) {
       if (piece.position == -1 && m == 6) { move = m; break; }
       if (piece.position >= 0 && piece.position + m <= 57) { move = m; break; }
    }

    if (move == -1) return;

    setState(() {
      if (piece.position == -1 && move == 6) {
        piece.position = 0;
      } else {
        piece.position += move;
        if (piece.position < 52) _checkCapture(piece);
      }
      _availableMoves.remove(move);
      
      if (_availableMoves.isEmpty) {
        if (_dice1 == 6 || _dice2 == 6) {
           _canRoll = true;
           _showMessage("Extra Roll!");
        } else {
          _nextTurn();
        }
      }
    });
  }

  void _checkCapture(LudoPiece movedPiece) {
    final movedOffset = _getGlobalOffset(movedPiece);
    for (var p in _pieces) {
      if (p.color != movedPiece.color && p.position >= 0 && p.position < 52) {
        if (_getGlobalOffset(p) == movedOffset) {
          p.position = -1;
          _showMessage("Captured ${p.color.name.toUpperCase()}!");
        }
      }
    }
  }

  void _nextTurn() {
    setState(() {
      int nextIndex = (_currentTurn.index + 1) % 4;
      _currentTurn = LudoColor.values[nextIndex];
      _canRoll = true;
      _availableMoves = [];
    });
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }

  @override
  void dispose() {
    _diceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1931), // Deep blue night sky
      appBar: AppBar(
        title: const Text('Ludo Club Elite', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF185ADB),
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          _buildTurnIndicator(),
          const Expanded(child: Center(child: LudoBoardWidget())),
          _buildDiceArea(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTurnIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: _getColor(_currentTurn),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)],
      ),
      child: Text(
        _currentTurn == LudoColor.red ? "YOU" : "COMPUTER ${_currentTurn.index}",
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
  }

  Widget _buildDiceArea() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DiceWidget(value: _dice1, isRolling: _isRolling, controller: _diceController),
          const SizedBox(width: 20),
          DiceWidget(value: _dice2, isRolling: _isRolling, controller: _diceController),
          const SizedBox(width: 40),
          ElevatedButton(
            onPressed: _canRoll ? _rollDice : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC947),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: Text(_canRoll ? "ROLL" : "MOVE", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Color _getColor(LudoColor color) {
    switch (color) {
      case LudoColor.red: return const Color(0xFFE94560);
      case LudoColor.green: return const Color(0xFF2ECC71);
      case LudoColor.yellow: return const Color(0xFFFFD700);
      case LudoColor.blue: return const Color(0xFF3498DB);
    }
  }

  Offset _getGlobalOffset(LudoPiece piece) {
    if (piece.position == -1) {
      final base = _getBasePos(piece.color);
      final slots = [const Offset(1.5, 1.5), const Offset(3.5, 1.5), const Offset(1.5, 3.5), const Offset(3.5, 3.5)];
      return Offset(base.dx + slots[piece.id].dx, base.dy + slots[piece.id].dy);
    }
    if (piece.position < 52) {
      int startIdx = 0;
      switch (piece.color) {
        case LudoColor.red: startIdx = 0; break;
        case LudoColor.green: startIdx = 13; break;
        case LudoColor.yellow: startIdx = 26; break;
        case LudoColor.blue: startIdx = 39; break;
      }
      return _mainPath[(startIdx + piece.position) % 52];
    }
    int homeStep = piece.position - 52;
    switch (piece.color) {
      case LudoColor.red: return Offset(1.0 + homeStep, 7.0);
      case LudoColor.green: return Offset(7.0, 1.0 + homeStep);
      case LudoColor.yellow: return Offset(13.0 - homeStep, 7.0);
      case LudoColor.blue: return Offset(7.0, 13.0 - homeStep);
    }
    return const Offset(7.0, 7.0);
  }

  Offset _getBasePos(LudoColor color) {
    switch (color) {
      case LudoColor.red: return const Offset(0, 0);
      case LudoColor.green: return const Offset(9, 0);
      case LudoColor.yellow: return const Offset(9, 9);
      case LudoColor.blue: return const Offset(0, 9);
    }
  }
}

class LudoBoardWidget extends StatelessWidget {
  const LudoBoardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final parent = context.findAncestorStateOfType<_LudoGameScreenState>()!;
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFC49102), width: 8),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(blurRadius: 20, color: Colors.black45)],
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: LudoBoardPainter())),
            ...parent._pieces.map((p) => _buildPieceWidget(p, parent)),
            // Labels matching screenshot
            const Positioned(top: 10, left: 10, child: Text("Computer 2", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
            const Positioned(top: 10, right: 10, child: Text("Computer 3", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
            const Positioned(bottom: 10, left: 10, child: Text("You", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
            const Positioned(bottom: 10, right: 10, child: Text("Computer 4", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
          ],
        ),
      ),
    );
  }

  Widget _buildPieceWidget(LudoPiece piece, _LudoGameScreenState parent) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth / 15;
        final h = constraints.maxHeight / 15;
        Offset gridPos = parent._getGlobalOffset(piece);

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          left: gridPos.dx * w + (w * 0.1),
          top: gridPos.dy * h + (h * 0.1),
          child: GestureDetector(
            onTap: () => parent._movePiece(piece),
            child: Container(
              width: w * 0.8,
              height: h * 0.8,
              decoration: BoxDecoration(
                color: parent._getColor(piece.color),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [BoxShadow(blurRadius: 4, offset: Offset(1, 1))],
              ),
              child: piece.color == parent._currentTurn && !parent._canRoll
                ? const Center(child: Icon(Icons.touch_app, size: 10, color: Colors.white))
                : null,
            ),
          ),
        );
      },
    );
  }
}

class DiceWidget extends StatelessWidget {
  final int value;
  final bool isRolling;
  final AnimationController controller;

  const DiceWidget({super.key, required this.value, required this.isRolling, required this.controller});

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: controller,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
            const BoxShadow(color: Colors.white, blurRadius: 2, offset: Offset(-2, -2), spreadRadius: 1),
          ],
        ),
        child: CustomPaint(
          painter: DicePainter(value: value, dotColor: const Color(0xFF4B0082)),
        ),
      ),
    );
  }
}

class DicePainter extends CustomPainter {
  final int value;
  final Color dotColor;
  DicePainter({required this.value, required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dotColor;
    final r = size.width * 0.1;
    final center = size.width / 2;
    final left = size.width * 0.25;
    final right = size.width * 0.75;
    final top = size.height * 0.25;
    final bottom = size.height * 0.75;

    List<Offset> dots = [];
    if (value == 1) dots = [Offset(center, center)];
    else if (value == 2) dots = [Offset(left, top), Offset(right, bottom)];
    else if (value == 3) dots = [Offset(left, top), Offset(center, center), Offset(right, bottom)];
    else if (value == 4) dots = [Offset(left, top), Offset(right, top), Offset(left, bottom), Offset(right, bottom)];
    else if (value == 5) dots = [Offset(left, top), Offset(right, top), Offset(center, center), Offset(left, bottom), Offset(right, bottom)];
    else if (value == 6) dots = [Offset(left, top), Offset(right, top), Offset(left, center), Offset(right, center), Offset(left, bottom), Offset(right, bottom)];

    for (var dot in dots) {
      canvas.drawCircle(dot, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class LudoBoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / 15;
    final h = size.height / 15;

    _drawBase(canvas, 0, 0, const Color(0xFFE94560), w, h);
    _drawBase(canvas, 9, 0, const Color(0xFF2ECC71), w, h);
    _drawBase(canvas, 9, 9, const Color(0xFFFFD700), w, h);
    _drawBase(canvas, 0, 9, const Color(0xFF3498DB), w, h);

    final pathPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final linePaint = Paint()..color = Colors.black26..style = PaintingStyle.stroke..strokeWidth = 0.5;

    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 6; j++) {
        _drawGridCell(canvas, (6 + i) * w, j * h, pathPaint, w, h, linePaint);
        _drawGridCell(canvas, (6 + i) * w, (9 + j) * h, pathPaint, w, h, linePaint);
        _drawGridCell(canvas, j * w, (6 + i) * h, pathPaint, w, h, linePaint);
        _drawGridCell(canvas, (9 + j) * w, (6 + i) * h, pathPaint, w, h, linePaint);
      }
    }

    for (int i = 1; i < 6; i++) {
      _drawGridCell(canvas, i * w, 7 * h, const Color(0xFFE94560), w, h);
      _drawGridCell(canvas, 7 * w, i * h, const Color(0xFF2ECC71), w, h);
      _drawGridCell(canvas, (14 - i) * w, 7 * h, const Color(0xFFFFD700), w, h);
      _drawGridCell(canvas, 7 * w, (14 - i) * h, const Color(0xFF3498DB), w, h);
    }

    _drawGridCell(canvas, 1 * w, 6 * h, const Color(0xFFE94560), w, h);
    _drawGridCell(canvas, 8 * w, 1 * h, const Color(0xFF2ECC71), w, h);
    _drawGridCell(canvas, 13 * w, 8 * h, const Color(0xFFFFD700), w, h);
    _drawGridCell(canvas, 6 * w, 13 * h, const Color(0xFF3498DB), w, h);

    _drawCenterGoal(canvas, size, w, h);
  }

  void _drawBase(Canvas canvas, double x, double y, Color color, double w, double h) {
    canvas.drawRect(Rect.fromLTWH(x * w, y * h, 6 * w, 6 * h), Paint()..color = color);
    canvas.drawRect(Rect.fromLTWH((x + 1) * w, (y + 1) * h, 4 * w, 4 * h), Paint()..color = Colors.white);
    final slotPaint = Paint()..color = color;
    double r = w * 0.7;
    canvas.drawCircle(Offset((x + 2) * w, (y + 2) * h), r, slotPaint);
    canvas.drawCircle(Offset((x + 4) * w, (y + 2) * h), r, slotPaint);
    canvas.drawCircle(Offset((x + 2) * w, (y + 4) * h), r, slotPaint);
    canvas.drawCircle(Offset((x + 4) * w, (y + 4) * h), r, slotPaint);
  }

  void _drawGridCell(Canvas canvas, double x, double y, dynamic colorOrPaint, double w, double h, [Paint? linePaint]) {
    final rect = Rect.fromLTWH(x, y, w, h);
    if (colorOrPaint is Color) canvas.drawRect(rect, Paint()..color = colorOrPaint);
    else canvas.drawRect(rect, colorOrPaint);
    canvas.drawRect(rect, linePaint ?? (Paint()..color = Colors.black26..style = PaintingStyle.stroke));
  }

  void _drawCenterGoal(Canvas canvas, Size size, double w, double h) {
    final center = Offset(size.width / 2, size.height / 2);
    final p1 = Offset(6 * w, 6 * h), p2 = Offset(9 * w, 6 * h), p3 = Offset(9 * w, 9 * h), p4 = Offset(6 * w, 9 * h);
    _drawTriangle(canvas, p1, p4, center, const Color(0xFFE94560));
    _drawTriangle(canvas, p1, p2, center, const Color(0xFF2ECC71));
    _drawTriangle(canvas, p2, p3, center, const Color(0xFFFFD700));
    _drawTriangle(canvas, p3, p4, center, const Color(0xFF3498DB));
  }

  void _drawTriangle(Canvas canvas, Offset a, Offset b, Offset c, Color color) {
    final path = Path()..moveTo(a.dx, a.dy)..lineTo(b.dx, b.dy)..lineTo(c.dx, c.dy)..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(path, Paint()..color = Colors.black26..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
